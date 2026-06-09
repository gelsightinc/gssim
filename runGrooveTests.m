%RUNGROOVETESTS Run the gssim groove width unit tests.
%
%   RUNGROOVETESTS() runs tests/testGrooveWidth from anywhere, without needing
%   to remember the path or .m extension. Returns the TestResult array.
%
%   Example:
%      runGrooveTests
%
function results = runGrooveTests()
    here    = fileparts(mfilename('fullpath'));
    testfile = fullfile(here, 'tests', 'testGrooveWidth.m');
    results = runtests(testfile);
end
