function db_ERA5_data_retrieval(siteID,dateStart,dateEnd,biometPath,type)
%==========================================================================
% The function downloads hourly ERA5 land data by calling the CDS API using
%   a Python script (ERA5_EC_pipeline_ts.py). The function can be called in
%   a first stage INI file using the Evaluate statement within a dummy
%   variable.
% For now, the following variables are downloaded by default: (1) 2-m dew 
%   point temperature; (2) 2-m air temperature; (3) surface incoming solar
%   radiation; (4) surface pressure; and (5) total precipitation. This 
%   could be modified so that the Python script accepts an optional input 
%   for alternate/additional variables.
%
% Example(s):
% --> Command line
% db_ERA5_data_retrieval('DSM','2024-01-01','2025-12-31')
%
% --> First stage INI
% [Trace]
% 	variableName = 'ERA_API'
% 	title = 'Used to call ERA API'
% 	inputFileName = {'clean_tv'}
% 	measurementType = 'met'
% 	units = ''
%   Evaluate = 'db_ERA5_data_retrieval(char("TST"),"2024-01-01","2025-12-31");
%               db_ERA5_compile(char("TST"),1);'
% [End]
%
%==========================================================================

if ispc
    pth_sep = '\';
elseif ismac
    pth_sep = '/';
end

% Folder where current function is located
file_path = fileparts(which('db_ERA5_data_retrieval'));
path_parts = regexp(file_path,pth_sep,'split');
root_pth = sprintf("%s%s%s",path_parts{1},pth_sep,path_parts{2});

% Default is to pull the past year of data
tmp = today; %#ok<TTDAY1>
arg_default('dateStart',char(datetime(tmp-366,'convertfrom','datenum','format','yyyy-MM-dd'))); %#ok<*DATST>
arg_default('dateEnd',char(datetime(tmp-366,'convertfrom','datenum','format','yyyy-MM-dd')));
arg_default('biometPath',root_pth)
arg_default('type','ts')

% Save raw ERA5 data to temporary directory
if strcmp(tempdir,'/tmp') & ~ispc
    % /var/tmp is not cleared on reboot
    pathToMatlabTemp = fullfile('/var/tmp','MatlabTemp',siteID);
else
    pathToMatlabTemp = fullfile(tempdir,'MatlabTemp',siteID);
end
if ~exist(pathToMatlabTemp,'dir')
    mkdir(pathToMatlabTemp);
end

% The 'ts' option downloads an API optimized time series for a single 
%   location from the ERA5 dataset. The 'ts' option is much faster than a
%   call to the "reanalysis-era5-land" spatial dataset.
if strcmp(type,'ts')
    pathToPythonScript = fullfile(biometPath,'Python','ERA5_EC_pipeline_ts.py');
elseif strcmp(type,'spatial')
    pathToPythonScript = fullfile(biometPath,'Python','ERA5_EC_pipeline.py');
end

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

if strcmp(type,'ts')
    % Input argument order:
    % [0] script; [1] start date; [2] end date; [3] latitude;
    %   [4] longitude; [5] output directory
    
    % Python script uses CDS API
    cmd_str = sprintf("%s %s %s %3.1f %3.1f %s",pathToPythonScript,...
        dateStart, dateEnd, lat, lon, pathToMatlabTemp);

elseif strcmp(type,'spatial')
    % Input argument order:
    % [0] script; [1] start year; [2] end year; [3] start month; [4] end month
    %   [5] latitude; [6] longitude; [7] output directory
    
    [yearStart,mnthStart,~] = datevec(dateStart);
    [yearEnd,mnthEnd,~] = datevec(dateStart);

    if yearStart~=YearEnd
        mnthStart = 1;
        mnthEnd = 12;
    end

    % Python script uses CDS API
    cmd_str = sprintf("%s %d %d %d %d %3.4f %3.4f %s",pathToPythonScript,yearStart,...
        yearEnd,mnthStart,mnthEnd, lat, lon, pathToMatlabTemp);
end

pyrunfile(cmd_str);

%% Extract and rename .zip files
% The 'ts' dataset can only be downloaded as .zip files

if strcmp(type,'ts')
    varStr = {'2m_dewpoint_temperature','2m_temperature',...
            'surface_solar_radiation_downwards','surface_pressure',...
            'total_precipitation'};
    
    for i=1:length(varStr)
        pathToZipFile = fullfile(pathToMatlabTemp,char([varStr{i} '.zip']));
    
        if isfile(pathToZipFile)
            % Unzip ERA data
            file2rename = unzip(pathToZipFile,pathToMatlabTemp);
    
            % Rename .nc file
            dest = fullfile(pathToMatlabTemp,char([varStr{i} '.nc']));
            movefile(file2rename{1},dest)
            
            % Delete .zip file
            delete(pathToZipFile)
        end
    end
end