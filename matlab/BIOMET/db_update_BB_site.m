function db_update_BB_site(yearIn,sites,skipWebUpdates)
%
% NOTE: Pass sites as a cell array {'BB'}

% renames Burns Bog logger files, moves them from CSI_NET\old on PAOA001 to
% CSI_NET\old\yyyy, updates the annex001 database

% user can input yearIn, sites (cellstr array containing site suffixes)
% use do_eddy = 1, to turn on dbase updates using calculated daily flux
% files

% file created:  June 24, 2019        
% last modified: Jan   8, 2025 
%

% function based on db_update_HH_sites

% Revisions:
%
% Jan 8, 2025 (Zoran)
%   - Bug fix/Improvement: For some data loggers each new year a new ProgressList
%     would be created which would contain *all* datalogger files from the Sites folder. 
%     That means that the first time this function would run in a new year, 
%     all datalogger files for all years would be reprocessed!). The fix 
%     forces reading of data logger files with extensions .YYYY* and avoids
%     reprocessing of old files.
% Feb 20, 2024 (Zoran)
%  - Syntax updates
%  - Cleaning out some redundant eval statements
%  - at the line ~149, replaced fr_SmartFlux_database with
%    fr_EddyPro_database
% Jan 18, 2024 (Zoran)
%  - Updated for the new syntax of db_struct2database and fr_read_generic_data_file
%    structType=1, forceFullDB = 0
% Dec 19, 2023 (Zoran)
%  - added synchronization of BBS Manual chamber data.
% Oct 5, 2023 (Zoran)
%  - added BBS manual chamber data processing
% June 2, 2021 (Zoran and Nick)
%   - modifications to make the program work for Manitoba sites.
% Nov 12, 2019 (Zoran)
%   - remove >> null from: dos('start /MIN C:\Ubc_flux\BiometFTPsite\BB_Web_Update.bat>>null');
%     It used to work when I used the old Matlab but it stopped now (Message "Access denied".  Must
%     be that the null file was being written somewhere where it shouldn't.
%     
% Nov  9, 2019 (Zoran)
%   - added BB2 site
% Oct 27, 2019 (Zoran)
%   - Added skipWebUpdates update flag that has to be set to 0 if user
%   wants to update the web page too. Used to speed up the debugging


dv=year(datetime);
arg_default('yearIn',dv);
arg_default('sites',{'BB'});
arg_default('skipWebUpdates',1);   % skip web plot updates by default

missingPointValue = NaN;        % For BB sites we'll use NaN to indicate missing values (new feature since Oct 20, 2019)

% Add file renaming + copying to \\paoa001
pth_db = db_pth_root;

for cntYears=1:length(yearIn)
    for cntSites=1:length(sites)
        siteID = char(sites(cntSites));
        fprintf('\n**** Processing Year: %d, Site: %s   *************\n',yearIn(cntYears),siteID);
        
        % Progress list for BBx_MET (CR1000) logger
        progressList_30min_Pth = fullfile(pth_db,[siteID '_30min_progressList_' num2str(yearIn(cntYears)) '.mat']); 
        
        % Progress list for BBx_RAW (CR1000) logger
        progressList_RAW30min_Pth = fullfile(pth_db,[siteID...
            '_RAW30min_progressList_' num2str(yearIn(cntYears)) '.mat']);     
        
        % Path to Climate Database: HHClimateDatabase_Pth
        if strcmp(siteID,'BB')
            % Special processing for 5-min BB site data files'
            ClimateDatabase_Pth = fullfile(pth_db,'yyyy',siteID,'Met\5min');
        else
            ClimateDatabase_Pth = fullfile(pth_db,'yyyy',siteID,'Met');
        end

        % Progress list for SmartFlux files: progressListHH_SmartFlux_Pth =
        % \\annex001\database\HH_SmartFlux_ProgressList
        progressList_SmartFlux_Pth = fullfile(pth_db,[siteID '_SmartFlux_progressList_' num2str(yearIn(cntYears)) '.mat']);
        % Path to Flux Database: FluxDataBase_Pth
        FluxDatabase_Pth = fullfile(pth_db, 'yyyy', siteID,'Flux');        

        % Processing of MET data
        outputPath = ClimateDatabase_Pth;
        if strcmp(siteID,'BB')
            % Special processing for 5-min BB site data files'
            %=================================        
            % Process BB_MET (CR1000) logger
            % its table is updated in 5-minute intervals so I needed to add
            % "_30min_Pth,outputPath,2,0,5" to the end of cmdTMP (see below)
            % (Zoran 20190624)
            %=================================
            [numOfFilesProcessed,numOfDataPointsProcessed] = ...
                   fr_site_met_database(fullfile('p:\sites\', siteID,['\MET\BB_MET.' num2str(yearIn(cntYears)) '*']), ...
                                        [],[],[],progressList_30min_Pth,outputPath,2,0,5,[],missingPointValue);
            fprintf('  %s_MET:  Number of files processed = %d, Number of 5-minute periods = %d\n',siteID,numOfFilesProcessed,numOfDataPointsProcessed);

            % convert 5-minute files into 30-min files
            BB_5min_2_30min(yearIn(cntYears), siteID);

        elseif strcmp(siteID,'BB2')
            [numOfFilesProcessed,numOfDataPointsProcessed] = fr_site_met_database(...
                fullfile('p:\sites\', siteID, 'MET', [siteID '_MET.' num2str(yearIn(cntYears)) '*']), ...
                [],[],[],progressList_30min_Pth,outputPath,2,0,30,[],missingPointValue);
            fprintf('  %s_MET:  Number of files processed = %d, Number of 5-minute periods = %d\n',siteID,numOfFilesProcessed,numOfDataPointsProcessed);

       elseif strcmp(siteID,'DSM')||strcmp(siteID,'RBM')
            % RAW Table
            [numOfFilesProcessed,numOfDataPointsProcessed] = fr_site_met_database(...
                fullfile('p:\sites\', siteID,'MET', [siteID '_RAW.' num2str(yearIn(cntYears)) '*']),...
                [],[],[],progressList_RAW30min_Pth,outputPath,2,0,30,[],missingPointValue);
            fprintf('  %s_RAW:  Number of files processed = %d, Number of 30-minute periods = %d\n',siteID,numOfFilesProcessed,numOfDataPointsProcessed);
            % MET Table
            [numOfFilesProcessed,numOfDataPointsProcessed] = fr_site_met_database(...
                    fullfile('p:\sites\',siteID,'MET', [siteID '_MET.' num2str(yearIn(cntYears)) '*']),...
                    [],[],[],progressList_30min_Pth,outputPath,2,0,30,[],missingPointValue);          
            fprintf('  %s_MET:  Number of files processed = %d, Number of 30-minute periods = %d\n',siteID,numOfFilesProcessed,numOfDataPointsProcessed);
        end

        %=====================================
        % Process SmartFlux EP-summary files 
        %======================================
        try
            outputPath = FluxDatabase_Pth;
            inputPath = fullfile('p:\sites', siteID, 'Flux', [num2str(yearIn(cntYears)) '*_EP-Summary*.txt']);
            progressList = progressList_SmartFlux_Pth;  
            [numOfFilesProcessed,numOfDataPointsProcessed]= fr_EddyPro_database(inputPath,progressList,outputPath,[],[],missingPointValue);           
            fprintf('  %s  HH_SmartFlux:  Number of files processed = %d, Number of HHours = %d\n',siteID,numOfFilesProcessed,numOfDataPointsProcessed);
        catch
        end
        %==================================================
        % Process manual chamber measurements at BBS site
        %==================================================
        try
            if strcmp(siteID,'BBS')
                % Paths for Chamber processing
                outputPath = fullfile(pth_db,'yyyy',siteID,'Chambers');
                inputPath = fullfile('p:\sites',siteID,'Chambers','*.csv');
                progressListPath = fullfile(pth_db,num2str(yearIn(cntYears)),siteID,'Chambers','ProgressList.mat');
                % Synchronize csv files created by SoilFluxPro software
                csvSourceFolder = fullfile('\\137.82.55.154\data-dump',siteID,'Chamberdata\Fluxesdata\Fluxesdata_recomputed\csv_file');
                csvOutputFolder = fullfile('P:\Sites', siteID, 'Chambers');
                cmdTMP = ['robocopy ' csvSourceFolder ' ' csvOutputFolder ' /R:3 /W:10 /REG /NDL /NFL /NJH /log+:P:\Sites\Log_files\' siteID '_chambers_sync.log' ];
                dos(cmdTMP);
                % Run chamber data processing
                [numOfFilesProcessed,numOfDataPointsProcessed]= ...
                          fr_SoilFluxPro_database(inputPath,progressListPath,outputPath,'1min',[],missingPointValue);                                                            
                fprintf('%s  Manual chambers:  Number of files processed = %d, Number of HHours = %d\n',siteID,numOfFilesProcessed,numOfDataPointsProcessed);
                % Process manual Water Level measurements
                % Synchronize manualy edited xlsx file 
                csvSourceFolder = fullfile('\\137.82.55.154\data-dump',siteID,'Chamberdata\Manualdata');
                csvOutputFolder = fullfile('P:\Sites', siteID, 'Chambers\Manualdata');
                cmdTMP = ['robocopy ' csvSourceFolder ' ' csvOutputFolder ' /S /R:3 /W:10 /REG /NDL /NFL /NJH /log+:P:\Sites\Log_files\' siteID '_chambers_sync.log' ];
                dos(cmdTMP);
                % Run Water Level data processing
                [~,~,~] = fr_read_generic_data_file(fullfile(csvOutputFolder,'WL_for_each_collar.xlsx'),'caller',[],1,[],[2 Inf],1,'spreadsheet');
                db_struct2database(Stats,fullfile(outputPath,'WaterLevel'),[],[],[],NaN,1,0);
                                
                % Backup all data
                csvSourceFolder = fullfile('\\137.82.55.154\data-dump',siteID,'Chamberdata\Fluxesdata\Fluxesdata_originalcopy');
                csvOutputFolder = fullfile('P:\Sites', siteID, 'Chambers','HF_data','Original');
                cmdTMP = ['robocopy ' csvSourceFolder ' ' csvOutputFolder ' /xf .DS_Store /R:3 /W:10 /REG /NDL /NFL /NJH /log+:P:\Sites\Log_files\' siteID '_chambers_sync.log' ];
                dos(cmdTMP);
                csvSourceFolder = fullfile('\\137.82.55.154\data-dump',siteID,'Chamberdata\Fluxesdata\Fluxesdata_recomputed');
                csvOutputFolder = fullfile('P:\Sites', siteID, 'Chambers','HF_data','Recomputed');
                cmdTMP = ['robocopy ' csvSourceFolder ' ' csvOutputFolder ' /xf .DS_Store /R:3 /W:10 /S /REG /NDL /NFL /NJH /log+:P:\Sites\Log_files\' siteID '_chambers_sync.log' ];
                dos(cmdTMP);                  
            end            
        catch
        end

    end %j  site counter
    
end %k   year counter

if skipWebUpdates ==0
    % create CSV files for the web server
    fprintf('\nWeb updates for all sites and all years...');
    tic;
    for cntSites=1:length(sites)
        % make sure that a bug in one site processing does not crash all
        % updates. Do it one site at the time
        try
            BB_webupdate(sites(cntSites),'P:\Micromet_web\www\webdata\resources\csv\');
        catch
        end
    end
    fprintf(' Finished in: %5.1f seconds.\n',toc);

    % Upload CSV files to the web server
    system('start /MIN C:\Ubc_flux\BiometFTPsite\BB_Web_Update.bat');
else
    fprintf('*** Web-plot update skipped. Use flag skipWebUpdates=0 to do the updates.\n\n');
end
