// mex shadeQuadratic.cpp 
#include "mex.h"
#include "common.h"

#include <algorithm>
#include <cmath>
#include <iostream>


using namespace std;

void checkInputs(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {

	if (nrhs != 2)
		mexErrMsgTxt("Incorrect number of input arguments.");

	if (nlhs != 1)
		mexErrMsgTxt("Incorrect number of output arguments.");

	// Check array sizes 
	int h, w, m, n, nL, i, nX;
	
	mwSize ndim;
	const mwSize *dims;
	ndim = mxGetNumberOfDimensions(prhs[0]);

	if (ndim != 3)
		mexErrMsgTxt("Normal map must have N = 3 channels.");

	dims = mxGetDimensions(prhs[0]); 
	h = dims[0];
	w = dims[1];


	if (!mxIsNumeric(prhs[0]) || !mxIsDouble(prhs[0]))
		mexErrMsgTxt("Normal mat must be double precision");

	
	// Check the struct
	if (!mxIsStruct(prhs[1]))
		mexErrMsgTxt("Second argument must be a struct.");

	// Check that the struct has the correct fields
	// nL field, must be 1 x 1
	mxArray *tmp;
	tmp = mxGetField(prhs[1], 0, "nL");
	if (tmp == NULL)
		mexErrMsgTxt("struct does not have the field: nL");

	m = mxGetM(tmp);
	n = mxGetN(tmp);
	if (!mxIsNumeric(tmp) || m != 1 || n != 1)
		mexErrMsgTxt("nL field has an incorrect size.");
	nL = (int)mxGetScalar(tmp);
	
	
	// linfit
	tmp = mxGetField(prhs[1], 0, "linfit");
	if (tmp == NULL)
		mexErrMsgTxt("struct does not have the field: linfit");

	nX = mxGetM(tmp);
	n = mxGetN(tmp);
	if (!mxIsNumeric(tmp) || !(n == 4*nL || n == 3*nL))
		mexErrMsgTxt("linfit is not the correct size.");

	if (!checkmodelsize(nX))
		mexErrMsgTxt("linfit is not the correct size.");

	// quadfit
	tmp = mxGetField(prhs[1], 0, "quadfit");
	if (tmp == NULL)
		mexErrMsgTxt("struct does not have the field: quadfit");

	nX = mxGetM(tmp);
	n = mxGetN(tmp);
	if (!mxIsNumeric(tmp) || !(n == 11*nL || n == 10*nL))
		mexErrMsgTxt("quadfit is not the correct size.");

	if (!checkmodelsize(nX))
		mexErrMsgTxt("quadfit is not the correct size.");


	// Size field, must be 2 x 1 or 1 x 2
	tmp = mxGetField(prhs[1], 0, "sz");
	if (tmp == NULL)
		mexErrMsgTxt("struct does not have the field: sz");

	m = mxGetM(tmp);
	n = mxGetN(tmp);
	if (!mxIsNumeric(tmp) || std::max(m,n) != 2 || std::min(m,n) != 1)
		mexErrMsgTxt("sz field has an incorrect size.");

	if (!mxIsDouble(tmp))
		mexErrMsgTxt("sz field must be double precision.");

    
	return;
}


/*
 *  
 */
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) 
{ 
	const mwSize *dims;
	mwSize newdim[3] = {0, 0, 3};
	mwSize ndim;
	int i, xdim, ydim, nL, nX, stx;
	mwIndex subs[3];
	mwIndex index;
	mxArray *tmp;
	double xv, yv;

	checkInputs(nlhs, plhs, nrhs, prhs);
	dims = mxGetDimensions(prhs[0]); 

	ydim = dims[0];
	xdim = dims[1];

	newdim[0] = ydim;
	newdim[1] = xdim;

	// Normal pointer
	double *im_p;
	im_p = mxGetPr(prhs[0]);

	tmp = mxGetField(prhs[1], 0, "nL");
	nL = (int)mxGetScalar(tmp);

	// set the output dimension
	newdim[2] = nL;

	// Unpack linfit
	mxArray *linref;
	double *lin_pt;
	linref = mxGetField(prhs[1], 0, "linfit");
	lin_pt = mxGetPr(linref);
	nX = mxGetM(linref);
	int nlinfit = floor(mxGetN(linref)/nL);
	bool donormalized = (nlinfit == 4);
	
	

	// Unpack quadfit
	mxArray *quadref;
	double *quad_pt;
	quadref = mxGetField(prhs[1], 0, "quadfit");
	quad_pt = mxGetPr(quadref);
	int nquadfit = floor(mxGetN(quadref)/nL);
	donormalized = (nquadfit == 11);
	int quadstep = nquadfit;
	if (donormalized)
		quadstep = nquadfit - 1;
	


	// Coordinates for surface fit
    const int ncf = 28;
	double Xmat[ncf];
	Xmat[ncf-1] = 1.0;
    stx = ncf-nX;
	
	
	// surface normal
	double ntemp[3];
	

	// Unpack size
	tmp = mxGetField(prhs[1], 0, "sz");
	double xc, yc, dim;
	double *sz_p;
	sz_p = mxGetPr(tmp);
	yc = (sz_p[0]+1.0)/2.0;
	xc = (sz_p[1]+1.0)/2.0;
	dim = min(sz_p[0], sz_p[1]);

	double dy = 1.0;
	double dx = 1.0;


	// Memory allocation
	double *fvec;
	fvec = (double *)mxCalloc(nL, sizeof(double));
	if (fvec == NULL) {
		mexErrMsgTxt("Cannot allocate memory for temporary vector.");
	}
	
	// Quadratic model matrix
	double *Qmat;
	Qmat = (double *)mxCalloc(quadstep*nL, sizeof(double));
	if (Qmat == NULL) {
        mxFree(fvec);
		mexErrMsgTxt("Cannot allocate memory for temporary vector.");
	}

	// Memory allocation
	plhs[0] = mxCreateNumericArray(3, newdim, mxDOUBLE_CLASS, mxREAL); 
	if (plhs[0] == NULL) {
        mxFree(fvec);
        mxFree(Qmat);
		mexErrMsgTxt("Cannot allocate memory for output.");
	}

	double *outim = mxGetPr(plhs[0]);
	double nm;

	int i1, i2, i3;
	int z1, z2, base, zp;
	//cout << "ydim: " << ydim << ", xdim: " << xdim << endl;

	// Iterate over all pixels
	for (int y = 0; y < ydim; ++y) {
		subs[0] = y;

		// y-coordinate of this pixel
		yv = (y*dy - yc)/dim;

		
		for (int x = 0; x < xdim; ++x) {
			subs[1] = x;

			// x-coordinate of this pixel
			xv = (x*dx - xc)/dim;

			Xmat[ 0] = xv*xv*xv*xv*xv*xv;
			Xmat[ 1] = xv*xv*xv*xv*xv*yv;
			Xmat[ 2] = xv*xv*xv*xv*yv*yv;
			Xmat[ 3] = xv*xv*xv*yv*yv*yv;
			Xmat[ 4] = xv*xv*yv*yv*yv*yv;
			Xmat[ 5] = xv*yv*yv*yv*yv*yv;
			Xmat[ 6] = yv*yv*yv*yv*yv*yv;

			Xmat[ 7] = xv*xv*xv*xv*xv;
			Xmat[ 8] = xv*xv*xv*xv*yv;
			Xmat[ 9] = xv*xv*xv*yv*yv;
			Xmat[10] = xv*xv*yv*yv*yv;
			Xmat[11] = xv*yv*yv*yv*yv;
			Xmat[12] = yv*yv*yv*yv*yv;

			Xmat[13] = xv*xv*xv*xv;
			Xmat[14] = xv*xv*xv*yv;
			Xmat[15] = xv*xv*yv*yv;
			Xmat[16] = xv*yv*yv*yv;
			Xmat[17] = yv*yv*yv*yv;

			Xmat[18] = xv*xv*xv;
			Xmat[19] = xv*xv*yv;
			Xmat[20] = xv*yv*yv;
			Xmat[21] = yv*yv*yv;
			Xmat[22] = xv*xv;
			Xmat[23] = xv*yv;
			Xmat[24] = yv*yv;
			Xmat[25] = xv;
			Xmat[26] = yv;


			// Unpack values and check for dark pixels
			for (int z = 0; z < 3; ++z) {
				subs[2] = z;
				index = mxCalcSingleSubscript(prhs[0], 3, subs);
				ntemp[z] = im_p[index];
			}


			/*** Nonlinear optimization ***/
			// Quadratic shading model
			if (donormalized)
				normalizedlightmatrix(nL, nX, nquadfit, Xmat+stx, quad_pt, Qmat);
			else
				lightmatrix(nL, nX, nquadfit, Xmat+stx, quad_pt, Qmat);


			// Jacobian is 2*N^T * A + b^T
			// Coefficients of A are the 0-5 of Qmat
			// Coefficients of b are 6-8 of Qmat
			// Coefficient c is 9 of Qmat
			for (int z = 0; z < nL; ++z) {

				int baseix = quadstep*z;
				double a00 = Qmat[baseix + 0];
				double a01 = Qmat[baseix + 1];
				double a02 = Qmat[baseix + 2];
				double a10 = a01;
				double a11 = Qmat[baseix + 3];
				double a12 = Qmat[baseix + 4];
				double a20 = a02;
				double a21 = a12;
				double a22 = Qmat[baseix + 5];

				double b0 = Qmat[baseix + 6];
				double b1 = Qmat[baseix + 7];
				double b2 = Qmat[baseix + 8];

				double cval = Qmat[baseix + 9];
				
				double an0 = a00*ntemp[0] + a01*ntemp[1] + a02*ntemp[2];
				double an1 = a10*ntemp[0] + a11*ntemp[1] + a12*ntemp[2];
				double an2 = a20*ntemp[0] + a21*ntemp[1] + a22*ntemp[2];
				double ntan = ntemp[0]*an0 + ntemp[1]*an1 + ntemp[2]*an2;

				fvec[z] = max(ntan + b0*ntemp[0] + b1*ntemp[1] + b2*ntemp[2] + cval, 0.0 );
			}


			// Save intensity
			for (int z = 0; z < nL; ++z) {
				subs[2] = z;
				index = mxCalcSingleSubscript(plhs[0], 3, subs);

				outim[index] = fvec[z];
			}
		}


	}
	

	// Free memory
	mxFree(fvec);
	mxFree(Qmat);

	return;
} 




