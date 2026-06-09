%TESTGROOVEWIDTH Unit tests for groove edge-to-edge width accuracy.
%
%   These tests verify the bottom (lower-corner) edge-to-edge width of a
%   simulated groove scan using sub-pixel edge detection on the saved
%   heightmap (see GROOVEEDGETOEDGE). They demonstrate that:
%
%     (1) A groove built directly at the calibrated resolution is NOT 0.500 mm
%         wide as intended -- it is quantized by the mm-per-pixel resolution.
%
%     (2) Building the geometry at a finer resolution with anti-aliasing
%         (settings.geommmpp) brings the measured width much closer to the
%         nominal 0.500 mm.
%
%   This test file lives in the tests/ subdirectory; it adds the parent
%   project folder to the path and runs from there so that createscan and the
%   devices/ calibration files resolve.
%
%   Run with:
%      results = runtests('tests/testGrooveWidth')
%
%   The core measurement, grooveEdgeToEdge(scanpath, tset), takes a scan path
%   and a settings struct and can be used independently of this test.
%
classdef testGrooveWidth < matlab.unittest.TestCase

    properties (Constant)
        Calib       = 'series2_2EF6_4JNW';
        NominalWmm  = 0.5;        % Intended bottom width (mm)
        GeomMmpp    = 0.001;      % Fine geometry resolution for the improved scan
    end

    properties
        BaselinePath   % Scan folder built at the calibrated resolution (legacy)
        ImprovedPath   % Scan folder built with high-resolution geometry + AA
        Tset           % Groove settings struct used for both scans
        Mmpp           % Calibrated resolution (mm-per-pixel)
        CreatedDirs = {};
    end

    methods (TestClassSetup)
        function buildScans(tc)
            import matlab.unittest.fixtures.CurrentFolderFixture

            % Run from the project root so createscan, simGroove and the
            % devices/ calibration files are on the path / resolvable.
            rootdir = fileparts(fileparts(mfilename('fullpath')));
            tc.applyFixture(CurrentFolderFixture(rootdir));

            % Default groove settings (depth 0.5, width 0.5, angle 30)
            tc.Tset = createscan(tc.Calib, 'groove');

            pdata    = loadDevice(tc.Calib);
            tc.Mmpp  = pdata.mmpp;

            % (1) Legacy scan: geometry built directly at calibrated mmpp
            baseTset = tc.Tset;
            baseTset.geommmpp = 0;
            [~, base] = createscan(tc.Calib, 'groove', 'TestGrooveBaseline', baseTset);
            tc.BaselinePath = fullfile(rootdir, base);
            tc.CreatedDirs{end+1} = tc.BaselinePath;

            % (2) Improved scan: high-resolution geometry + anti-aliasing
            hiTset = tc.Tset;
            hiTset.geommmpp = tc.GeomMmpp;
            [~, hi] = createscan(tc.Calib, 'groove', 'TestGrooveHiRes', hiTset);
            tc.ImprovedPath = fullfile(rootdir, hi);
            tc.CreatedDirs{end+1} = tc.ImprovedPath;
        end
    end

    methods (TestClassTeardown)
        function cleanup(tc)
            for i = 1:numel(tc.CreatedDirs)
                d = tc.CreatedDirs{i};
                if ~isempty(d) && exist(d, 'dir')
                    rmdir(d, 's');
                end
            end
        end
    end

    methods (Test)

        function detectsQuantizedWidth(tc)
            % The legacy groove is quantized by the mm-per-pixel resolution and
            % is therefore NOT exactly 0.500 mm wide.
            [w, info] = grooveEdgeToEdge(tc.BaselinePath, tc.Tset);

            fprintf('\n[baseline] bottom width = %.4f mm (nominal %.3f, mmpp %.5f)\n', ...
                    w, tc.NominalWmm, tc.Mmpp);

            % Two lower corners must have been found
            tc.verifyNumElements(info.bottomedgespx, 2, ...
                'expected exactly two lower groove corners');

            % Confirm the scan is measurably NOT 0.500 mm wide. The expected
            % quantization error is on the order of one pixel (~0.007 mm).
            err = abs(w - tc.NominalWmm);
            tc.verifyGreaterThan(err, 0.002, ...
                'baseline groove should be measurably off 0.500 mm due to quantization');

            % And the deviation should not exceed roughly one pixel
            tc.verifyLessThan(err, tc.Mmpp, ...
                'quantization error should be within ~1 pixel');
        end

        function highResImprovesWidth(tc)
            % The high-resolution + anti-aliased geometry should measure much
            % closer to the nominal 0.500 mm.
            wHi = grooveEdgeToEdge(tc.ImprovedPath, tc.Tset);
            wLo = grooveEdgeToEdge(tc.BaselinePath, tc.Tset);

            errHi = abs(wHi - tc.NominalWmm);
            errLo = abs(wLo - tc.NominalWmm);

            fprintf('[improved] bottom width = %.4f mm  (err %.4f)\n', wHi, errHi);
            fprintf('[baseline] bottom width = %.4f mm  (err %.4f)\n', wLo, errLo);
            fprintf('error reduced by %.1fx\n', errLo/max(errHi,eps));

            % The high-resolution geometry must be closer to nominal...
            tc.verifyLessThan(errHi, errLo, ...
                'high-resolution geometry should be more accurate than the baseline');

            % ...and within a tight tolerance of the intended width.
            tc.verifyLessThan(errHi, 0.0025, ...
                'high-resolution groove width should be within 0.0025 mm of nominal');
        end

    end
end
