function structConfig = db_update_GHG_files(dateIn,siteID,hfPath,flagSave,dbPath,flagVerbose)
% structConfig = process_GHG_files(dateIn,siteID,hfPath,flagSave)
% 
% This function reads all GHG information (data stats and configuration) and 
% stores that info (usually) under 'database\yyyy\siteID\Flux\GHG'
%
% Inputs:
%   dateIn              - range of dates to process (rounded to days)
%   siteID              - site ID
%   hfPath              - path to raw data folder (P:\Project\Sites\siteID\HighFrequencyData\raw)
%   flagSave            - true (default) save structConfig into database
%   pthOut              - output path for the database (P:\Project\Database\yyyy)
%   flagVerbose         - false (default) - don't print output
%
% Outputs:
%   structConfig        - output (optional)
%
%
% Note:
%   - works with 30-minute files only
%
%
% (c) Zoran Nesic                   File created:       Feb 16, 2026
%                                   Last modification:  Feb 17, 2026
%

% Revisions:
%

arg_default('flagSave',1)
arg_default('flagVerbose',0)

dateIn = round(dateIn);  % cycle trough days

tst = 0;  % 1 - load the data instead of processing it (troubleshooting on Zoran's pc only)
if tst~=1
    cntData = 0;
    startTime0 = datetime;
    for currentDay = dateIn
        fPattern = sprintf('%s*.ghg',datestr(currentDay,'yyyy-mm-ddT')); %#ok<DATST>
        patternOneDay = fullfile(hfPath,siteID,'raw',num2str(year(currentDay)),sprintf('%02d',month(currentDay)),fPattern);
        allFiles = dir(patternOneDay);
        for cntFile=1:length(allFiles)
            startTime = datetime;
            pathToGHGfile = fullfile(allFiles(cntFile).folder,allFiles(cntFile).name);
            [~,~,~,~,structConfigTmp] = fr_read_GHG_file(pathToGHGfile);
            %dataOut(cntFile) = dataOutTmp;
            cntData = cntData + 1;
            structConfig(cntData) = structConfigTmp; %#ok<AGROW>
            if flagVerbose
                fprintf('Done: %s (%4.1f sec )\n',pathToGHGfile,seconds(datetime-startTime));
            end
        end
        save(['structConfig_test_' num2str(year(currentDay))] ,'structConfig')
    end
    if flagVerbose
        fprintf('Loaded data from %d GHG files in %4.1f seconds\n',cntData,seconds(datetime-startTime0));
    end
else
    load (['structConfig_test_' num2str(year(dateIn(end)))]);
end
if flagSave
    % convert structConfig from type 0 to type 1
    structConfigType1 = db_convert_structType_0_to_1(structConfig);
    % convert all elements of structConfigType1 to set of
    % file names and corresponding data arrays
    outputFilesAndData = db_struct2filenames(structConfigType1);
    % extract and round up the TimeVector
    new_tv = [structConfig(:).TimeVector];
    new_tv = fr_round_time(new_tv,'30MIN',2);
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
        startTime  = datetime;
        % create time vector for the full year
        currentYearTv = fr_round_time(datetime(currentYear,1,1,0,30,0):1/48:datetime(currentYear+1,1,1,0,0,0),'30min')';

        % find index of all points belonging to this year
        [~,indCurrentYear,indNewData] = intersect(currentYearTv,new_tv,'stable');
        %indCurrentYear = find(new_tv > datenum(currentYear,1,1,0,0,0.1) & new_tv <= datenum(currentYear+1,1,1)); %#ok<*DATNM>
        % skip to the next year if there are no points belonging to currentYear
        if isempty(indCurrentYear)
            continue
        end
        
        % create path string
        currentPath = fullfile(dbPath,num2str(currentYear),siteID,'Flux','GHG');        
        % Now check if the path exists. Create if it doesn't.
        currentPath = confirmOrCreate(currentPath);
        %------------------------------------
        % proceed with the database updates
        %------------------------------------
        
        % Test the existance of clean_tv. Create if needed.
        if ~exist(fullfile(currentPath,'clean_tv'),'file')
            save_bor(fullfile(currentPath,'clean_tv'),8,currentYearTv);
        end
        % in case data needs to be initialized use this default trace
        allNaN = NaN(size(currentYearTv));
        % cycle through all files and either insert new data or create new files
        cntUpdates = 0;
        for cntAllFiles = 1:length(outputFilesAndData)
            fileName = fullfile(currentPath,outputFilesAndData{cntAllFiles}.fileName);
            newData  = outputFilesAndData{cntAllFiles}.data;
            if isnumeric(newData)
                % save only numeric types
                cntUpdates = cntUpdates + 1;
                if endsWith(fileName,{'TimeVector','clean_tv'},'IgnoreCase',true)
                    fileType = 8; %'float64';
                else
                    fileType = 1; %'float32';
                end
                % Do not write any fileType = 8 data
                if fileType == 1
                    % Check if the file exist
                    if ~exist(fileName,'file')
                        % initiate file with NaNs if it doesn't exist
                        oldData = allNaN;
                    else
                        % load the old data 
                        oldData = read_bor(fileName,fileType);
                    end
                    % insert the new data into oldData
                    oldData(indCurrentYear) = newData(indNewData);
                    % save new file back
                    save_bor(fileName,fileType,oldData);
                end
            end
        end

        if flagVerbose
            fprintf('     %d database entries for %d generated in %4.1f seconds.\n',length(indCurrentYear),currentYear,seconds(datetime-startTime));
        end
    end % currentYear
end % flagSave    

% helper functions

function currentPath = confirmOrCreate(currentPath)
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
