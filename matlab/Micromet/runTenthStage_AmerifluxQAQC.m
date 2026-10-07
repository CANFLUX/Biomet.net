function runTenthStage_AmerifluxQAQC(yy_str,siteID)

% Find path to the newest version of Rscript
pthRbin = findRPath;

% Biomet /R/ path which contains the /ameriflux_qaqc/ folder
biometRpath = findBiometRpath;

% Find database path
rootDatabasePath = findDatabasePath;

% Path where Ameriflux formatted csv is stored
pthDatabase = fullfile(rootDatabasePath,yy_str,siteID,'Clean','Ameriflux');

% For general use case, this shouldn't have the 'CA-' prefix, but not sure
%   how this should be addressed (P.Moore - 2026-09-08).
ameriflux_siteID = char(['CA-' siteID]);

% Temporary path for csv created by sw_in_pot_[]_multi
pth_sw_in_pot = fullfile(pthDatabase,'temp',char([ameriflux_siteID '_' yy_str '.csv']));

% Temporary path used by "sw_in_pot_[]_multi"
if length(pth_sw_in_pot)<64
    tmpPath = pthDatabase;
else
    if ~ispc
        % Define source and target directories
        tmpPath = fullfile(getenv('HOME'),'/tmp_QAQC');

        if ~isfolder(tmpPath)
            mkdir(tmpPath)
        end
    else
        tmpDrive = availableDriveLetter;
        
        %====== This might be required for mapping to network drives =====%
        % driveInfo = System.IO.DriveInfo(System.IO.Path.GetPathRoot(pthDatabase));
        % isNetwork = strcmp(driveInfo.DriveType, 'Network');
        % 
        % % Map temporary drive to the pthDatabase directory
        % if isNetwork
        %     system(sprintf('net use %s "%s"',tmpDrive,pthDatabase));
        % else
        %     system(sprintf('subst %s "%s"',tmpDrive,pthDatabase));
        % end

        system(sprintf('subst %s "%s"',tmpDrive,pthDatabase));

        tmpPath = tmpDrive;
    end
end

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
%       ameriflux siteID; (6) temp path (7) latitude; (8) longitude; 
%       (9) time zone offset
CLI_args = sprintf('"%s" --vanilla "%s" "%s" "%s" "%s" "%s" %2.4f %2.4f %i',...
    pthRbin,...
    fullfile(biometRpath,'ameriflux_qaqc','R','amf_chk_run.R'),...
    strrep(fullfile(biometRpath,'ameriflux_qaqc'),'\','/'),...
    strrep(pthDatabase,'\','/'),...
    ameriflux_siteID, ...
    strrep(tmpPath,'\','/'),...
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
else
    % Delete temporary directory created by amerifluxqaqc.R
    rmdir(fullfile(tmpPath,'temp'),'s')
end

% When R is finished, print cmdOutput
fprintf('%s\n',cmdOutput)

% Remove temporary mapped drive -- PC
if exist("tmpDrive","var")
    system(sprintf('subst %s /d',tmpDrive));
    disp('Removed temporary mapped drive')
end

% Remove temporary folder -- Mac
if contains(tmpPath,'/tmp_QAQC')
    rmdir(tmpPath,'s')
end

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