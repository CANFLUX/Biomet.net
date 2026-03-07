function [numOfFilesProcessed,numOfDataPointsProcessed] = fr_EFOY_database(...
                wildCardPath,processProgressListPath,databasePath,...
                timeUnit,structPrefix,missingPointValue)
% fr_EFOY_database - read EFOY generator xlsx files and create/update 
%                        Biomet/Micromet climate data base
% 
% Inputs:
%       wildCardPath            - full file name including path. Wild cards accepted
%       processProgressListPath - path where the progress list is kept
%       databasePath            - path to output location  (*** see the note above ***)
%       timeUnit                - minutes in the sample period (spacing between two
%                                 consecutive data points). Default 30 (hhour)
%       structPrefix            - used to add prefix to all database file names
%                                 (structPrefix.TimeVector,...) so that multiple loggers
%                                 can be stored in the same database folder
%       missingPointValue       - default 0 (Biomet legacy), all new non-Biomet sites should be NaN
%
%
%
% NOTE:
%       databasePath needs to include "\yyyy\" string if multiple years of
%       data are going to be found in the wildCardPath folder!
%
%
%
% Zoran Nesic           File Created:      Mar  5, 2026
%                       Last modification: Mar  6, 2026

%
% Revisions:
%

    arg_default('timeUnit','30MIN');        % default is 30 minutes
    arg_default('structPrefix',[]);         % default is that there is no prefix to database file names
    arg_default('missingPointValue',NaN);   % default is 0, legacy issue. Use NaN for all non-Biomet-UBC databases 
    
    h = dir(wildCardPath);
    if isempty(h)
        error('File: %s not found\n',wildCardPath);
    end
    
    if exist(processProgressListPath,'file')
        load(processProgressListPath,'filesProcessProgressList');
    else
        filesProcessProgressList = [];
    end
    
    numOfFilesProcessed = 0;
    numOfDataPointsProcessed = 0;
    warning_state = warning;
    warning('off')
    hnd_wait = waitbar(0,'Updating site database...');
    
    for i=1:length(h)
        pth = h(i).folder;
        try 
            stPth = 1;if length(pth)>30,stPth=length(pth)-30;end
            waitbar(i/length(h),hnd_wait,{'Processing: %s ', ['...' pth(stPth:end) ], h(i).name})
        catch 
            waitbar(i/length(h),hnd_wait)
        end
    
        % Find the current file in the fileProcessProgressList
        j = findFileInProgressList(h(i).name, filesProcessProgressList);
        % if it doesn't exist add a new value
        if j > length(filesProcessProgressList)
            filesProcessProgressList(j).Name = h(i).name;
            filesProcessProgressList(j).Modified = 0;      % datenum(h(i).date);
        end
        % if the file modification data change since the last processing then
        % reprocess it
        if filesProcessProgressList(j).Modified < datenum(h(i).date)
            try
                % when a file is found that hasn't been processed
                % load it.
                fileName = fullfile(pth,h(i).name);
                % read xlsx file as a time table
                tbIn = readtimetable(fileName);
                % resample at 30-min rate
                tbIn = retime(tbIn, 'regular', @nanmean, 'TimeStep', minutes(30));
                % convert the time table to Biomet struct type 1
                EFOY_stats = timetable2Struct1(tbIn);
                
                % If required, add Prefix to the output structure.
                if ~isempty(structPrefix)
                    temp = [];
                    for k=1:length(EFOY_stats)
                        temp(k).(structPrefix) = EFOY_stats(k); %#ok<*AGROW>
                        temp(k).(structPrefix).TimeVector = [];
                        temp(k).TimeVector = EFOY_stats(k).TimeVector;
                    end
                    EFOY_stats = temp;
                end
                % Save structure to database
                [~,~, ~,errCode] = db_struct2database(EFOY_stats,...
                                                       databasePath,[],[],...
                                                       timeUnit,missingPointValue,1,1);
                numOfFilesProcessed = numOfFilesProcessed + 1;
                numOfDataPointsProcessed = numOfDataPointsProcessed + length(EFOY_stats.TimeVector);
                if errCode == 0
                    filesProcessProgressList(j).Modified = datenum(h(i).date);
                end
            catch
                fprintf('Error in processing of: %s\n',fullfile(pth,h(i).name));
            end % of try
        end %  if filesProcessProgressList(j).Modified < datenum(h(i).date)
    end % for i=1:length(h)
    % Close progress bar
    close(hnd_wait)
    % Return warning state 
    try 
       for i = 1:length(warning_state)
          warning(warning_state(i).identifier,warning_state(i).state)
       end
    catch
    end
    
    if ~isempty(processProgressListPath)
        try
            save(processProgressListPath,'filesProcessProgressList')
        catch
            error('Error while saving processProgressList\n');
        end
    else
        fprintf('Data processed. \nprocessProgressList not saved per user''s request.\n\n');
    end
end


%=================================================
% ------------ Helper functions ------------------
%=================================================


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
end

function S = timetable2Struct1(TT)
    %TIMETABLETOSTRUCTVECTORS Convert a timetable to a struct of column vectors.
    %   S = TIMETABLETOSTRUCTVECTORS(TT) converts the timetable TT into a struct S.
    %   - S.TimeVector contains the row times from TT (datenum).
    %   - Each variable in TT becomes one or more vector fields in S.
    %     * If a variable is n-by-1, it becomes S.<VarName>.
    %     * If a variable is n-by-m (m > 1), it becomes S.<VarName>_1, ..., S.<VarName>_m.
    %
    %   Notes:
    %   - Variable/field names are sanitized via matlab.lang.makeValidName.
    %   - Data types are preserved (numeric, logical, string, cellstr, datetime, duration, categorical, etc.).
    %
    %   Example:
    %       TT = timetable(datetime(2024,1,1)+(0:2)', [1;2;3], rand(3,2), 'VariableNames', {'A','B'});
    %       S  = timetableToStructVectors(TT);
    %       % S has fields: TimeVector, A, B_1, B_2
    
    % Basic validation
    if ~istimetable(TT)
        error('Input must be a timetable.');
    end
    
    % Initialize output struct
    S = struct();
    
    % Extract row times into TimeVector (as datenum
    S.TimeVector = datenum(TT.Properties.RowTimes);
    
    % Get variable names
    varNames = TT.Properties.VariableNames;
    n = height(TT);
    
    for i = 1:numel(varNames)
        rawName = varNames{i};
        baseField = matlab.lang.makeValidName(rawName);
    
        % Extract the variable data
        data = TT.(rawName);
    
        % Ensure rows match timetable height
        if size(data,1) ~= n
            error('Variable "%s" has %d rows but timetable has %d rows.', rawName, size(data,1), n);
        end
    
        % Handle scalars-per-row or multi-column variables
        % If it's a vector (n-by-1), store directly
        if iscolumn(data)
            S.(baseField) = data;
            continue;
        end
    
        % If it's a 2D array n-by-m with m>1, split by columns
        if ismatrix(data) && size(data,2) > 1
            m = size(data,2);
            for k = 1:m
                fieldK = sprintf('%s_%d', baseField, k);
                S.(fieldK) = data(:, k);
            end
            continue;
        end
    
        % If it's higher-dimensional (e.g., n-by-a-by-b), try to split second dim
        if ndims(data) > 2
            % Attempt to reshape to n-by-M and then split
            sz = size(data);
            if sz(1) ~= n
                error('Unsupported variable shape for "%s".', rawName);
            end
            M = prod(sz(2:end));
            data2D = reshape(data, n, M);
            for k = 1:M
                fieldK = sprintf('%s_%d', baseField, k);
                S.(fieldK) = data2D(:, k);
            end
            continue;
        end
    
        % Fallback: store as-is (n-by-1 or split already handled).
        S.(baseField) = data;
    end
end
