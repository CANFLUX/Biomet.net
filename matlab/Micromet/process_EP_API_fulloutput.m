function process_EP_API_fulloutput(allSites,pthEPAPI_main,pthEP_main,flagCreate,flagOverwrite)
% process_EP_API_fulloutput - copy and rename EddyPro_API output files to acceptible EP _fulloutput_ names
%
% Arguments
%
%   allSites             - cell array of siteIDs of the sites that need to be processed
%   pthEPAPI_main       - API outputs path
%   pthEP_main          - path for renamed files
%   flagCreate          - true  (create the entire pthEP_main path if it doesn't exist)
%                         false (default) (error if pthEP_main doesn't exist)
%   flagOverwrite       - true  (overwrite _fulloutput_ file)
%                         false (default, don't overwrite _fulloutput_ files)
%
%
% NOTE:  ALL output folders under pthEPAPI_main (named: yyyymmddHHMM) are
%        going to be processed. If this is not what is wanted, move those files
%        or rename them so the names don't match the format 2yyymmddHHMM.
%
%
% Zoran Nesic               File created:       Aug 14, 2025
%                           Last modification:  Aug 26, 2025

% Revisions
%
% Aug 26, 2025 (Zoran)
%   - Added a test if allSites is a cell array

arg_default('flagCreate',false)
arg_default('flagOverwrite',0)
% default is to process all sites
allSitesTmp        = get_TAB_site_names;
arg_default('allSites',allSitesTmp)
if ~iscell(allSites)
    error('allSites needs to be a cell array of sites!');
end

fprintf('\n======================\nRenaming EddyPro API output files started...\n\n');
for cSite = allSites
    siteID = char(cSite);
    pthIn = fullfile(pthEPAPI_main,siteID);
    pthOut = fullfile(pthEP_main,siteID);
    % Find all folders that are in the formated like this: 2xxxxxxxxxx
    % and assume that they are time stamps: yyyymmddHHMM
    % those folders are what EP API creates after each run
    allFolders  = dir(fullfile(pthIn,'2*'));
    allFolders  = allFolders([allFolders(:).isdir]);
    folderNames = {allFolders(:).name};
    % Load up the list of folders that were previously processed
    pthProgressList = fullfile(pthIn,'progressList.mat');
    if exist(pthProgressList,'file')
        load(pthProgressList,'progressList');
    else
        progressList = [];
    end
    for  cFolder = folderNames
        fName = char(cFolder);
        % if the folder hasn't been processed before run it now
        if ~any(ismember(progressList,fName))
            try
                fprintf('Renaming files in: %6s\\%s\n',siteID,fName);
                inputPath = fullfile(pthIn,fName);            
                result = existFolder(pthOut,flagCreate);                     
                cntFiles = rename_EP_API_files(siteID,inputPath,pthOut,flagOverwrite);
                % if renaming finished without error, add folder to the
                % progress list
                progressList{length(progressList)+1} = fName;
                save(pthProgressList,'progressList');
            catch ME
            end
        end
    end
end
fprintf('Done.\n\n');
