function [structIn,dbFileNames, dbFieldNames,errCode] = db_struct2database(structIn,pthOut,verbose_flag,excludeSubStructures,timeUnit,missingPointValue,structType,forceFullDB)
% db_struct2database - creates a sparse database (database that does not contain all hhour values)
%
% eg. [structIn,dbFileNames, dbFieldNames,errCode] = ...
%             db_struct2database(Stats,'v:\database\2023\BBS\Chambers',[],[],[],NaN);
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
%       structType              - 0 [default] - Struct(ind).Variable, 1 - Struct.Variable(ind).
%                                 The default is to index the structure using the old style: Struct(:).TimeVector,...
%                                 This works well with the UBC Biomet EC calculation program outputs which are large
%                                 nested trees of outputs: "Stats(:).MainEddy.Three_Rotations.AvgDtr.Fluxes.Hs"
%                                 For most of the simple input files like the ones from EddyPro, Ameriflux, SmartFluxPro
%                                 it's much faster to load the data into the new style: Stats.TimeVector(:).
%                                 Use structType = 1 for the non-legacy simple stuff.
%                                 Note: There is a matching parameter for the database creation program: fr_read_generic_data.
%                                       Use the same value for structType!
%       forceFullDB             - 0 - creates sparse (non-complete) database, 
%                                 1 [default] - creates standard Biomet database (all points in a year) 
%
% Outputs:
%       structIn                - filtered and sorted input structIn
%       dbFileNames             - database file names
%       dbFieldNames            - structIn field names
%       errCode                 - error code
%
%
% NOTE: Update this function by adding a flag that forces a full (non-spares) database
%       creation. Hint: if the target path contains a TimeVector with all elements,
%       then the new database will have all elements. So, if the "force flag" is true
%       create and write a full TimeVector
%
%
% (c) Zoran Nesic               File created:       Sep 28, 2023
%                               Last modification:  Aug 11, 2024

% Revisions:
% 
% Aug 11, 2024 (Zoran)
%   - Fixed bug: clean_tv file should have been treated the same way as sample_tv 
%     and other time traces but it wasn't. That caused an error when updateing folders
%     that contained this file.
% May 9, 2024 (Zoran)
%   - Bug fix. This line was wrong because it worked only for 30-minute tables: 
%       currentTv = fr_round_time(datetime(currentYear,1,1,0,30,0):fr_timestep(timeUnit):datetime(currentYear+1,1,1,0,0,0))';
%     correct line is:
%     currentTv = fr_round_time(datetime(currentYear,1,1,0,0,0)+fr_timestep(timeUnit):fr_timestep(timeUnit):datetime(currentYear+1,1,1,0,0,0),timeUnit)';
% Mar 22, 2024 (Zoran)
%   - Bug fix: when the output folder contained ".DS_Store" file saveAll would
%     crash. Added this line: "&& ~contains(allFiles(cntAllFiles).name,'.DS_Store') ..."
% Mar 11, 2024 (Zoran)
%   - found a bug. The program was not dealing with the duplicate time-vector entries
%     properly (actually, not at all). 
%     It was testing: 
%            [new_tv,IA]=unique(new_tv);
%            if length(tmp_new_tv) ~= length(new_tv)
%     but this was never true IA and new_tv were always of the same size.
%     Changed to:
%           [tmp_new_tv,IA]=unique(new_tv,'last');
%           if length(tmp_new_tv) ~= length(new_tv)
%     The parameter 'last' in unique specifies that last duplicate entry should be kept.
%
% Jan 17, 2024 (Zoran)
%  - added forceFullDB flag. The program now defaults to a full data base (for 30min data that means 17520 points)
% Jan 12, 2024 (Zoran)
%  - added an option to deal with structIn that are not in the old format: "structIn(:).Field1.Field1_1"
%    but in a much simpler, one level, "structIn.Field1(:)", "structIn.Field2(:)" format.
%    See fr_read_generic_data.m for more information.
%  - found a bug. 
%      It was:     indCurrentYear = find(new_tv > datenum(currentYear,1,1,1,0,0.1) ...
%      Instead of: indCurrentYear = find(new_tv > datenum(currentYear,1,1,0,0,0.1) ...
% Jan 2, 2024 (Zoran)
%  - enabled multiple years in the same xlsx file. If the structIn contains
%    multiple years in it that the pathOut has to contain '\yyyy\'.
%    If the path contains a fixed year (2024) then only the data for that year
%    will be processed.
% Dec 21, 2023 (Zoran)
%  - minor edits (changed 30 to '30min')
% Nov 16, 2023 (Zoran)
%  - The previous bug "fix" wasn't complete. There were multiple issues
%    but the main one was that the program didn't properly handle 
%    cases with 8 byte storage (tv vectors) and 4 byte storage (data)
% Nov 10, 2023 (Zoran)
%  - Fixed a bug that crashed the processing if a new chamber was added
%    to the set. In that case the missing data (the data for that chamber
%    before it was introduced to the set) was not initiated properly. The fix assures
%    that the missing values are initiated as NaNs.
% Oct 4, 2023 (Zoran)
%  - added errCode as an output

    
    arg_default('verbose_flag',1);              % default 1 (ON)
    arg_default('excludeSubStructures',[]);     % default exclude none
    arg_default('timeUnit','30min');            % default is 30 minutes
    arg_default('missingPointValue',0);         % default is 0 (legacy Biomet value). Newer setups should use NaN
    arg_default('structType',0);
    arg_default('forceFullDB',1);

    if verbose_flag == 1; fprintf('\n------ db_struct2database processing ---------\n');end

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
    if structType == 0
        new_tv = fr_round_time(get_stats_field_fast(structIn,'TimeVector'),timeUnit,1);
    else
        new_tv = fr_round_time(structIn.TimeVector,timeUnit,1);
    end

    % Filter based on the bad new_tv data
    % Keep only tv that are numbers and not zeros
    indGoodTv = find(isfinite(new_tv) & new_tv~=0);
    new_tv = new_tv(indGoodTv);
    if length(indGoodTv) ~= length(new_tv)
        if structType == 0
            structIn = structIn(indGoodTv);
        else
            for cntFields = 1:nFields
                sFieldName = char(allFieldNames(cntFields));
                structIn.(sFieldName) = structIn.(sFieldName)(indGoodTv);
            end
        end    
    end
    
    % Make sure there are no duplicate entries.
    % If there are duplicate entries, keep the last one
    [tmp_new_tv,IA]=unique(new_tv,'last');
    if length(tmp_new_tv) ~= length(new_tv)               
        if structType == 0
            structIn = structIn(IA);
        else
            for cntFields = 1:nFields
                sFieldName = char(allFieldNames(cntFields));
                structIn.(sFieldName) = structIn.(sFieldName)(IA);
            end
        end   
        new_tv = tmp_new_tv;
    end
    

    % Sort the time vector and the structure
    [new_tv,IA] = sort(new_tv);
    if ~all(diff(IA)==1)                 % does data need sorting?
        if structType == 0
            structIn = structIn(IA);
        else
            for cntFields = 1:nFields
                sFieldName = char(allFieldNames(cntFields));
                structIn.(sFieldName) = structIn.(sFieldName)(IA);
            end
        end    
    end    
    
    %%
    % Cycle through all years and process data one year at a time    
    allYears = unique(year(new_tv));
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
            currentTvfile = read_bor(tvFileName,8);
        else
            currentTvfile = [];
        end   

        % First check if working with a full data base (17,520 samples for 365 day in case of 30-min sampling)
        if forceFullDB == 1
            currentTv = fr_round_time(datetime(currentYear,1,1,0,0,0)+fr_timestep(timeUnit):fr_timestep(timeUnit):datetime(currentYear+1,1,1,0,0,0),timeUnit)';
            % to prevent mistakently overwriting a sparse database, check if TimeVector already exists and it's of
            % different size that currentTv
            if ~(isempty(currentTvfile) | ...
                    (~isempty(currentTvfile) && (length(currentTvfile)== length(currentTv)))) 
                    % |...
                    % ((length(currentTvfile)== length(currentTv)) && all(currentTv==currentTvfile)))
                error('\n*******\n  Folder: %s \n  already contains TimeVector and it is not of the same size.\n  You might be attempting to overwrite a sparse database!\n',currentPath);
            end
        else
            currentTv =  currentTvfile;
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
                        if contains(fileName,'TimeVector')
                            save_bor(fileName,8,newTv);
                        else
                            % this chamber (fileName) was added to the set of measurements
                            % after the database was already initated. Find where the new data fits
                            % and initiate this database file properly
                            dataOut = missingPointValue * ones(size(newTv));
                            if ~isempty(newDataInd)
                                dataOut(newDataInd) = dataIn;
                            end                    
                            if contains(fileName,'RecalcTime') ...
                                      || contains(fileName,'sample_tv')...
                                      || contains(fileName,'clean_tv')
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
        
                        if contains(fileName,'RecalcTime') ...
                                || contains(fileName,'TimeVector') ...
                                || contains(fileName,'sample_tv') ...
                                || contains(fileName,'clean_tv')
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
                        if contains(fileName,'RecalcTime') ...
                                || contains(fileName,'TimeVector') ...
                                || contains(fileName,'sample_tv')...
                                || contains(fileName,'clean_tv')
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
               && ~strcmpi(allFiles(cntAllFiles).name,'TimeVector') ...
               && ~contains(allFiles(cntAllFiles).name,'.mat','IgnoreCase',true) ...
               && ~contains(allFiles(cntAllFiles).name,'.DS_Store') ...
               && ~contains(allFiles(cntAllFiles).name,'clean_tv')
                
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
                    if contains(fileName,'RecalcTime') ...
                            || contains(fileName,'TimeVector') ...
                            || contains(fileName,'sample_tv') ...
                            || contains(fileName,'clean_tv')
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
                    if contains(fileName,'RecalcTime') ...
                            || contains(fileName,'TimeVector') ...
                            || contains(fileName,'sample_tv') ...
                            || contains(fileName,'clean_tv')
                        save_bor(fileName,8,dataOut);
                    else
                        save_bor(fileName,1,dataOut);
                    end                    
                end
            end
        end
    catch ME
        disp(ME);
        error('\n\nUnhandled error in db_struct2database.m\n')
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
