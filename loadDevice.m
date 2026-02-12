%LOADDEVICE Load device from calibration file
%
%   CDATA = LOADDEVICE(CALIBFILE) Loads the calibration file CALIBFILE from the devices folder
%
%
function [pdata,cpath] = loadDevice(calibfile)

    % Check for calibration file
    [pdir,filenm,fext] = fileparts(calibfile);
    if isempty(fext)
        % Add yaml extension if necessary
        calibfile = [calibfile '.yaml'];
    end

    % Look in devices folder if only file name is specified
    if isempty(pdir)
        cpath = fullfile('devices',calibfile);
    else
        cpath = calibfile;
    end

    if ~exist(cpath, 'file')
        error('cannot find calibration file %s in the devices folder',calibfile)
    end

    % Load the illumination model
    pdata = loadCalibration(cpath);

end
