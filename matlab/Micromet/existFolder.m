function result = existFolder(folderIn,flagCreate)
% result = existFolder(folderIn,flagCreate)
%
% Check if a folder exists. If it doesn't and flagCreate==true, then create all the missing folders.
% 
% Inputs:
%       folderIn        - full path to a folder
%       flagCreate      - if false (default) just return the status, if true then create the path.
% Outputs:
%       result          - true if the folder exists/has been created (flagCreate==true), false otherwise
%
%
% (c) Zoran Nesic                               File created:      Aug 13, 2025
%                                               Last modification: Aug 13, 2025
%

% Revisions:
%

arg_default('flagCreate',false)
result = false;

folderIn = fullfile(folderIn,filesep);
curFolderName = [];

if ~exist(folderIn,"dir")
    if flagCreate
        try
            allFolders = split(fileparts(folderIn),filesep);
            st = 1;
            if strfind(allFolders{st},':')
                curFolderName = fullfile(char(allFolders{st}),filesep);
                st = 2;        
            end           
            for cntFolders = st:length(allFolders)
                curFolderName = fullfile([curFolderName char(allFolders{cntFolders})],filesep);
                if ~isempty(curFolderName) & ~exist(curFolderName,'dir')
                     fprintf('Creating folder: %s\n',curFolderName);
                     mkdir(curFolderName)
                end
            end    
            result = true;
        catch ME
            error('Folder %s does not exist and cannot be created!\n',folderIn)
        end
    end
else
    result = true;
end
