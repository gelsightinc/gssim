%MERGESETTINGS
%
%   SETTINGS = MERGESETTINGS(OLDSETTINGS, NEWSETTINGS) merges settings from
%   struct NEWSETTINGS into struct OLDSETTINGS.
%
function settings = mergesettings(oldsettings, newsettings)

    settings = oldsettings;
    fields = fieldnames(newsettings);

    for i = 1 : numel(fields)
        if isfield(oldsettings, fields{i})
            settings.(fields{i}) = newsettings.(fields{i});
        end
    end

end


