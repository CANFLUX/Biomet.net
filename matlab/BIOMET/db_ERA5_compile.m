function db_ERA5_compile(siteID,deleteFile)

% Inputs:
% siteID            - site identifier in database
% deleteFile        - [1] deletes .nc file after processing; [0] keep files

arg_default('deleteFile',0);    % Only delete .nc files if explicitly chosen

% Location where ERA5 data has been saved to
pathToMatlabTemp = fullfile(tempdir,'MatlabTemp',siteID);

% Currently set to process dew point temperature (d2m - °K)), air 
%   temperature (t2m - °K), incoming shortwave radiation (ssrd - J hr^-1 m^-2),
%   surface pressure (sp - Pa), and total precipitation (tp - m).
varStr_nc = {'d2m','t2m','ssrd','sp','tp'};
varStr_file = {'2m_dewpoint_temperature','2m_temperature',...
    'surface_solar_radiation_downwards','surface_pressure',...
    'total_precipitation'};

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
        GMT_offset = yml_data.Metadata.TimeZoneHour;
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
        
        % Get time units
        info = ncinfo(source);
        varNames = {info.Variables.Name};
        idx1 = strcmp(varNames,'valid_time');
        ind1 = 1:length(idx1);
        varNames = {info.Variables(ind1(idx1)).Attributes.Name};
        idx2 = strcmp(varNames,'units');
        ind2 = 1:length(idx2);
        unitStr = info.Variables(ind1(idx1)).Attributes(ind2(idx2)).Value;
        
        % Get latitude and longitude in ERA5 .nc file
        lat = ncread(source,'latitude');
        lon = ncread(source,'longitude');
        
        % lat_mat should proceed from north to shouth from left to right
        % lon_mat should proceed from west to east from top to bottom
        [lat_mat,lon_mat] = meshgrid(lat,lon);
        
        if contains(unitStr,'hours')
            % Hours since 1970-01-01
            CF = 24;
        else
            % Seconds since 1970-01-01
            GMT_offset = GMT_offset .* 3600;
            CF = 86400; % Conversion factor
        end
        
        tv = ncread(source,'valid_time') + GMT_offset;
        tv = double(tv)./CF; % Days since 1970-01-01
        tv = tv + datenum(1970,1,1); % Matlab format
        % tv_dt = datetime(tv,'ConvertFrom','datenum');
        
        % If data was downloaded using the 'spatial' option, then the data
        %   is spatially interpolated.
        if numel(lat_mat)==1
            start = 1;
            count = Inf;
            interpStr = 'no';
        else
            [dim1, dim2] = size(lat_mat);
            start = [1 1 1];
            count = [dim1 dim2 Inf];
            interpStr = 'yes';
        end
        
        % Read variable data from .nc file
        raw = ncread(source,varStr_nc{i},start,count);
        
        % Interpolate spatial data when necessary
        if strcmp(interpStr,'yes')
            N = size(raw,3);
            data = nan(N,1);
            for k=1:N
                tmp = squeeze(raw(:,:,k));
                idx = ~isnan(tmp);
                if sum(idx(:))>1
                    method = 'linear';
                else
                    method = 'nearst';
                end
                F = scatteredInterpolant(lon_mat(idx),lat_mat(idx),tmp(idx),method);
                data(k,1) = F(lon_target,lat_target);
            end
        else
            data = raw;
        end
        
        % Unit conversion
        switch varStr_nc{i}
            case {'t2m','d2m'}
                data = data - 273.15; % Convert to °C

                % Note: to convert dew point temperature to RH, you need to
                %   have ambient air temperature. As such, RH should be
                %   calculated at a later point.
            case 'ssrd'
                if strcmp(interpStr,'yes')
                    data = [diff(data); 0]; % Convert to hourly from accumulated
                    data(data<0) = 0;
                end
                data = data./3600; % Convert to W m^-2
            case 'sp'
                data = data ./ 1000; % Converts from Pa to kPa
            case 'tp'
                data = data .* 1000; % Converts from m to mm
        end

        % Interpolate data to be half-hourly
        x = 2.*(1:length(data))';
        xi = (1:(2*length(data)))';
        tmp_interp = interp1(x,data,xi);
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