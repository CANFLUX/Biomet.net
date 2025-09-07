function [successOut,outputPath] = release_TAB_project(projectPath,outputFolderName,foldersToCopy)
% release_TAB_project - create a release version of a TAB project 
%                       in the folder outputFolderName\yyyymmddThhmm
% 
% Arguments
%   projectPath             - project path
%   outputFolderName        - output folder where the release version will be stored
%   foldersToCopy           - cell array of the folder names to copy (see below for the defaults)
%
% Example: Copy the entire project SMC (without Sites folder) to 'e:\allReleases\SMC\yyyymmddThhmm'
%       projectPath      = 'E:\Pipeline_Projects\SMC';
%       outputFolderName = 'e:\allReleases\';
%       structProject    = set_TAB_project(projectPath);
%       successOut       = release_TAB_project(projectPath,outputFolderName);
%
%  
% Zoran Nesic               File created:       Sep  5, 2025
%                           Last modification:  Sep  7, 2025

% Revisions
%
% Sep 7, 2025 (Zoran)
%   - cleaned up some commented-out lines.
 
defaultFoldersToCopy = {'Database','Matlab','Scripts'};
arg_default('foldersToCopy',defaultFoldersToCopy)

% set new project to be current
structProject=set_TAB_project(projectPath);

% Create the time stamp
timeNow = datetime(datetime,'format',"uuuuMMdd'T'HHmm");
fprintf('=====================================\n');
fprintf('Release project started at: %s\n\n',datetime);

% this is the release folder's (YYYYMMDDTHHMM) full path:
outputPath = fullfile(outputFolderName,structProject.projectName,string(timeNow));
successOut = 1;

for cntFolders = 1:length(foldersToCopy)
    currentFolder = char(foldersToCopy(cntFolders));
    folderPathIn  = fullfile(structProject.path,currentFolder);
    folderPathOut = fullfile(outputPath,currentFolder);
    [success,message,~] = copyfile(folderPathIn,folderPathOut);
    if ~success
        fprintf(2,'%s\n',message);
        successOut = 0;
    end
end

pathBiomet = which('read_bor');
indEnd = regexpi(pathBiomet,[filesep 'Biomet.net' filesep],"end");
pathBiomet = pathBiomet(1:indEnd);
[success,message,~] = copyfile(fullfile(pathBiomet),fullfile(outputPath,'Biomet.net'));
if ~success
    fprintf(2,'%s\n',message);
    successOut = 0;
end

fprintf('TAB project released to the folder: %s (time: %s seconds)\n',outputPath,duration(datetime-timeNow));

