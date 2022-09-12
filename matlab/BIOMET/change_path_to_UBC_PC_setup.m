function [newPath,oldPath] = change_path_to_UBC_PC_setup(newPathPat)
% Change the path to all UBC_PC_setup subfolders to newPath
%
% newPathPat - new path pattern to "UBC_PC_setup" folder instead of the current one.
%              newPathPat has to contain string "UBC_PC_setup/PC_specific"
%
% Program searches through the current path to find the occurance of "PC_specific".
% It then uses that as the reference point of the current path for UBC_PC_setup functions.
% It replaces all the lines that contain "UBC_PC_setup\PC_specific\" 
%                        with <newPathPat>\UBC_PC_setup\PC_specific\.
% 
% Example:
%    If the original path is:
%       c:\UBC_PC_setup
%    and the newPath is:
%       D:\NZ\MATLAB\CurrentProjects\myVersion\UBC_PC_setup
%    then all paths that contain:
%       PC_Specific\
%    will change to:
%       D:\NZ\MATLAB\CurrentProjects\myVersion\UBC_PC_setup\PC_specific\
%
% Zoran Nesic               File created:           Sep 11, 2022
%                           Last modification:      Sep 11, 2022

%
% Revisions:
%
%

% Store the current full path
oldPath = path;

% Make sure that the newPathPat uses proper folder separators
newPathPat = setFolderSeparator(char(newPathPat));
% Make sure that newPath ends with filesep
if ~strcmp(newPathPat(end),filesep)
    newPathPat(end+1) = filesep;
end

% at this point newPathPat has to end with matlab\ or matlab/
if ~strcmpi(newPathPat(end-12:end),['UBC_PC_setup' filesep])
    error('Input path: %s has to end with the string "UBC_PC_setup"\nMaybe you want: %s%s%s',newPathPat,newPathPat,'UBC_PC_Setup',filesep)
end
% find the target folder (here we use the first occurance of 
%      "PC_specific" to find the folder that needs replacing
strInd = strfind(oldPath,'PC_specific');
indSep = strfind(oldPath,';');
indEnd = find(indSep >= strInd(1),1);           % find the ";" at the end of PC_specific
if indEnd == 1
    % if the PC_specific is the first item on the path start from 1
    startPoint = 1;                             
else
    % if not, start from the character one after the previous ";"
    startPoint = indSep(indEnd-1)+1;            
end
oldPathPat = oldPath(startPoint: strInd(1)-1);  % pathPat = "\\paoa001\matlab\"

% Replace oldPathPat in oldPathPat with newPathPat
newPath = replace(oldPath,oldPathPat,newPathPat);

% Set the new path
path(newPath);