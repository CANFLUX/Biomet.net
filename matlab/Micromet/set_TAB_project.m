function structProject = set_TAB_project(projectPath,flagSetUserData,localPath)
% Entry point for all Trace Analysis Biomet (TAB) data projects
% set_TAB_project ('p:\')  - sets Biomet.net toolbox on p: drive that has R/W access 
%                            to the folder: p:\Database, p:\Sites,p:\Matlab
%
% set_TAB_project('v:\',[],'c:\temp') sets Biomet.net to run on v:\ drive with R/O access
%                                     It uses 'c:\temp' for writing temp files.
%
% Inputs:
%   projectPath         - path to the main project folder (parent of Database and Sites folders)
%   flagSetUserData     - 0 (default) do nothing, 1 - store structProject into figure(0) UserData.
%   localPath           - [] (default) - the current Matlab window will be set to projectPath/Matlab
%                                        and biomet_database_default and biomet_sites_default files
%                                        will be saved there.
%                         localPath    - the current Matlab window will be set to localPath and the
%                                        default files will go there. To be used when the user
%                                        has Read Only permissions for the projectPath.
% Output:
%   structProject       - a structure that keeps all the info about a project.
%
%
%
% NOTE: 
%       This file calls get_TAB_project_configuration which is now 
%       a Matlab function. In the final verson it will call
%       yaml.loadfile('projectName_config.yml') once
%       we finalize the format of structProject.
%
% Zoran Nesic           File created:       May 15, 2024
%                       Last modification:  May  9, 2025

% Revisions
%
% May 9, 2025 (Zoran)
%   - made setting up the default paths for Sites and Database folder
%     completely controllable by get_TAB_project_configuration()
% Aug 22, 2024 (Zoran)
%   - changed the name of the function that loads yaml file to get_TAB_project_configuration.
% Aug 20, 2024 (Zoran)
%   - added input option localPath. When accessing a read-only project folder remotely,
%     creating biomet_sites_ and dabase_default would not work. In that case
%     user should point localPath to the folder where they have write priviledges. 
%   - Added more comments
% Aug 8, 2024 (Zoran)
%   - Fixed a bug where if projectPath was a string and not a char the 
%     biomet_database_default.m creation would fail. Made sure that the projectPath
%     is a char.
% May 22, 2024 (Zoran)
%   - Added automatic creation of:
%       - biomet_database_default.m
%       - biomet_sites_default.m
%   - Created an external, project-specific function: pretend_configYAML()

arg_default('flagSetUserData',0);
arg_default('localPath',[]);

% Make sure the file separators are set properly for 
% Windows and macOS
projectPath = char(fullfile(projectPath));

% projectPath must exist
if ~exist(projectPath,'dir')
    error('Folder: %s does not exist!',projectPath);
end

% set the Matlab current path to projectPath/Matlab
if isempty(localPath)
    cd(fullfile(projectPath,'Matlab'));
elseif exist(localPath,'dir')
    addpath(fullfile(projectPath,'Matlab'))
    cd(localPath)
else
    error (sprintf('Path: %s does not exist!',localPath));
end

% ----------------------------------------
% load yaml file into structProject here
% ----------------------------------------
structProject = get_TAB_project_configuration(projectPath);

% if required, save data under UserData so it's visible 
% to all Matlab functions.
if flagSetUserData == 1
    UserData = get(0,'UserData');
    UserData.structProject = structProject;
    set(0,"UserData",UserData)
end

% to keep compatibility with the legacy code, this function
% will now create the following Matlab functions in the current folder:
% - biomet_database_default.m
% - biomet_sites_default.m
fid = fopen('biomet_database_default.m','w');
if fid > 0
    fprintf(fid,'%s\n','function folderDatabase = biomet_database_default');
    fprintf(fid,'%s(''%s'')\n','% This file is generated automatically by set_TAB_project.m',projectPath);
    dbPth = structProject.databasePath;
    fprintf(fid,'%s\n',['folderDatabase = '''  dbPth ''';']);
    fclose(fid);
end

fid = fopen('biomet_sites_default.m','w');
if fid > 0
    fprintf(fid,'%s\n','function folderSites = biomet_sites_default');
    fprintf(fid,'%s(''%s'')\n','% This file is generated automatically by set_TAB_project',projectPath);
    sitesPth = structProject.sitesPath;
    fprintf(fid,'%s\n',['folderSites = '''  sitesPth ''';']);
    fclose(fid);
end


