%SAVECALIBRATION Load a calibration from a yaml and png file
%
%   SAVECALIBRATION(CDATA, CNAME) saves a calibration struct CDATA into 
%   yaml and png files with base name CNAME.
%   
function saveCalibration(pdata, fname)
    fov = 5.0;
    angbias = 0.03;
    savecamera = true;

    fd = fopen(fname, 'w');

    fprintf(fd, 'nL: %d\n', pdata.nL);
    fprintf(fd, 'width: %d\n', pdata.sz(2) );
    fprintf(fd, 'height: %d\n', pdata.sz(1) );
    fprintf(fd, 'mmperpixel: %.15f\n',pdata.mmpp );
    fprintf(fd, 'magnification: 0\n');
    fprintf(fd, 'darkthresh: 1\n');
    fprintf(fd, 'lightthresh: 1\n');
    fprintf(fd, 'black: [');
    fprintf(fd, '%.6f, ',pdata.black(1:end-1));
    fprintf(fd, '%.6f]\n',pdata.black(end));
    fprintf(fd, 'white: [');
    fprintf(fd, '%.6f, ',pdata.white(1:end-1));
    fprintf(fd, '%.6f]\n',pdata.white(end));

    % Parameters block
    fprintf(fd,'parameters:\n');
    fprintf(fd,'    datafactor: 5000\n');
    if isfield(pdata,'fov')
        fov = pdata.fov;
    end
    if isfield(pdata,'angbias')
        angbias = pdata.angbias;
    end
    fprintf(fd,'    fov:      : %.5f\n',fov);
    fprintf(fd,'    modelsize : %d\n',pdata.modelsize);
    fprintf(fd,'    radiusbias: %.5f\n',angbias);
    fprintf(fd,'    version: 2014\n');

    fprintf(fd,'linfit:\n');
    printmatrix(fd, pdata.linfit);

    fprintf(fd,'quadfit:\n');
    printmatrix(fd, pdata.quadfit);

    if isfield(pdata,'flatfield')
        [pdir,fbase,fext] = fileparts(fname);
        sz = size(pdata.flatfield.lowres{1});
        sc = pdata.flatfield.midvalues;
        fprintf(fd,'flatfield:\n');
        fprintf(fd,'    modelfile: %s.png\n',fbase);
        fprintf(fd,'    modelsize: %d, %d\n',sz(2),sz(1));
        fprintf(fd,'    nL: %d\n',numel(pdata.flatfield.lowres));
        fprintf(fd,'    scale: [');
        fprintf(fd,'%.8f,',sc(1:end-1));
        fprintf(fd,'%.8f]\n',sc(end));
        fprintf(fd,'    size: %d, %d\n',pdata.sz(2),pdata.sz(1));

        % Save png
        fullpng1 = cat(2, pdata.flatfield.lowres{1:3});
        fullpng2 = cat(2, pdata.flatfield.lowres{4:6});
        imwrite(im2uint16(cat(1, fullpng1, fullpng2)), fullfile(pdir,[fbase '.png']));
    end
    if savecamera
        fprintf(fd,'camera: \n');
        fprintf(fd,'    cameraid: CIMAF2108007\n');
        fprintf(fd,'    cameratype: Ximea\n');
        fprintf(fd,'    gelid: 2ACX-4HNN\n');
        fprintf(fd,'    gelusecount: 18\n');
        fprintf(fd,'    lensfocuspos: -470.76\n');
        fprintf(fd,'    shutter: 2.260\n');
		fprintf(fd,'device: \n');
		fprintf(fd,'    calibname: calibration_series2\n');
		fprintf(fd,'    devicetemp: 40.8125\n');
		fprintf(fd,'    devicetype: 0.5X 5 MP\n');
		fprintf(fd,'    version: 2\n');
    end

    fclose(fd);


end

%
%
%
function printmatrix(fd, M)

    fprintf(fd, '    rows: %d\n',size(M,1));
    fprintf(fd, '    cols: %d\n',size(M,2));
    fprintf(fd, '    values: [');
   
    % Print row-wise
    Mt = M';
    fprintf(fd, '%.15f, ',Mt(1:end-1));
    fprintf(fd, '%.15f]\n',Mt(end));
end
