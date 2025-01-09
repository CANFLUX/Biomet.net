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
%                           Last modification:  
%

% Revisions:
%

[yearNow,~,~]= datevec(now);
arg_default('yearRange',yearNow);               % default year is now
arg_default('UTC2local',0)                      % default offset is 0
arg_default('stationID',72785794129);           % default station is Pullman Moscow regional airport
arg_default('timeUnit','60MIN');                % data is hourly (60 minutes)

pathToMatlabTemp = fullfile(tempdir,'MatlabTemp');
if ~exist(pathToMatlabTemp,'dir')
    mkdir(pathToMatlabTemp);
end
tempFileName = fullfile(pathToMatlabTemp,'junk9999.csv');  % temp file name

for yearIn = yearRange
    fprintf('Processing: StationID = %d, Year = %d\n',stationID,yearIn);
    urlDataSource = sprintf('https://www.ncei.noaa.gov/data/global-hourly/access/%d/%d.csv',...
                            yearIn,stationID);
    options = weboptions('Timeout',20);     % set timeout for websave to 20 seconds (default is 5)
    
    % Retirieve file and save to temporary file
    websave(tempFileName,urlDataSource,options);
    
    % Extract data from temporary file
    [Stats,~,~] = fr_read_NCEI_file(tempFileName,[],[],1);
    delete(tempFileName);
    
    % Adjust time 
    % Note: The Pullman Moscow station reports at 58 minutes past the hour
    %   so it seems reasonable to just round to the nearest hour. However,
    %   whether this applies to all weather station data needs to be
    %   assessed.
    TimeVector = get_stats_field(Stats,'TimeVector') + UTC2local;
    for cnt = 1:length(TimeVector)
        Stats(cnt).TimeVector = fr_round_time(TimeVector(cnt),'hour',1);
    end

    datetimeTV = datetime(TimeVector,'convertfrom','datenum');
    years = unique(year(datetimeTV));
    for currentYear = years(1):years(end)
        % fprintf('Processing: StationID = %d, Year = %d\n',stationID,currentYear);
        fprintf('Saving 60-min data to %s folder.\n',dbPath);

        db_struct2database(Stats,dbPath,0,[],timeUnit,NaN,0,1);
        % now interpolate data from 60- to 30- min time periods
        % and shift it by 30 min forward.
        % generic TimeVector for GMT time
        TimeVector30min = fr_round_time(datenum(currentYear,1,1,0,30,0):1/48:datenum(currentYear+1,1,1));
        Stats30min = interp_Struct(Stats,TimeVector30min);
        db30minPath = fullfile(dbPath,'30min');
                    
        fprintf('Saving 30-min data to %s folder.\n',db30minPath);
        %db_save_struct(Stats30min,db30minPath,[],[],30,NaN);
        db_struct2database(Stats30min,db30minPath,0,[],'30MIN',NaN,0,1);
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