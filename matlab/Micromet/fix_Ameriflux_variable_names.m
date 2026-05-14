function fix_Ameriflux_variable_names(fileName)
% fix_Ameriflux_variable_names(fileName) 
%
% fileName      - file name usually of .ini or .yml type
%
%
% This function fixes the issue with data pipeline ini files that
% had their variables names in the old Ameriflux format. The function
% reads the old ini file "fileName" and replaces all variable names
% formatted as "*_x_y_z_F" (where x, y and z are numbers) to the
% new format: "*_F_x_y_z". It works on *.ini and *.yml files (or any other
% files for that matter). The output is saved in the file with the same name
% with addition of "_fixed" to it; and in the original folder. For that
% reason the program has to have write permission for that location.
%
%
% Zoran Nesic               File created:       May  6, 2026
%                           Last modification:  May 14, 2026
%

%
% Revisions:
%
% May 14, 2026 (Zoran)
%   - added replacing VWC_ with SWC_

    % Read entire file
    fid = fopen(fileName, 'r');
    if fid == -1
        error('Could not open file');
    end
    
    lines = {};
    tline = fgetl(fid);
    
    while ischar(tline)
        lines{end+1} = tline; %#ok<AGROW>
        tline = fgetl(fid);
    end
    
    fclose(fid);

    % Process each line
    for i = 1:length(lines)
        line = lines{i};
        
        % Skip comment lines
        trimmed = strtrim(line);
        if startsWith(trimmed, '%')
            continue;
        end
        
        % Regex pattern:
        % Match: _<num>_<num>_<num>_F
        % Capture the numbers
        pattern = '_(\d+)_(\d+)_(\d+)_F';
        
        % Replace with: _F_<num>_<num>_<num>
        replacement = '_F_$1_$2_$3';
        
        line = regexprep(line, pattern, replacement);

        % Regex pattern:
        % Match: VWC_ and replace with SWC_
        % Capture the numbers
        pattern = 'VWC_';
        replacement = 'SWC_';       
        line = regexprep(line, pattern, replacement);

        lines{i} = line; %#ok<AGROW>
    end

    % Build new filename
    [path, name, ext] = fileparts(fileName);
    newFileName = fullfile(path, [name '_fixed' ext]);

    % Write output file
    fid = fopen(newFileName, 'w');
    if fid == -1
        error('Could not create output file');
    end
    
    for i = 1:length(lines)
        fprintf(fid, '%s\n', lines{i});
    end
    
    fclose(fid);

    fprintf('Processed file saved as: %s\n', newFileName);

end