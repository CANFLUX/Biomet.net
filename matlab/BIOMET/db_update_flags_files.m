function dataOut = db_update_flags_files(yearIn,siteID,sitesPathRoot, databasePathRoot,timeUnit,missingPointValue)
% db_update_flags_files - reads an xlsx or a csv file containing data-exclusion flags and exports those flags into database format
%                         Multiple flags can be created using one xlsx file
%
% dataOut = db_update_flags_files( yearIn,siteID,sitesPathRoot,databasePathRoot,timeUnit,missingPointValue)
%
% Example:
%    dataOut = db_update_flags_files(2022,'DSM','p:/Sites','p:/database') 
%    reads input file p:/Sites/DSM/MET/DSM_flags_2022.xlxs and
%    updates or creates data base files under p:/database
%
%
% Inputs:
%       yearIn          - array of years to process. Default is the current year
%       siteID          - site ID ('DSM', 'RBM'...)
%       sitesPathRoot   - path to Sites folder (usually: p:/Sites or structProject.sitesPath)
%       databasePath    - path to database (usually p:/database or structProject.databasePath)
%       timeUnit        - minutes in the sample period (spacing between two
%                         consecutive data points). Default '30MIN' (half-hour)
%
% Notes:
%    - the input file should be located under p:/Sites/siteID/MET folder.
%    - The file should be named: siteID_flags*.xlsx or .csv.
%    - use this template for the input file
% ------------ start of the template ------------------------------------------------
%          Header line 1
%          Header line 2
%          Header line 3
%          Header line 4
%          StartDate	      EndDate           flagDO_1_1_1    flag_pH_1_1_1   Notes
%          2022-06-25 09:30	2022-06-25 10:30    1                               Service 1
%          2022-08-30 10:15	2022-08-30 12:30	1                               Service 2
%          2022-09-15 08:50	2022-09-19 13:30    1                               Service 3
%          2022-09-30 10:30	2022-09-30 11:30	1                               Service 4
%          2022-04-23 15:30	2022-06-25 16:00                    1               Bad data
%          2022-07-02 20:00	2022-07-27 13:30                    1               Bad data
%          2022-07-29 10:00	2022-08-30 13:00                    1               Bad data
%          2022-09-09 00:00	2022-09-19 12:30                    1               Bad data
%-------------------------------------------------------------------------------------------
%   - The number of header lines has to be 4
%   - Any number of columns for flags can be used (min=1)
%   - Flag names have to be valid Matlab variable names and valid Windows file names
%     (suggestion: use Ameriflux convention as in the template above)
%   - The column titles: StartDate, EndDate and Notes should not be changed
%
%
% Zoran Nesic           File Created:      Nov 15, 2022
%                       Last modification: Nov 19, 2025

%
% Revisions:
%
% Nov 19, 2025 (Zoran)
%   - Improvements:
%       - It now reads multiple input files at the same time and it can work with multiple years 
%         all within one or within multiple files.
%       - csv and xlsx files can co-exist in the same (Met) folder. No need to rewrite the old flag files,
%         one can just add new file(s) in the format (xlsx or csv) that they like
%       - Using db_struct2database instead of the old db_new_eddy function.
%       - timeUnit can now be the standard '30MIN' or '5MIN'... but the old style (number 30) still works.
%       - it can now deal with time steps different than 30 minutes (hasn't been tested very well yet)
% Nov 25, 2022 (Zoran)
%  - Changed the values that are inserted to indicate that the points should
%    be excluded. Instead of 1s we should be using missingPointValue to match how the flagging
%    works in the first stage cleaning.
% Nov 18, 2022 (Zoran)
%  - Added comments
%

yearNow = year(datetime); 
arg_default('time_shift',0);
arg_default('timeUnit','30MIN'); %
arg_default('yearIn',yearNow)
arg_default('missingPointValue',NaN); %   % default missing point code is 0
dataOut = [];

% Make sure timeUnit is a char. 
if isnumeric(timeUnit)
    % if timeUnit is a number assume it's in minutes and format it appropriatelly
    timeUnit = sprintf('%dMIN',timeUnit);
end

% the source file is an xlxs or csv file that's under the site's MET folder.
% Here is its path
filePath = fullfile(sitesPathRoot,siteID,'MET');

% Load up the names of files that match siteID_flags*.xlsx or siteID_flags*.csv
fileName = fullfile(filePath,sprintf('%s_flags*.xlsx',siteID));
allFiles = dir(fileName);
fileName = fullfile(filePath,sprintf('%s_flags*.csv',siteID));
allFiles = [allFiles ; dir(fileName)];
if isempty(allFiles)
    % If there are no such files return
    return
end

% Loop through all files and load the data
tableIn = table([]);
for cntFiles = 1:length(allFiles)
    currentFileName = fullfile(allFiles(cntFiles).folder,allFiles(cntFiles).name);
    if cntFiles == 1
        tableIn = readtable(currentFileName,"NumHeaderLines",4);
    else
        tableIn = [tableIn ; readtable(currentFileName,"NumHeaderLines",4)];
    end
end

% find all years that the data belongs to
yearsInTable = unique(year([tableIn.StartDate;tableIn.EndDate]));
yearsInTable = yearsInTable(:)';

% Time increment:
if strcmpi(timeUnit(end-2:end),'MIN')
    if length(timeUnit)==3
        numOfMin = 1;
    else
        numOfMin = str2double(timeUnit(1:end-3));
    end
else
    numOfMin = [];
end

% cycle through each of those years
for cntYears = yearsInTable

    % Process only the cntYears that are also in yearIn
    if ismember(cntYears,yearIn)
       
        % create a time vector for the entire year
        dataOut.TimeVector = datenum(datetime(cntYears,1,1,0,numOfMin,0):minutes(numOfMin):datetime(cntYears+1,1,1))'; %#ok<*DATNM>
        
        flagNum = 0;
        varNames = {};
        for cntVars = 1:length(tableIn.Properties.VariableNames)
            varNameTmp = tableIn.Properties.VariableNames(cntVars);
            % find flag columns (all columns that are not in the list below)
            if ~ismember(varNameTmp,{'StartDate','EndDate','Notes'}) 
                % set all values in varName to 0
                dataOut.(char(varNameTmp)) = zeros(size(dataOut.TimeVector));
                flagNum = flagNum + 1;
                varNames(flagNum) = varNameTmp; %#ok<*AGROW>
            end
        end
        
        % Find periods for each variable that need to be "flagged" (set to missingPointValue)
        % and flag them
        for cntVars = 1:length(varNames)
            currVar = char(varNames(cntVars));
            flagVar = tableIn.(currVar);
            indVar  = find(~isnan(flagVar));
            for cntPeriods = 1:length(indVar)
                % find a time period for the current flag
                startPeriod = datenum(tableIn.StartDate(indVar(cntPeriods)));
                endPeriod   = datenum(tableIn.EndDate(indVar(cntPeriods)));
                % flag that period
                indData2Flag = find(dataOut.TimeVector > startPeriod ...
                                  & dataOut.TimeVector <=fr_round_time(endPeriod,[],2) ); 
                dataOut.(currVar)(indData2Flag) = missingPointValue; %#ok<FNDSB>
            end
        end
           
        % full path (Example: p:\database\2022\DSM\Flags)
        pthOut = fullfile(databasePathRoot,num2str(cntYears),siteID,'Flags');
        
        % save traces into database
        structType = 1;
        db_struct2database(dataOut,pthOut,[],[],timeUnit,missingPointValue,structType);
    end
end
