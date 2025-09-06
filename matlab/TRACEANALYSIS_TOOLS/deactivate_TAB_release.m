function deactivate_TAB_release(projectPath)
% deactivate_TAB_release  - returns Matlab settings from a release version 
%                           of a project back to the current project version
%                           and current version of Biomet.met
%                           see: release_TAB_project and activate_TAB_release
% 
% Arguments
%   projectPath    - project path
%
% Example: 
%    %Setup Matlab to use the project at projectPath with the default Biomet.net
%       projectPath      = 'E:\Pipeline_Projects\SMC';
%       deactivate_TAB_release(projectPath)
%  
% Zoran Nesic               File created:       Sep  5, 2025
%                           Last modification:  Sep  5, 2025

% Revisions
%

% Reset default paths for Biomet.net 
path(pathdef)
startup

% Set the new project
structProject=set_TAB_project(projectPath);