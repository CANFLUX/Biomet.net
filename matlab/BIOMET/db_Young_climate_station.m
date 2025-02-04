function db_Young_climate_station_new(fileName,stationName,siteID,inFileNum)
% db_Young_climate_station(stationName,fileName)
%
% fileName = 'C:\Users\zoran\Downloads\Newdale-Hamiota-Oakburn-Data.xls';
%
% Zoran Nesic               File created:       Sep  7, 2022
%                           Last modification:  Feb 3, 2025

%
% Revisions:
%
% Feb 3, 2025 (Rosie)
%  - Updated script so no edits are needed if switching between input files;
%    filename is automated based on input parameter 'fileName':
%       fileName: full name of raw input data file (string)
%       stationName: name of climate station substitute data is from, e.g. 'Newdale'
%       siteID: flux station siteID, e.g. 'YOUNG' 
%
% Jan 28, 2025 (Rosie)
%  - Edited db_Young_climate_station function to work conditionally for 
%    each of five different input files, each formatted a bit differently 
%    and with their own issues (now we have more Newdale data (covering 
%    2021-2024 time period, inclusive, details in inline comments below). 
%  - Discovered Newdale data includes daylight savings time, so script now
%    converts all hourly data to standard time before interpolating to
%    30-min data. 
%  - Edited 30-min interpolation, hourly data represents the hour before 
%    each timestamp, previous code wasn't including the first half hour of
%    dataset.
%
% Oct 17, 2023 (Zoran)
%  - Changed:
%      siteData = origData(strcmp(origData.StationName,stationName),:);
%    to
%      siteData = origData(strcmpi(origData.StationName,stationName),:);
%    bacause the Manitoba group uses interchangebly Newdale and newdale in
%    their source data files.
% Sep 13, 2022 (Zoran)
%  - converted units for SolarRad from MJ/m^2/hour to W/m^2
%  - added default arguments for the function inputs fileName and stationName
%    so it can be used for other Manitoba stations.

%stationName = 'Newdale';
%fileName = 'C:\Users\zoran\Downloads\Newdale-Hamiota-Oakburn-Data.xls';

% arg_default('stationName','Newdale')
% siteID = 'YOUNG';

% arg_default('fileName','C:\Users\zoran\Downloads\Newdale-Hamiota-Oakburn-Data.xls');

% Input files; as of Jan 2025 we have 5 separate files containing Newdale data 
% covering the period from 1 Jan 2021 - 31 Dec 2024. Some files have different 
% formatting (e.g. date, StationName vs. Station) and need slightly
% different processing:
%   (1) 'Newdale-Hamiota-Oakburn-Data.xls - Newdale-Hamiota-Oakburn-Data.csv' (1 Jan 2021 - 5 Sept 2022)
%   (2) 'Newdale-60min-September2022.xlsx' (4 Sept 2022 - 15 Sept 2022; fills gap in 2022)
%   (3) 'Newdale-2022-2023-TScott.xlsx' (15 Sept 2022 - 11 Oct 2023)
%   (4) 'Newdale-60min-2023.xlsx' (all of 2023)
%   (5) 'Newdale-60min-2024.xlsx' (all of 2024)

if strcmpi(fileName,'Newdale-Hamiota-Oakburn-Data.xls - Newdale-Hamiota-Oakburn-Data.csv')
    % File 1: this file has data from 1 Jan 2021 - 5 Sept 2022
    inFileNum = 1;
elseif strcmpi(fileName,'Newdale-60min-September2022.xlsx')
    % File 2: this file has data from 4 Sept 2022 - 15 Sept 2022 (fills gap in 2022)
    inFileNum = 2;
elseif strcmpi(fileName,'Newdale-2022-2023-TScott.xlsx')
    % File 3: this file has data from 15 Sept 2022 - 11 Oct 2023
    inFileNum = 3;
elseif strcmpi(fileName,'Newdale-60min-2023.xlsx')
    % File 4: this file has a full year of data for 2023
    inFileNum = 4;
elseif strcmpi(fileName,'Newdale-60min-2024.xlsx')
    % File 5: this file has a full year of data for 2024
    inFileNum = 5;
else
    % this is a new file. The file type has to be given as an input value.
    if ~exist('inFileNum','var') | isempty(inFileNum)
        fprintf(2,'For this input file (%s) programs needs to have inFileNum parameter set!\n',fileName);
    end
end
fullFilePath = fullfile(biomet_sites_default,siteID,'Met',fileName);

% output path
dbPath = fullfile(biomet_database_default,'yyyy','Young','Met',stationName); 
% dbPath = fullfile(biomet_database_default,['yyyy\Young\Met\' stationName]);   % Mac OS didn't like backslashes

% Read the data file
origData = readtable(fullFilePath);

% Extract data for stationName
if inFileNum == 1 || inFileNum == 3
    siteData = origData(strcmpi(origData.StationName,stationName),:); % for pre 2023 data
else
    siteData = origData(strcmpi(origData.Station,stationName),:);   % for 2023/2024 data file, the column header uses "Station" instead of "StationName" for "newdale" column
end

% Format date 
if inFileNum == 1
    t = datetime(siteData.TMSTAMP);
    t.Year(t.Year == 21) = 2021;
    t.Year(t.Year == 22) = 2022;
    siteData.TMSTAMP = t;
elseif inFileNum == 3
    t = datetime(siteData.TMSTAMP,"InputFormat","uuuu-MM-dd HH:mm:ss"); %,"Format","dd-MMM-uuuu HH:mm:ss");
    siteData.TMSTAMP = t;
end

% NO! Do unit conversion in INI files for consistency across years - Rosie, 21 Jan
% 2025
% Unit conversion: convert not-micromet-standard field units
% siteData.AvgRS_kw = siteData.AvgRS_kw * 1000; % kW/m^2 -> W/m^2
% siteData.TotRS_MJ = siteData.TotRS_MJ * (1e6/3600); % MJ/m^2/hour -> W/m^2

% The following was already present and variable is not used (SolarRad
% represents calculated "potential" solar rad, not measured, per email with
% Alison Sass from MB Gov., Jan 2025). 
siteData.SolarRad = siteData.SolarRad * (1e6/3600); % MJ/m^2/hour -> W/m^2

% Convert siteData to Stats structure
Stats = table2struct(siteData);

% go through all the Stats fields. 
allFields = fieldnames(Stats);
% go field by field, convert 'datetime' fields to 'datenum' fields
% and remove all the other fields that are not 'double'-s
for cntFields = 1:length(allFields)
    oneField = char(allFields(cntFields));
    foo = Stats(1).(oneField);
    foo = whos('foo');
    if strcmpi(oneField,'TMSTAMP')
        % This is the TimeVector. Rename the field
        for cntRows = 1:length(Stats)
            Stats(cntRows).TimeVector = datenum(Stats(cntRows).(oneField));
        end
        datetimeTV = siteData.TMSTAMP;
        Stats = rmfield(Stats,oneField);
    elseif ~strcmp(foo.class,'double')
        % remove all fields that are not class 'double'
        Stats = rmfield(Stats,oneField);
    end
end

% Rosie, 21 Jan 2025: As of Jan 2025 we found out that Newdale data includes daylight
% savings (per Alison Sass, MB Gov), "We measure in local Manitoba time, 
% whether that be daylight savings or not.  You will notice that there is 
% an hour of blank data in spring and an extra hour (02:01:00) in the fall 
% on the days that the time changes occur." 
% Fix this (convert to standard time throughout) by correcting the
% timestamp, since the data is good and correct length for year. 

idx1 = find(diff(datetimeTV.Hour) > 1);    % find "missing" spring timestamp when time change occurs
idx2 = find(datetimeTV.Minute == 1);      % find duplicate fall timestamp when time change occurs
                                                % See, e.g.:     '05-Nov-2023 02:00:00'
                                                %                '05-Nov-2023 02:01:00'
allNewFields = fieldnames(Stats);
if inFileNum == 1  
    datetimeTV(idx2).Minute = 0;            % correct "extra" timestamp when daylight savings ends (November)

    % possible for there to be multiple indices if data file contains more than one year
    datetimeTV(idx1(1)+1:idx2-1).Hour = datetimeTV(idx1(1)+1:idx2-1).Hour - 1;    % convert daylight savings timestamps to standard time
    datetimeTV(idx1(2)+1:end).Hour = datetimeTV(idx1(2)+1:end).Hour - 1;            % file ends in Sept 2022 prior to switch back to standard time

    % Daylights savings was recorded late in 2021, on 17 March instead of
    % 14 Mar, data "gap" denoting this is seen on 17th Mar
    % Remove data (= NaN) between 14-17 March 2021 to be safe
    % datetimeTV index = 1729 is index before daylight savings started in
    % reality (01:00 on 14 Mar 2021). index = idx(1)+1 is index where we
    % know daylight savings is occurring.
    for j_del = 1729:idx1(1)+1
        for i_del = 3:38    % fields from allNewFields to be made equal to NaN (do not remove TimeVector)
            currField = char(allNewFields(i_del));
            % foo = Stats(1).(currField);
            % foo = whos('foo');
            Stats(j_del).(currField) = NaN;
        end
    end
elseif inFileNum == 2
    % File contains only September 2022 data, it is in daylight savings so
    % convert all data to standard time
    datetimeTV.Hour = datetimeTV.Hour - 1;
elseif inFileNum == 3
    % File begins in September 2022 (after end of inFileNum 2), ends in October 2023
    % Indices prior to idx2 and after idx1 need converting to standard time
    datetimeTV(idx2).Minute = 0;        % correct "extra" timestamp when daylight savings ends (November)
    datetimeTV(1:idx2-1).Hour = datetimeTV(1:idx2-1).Hour - 1;
    datetimeTV(idx1+1:end).Hour = datetimeTV(idx1+1:end).Hour - 1;
else
    % inFileNums 4 and 5: files are each for one full year, 2023 and 2024 respectively
    datetimeTV(idx2).Minute = 0;            % correct "extra" timestamp when daylight savings ends (November)
    datetimeTV(idx1+1:idx2-1).Hour = datetimeTV(idx1+1:idx2-1).Hour - 1;    % convert daylight savings timestamps to standard time
end

% Assign new time vector to Stats.TimeVector field so all data is saved in
% standard time
for cntRows = 1:length(Stats)
    Stats(cntRows).TimeVector = datenum(datetimeTV(cntRows));
end

% % (Old timestamp analysis, incorrect, removed 21 Jan 2025) 
% % This particular xls files has some data in it that's not on hourly marks
% % See:     '07-Nov-2021 02:00:00'
% %          '07-Nov-2021 02:01:00'
% % The point repetition (two points for the same hourly period creates 
% % trouble in db_save_structure.
% % Fix it by keeping only the point that are exactly on the hourly mark
% % Create a datetime vector that contains only true hourly values
% startDatetime = datenum(datetimeTV(1));
% endDatetime   = datenum(datetimeTV(end));
% fullHourlyTimeVector = fr_round_time(startDatetime:1/24:endDatetime)';
% [~,indGoodHourlyPoints] = intersect(datenum(datetimeTV),fullHourlyTimeVector);
% Stats = Stats(indGoodHourlyPoints);

% Table data is now in a proper Stats structure
% save Stats into data base

years = unique(year(datetimeTV));
for currentYear = years(1):years(end)  
    fprintf('Processing: Station = %s for year = %d  ',stationName,currentYear);
    fprintf('   ');
    fprintf('Saving 60-min data to %s folder.\n',dbPath);
    db_save_struct(Stats,dbPath,[],[],60,NaN);
    % now interpolate data from 60- to 30- min time periods
    % generic TimeVector for local standard time
    TimeVector30min = fr_round_time(datenum(currentYear,1,1,0,30,0):1/48:datenum(currentYear+1,1,1));
    Stats30min = interp_Struct(Stats,TimeVector30min,inFileNum);
    db30minPath = fullfile(dbPath,'30min');

    if isempty(Stats30min)
        fprintf('')
        fprintf('Check: 30-min data not calculated for %d.\n',currentYear)
        return
    else
        fprintf('Saving 30-min data to %s folder.\n',db30minPath);
        db_save_struct(Stats30min,db30minPath,[],[],30,NaN);
    end
end




function Stats_interp = interp_Struct(Stats,TimeVector30min,inFileNum)
    % Newdale time vector
    tv_Newdale60min = get_stats_field(Stats,'TimeVector'); 

    % find time vector for current year
    t_ST = datetime(TimeVector30min,"ConvertFrom","datenum");   % standard time
    year = unique(t_ST.Year);
    year = year(1); % start of data will have correct year (if defined correctly above)

    t_Newdale = datetime(tv_Newdale60min,"ConvertFrom","datenum");
    ind = find(t_Newdale.Year == year);
    if inFileNum == 1
        % shift indices according to timestamp (e.g. first data point in year 2022
        % represents data in year 2021)
        if t_Newdale(ind(end)).Month == 12 && t_Newdale(ind(end)).Day == 31 && t_Newdale(ind(end)).Hour == 23
            ind(end+1) = ind(end)+1;
        else
            ind(1) = [];
        end
        t_Newdale = t_Newdale(ind(1):ind(end));
        tv_Newdale60min = datenum(t_Newdale);
        TimeVector30min = TimeVector30min(TimeVector30min >= tv_Newdale60min(1)-1/48 & TimeVector30min <= tv_Newdale60min(end));
    elseif inFileNum == 2
        TimeVector30min = TimeVector30min(TimeVector30min >= tv_Newdale60min(1)-1/48 & TimeVector30min <= tv_Newdale60min(end));
    elseif inFileNum == 3
        % shift indices according to timestamp (e.g. first data point in year 2022
        % represents data in year 2021)
        if t_Newdale(ind(end)).Month == 12 && t_Newdale(ind(end)).Day == 31 && t_Newdale(ind(end)).Hour == 23
            ind(end+1) = ind(end)+1;
        else
            ind(1) = [];
        end
        t_Newdale = t_Newdale(ind(1):ind(end));
        tv_Newdale60min = datenum(t_Newdale);
        TimeVector30min = TimeVector30min(TimeVector30min >= tv_Newdale60min(1)-1/48 & TimeVector30min <= tv_Newdale60min(end));
    else
        % shift indices according to timestamp (e.g. first data point in year 2022
        % represents data in year 2021)
        if t_Newdale(ind(end)).Month == 12 && t_Newdale(ind(end)).Day == 31 && t_Newdale(ind(end)).Hour == 23
            ind(end+1) = ind(end)+1;
        end
        t_Newdale = t_Newdale(ind(1):ind(end));
        tv_Newdale60min = datenum(t_Newdale);
        TimeVector30min = TimeVector30min(TimeVector30min >= tv_Newdale60min(1)-1/48 & TimeVector30min <= tv_Newdale60min(end));
    end
    
    if isempty(TimeVector30min)
        Stats_interp = [];
        return
    end

    % find the time period - could put this here as applied to all files,
    % but during analysis I found it helpful to see what was being done for
    % each file all at once, above.
    % TimeVector30min = TimeVector30min(TimeVector30min >= tv_Newdale60min(1)-1/48 & TimeVector30min <= tv_Newdale60min(end)); 
    
    N = length(TimeVector30min);
    % interpolate all data traces to go from 60-min to 30-min period    
    fnames= fieldnames(Stats);
    for k = 1:numel(fnames)
        if ~strcmpi(char(fnames{k}),'TimeVector')
            % extract 60-min data
            x60min = get_stats_field(Stats(ind),char(fnames{k}));
            % interpolate it to double the samples (30-min)
            x = interp1(tv_Newdale60min,x60min,TimeVector30min,'linear','extrap');
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