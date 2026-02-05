function runTenthStage_AmerifluxQAQC(yy_str,siteID)

% Find path to the newest version of Rscript
pthRbin = findRPath;

% Biomet /R/ path which contains the /amerifluxqaqc/ folder
biometRpath = findBiometRpath;

% Find database path
rootDatabasePath = findDatabasePath;

% Path where Ameriflux formatted csv is stored
pthDatabase = fullfile(rootDatabasePath,yy_str,siteID,'Clean','Ameriflux');

% Path for siteID_config.yml
path_yml = fullfile(biomet_database_default,'Calculation_Procedures',...
    'TraceAnalysis_ini',siteID,char([siteID '_config.yml']));

if isfile(path_yml)
    % Load siteID_config.yml to check for Ameriflux QAQC flag
    yml_data = yaml.loadFile(path_yml);
    
    good2go = isfield(yml_data.Metadata,'lat') &...
        isfield(yml_data.Metadata,'long') &...
        isfield(yml_data.Metadata,'TimeZoneHour');
    if ~good2go
        fprintf('Missing metadata! Check %s for Metadata:lat, Metadata:long, and Metadata:TimeZoneHour', path_yml)
        return
    end
end
            
% Command to launch R and execute ameriflux qaqc scripts
%--> (1) R program; (2) R-script; (3) ameriflux qaqc
%       R-scripts folder; (4) database folder; (5)
%       ameriflux siteID; (6) latitude; (7) longitude; (8)
%       time zone offset
CLI_args = sprintf('"%s" --vanilla "%s" "%s" "%s" "%s" "%s" %2.4f %2.4f %i',...
    pthRbin,...
    fullfile(biometRpath,'amerifluxqaqc','R','amf_chk_run.R'),...
    strrep(fullfile(biometRpath,'amerifluxqaqc'),'\','/'),...
    strrep(pthDatabase,'\','/'),...
    char(['CA-' siteID]), ...
    strrep(pthDatabase,'\','/'),...
    yml_data.Metadata.lat,...
    yml_data.Metadata.long,...
    yml_data.Metadata.TimeZoneHour);

% Run the command line argument
fprintf('Running the following command: %s\n', CLI_args);
fprintf('Start time: %s\n\n',datetime)
[statusR,cmdOutput] = system(CLI_args);

if statusR~=0
    qaqc_log = fullfile(pthDatabase,'QAQC','output');
    fprintf('\n *** Failed running amerifluxqaqc.R ***\n To see roughly where the problem occurred, check the log in the latest folder here:\n %s\n\n',qaqc_log)
    fprintf('Below is the console window output from R\n %s\n',cmdOutput);
end
% When R is finished, print cmdOutput
fprintf('%s\n',cmdOutput)

% Delete temporary directory created by amerifluxqaqc.R
rmdir(fullfile(pthDatabase,'temp'),'s')

end

% ===============================================================================================
% Local functions
%================================================================================================

function biometRpath = findBiometRpath
    funA = which('read_bor');     % First find the path to Biomet.net by looking for a standard Biomet.net functions
    tstPattern = [filesep 'Biomet.net' filesep];
    indFirstFilesep=strfind(funA,tstPattern);
    biometRpath = fullfile(funA(1:indFirstFilesep-1),tstPattern,'R');
end

function databasePath = findDatabasePath
    databasePath = biomet_path('yyyy');
    indY = strfind(databasePath,'yyyy');
    databasePath = databasePath(1:indY-2);
    if strcmp(databasePath(end),':')
        % if databasePath is just the drive (c:) then add filesep
        databasePath = [databasePath filesep];
    end
end

function Rpath = findRPath
    if ispc     % for PCs
        if exist("biomet_Rpath_default.m",'file')
            Rpath = biomet_Rpath_default;
        else
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
        end
    elseif isunix    % for Mac OS or linux
        if exist("biomet_Rpath_default.m",'file')
            Rpath = biomet_Rpath_default;
        else        
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
end
