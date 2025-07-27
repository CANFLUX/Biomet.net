function automatic_metafile_gen(yearIn,siteID,stageNum,exportList,fName)
% automatic_metafile_gen - extract fields from the ini files and create a metafile
%
% automatic_metafile_gen(yearIn,siteID,stageNum,exportList,fName)
%
% Arguments
%
%   yearIn      - the year that requires processing
%   siteID      - site name (like 'DSM')
%   stageNum    - a number (1-2) of the cleaning stage number
%   exportList  - a cell array of the fields that are being exported. 
%                 If a field is missing, replace it with a blank space
%   fName       - file name to export into. If empty, just list it
%                 in the command window.
%
%  Example:
%   yearIn = 2025;
%   siteID = 'DSM';
%   stageNum = 2;
%   fName = fullfile('meta-file.csv');
%   exportList = {'variableName','units','comments','title'};
%   automatic_metafile_gen(yearIn,siteID,stageNum,exportList,fName)
%
% Zoran Nesic               File created:       Jul 26, 2023
%                           Last modification:  Jul 26, 2023

% Revisions
%

    
    trace_str= readIniFileDirect(yearIn,siteID,stageNum);
    
    % save meta file
    if ~isempty(fName)
        fid = fopen(fName,'w');
        if fid < 0
            error('Cannot open file')
        end
        fprintf('Creating metafile %s for the site: %s and the stage: %d. \n',fName,siteID,stageNum)
    else
        fid = 1;
    end

    % cycle through traces
    nTraces = length(trace_str);
    for cntTraces=1:nTraces
        iniInfo           = trace_str(cntTraces).ini;
        fprintf(fid,'%3d',cntTraces);
        for cntFields = 1:length(exportList)
            metaField = extractName(iniInfo,char(exportList(cntFields)));            
            fprintf(fid,',%s',metaField);
        end
        fprintf(fid,'\n');
    end
    if fid >= 3
        fclose(fid);
        fprintf('Done.\n')
    end
    


end

function metaField = extractName(iniInfo,targetName)
    fNames  = fieldnames(iniInfo);
    fInd = find(strcmpi(fNames,targetName));
    if fInd > 0
        metaField = char(iniInfo.(targetName));
    else
        metaField = ' ';
    end
end


