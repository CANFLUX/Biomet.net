function run_TAB_db_update(yearIn,sitesIn)
% Generic TAB data processing function
%
% This program is based on run_UQAM_db_update (CARBONIQUE project)
%
% Zoran Nesic           File created:       Aug 20, 2025
%                       Last modification:  Aug 21, 2025

%
% Revisions:
%
% Aug 21, 2025 (Zoran)
%   - Added renaming CSI files and ECCC station processing to this function
%     so we don't have to schedule the other tasks separately. 

startTime = datetime;
arg_default('yearIn',year(startTime));    % default - current year
structProject = get_TAB_project;
allSites = get_TAB_site_names;
arg_default('sitesIn',allSites);        % default - all sites

if ischar(sitesIn)
    sitesIn = {sitesIn};
end

fprintf('===============================\n');
fprintf('***** run_TAB_db_update ******\n');
fprintf('===============================\n');
fprintf('%s\n',datetime);
% Run database updates for on-line data
db_update_TAB_site(yearIn,sitesIn);

% Cycle through all the sites and do site specific chores
% (netCam picture taking, ...)
for currentSiteID = sitesIn
    siteID = char(currentSiteID);
    % Extract site info
    latIn = structProject.sites.(siteID).Metadata.lat;
    longIn = structProject.sites.(siteID).Metadata.long;    
    % Take time-lapse photos only once per hour (min<30) and
    % during "daytime" (globalradiation > 50W)
    % NOTE: potential_radiation() needs West to have positive longIn, hence
    %       the change of sign below! It also needs GMT time 
    siteUTCtime = convert_PCtime2UTC;   
    if potential_radiation(siteUTCtime,latIn,-longIn) > 50 && minute(datetime)<30
        dtStart = datetime;
        fprintf('  Taking %s Phenocam picture. %s\n',siteID,dtStart);
        hourIn = hour(datetime);
        netCam_Link = structProject.sites.(siteID).netCam_Link;
        take_Phenocam_picture(siteID,netCam_Link,hourIn);  
        fprintf('Finished. (Duration: %s)\n',datetime-dtStart);
    end
    % Run cleaning stage 1 and 2
    try
        fr_automated_cleaning(yearIn,siteID,[1 2]);
    catch
        fprintf(2,'fr_automated_cleaning failed when running %s site!\n', siteID);
    end
end

% --- rename all Met files once per day ----
if hour(datetime) == 0 && minute(datetime) < 30
    try
        TAB_rename_csi_files
    catch
        fprintf(2,'Error renaming CSI files. (%s)',datetime);
    end
end

% --- process ECCC stations once per day ----
if hour(datetime) == 0 && minute(datetime) > 30
    try
        process_ECCC_stations;
    catch
        fprintf(2,'Error processing ECCC stations. (%s)',datetime);
    end
end

fprintf('\n\n%s\n',datetime);
fprintf('**** run_TAB_db_update finished in %6.1f sec.******\n',seconds(datetime-startTime));
fprintf('=====================================================\n\n\n');

