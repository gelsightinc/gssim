%PLOTWIDTHERRORVSGEOMRES Measured groove width error vs geometry resolution.
%
%   Sweeps the geometry build resolution (settings.geommmpp) and measures the
%   bottom edge-to-edge width of the resulting groove with sub-pixel edge
%   detection (grooveEdgeToEdge). Produces a plot of |measured - nominal| vs
%   geommmpp and saves it as a PNG.
%
function plotWidthErrorVsGeomRes()

    calib   = 'series2_2EF6_4JNW';
    nominal = 0.5;                       % Intended bottom width (mm)
    geomvec = 0.0085:-0.0005:0.0005;     % Geometry resolutions to sweep
                                         % (>= scan mmpp falls back to original)

    pdata = loadDevice(calib);
    mmpp  = pdata.mmpp;
    tset  = simGroove(pdata);            % default groove settings

    tmpdir = fullfile(tempdir, 'gssim_widthsweep');
    if ~exist(tmpdir, 'dir'); mkdir(tmpdir); end

    err     = zeros(size(geomvec));
    measured = zeros(size(geomvec));
    for k = 1:numel(geomvec)
        s = tset;
        s.geommmpp = geomvec(k);
        hm = simGroove(pdata, s);                  % build heightmap in memory
        writetmd(hm, mmpp, fullfile(tmpdir, 'heightmap.tmd'));
        w = grooveEdgeToEdge(tmpdir, tset);        % measure with detector
        measured(k) = w;
        err(k)      = abs(w - nominal);
        fprintf('geommmpp = %.4f mm  ->  width = %.4f mm  (error %.4f mm)\n', ...
                geomvec(k), w, err(k));
    end

    % Reference: legacy build (geometry at the calibrated resolution)
    s0 = tset; s0.geommmpp = 0;
    hm0 = simGroove(pdata, s0);
    writetmd(hm0, mmpp, fullfile(tmpdir, 'heightmap.tmd'));
    wLegacy   = grooveEdgeToEdge(tmpdir, tset);
    errLegacy = abs(wLegacy - nominal);

    % ---- Plot ----
    fig = figure('Color', 'w', 'Position', [100 100 760 480]);
    try, colordef(fig, 'white'); end %#ok<TRYNC> % force light theme if available
    ax = axes(fig); hold(ax, 'on');
    set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'GridColor', [0.15 0.15 0.15]);
    hline = plot(ax, geomvec*1000, err*1000, '-o', 'LineWidth', 1.8, ...
         'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74]);
    yline(errLegacy*1000, '--', ...
          sprintf('legacy (geommmpp = 0): %.1f \\mum', errLegacy*1000), ...
          'Color', [0.85 0.33 0.10], 'LineWidth', 1.4, ...
          'LabelHorizontalAlignment', 'left');
    xline(mmpp*1000, ':', sprintf('calibrated mmpp = %.1f \\mum', mmpp*1000), ...
          'Color', [0.4 0.4 0.4]);
    grid on;
    set(gca, 'XDir', 'reverse');         % finer resolution to the right
    xlabel('Geometry resolution  geommmpp  (\mum / pixel)');
    ylabel('Measured width error  |w - 0.500|  (\mum)');
    title(sprintf('Groove bottom-width error vs geometry resolution\n(%s, mmpp = %.4f mm, nominal 0.500 mm)', ...
          calib, mmpp), 'Interpreter', 'none', 'Color', 'k');
    set([ax.XLabel ax.YLabel], 'Color', 'k');
    legend(ax, hline, {'high-res + anti-aliasing'}, 'Location', 'northeast', ...
           'TextColor', 'k');

    outpng = fullfile(fileparts(mfilename('fullpath')), 'width_error_vs_geomres.png');
    exportgraphics(fig, outpng, 'Resolution', 150);
    fprintf('\nSaved plot: %s\n', outpng);

    rmdir(tmpdir, 's');
end
