function [numOfFilesProcessed,numOfDataPointsProcessed] = fr_HOBO_database(wildCardPath,processProgressListPath,databasePath,time_shift,timeUnit,missingPointValue)
% fr_HOBO_database - read HOBO 30-min csv files and create a HOBO data base
% 
% fr_HOBO_database(wildCardPath,processProgressListPath,databasePath,time_shift,timeUnit,missingPointValue)
%
% Example:
% [nFiles,nHHours] = fr_HOBO_database('p:\Katrina_data\Sites\USRRC\HOBO_water_table\HOBO_20230801.csv',[],'p:\Katrina_data\Database\yyyy\USRRC\WaterTable',[],[],NaN);
% [nFiles,nHHours] = fr_HOBO_database('e:\junk\Katrina_data\Sites\USRRC\HOBO_water_table\test1.csv',[],'d:\junk\Katrina_data\Database\yyyy\USRRC\WaterTable',[],[],NaN);
% Updates or Creates data base under p:\Katrina_data\Database
%
% NOTE:
%       databasePath needs to include "\yyyy\" string if multiple years of
%       data are going to be found in the wildCardPath folder!
%
% Inputs:
%       wildCardPath - full SmartFlux summary file name, including path. Wild cards accepted
%       processProgressListPath - path where the progress list is kept
%       databasePath - path to output location  (*** see the note above ***)
%       timeShift    - time offset to be added to the tv vector (in tv
%                      units, 0 if datebase is in GMT)
%       timeUnit     -  minutes in the sample period (spacing between two
%                     consecutive data points). Default 30 (hhour)
%
% Zoran Nesic           File Created:      Aug   7, 2023
%                       Last modification: Aug   9, 2023

%
% Revisions:
%
% Aug 9, 2023 (Zoran)
%   - Added proper handling of the "No files found" for the given path
%

arg_default('time_shift',0);
arg_default('timeUnit',30); %
arg_default('missingPointValue',0); %   % default missing point code is 0

if isempty(processProgressListPath)
    flagUseProgressList = 0;
else
    flagUseProgressList = 1;
end
h = dir(wildCardPath);

if ~isempty(h)
    x = strfind(wildCardPath,filesep);
    y = strfind(wildCardPath,'.*');

    pth = wildCardPath(1:x(end));

    if flagUseProgressList == 1
        if exist(processProgressListPath) %#ok<*EXIST> * do not use 'var' option  here. It does not work correctly
            load(processProgressListPath,'filesProcessProgressList');
        else
            filesProcessProgressList = [];
        end

        filesToProcess = [];                %#ok<*NASGU> % list of files that have not been processed or
                                            % that have been modified since the last processing
        indFilesToProcess = [];             % index of the file that needs to be process in the 
                                            % filesProcessProgressList
    end

    numOfFilesProcessed = 0;
    numOfDataPointsProcessed = 0;
    warning_state = warning;
    warning('off') %#ok<*WNOFF>
    hnd_wait = waitbar(0,'Updating database...');

    for i=1:length(h)
        fileName = fullfile(pth,h(i).name);
        try 
            waitbar(i/length(h),hnd_wait,sprintf('Processing: %s ', fileName))
        catch  %#ok<*CTCH>
            waitbar(i/length(h),hnd_wait)
        end
        flagProcessCurrentFile = 0;
        if flagUseProgressList == 1
            % Find the current file in the fileProcessProgressList
            j = findFileInProgressList(h(i).name, filesProcessProgressList);
            % if it doesn't exist add a new value
            if j > length(filesProcessProgressList)
                filesProcessProgressList(j).Name = h(i).name; %#ok<*AGROW>
                filesProcessProgressList(j).Modified = 0;      % datenum(h(i).date);
            end
        end

        % if the file modification data change since the last processing  or if ProgressList is not used
        % then reprocess it
        if flagProcessCurrentFile == 0 ...
                || (flagProcessCurrentFile== 1 && filesProcessProgressList(j).Modified < datenum(h(i).date)) 
            try
                % when a file is found that hasn't been processed
                % load it using fr_read_HOBO_file
                [~, ~,tv] = fr_read_HOBO_file(fileName,'caller','Stats');
                tv = tv + time_shift;

                % if there were no errors try to update database
                % Save data belonging to different years to different folders
                % if databasePath contains "\yyyy\" string (replace it with
                % \2005\ for year 2005)
                yearVector = datevec(tv);
                yearVector = yearVector(:,1);
                years = unique(yearVector)';
                ind_yyyy = strfind(databasePath,[filesep 'yyyy' filesep]);
                if ~isempty(ind_yyyy)            
                    databasePathNew = databasePath;
                    for year_ind = years
                        one_year_ind = find(tv > datenum(year_ind,1,1) & tv <= datenum(year_ind+1,1,1));
                        databasePathNew(ind_yyyy+1:ind_yyyy+4) = num2str(year_ind);
                        [k] = db_new_eddy(Stats(one_year_ind),[],databasePathNew,0,[],timeUnit,missingPointValue); %#ok<*FNDSB>
                    end
                else
                    [k] = db_new_eddy(Stats,[],databasePath,0,[],timeUnit,missingPointValue);
                end
                % if there is no errors update records
                numOfFilesProcessed = numOfFilesProcessed + 1;
                numOfDataPointsProcessed = numOfDataPointsProcessed + length(tv);
                if flagProcessCurrentFile == 1
                    filesProcessProgressList(j).Modified = datenum(h(i).date);
                end
            catch
                fprintf('Error in processing of: %s\n',fullfile(pth,h(i).name))
            end % of try
        end %  if filesProcessProgressList(j).Modified < datenum(h(i).date)
    end % for i=1:length(h)
    % Close progress bar
    close(hnd_wait)
    % Return warning state 
    try  %#ok<TRYNC>
       for i = 1:length(warning_state)
          warning(warning_state(i).identifier,warning_state(i).state)
       end
    end

    if flagProcessCurrentFile == 1
        save(processProgressListPath,'filesProcessProgressList')
    end
else
    fprintf('No files matching: %s are found\nExiting...\n',wildCardPath);
    numOfFilesProcessed = 0;
    numOfDataPointsProcessed = 0;
end

% this function returns and index pointing to where fileName is in the 
% fileProcessProgressList.  If fileName doesn't exist in the list
% the output is list length + 1
function ind = findFileInProgressList(fileName, filesProcessProgressList)

    ind = [];
    for j = 1:length(filesProcessProgressList)
        if strcmp(fileName,filesProcessProgressList(j).Name)
            ind = j;
            break
        end %  if strcmp(fileName,filesProcessProgressList(j).Name)
    end % for j = 1:length(filesProcessProgressList)
    if isempty(ind)
        ind = length(filesProcessProgressList)+1;
    end 
