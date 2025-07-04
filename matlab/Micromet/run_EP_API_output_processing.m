function run_EP_API_output_processing(dateIn,siteID,epapiPath)
%  run_EP_API_output_processing - move EddyPro API outputs to siteID\Flux folder
% 
% Inputs:
%   dateIn              - date of recalculations (folder where EddyPro API output files are saved)
%                         datetime string or a datenum
%   siteID              - site ID (name)
%   epapiPath           - path where EddyPro API stores siteID output files
%
%
% This function transfers EddyPro API (EPAPI) outputs from the EPAPI folder to 
%  Sites\siteID\Flux folder
%
%   
% Example:
%     dateIn = "Jun 30, 2025";
%     siteID = 'OHM';
%     epapiPath = '\\137.82.55.154\highfreq';
%     run_EP_API_output_processing(dateIn,siteID,epapiPath)
%  The function will search inside this folder: \\137.82.55.154\highfreq\siteID
%  for all the sub-folders that match this pattern: 20250603*
%  It will then rename all the EP API output files found in those folders to
%  the standard EP output file-name format:
%     eddypro_siteID_startdate_enddate_full_output_recalctime_adv.csv
%  and store those renamed files into the myProject\Sites\siteID\Flux folder
%
%
%  Note: this function could be updated later so that it processes only the YYYYMMDDHHMM
%        sub-folders that have not been processed already. 
%
%
% (c) Zoran Nesic                   File created:       Jul  4, 2025
%                                   Last modification:  Jul  4, 2025
%
%


%dateIn could be a string/datetime or datenum 
if isnumeric(dateIn)
    % assume that dateIn is datenum
    dateOfProcessing = datetime(dateIn,'convertfrom','datenum');
else
    % assume is datetime or a string
    dateOfProcessing = datetime(dateIn);
end

if length(dateOfProcessing) > 1
    error('dateIn cannot be an array!');
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
        rename_EP_API_files(siteID,epapiFolder,fluxFolder,flagOverwrite);
    end
end