function db_ECCC_climate_station(yearRange,monthRange,stationID,dbPath,timeUnit) 
% db_ECCC_climate_station(yearRange,monthRange,stationID,dbPath,timeperiod) 
%
% Inputs:
%   yearRange       - years to process (2020:2022)
%   monthRange      - months to process (1:12)
%   stationID       - station ID
%   dbPath          - path where data goes. It has to contain "yyyy"
%                     (p:\database\yyyy\BB1\MET\ECCC)
%   timeUnit        - data sample rate in minutes (default for ECCC is '60MIN')
%
%
% Zoran Nesic               File created:       Apr  3, 2022
%                           Last modification:  Nov 21, 2024
%

% Revisions:
%
% Nov 21, 2024 (Zoran)
%   - renamed timeperiod to timeUnit and switched it from a number to a string
%     to match all the other db_ programs. Default changed from 60 to '60MIN' 
%   - switched from using db_save_struct to the new standard: db_struct2database.
% Nov 29, 2022 (Zoran)
%   - Increased timeout for websave from 5s to 20s. The original value
%     was not sufficient when downloading some of the ECCC data.
% Sep 13, 2022 (Zoran)
%   - Changed the Pbar multiplier from 1000 to 1 to keep the Pbar units as kPa
%      [Stats,~,~] = fr_read_EnvCanada_file(tempFileName,[],[],1);
% July 18, 2022 (Zoran)
%   - fixed the bug when I divided all the traces by 2 instead of doing
%   that only to Percip
% July 14, 2022 (Zoran)
%  - added data processing and database updates for 30-min data. The new
%    data set is saved in the same folder as the 60-min data but
%    under the sub-folder "30min".

[yearNow,monthNow,~]= datevec(now);
arg_default('yearRange',yearNow);               % default year is now
arg_default('monthRange',monthNow-1:monthNow)   % default month is previous:current
arg_default('stationID',49088);                 % default station is Burns Bog
arg_default('timeUnit','60MIN');                % data is hourly (60 minutes)

pathToMatlabTemp = fullfile(tempdir,'MatlabTemp');
if ~exist(pathToMatlabTemp,'dir')
    mkdir(pathToMatlabTemp);
end
tempFileName = fullfile(pathToMatlabTemp,'junk9999.csv');  % temp file name

for yearNow = yearRange
    for currentMonth = monthRange
        % load current month (month can be zero or negative if we are processing currentMonth-1:currentMonth)
        if currentMonth <1 
            yearIn = yearNow-1;
            monthIn = currentMonth+12;
        else
            yearIn = yearNow;
            monthIn = currentMonth;
        end
        %fprintf('Processing: StationID = %d, Year = %d, Month = %d\n',stationID,yearIn,monthIn);
        urlDataSource = sprintf('https://climate.weather.gc.ca/climate_data/bulk_data_e.html?format=csv&stationID=%d&Year=%d&Month=%d&Day=14&timeframe=1&submit=%20Download+Data',...
                                stationID,yearIn,monthIn);
        options = weboptions('Timeout',20);             % set timeout for websave to 15seconds (default is 5)
        websave(tempFileName,urlDataSource,options);
        [Stats,~,~] = fr_read_EnvCanada_file(tempFileName,[],[],1);
        delete(tempFileName);
        % extract time 
        % Note: the time stamp in the ECCC files is set to the middle of the period
        %       10:00am is data avarage for the period of 9:30 to 10:30
        %       This issue will be dealt with in the post processing
        TimeVector = get_stats_field(Stats,'TimeVector');
        for cnt = 1:length(TimeVector)
            Stats(cnt).TimeVector = fr_round_time(TimeVector(cnt));
        end

        datetimeTV = datetime(TimeVector,'convertfrom','datenum');
        years = unique(year(datetimeTV));
        for currentYear = years(1):years(end)
            fprintf('Processing: StationID = %d, Year = %d, Month = %d   ',stationID,currentYear,monthIn);
            fprintf('   ');
            fprintf('Saving 60-min data to %s folder.\n',dbPath);
            %db_save_struct(Stats,dbPath,[],[],timeperiod,NaN);
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
end

function Stats_interp = interp_Struct(Stats,TimeVector30min)
    % time-shifted ECCC time vector
    tv_ECCC60min = get_stats_field(Stats,'TimeVector')+1/48;  % 1/48 is the 30-min forward shift of ECCC data
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
        