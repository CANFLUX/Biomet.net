function Biomet_Main_Scheduler
% Biomet_Main_Scheduler - it runs all Matlab processing for Biomet sites
%
% It runs every 10 minutes (at 2,12,22,32,42,52 min)from the Windows scheduler and
% parses the tasks that need to be done.
%
% Each individual task is inside of a try-catch-end structure. Each task
% adds to the report file.
%
%
% Zoran Nesic           File created:       Feb 12, 2024
%                       Last modification:  Nov 27, 2025

% Revisions:
%
% Nov 27, 2025 (Zoran)
%   - added keeping 10 newest AB1 summary files on Biomet webpage for Pat
% Nov 7, 2025 (Zoran)
%   - Bug fix: added checking if any Picarro zip files exist before trying to move them.
%     This used to case an error. Also added try/catch/end just in case.
% Sep 11, 2025 (Zoran)
%   - Switch from using sync.com to using \\annex001 for data transfers
%     from Picarro 
% May 9, 2025 (Zoran)
%   - Added processing of AB1 site
% Jan 15, 2025 (Zoran)
%   - Commented out YF data processing. Site has been shut down Jan 11,
%     2025.
% Oct 20, 2024 (Zoran)
%   - Added more comments to remind me to change the filePath for Totem
%   data. See: Process_Climate_Station
% Sep 22, 2024 (Zoran)
%   - changed source folder for Totem Field station from files.ubc.ca to
%     \\annex001\climate-UBC
% May 12, 2024 (Zoran)
%   - changed source folder for Totem Field station from sync.com to
%   files.ubc.ca
% Feb 21, 2024 (Zoran)
%   - added changing folder to d:\ at the beginning and after running
%     Picarro data processing to avoid database path issues if testing the
%     program from SAL setup. 
%   - Fixed program output by removing "\" from Sites\TEMP fprint
%     statements.
%   - added logging of all "result" from running "system" commands in cases
%     when ~isempty(result)
% Feb 20, 2024 (Zoran)
%   - Still refusing to work when started by Task Scheduler. 
%     It doesn't want to see the files on drive T:
%     Replace T: with \files.ubc.ca\Team based on my notes in OneNote.
% Feb 19, 2024 (Zoran)
%   - Reprogrammed robocopy and move options to work from Matlab directly
%       not through the C:\Ubc_flux\PicarroMove.bat file. For some reason the robocopy could not see
%       the target folder when used from the bat file. This is an attempt to
%       fix it. Will see how it goes.
% Feb 13, 2024
%   - Added:
%       cd('\\files.ubc.ca\team\LFS\Research_Groups\Sean_Smukler\SALdata\matlab\Zoran_Picarro');
%     to make sure that Picarro processing can run properly.
%

% Make sure that the default folder is d:\
cd('d:\')
    [yearX,monthX,dayX,hourX,minuteX,secondX] = datevec(datetime); %#ok<*ASGLU>

    % Start with the tasks that run most often

    %fid = 1;  % for testing print logs on screen only
    strDT = char(datetime,'yyyyMMdd');
    fid = fopen(['d:\Sites\Log\Biomet_Main_Scheduler_' strDT '.log'],'a');
  
    fprintf(fid,'============== Biomet_Main_Scheduler.m ==================\n');
    fprintf(fid,' %s\n',datetime);
  
    %----------------------------------
    % Climate station data processing
    if minuteX == 2 || minuteX == 32
        fprintf(fid,'======= Climate station data processing ========\n');
        fprintf(fid, ' %s\n',datetime);
        % at 2 minutes and 32 minutes every hour
        % Process CR21x files
        fprintf(fid,' Processing old CR21x/10x files.\n');
        Process_Climate_Station(fid);
        % Proces CR1000 files
        fprintf(fid,' Processing Totem Field CR1000 files.\n');
        db_update_Totem(yearX)
        % Do only if the first run in that hour
        if minuteX==2 
            try
                % Clean Totem data once per hourdb_
                % clean last and the current year
                fprintf(fid,' Cleaning Totem Field data.\n');
                fr_automated_cleaning(yearX-1:yearX,'UBC_Totem',[1 2 3 ]);
                fprintf(fid,' Exporting Totem Field data.\n');
                Export_Totem_One_Year;
                Export_for_Tin;
                % If this is the first run in a new day then date-stamp the raw
                % file from the previous day
                if hourX == 0
                    % Replaces a Task Scheduler task:
                    % ClimateStation_daily_file_rename
                    fprintf(fid,'Renaming Totem Field daily CSI files.\n');
                    ClimateStation_movefile;
                end
            catch myError
                fprintf(fid,' Error while working on Totem Field data processing.\n');
                fprintf(fid,'%s\n',myError.message);
            end
        end
        fprintf(fid,' %s\n',datetime);
        fprintf(fid,'======= End of Climate station data processing ========\n');
    elseif minuteX == 12 || minuteX == 42
        % move files from d:\Sites\TEMP folder to database Raw folders
        fprintf(fid,'======= Moving Sites-TEMP data to RAW (%s)========\n',string(datetime));
        fprintf(fid,' %s\n',datetime);
        [status,result] = system('c:\ubc_flux\Move_CSI_net_files.exe c:\ubc_flux\Move_CSI_net_files.ini');
        if ~isempty(result)
            fprintf(fid,'   Error while moving files:\n%s\n',result);        
        end
        fprintf(fid,' %s\n',datetime);
        fprintf(fid,'======= End of Moving Sites-TEMP data (%s)========\n',datetime);
    end
    
    % %------------------------
    % % YF site: File unzipping
    % if ismember(hourX,14:17) && minuteX == 2
    %     fprintf(fid,'======= Moving and Unzipping YF DailyZip files (%s) ========\n',datetime);
    %     fprintf(fid,'%s\n',datetime);
    %     fprintf(fid,'Moving ZIP files from Sync.com to Sites.\n');
    %     [status,result] = system('"C:\Ubc_flux\Move_DailyZipFiles_from_Public_to_Sites.bat"');
    %     if ~isempty(result)
    %         fprintf(fid,'   Error while moving ZIP files:\n%s\n',result);        
    %     end        
    %     fprintf(fid,'------- Unzipping ... (%s) -------\n',datetime);
    %     % *** Note: UBC_ZIP.exe has a one minute wait period before it returns control to 
    %     %           Matlab. Use "&" to avoid waiting for it to return
    %     %           control to Matlab but be aware that the unzipping may
    %     %           not be finshed yet. Alternatively, bypass this program
    %     %           by writing a Matlab native version of UBC_ZIP.
    %     % ***           
    %     [status,result] = system('C:\Ubc_flux\UBC_ZIP.exe C:\Ubc_flux\ubc_unzip.ini &');
    %     if ~isempty(result)
    %         fprintf(fid,'   Error while unzipping files:\n%s\n',result);        
    %     end        
    %     fprintf(fid,'%s\n',datetime);
    %     fprintf(fid,'======= End of Moving and Unzipping (%s)    ========\n',datetime);
    % end
    % 
    % %------------------------
    % % YF site: MET data processing
    % if ismember(hourX,14:17) && minuteX == 12
    %     fprintf(fid,'======= YF MET data processing (%s) ========\n',datetime);
    %     fprintf(fid,'%s\n',datetime);
    %     run_YF_met_db_update;
    %     fprintf(fid,'%s\n',datetime);
    %     fprintf(fid,'======= End of YF MET data processing (%s)    ========\n',datetime);
    % end

    %------------------------
    %  MBP1 site: data processing
    if ismember(hourX,[15 19]) && minuteX == 22
        fprintf(fid,'======= MPB1 data processing (%s) ========\n',datetime);
        fprintf(fid,'%s\n',datetime);
        run_MPB_db_update;
        fprintf(fid,'%s\n',datetime);
        fprintf(fid,'======= End of MPB1 data processing (%s)    ========\n',datetime);
    end

    %------------------------
    %  AB1 site: data processing
    if ismember(minuteX,[12 52])
        fprintf(fid,'======= AB1 data processing (%s) ========\n',datetime);
        fprintf(fid,'%s\n',datetime);
        % code to keep the last nFilesToCopy days of AB EC summaries on the web site
        webPath = 'D:\Sites\web_page_weather\AB1';
        ecSummariesPath = 'D:\Sites\AB1\Flux';
        allSummaries = dir(fullfile(ecSummariesPath,'*_EP-Summary.txt'));
        
        % From the target folder delete all *_EP-Summary.txt files
        delete(fullfile(webPath,'*_EP-Summary.txt'));
                
        % Copy the newest files from EC folder to web folder
        nFilesToCopy = 10;
        dateStart = dateshift(datetime('now') - days(nFilesToCopy-1),'start','day');
        for cntFiles = 1:length(allSummaries)
            fileDate = allSummaries(cntFiles).name;
            fileDate = fileDate(1:10);
            if dateStart <= fileDate           
                srcFile = fullfile(allSummaries(cntFiles).folder,allSummaries(cntFiles).name);
                dstFile = fullfile(webPath,allSummaries(cntFiles).name);
                copyfile(srcFile,dstFile);
            end
        end
        % now run automatic processing for AB1 
        [status,result] = system('d:\Scripts\AB1_AutomaticProcessing.bat');
        fprintf(fid,'%s\n',datetime);
        fprintf(fid,'======= End of AB1 data processing (%s)    ========\n',datetime);
    end

    %--------------------------
    % Picarro data processing
    % 
    % I could also use:
    %  [status,result] = system('"C:\Ubc_flux\dbase_update\Run_Picarro_from_Matlab_via_TaskManager.lnk"')
    % (I tested it and it works. Don't like using tasks for this
    % so I'll try converting C:\Ubc_flux\PicarroMove.bat to Matlab code)
    %
    if (hourX == 1 && ismember(minuteX,[52]) ) || (hourX == 2 && ismember(minuteX,[22 52]))  %#ok<*NBRAK>
        fprintf(fid,'======= Picarro processing ========\n');
        fprintf(fid,'Moving ZIP files from Sync.com to Sites.\n');
        fprintf(fid,'%s\n',datetime);
        % [status,result] = system('"C:\Ubc_flux\Move_DailyZipFiles_from_Public_to_Sites.bat"');
        % if ~isempty(result)
        %     fprintf(fid,'   Error while moving DailyZip files:\n%s\n',result);        
        % end
        if ~isempty(dir('\\annex001\Picarro\*.zip'))
            try
                movefile('\\annex001\Picarro\*.zip','D:\Sites\Picarro_AGGP\dailyZip');
            catch
            end
        end
        % *** Note: UBC_ZIP.exe has a one minute wait period before it returns control to 
        %           Matlab. Use "&" to avoid waiting for it to return
        %           control to Matlab but be aware that the unzipping may
        %           not be finshed yet. 
        %           In this case the proper thing to do is to wait for
        %           UBC_ZIP to finish 60s wait.
        % ***          
        fprintf(fid,'Unzipping files.\n');
        [status,result] = system('C:\Ubc_flux\UBC_ZIP.exe C:\Ubc_flux\ubc_unzip.ini'); 
        if ~isempty(result)
            fprintf(fid,'   Error while unzipping files:\n%s\n',result);        
        end
        fprintf(fid,'Moving Picarro files to files.ubc.ca\\team.\n');
[status,result] = system('robocopy D:\Sites\Picarro_AGGP\DataLog_User        "\\files.ubc.ca\Team\LFS\Research_Groups\Sean_Smukler\SALdata\GHGdata\SAL Picarro All Data\UBC Farm Continous Data" /MOVE /E /NDL /NFL "');
        if ~isempty(result)
            fprintf(fid,'   Error while robocopying DataLog_User files:\n%s\n',result);        
        end
% [status,result] = system('"rmdir D:\Sites\Picarro_AGGP\DataLog_User /S/Q "');
[success,result] = rmdir('D:\Sites\Picarro_AGGP\DataLog_User','s');
        if ~isempty(result)
            fprintf(fid,'   Error while removing DataLog_User folder:\n%s\n',result);        
        end
[status,result] = system('robocopy D:\Sites\Picarro_AGGP\UBC_folder\csi_net  "\\files.ubc.ca\Team\LFS\Research_Groups\Sean_Smukler\SALdata\GHGdata\SAL Picarro All Data\met-data\csi_net"                  /E /NDL /NFL         "');
        if ~isempty(result)
            fprintf(fid,'   Error while robocopying UBC_folder:CSI_NET :\n%s\n',result);        
        end
[status,result] = system('robocopy D:\Sites\Picarro_AGGP\UBC_folder          "\\files.ubc.ca\Team\LFS\Research_Groups\Sean_Smukler\SALdata\GHGdata\SAL Picarro All Data\UBC Farm Continous Data\UBC_folder"  /MOVE /E /NDL /NFL "');
        if ~isempty(result)
            fprintf(fid,'   Error while robocopying UBC_folder:\n%s\n',result);        
        end
[status,result] = system('rmdir D:\Sites\Picarro_AGGP\UBC_folder /S/Q ');
        if ~isempty(result)
            fprintf(fid,'   Error while removing UBC_folder:\n%s\n',result);        
        end

        %[status,result] = system('"C:\Ubc_flux\PicarroMove.bat"');
        % fprintf(fid,'%s\n',result);
    [status,result] = system('dir \\files.ubc.ca\team\LFS\Research_Groups\');
    fprintf(fid,'%s\n',result);
        fprintf(fid,'Processing Picarro data.\n');
        cd('\\files.ubc.ca\team\LFS\Research_Groups\Sean_Smukler\SALdata\matlab\Zoran_Picarro');
    fprintf(fid,'%s\n',pwd);
        process_Picarro_AGGP_data;
        fprintf(fid,'%s\n',datetime);
        fprintf(fid,'======= End of Picarro processing (%s) ========\n',datetime);
        % Make sure that the default folder is back to d:\
        cd('d:\')        
    end
    
    % ---------------------------
    % Morning db_update_all
    % 4:02pm GMT
    % Replaces Task Scheduler task: update_annex001_db_and_clean
    if hourX == 16 && ismember(minuteX,[2])
        fprintf(fid,'======= Morning db_update_all ========\n');
        fprintf(fid,'%s\n',datetime);
        db_update_all(1,0);
        fprintf(fid,'%s\n',datetime);
        fprintf(fid,'======= End of db_update_all processing (%s) ========\n',datetime);
    end
    fprintf(fid,' %s\n',datetime);    
    fprintf(fid,'============== All done! ==================\n\n\n');    
   fclose(fid); 
end

%%
function Process_Climate_Station(fid)
    try        
        % Copy files from Sync.com folder. Force overwriting.
        % Replaces a Task Scheduler task: ClimateStation_Data_Copy
        %filePath = 'd:\Sites\Sync\Sync\ClimateStation_to_UBC';
        %filePath = 'T:\Research_Groups\BioMet\ClimateStation';        
        %  ********
        %  !!!!! DON'T FORGET to change the filePath also in ClimateStation_movefile !!!! 
        %  *******
        filePath = '\\annex001\Climate-UBC'; 
        % !!!! See the note above

        destinationPath = 'D:\SITES\ubc\CSI_NET';
        fprintf(fid,'  Copying ubraw.dat from Sync to CSI_NET... %s  \n',datetime);
        [Success,Msg,MsgID] = copyfile(fullfile(filePath,'ubraw.dat'),...
                                       fullfile(destinationPath,'ubraw.dat'),...
                                       'f');
        if ~Success
            fprintf(fid,'%s\n',Msg);
        end
        % Move CONFLICT files from csi_net to csi_net\old folder. Give them unique names
        % using the file time stamp     
        fprintf(fid,'  Moving ubraw-CONFLICT files... %s \n',datetime);
        sConflictFiles = dir(fullfile(filePath,'ubraw-CONFLICT*.dat'));
        if ~isempty(sConflictFiles)
            for cntFiles = 1:length(sConflictFiles)
                fileName         = sConflictFiles(cntFiles).name;
                sourceFile       = fullfile(filePath,fileName);
                dt               = datetime(sConflictFiles(cntFiles).datenum,'convertfrom','datenum');
                fileExt          = char(dt,'yyyyMMdd''T''HHmmSS');
                %fileExt          = datestr(sConflictFiles(cntFiles).datenum,30);
                destinationFile1 = fullfile(destinationPath,[fileName(1:end-3) fileExt]);
                [Status1,Message1,MessageID1] = fr_movefile(sourceFile,destinationFile1);
            end
            if ~Status1
                fprintf(fid,'%s\n',Msg);
            end        
        end
    catch
        fprintf(fid,'  Error while processing climate station data\n');
    end    
    % Process climate station data. 
    % Replaces Task Scheduler event: dbase_update
    % Use a dummy Task Scheduler event called by a batch link below
    % C:\Windows\System32\schtasks.exe /RUN /TN "Biomet\Database_updates\Run dbase_update from Matlab"
    % This task looks like this: C:\Ubc_flux\dbase_update\dbase_update.exe c:\ubc_flux\dbase_update.ini
    % Running a Task Scheduler even is a workaround for Windows asking
    % about admin permissions to run this program
    fprintf(fid,'  Climate station: converting csv to database... %s \n',datetime);
    [status,result] = system('"C:\Ubc_flux\dbase_update\UseMatlabToRunDbase_update-bat.lnk"');
    if ~isempty(result)
        fprintf(fid,'   Error while running UseMatlabToRunDbase_update-bat.lnk:\n%s\n',result);        
    end    
end
%%


% Testing if dbase_update.exe is running:
%     status1,result1] = system('tasklist /FI "imagename eq dbase_update.exe" /fo table /nh')
% Return PID for the current Matlab session:
%     feature('getpid')
%     
%     try
% each system() run should call a batch file that"
%   - deletes semaphor file
%   - runs a program
%   - creates semaphor file
% Matlab runs the batch file and then waits until it either time outs or it sees 
% the semaphor file appear. If the timeout happens first - that's an error. If
% the semaphor file appers first, than the processing was OK.
%   
%         fprintf('%s Climate station: converting csv to database... ',datetime);
%         [status,result] = system('"C:\Ubc_flux\dbase_update\UseMatlabToRunDbase_update-bat.lnk"');
%         if status == 0
%             fprintf(' Done (%s)\n',datetime);
%         else
%             fprintf(' Failed (%s)\n',datetime);
%         end
%     catch
%         fprinf('Error:%s (%s)\n',result,datetime);
%     end
%     % Clean and export climate data
%     try
%         fprintf('%s Climate station: Cleaning and Exporting... ',datetime);
%         db_clean_Totem;
%         Export_Totem_One_Year;
%         Export_for_Tin;
%         fprintf(' Done (%s)\n',datetime);
%     catch
%         fprinf('Error:%s (%s)\n',result,datetime);
%     end        
% end
% 
%             
%     