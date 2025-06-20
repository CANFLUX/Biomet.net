function [numOfFilesProcessed,numOfDataPointsProcessed] = fr_Hydrology_database(wildCardPath,processProgressListPath,databasePath,time_shift,timeUnit,missingPointValue)
% fr_Hydrology_database - reads Carbonique Hydrology files and puts data into data base
% 
% fr_Hydrology_database(wildCardPath,processProgressListPath,databasePath,time_shift,timeUnit,missingPointValue)
%
% Example:
% [nFiles,nHHours]=fr_Hydrology_database('D:\EXO3_LAT02_20250528.csv', ...
%                                  'E:\Pipeline_Projects\Database\log\UQAM_2_LAT_OUT_progressList.mat',...
%                                  'E:\Pipeline_Projects\Database\yyyy\Hydrology\UQAM_2_LAT_OUT');
%       This updates/creates data base under E:\Pipeline_Projects\Database folder.
%
%
%
% NOTE1:
%       databasePath needs to include "\yyyy\" string if multiple years of
%       data are going to be found in the wildCardPath folder!
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
%
%
% Zoran Nesic                   File Created:      Jun 20, 2024
%                               Last modification: Jun 20, 2025

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

allFiles = dir(wildCardPath);

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
                [~, ~,tv,Stats] = fr_read_Hydrology_file(fileName);
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
