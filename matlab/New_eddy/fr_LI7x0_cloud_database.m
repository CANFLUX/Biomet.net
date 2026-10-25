function [numOfFilesProcessed,numOfDataPointsProcessed] = fr_LI7x0_cloud_database(wildCardPath,processProgressListPath,databasePath,time_shift,timeUnit,missingPointValue,optionsFileRead)
% fr_LI7x0_cloud_database - reads LI-710 and LI-720 files downloaded from LI-COR cloud and puts data into data base
% 
% fr_LI7x0_cloud_database(wildCardPath,processProgressListPath,databasePath,time_shift,timeUnit,missingPointValue)
%
% Example:
% [nFiles,nHHours]=fr_LI7x0_cloud_database('d:\Sites\HH\Flux\*_WIB.csv', ...
%                                  'p:\database\HH\2026\LI7x0_progressList.mat','p:\database\yyyy\');
%       This updates or creates data base under p:\database folder.
%
%
%
% NOTE1:
%       databasePath needs to include "\yyyy\" string if multiple years of
%       data are going to be found in the wildCardPath folder!
% NOTE2:
%       To speed up reprocessing of multipe EddyPro files that are found in wildCardPath,
%       see if it can be changed to load up all the data first and 
%       only then run db_struct2database. Some careful error handling when appending Structures
%       to each other will be needed. Some fields may appear or disapear,...
%
% Inputs:
%       wildCardPath            - full SmartFlux summary file name, including path. Wild cards accepted
%       processProgressListPath - path where the progress list is kept
%       databasePath            - path to output location  (*** see the note1 above ***)
%       timeShift               - time offset to be added to the tv vector (in tv
%                                 units, 0 if datebase is in GMT)
%       timeUnit                -  minutes in the sample period (spacing between two
%                                  consecutive data points). Default '30min' (hhour)
%       missingPointValue       - Values that indicate missing data (default = NaN)
%       optionsFileRead         - parameters passed to
%                                 fr_read_EddyPro_file. See that file for
%                                 more info. Default = [];
%
% Zoran Nesic                   File Created:      Oct 25, 2026
%                               Last modification: Oct 25, 2026


%
% Revisions:
%

arg_default('time_shift',0);
arg_default('timeUnit','30MIN'); %
arg_default('missingPointValue',NaN); %   % default missing point code is 0
arg_default('optionsFileRead',[]);

% append filesep on the end of databasePath
% some legacy programs expect it
databasePath = fullfile(databasePath,filesep);

pth = fileparts(wildCardPath); 

if exist(processProgressListPath) %#ok<*EXIST> * do not use 'var' option  here. It does not work correctly
    load(processProgressListPath,'filesProcessProgressList');
else
    filesProcessProgressList = [];
end

filesToProcess = [];                %#ok<*NASGU> % list of files that have not been processed or
                                    % that have been modified since the last processing
indFilesToProcess = [];             % index of the file that needs to be process in the 
                                    % filesProcessProgressList
numOfFilesProcessed = 0;
numOfDataPointsProcessed = 0;
warning_state = warning;
warning('off') %#ok<*WNOFF>
hnd_wait = waitbar(0,'Updating database...');
allFiles = dir(wildCardPath);

for cntFiles=1:length(allFiles)
    try 
        waitbar(cntFiles/length(allFiles),hnd_wait,{sprintf('Processing: %s',allFiles(cntFiles).name),sprintf('In folder: %s ',pth)})
    catch  %#ok<*CTCH>
        waitbar(cntFiles/length(allFiles),hnd_wait)
    end

    % Find the current file in the fileProcessProgressList
    indProgressList = findFileInProgressList(allFiles(cntFiles).name, filesProcessProgressList);
    % if it doesn't exist add a new value
    if indProgressList > length(filesProcessProgressList)
        filesProcessProgressList(indProgressList).Name = allFiles(cntFiles).name; %#ok<*AGROW>
        filesProcessProgressList(indProgressList).Modified = 0;      % datenum(h(i).date);
    end
    % if the file modification data change since the last processing then
    % reprocess it
    if filesProcessProgressList(indProgressList).Modified < datenum(allFiles(cntFiles).date)
        try
            % when a file is found that hasn't been processed try
            % to load it. fr_read_EddyPro_file is able to read
            % full_output, _biomet_ and EP-Summary files
            fileName = fullfile(pth,allFiles(cntFiles).name);
            if allFiles(cntFiles).bytes == 0 
                % If file is of zero-length, skip processing but add it to the progress list
                tv = [];
                structOut = [];
                fprintf(2,'Empty file: %s. Skipping... \n', fileName);
            else           
                structOut = read_LI7x0_file(fileName);
                tv = length(structOut.TimeVector);
                structOut.TimeVector = structOut.TimeVector + time_shift;
                structType = 1;
                db_struct2database(structOut,databasePath,0,[],timeUnit,missingPointValue,structType,1);         
            end
            % if there is no errors update records
            numOfFilesProcessed = numOfFilesProcessed + 1;
            numOfDataPointsProcessed = numOfDataPointsProcessed + length(tv);
            filesProcessProgressList(indProgressList).Modified = datenum(allFiles(cntFiles).date);
        catch ME
            fprintf(2,'\nError processing file: %s. \n',fileName);
            fprintf(2,'%s\n',ME.message);
            fprintf(2,'Error on line: %d in %s\n\n',ME.stack(1).line,ME.stack(1).file);
        end % of try

    end %  filesProcessProgressList(indProgressList).Modified < datenum(allFiles(cntFiles).date)
end % cntFiles=1:length(allFiles)
% Close progress bar
close(hnd_wait)
% Return warning state 
try  %#ok<TRYNC>
   for cntState = 1:length(warning_state)
      warning(warning_state(cntState).identifier,warning_state(cntState).state)
   end
end

save(processProgressListPath,'filesProcessProgressList')




%=================================================
%               Helper functions
%=================================================

%------------------------------------------------------
%           processLI7x0_file(fileName)
%
% Main function for loading up and storing data into 
% an output structure
function structOut = read_LI7x0_file(fileName)
   tableIn=readtable(fileName);
    % The column names in the original table are too long
    % It appears that a unique set of names can be created by
    % removing all the characters from the column name that 
    % follow ther first "_".
    % Note: the user should make sure that they know if 
    %       this abriviated some variable name too much.
    %       Example of one abriviated variable is "Monin"
    %       It should be "Monin-Obukhov length".
    %       In such a case the user should rename this trace 
    %       in the 1st stage ini file to something 
    %       more appropriate. Maybe: Monin_Obukhov_length
    allNames = tableIn.Properties.VariableNames;
    for countNames = 1:length(allNames)
        tmp = split(allNames(countNames),'_');
        allNames(countNames) = tmp(1);
    end
    tableIn.Properties.VariableNames=allNames;
    
    % There is an unfortunate thing that LI-COR didn't learn
    % from Y2K so they use two digit years.
    % The following "fixes" two-digit column (0026 -> 2026)
    dateStr = string(tableIn.Date);
    % Extract year/month/day
    y = str2double(extractBefore(dateStr,5));
    m = extractBetween(dateStr,6,7);
    d = extractAfter(dateStr,8);
    % Assume all years are post-2000
    dateStr = string(y + 2000) + "-" + m + "-" + d;
    
    % Create DateTime from Date + Time
    % Remove timezone portion (e.g. " +0700")
    timeStr = extractBefore(string(tableIn.Time)," +");
    tableIn.DateTime = datetime(dateStr + " " + timeStr, 'InputFormat','yyyy-MM-dd HH:mm:ss');
    
    % Save time zone
    tableIn.timeZoneHours = double(extractAfter(string(tableIn.Time),' '))/100;
    
    % LI-COR used every possible variation of the number formats:
    %  1000.23, "1,000.23", ...  :-(
    % Convert all numeric-looking cell-array columns to doubles
    vars = tableIn.Properties.VariableNames;
    % Loop through all variables 
    for k = 1:numel(vars)
        col = tableIn.(vars{k});
        % Only process cell arrays
        if ~iscell(col)        
            continue
        end
    
        % Initialize numeric output
        tmp = NaN(size(col));
    
        % Non-empty cells
        idx = ~cellfun('isempty',col);
    
        if ~any(idx)
            continue
        end
    
        % Remove commas and convert to double
        tmp(idx) = cellfun( ...
            @(s) str2double(erase(s,',')), ...
            col(idx));
    
        % Replace variable only if at least one value converted successfully
        if any(~isnan(tmp(idx)))
            tableIn.(vars{k}) = tmp;
        end
    end
    
    % Make it look better by:
    % putting DateTime first
    tableIn = movevars(tableIn,'DateTime','Before',1);
    tableIn = movevars(tableIn,'timeZoneHours','Before',2);
    % removing original Date and Time columns
    tableIn(:,{'Date','Time','Line'}) = [];
    
    % Split each table into two tables. One is measured at 30 min intervals (:00 or :30)
    % the other one is at "random"/"odd" times (see an original file for more info)
    ind30 = minute(tableIn.DateTime)== 30 | minute(tableIn.DateTime)== 0;
    T_30 = tableIn(ind30,:);
    T_odd = tableIn(~ind30,:);
    % Save the original DateTime of the _odd table for troubleshooting purposes
    T_odd.DateTimeOrig = T_odd.DateTime;
    T_odd = movevars(T_odd,'DateTimeOrig','after',1);
    T_odd.DateTime = dateshift(T_odd.DateTime,'start','day') + ...
        minutes(30 * round(minutes(T_odd.DateTime - dateshift(T_odd.DateTime,'start','day'))/30));
    
    %
    % Convert tables to structures and make sure that NaN in one variable does not 
    % overwrite a valid number (notnan) in the same variable in the other table/structure 
    structT_30 = table2TABstruct(T_30,1);
    structT_odd = table2TABstruct(T_odd,1);
    % time vector for both tables
    tv_all = union(structT_30.TimeVector,structT_odd.TimeVector);
    structOut.TimeVector = tv_all;
    vars = fieldnames(structT_30);
    for cntVars = 1:numel(vars)
        fName = char(vars(cntVars));
        % initiate structOut.(fName)
        structOut.(fName) = nan(size(tv_all));
        % find the points in _odd that are also in tv_all
        [~,ia,ib] = intersect(tv_all,structT_odd.TimeVector);
        % insert _odd points into structOut
        structOut.(fName)(ia) = structT_odd.(fName)(ib);
        [~,ia,ib] = intersect(tv_all,structT_30.TimeVector);
        indNotNan = find(~isnan(structT_30.(fName)(ib)));
        structOut.(fName)(ia(indNotNan)) = structT_30.(fName)(ib(indNotNan));
    end

%------------------------------------------------------
%      table2TABstruct(tblIn,flagConvertDateTime)
%
% Converting a table to structType = 1
% We should make a stand alone one for Biomet.net
% If it's known that the table contains column DataTime
% set flagConvertDateTime=1 to automatically 
% generate TimeVector field
function structOut = table2TABstruct(tblIn,flagConvertDateTime)
    arg_default('flagConvertDateTime',0)
    if flagConvertDateTime
        structOut.TimeVector = datenum(tblIn.DateTime);
    end
    vars = tblIn.Properties.VariableNames;
    for cntVars = 1:numel(vars)
        colIn = tblIn.(vars{cntVars});
        if ~isnumeric(colIn)
            continue;
        end
        structOut.(vars{cntVars}) = colIn;
    end

%------------------------------------------------------
%      findFileInProgressList(fileName, filesProcessProgressList)
%
% this function returns and index pointing to where fileName is in the 
% fileProcessProgressList.  If fileName doesn't exist in the list
% the output is list length + 1
function ind = findFileInProgressList(fileName, filesProcessProgressList)

    ind = [];
    for cntList = 1:length(filesProcessProgressList)
        if strcmp(fileName,filesProcessProgressList(cntList).Name)
            ind = cntList;
            break
        end %  strcmp(fileName,filesProcessProgressList(cntList).Name)
    end % cntList = 1:length(filesProcessProgressList)
    if isempty(ind)
        ind = length(filesProcessProgressList)+1;
    end 



