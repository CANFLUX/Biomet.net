function create_TAB_ProjectFolders(projectPath,siteID)
% Create the directory structure for Trace Analysis Biomet (TAB) data projects
% create_TAB_ProjectFolders ('E:\Projects\My_MicrometSites','Site_1')
%                           - creates the data tree to be used with TAB projects
%                           - clones the common set of files from GigHub
%                           - follows the instructions given here: 
%                              (Point to pipeline-documentation GigHum)
%
%
% Inputs:
%   projectPath         - path to the main project folder (parent of Database and Sites folders)
%   siteID              - short Ameriflux site ID or your site ID. No spaces are allowed.
%
% Output:
%
%
% Zoran Nesic           File created:       Aug 23, 2024
%                       Last modification:  Sep 13, 2024

% Revisions
%
% Sep 13, 2024 (Zoran)
%   - Added a few warning dialogs that can prevent accidental overwriting
%     of the local ini files.
% Sep 12, 2024 (Zoran)
%   - added repo for include files.
%   (https://github.com/CANFLUX/TAB_include_files.git)

if ~exist('projectPath','var')
    error('Missing Project Path.')
end
if ~exist('siteID','var')
    error('Missing siteID.')
else
    siteID = upper(siteID);
end

if ~exist(projectPath,'dir')
    mkdir(projectPath);
end

if exist(fullfile(projectPath,'Database'),'dir') ...
   || exist(fullfile(projectPath,'Sites'),'dir') ...
   || exist(fullfile(projectPath,'Matlab'),'dir')
     selection = questdlg('Project folders already exist! Do you want to overwrite them?', ...
                     'Last warning!', ...
                     'Yes', 'No','No');
    if strcmpi(selection,'No')
        return
    end
end

tmpPath = fullfile(projectPath,'Database');
if ~exist(tmpPath,'dir')
    mkdir(tmpPath);
end
tmpPath = fullfile(projectPath,'Database','Calculation_Procedures');
if ~exist(tmpPath,'dir')
    mkdir(tmpPath);
end

tmpPath = fullfile(projectPath,'Database','Calculation_Procedures','AmeriFlux');
if ~exist(tmpPath,'dir')
    mkdir(tmpPath);
    url1 = 'https://github.com/CANFLUX/TAB_Ameriflux_variables.git';
    gitclone(url1,tmpPath,Depth=1);
else
    % For repo to be downloaded the folder needs to be empty so first remove it
    ButtonName = questdlg('AmeriFlux repo folder already exists. If you press OK it will be deleted. Your personalized files will be lost! Do you want to proceed?', ...
                         'Deleting local files', ...
                         'Yes', 'No','No');
    if strcmpi(ButtonName,'Yes')
        ButtonName = questdlg('Are you sure!', ...
                     'Last warning!', ...
                     'Yes', 'No','No');
        if strcmpi(ButtonName,'Yes')
            fprintf('Overwriting AmerFlux local copy.\n\n')
            rmdir(tmpPath,"s");
            mkdir(tmpPath);
            url1 = 'https://github.com/CANFLUX/TAB_Ameriflux_variables.git';
            gitclone(url1,tmpPath,Depth=1);            
        else
            fprintf('Skipping AmerFlux repo cloning.\n\n')
        end
    else
        fprintf('Skipping AmerFlux repo cloning.\n\n')
    end
end

tmpPath = fullfile(projectPath,'Database','Calculation_Procedures','TraceAnalysis_ini');
if ~exist(tmpPath,'dir')
    mkdir(tmpPath);
    url1 = 'https://github.com/CANFLUX/TAB_include_files.git';
    gitclone(url1,tmpPath,Depth=1);
else
    % For repo to be downloaded the folder needs to be empty so first remove it
    ButtonName = questdlg('TraceAnalisis_ini folder already exists. If you press OK it will be deleted. Your personalized INI files will be lost! Do you want to proceed?', ...
                         'Deleting local files', ...
                         'Yes', 'No','No');
    if strcmpi(ButtonName,'Yes')
        ButtonName = questdlg('Are you sure!', ...
                     'Last warning!', ...
                     'Yes', 'No','No');
        if strcmpi(ButtonName,'Yes')
            fprintf('Overwriting TraceAnalisis_ini folder.\n\n')
            rmdir(tmpPath,"s");
            mkdir(tmpPath);
            url1 = 'https://github.com/CANFLUX/TAB_include_files.git';
            gitclone(url1,tmpPath,Depth=1);           
        else
            fprintf('Skipping TraceAnalisis_ini folder repo cloning.\n\n')
        end
    else
        fprintf('Skipping TraceAnalisis_ini folder repo cloning.\n\n')
    end
end

tmpPath = fullfile(projectPath,'Database','Calculation_Procedures','TraceAnalysis_ini',siteID);
if ~exist(tmpPath,'dir')
    mkdir(tmpPath);
end

tmpPath = fullfile(projectPath,'Database','Calculation_Procedures','TraceAnalysis_ini',siteID,'Derived_Variables');
if ~exist(tmpPath,'dir')
    mkdir(tmpPath);
end

tmpPath = fullfile(projectPath,'Database','Calculation_Procedures','TraceAnalysis_ini',siteID,'log');
if ~exist(tmpPath,'dir')
    mkdir(tmpPath);
end

tmpPath = fullfile(projectPath,'Sites');
if ~exist(tmpPath,'dir')
    mkdir(tmpPath);
end

tmpPath = fullfile(projectPath,'Sites',siteID);
if ~exist(tmpPath,'dir')
    mkdir(tmpPath);
end


tmpPath = fullfile(projectPath,'Matlab');
if ~exist(tmpPath,'dir')
    mkdir(tmpPath);
end

% For a TAB project to function it also needs a get_TAB_project_configuration.m file
% The following code creates the bare minimum version of this file (if it doesn't already exist)
fileName = fullfile(projectPath,'Matlab','get_TAB_project_configuration.m');
if exist(fileName,'file')
    fprintf(2,'get_TAB_project_configuration.m already exists. Leaving it as is...\n');
else
    fid = fopen(fileName,'w');
    if fid > 0
        fprintf(fid,'%s\n','function structProject = get_TAB_project_configuration(projectPath)');
        fprintf(fid,'%%This file is generated automatically by create_TAB_ProjectFolders.m\n');
        fprintf(fid,'%s\n','projectName = '''';');
        fprintf(fid,'%s\n','structProject.projectName   = projectName;');
        fprintf(fid,'%s\n','structProject.path          = fullfile(projectPath);');
        fprintf(fid,'%s\n','structProject.databasePath  = fullfile(structProject.path,''Database'');');
        fprintf(fid,'%s\n','structProject.sitesPath     = fullfile(structProject.path,''Sites'');');
        fprintf(fid,'%s\n','structProject.matlabPath    = fullfile(structProject.path,''Matlab'');');
        fclose(fid);
    end
end