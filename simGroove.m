%SIMGROOVE Simulate a groove
%
%   settings = SIMGROOVE(DEVICE) returns the default Groove settings for the
%   device specified by the DEVICE. The DEVICE struct must have two fields:
%      sz      The heightmap size in pixels (rows x columns)
%      mmpp    The heightmap resolution in millimeters-per-pixel
%
%   The settings struct has the following fields:
%      depthmm      Depth of the groove in mm
%      orientation  'horizontal' or 'vertical'
%      widthmm      Bottom width of the groove in mm
%      angle        Angle of the side walls relative to horizontal (degrees)
%      geommpp     Geometry resolution in mm-per-pixel used to build the
%                   groove before it is resampled at the calibrated mmpp.
%                   When 0 (the default) the groove is built directly at the
%                   calibrated resolution (legacy behavior). The fine-grid
%                   path is only used when geommpp oversamples the calibrated
%                   mmpp by at least MINRATIO (1.5x, i.e. mmpp/geommpp >= 1.5);
%                   when geommpp is only marginally finer, the oversampling is
%                   too small to help and the original method is used instead.
%                   When engaged (e.g. geommpp = 0.001) the profile is
%                   constructed on the fine grid, anti-alias filtered with a
%                   Gaussian, then interpolated onto the calibrated grid,
%                   which greatly reduces the quantization error in the
%                   feature widths.
%      aasigma      Standard deviation of the anti-aliasing Gaussian, in
%                   units of calibrated pixels (default 0.5). Only used when
%                   geommpp is enabled.
%
function outval = simGroove(device, insettings)

    defaults.depthmm     = 0.5;                % Depth of groove in mm
    defaults.orientation = 'horizontal';       % Orientation of groove
    defaults.widthmm     = 0.5;                % Bottom width of groove
    defaults.angle       = 30;                 % Angle of side walls relative to horizontal
    defaults.geommpp    = 0;                  % Geometry build resolution (0 = use calibrated mmpp)
    defaults.aasigma     = 0.5;                % Anti-aliasing Gaussian sigma, in calibrated pixels

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
% Make a groove profile.
%
% When settings.geommpp is enabled and finer than the calibrated mmpp, the
% groove is built on a fine grid, anti-alias filtered, and resampled onto the
% calibrated grid. Otherwise the groove is built directly at mmpp (legacy).
%
function z = makeGrooveProfile(dim, mmpp, settings)

    geommpp = 0;
    if isfield(settings,'geommpp')
        geommpp = settings.geommpp;
    end

    % Only use the fine-grid path when geommpp oversamples the calibrated
    % resolution by at least this ratio. When the ratio is too close to 1 the
    % anti-aliasing has too little to work with and the fine grid can actually
    % be less accurate than the calibrated grid, so we fall back to the
    % original method.
    MINRATIO = 1.5;
    if geommpp <= 0 || (mmpp / geommpp) < MINRATIO
        z = rawGrooveProfile(dim, mmpp, settings);
        return;
    end

    % --- High-resolution geometry path ---

    % Number of fine-grid samples spanning the same physical extent
    dim_hi = round(dim * mmpp / geommpp);

    % Build the groove at the fine geometry resolution
    prof_hi = rawGrooveProfile(dim_hi, geommpp, settings);

    % Anti-aliasing Gaussian (sigma in fine-grid pixels) applied before
    % resampling down to the calibrated grid.
    aasigma = 0.5;
    if isfield(settings,'aasigma')
        aasigma = settings.aasigma;
    end
    sigma_hi = aasigma * (mmpp / geommpp);

    rad = ceil(4 * sigma_hi);
    xk  = -rad:rad;
    gk  = exp(-xk.^2 / (2*sigma_hi^2));
    gk  = gk / sum(gk);

    % Replicate-pad the ends so the flat regions are preserved by the filter
    pad      = [repmat(prof_hi(1),1,rad), prof_hi(:)', repmat(prof_hi(end),1,rad)];
    prof_hib = conv(pad, gk, 'valid');

    % Resample onto the calibrated grid, keeping the groove centered. Positions
    % are measured relative to the center sample of each grid so that the groove
    % center coincides on both grids.
    cthi  = floor((dim_hi + 1)/2);
    ctcal = floor((dim + 1)/2);
    x_hi  = ((1:dim_hi) - cthi)  * geommpp;
    x_cal = ((1:dim)    - ctcal) * mmpp;

    z = interp1(x_hi, prof_hib, x_cal, 'linear', 0);
    z = z(:)';
end

%
% Build the raw (quantized) groove profile at a given resolution.
% This is the original groove construction.
%
function z = rawGrooveProfile(dim, mmpp, settings)

    % Center of groove
    ct = floor((dim+1)/2);

    % Groove bottom in pixels. The flat bottom is a plateau whose two ends are
    % the side-wall start points (both at -gdepth), so it holds wdpx+2 samples
    % and spans (wdpx+1) intervals. For an edge-to-edge bottom width of widthmm
    % we need wdpx+1 = widthmm/mmpp, hence the -1 (subtracting 2 made the bottom
    % one pixel too narrow).
    wdpx = round(settings.widthmm / mmpp) - 1;

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
