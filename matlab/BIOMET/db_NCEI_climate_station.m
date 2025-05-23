function db_NCEI_climate_station(yearRange,UTC2local,stationID,dbPath,timeUnit) 
%
% Inputs:
%   yearRange       - years to process (2020:2022)
%   UTC2local       - Hours +/- to add to TimeVector to make local time
%   stationID       - station ID
%   dbPath          - path where data goes. It has to contain "yyyy"
%                     (p:\database\yyyy\BB1\MET\ECCC)
%   timeUnit        - data sample rate in minutes (default for ECCC is '60MIN')
%
%
% Paul Moore                File created:       Jan 09, 2025
%                           Last modification:  Jan 15, 2025

% Revisions:
% May 22, 2025 (Paul)
%   - Reporting time and intervals are not necessarily hourly or consistent
%       so adopted an approach where data is interpolated to hourly for
%       periods which don't have multi-hour gaps.
% Jan 15, 2025 (Paul)
%   - Fixed time offset (supposed to be hours, not days)
%   - Station list can be found at: https://www.ncei.noaa.gov/pub/data/noaa/isd-history.txt
%   - stationID is the USAF and WBAN numbers combined into an 11-digit number
%   - Map view of ISD stations: https://www.ncei.noaa.gov/access/search/data-search/global-hourly

[yearNow,~,~]= datevec(now);
arg_default('yearRange',yearNow);               % default year is now
arg_default('UTC2local',0)                      % default offset is 0
arg_default('stationID',72785794129);           % default station is Pullman Moscow regional airport
arg_default('timeUnit','60MIN');                % data is hourly (60 minutes)
arg_default('dbPath','');

if isempty(dbPath)
    dbPath = fullfile(biomet_database_default,'yyyy','ECCC',num2str(stationID));
end

pathToMatlabTemp = fullfile(tempdir,'MatlabTemp');
if ~exist(pathToMatlabTemp,'dir')
    mkdir(pathToMatlabTemp);
end
tempFileName = fullfile(pathToMatlabTemp,'junk9999.csv');  % temp file name

for yearIn = yearRange
    fprintf('Processing: StationID = %s, Year = %d\n',stationID,yearIn);
    urlDataSource = sprintf('https://www.ncei.noaa.gov/data/global-hourly/access/%d/%s.csv',...
                            yearIn,stationID);
    options = weboptions('Timeout',20);     % set timeout for websave to 20 seconds (default is 5)
    
    % Retirieve file and save to temporary file
    websave(tempFileName,urlDataSource,options);
    
    % Extract data from temporary file
    [Stats0,~,~] = fr_read_NCEI_file(tempFileName,[],[],1);
    delete(tempFileName);
    
    % Adjust time 
    TimeVector = get_stats_field(Stats0,'TimeVector') + UTC2local./24;
    
    % Extract hourly data adjusted for UTC offset
    tv_hr = (datenum(yearIn,1,1,0,0,0):1/24:datenum(yearIn,12,31,23,0,0))' + UTC2local./24;

    for cnt=1:length(tv_hr)
        Stats(cnt).TimeVector = tv_hr(cnt);
    end

    % Get time interval between reported values
    dt = [0; diff(TimeVector)];
    dt_hr = 1440 .* interp1(TimeVector,dt,tv_hr,'linear','extrap');
    idx = dt_hr>65; % Multi-hour gaps not suitable for interpolation

    fn = fieldnames(Stats0);
    for i=1:length(fn)
        if ~strcmpi(fn{i},'TimeVector')
            y_orig = get_stats_field(Stats0,fn{i});
            
            % Interpolate data onto an hour interval
            y_hr = interp1(TimeVector,y_orig,tv_hr,'linear','extrap');

            % Replace multi-hour gaps in original data with NaN
            y_hr(idx) = NaN;
    
            for cnt=1:length(tv_hr)
                Stats(cnt).(fn{i}) = y_hr(cnt);
            end
        end
    end

    % Set reporting time interval
    interval_round = 'hour';
    TimeVector = get_stats_field(Stats,'TimeVector');

    for cnt = 1:length(TimeVector)
        Stats(cnt).TimeVector = fr_round_time(TimeVector(cnt),interval_round,1);
    end

    % Remove creation of duplicates
    % --> This shouldn't be an issue with the new approach (Paul-2025-05-22)
    TimeVector = get_stats_field(Stats,'TimeVector');
    idx = 1440 .* diff([0;TimeVector])>0;
    Stats = Stats(idx);

    datetimeTV = datetime(TimeVector,'convertfrom','datenum');
    years = unique(year(datetimeTV));
    for currentYear = years(1):years(end)
        if strcmp(interval_round,'hour')
            % fprintf('Processing: StationID = %d, Year = %d\n',stationID,currentYear);
            fprintf('Saving 60-min data to %s folder.\n',dbPath);
    
            db_struct2database(Stats,dbPath,0,[],timeUnit,NaN,0,1);
            % now interpolate data from 60- to 30- min time periods
            % and shift it by 30 min forward.
            % generic TimeVector for GMT time
            TimeVector30min = fr_round_time(datenum(currentYear,1,1,0,0,0):1/48:datenum(currentYear,12,31,23,30,0));
            Stats30min = interp_Struct(Stats,TimeVector30min);
            db30minPath = fullfile(dbPath,'30min');
                        
            fprintf('Saving 30-min data to %s folder.\n',db30minPath);
            %db_save_struct(Stats30min,db30minPath,[],[],30,NaN);
            db_struct2database(Stats30min,db30minPath,0,[],'30MIN',NaN,0,1);
        elseif strcmp(interval_round,'30min')
            db30minPath = fullfile(dbPath,'30min');
            fprintf('Saving 30-min data to %s folder.\n',db30minPath);
            db_struct2database(Stats,dbPath,0,[],timeUnit,NaN,0,1);
        end
    end
end


function Stats_interp = interp_Struct(Stats,TimeVector30min)

tv_ECCC60min = get_stats_field(Stats,'TimeVector');
% find the time period
TimeVector30min = TimeVector30min(TimeVector30min >= tv_ECCC60min(1) & TimeVector30min <= tv_ECCC60min(end)); 

N = length(TimeVector30min);
% interpolate all data traces to go from 60-min to 30-min
% period    
fnames= fieldnames(Stats);
for k = 1:numel(fnames)
    if ~strcmpi(char(fnames{k}),'TimeVector')
        % extract 60-min data
        x60min = get_stats_field(Stats,char(fnames{k}));
        % interpolate it to double the samples (30-min)
        x = interp1(tv_ECCC60min,x60min,TimeVector30min,'linear','extrap');
	    if strcmpi(char(fnames{k}),'Precip')
			x = x/2;
		end
        % create a Stats_interp field
        for cnt=1:N
            Stats_interp(cnt).(char(fnames{k})) = x(cnt); %#ok<*AGROW>
        end
    else
        for cnt=1:N
            Stats_interp(cnt).TimeVector = TimeVector30min(cnt);
        end
    end
end