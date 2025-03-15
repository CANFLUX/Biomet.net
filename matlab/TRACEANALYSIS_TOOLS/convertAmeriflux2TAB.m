function result = convertAmeriflux2TAB(allNewSites,dbID,sourcePath,projectPath,flagNewSites)
% Convert Ameriflux BASE+BIF files into TAB database project
%
% Example creating a new project with two sites:
%    allNewSites = {'BR-Npw','CA-BOU'};
%    dbID = 'AMF';
%    sourcePath = 'E:\Pipeline_Projects\Ameriflux_raw';
%    projectPath = 'E:\Pipeline_Projects\Ameriflux_CH4_v2'
%    flagNewSites = false
%    result = convertAmeriflux2TAB(allNewSites,dbID,sourcePath,projectPath,flagNewSites);
%
% Example: adding a new site to an existing project
%    allNewSites = {'CA-DSM'};
%    dbID = 'AMF';
%    sourcePath = 'E:\Pipeline_Projects\Ameriflux_raw';
%    projectPath = 'E:\Pipeline_Projects\Ameriflux_CH4_v2'
%    flagNewSites = true
%    result = convertAmeriflux2TAB(allNewSites,dbID,sourcePath,projectPath,flagNewSites);
%
%
% Zoran Nesic               File created:           Mar 12, 2025
%                           Last modification:      Mar 14, 2025

% Revisions:
%
% Mar 14, 2025 (Zoran)
%  - Function will now not work if the output folder already exists.
%  - siteName will be used if found in BIF file to populate FirstStage.ini field
%  - added option flagNewSites when adding a new site to an existing project
%

arg_default('flagNewSites',false)

result = 1; %#ok<NASGU>
missingPointValue = NaN;
timeUnit= '30MIN';
fprintf('\n\n\n============== Conversion Ameriflux -> TAB ===========================\n\n');
if exist(projectPath,'dir') && ~flagNewSites  
    fprintf(2,'  *** If you are trying to add a site to an existing project use flagNewSites = true.');
    fprintf('\n\n');
    error('  The output folder already exists. Exiting...');
end


for cntSites = 1:length(allNewSites)
    siteID_origin = char(allNewSites(cntSites));
    siteID = upper(strrep(siteID_origin,'-',''));

    % Create new project or just add a new site
    create_TAB_ProjectFolders(projectPath,siteID,flagNewSites);
    % After the previous step, the new project exists and we treat
    % the other sites as new sites.
    flagNewSites = true; 
    structProject=set_TAB_project(projectPath);

    % Copy the raw data to the Flux folder
    sourceFiles = fullfile(sourcePath,[dbID '_' siteID_origin '*.*']);
    destinationFolder = fullfile(projectPath,'Sites',siteID,'Flux');
    copyfile(sourceFiles, destinationFolder);

    % Create the ThirdStage ini file and extract site info from the BIF file
    thirdStageIni = createAmerifluxThirdStageIni(structProject,dbID,siteID,siteID_origin);
    disp(thirdStageIni);
    %% ====================================================================================
    %  Convert raw files
    %  ---------------------------------------------------------------------------
    % Input file name
    dataFileName = [dbID '_' siteID_origin '*.csv'];
    csvNames = dir(fullfile(structProject.sitesPath,siteID,'Flux',dataFileName));
    
    fileName = fullfile(csvNames.folder,csvNames.name);
    [~, ~,~,outStruct] = fr_read_Ameriflux_file(fileName);
    
    % set database path
    databasePath = fullfile(structProject.databasePath,'yyyy',siteID,'Flux');
    
    % Convert outStruct into database (all 6 years)
    db_struct2database(outStruct,databasePath,0,[],timeUnit,missingPointValue,1,1);

    %% Create a FirstStage and SecondStage ini files
    
    % Setup for the ini files
    structSetup.startYear = thirdStageIni.startYear;
    structSetup.startMonth = thirdStageIni.startMonth;
    structSetup.startDay = thirdStageIni.startDay;
    structSetup.endYear = 2999;
    structSetup.endMonth = 12;
    structSetup.endDay = 31;
    if isfield(thirdStageIni,'siteName')
        structSetup.Site_name = thirdStageIni.siteName;
    else
        structSetup.Site_name = 'Long name here';
    end
    structSetup.siteID = siteID;
    structSetup.allMeasurementTypes = {'Flux'};
    structSetup.Difference_GMT_to_local_time = ...
                         -thirdStageIni.GMT_offset;     % local+Difference_GMT_to_local_time -> GMT time
    structSetup.outputPath = [];                        % keep it in the local directory
    structSetup.isTemplate = false;                     % Set to false if you want to create ini files 
                                                        % and not templates (it will overwrite the ini 
                                                        % files under TraceAnalysis_ini)
    % FirstStage template:
    createFirstStageIni(structSetup)
    % SecondStage template:
    createSecondStageIni(structSetup)    
end

result = 0;



