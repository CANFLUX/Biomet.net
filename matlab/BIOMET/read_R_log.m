function read_R_log(fid)

countLines = 1;

try
    % Set some locally used variables
    tm_line=fgetl(fid);
    while ischar(tm_line)
        tm_line = strtrim(tm_line);             % remove leading and trailing whitespace chars
        tm_line = regexprep(tm_line,'\[1\] "','');
        temp = find(tm_line~=32 & tm_line~=9);  %skip white space outside [TRACE]->[END] blocks
        if isempty(temp) | strcmp(tm_line(temp(1)),'%')
            % if tm_line is empty or a comment line, do nothing
        elseif strncmp(tm_line,'<P2M>',5)
            % Extract string between '<P2M>' ... '</P2M>'

            start_pos = strfind(tm_line,'<P2M>') + 5;
            end_pos = strfind(tm_line,'</P2M>') - 1;
            
            if ~isempty(start_pos) & ~isempty(end_pos)
                fprintf(2,char([tm_line(start_pos:end_pos) '\n']))
            end
        end
        tm_line = fgetl(fid);		%get next line of ini_file
        countLines = countLines + 1;
    end
catch ME
    disp('')
    rethrow(ME);
end