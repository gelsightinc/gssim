%PLOTWIDTHERRORVSGEOMRES Measured groove width error vs geometry resolution.
%
%   Sweeps the geometry build resolution (geommpp) and measures the bottom
%   edge-to-edge width of the resulting groove with sub-pixel edge detection
%   (grooveEdgeToEdge). Produces a plot of |measured - nominal| vs geommpp and
%   saves it as a PNG.
%
%   This script reproduces the ORIGINAL groove construction
%   (wdpx = round(widthmm/mmpp) - 2) so the figure stays consistent with the
%   first GSSim journal entry. It builds the geometry itself (mirroring
%   simGroove's anti-aliasing + resample path with off = 2) rather than calling
%   simGroove, which has since been changed to the corrected off = 1. See
%   plotWidthErrorOrigVsFix.m for the original-vs-fixed comparison.
%
function plotWidthErrorVsGeomRes()

    calib   = 'series2_2EF6_4JNW';
    nominal = 0.5;                       % Intended bottom width (mm)
    geomvec = 0.0085:-0.0005:0.0005;     % Geometry resolutions to sweep
    off     = 2;                         % Original (pre-fix) bottom-width offset

    pdata = loadDevice(calib);
    mmpp  = pdata.mmpp;
    tset  = simGroove(pdata);
    tset.widthmm = nominal;

    tmpdir = fullfile(tempdir, 'gssim_widthsweep');
    if ~exist(tmpdir, 'dir'); mkdir(tmpdir); end

    err = zeros(size(geomvec));
    for k = 1:numel(geomvec)
        w = measure(pdata, tset, geomvec(k), off, tmpdir);
        err(k) = abs(w - nominal);
        fprintf('geommpp = %.4f mm  ->  width = %.4f mm  (error %.4f mm)\n', ...
                geomvec(k), w, err(k));
    end

    % Reference: legacy build (geometry at the calibrated resolution)
    wLegacy   = measure(pdata, tset, 0, off, tmpdir);
    errLegacy = abs(wLegacy - nominal);

    % ---- Plot ----
    fig = figure('Color', 'w', 'Position', [100 100 760 480]);
    try, colordef(fig, 'white'); end %#ok<TRYNC> % force light theme if available
    ax = axes(fig); hold(ax, 'on');
    set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'GridColor', [0.15 0.15 0.15]);
    hline = plot(ax, geomvec*1000, err*1000, '-o', 'LineWidth', 1.8, ...
         'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74]);
    yline(errLegacy*1000, '--', ...
          sprintf('legacy (geommpp = 0): %.1f \\mum', errLegacy*1000), ...
          'Color', [0.85 0.33 0.10], 'LineWidth', 1.4, ...
          'LabelHorizontalAlignment', 'left', 'Color', [0.85 0.33 0.10]);
    xline(mmpp*1000, ':', sprintf('calibrated mmpp = %.1f \\mum', mmpp*1000), ...
          'Color', [0.4 0.4 0.4]);
    grid on;
    set(ax, 'XDir', 'reverse');          % finer resolution to the right
    xlabel('Geometry resolution  geommpp  (\mum / pixel)');
    ylabel('Measured width error  |w - 0.500|  (\mum)');
    title(sprintf('Groove bottom-width error vs geometry resolution\n(%s, mmpp = %.4f mm, nominal 0.500 mm)', ...
          calib, mmpp), 'Interpreter', 'none', 'Color', 'k');
    set([ax.XLabel ax.YLabel], 'Color', 'k');
    legend(ax, hline, {'high-res + anti-aliasing'}, 'Location', 'northeast', ...
           'TextColor', 'k', 'Color', 'w', 'EdgeColor', [0.6 0.6 0.6]);

    outpng = fullfile(fileparts(mfilename('fullpath')), 'width_error_vs_geomres.png');
    exportgraphics(fig, outpng, 'Resolution', 150);
    fprintf('\nSaved plot: %s\n', outpng);

    rmdir(tmpdir, 's');
end

function w = measure(pdata, tset, geommpp, off, tmpdir)
    mmpp = pdata.mmpp;
    dim  = pdata.sz(1);
    prof = makeProfile(dim, mmpp, tset, geommpp, off);
    hm   = repmat(prof(:), [1 20]);
    writetmd(hm, mmpp, fullfile(tmpdir, 'heightmap.tmd'));
    w = grooveEdgeToEdge(tmpdir, tset);
end

% Mirror of simGroove.makeGrooveProfile, parameterized by the bottom-width
% offset (off = 2 original construction).
function z = makeProfile(dim, mmpp, settings, geommpp, off)
    MINRATIO = 1.5;
    aasigma  = 0.5;
    if geommpp <= 0 || (mmpp/geommpp) < MINRATIO
        z = rawGroove(dim, mmpp, settings, off);
        return;
    end
    dim_hi  = round(dim * mmpp / geommpp);
    prof_hi = rawGroove(dim_hi, geommpp, settings, off);
    sigma_hi = aasigma * (mmpp/geommpp);
    rad = ceil(4*sigma_hi); xk = -rad:rad;
    gk = exp(-xk.^2/(2*sigma_hi^2)); gk = gk/sum(gk);
    pad = [repmat(prof_hi(1),1,rad), prof_hi(:)', repmat(prof_hi(end),1,rad)];
    prof_hib = conv(pad, gk, 'valid');
    cthi = floor((dim_hi+1)/2); ctcal = floor((dim+1)/2);
    x_hi = ((1:dim_hi)-cthi)*geommpp; x_cal = ((1:dim)-ctcal)*mmpp;
    z = interp1(x_hi, prof_hib, x_cal, 'linear', 0); z = z(:)';
end

function z = rawGroove(dim, mmpp, s, off)
    ct = floor((dim+1)/2);
    wdpx = round(s.widthmm/mmpp) - off;
    gdepth = s.depthmm/mmpp;
    ewpx = round(gdepth/tan(s.angle/180*pi));
    sidewall = linspace(-gdepth, 0, ewpx);
    groove = [fliplr(sidewall) -gdepth*ones(1,wdpx) sidewall];
    ghalf = floor(length(groove)/2);
    z = zeros(1,dim); z(ct-ghalf-1+(1:length(groove))) = groove; z = z*mmpp;
end
