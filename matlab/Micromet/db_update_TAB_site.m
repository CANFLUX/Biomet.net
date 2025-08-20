function db_update_TAB_site(yearIn,sites)
% db_update_TAB_site - runs database updates for all "sites". 
%
%
% NOTE: Pass sites as a cell array {'UQAM_0'}
%
% Zorn Nesic            File created:       Aug 20, 2025
%                       Last modification:  Aug 20, 2025
%

% function based on db_update_UQAM_site

% Revisions:
%

% Find all site names
structProject = get_TAB_project;
allSites = fieldnames(structProject.sites);

% defaults for the input arguments
arg_default('yearIn',year(datetime));
arg_default('sites',allSites);

missingPointValue = NaN;        % Use NaN to indicate missing values

% Datbase path
pth_db = db_pth_root;
pthSites = biomet_sites_default;

for cntYears=1:length(yearIn)
    for cntSites=1:length(sites)
        siteID = char(sites(cntSites));
        strYear = num2str(yearIn(cntYears));
        pthLog = fullfile(pth_db,'log');
        dtStartTime = datetime;
        fprintf('\n**** Processing Year: %d, Site: %s   *************\n',yearIn(cntYears),siteID);
        
        %----------------------------------------------
        % Cycle through all loggers and logger tables
        %----------------------------------------------
        for cntTbl = 1:length(structProject.sites.(siteID).dataSources.met.table)
            tableMin            = structProject.sites.(siteID).dataSources.met.table(cntTbl).timeStepMin;   
            dbFolderName        = structProject.sites.(siteID).dataSources.met.table(cntTbl).dbFolderName;
            tableName           = structProject.sites.(siteID).dataSources.met.table(cntTbl).source;
            strTimeUnit            = [num2str(tableMin) 'MIN'];
            % progress list name:
            progressListName    = sprintf('%s_progressList_%s.mat',tableName,strYear);
            % set paths
            progressList_Pth    = fullfile(pthLog,progressListName); 
            outputPath          = fullfile(pth_db,'yyyy',siteID,dbFolderName);

            % Process logger files with the pattern ".YYYY*" (historical
            % files)
            strTablePattern     = [tableName '.' strYear '*'];
            loggerTable_pth     = fullfile(pthSites,siteID,'Met',strTablePattern);
            % Process csv -> database
            [numOfFilesProcessed,numOfDataPointsProcessed]= ...
                   fr_TOA5_database(loggerTable_pth,progressList_Pth,outputPath,[],strTimeUnit,missingPointValue);             
            fprintf('  %s:  Number of files processed = %d, Number of %d-minute periods = %d\n',strTablePattern,...
                numOfFilesProcessed,tableMin,numOfDataPointsProcessed);

            % Process logger files with the pattern ".dat" (current files)
            strTablePattern     = [tableName '.dat'];
            loggerTable_pth     = fullfile(pthSites,siteID,'Met',strTablePattern);
            % Process csv -> database
            [numOfFilesProcessed,numOfDataPointsProcessed]= ...
                   fr_TOA5_database(loggerTable_pth,progressList_Pth,outputPath,[],strTimeUnit,missingPointValue);             
            fprintf('  %s:  Number of files processed = %d, Number of %d-minute periods = %d\n',strTablePattern,...
                numOfFilesProcessed,tableMin,numOfDataPointsProcessed);
        end
    
        %=====================================
        % Process SmartFlux EP-summary files 
        %======================================
        try
            outputPath = fullfile(pth_db,'yyyy',siteID,'Flux');
            strEPPattern = [strYear '*_EP-Summary*.txt'];
            inputPath = fullfile(pthSites, siteID, 'Flux', strEPPattern);
            progressListName    = sprintf('%s_%s_progressList_%s.mat',siteID,'SmartFlux',strYear);
            progressList_Pth    = fullfile(pthLog,progressListName);  
            [numOfFilesProcessed,numOfDataPointsProcessed]= ...
                fr_EddyPro_database(inputPath,progressList_Pth,outputPath,[],[],missingPointValue);           
            fprintf('  %s: SmartFlux:       Number of files (%s) processed = %d, Number of HHours = %d\n',siteID,strEPPattern,numOfFilesProcessed,numOfDataPointsProcessed);
        catch
            fprintf(2,'An error happen while running fr_EddyPro_database (SmartFlux summary files) in db_update_UQAM_site.m\n');
        end
        %=====================================
        % Process EddyPro recalculated files 
        %====================================== 
        % First _full_output files
        try
            % Run database update for EddyPro recalculations
            outputPath = fullfile(pth_db,'yyyy',siteID,'Flux');
            strEPPattern = sprintf('eddypro_%s_%d*_full_output*_adv.csv',siteID,yearIn(cntYears));
            inputPath = fullfile(pthSites,siteID,'Flux',strEPPattern);
            %inputPath = fullfile(pthSites, siteID, 'Flux', [num2str(yearIn(cntYears)) '*_EP-Summary*.txt']);
            progressListName    = sprintf('%s_%s_progressList_%s.mat',siteID,'EddyPro',strYear);
            progressList_Pth    = fullfile(pthLog,progressListName); 
            [numOfFilesProcessed,numOfDataPointsProcessed]= ...
                fr_EddyPro_database(inputPath,progressList_Pth,outputPath,[],[],missingPointValue);  
            fprintf('  %s: EddyPro:         Number of files (%s) processed = %d, Number of HHours = %d\n',siteID,strEPPattern,numOfFilesProcessed,numOfDataPointsProcessed);
        catch
            fprintf(2,'An error happen while running fr_EddyPro_database ( EddyPro full_output) in db_update_UQAM_site.m\n');
        end    
        % Then process _biomet_ files
        try
            % output goes under Flux/biomet
            outputPath = fullfile(pth_db,'yyyy',siteID,'Flux','biomet');                     
            % Path to the source files
            strEPPattern = sprintf('eddypro_%s_%d*_biomet*_adv.csv',siteID,yearIn(cntYears));
            inputPath = fullfile(pthSites,siteID,'Flux',strEPPattern);
            progressListName    = sprintf('%s_%s_progressList_%s.mat',siteID,'EddyPro_biomet',strYear);
            progressList_Pth    = fullfile(pthLog,progressListName); 
            % Process the new files
            [numOfFilesProcessed,numOfDataPointsProcessed]= fr_EddyPro_database(inputPath,progressList_Pth,outputPath,[],[],missingPointValue);           
            fprintf('  %s: EddyPro_biomet:  Number of files (%s) processed = %d, Number of HHours = %d\n',siteID,strEPPattern,numOfFilesProcessed,numOfDataPointsProcessed);
        catch
            fprintf(2,'An error happen while running fr_EddyPro_database ( EddyPro _biomet_) in db_update_UQAM_site.m\n');
        end
        fprintf('Finished. (Duration: %s)\n',datetime-dtStartTime);
    end %j  site counter
    
end %k   year counter

