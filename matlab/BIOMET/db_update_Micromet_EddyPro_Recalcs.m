function db_update_Micromet_EddyPro_Recalcs(yearIn,sitesIn,flagProcessBiometEddyProFiles)
% Convert EddyPro recalc files to database (read_bor()) files
%
%
% Zoran Nesic       File created:       Aug 24, 2022
%                   Last modification:  Feb 28, 2024 
% 


% Revisions:
%
% Feb 28, 2024 (Zoran)
%   - added conversion to a cell for the single sitID inputed as a char.
%   - syntax cleanup
% Feb 16, 2024 (Zoran)
%   - changed fr_SmartFlux_database to fr_EddyPro_database
% Jul 22, 2023 (Zoran)
%  - Added option to use a different path to "Sites" folder if there is a file
%    biomet_sites_default.m on the path. Otherwise the program defaults to "p:\Sites'
%  - Removed conversion of all "\" and "/" into "/". I think that fullfile handles that the right way.
% Oct 24, 2022 (Zoran)
%   - pointed input path for the database to be p:/ 
%     (not //vinimet.geog.ubc.ca/projects as before.
% Aug 29, 2022 (Zoran)
%   - A small change in an fprintf() line.


arg_default('yearIn',year(datetime));
arg_default('sitesIn',{'BB'});
arg_default('flagProcessBiometEddyProFiles',0);

if exist('biomet_sites_default.m','file')
    sites_pth = biomet_sites_default;
else
    sites_pth = 'p:\Sites';
end

missingPointValue = NaN;            % For Micromet sites we'll use NaN to indicate missing values (new feature since Oct 20, 2019)

pth_db = db_pth_root; 

if ~iscellstr(sitesIn) %#ok<ISCLSTR>
    % Assume it is a string with a single SiteId
    sitesIn = cellstr(sitesIn);
end

for cntYear=1:length(yearIn)
    for cntSites=1:length(sitesIn)
        siteID = char(sitesIn(cntSites));
        fprintf('\n**** Processing Year: %d, Site: %s   *************\n',yearIn(cntYear),siteID);

        % Progress list for EddyPro files
        progressListPath = fullfile(pth_db,sprintf('%s_EddyPro_progressList_%d.mat',siteID,yearIn(cntYear)));

        % Path to Flux Database
        outputPath = fullfile(pth_db,'yyyy',siteID,'Flux');
        % Path to the source files
        inputPath = fullfile(sites_pth,...
                           sprintf('%s/Flux/eddypro_%s_%d*_full_output*_adv.csv',siteID,siteID,yearIn(cntYear)));
        % Process the new files
        [numOfFilesProcessed,numOfDataPointsProcessed]= fr_EddyPro_database(inputPath,progressListPath,outputPath,[],[],missingPointValue);
        fprintf('%s  EddyPro_full_output:  Number of files processed = %d, Number of HHours = %d\n',siteID,numOfFilesProcessed,numOfDataPointsProcessed);
        
        % Check if processing of Biomet EddyPro output files is requested
        if flagProcessBiometEddyProFiles ~= 0
            % Data goes to Met folder in the database
            % Path to Met Database
            outputPath = fullfile(pth_db,'yyyy',siteID,'Met');
            % Path to the source files
            inputPath = fullfile(sites_pth,...
                               sprintf('%s/Flux/eddypro_%s_%d*_biomet*_adv.csv',siteID,siteID,yearIn(cntYear)));
            % Process the new files
            [numOfFilesProcessed,numOfDataPointsProcessed]= fr_EddyPro_database(inputPath,progressListPath,outputPath,[],[],missingPointValue);
            fprintf('%s  EddyPro_biomet:  Number of files processed = %d, Number of HHours = %d\n',siteID,numOfFilesProcessed,numOfDataPointsProcessed);
        end
    end %j  site counter
    
end %k   year counter

