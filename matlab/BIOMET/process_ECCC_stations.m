function process_ECCC_stations

structProject = get_TAB_project;

pthSites = structProject.sitesPath;
sitesIn = fieldnames(structProject.sites);

diary(fullfile(pthSites,'process_ECCC.log'));
fprintf('=================================================\n')
fprintf('Started: %s\n',datetime);

% Find all ECCC stations for this project
stationIDs = [];
for cntSites = 1:length(sitesIn)
    siteID = char(sitesIn(cntSites));
    for cntECCC = 1:length(structProject.sites.(siteID).dataSources.eccc)
        stationIDs = [stationIDs structProject.sites.(siteID).dataSources.eccc(cntECCC).stationsID]; %#ok<AGROW>
    end
    
end
stationIDs = unique(stationIDs);
try
    fprintf('Start ECCC processing\n');
    monthRange = month(datetime)+[-1:0]; %#ok<NBRAK1>
    run_ECCC_climate_station_update(year(datetime),monthRange,stationIDs,db_pth_root)
    fprintf('Finish ECCC processing\n');
catch ME
    disp(ME);
end