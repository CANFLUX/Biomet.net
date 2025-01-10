function fidLog = runThirdStageCleaningREddyProc(yearIn,siteID,yearsToProcess);
% runThirdStageCleaningREddyProc(yearIn,siteID)
%
% This function invokes Micromet third-stage cleaning R-script.
% Usually, it's called by fr_automated_cleaning()
%
% Arguments
%   yearIn          - year to clean
%   siteID          - site ID as a char
%   yearsToProcess  - 1 (default) or more. REddyProc can use more years 
%                     for gap-filling even when outputing one year only
%
% Zoran Nesic               File created:       Oct 25, 2022
%                           Last modification:  Oct 24, 2024
%

% Revisions
%
% Dec, 2024 (Paul)
%   - fidLog added as function output
% Oct 24, 2024 (Zoran)
%   - Bug fix: enclosed all the paths into "" when calling R script. That removes the bug 
%     where the calls to R would not work if the file path included spaces.
% Jun 13, 2024 (Zoran)
%   - The function now passes the path to the database to the ThirdStage.R script
%     as the first argument. 
%   - Replaced all "\" with "/" when calling R script.
% May 17, 2024 (Zoran)
%   - Major change to match the new R function ThirdStage.R. 
%   - Different input parameters.
%   - Moved the old revision notes to the bottom of the file because
%     they are less relevant now after this update

    % Prepare input parameters, create defaults if needed
    arg_default('yearsToProcess',1);     % Use only the current year for gap filling
    
    startYear = yearIn - yearsToProcess + 1;
    endYear   = yearIn;

    % find path to R database_functions folder
    pthBiometR = findBiometRpath;
    pthThirdStageR = fullfile(pthBiometR,"ThirdStage.R");
    
    % find path to database
    pthDatabase = findDatabasePath;
    
    % This one should be under ../Database/Calculation_procedures\TraceAnalysis_ini\siteID:
    pthIni = fullfile(pthDatabase,'Calculation_Procedures','TraceAnalysis_ini',siteID);
    
    % Find path to the newest version of Rscript
    pthRbin = findRPath;    

    % create all file paths
    % log files go under ../database/Calculation_Procedures\TraceAnalysis_ini\siteID\log
    if ~exist(fullfile(pthIni,'log'),'dir')
        mkdir(fullfile(pthIni,'log'))
    end    
    pthLogFile = fullfile(pthIni,'log',[siteID '_ThirdStageCleaning.log']);
    
    tic;
    tv_start = now; %#ok<TNOW1>

    % Run RScript
    % concatenate the command line argument
    CLI_args = sprintf('"%s" --vanilla "%s" "%s" %s %i %i',pthRbin,pthThirdStageR ,strrep(pthDatabase,'\','/'),siteID,startYear,endYear);
    CLI_args = [CLI_args ' 2> "' pthLogFile '" 1>&2'];
    % run the command line argument
    fprintf('Running the following command: %s\n', CLI_args);
    fprintf('Start time: %s\n\n',datetime)
    [statusR,cmdOutput] = system(CLI_args);
    fprintf('End time: %s\n\n',datetime)
    % When R is finished, print cmdOutput and the footer in the log file
    fidLog = fopen(pthLogFile,'a');      
    if fidLog > 0    
        fprintf(fidLog,'=============================================================\n');
        if statusR == 0
            fprintf(fidLog,'Completed running Third Stage Rscript: %s\n',pthRbin);
        else
            fprintf(fidLog,'Failed running Third Stage Rscript: %s\n',pthRbin);
        end
        fprintf(fidLog,'=============================================================\n');
        fprintf(fidLog,'\n\nCommand output:\n\n');
        fprintf(fidLog,cmdOutput);
        fprintf(fidLog,'\n\n\n\n');
        fprintf(fidLog,'=============================================================\n');
        fprintf(fidLog,'Rscript:      %s\n',pthRbin);
        fprintf(fidLog,'Command line: %s\n',CLI_args);
        fprintf(fidLog,'Start:        %s\n',datestr(tv_start)); %#ok<DATST>
        fprintf(fidLog,'End:          %s\n',datestr(now)); %#ok<TNOW1,DATST>
        fprintf(fidLog,'Elapsed time: %6.1f min\n',toc/60);
        fprintf(fidLog,'==============================================================\n'); 
        fclose(fidLog);
    end
    
end



% ===============================================================================================
% Local functions
%================================================================================================

function biometRpath = findBiometRpath
    funA = which('read_bor');     % First find the path to Biomet.net by looking for a standard Biomet.net functions
    tstPattern = [filesep 'Biomet.net' filesep];
    indFirstFilesep=strfind(funA,tstPattern);
    biometRpath = fullfile(funA(1:indFirstFilesep-1),tstPattern,'R', 'database_functions');
end

function databasePath = findDatabasePath
    databasePath = biomet_path('yyyy');
    indY = strfind(databasePath,'yyyy');
    databasePath = databasePath(1:indY-2); 
end

function Rpath = findRPath
    if ispc     % for PCs
        pathMatlab = matlabroot;
        indY = strfind(upper(pathMatlab),[filesep 'MATLAB']);
        pathBin = fullfile(pathMatlab(1:indY-1));
        s = dir(fullfile(pathBin,'R','R-*'));
        if length(s) < 1
            error ('Cannot find location of R inside of %s\n',pathBin);
        end
        [~,N ]=sort({s(:).name});
        N = N(end);
        Rpath = fullfile(s(N).folder,s(N).name,'bin','Rscript.exe');
    elseif ismac    % for Mac OS
        % look for location of Rscript executable
        [status,outpath] = system('which Rscript');    
        if status   
            % can't find Rscript, need to modify system path to include 
            % where Rscript is installed (e.g. '/usr/local/bin/')
            % this might appear redundant but works with approach to use UNIX
            % "which" command, and so we don't assume path to Rscript is
            % same on every Mac
            Rloc = '/usr/local/bin';    % likely path to Rscript
            path = getenv('PATH');
            newpath = [path ':' Rloc];
            setenv('PATH',newpath);
            [~,outpath] = system('which R');
        end   
        indY = strfind(outpath,[filesep 'R']);
        pathBin = fullfile(outpath(1:indY-1));
        Rpath = fullfile(pathBin,'Rscript'); 
          
        % check 
        if ~isfile(Rpath)
            error ('Cannot find R in %s\n',pathBin);
        end

    end
end
        

% OLD revisions
% Mar 20, 2024 (Rosie)
%   - Edited to run on both Windows PC and now also Mac OS (Ventura 13.5);
%   - Other minor edits to remove warnings (Matlab 2023b).
% Apr 28, 2023 (Zoran)
%   - Added a new paramter to _setThirdStageCleaningParameters.R:
%       -  fprintf(fidIni,'data_source    <- "%s"\n','MICROMET');
% Feb 2, 2022 (Zoran/June)
%   - fixed a bug in sub-function findRPath that incorrectly identified 
%     the newest Rscript installation.
% Nov 7, 2022 (Zoran)
%  - Changed yearsToProcess from 1 to 99. Now all data for the site will be
%    used for gap filling
% Nov 6, 2022 (Zoran)
%  - Added some comments
% Nov 5, 2022 (Zoran)
%  - changed the way ini data gets transfered to R. Instead of having a csv
%    ini file siteID_ThirdStageCleaningParameters.ini, we'll use an 
%    R script named: siteID '_setThirdStageCleaningParameters.R
%    Much easier for the users.
% Nov 2, 2022 (Zoran)
%  - changed the name of main R script to Run_ThirdStage_REddyProc.R
%  - arguments for R script are now passed mostly as data in an ini
%    file: siteID_ThirdStageCleaningParameters.ini. Only the path to
%    the ini file is passed directly as an input argument to Run_ThirdStage_REddyProc.R
