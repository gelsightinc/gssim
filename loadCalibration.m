function pdata = loadIlluminationModel(fpath)

    if ~exist(fpath,'file')
        error('cannot locate scan file: %s',fpath);
    end

    [cfolder,cfile,cext] = fileparts(fpath);
    
    pdata.linfit  = [];
    pdata.quadfit = [];
    pdata.nL      = 6;
    pdata.sz      = [1 1];
    pdata.mmpp    = 0.0;
    pdata.black   = zeros(6,1);
    pdata.white   = ones(6,1);

    fd = fopen(fpath,'r');
    
    line = fgetl(fd);
    while ischar(line)
        % Find key
        colonix = strfind(line,':');
        lastline = [];
        if ~isempty(colonix)
            key = line(1:colonix-1);
            key = strtrim(key);
            
            value = strtrim(line(colonix+1:end));
            if strcmp(key,'nL')
                pdata.nL = str2num(value);
            elseif strcmp(key,'width')
                pdata.sz(2) = str2num(value);
            elseif strcmp(key,'height')
                pdata.sz(1) = str2num(value);
            elseif strcmp(key,'mmperpixel')
                pdata.mmpp = str2num(value);
            elseif strcmp(key,'linfit')
                [M,lastline] = loadmatrix(fd);
                pdata.linfit = M;
            elseif strcmp(key,'quadfit')
                [M,lastline] = loadmatrix(fd);
                pdata.quadfit = M;
            elseif strcmp(key,'black')
                pdata.black = str2num(value);
                pdata.black = pdata.black(:);
            elseif strcmp(key,'white')
                pdata.white = str2num(value);
                pdata.white = pdata.white(:);
            elseif strcmp(key,'flatfield')
                [F,lastline] = loadflatfield(fd, cfolder);
                pdata.flatfield = F;
			end
		end

        if ~isempty(lastline)
            line = lastline;
        else
            line = fgetl(fd);
        end
    end

    % Set model size field depending on number of coefficients 
    msz = (-1 + sqrt(1 + 8*size(pdata.linfit,1)))/2;
    if (msz < 1 || msz > 5)
        error('incorrect spatial complexity');
    end
    pdata.modelsize = msz-1;

end

%
%
%
function [M,lastline] = loadmatrix(fd)
    
	rows = 0;
	cols = 0;
	vals = 0;
    M    = 0;

    line = fgetl(fd);
    lastline = line;
    ix = 0;
    while ischar(line)
        % Find dashes not associated with numbers
        dashes = (line == '-');
        numbers = isstrprop(line,'digit');
        dashix = find(dashes(1:end-1) & ~numbers(2:end));
        colonix = strfind(line,':');
        
        if isempty(colonix)
            line = fgetl(fd);
            continue;
        end
        % Count leading whitespace
        whiteix = min(find(isspace(line) == 0));
        if whiteix == 1
            lastline = line;

            M = reshape(vals, cols, rows)';
            return;
        end
        
        
        if ~isempty(dashix)
            ix = ix + 1;
            key = strtrim(line(dashix+1 : colonix-1));
        else
            key = strtrim(line(1:colonix-1));
        end
        
        value = strtrim(line(colonix+1:end));

        if strcmp(key,'rows')
            rows = str2num(value);
        elseif strcmp(key,'cols')
            cols = str2num(value);
        elseif strcmp(key,'values')
            vals = str2num(value);
        end
        %fprintf('%s : %s\n',key,value);
        
        line = fgetl(fd);
    end

    M = reshape(vals, cols, rows)';
    

end

%
%
%
function [F,lastline] = loadflatfield(fd, cfolder)
    
	fullsz  = [0 0];
	modelsz = [0 0];
    M       = 0;
    modelfile = '';
    midvalues = [];
    nL = 0;

    line = fgetl(fd);
    lastline = line;
    ix = 0;
    while ischar(line)
        % Count leading whitespace
        whiteix = min(find(isspace(line) == 0));
        if whiteix == 1
            lastline = line;
            break;
        end
        
        colonix = strfind(line,':');
        
        if isempty(colonix)
            line = fgetl(fd);
            continue;
        end
        
        key = strtrim(line(1:colonix-1));
        value = strtrim(line(colonix+1:end));

        if strcmp(key,'modelfile')
            modelfile = value;
        elseif strcmp(key,'modelsize')
            % Trim parentheses
            vtrim = strrep(strrep(value,'(',' '),')', ' ');
            modelsz = str2num(vtrim);
        elseif strcmp(key,'size')
            vtrim = strrep(strrep(value,'(',' '),')', ' ');
            fullsz = str2num(vtrim);
        elseif strcmp(key,'nL')
            nL = str2num(value);
        elseif strcmp(key,'scale')
            midvalues = str2num(value);
        elseif strcmp(key,'values')
            vals = str2num(value);
        end
        %fprintf('%s : %s\n',key,value);
        
        line = fgetl(fd);
    end

    % Look for image
    impath = fullfile(cfolder, modelfile);
    if ~exist(impath, 'file')
        error('cannot find flatfield image %s',impath);
    end
    im = im2double(imread(impath));

    % Check image size
    yd = modelsz(2)*2;
    xd = modelsz(1)*3;

    if yd ~= size(im,1) || xd ~= size(im,2)
        error('incorrect flatfield image size');
    end
    

    F.scale     = mean(modelsz./fullsz);
    F.size      = fliplr(fullsz);
    for i = 1 : nL
        rx = floor((i-1)/3)+1;
        cx = mod(i-1,3)+1;
        xst = (cx-1)*modelsz(1);
        yst = (rx-1)*modelsz(2);
        roi = [xst+1 xst+modelsz(1)  yst+1 yst+modelsz(2)];
        F.lowres{i} = max(im(roi(3):roi(4),roi(1):roi(2)), 1/255);
        F.correction{i} = midvalues(i) ./ F.lowres{i};
    end
    F.midvalues = midvalues;

end

