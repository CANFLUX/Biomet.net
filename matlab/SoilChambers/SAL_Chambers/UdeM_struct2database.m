function [structIn,dbFileNames, dbFieldNames,errCode] = UdeM_struct2database(structIn,pthOut,verbose_flag,excludeSubStructures,timeUnit,missingPointValue)
% UdeM_struct2database - creates database from UdeM chamber data structures
%
% eg. [structIn,dbFileNames, dbFieldNames,errCode] = ...
%             UdeM_struct2database(Stats,'v:\database\2023\BBS\Chambers',[],[],[],NaN);
%       would update the database using for the year 2023.
%
% Inputs:
%       structIn                - input data structure. Has to contain a structIn.TimeVector!  
%       pthOut                  - data base location for the output data
%       verbose_flag            - 1 -ON (default), 
%                                 otherwise - OFF
%       excludeSubStructures    - cell array or a string with names or a name
%                                 of the substructure within structIn or HHour that should not be
%                                 processed.  Setting excludeSubStructures to 'DataHF' will remove
%                                 the field 'DataHF from structIn.
%       timeUnit                - minutes in the sample period (spacing between two
%                                 consecutive data points. Default '30min' (hhour)
%       missingPointValue       - value to fill in for the missing data points. Default: NaN
%
% Outputs:
%       structIn                - filtered and sorted input structIn
%       dbFileNames             - database file names
%       dbFieldNames            - structIn field names
%       errCode                 - error code
%
%
%
% (c) Zoran Nesic               File created:       Jan 10, 2026
%                               Last modification:  Jan 10, 2026

% Revisions:
% 

fprintf(2,'UdeM_struct2database function is being tested. Not fully debugged yet.\n');

    arg_default('verbose_flag',1);              % default 1 (ON)
    arg_default('excludeSubStructures',[]);     % default exclude none
    arg_default('timeUnit','30min');            % default is 30 minutes
    arg_default('missingPointValue',NaN);       % missing points set to NaN
        
    if verbose_flag == 1; fprintf('\n------ UdeM_struct2database processing ---------\n');end

    % Initiate default outputs
    dbFileNames = [];
    dbFieldNames = [];
    errCode = 10;       % no data processed

    % Make sure the output path has proper filesep for this OS
    pthOut = fullfile(pthOut);

    % Remove any topmost fields that don't need to be converted to the data
    % base format:
    if ~isempty(excludeSubStructures)
        structIn = rmfield(structIn,excludeSubStructures);
    end
    
    % the number of fields in structIn
    allFieldNames = fieldnames(structIn);
    nFields = length(allFieldNames);

    %
    % extract the time vector and round it to the nearest timeUnit
    %
    tic;
    new_tv = fr_round_time(structIn.TimeVector,timeUnit,1);

    % Filter based on the bad new_tv data
    % Keep only tv that are numbers and not zeros
    indGoodTv = find(isfinite(new_tv) & new_tv~=0);
    new_tv = new_tv(indGoodTv);
    if length(indGoodTv) ~= length(new_tv)
        for cntFields = 1:nFields
            sFieldName = char(allFieldNames(cntFields));
            structIn.(sFieldName) = structIn.(sFieldName)(indGoodTv);
        end
    end
    
    % Make sure there are no duplicate entries.
    % If there are duplicate entries, keep the last one
    [tmp_new_tv,IA]=unique(new_tv,'last');
    if length(tmp_new_tv) ~= length(new_tv)               
        for cntFields = 1:nFields
            sFieldName = char(allFieldNames(cntFields));
            structIn.(sFieldName) = structIn.(sFieldName)(IA);
        end
        new_tv = tmp_new_tv;
    end
    
    % Sort the time vector and the structure
    [new_tv,IA] = sort(new_tv);
    if ~all(diff(IA)==1)                 % does data need sorting?
        for cntFields = 1:nFields
            sFieldName = char(allFieldNames(cntFields));
            structIn.(sFieldName) = structIn.(sFieldName)(IA);
        end
    end    
    
    %%
    % Cycle through all years and process data one year at a time  
    % Subtract ~1second from the new_tv otherwise the next statement
    % will never process the data with the new_tv that starts with
    % TimeVector which is exactly at midnight. The "allYears" will not 
    % identify this line as belonging to the previous year.
    % Example:
    %  The following two time vectors should return two allYears (2024 and 2025)
    %  (TimeVector contains *end times* so the first point belong to 2024)
    %  but it returns only one (2025)
    %   unique(year([datenum(2025,1,1,0,0,0); datenum(2025,1,1,0,30,0)]))
    %  The fix is to subtract <1s from the data:
    %   unique(year([datenum(2025,1,1,0,0,0); datenum(2025,1,1,0,30,0)]-1e-6))
    allYears = unique(year(new_tv-1e-6));
    allYears = allYears(:)';   % make sure that allYears is "horizontal" vector
    for currentYear = allYears
        indCurrentYear = find(new_tv > datenum(currentYear,1,1,0,0,0.1) & new_tv <= datenum(currentYear+1,1,1)); %#ok<*DATNM>
        if isempty(indCurrentYear)
            continue
        end
        currentPath = pthOut;
        % Test the path name in case it's given as a generic \yyyy\ or /yyyy/ path
        ind_yyyy = strfind(currentPath,[filesep 'yyyy' filesep]);
        if ~isempty(ind_yyyy) %#ok<*STREMP>
            % Replace yyyy in pathOut with the current year
            currentPath(ind_yyyy+1:ind_yyyy+4) = num2str(currentYear);
        else
            % pathOut does not contain generic yyyy path. 
            % check if it contains the actual year in the path
            ind_yyyy = strfind(currentPath,[filesep num2str(currentYear) filesep]);
            if isempty(ind_yyyy)
                % if pthOut does not contain yyyy nor the current year
                % then quit 
                fprintf(2,'\n*** Error while processing data for year: %d ***\n',currentYear)
                fprintf(2,'  pthOut = %s does not contain year == %d \n  nor the generic placeholder: yyyy. \n  Skipping this year.\n',pthOut,currentYear);           
                % go to the next year in allYears
                continue
            end
        end
        % Now check if the path exists. Create if it doesn't.
        pth_tmp = fr_valid_path_name(currentPath);          
        if isempty(pth_tmp)
            fprintf(1,'Directory %s does not exist!... ',currentPath);
            fprintf(1,'Creating new folder!... ');
            indDrive = find(currentPath == filesep);
            [successFlag] = mkdir(currentPath(1:indDrive(1)),currentPath(indDrive(1)+1:end));
            if successFlag
                fprintf(1,'New folder created!\n');
            else
                fprintf(1,'Error creating folder!\n');
                error('Error creating folder!');
            end
        else
            currentPath = pth_tmp;
        end
        % proceed with the database updates
        
        tvFileName= fullfile(currentPath,'TimeVector');
        % Load up the current timeVector if it exists
        if exist(tvFileName,"file")
            currentTv = read_bor(tvFileName,8);
        else
            % If it doesn't create a full timevector
            currentTv = fr_round_time(datetime(currentYear,1,1,0,0,0)+fr_timestep(timeUnit):fr_timestep(timeUnit):datetime(currentYear+1,1,1,0,0,0),timeUnit)';
        end   

        %--------------------------------------------------------------------------------
        % Find all field names in the structIn
        % (search recursivly for all field names)
        %--------------------------------------------------------------------------------
        if structType == 0
            dbFileNamesTmp = [];
            for cntStruct = 1:length(structIn)
                dbFileNamesTmp = unique([dbFileNamesTmp recursiveStrucFieldNames(structIn,cntStruct)]);
            end
            
            % Remove the cells that do not contain data
            % If there is a field .LR1 that also exists in .LR1.(another_field)
            % than .LR1 does not contain data (it contains cells) and it should be
            % ignored.
            delFields = [];
            cntDelFields = 0;
            for cntFields = 1:length(dbFileNamesTmp)
                currentField = [char(dbFileNamesTmp(cntFields)) '.'];
                for cntOtherFields = cntFields+1:length(dbFileNamesTmp)
                    % if the currentField exists as a start of any other field
                    % that means that it does not contain data. Erase
                    if strfind(char(dbFileNamesTmp(cntOtherFields)),currentField)==1
                        cntDelFields = cntDelFields + 1;
                        delFields(cntDelFields) = cntFields;
                        break
                    end
                end
            end
            % Erase selected names
            if cntDelFields > 0
                dbFileNamesTmp(delFields) = [];
            end            
        else
            dbFileNamesTmp = fieldnames(structIn);
        end

        nFiles = length(dbFileNamesTmp);
        dbFileNames = [];
        dbFieldNames = [];
        for i=1:nFiles
            % create file and field names
            fieldName = char(dbFileNamesTmp(i));
            [fileNameX] = replaceControlCodes(fieldName);
            dbFileNames{i}=fullfile(currentPath,fileNameX);
            dbFieldNames{i} = fieldName; %#ok<*AGROW>
        end
        % Save the data for the currentYear only. 
        errCode = saveAll(structIn,dbFileNames,dbFieldNames,currentTv,new_tv,missingPointValue,structType,indCurrentYear);
        % report time
        tm = toc;
        if errCode ~= 0
            fprintf('     ***  %d errors during processing. ***\n',errCode);
        else
            if verbose_flag,fprintf('     %i database entries for %d generated in %4.1f seconds.\n',length(indCurrentYear),currentYear,tm);end
        end
        tic
    end % currentYear


%===============================================================
%
% Save all files
%
%===============================================================
function errCode = saveAll(statsNew,fileNamesIn,fieldNamesIn,currentTv,inputTv,missingPointValue,structType,indCurrentYear)
    try
        errCode = 0;
        % extract output path (pathOut) from fileNamesIn.
        strTemp = char(fileNamesIn(1));
        indSep = strfind(strTemp,filesep);
        pathOut = strTemp(1:indSep(end)-1); 
    
        % extract the valid time vector range
        inputTv = inputTv(indCurrentYear);
        % combine the two time vectors
        newTv = union(currentTv,inputTv);
        % find where new data (newDataInd) and old data (oldDataInd) fits in the newTv
        [~,newDataInd] = intersect(newTv,inputTv);
        [~,oldDataInd] = intersect(newTv,currentTv);
    
        %-------------------------------------------------------
        % First go through all the 
        % fields in the new data (fileNamesIn) and update them.
        % Warning: This will leave some database files that were
        %          not in the new data structure untouched.
        %          They are going to need to be updated too.
        %          
        for i=1:length(fileNamesIn)
            fileName = char(fileNamesIn(i));
            fieldName = char(fieldNamesIn(i));
            try
                if structType == 0
                    dataIn = get_stats_field_fast(statsNew(indCurrentYear),fieldName);
                else
                    dataIn = statsNew.(fieldName)(indCurrentYear);
                end
                if ~isempty(dataIn)
                    if ~exist(fileName,'file')
                        % if the file doesn't exist
                        % create it (dbase initialization)
                        % special handling of TimeVector:
                        %   - it's double precision
                        %   - it's unique (if it doesn't exist than the database does not exist)
                        % If any of the other file names do not exist a special handling is needed
                        % because that means that a new chamber has been added to the set and that
                        % chamber needs to be aligned in time with the previous chambers. That means that
                        % the trace has to get the NaN-s for all the samples before its first measurement 
                        % happened.
                        if contains(fileName,'TimeVector','IgnoreCase',true)
                            save_bor(fileName,8,newTv);
                        else
                            % this chamber (fileName) was added to the set of measurements
                            % after the database was already initated. Find where the new data fits
                            % and initiate this database file properly
                            dataOut = missingPointValue * ones(size(newTv));
                            if ~isempty(newDataInd)
                                dataOut(newDataInd) = dataIn;
                            end                    
                            if contains(fileName,'RecalcTime','IgnoreCase',true) ...
                                      || contains(fileName,'sample_tv','IgnoreCase',true)...
                                      || contains(fileName,'clean_tv','IgnoreCase',true)
                                save_bor(fileName,8,dataOut);
                            else
                                save_bor(fileName,1,dataOut);
                            end
                        end
                    else
                        % if file already exist open it up
                        % Remeber that it's aligned to currentTv
                        % add the new data in
                        % save it back
        
                        if contains(fileName,'RecalcTime','IgnoreCase',true) ...
                                || contains(fileName,'TimeVector','IgnoreCase',true) ...
                                || contains(fileName,'sample_tv','IgnoreCase',true) ...
                                || contains(fileName,'clean_tv','IgnoreCase',true)
                            oldTrace = read_bor(fileName,8);
                        else                    
                            oldTrace = read_bor(fileName);
                        end % findstr(fileName,'RecalcTime')
                        % combine new with old data
                        dataOut = missingPointValue * ones(size(newTv));
                        if ~isempty(oldDataInd)
                            dataOut(oldDataInd) = oldTrace;
                        end
                        if ~isempty(newDataInd)
                            dataOut(newDataInd) = dataIn;
                        end
                        % Save the new combined trace
                        if contains(fileName,'RecalcTime','IgnoreCase',true) ...
                                || contains(fileName,'TimeVector','IgnoreCase',true) ...
                                || contains(fileName,'sample_tv','IgnoreCase',true)...
                                || contains(fileName,'clean_tv','IgnoreCase',true)
                            save_bor(fileName,8,dataOut);
                        else
                            save_bor(fileName,1,dataOut);
                        end
                       
                    end % ~exist(fileName,'file')
                end % ~isempty(dataIn)
            catch
                disp(['Error while processing: ' fieldName]);
                errCode = errCode + 1;
            end %try
        end % i=1:length(fileNamesIn)
        
        % Some functions expect clean_tv
        % create one by simply copying TimeVector to clean_tv
        try
            copyfile(fullfile(pathOut,'TimeVector'),fullfile(pathOut,'clean_tv'))
        catch
        end
        %end % of function
    
        %-------------------------------------------------------
        % At this point it's possible to have some database files
        % that were not updated (were not incremented in size) because
        % those chambers were not sampled (the field names are not existant)
        % in the current data set (statsNew)
        % Deal with them here:
    
        % Gather all file names in the database folder 
        allFiles = dir(pathOut);
        for cntAllFiles=1:length(allFiles)
            fileName = fullfile(allFiles(cntAllFiles).folder,allFiles(cntAllFiles).name);
            if ~allFiles(cntAllFiles).isdir ...
               && ~contains(allFiles(cntAllFiles).name,'TimeVector','IgnoreCase',true) ...
               && ~contains(allFiles(cntAllFiles).name,'.mat','IgnoreCase',true) ...
               && ~contains(allFiles(cntAllFiles).name,'.DS_Store','IgnoreCase',true) ...
               && ~contains(allFiles(cntAllFiles).name,'clean_tv','IgnoreCase',true)
                
                foundFile = false;                      % Default: the file does not exist in fileNamesIn  
                % search for fileName in fileNamesIn
                for cntAllFields = 1:length(fileNamesIn)
                    newFileName = char(fileNamesIn(cntAllFields));
                    if strcmpi(fileName,newFileName)
                        % file found. Set the flag to true and exit
                        foundFile = true;
                        break
                    end
                end
                
                if ~foundFile
                    % if the fileName wasn't found in fileNamesIn
                    % it needs to be updated by adding missingPointValue to it.
                    % Start by loading the file up                  
                    if contains(fileName,'RecalcTime','IgnoreCase',true) ...
                            || contains(fileName,'TimeVector','IgnoreCase',true) ...
                            || contains(fileName,'sample_tv','IgnoreCase',true) ...
                            || contains(fileName,'clean_tv','IgnoreCase',true)
                        oldTrace = read_bor(fileName,8);
                    else
                        oldTrace = read_bor(fileName);
                    end                           
                    % combine new with the old data
                    dataOut = missingPointValue * ones(size(newTv));
                    if ~isempty(oldDataInd)
                        dataOut(oldDataInd) = oldTrace;
                    end
                    % Save the new combined trace
                    if contains(fileName,'RecalcTime','IgnoreCase',true) ...
                            || contains(fileName,'TimeVector','IgnoreCase',true) ...
                            || contains(fileName,'sample_tv','IgnoreCase',true) ...
                            || contains(fileName,'clean_tv','IgnoreCase',true)
                        save_bor(fileName,8,dataOut);
                    else
                        save_bor(fileName,1,dataOut);
                    end                    
                end
            end
        end
    catch ME
        disp(ME);
        disp(ME.stack(1));
        error('Unhandled error in db_struct2database.m')
    end
      

%===============================================================
%
% replace control codes
%
%===============================================================

function [fileName] = replaceControlCodes(oldName)
% replace all the brackets and commas using the following table
% '('  -> '_'
% ','  -> '_'
% ')'  -> []
% '__' -> '.'
ind = strfind(oldName,'__' );
if length(ind)==1   % the special code of '__' works only if there is only one in the name
    oldName = [oldName(1:ind-1) '.' oldName(ind+2:end)];
end
ind = find(oldName == '(' | oldName == ',');
oldName(ind) = '_'; %#ok<*FNDSB>
ind = find(oldName == ')');
oldName(ind) = [];
fileName = oldName;

%end % of function

%===============================================================
%
% Recursive structure field name search
%
%===============================================================

function dbFileNames = recursiveStrucFieldNames(StatsAll,n_template)
arg_default('n_template',1);
dbFileNames = [];
nFiles = 0;
statsFieldNames = fieldnames(StatsAll);
for i = 1:length(statsFieldNames)
    fName = char(statsFieldNames(i));
    % load the first element of StatsAll to
    % examine the structure type
    fieldTmp = getfield(StatsAll,{n_template},fName);
    % skip fields 'Configuration', 'Spectra' and all character and cell fields
    if ~strcmp(fName,'Configuration') & ~ischar(fieldTmp) & ~iscell(fieldTmp) & ~strcmp(fName,'Spectra')
        % is it a vector or not
        nLen = length(fieldTmp);
        if nLen > 1
            [nCol, nRow] = size(fieldTmp);
            for j = 1:nCol
                for j1 = 1:nRow
                    nFiles = nFiles + 1;
                    if nCol == 1 | nRow == 1
                        % if it's a one dimensional vector use only one index
                        jj = max(j,j1);
                        dbFileNames{nFiles} = [fName '(' num2str(jj) ')' ];
                    else
                        % for two dimensional vectors use two
                        dbFileNames{nFiles} = [fName '(' num2str(j) ',' num2str(j1) ')' ];
                    end % if nCol == 1 or nRow == 1
                    % test if it's a structure and do a recursive call
                    if isstruct(fieldTmp)
                        %-------------------------
                        % recursive call goes here
                        %-------------------------
                        %                    fieldI = get_stats_field_fast(StatsAll,fName);
                        if nCol == 1 | nRow == 1
                            % if it's a one dimensional vector use only one index
                            jj = max(j,j1);
                            dbFileNamesTmp = recursiveStrucFieldNames(fieldTmp(jj));
                        else
                            % for two dimensional vectors use two
                            dbFileNamesTmp = recursiveStrucFieldNames(fieldTmp(j,j1));
                        end % if nCol == 1 or nRow == 1

                        mFiles = length(dbFileNamesTmp);
                        dbFileNamesBase = char(dbFileNames{nFiles});
                        % move the pointer back to overwrite the last entry
                        nFiles = nFiles - 1;
                        for k=1:mFiles
                            nFiles = nFiles + 1;
                            dbFileNames{nFiles}=[dbFileNamesBase '.' char(dbFileNamesTmp(k))];
                        end % i=1:nFiles
                    end % if isstruc(fieldTmp)
                end % for j1=1:nRow
            end % j = 1:nCol
        else
            % save new file name
            nFiles = nFiles + 1;
            dbFileNames{nFiles} = fName;
            % test if it's a structure and do a recursive call
            if isstruct(fieldTmp)
                %-------------------------
                % recursive call goes here
                %-------------------------
                %                    fieldI = get_stats_field_fast(StatsAll,fName);
                dbFileNamesTmp = recursiveStrucFieldNames(fieldTmp);
                mFiles = length(dbFileNamesTmp);
                dbFileNamesBase = char(dbFileNames{nFiles});
                % back out the index by one (over-write the last fName entry)
                nFiles = nFiles - 1;
                for k=1:mFiles
                    nFiles = nFiles + 1;
                    dbFileNames{nFiles}=[dbFileNamesBase '.' char(dbFileNamesTmp(k))];
                end % i=1:nFiles
            end % if isstruc(fieldTmp)
        end % nLen > 1
    end % fName ~= 'Configuration'
end % for i =

function timeStep = fr_timestep(unitsIn)
    if strcmpi(unitsIn(end-2:end),'MIN')
        if length(unitsIn)==3
            numOfMin = 1;
        else
            numOfMin = str2double(unitsIn(1:end-3));
        end
    else
        numOfMin = [];
    end
    
    if strcmpi(unitsIn,'SEC')
        timeStep = 1/24/60/60; %#ok<*FVAL>
    elseif ~isempty(numOfMin)
        timeStep = 1/24/60*numOfMin;
    elseif strcmpi(unitsIn,'HOUR')
        timeStep = 1/24;    
    elseif strcmpi(unitsIn,'DAY')
        timeStep = 1;   
    else
        error 'Wrong units!'
    end    
