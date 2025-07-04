function run_EP_API_output_processing(dateIn,siteID,epapiPath)
%
% This function transfers EddyPro API (EPAPI) outputs from EPAPI folder to 
%  Sites\siteID\Flux folder
%
% File locations
%   EPAPI outputs:                  apapiPath\siteID\eddyProAPIOutputs\siteID\yyyymmddhhmm
%   renamed EP files:               Sites\siteID\Flux
%   

% for a given subfolder name, find all _full_output_ files and copy them to
% "Sites\Common\EddyPro_Output\siteID\full_output_from_auto_processing_for_Zoran" 
% folder
% (this will be automated later, the program
% will search for the new/unprocessed data folders and process them
% automatically)


%dateIn could be a string/datetime or datenum 
if isnumeric(dateIn)
    % assume that dateIn is datenum
    dateOfProcessing = datetime(dateIn,'convertfrom','datenum');
else
    % assume is datetime or a string
    dateOfProcessing = datetime(dateIn);
end

% Set the location where the properly named EP files should go 
% Usually: Sites\siteID\Flux
% (should this be an input parameter to make it more generic?)
structProject = get_TAB_project;
fluxFolder = fullfile(structProject.sitesPath,siteID,'Flux');

% The EddyPro API (EPAPI) 
dateOfProcessing.Format = 'uuuuMMdd';
apiOutputFolder = fullfile(epapiPath,siteID,'eddyProAPIOutputs',[char(dateOfProcessing) '*']);
apiOutputFolder = dir(apiOutputFolder);
% NOTE: apiOutputFolder contains all folders with the same YYYYMMDD*
%       pattern. If there were multiple calculation runs of the same or
%       of the overlapping date periods then the order of the processing is not
%       determined. That means that some test (bad) runs from the same day could
%       overwrite the final "good" results. It's up to user to delete the
%       test runs.
for cntFolders = 1:length(apiOutputFolder)
    if apiOutputFolder(cntFolders).isdir
        epapiFolder = fullfile(apiOutputFolder(cntFolders).folder,apiOutputFolder(cntFolders).name);
        % Rename EP API output file to the Ecoflux/Micromet standardized EP name outputs
        flagOverwrite = 0;
        nFiles = rename_EP_API_files(siteID,epapiFolder,fluxFolder,flagOverwrite);
    end
end