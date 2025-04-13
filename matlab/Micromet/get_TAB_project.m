function structProject = get_TAB_project(projectPath)
% Collect all project info for a project. 
% This is a wrapper function for a project-specific get_TAB_project_configuration.m
% 
% get_TAB_project ('p:\mainProject')   - creates a structure will all the project info for a project in p:\mainProject
%
% Inputs:
%   projectPath         - path to the main project folder (parent of Database and Sites folders)
%                         If projectPath is not give, then the function is going to load the default one
% Output:
%   structProject       - a structure that keeps all the info about a project.
%
%
% Zoran Nesic           File created:       Apr 12, 2025
%                       Last modification:  Apr 12, 2025

% Revisions
%

% the default project path can be extraced from biomet_database_default if it exists.
if exist("biomet_database_default.m","file")
    defaultProjectPath = fileparts(biomet_database_default);
else
    defaultProjectPath = [];
end

arg_default('projectPath',defaultProjectPath)

if isempty(projectPath)
    fprintf(2,'function get_TAB_project requires biomet_database_default!\n')
    error('Exiting...')
end

structProject=get_TAB_project_configuration(projectPath);