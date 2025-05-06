function thirdStageIni = createAmerifluxThirdStageIni(structProject,dbID,siteID,siteID_origin)
% Create the third stage YAML defaults for the given Ameriflux data set
% using the TMP_config.yml template.
%
% The function assumes that the Ameriflux BIF file is stored in an already existing
% project folder (.../projectName/Sites/siteID/Flux).
%
% Input:
%   structProject       - the structure obtained by a call to set_TAB_project
%   dbID                - 'AMF' for Ameriflux
%   siteID              - Usually matches Ameriflux SITE_ID but with all caps and without '-'
%                         Example: 'BR-Npw' => 'BRNPW'
%   siteID_origin       - Original Ameriflux SITE_ID
%                         Example: 'BR-Npw'
%
% Output:
%   thirdStageIni       - structure containing fields extraced from the BIF file:
%                         {'startYear','startMonth','startDay', 'lat','long','GMT_offset'}
%
%
% Example:
%   Assumptions:
%       - There are two files downloaded for an Ameriflux site:
%           - AMF_BR-Npw_BASE_HH_1-5.csv
%           - AMF_BR-Npw_BIF_*.xlsx
%   First define setup parameters:
%       dbID = 'AMF';
%       siteID_origin = 'BR-Npw';
%       siteID = 'BRNPW';
%       pathProject = 'E:\Pipeline_Projects\Data44';
%       dataFileName = 'AMF_BR-Npw_BASE_HH_1-5.csv';
%
%   Call main function:
%       thirdStageIni = createAmerifluxThirdStageIni(structProject,dbID,siteID,siteID_origin);
%
% Notes
% This function is meant to get the user quickly starte. Some ini and yml files
% may need manual editing for better tuning.
%
%
%
% Zoran Nesic               File created:           Mar  6, 2025
%                           Last modification:      Mar 14, 2025

% Revisions
%
% Mar 14, 2025 (Zoran)
%   - added better testing for startDate. The function now checks two different
%     variables: 'LOCATION_DATE_START' and 'FLUX_MEASUREMENTS_DATE_START'
%     Better handling of missing month and day fields. 
%     If multiple 'FLUX_MEASUREMENTS_DATE_START' rows are found, use only the first one!
%     If there are no valid start date fields, use the default 19000101 (Jan 1, 1900)


pathYmlTemplate = fullfile(structProject.databasePath,'Calculation_Procedures','TraceAnalysis_ini','TMP_config.yml');
pathSiteIni = fullfile(structProject.databasePath,'Calculation_Procedures','TraceAnalysis_ini',siteID,[ siteID '_config.yml']);

siteBADM = fullfile(structProject.sitesPath,siteID,'Flux',[dbID '_' siteID_origin '_BIF_*.xlsx']);
s = dir(siteBADM);
if isempty(s)
    error('File: %s does not exist!\n',siteBADM);
end

% load metaData
siteBADM = fullfile(s(1).folder,s(1).name);
metaData = readtable(siteBADM);
% Extract info from metaData 
% Extract startYear
% This information could be in a few different fields. 
% Try them one at the time.
rowDate = find(strcmpi(metaData.VARIABLE,'LOCATION_DATE_START'));
if isempty(rowDate)
    rowDate = find(strcmpi(metaData.VARIABLE,'FLUX_MEASUREMENTS_DATE_START'));
end
if isempty(rowDate)
    % Couldn't find the date when the measurements started. 
    % Default to 1900
    startYear = '19000101';
end
try
    startYear = char(table2array(metaData(rowDate(1),5)));    
    thirdStageIni.startYear = str2double(startYear(1:4));
    if length(startYear)>= 8
        thirdStageIni.startMonth = str2double(startYear(5:6));
        thirdStageIni.startDay = str2double(startYear(7:8));
    else
        fprintf(2,'Month and date of the site start date not found. Using Jan 1.\n');
        thirdStageIni.startMonth = 1;
        thirdStageIni.startDay = 1;
    end

catch
    fprintf(2,'There was an issue trying to find the site start date. Using 1900-01-01.\n');
    thirdStageIni.startYear = 1900;
    thirdStageIni.startMonth = 1;
    thirdStageIni.startDay = 1;
end    
%
% Extract lat & long
rowDate = find(strcmpi(metaData.VARIABLE,'LOCATION_LAT'));
locLAT = char(table2array(metaData(rowDate,5)));
thirdStageIni.lat = str2double(locLAT);

rowDate = find(strcmpi(metaData.VARIABLE,'LOCATION_LONG'));
locLONG = char(table2array(metaData(rowDate,5)));
thirdStageIni.long = str2double(locLONG);

% Extract UTC offset
rowDate = find(strcmpi(metaData.VARIABLE,'UTC_OFFSET'));
UTC_offset = char(table2array(metaData(rowDate,5)));
thirdStageIni.GMT_offset = str2double(UTC_offset);

% Extract SITE_NAME
rowDate = find(strcmpi(metaData.VARIABLE,'SITE_NAME'));
if isempty(rowDate)
    siteName = [];
else
    siteName = char(table2array(metaData(rowDate(1),5)));
    thirdStageIni.siteName = siteName;
end

fprintf('---------------------------\n');
fprintf('Creating template file: %s\n',pathSiteIni);

% saving YAML file 
% Use the TMP_config.yml template and replace the
% info there with the info from the BIF file
fidIn = fopen(pathYmlTemplate);
if fidIn >0
    fidOut = fopen(pathSiteIni,"w");
    if fidOut < 0 
        error('Cannot open output file: %s',pathSiteIni);
    end
    while ~feof(fidIn)
        oneLine = fgetl(fidIn);
        if startsWith(strtrim(oneLine),'siteID')
            oneLine = [oneLine(1:find(oneLine==':')) ' ' siteID];
        elseif startsWith(strtrim(oneLine),'estYear')
            oneLine = [oneLine(1:find(oneLine==':')) ' ' startYear(1:4)];
        elseif startsWith(strtrim(oneLine),'lat')
            oneLine = [oneLine(1:find(oneLine==':')) ' ' locLAT];
        elseif startsWith(strtrim(oneLine),'long')
            oneLine = [oneLine(1:find(oneLine==':')) ' ' locLONG];
        elseif startsWith(strtrim(oneLine),'TimeZoneHour')
            oneLine = [oneLine(1:find(oneLine==':')) ' ' UTC_offset];
        end
     
        fprintf(fidOut,'%s\n',oneLine);
    end
end
fclose(fidIn);
fclose(fidOut);
fprintf('Template created: %s\n',pathSiteIni);



