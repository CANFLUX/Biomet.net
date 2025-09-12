function foldersToClean = db_find_folders_to_clean(yearIn,siteID,stageNum,use_yaml)
% find all Clean folders that are used for this site and at this stage
%
% db_find_folders_to_clean(yearIn,siteID,stageNum)
%
%
% Zoran Nesic           File created:       Jan 25, 2023
%                       Last modification:  Feb  3, 2023

%
% Revisions
%
% Feb 3, 2023 (Zoran)
%   - added the last line: foldersToClean = unique(foldersToClean);
%     to avoid issues with measurementType varibles. See the comments in
%     the code.
% Jan 26, 2023 (Zoran)
%   - initialized variable foldersToClean{}

arg_default('use_yaml',false)

trace_str = readIniFileDirect(yearIn,siteID,stageNum,use_yaml);
nAll = length(trace_str);
names1{nAll}={};
for cnt=1:nAll
    names1{cnt} = trace_str(cnt).ini.measurementType;
end
foldersToCleanTmp = unique(names1);
nClean = length(foldersToCleanTmp);
foldersToClean{nClean} = {}; 
% Clean the folder names and replace the abbreviation with full names
for cnt=1:nClean
    newName = foldersToCleanTmp{cnt};
    % check if the name is an abbreviation
    tmp = biomet_path(yearIn,siteID,newName);
    tmpName = tmp(length(biomet_path(yearIn,siteID))+1:end-1);
    % if tmpName == newName it's not an abbreviation. 
    if strcmpi(newName,tmpName)
        % this is the actual folder name. Make sure that the first latter
        % is in CAPS and add 'Clean' after it
        newName(1) = upper(newName(1));
        newName = fullfile(newName,'Clean');
    else
        % otherwise, use the full name.
        newName = tmpName;
        % in the case that the full name is 'Clean\ThirdStage'
        % then replace it with 'Clean\SecondStage' if needed
        if strcmp(newName,'Clean\ThirdStage')
            if stageNum==2
                newName = 'Clean\SecondStage';
            end
        else
            % newName is just a folder under database/yyyy/siteID/newName
            % so the folder to clean is database/yyyy/siteID/newName/Clean
            newName = fullfile(newName,'Clean');
        end
    end
    % at this point newName contains a folder that needs to be emptied
    foldersToClean{cnt} = fullfile(num2str(yearIn),siteID,newName);
    %fprintf('Folder to empty: %s\n',foldersToClean{cnt});
end
% Make sure that all the folder names are unique.
% That may not be the case if ini file contains 
% measurementType ='met' and measurementType ='Met'
% or similar
foldersToClean = unique(foldersToClean);

