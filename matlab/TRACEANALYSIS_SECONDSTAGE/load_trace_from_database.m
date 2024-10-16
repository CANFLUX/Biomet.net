function trace_out = load_trace_from_database(trace_in) 
%This function reads from the database using the information present in the 'ini'
%structure located as a field in the input 'trace_in'.
%This 'ini' structure should contain an 'inputFileName' as a field.
%The 'inputFileName' gives the name of the raw, uncleaned binary data file located
%in the database, associated with 'trace_in'.
%Also, the inputFileName should include the partial path to the file, since
%the biomet_path function used here only return the path to databas

%The result is the same as 'trace_in' except with three new fields: data,data_old,DOY
%which are raw data, and the decimal day of year with time shift.

% Revisions: 
%
% May 24, 2024 (Zoran)
%   - Bug fix. The function was not able to read traces that had multiple
%     inputFileNames since introduction of special case inputFileNames
%     (clean_tv and TimeVector). This line was added to kill the 
%     bug: length(trace_in.ini.inputFileName)==1 && (... check clean_tv...)
% Apr 10, 2024 (Zoran)
%  - made sure that the program checks if "&& ~isempty(trace_in.ini.inputFileName_dates)" before
%    trying to deal with the inputFileName_dates information. Otherwise bad things happen 
%    when inputFileName_dates = [];
% Apr 2, 2024 (Zoran)
%   - Enabled trace file name to be 'clean_tv' or TimeVector. That way the 
%     time can be loaded up and used to filter data periods.
% May 9, 2023 (Zoran)
%   - When .inputFileName length was 1 the string was not processed correctly.
%     The single .inputFileName is a string and when we had multiple .inputFileName
%     they were kept in a cell array. Added this section to deal with it:
%         if iscell(trace_in.ini.inputFileName(i))
%             inputFileName = char(trace_in.ini.inputFileName(i));
%         else
%             inputFileName = char(trace_in.ini.inputFileName(i,:));
%         end
%   - Bug fix: instead of testing if ~exist('temp_data','var') I used to
%     check if i==1 (very wrong)
%    - Another bug. Changed:
%         ind = find(tvYear >= trace_in.ini.inputFileName_dates(i,1) & ...
%             tvYear < trace_in.ini.inputFileName_dates(i,2));
% to
%         ind = find(tvYear >= trace_in.ini.inputFileName_dates(i,1) & ...
%             tvYear <= trace_in.ini.inputFileName_dates(i,2));
% Feb 11, 2023 (Zoran)
%   - Removed old comments that are not relevant anymore.
%   - Removed a big chunk of code that didn't do anything useful anymore.
%   - Added proper handling of 'inputFileName_dates'
% Nov 25, 2022 (Zoran)
%   - Warnings for missing data traces in the ini files were turned off.
%     Turned them back on (warn_flag = 1)
% Apr 11, 2022 (Zoran)
%   - replaced testing:
%       find( tmp_FileName == '\'...
%     with
%       find( tmp_FileName == filesep...
%   - removed some syntax warnings
%
% Elyn 07.11.01 - allow for different inputFileNames associated with different times
%                   for eg. when a sensor is changed from one logger to another

warn_flag = 1;
Year = trace_in.Year;
SiteID = trace_in.SiteID;
time_shift = trace_in.Diff_GMT_to_local_time;

pth = biomet_path(Year,SiteID, trace_in.ini.measurementType);		%find path in database

% if trace name is 'clean_tv' or 'TimeVector' then load it up as a special case
% Load it up using read_bor and skip all the other tests.
% First check if inputFileName has only one entry, otherwise it's not
% loading time vector.
if length(trace_in.ini.inputFileName)==1 && ... 
    (length(trace_in.ini.inputFileName)==1 && strcmpi(trace_in.ini.inputFileName,'clean_tv') || strcmpi(trace_in.ini.inputFileName,'TimeVector'))
    temp_data = read_bor(fullfile(pth, char(trace_in.ini.inputFileName)),8);			%read tv from database
    timeVector = temp_data;
    loadError = 0; % Added 2024-07-29 (P.Moore)
else
    if isfield(trace_in.ini,'inputFileName_dates') && ~isempty(trace_in.ini.inputFileName_dates)
        % Create a time vector first for the current year
        % to be able to pick the inputFileName(s) that 
        % were relevant for that year.
        % The time vector resolution is assumed to be 30min and it's only used
        % here to identify the correct file name (it's not part of the data
        % output)
        tvYear = fr_round_time(datenum(Year,1,1,0,30,0):1/48:datenum(Year+1,1,1,0,0,0)); %#ok<*DATNM>
        for i = 1:size(char(trace_in.ini.inputFileName),1)
            % Sometimes users would not input singular inputFileName-s as 
            % a cell array. This deals with that issue by checking first
            if iscell(trace_in.ini.inputFileName(i))
                inputFileName = char(trace_in.ini.inputFileName(i));
            else
                inputFileName = char(trace_in.ini.inputFileName(i,:));
            end
            ind = find(tvYear > trace_in.ini.inputFileName_dates(i,1) & ...
                tvYear <= trace_in.ini.inputFileName_dates(i,2));        
            if ~isempty(ind)
                % load data only if this input file is relevant for this year.
                % (this data trace could be non-existent for this year in which
                % case program would output errors. This way only relevant
                % files are read.
                [temp_data_cur,timeVector,loadError] = read_db(Year,SiteID,...
                    trace_in.ini.measurementType,inputFileName,warn_flag);
                if ~exist('temp_data','var')
                    % Create a NaN array of the appropriate length.
                    temp_data = NaN.*ones(length(timeVector),1);
                end
                try
                    temp_data(ind) = temp_data_cur(ind);
                catch
                    if ~isempty(ind)
                        try
                            temp_data(ind) = read_bor([pth inputFileName],[],[],[],ind);			%read from database
                        catch
                        end
                    end
                end
            end
        end
    else
        [temp_data,timeVector,loadError] = read_db(Year,SiteID,...
            trace_in.ini.measurementType,char(trace_in.ini.inputFileName),warn_flag);
    end
end
         
%if berms data has been inputed then
if ~isempty(trace_in.data)
         
	%merge the data 
	NaNgetSpikes = bitor(diff(isnan(trace_in.data)) > 0, diff(~isnan(trace_in.data)) > 0);
   
   indexNaNs = find(NaNgetSpikes == 1);   
      
   if isnan(trace_in.data(1))
      indexNaNs( length(indexNaNs) + 1 ) = 0;
   end
   
   indexNaNs = sort(indexNaNs);
   
	numPairs = floor( length(indexNaNs) / 2 );
	remainder = rem( length(indexNaNs), 2 );
               
   temp_vec = temp_data(indOut);
   
	if numPairs >= 1   
        for countPairs = 1:numPairs
         trace_in.data( indexNaNs(countPairs*2-1)+1:indexNaNs(countPairs*2) ) = temp_vec( indexNaNs(countPairs*2-1)+1:indexNaNs(countPairs*2) );
        end
	end

	if remainder == 1
		trace_in.data( indexNaNs( length(indexNaNs) )+1:length(trace_in.data) ) = temp_vec( indexNaNs(length(indexNaNs))+1:length(trace_in.data) );
	end   
else
%   trace_in.data = temp_data(indOut);
end

if length(temp_data) == 1 & isnan(temp_data) 
    trace_in.data       = NaN .* ones(size(timeVector));
else
    trace_in.data       = temp_data;
end
trace_in.DOY        = timeVector - datenum(Year,1,0);
trace_in.DOY        = trace_in.DOY - time_shift/24;
trace_in.timeVector = timeVector;
trace_in.data_old   = trace_in.data;
trace_in.Error      = loadError; % Added 2024-07-29 (P.Moore)
trace_out           = trace_in;


