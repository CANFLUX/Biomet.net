function kill_ThirdStage = basic_error_check_yml_site_config(siteID, yearIn, pthIni, pthBiomet)
%
% Function description
%
% Arguments
%   siteID          - site ID as a char
%   yearIn          - year to clean
%   pthIni          - path which contains the site specific _config.yml
%   pthBiomet       - Biomet path which contains global_config.yml (optional)
%
% Paul Moore                File created:       Jan 29, 2025
%                           Last modification:  Mmm dd, YYYY
%

% Revisions
%
% Feb 06, 2024 (Paul)
%   - Bug fixes. Now removes 'Run' if present in storage terms. Now ignores
%       checking storage terms associated with a flux that has been set to
%       NULL.


fprintf('\n================================= LOG =================================\n')

if nargin<4
    pthBiomet = findBiometRpath;
end

if isstring(siteID)
    siteID = char(siteID);
end

arg_default('pthIni',fullfile(biomet_database_default,...
    'Calculation_Procedures\TraceAnalysis_ini',siteID))

% Temporary defaults
% siteID = 'OHM';
% pthIni = 'C:\EcoFlux lab\Database\Calculation_Procedures\TraceAnalysis_ini\OHM';
% pthIni = 'F:\EcoFlux lab\Database\Calculation_Procedures\TraceAnalysis_ini\OHM';

filename = char([char([siteID '_config.yml'])]);
fullpath = fullfile(pthIni,filename);
kill_ThirdStage = false;
msg.FYI = {};
msg.Warning = {};
msg.Error = {};

% Load yml file
site_config = yaml.loadFile(fullpath);
global_config = yaml.loadFile(fullfile(pthBiomet,'global_config.yml'));

% Checks for basic Processing: ThirdStage: Fluxes
bad_format = basicFormatChk(site_config, siteID);

if bad_format
    fprintf(2,'\n Error ----> %s improperly formatted! (see above) \n\n Third Stage processing cannot proceed!!!\n',filename);
    fprintf('\n See: <a href = "https://github.com/CANFLUX/Calculation_Procedures/tree/main/TraceAnalysis_ini">site_config.yml template</a> (***PLACEHOLDER***)\n')
    % If yaml format is incorrect, stop execution and send message to
    %   calling function.
    kill_ThirdStage = true;

    fprintf('=======================================================================\n')
    return
end

% Check that flux names in yaml file match a trace in the second stage
%--> Get names of fluxes listed in site_config
fluxes = fieldnames(site_config.Processing.ThirdStage.Fluxes);

% If any flux trace is not found in database or if a trace is empty, then
%   kill_ThirdStage will return as true.
[msg, kill_ThirdStage] = check4traces(site_config, fluxes, siteID, yearIn,...
    'Fluxes', kill_ThirdStage, msg);

% if kill_ThirdStage
%     return
% end

% If there is no Storage_Correction: Run: False in the site specific
%   configuration file, the default behaviour is to apply the storage
%   correction terms in the global configuration file.
check_SC = true;
global_SC = true;
if isfield(site_config.Processing.ThirdStage,'Storage_Correction')
    % There might not be site-specific SC terms, but the code will at least
    %   check there first.
    global_SC = false;
    if isfield(site_config.Processing.ThirdStage.Storage_Correction, 'Run')
        if ~site_config.Processing.ThirdStage.Storage_Correction.Run
            check_SC = false;
        end
    else
        % Run should be there by default
        disp('Improperly formatted site_config.yml')
    end
end
% Check that storage names in yaml file match a trace in the second stage
%--> Get names of trace listed in site_config or global_config
if check_SC
    if isfield(site_config.Processing.ThirdStage.Storage_Correction,'NEE') & ~global_SC
        yml_config = site_config; % Check trace names from site-specific
    elseif isfield(global_config.Processing.ThirdStage.Storage_Correction,'NEE')
        yml_config = global_config; % Check trace names from global
    else
        % This should never happen since global_config should not be changed
        fprintf('\n Fatal error!!! Your computer will now self destruct\n Have a nice day =)\n')
        
        ascii_img = getMushroomCloud;
        fprintf(ascii_img)
    end
    
    % Get fieldnames under Storage_Correction
    storage = fieldnames(yml_config.Processing.ThirdStage.Storage_Correction);
    %--> Remove 'Run' from storage names
    storage = storage(~strcmpi(storage,'Run'));
    %--> Remove any storage terms associated with a flux set to NULL
    keep_SC = true(length(storage),1);
    for i=1:length(storage)
        if isfield(site_config.Processing.ThirdStage.Fluxes,storage{i})
            flux2check = site_config.Processing.ThirdStage.Fluxes.(storage{i});
            if strcmpi(class(flux2check),'yaml.Null')
                keep_SC(i,1) = false;
            end
        else
            % This shouldn't ever happen.
        end
    end
    storage = storage(keep_SC);

    % If any storage trace is not found in the database or if a trace is empty, 
    %   then kill_ThirdStage will return as true.
    [msg, kill_ThirdStage] = check4traces(yml_config, storage, siteID, yearIn,...
        'Storage_Correction', kill_ThirdStage, msg);
end


% Check trace names found in Processing: ThirdStage: REddyProc: vars_in:
%--> For now, assume Processing: ThirdStage: REddyProc: is in site_config
if isfield(site_config.Processing.ThirdStage.REddyProc,'vars_in')
    vars_in = fieldnames(site_config.Processing.ThirdStage.REddyProc.vars_in);
    yml_config = site_config;
else
    disp('Improperly formatted site_config.yml')
    disp('Missing -- Processing: ThirdStage: REddyProc: vars_in:')
end

% Often NEE is actually FC in the second stage
idx = strcmpi(vars_in,'NEE');
if ~isempty(idx)
    replacement_val = yml_config.Processing.ThirdStage.Fluxes.NEE;
    if ~strcmpi(class(replacement_val),'yaml.Null')
        yml_config.Processing.ThirdStage.REddyProc.vars_in.NEE = ...
            char(replacement_val);
    end
end

% If any vars_in trace is not found in the database or if a trace is empty, 
%   then kill_ThirdStage will return as true.
[msg, kill_ThirdStage] = check4traces(yml_config, vars_in, siteID, yearIn,...
    'REddyProc.vars_in', kill_ThirdStage, msg);


% Other things that could be checked:
% 1. Values in REddyProc:MDSGapFill: basic: match a key entry in REddyProc: vars_in
% 2. Suffixes for RF_GapFilling: Models: [Flux]: var_dep: correspond with
%       ThirdStage options (e.g. if JS_Moving_Z: Run: false, then the
%       suffix would need to be different.
% 3. Error checking for RF_GapFilling predictors


% Display messages in command window
disp([msg.FYI; msg.Warning; msg.Error])
% fprintf('\n')

if kill_ThirdStage
    % fprintf(getGun2KillThirdStage)
    fprintf(2,'\n    Third Stage processing cannot proceed!!! [see error(s) above]\n');
end

fprintf('=======================================================================\n')


%% Check if traces are in second stage
function [msg, kill_ThirdStage] = check4traces(yml_config, varnames, siteID,...
    yearIn,type, kill_ThirdStage, msg)

for i=1:length(varnames)
    trace2check = eval(char(['yml_config.Processing.ThirdStage.' char(type)...
        '.' varnames{i}]));
    % trace2check = yml_config.Processing.ThirdStage.(type).(varnames{i});
    
    % Extract trace name for type = 'Storage_correction';
    if isstruct(trace2check)
        tmp = struct2table(trace2check);
        trace2check = tmp{1,1};
    end
    
    if strcmpi(class(trace2check),'yaml.Null')
        % This message doesn't provide the full story!!!
        
        % The assumption is that this has intentionally been set by the
        %   user, but printing to screen as a placehold operation for now.
        msg.FYI = [msg.FYI;...
            char(['FYI ------> Processing: ThirdStage: ' regexprep(type,'[.]',': ') ': ' varnames{i} ' set to NULL in site_config.yaml'])];
    else
        % Make sure that 'flux2check' is a trace in the second stage
        siteYear_folder = fullfile(biomet_database_default,num2str(yearIn),siteID);
        file2check = fullfile(siteYear_folder, 'Clean\SecondStage', trace2check);
        
        if ~isfile(file2check)
            if strcmp(type,'REddyProc.vars_in')
                prefix_str = 'Warning --> ';
                msg_type = 'Warning';
                
                % NEE and season are special cases
                if strcmpi(trace2check,'season')
                    prefix_str = 'FYI ------> ';
                    msg_type = 'FYI';
                end
            else
                prefix_str = 'Error ----> ';
                msg_type = 'Error';
                kill_ThirdStage = true;
            end
            msg.(msg_type) = [msg.(msg_type);...
                char([prefix_str 'File not present.     [' char(file2check) ']'])];
        else
            % Load flux and check that it is not empty
            trace = read_bor(file2check);

            if sum(~isnan(trace))==0
                n_char = length(char(trace2check));
                msg.Error = [msg.Error;...
                    char(['Error ----> No data in ' char(trace2check) '!' repmat(' ',1,10-n_char) '[' char(file2check) ']'])];
                % disp(file2check)
                kill_ThirdStage = true;
            end
        end
    end
end


%% Subfunction to check basic formatting
function bad_format = basicFormatChk(site_config,siteID)

% Default unless an error is detected
bad_format = false;
yml_file = char([siteID '_config.yml']);

if isfield(site_config,'Processing')
    if isfield(site_config.Processing,'ThirdStage')
        if ~isfield(site_config.Processing.ThirdStage,'Fluxes')
            fprintf(' [Processing: ThirdStage: Fluxes] key not found in %s\n',yml_file)
            bad_format = true;
        end

        if ~isfield(site_config.Processing.ThirdStage,'Storage_Correction')
            fprintf(' [Processing: ThirdStage: Storage_Correction] key not found in %s\n',yml_file)
            bad_format = true;
        end
    else
        fprintf(' [Processing: ThirdStage:] key not found in %s\n',yml_file)
        bad_format = true;
    end
else
    fprintf(' [Processing:] key not found in %s\n',yml_file)
    bad_format = true;
end


function biometRpath = findBiometRpath
    funA = which('read_bor');     % First find the path to Biomet.net by looking for a standard Biomet.net functions
    tstPattern = [filesep 'Biomet.net' filesep];
    indFirstFilesep=strfind(funA,tstPattern);
    biometRpath = fullfile(funA(1:indFirstFilesep-1),tstPattern,'R', 'database_functions');


%% ASCII images
function ascii_img = getMushroomCloud

ascii_img='\n     _.-^^---....,,--\n _--                  --_\n<                         >\n|                         |\n (._                   _.)\n    ```--. . , , .--```\n          | |   |\n       .-=||  | |=-.\n       `-=#$#&#$#=-\n          | ;  :|\n _____.,-##&$@##~,._____;\n';

function ascii_img = getGun2KillThirdStage

ascii_img = '\n    _=__________________________-\n  /  ////  (____)  = = = =____ |     THIRD\n _|_////_________________(____|      STAGE\n    )/  o  /) /  )/ \n   (/     /)__(_))\n  (/     /)\n (/     /)\n(/_ o _/)\n--------\n';