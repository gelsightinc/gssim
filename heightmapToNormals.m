%HEIGHTMAPTONORMALS
%
%   NRM = HEIGHTMAPTONORMALS(HM, MMPP) converts the heightmap HM to a normal map
%   NRM using the resolution MMPP in millimeters-per-pixel. The normal map NRM 
%   is a NUMROWS x NUMCOLS x 3 matrix where each pixel encodes a unit-length surface
%   normal Nx, Ny, Nz with values between -1.0 and 1.0. 
%
function nrm = heightmapToNormals(hm, mmpp)
 
    % Convert heightmap from mm to pixels
	hmpx = hm / mmpp;

	[gx,gy] = gradient(hmpx);

	nm = sqrt(gx.^2 + gy.^2 + 1);

	dx = -gx./nm;
	dy = -gy./nm;
	dz =   1./nm;
	nrm = cat(3, dx, dy, dz);

end


