function db_ERA5_data_retrieval(siteID,yearRange,monthRange,biometPath)

if ispc
    pth_sep = '\';
elseif ismac
    pth_sep = '/';
end

% Folder where current function is located
file_path = fileparts(which('db_ERA5_data_retrieval'));
path_parts = regexp(file_path,pth_sep,'split');
root_pth = sprintf("%s%s%s",path_parts{1},pth_sep,path_parts{2});

[yearNow,monthNow,~]= datevec(datetime("now"));
arg_default('yearRange',yearNow);               % default year is now
arg_default('monthRange',monthNow-1:monthNow)   % default month is previous month
arg_default('biometPath',root_pth)

% Save raw ERA5 data to temporary directory
pathToMatlabTemp = fullfile(tempdir,'MatlabTemp',siteID);
if ~exist(pathToMatlabTemp,'dir')
    mkdir(pathToMatlabTemp);
end

pathToPythonScript = fullfile(biometPath,'Python','ERA5_EC_pipeline.py');

% Path for siteID.yml
path_yml = fullfile(biomet_database_default,'Calculation_Procedures',...
    'TraceAnalysis_ini',siteID,char([siteID '_config.yml']));

if ~isfile(path_yml)
    fprintf('Could not find: %s\n',path_yml)
    disp('Aborting ERA5 data retrieval!')
    return
end

% Retrieve lat-lon from siteID.yml file
yml_data = yaml.loadFile(path_yml);

lat = [];
lon = [];

if isfield(yml_data,'Metadata')
    if isfield(yml_data.Metadata,'lat') && isfield(yml_data.Metadata,'long')
        lat = yml_data.Metadata.lat;
        lon = yml_data.Metadata.long;
    end
end

if isempty(lat) | isempty(lon)
    disp('Missing metadata. Check that lat and long are specified in the _config.yml file.')
    disp('Aborting ERA5 data retrieval!')
    return
end


%% Run API request for ERA5 download
%--> Retrieves hourly ERA5 data in one month batches

% Input argument order:
% [0] script; [1] start year; [2] end year; [3] start month; [4] end month
%   [5] latitude; [6] longitude

% Python script uses CDS API
cmd_str = sprintf("%s %d %d %d %d %3.4f %3.4f %s",pathToPythonScript,yearRange(1),...
    yearRange(end),monthRange(1),monthRange(end), lat, lon, pathToMatlabTemp);
% cmd_test = "F:\EcoFlux lab\Matlab\ERA5_EC_pipeline.py 2001 2024 1 12 52.9 -85.94 'F:\ERA5\temp\'";

pyrunfile(cmd_str);
