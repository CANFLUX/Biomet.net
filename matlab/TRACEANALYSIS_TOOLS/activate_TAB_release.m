function activate_TAB_release(releasePath)
% activate_TAB_release  - sets up to run a project created using release_TAB_project() function
% 
% Arguments
%   releasePath    - project path (ends with '\yyyymmddThhmm), see release_TAB_project()
%
% Example: 
%    %Setup Matlab to use a "released" project in: 'e:\allReleases\SMC\yyyymmddThhmm'
%       releasePath      = 'E:\Pipeline_Projects\SMC\20250905T1125';
%       activate_TAB_release(releasePath)
%  
% Zoran Nesic               File created:       Sep  5, 2025
%                           Last modification:  Sep  5, 2025

% Revisions
%

% Set the project configuration
structProject=set_TAB_project(releasePath);
% convert to using "frozen" release of Biomet.net
cd(fullfile(structProject.path,'Biomet.net','matlab','startup'))
path(pathdef)
startup
% Go back to the 
structProject=set_TAB_project(releasePath);

% show the new setup
fprintf('==========================\n\n');
fprintf('Now using this project release: \n');
display(structProject)
newPath = split(path,';');
fprintf('Matlab will now use this new Biomet.net path:\n')
disp(newPath(3:6))