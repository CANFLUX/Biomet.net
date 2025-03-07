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
%   - The create the project folder:
%       create_TAB_ProjectFolders(pathProject,siteID);
%   - Copy those two Ameriflux files to this folder 
%     (the folder was created automatically in the previous step):
%        'E:\Pipeline_Projects\Data44\Sites\BRNPW\Flux'
%   - Set TAB project:
%       structProject=set_TAB_project(pathProject);
%   - Call this function:
%       thirdStageIni = createAmerifluxThirdStageIni(structProject,dbID,siteID,siteID_origin);
%   - The yml file (BRNPW_config.yml) is stored under this folder:
%       'E:\Pipeline_Projects\Data44\Database\Calculation_Procedures\TraceAnalysis_ini\BRNPW'
%
% The user can then edit the newly created yml file manually, if needed.
%
%
%
% Zoran Nesic               File created:           Mar  6, 2025
%                           Last modification:      Mar  6, 2025

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
rowDate = find(strcmpi(metaData.VARIABLE,'location_date_start'));
startYear = char(table2array(metaData(rowDate,5)));
thirdStageIni.startYear = str2double(startYear(1:4));
thirdStageIni.startMonth = str2double(startYear(5:6));
thirdStageIni.startDay = str2double(startYear(7:8));
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



