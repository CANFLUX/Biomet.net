
% ==========================================================
%  Setup parameters

kill

% ------------
% The input parameters
allNewSites = {'BR-Npw','CA-BOU'};
dbID = 'AMF';
sourcePath = 'E:\Pipeline_Projects\Ameriflux_raw';
projectPath = 'E:\Pipeline_Projects\Ameriflux_CH4';
%-----------------------------------------------------

missingPointValue = NaN;
timeUnit= '30MIN';

if exist(projectPath,'dir')
    rmdir(projectPath,'s');
end


for cntSites = 1:length(allNewSites)
    siteID_origin = char(allNewSites(cntSites));
    siteID = upper(strrep(siteID_origin,'-',''));
    if cntSites == 1
        create_TAB_ProjectFolders(projectPath,siteID);
        structProject=set_TAB_project(projectPath);
    else
        create_TAB_ProjectFolders(projectPath,siteID,true)
    end
    % Copy the raw data to the Flux folder
    sourceFiles = fullfile(sourcePath,[dbID '_' siteID_origin '*.*']);
    destinationFolder = fullfile(projectPath,'Sites',siteID,'Flux');
    copyfile(sourceFiles, destinationFolder);

    % Create the ThirdStage ini file and extract site info from the BIF file
    thirdStageIni = createAmerifluxThirdStageIni(structProject,dbID,siteID,siteID_origin);
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
    structSetup.Site_name = 'Long name here';
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





