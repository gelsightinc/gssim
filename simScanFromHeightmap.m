%SIMSCANFROMHEIGHTMAP Simulate a scan from an existing heightmap
%
%   settings = SIMSCANFROMHEIGHTMAP(DEVICE) returns the default Groove settings for the
%   device specified by the DEVICE. The DEVICE struct must have two fields:
%      sz      The heightmap size in pixels (rows x columns)
%      mmpp    The heightmap resolution in millimeters-per-pixel
%
function outval = simScanFromHeightmap(device, insettings)

    defaults.scandr = '';   % Path to scan folder
    defaults.filenm = '';   % Heightmap name

    % Return default settings if none are specified
    if nargin == 1
        outval = defaults;
        return;
    end

    % Merge settings
    settings = mergesettings(defaults, insettings);


    [pdir,filenm,fext] = fileparts(settings.filenm);
    if ~strcmp(fext,'.tmd')
        fext = '.tmd';
    end

    fullpath = fullfile(settings.scandr,[filenm fext]);
    if ~exist(fullpath,'file')
        error('cannot load tmd file %s',fullpath);
    end

    [hm,dt] = readtmd(fullpath);


    outval = hm;
end

