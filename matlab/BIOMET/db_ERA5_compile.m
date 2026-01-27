function db_ERA5_compile(siteID,deleteFile)

% Inputs:
% pathToMatlabTemp  - location where ERA5 data saved to
% siteID            - site identifier in database
% deleteFile        - [1] deletes .nc file after processing; [0] keep files

arg_default('deleteFile',0);    % Only delete .nc files if explicitly included

% Location where ERA5 data has been saved to
pathToMatlabTemp = fullfile(tempdir,'MatlabTemp',siteID);

% Currently set to process dew point temperature (d2m - °K)), air 
% temperature (t2m - °K), and incoming shortwave radiation (ssrd - W m^-2)
varStr_nc = {'d2m','t2m','ssrd'};
varStr_file = {'2m_dewpoint_temperature','2m_temperature',...
    'surface_solar_radiation_downwards'};

dataSource = 'ERA5';
pthOutMet = fullfile(biomet_database_default,'yyyy',dataSource,siteID);
structType = 1;  %0 - old and slow, 1 - new and fast
timeUnit = '30min';
missingPointValue = NaN;

% Path for siteID.yml
path_yml = fullfile(biomet_database_default,'Calculation_Procedures',...
    'TraceAnalysis_ini',siteID,char([siteID '_config.yml']));

% If run in series with 'db_ERA5_data_retrieval.m', the error check below
%   is redundant.
if ~isfile(path_yml)
    fprintf('Could not find: %s\n',path_yml)
    disp('Aborting!')
end

% Retrieve lat-lon from siteID.yml file
yml_data = yaml.loadFile(path_yml);

lat_target = [];
lon_target = [];
GMT_offset = [];

if isfield(yml_data,'Metadata')
    if isfield(yml_data.Metadata,'lat') && isfield(yml_data.Metadata,'long')
        lat_target = yml_data.Metadata.lat;
        lon_target = yml_data.Metadata.long;
    end

    if isfield(yml_data.Metadata,'TimeZoneHour')
        GMT_offset = yml_data.Metadata.TimeZoneHour .* 3600; % Converts from hours to minutes
    end
end

if isempty(lat_target) | isempty(lon_target) | isempty(GMT_offset)
    disp('Missing metadata. Check that lat, long, and TimeZoneHour are specified in the _config.yml file.')
    disp('Aborting!')
    return
end


for i=1:length(varStr_file)
    % Get list of .nc files from 'pathToMatlabTemp' folder for given variable
    files = dir(fullfile(pathToMatlabTemp,char([varStr_file{i} '*.nc'])));
    for j=1:length(files)
        ERA5_data = struct();
        
        source = fullfile(pathToMatlabTemp,files(j).name);
    
        % Get latitude and longitude in ERA5 .nc file
        lat = ncread(source,'latitude');
        lon = ncread(source,'longitude');
        
        % lat_mat should proceed from north to shouth from left to right
        % lon_mat should proceed from west to east from top to bottom
        [lat_mat,lon_mat] = meshgrid(lat,lon);
        
        % Seconds since 1970-01-01
        tv = ncread(source,'valid_time') + GMT_offset;
        tv = double(tv)./86400; % Days since 1970-01-01
        tv = tv + datenum(1970,1,1); % Matlab format
        % tv_dt = datetime(tv,'ConvertFrom','datenum');
    
        raw = ncread(source,varStr_nc{i},[1,1,1],[3 3 Inf]);
        N = size(raw,3);
        spatial_interp = nan(N,1);
        for k=1:N
            tmp = squeeze(raw(:,:,k));
            F = scatteredInterpolant(lon_mat(:),lat_mat(:),tmp(:));
            spatial_interp(k,1) = F(lon_target,lat_target);
        end
        
        % Unit conversion
        switch varStr_nc{i}
            case {'t2m','d2m'}
                spatial_interp = spatial_interp - 273.15; % Convert to °C

                % Note: to convert dew point temperature to RH, you need to
                %   have ambient air temperature. As such, RH should be
                %   calculated at a later point.
            case 'ssrd'
                spatial_interp = [diff(spatial_interp); 0]; % Convert to hourly from accumulated
                spatial_interp(spatial_interp<0) = 0;
                spatial_interp = spatial_interp./3600; % Convert to W m^-2
        end

        % Interpolate data to be half-hourly
        x = 2.*(1:length(spatial_interp))';
        xi = (1:(2*length(spatial_interp)))';
        tmp_interp = interp1(x,spatial_interp,xi);
        tv_interp = interp1(x,tv,xi);
        tv_interp = fr_round_time(tv_interp,'30min');

        % Add variable to structure
        ERA5_data.(varStr_nc{i}) = tmp_interp;
        ERA5_data.TimeVector = tv_interp;

        % Save data to binary files in database
        db_struct2database(ERA5_data,pthOutMet,0,[],timeUnit,missingPointValue,structType,1);
        
        if deleteFile==1
            delete(source)
        end
    end
end

% Delete temporary folder if it's empty
if deleteFile==1
    [status,msg] = rmdir(pathToMatlabTemp);

    if status==0
        disp(msg)
    end
end