function [numOfFilesProcessed,numOfDataPointsProcessed] = fr_EddyPro_database(wildCardPath,processProgressListPath,databasePath,time_shift,timeUnit,missingPointValue,optionsFileRead)
% fr_EddyPro_database - reads EddyPro full_output, _biomet_ or the summary files and puts data into data base
% 
% fr_EddyPro_database(wildCardPath,processProgressListPath,databasePath,time_shift,timeUnit,missingPointValue)
%
% Example:
% [nFiles,nHHours]=fr_EddyPro_database('d:\Sites\HH\SmartFlux\*_EP-Summary.txt', ...
%                                  '\\annex001\database\HH\2024\HH_EddyPro_progressList.mat','\\annex001\database\yyyy\');
%       This updates or creates data base under \\annex001\database folder.
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
% Zoran Nesic                   File Created:      Feb  16, 2024
%                               Last modification: Mar  22, 2025

% Created based on fr_SmartFlux_database.m

%
% Revisions:
%
% Mar 22, 2025 (Zoran)
%   - Now using sort_EdduPro_files instead of simple dir(). This call returnes a list
%     of files that match the wildCardPath in the ascending order of their time stamps.
%     See sort_EddyPro_files() for more details.
%   - renamed a few variables to make code easier to read ("i","j"...)
% Jan 4, 2025 (Zoran)
%   - Improvement: the function now checks if the input file is empty (h(i).bytes == 0) before tryint to process it.
%     In case the file is empty, the program will report that it's skipping it and it will mark it as processed.
%   - Improvement: split the waitbar message into two lines to improve readability.
% Sep 2, 2024 (Zoran)
%   - Added new parameter optionsFileRead to be passed to
%     fr_read_EddyPro_file. See that file for more info. 


arg_default('time_shift',0);
arg_default('timeUnit','30MIN'); %
arg_default('missingPointValue',0); %   % default missing point code is 0
arg_default('optionsFileRead',[]);

% append filesep on the end of databasePath
% some legacy programs expect it
databasePath = fullfile(databasePath,filesep);

%allFiles = dir(wildCardPath);
allFiles = sort_EddyPro_files(wildCardPath);

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
                Stats = [];
                fprintf(2,'Empty file: %s. Skipping... \n', fileName);
            else            
                [~, ~,tv,Stats] = fr_read_EddyPro_file(fileName,[],[],optionsFileRead);
                tv = tv + time_shift;
                structType = 1;
                db_struct2database(Stats,databasePath,0,[],timeUnit,missingPointValue,structType,1);         
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
