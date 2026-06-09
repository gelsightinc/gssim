%GROOVEEDGETOEDGE Measure the edge-to-edge width of a simulated groove scan.
%
%   W = GROOVEEDGETOEDGE(SCANPATH, TSET) loads the heightmap saved in the scan
%   folder SCANPATH and measures the bottom edge-to-edge width (in mm) of the
%   groove described by the settings struct TSET. The width is the distance
%   between the two lower corners of the trapezoidal groove (where the sloping
%   side walls meet the flat bottom) -- the feature whose nominal value is
%   TSET.widthmm.
%
%   Because the saved scan contains only a sampled heightmap (no analytic
%   geometry), the corners are located with sub-pixel accuracy using the
%   second derivative of a Gaussian (a 1-D Laplacian-of-Gaussian). The slope
%   of the height profile is piecewise constant, so each corner appears as an
%   extremum in the second-derivative response; the two lower corners are the
%   positive extrema. Each extremum is refined to sub-pixel position with a
%   parabolic fit.
%
%   [W, INFO] = GROOVEEDGETOEDGE(...) also returns a struct INFO with fields:
%      bottomwidthmm  Bottom (lower-corner) edge-to-edge width in mm
%      topwidthmm     Top opening (upper-corner) edge-to-edge width in mm
%      bottomedgespx  Sub-pixel positions of the two lower corners
%      topedgespx     Sub-pixel positions of the two upper corners
%      profile        The 1-D height cross-section used (mm)
%      mmpp           Resolution of the heightmap (mm-per-pixel)
%
%   [...] = GROOVEEDGETOEDGE(..., 'sigma', S) sets the Gaussian smoothing scale
%   in pixels (default 2.0).
%
%   Example:
%      tset = createscan('series2_2EF6_4JNW','groove');
%      createscan('series2_2EF6_4JNW','groove','Scan',tset);
%      w = grooveEdgeToEdge('Scan-001', tset)
%
%   See also SIMGROOVE, CREATESCAN.
%
function [w, info] = grooveEdgeToEdge(scanpath, tset, varargin)

    p = inputParser;
    addParameter(p, 'sigma', 2.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'filenm', 'heightmap.tmd', @(x) ischar(x) || isstring(x));
    parse(p, varargin{:});
    sigma  = p.Results.sigma;
    filenm = char(p.Results.filenm);

    % Locate and read the heightmap
    hmpath = fullfile(scanpath, filenm);
    if ~exist(hmpath, 'file')
        error('grooveEdgeToEdge:noHeightmap', 'cannot find heightmap %s', hmpath);
    end
    [hm, data] = readtmd(hmpath);
    mmpp = data.mmpp;

    % Extract a 1-D cross-section perpendicular to the groove.
    orientation = 'horizontal';
    if isfield(tset, 'orientation')
        orientation = tset.orientation;
    end
    if strcmp(orientation, 'horizontal')
        % Groove runs across columns; profile varies down the rows
        prof = hm(:, round(size(hm,2)/2));
    else
        % Vertical groove; profile varies across the columns
        prof = hm(round(size(hm,1)/2), :);
    end
    prof = prof(:)';

    % Sub-pixel corner detection
    [posEdges, negEdges] = detectGrooveCorners(prof, sigma);

    if numel(posEdges) < 2
        error('grooveEdgeToEdge:noBottomEdges', ...
              'could not localize the two lower groove corners');
    end

    bottomedges = sort(posEdges(1:2));
    bottomwidth = (bottomedges(2) - bottomedges(1)) * mmpp;

    topwidth    = NaN;
    topedges    = [NaN NaN];
    if numel(negEdges) >= 2
        topedges = sort(negEdges(1:2));
        topwidth = (topedges(2) - topedges(1)) * mmpp;
    end

    w = bottomwidth;

    info = struct();
    info.bottomwidthmm = bottomwidth;
    info.topwidthmm    = topwidth;
    info.bottomedgespx = bottomedges;
    info.topedgespx    = topedges;
    info.profile       = prof;
    info.mmpp          = mmpp;
end

%
% Locate the groove corners using the second derivative of a Gaussian.
% Returns the sub-pixel positions of the positive extrema (lower corners,
% where the walls meet the flat bottom) and negative extrema (upper corners,
% where the flat surface meets the walls). Positions are returned strongest
% first.
%
function [posEdges, negEdges] = detectGrooveCorners(prof, sigma)

    prof = prof(:)';

    % Second-derivative-of-Gaussian kernel (1-D LoG)
    rad = ceil(4*sigma);
    x   = -rad:rad;
    g   = exp(-x.^2 / (2*sigma^2));
    g   = g / sum(g);
    gpp = (x.^2 - sigma^2) / sigma^4 .* g;   % d2/dx2 of Gaussian
    gpp = gpp - mean(gpp);                   % remove DC so flat regions -> 0

    resp = conv(prof, gpp, 'same');

    posEdges = refineExtrema(resp,  1);
    negEdges = refineExtrema(resp, -1);
end

%
% Find local extrema of RESP in the requested direction (+1 maxima, -1 minima),
% reject weak responses, and refine each to sub-pixel position with a parabolic
% fit. Returns positions sorted by descending response magnitude.
%
function pos = refineExtrema(resp, sgn)

    s = sgn * resp;
    n = numel(s);

    isext = false(1, n);
    isext(2:end-1) = s(2:end-1) > s(1:end-2) & s(2:end-1) > s(3:end);
    idx = find(isext);

    if isempty(idx)
        pos = [];
        return;
    end

    % Reject weak extrema (keep those above 20% of the strongest)
    thresh = 0.2 * max(s(idx));
    idx = idx(s(idx) >= thresh);

    pos = zeros(1, numel(idx));
    for k = 1:numel(idx)
        i  = idx(k);
        a  = s(i-1);
        b  = s(i);
        c  = s(i+1);
        den = a - 2*b + c;
        if den == 0
            pos(k) = i;
        else
            pos(k) = i + 0.5*(a - c) / den;
        end
    end

    % Sort strongest first
    [~, ord] = sort(s(idx), 'descend');
    pos = pos(ord);
end
