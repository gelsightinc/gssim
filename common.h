#ifndef COMMON_H
#define COMMON_H

#include <algorithm>


bool checkmodelsize(int nx) {
	bool retval = false;
	switch (nx) {
		case 28:
		case 21:
		case 15:
		case 10:
		case 6:
		case 3:
		case 1:
			retval = true;
	}
	return retval;
}



/*
 * Solve for normal assuming spatially-varying illumination
 */
inline void fullmultiply(int nL, int ncf, double *Xmat, 
		double *inv_p, double *sig, double *ntemp) {

	double temp;
	for (int nx = 0; nx < 3; ++nx) {

		temp = 0.0;
		for (int lx = 0; lx < nL; ++lx) {

			// Column of inv_p
			int cl = 3*lx + nx;
			double cf = 0.0;
			for (int xx = 0; xx < ncf; ++xx) {
				cf += Xmat[xx]*inv_p[cl*ncf + xx];
			}

			temp += cf*sig[lx];
		}
		ntemp[nx] = temp;
	}
}

/*
 * Interpolated light matrix
 * size of Lmat:
 *   rows = ncf
 *   cols = 3*nL
 */
inline void normalizedlightmatrix(int nL, int ncf, int nmodel, double *Xmat, double *linfit, double *Lmat) {

	double temp;
	static double MIN_SCALE = 0.001;
	// Iterate over light direction
	for (int lx = 0; lx < nL; ++lx) {

		// Iterate over the component of the light direction vector
		// The last component is the scale factor
		double sc = MIN_SCALE;
		for (int nx = nmodel-1; nx >= 0; --nx) {

			temp = 0.0;

			// Column of linfit
			int cl = nmodel*lx + nx;
			double cf = 0.0;
			for (int xx = 0; xx < ncf; ++xx) {
				cf += Xmat[xx]*linfit[cl*ncf + xx];
			}

			if (nx == nmodel-1) {
				sc = std::max(cf, MIN_SCALE);
			}
			else {
				// Entry of Lmat
				int ix = (nmodel-1)*lx + nx;

				Lmat[ix] = cf*sc;
			}
		}
	}
	
}

/*
 * Interpolated light matrix
 * size of Lmat:
 *   rows = ncf
 *   cols = 3*nL
 */
inline void lightmatrix(int nL, int ncf, int nmodel, double *Xmat, double *linfit, double *Lmat) {

	double temp;
	static double MIN_SCALE = 0.001;
	// Iterate over light direction
	for (int lx = 0; lx < nL; ++lx) {

		// Iterate over the component of the light direction vector
		// The last component is the scale factor
		double sc = MIN_SCALE;
		for (int nx = nmodel-1; nx >= 0; --nx) {

			temp = 0.0;

			// Column of linfit
			int cl = nmodel*lx + nx;
			double cf = 0.0;
			for (int xx = 0; xx < ncf; ++xx) {
				cf += Xmat[xx]*linfit[cl*ncf + xx];
			}

			Lmat[cl] = cf;
		}
	}
}


/*
 * Reflection vector
 */
inline void reflectionvector(int nL, int ncf, double *Xmat, double *rmodel, double *sig, double *rvec) {


    int nmodel = nL-1;
	// Iterate over light direction
	for (int lx = 0; lx < nL; ++lx) {

        double temp = 0.0;
		for (int nx = 0; nx < nmodel; ++nx) {

			int cl = nmodel*lx + nx;
			double cf = 0.0;
			for (int xx = 0; xx < ncf; ++xx) {
				cf += Xmat[xx]*rmodel[cl*ncf + xx];
			}

            if (nx >= lx)
                temp += cf*sig[nx+1];
            else
                temp += cf*sig[nx];

		}
        
        rvec[lx] = temp;
	}
	
}


#endif
