function run_TAB_db_update(yearIn,sitesIn)
% Generic TAB data processing function
%
% This program is based on run_UQAM_db_update (CARBONIQUE project)
%
% Zoran Nesic           File created:       Aug 20, 2025
%                       Last modification:  Jul 13, 2026

%
% Revisions:
%
% July 13, 2026 (Zoran)
%   - added protection in case the Metadata field does not exist
%   - if netCam_Link = {} skip Phenocam picture taking
% June 4, 2026 (Zoran)
%   - It now uses parallel processing toolbox if available. It will revert to regular processing
%     if PP toolbox is not available or the processing does not require it (single site + single year).
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


% Check if Parallel Processing toolbox exists
allToolboxes = ver;
toolboxON = contains([allToolboxes(:).Name],'Parallel Computing');

% Run database updates for on-line data
if toolboxON
    if length(sitesIn) > 1
        parfor cntSites = 1:length(sitesIn)
            db_update_TAB_site(yearIn,sitesIn(cntSites));
        end
    elseif length(yearIn)>1
        parfor cntYears = 1:length(yearIn)
            db_update_TAB_site(yearIn(cntSites),sitesIn);
        end
    else    
        db_update_TAB_site(yearIn,sitesIn);
    end
else
    db_update_TAB_site(yearIn,sitesIn);
end

% Cycle through all the sites and do site specific chores
% (netCam picture taking, ...)
for currentSiteID = sitesIn
    siteID = char(currentSiteID);
    % Extract site info if Metadata field exists
    if isfield(structProject.sites.(siteID),'Metadata')
        latIn = structProject.sites.(siteID).Metadata.lat;
        longIn = structProject.sites.(siteID).Metadata.long;    
    else
        latIn = 0;
        longIn = 0;
    end

    % Take time-lapse photos only if there is ~isempty(netCam_link)
    netCam_Link = structProject.sites.(siteID).netCam_Link;
    if ~isempty(netCam_Link)
        % Take time-lapse photos only once per hour (min<30) and
        % during "daytime" (globalradiation > 50W)
        % NOTE: potential_radiation() needs West to have positive longIn, hence
        %       the change of sign below! It also needs GMT time 
        siteUTCtime = convert_PCtime2UTC;   
        if potential_radiation(siteUTCtime,latIn,-longIn) > 50 && minute(datetime)<30
            dtStart = datetime;
            fprintf('  Taking %s Phenocam picture. %s\n',siteID,dtStart);
            hourIn = hour(datetime);
            
            take_Phenocam_picture(siteID,netCam_Link,hourIn);  
            fprintf('Finished. (Duration: %s)\n',datetime-dtStart);
        end
    end
end

% Run cleaning stage 1 and 2 (use parallel processing toolbox if avaliable)
pp_automated_cleaning(yearIn,sitesIn,[1 2]);

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
