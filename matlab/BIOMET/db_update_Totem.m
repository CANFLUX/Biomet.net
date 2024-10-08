function db_update_Totem(yearIn)
% Convert CR1000 files from UBC_Totem station
%
%
% Zoran Nesic       File created:       Aug 03, 2023
%                   Last modification:  Aug 03, 2023
% 


% Revisions:
%

dv=datevec(now);
arg_default('yearIn',dv(1));
sites_pth = 'd:\Sites';
pth_db = db_pth_root; 
siteID = 'UBC_Totem';
        
for k=1:length(yearIn)
    fprintf('\n**** Processing Year: %d, Site: UBC_Totem   *************\n',yearIn(k));

    % Progress list for UBC_Totem CR1000 files
    progressListPath = fullfile(pth_db,sprintf('%s_progressList_%d.mat',siteID,yearIn(k)));

    % Path to UBC_Totem Database
    outputPath = fullfile(pth_db,'yyyy',siteID,'Climate');                     
    % Path to the source files
    inputPath = fullfile(sites_pth,'UBC','CSI_net');
    % Process the new files
    cmdTMP = (['[numOfFilesProcessed,numOfDataPointsProcessed] = fr_site_met_database(''p:\sites\' siteID ...
        '\MET\' siteID '_MET.*''' ',[],[],[],progressList' ...
        siteID '_30min_Pth,outputPath,2,0,30,[],missingPointValue);']);
    % First check if there are CR1000 files under OLD folder
    % Keep track of which ones were already processed
    [numOfFilesProcessed1,numOfDataPointsProcessed1] = fr_site_met_database(fullfile(sites_pth,'ubc','CSI_NET','OLD','TF-ClimateStation_CR1000_Clim_30m.*'),...
                                                      [],[],[],progressListPath,outputPath,2,0,30,[]);
    % Then process the ones under CSI_NET, but don't keep the progressList
    [numOfFilesProcessed2,numOfDataPointsProcessed2] = fr_site_met_database(fullfile(sites_pth,'ubc','CSI_NET','TF-ClimateStation_CR1000_Clim_30m.*'),...
                                                      [],[],[],[],outputPath,2,0,30,[]);
    fprintf('UBC_Totem Climate:  Number of files processed = %d, Number of 30-minute periods = %d\n',numOfFilesProcessed1+numOfFilesProcessed2,numOfDataPointsProcessed1+numOfDataPointsProcessed2);                                                  
end %k   year counter

