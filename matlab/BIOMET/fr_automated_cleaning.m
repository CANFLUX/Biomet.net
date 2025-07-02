function fr_automated_cleaning(Years,Sites,stages,db_out,db_ini)

% Example call: run stages 1 & 2 for two sites (BB & BB2) for two years (2022 & 2023) 
% fr_automated_cleaning([2022 2023],{'BB', 'BB2'},[1 2])

% fr_automated_cleaning(Years,Sites,stages,db_out)
%
% Run first to third stage cleaning and FCRN data export
%
%    fr_automated_cleaning with no arguments runs all stages for all sites 
%    for the current year and exits
% 
%    fr_automated_cleaning(Years,Sites,stages) allows to select Years (vector 
%    of years), Sites (cellstring array) and stages (vector of [1 2 3]). 
%    Defaults are the current year, all sites and all stages.
%    
%    If stages contains a 4 all cleaning stages are run and the data is
%    then exported in FCRN format to \\paoa003\BERMS
%
%    If stages contains a 5 all cleaning stages are run and the data is
%    then exported in FCRN format to \\paoa003\FCRN_local...added June 28,
%    2007 (Nick)
%
%   If stages contains a 6 all cleaning stages are run and web graphs are
%     exported...added July 10, 2007 (Nick--thanks Praveena!)
%
%    fr_automated_cleaning(Years,Sites,stages,db_out) writes the cleaned data 
%    into a different database with base path db_out. 
%    This option can be used to copy the cleaned database
%    using the standard biomet ini-files
%
%    fr_automated_cleaning(Years,Sites,stages,db_out,db_ini) uses db_ini as
%    a dabase base path to find the inifiles. This allows to update
%    a user specific database in db_out using the inifiles in db_ini and
%    data from the biomet database. 
% 
%    The default input and output database is y:\database on PAOA001 and
%    the biomet_path database on all other PCs. Use biomet_database_default
%    to use a local copy of the database.


% kai* Feb 12, 2003                     Last modified: Jul  2, 2025
%
% Revisions:
% 
% Jul 2, 2025 (Zoran)
%   - edited some comments and corrected the log file fprintf for stage 8 
%     (it used to print "9" instead of "8").
% May 20, 2024 (Zoran)
%   - Bug fix:
%     removed trailing filesep from derVarPth. Without this step the folder
%     "Derived_Variables" would not be removed from the path.
% May 17, 2024 (Zoran)
%   - adjusted the call to the 3rd stage cleaning (option #7) to match
%     the new runThirdStageCleaningREddyProc functions
%   - Added a test if Derived_Variables need to be removed from the path
%     before exiting the function.
% Mar 22, 2024 (Zoran)
%   - renamed SiteId to siteID
%   - removed Derived_Variables from the path when processing of a siteID is finished.
%     Leaving it to linger around could mess up running of some other programs/sites
%     during the current Matlab session (used to stay persistant until Matlab session is closed)
% Feb 12, 2024 (Zoran)
%   - Limitted running DerivedVariablesForGapFilling on Micromet sites
%     only.
%   - fixed nested counter loops "for i=" just before call to DerivedVariablesForGapFilling
%     code.
%   - added: && minute(datetime)< 30  to have DerivedVariablesForGapFilling
%     executed only once when hour(datetime)==0 instead of twice.
%   - added try-catch around that part of the code
%   - small syntax changes to get the "green checkmark" from Matlab editor. 
% Feb 12, 2023 (Zoran)
%   - changed output path for AmeriFlux data to Clean/Ameriflux in stage 8.
% Nov 7, 2022 (Zoran)
%   - Hard coded that the stage 7 now does 'fast' EP processing and uses only
%     (up to) 2 years of data for gap filling. Sara will decide later if those are
%     the optimal setting.
% Nov 4, 2022 (Zoran)
%   - confirmed that stages 7 and 8 work.
%   - minor edits of fprintf statements.
% Nov 3, 2022 (Zoran)
%   - added 7th and 8th stages. 
%     Stage 7  - cleans Micromet data using runThirdStageREddyProc.m
%     Stage 8  - exports Micromet data as AmeriFlux standard csv file
% Sep 21, 2022 (Zoran)
%   - change path creation to make it work compatible with MacOS:
%     Changed:
%       pth_out_second = fullfile(db_out,yy_str,siteID,'clean\SecondStage','');
%     to
%       pth_out_second = fullfile(db_out,yy_str,siteID,'clean','SecondStage','');
% Aug 10, 2022 (Zoran)
%   - Had to change my mind about preventing (error-ing)on the use of
%     db_out option. Some of our backup programs might be using this
%     feature. Until I fix those, this function will just print a warning.
% Jul 29, 2022 (Zoran)
%   - prevented user from using db_out option because it lead to unexpected
%     and wrong results. See below for more.
% Apr 6, 2022 (Zoran)
%   - added testing for diarylog (hTimer~=empty) to avoid issues when
%   running the program on the computers that don't use diarylog (vinimet)
% Mar 3, 2022 (Zoran)
%   - fixed a bug where the program would error when the diarylog timer
%     needed to be restarted at the end of this function. I added
%     try-catch-end around it.
% Jan 5, 2022 (Zoran)
%   - changed handling of diary file to make it compatible with the new
%     version of diarylog.m.
%   - fixed some of the syntax warnings
%   - commented out some unused variables.
% May 12, 2020 (Zoran)
%   - renamed function export.m to ta_export to avoid mixup with Matlab's
%     function
% Jul 14, 2018 (Zoran)
%   - Added LGR2 site to the list of All_Sites and All_site_name
% Jan 15, 2018 (Pat/Zoran)
%   - Added LGR1 site to the list of All_Sites and All_site_name
% Dec 19, 2011
%   - Fixed a bug that crashed the program when trying to write a diary file into a write-protected folder.
% July 10, 2007
%   -If stages contains a 6 all cleaning stages are run and web graphs are
%     exported...added July 10, 2007 to allow graphs to be created explicitly
%     by site and not just in dailymode (Nick)
% June 28, 2007
%       -If stages contains a 5 all cleaning stages are run and the data is
%    then exported in FCRN format to \\paoa003\FCRN_local...added June 28,
%    2007 (Nick)
% March 1, 2007
%       -put the diary writing into automated_cleaning.log inside a try
%       statement so function can be used on computers without write access
%       to Annex001 (e.g. to create local copies of cleaned traces)... Nick
% Nov 18, 2004
% Added FCRN export
% Oct 21, 2004
% Added HJP75 & FEN
% Sep 09, 2004
% Implemented db_out and db_ini option and use of db_dir_ini

% Prevent users from running into trouble when
% by using db_out (Zoran 20220729)
% 
% I left some notes at the end of this function in case I want to try to fix 
% it. Until then:
if exist('db_out') & ~isempty(db_out)
    %uiwait(msgbox('Do not use db_out path option!','Error in fr_automated_cleaning','error'))
    %error(sprintf('Using parameter "db_out" is not allowed!\n') )
    fprintf('---------------------------------------------------\n');
    fprintf(' do NOT use the input parameter db_out! \n');
    fprintf(' It does not do what it says. For more info \n');
    fprintf(' check notes in fr_automated_cleaning.m\n');
    fprintf('---------------------------------------------------\n');
    
end

if ~exist('Years') & ~exist('Sites') %#ok<*AND2,*EXIST>
    dailymode = 1;
else
    dailymode = 0;
end

Year_cur = datevec(datetime);
arg_default('Years',Year_cur(1));

All_Sites     = {'BS'   'CR' 'FEN' 'HJP02' 'HJP75' 'JP'   'OY' 'PA'   'YF' 'LGR1' 'LGR2'};
% All_Site_name = {'PAOB' 'CR' 'FEN' 'HJP02' 'HJP75' 'PAOJ' 'OY' 'PAOA' 'YF' 'LGR1' 'LGR2'};

arg_default('Sites',All_Sites)

if ~iscellstr(Sites) %#ok<ISCLSTR>
    % Assume it is a string with a single siteID
    Sites = cellstr(Sites);
end

arg_default('stages',[1 2 3]);
% When FCRN export is requested make sure all cleaning is done
if ~isempty(find(stages == 4))
    stages = [1 2 3 4];
end

% June 28, 2007: Nick added for the case that we want to update a local copy of the
% FCRN export database for internal use only
if ~isempty(find(stages == 5)) 
    stages = [1 2 3 5];
end

% July 10, 2007: Nick added for the case that we want to produce
% web graphs for export
if ~isempty(find(stages == 6))
    stages = [1 2 3 6];
end


% [~,ind_all] = intersect(All_Sites,upper(Sites));
% if isempty(ind_all)
%     Site_name = Sites;
% else
%     Site_name = All_Site_name(ind_all);
% end

% disable diarylog timer during the run
hTimer = timerfind('name','diarylog');
if ~isempty(hTimer)
    hTimer.stop
end

    
% ------------Nick's fix for using a local copy of the database---------------
if exist('biomet_database_default','file') == 2
    db_pth = biomet_database_default;
else
    db_pth = db_pth_root;
end
%--------------------------------------------------------------------------
arg_default('db_out',db_pth);
arg_default('db_ini',db_pth);

numOfYears = length(Years);
numOfSites = length(Sites);

for cntSites = 1:numOfSites
    siteID = upper(char(Sites(cntSites)));
    
    for cntYears = 1:numOfYears
        yy = Years(cntYears);
        yy_str = num2str(yy(1));
        try
            fid = fopen(fullfile(db_pth,yy_str,siteID,'automated_cleaning.log'),'a');
            if fid > -1
                fclose(fid);
                diary(fullfile(db_pth,yy_str,siteID,'automated_cleaning.log'));
            else
                disp(['Write protected file: ' fullfile(db_pth,yy_str,siteID,'automated_cleaning.log')]);
            end
        catch ME
            disp(ME.message);
        end
        fprintf('==============  Start =========================================\n');
        fprintf('Date: %s\n',datetime);
        fprintf('siteID = %s\n',siteID);
        
        %------------------------------------------------------------------
        % Get output paths
        %------------------------------------------------------------------
        pth_out_first  = fullfile(db_out,yy_str,siteID,'');
        pth_out_second = fullfile(db_out,yy_str,siteID,'Clean','SecondStage','');
        pth_out_third  = fullfile(db_out,yy_str,siteID,'Clean','ThirdStage', '');
        
        %------------------------------------------------------------------
        % Do first stage cleaning and exporting
        %------------------------------------------------------------------
        if ~isempty(find(stages == 1)) %#ok<*EFIND>
            stage_str = 'First ';
            disp(['============== ' stage_str ' stage cleaning ' siteID ' ' yy_str ' ==============']);
            db_dir_ini(yy(1),siteID,db_out,1);
            data_first = fr_cleaning_siteyear(yy(1),siteID,1,db_ini);
            ta_export(data_first,pth_out_first);
            fprintf('============== End of cleaning stage 1 =============\n');
        end
        
        %------------------------------------------------------------------
        % Do second stage cleaning and exporting
        %------------------------------------------------------------------
        if ~isempty(find(stages == 2))
            stage_str = 'Second';
            disp(['============== ' stage_str ' stage cleaning ' siteID ' ' yy_str ' ==============']);
            
            db_dir_ini(yy(1),siteID,db_out,2);
            data_second = fr_cleaning_siteyear(yy(1),siteID,2,db_ini);
            ta_export(data_second,pth_out_second);
            fprintf('============== End of cleaning stage 2 =============\n');
        end
        
        %------------------------------------------------------------------
        % Do third stage automated cleaning and exporting
        %------------------------------------------------------------------
        if ~isempty(find(stages == 3))
            stage_str = 'Third ';
            disp(['============== ' stage_str ' stage cleaning ' siteID ' ' yy_str ' ==============']);
            db_dir_ini(yy(1),siteID,db_out,3);
            data_third = fr_cleaning_siteyear(yy(1),siteID,3,db_ini);
            ta_export(data_third,pth_out_third);
            fprintf('============== End of cleaning stage 3 =============\n');
        end
        
        %------------------------------------------------------------------
        % Do FCRN exporting
        %------------------------------------------------------------------
        if ~isempty(find(stages == 4))
            disp(['============== ' siteID ' - FCRN Export =================================']);
            data_fcrn = fcrn_trace_str(data_first,data_second,data_third);
            fcrnexport(siteID,data_fcrn);
            fprintf('============== End of cleaning stage 4 =============\n');
        end
        
        % added June 28, 2007: Nick
        %------------------------------------------------------------------
        % Do a local FCRN export right up to current day
        %------------------------------------------------------------------
        if ~isempty(find(stages == 5))
            disp(['============== ' siteID ' - Local FCRN Export =================================']);
            data_fcrn_local = fcrn_trace_str(data_first,data_second,data_third);
            flag_local = 1;
            fcrnexport(siteID,data_fcrn_local,flag_local);
            fprintf('============== End of cleaning stage 5 =============\n');
        end
        
        %------------------------------------------------------------------
        % When in daily mode also produce automatic graphs
        %------------------------------------------------------------------
        if dailymode | ~isempty(find(stages==6)) %#ok<*OR2> % July 10, 2007: added a stage 6 so we can produce web graphs explicitly by site
            try
                if ismember(siteID,{'HP09' 'HP11' 'MPB1' 'MPB2' 'MPB3'})
                    opsite_web_analysis(yy(1),siteID);
                    autoGraph(data_first)
                else
                    autoGraph(data_third)
                end
            catch
                disp(['Could not generate graphs for ' siteID ' ' yy_str]);
            end
        end
        
        %------------------------------------------------------------------
        % Do 7th stage automated cleaning and exporting
        % This one is done using REddyProc and Rscript.
        % Currently in use with Sara Knox's sites only
        % The cleaning is done using the default parameters given in
        % runThirdStageCleaningREddyProc.
        %------------------------------------------------------------------
        if ~isempty(find(stages == 7))
            stage_str = '7-th';
            disp(['============== ' stage_str ' stage cleaning ' siteID ' ' yy_str ' ==============']);
            db_dir_ini(yy(1),siteID,db_out,3);
            Rstatus = runThirdStageCleaningREddyProc(yy(1),siteID,1);  % use only 1 year for gap filling

            if Rstatus~=0
                fprintf('Failed running Third Stage Rscript\n');
            end

            % Retrieve R log file and print "P2M" messages
            % folder = 'F:\EcoFlux lab\Database\Calculation_Procedures\TraceAnalysis_ini\TPAG\log\';
            folder = fullfile(db_pth,'Calculation_Procedures','TraceAnalysis_ini',siteID,'log');
            filename = char([siteID '_ThirdStageCleaning.log']);
            fid = fopen(fullfile(folder,filename));
            if fid~=-1
                fprintf('Retrieving critical messages from Third Stage R log:\n');
                read_R_log(fid)
                fclose(fid);
            end
            
            fprintf('============== End of cleaning stage 7 =============\n');
        end
        
        %------------------------------------------------------------------
        % 8th stage is the methane-gapfill-ml python pipeline
        %------------------------------------------------------------------
        if ~isempty(find(stages == 9))
            stage_str = '9-th';
            disp(['============== ' stage_str ' stage. Running CH4 gapfilling pipeline: ' siteID ' ' yy_str ' ==============']);
            runThirdStageCleaningMethaneGapfillML(yy,siteID);
            fprintf('============== End of cleaning stage 9 =============\n'); 
        end
        
        %------------------------------------------------------------------
        % 9th stage is export of clean data into AmeriFlux
        % format. The output data is stored to .../siteID/Clean/Ameriflux folder
        %------------------------------------------------------------------
        if ~isempty(find(stages == 8))
            stage_str = '8-th';
            disp(['============== ' stage_str ' stage. Exporting AmeriFlux csv file for: ' siteID ' ' yy_str ' ==============']);
            pathAF = fullfile(db_pth,num2str(yy(1)),siteID,'Clean','Ameriflux');
            saveDatabaseToAmeriFluxCSV(siteID,yy(1),pathAF);
            fprintf('============== End of cleaning stage 8 =============\n'); 
        end
        clear data_* ini_* pth_* mat_*
        

    end

    % Remove Derived_Variables path from the path
    derVarPth = fullfile(db_pth,'Calculation_Procedures','TraceAnalysis_ini',siteID,'Derived_Variables');
    if strcmp(derVarPth(end),filesep)
        % remove trailing filesep. "path" does not contain those
        derVarPth = derVarPth(1:end-1);
    end
    if contains(path,derVarPth,'IgnoreCase',true)
        rmpath( derVarPth)
    end

    fprintf('============== End of cleaning Site: %s, year: %d ===========\n',siteID,yy(1));
    
    if ~isempty(hTimer)
        % restart the original diary file name
        currentDiaryFileName = get(0,'DiaryFile');
        diary(currentDiaryFileName);
        try
            hTimer.start;
        catch
            % sometimes the timer is already running and we get an error
        end
    end
    
end


% Notes for a curious reader.

%============================================================
% THE FOLLOWING BUG has yet to be fixed!!!!
% Until it's fixed, always test the cleaning only on PAOA001 or ENG06 
% and do NOT use db_out option.
% If local version of database is needed, then make a copy of the entire site
% database for all years of interest, and change biomet_database_default so 
% it points to the local copy of the data base
%   - The data cleaning *always* reads
%     the source files (raw for stageOne cleaning, stageOne for stageTwo cleaning, 
%     stageTwo for stageThree cleaning) from the biomet_database_default or if that one was absent,
%     from \\annex001\database!!!
%     This bug was deadly in a stealhy way. It happens when one wants to use 
%     user-path as the output (optional input argument "db_out" in fr_automated_cleaning).
%     Program only OUTPUTS the clean data to user-path, does NEVER read it from it.
%     That means that the stage one cleaned raw data from ANNEX001. 
%    The parent function (fr_automated_cleaning)
%     would then store the outputs to either default path (again, usually ANNEX001) or
%     optionally to user-path. 
%     In the latter case, one would expect that the
%     the next stage cleaning would have used the newly cleaned files from the
%     previous stage (in the user-path) for the next stage 
%     cleaning. 
%     This was NOT the case. If the user-path was used then the 
%     cleaning worked like this:
%       - Raw data (ANNEX)                  -> FirstStage  Clean data (user-path)
%       - FirstStage Clean data (ANNEX!!!)  -> SecondStage Clean data (user-path)
%       - SecondStage Clean data (ANNEX!!!)  -> ThirdStage Clean data (user-path)
%     This was wrong! The correct procedure should be:
%       - Raw data (ANNEX)                    -> FirstStage  Clean data (user-path)
%       - FirstStage Clean data  (user-path)  -> SecondStage Clean data (user-path)
%       - SecondStage Clean data (user-path)  -> ThirdStage  Clean data (user-path)
%     The user would still be able to modify the Raw data location by editing
%     biomet_database_default.
%     This bug would not affect the cleaning that was done on the PAOA001. 
%     On the other hand, it must have caused a few issues over years for the students
%     doing intial cleaning on their own computers.
%
% This bug is not yet fixed because it's burried quite deep. 
% Read_data.m calls a few functions that 
% keep going back to the biomet_path to get the source path instead of using
% the new root (user-path)
% For a proper fix a lot of editing will be needed and legacy software may suffer.
% A hack might be needed (something along the lines of inserting info into set(0,'UserData')
% and checking that inside biomet_path. But biomet_path would need to make sure that 
% it uses this info *only* if called by a few TA functions 
% (read_data,read_single_trace and their children). The main program(s) 
% (like fr_automated_cleaning should always start by deleting this field from UserData before 
%  setting or not setting user-path). Think about it.

