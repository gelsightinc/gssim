%OUTPUTDIR Make a new output folder with a unique name
%   
%   FOLDERNM = OUTPUTDIR(BASE) makes a new output folder in the current folder
%   using the base name BASE. If a folder named BASE already exists, start with
%   the name BASE-002 and increment the counter until a unique folder name is
%   found. The function returns an error after the folder name BASE-999 is
%   checked.
%
%   FOLDERNM = OUTPUTDIR(PARENTDIR, BASE) makes a new output folder as a
%   subfolder of PARENTDIR following the same naming convention as above.
%
function name = outputdir(arg1, arg2)

	dr = '.';
	switch nargin
		case 0
			base = 'out';
		case 1
			base = arg1;
		case 2
			dr = arg1;
			base = arg2;
		otherwise
			error('unrecognized input arguments');
	end

    % If the name has not been used, make the folder and return it
    if ~exist(fullfile(dr,base),'dir')
        mkdir(fullfile(dr,base));
        name = base;
        return;
    end

	i = 2;
	name = sprintf('%s-%03d',base,i);
	while exist(fullfile(dr,name),'dir') && i < 1000
		i = i + 1;
		name = sprintf('%s-%03d',base,i);
	end
    if i >= 1000
        error('cannot create a new output folder');
    end

	mkdir(fullfile(dr,name));
end

