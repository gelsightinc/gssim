%SIMGROOVE Simulate a groove
%
%   settings = SIMGROOVE(DEVICE) returns the default Groove settings for the
%   device specified by the DEVICE. The DEVICE struct must have two fields:
%      sz      The heightmap size in pixels (rows x columns)
%      mmpp    The heightmap resolution in millimeters-per-pixel
%
function outval = simGroove(device, insettings)

    defaults.depthmm     = 0.5;                % Depth of groove in mm
    defaults.orientation = 'horizontal';       % Orientation of groove
    defaults.widthmm     = 0.5;                % Bottom width of groove
    defaults.angle       = 30;                 % Angle of side walls relative to horizontal

    % Return default settings if none are specified
    if nargin == 1
        outval = defaults;
        return;
    end

    % Merge settings
    settings = mergesettings(defaults, insettings);

    % Extract device parameters
    ydim = device.sz(1);
    xdim = device.sz(2);
    mmpp = device.mmpp;


    if strcmp(settings.orientation, 'horizontal')

        % Make a horizontal groove
        profile = makeGrooveProfile(ydim, mmpp, settings);

        hm = repmat(profile(:), [1 xdim]);


    else
        % Make a vertical groove
        profile = makeGrooveProfile(xdim, mmpp, settings);

        hm = repmat(profile(:)', [ydim 1]);
    end

    outval = hm;
end

%
% Make a groove profile
%
function z = makeGrooveProfile(dim, mmpp, settings)

    % Center of groove
    ct = floor((dim+1)/2);

    % Groove bottom in pixels, subtract 2 because side walls start at the depth value
    wdpx = round(settings.widthmm / mmpp) - 2;

    % Depth in pixels
    gdepth = settings.depthmm / mmpp;

    % Side wall width in pixels
    ewpx = round(gdepth / tan(settings.angle/180*pi));

    sidewall = linspace(-gdepth, 0, ewpx);

    % Create groove
    groove = [fliplr(sidewall) -gdepth*ones(1,wdpx)  sidewall];
    % The total groove length

    groovelen = length(groove);

    if groovelen > dim
        error('Invalid parameters, groove is too large for specified image size');
    end

    ghalf = floor(groovelen/2);
    
    z = zeros(1,dim);

    z(ct-ghalf-1 + (1:groovelen)) = groove;

    % Convert to mm
    z = z * mmpp;
end

