%CREATESCAN Create a scan of a specific type
%
%   CREATESCAN(CALIBFILE, TARGET, OUTPUTDR, SETTINGS) creates a simulated scan of
%   type TARGET using the calibration file CALIBFILE in the devices folder and
%   saves the scan in the folder OUTPUTDR. The settings for the TARGET type as 
%   specified by the struct SETTINGS.  
%
%   SETTINGS = CREATESCAN(CALIBFILE, TARGET) returns the default SETTINGS for the
%   specified TARGET and device DEVTYPE. 
%
function tsettings = createscan(calibfile, target, outputnm, insettings)

    % Load device calibration
    pdata = loadDevice(calibfile);

    if ~exist('insettings','var')
        insettings = defaultSettingsForTarget(target, pdata);
    end

    % Load target
    tsettings = loadTarget(target, pdata, insettings);

    % If we have not specified an output folder
    if nargin < 3
        if nargout == 1 
            % Return default settings
            return;
        else
            error('An output folder must be specified to create a scan');
        end
    end


    % Calibrated resolution in millimeters-per-pixel
    mmpp = pdata.mmpp;

    % Get heightmap for the specified target type
    hm = getHeightmap(target, pdata, tsettings);

    % Compute normal map from heightmap
    nrm = heightmapToNormals(hm, mmpp);

    % Create unique output folder
    outfolder = outputdir(outputnm);


	% Render images from normal map
	out = shadeQuadratic(nrm, pdata);

	% Apply flatfield model if required
	if isfield(pdata,'flatfield')
		% Flatfield correction
		for i = 1 : numel(pdata.flatfield.correction)
			cmap = imresize(pdata.flatfield.correction{i}, pdata.flatfield.size, 'bicubic');
			out(:,:,i) = min(max(out(:,:,i)./cmap,0),1);
		end
	end

	% Save heightmap as TMD 
    hname = 'heightmap.tmd';
	writetmd(hm, mmpp, fullfile(outfolder,hname));

    % Save normals
    nrmname = 'normals.png';
    imwrite(im2uint16( (nrm+1)/2 ), fullfile(outfolder, nrmname));


    % Save images
	for j = 1 : size(out,3)
		imwrite(im2uint8(out(:,:,j)), fullfile(outfolder, sprintf('image%02d.png',j)));
	end


    % Check for yaml suffix
    [pdir,calibname,cext] = fileparts(calibfile);
    calibyaml = calibfile;
    if isempty(cext)
        calibyaml = [calibfile '.yaml'];
    end

	% Create scan file
	savescan(outfolder, mmpp, calibyaml, hname, nrmname);

	% Save calibration to scan folder
	saveCalibration(pdata, fullfile(outfolder,calibyaml));

    fprintf('scan saved as %s\n',outfolder);

end

%
% Load device from calibration file
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

%
% Check target
%
function tsettings = loadTarget(target, pdata, insettings)

    % Load default settings for target
    tsettings = defaultSettingsForTarget(target, pdata);

    tsettings = mergesettings(tsettings, insettings);
    
end




%
% Return the default settings for the specified target type
%
function tsettings = defaultSettingsForTarget(target,pdata)

    % Check for simulation function 
    simfunction = ['sim' upper(target(1)) lower(target(2:end))];

    if exist(simfunction) ~= 2
        error('cannot find simulation function named %s.m',simfunction);
    end

    % Evaluate simulation function with only pdata as input argument
    tsettings = eval(sprintf('%s(pdata);',simfunction));

end



%
% Save the scan file
%
function savescan(scanfolder, mmpp, cname, hname, nrmname)

	% Save scan file
    fd = fopen(fullfile(scanfolder, 'scan.yaml'), 'w');


    fprintf(fd, 'images:\n');
    for i = 1 : 6
        fprintf(fd, '  - image%02d.png\n',i);
    end
    fprintf(fd,'mmperpixel: %.6f\n',mmpp);
    fprintf(fd,'calib: %s\n',cname);
    fprintf(fd,'activeheightmap: %s\n',hname);
    fprintf(fd,'activenormalmap: %s\n',nrmname);

    fclose(fd);

end

%
% Run simulation function to create heightmap
%
function hm = getHeightmap(target, pdata, tsettings)

    simfunction = ['sim' upper(target(1)) lower(target(2:end))];

    if exist(simfunction) ~= 2
        error('cannot find simulation function named %s.m',simfunction);
    end

    
    hm = eval(sprintf('%s(pdata, tsettings);',simfunction));

end

