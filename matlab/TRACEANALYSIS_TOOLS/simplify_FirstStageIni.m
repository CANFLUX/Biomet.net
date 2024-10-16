function result = simplify_FirstStageIni(iniFileName)
% simplify_FirstStageIni - Remove obsolete properties and such
%
%
% Zoran Nesic           File created:       Sep 14, 2024
%                       Last modification:  Oct  2, 2024

% 
% Revisions
%
% Oct 2, 2024 (Zoran)
%  - Bug fix: originalVariable was spelled OriginalVariable

if ~exist(iniFileName,'file')
    fprintf(2,'File %s does not exist!\n',iniFileName);
    return
end

linesRead = 0;
linesSaved = 0;
fidIn = fopen(iniFileName,'r');
if fidIn > 0
    fidOut = fopen([iniFileName '.new'],"w");
    insideTrace = false;
    if fidOut > 0
        while ~feof(fidIn)
            oneLine = fgets(fidIn);
            linesRead = linesRead + 1;
            if startsWith(strtrim(oneLine),'[Trace]')
                insideTrace = true;
            elseif startsWith(strtrim(oneLine),'[End]')         
                insideTrace = false;
            end
            if insideTrace
                if ~(startsWith(strtrim(oneLine),'originalVariable') ...
                        || startsWith(strtrim(oneLine),'calibrationDates') ...
                        || startsWith(strtrim(oneLine),'tags') ...
                        || isempty(strtrim(oneLine)))
                    % If inside of the [Trace]...[end] and none of the
                    % conditions is true, then save the line. Otherwise
                    % ignore the line
                    fprintf(fidOut,'%s',oneLine);
                    linesSaved = linesSaved + 1;
                end
            else
                % if outside of the [Trace]...[End] just copy the line
                fprintf(fidOut,'%s',oneLine);
                linesSaved = linesSaved + 1;       
            end
        end
    end
end
fclose(fidIn);
fclose(fidOut);
fprintf('Read: %d lines. Saved %d lines.\n',linesRead,linesSaved);



                

