function trace_str = read_data(yearIn, SiteID, ini_file)
% This function reads the data from the database.  Given the ini_file the function
% is able to determine what stage of the cleaning process should be applied (ie first of second stage)
% Note however that data is not cleaned in this stage;  data is mearly read from the database
% and in the case of the second stage clean data is read from the database (followed by calculations
% on the data.


% Input:	'yearIn' - year of the data to be read
%			'SideId' - site Id of the data to be read
%			'ini_file' - file path for the ini file (first or second stage)
% Output: 'trace_str' - an array of traces organized in a particular trace structure
%                      See the function 'read_ini_file' for more information


% last modification: Feb 1, 2025

% revisions:
%
% Feb 1, 2025 (Zoran)
%   - Bug fix: This function was displaying 'Cleaning traces...' but it was not cleaning them, only reading them
%     Replaced with: 'Reading traces from database...'
% Sep 13, 2024 (Zoran)
%   - Changed this line:
%       if isempty(lsttv) & isfield(trace_str(1).ini,'Evaluate1')
%     to
%       if isempty(lsttv) & endsWith(ini_file,'_SecondStage.ini','Ignorecase',true)
%     In the past isfield(trace_str(1).ini,'Evaluate1') was synonym with "is this the
%     second stage ini" because the FirstStage didn't have the Evaluate
%     property. That changed so this new option is the way to do it properly.
% Apr 30, 2024 (Zoran)
%   - Removed the orphan input parameter "countTraces" from the call to evaluate_trace. 
% Apr 29, 2024 (Zoran)
%   - reformated file and remove lines that were not used
%   - some syntax improvements
%   - removed unused input parameters sourceDB and options. Checked Biomet.net
%     and confirmed that they are not used/needed.
%   - groundwork for adding Evaluate to 1st stage
% Apr 2, 2024 (Zoran)
%   - changed: arg_default('year',yearNow) to arg_default('yearIn',yearNow).
%     The former was wrong.
% Feb 22, 2024 (Zoran)
%   - added  && ~isempty(trace_str(1).searchPath) to avoid warning
%     messages.
% Feb 15, 2023 (Zoran)
%   - made SearchPath option 'auto' work for the ThirdStage.ini files too.
% Jan 23, 2023 (Zoran)
%   - added an option for the SecondStage ini file to have searchPath defined
%     as 'Met,Flux' instead of 'low_level'. This makes ini files very flexible
%     and remove need to edit this function every time we add a folder name
%     that hasn't been standardized until that moment.
%   - also added 'auto' option for the searchPath. This option loads all
%     Clean traces from the traces that are mentioned in FirstStage.ini
%     for this site
%   - Changed misleading message 'Reading traces from database' to
%     'Cleaning traces...' which is what is happening at that point.
% July 18, 2022 (Zoran)
%   - added try-catch-end around fr_set_site statements. That should keep
%       it compatible with the legacy operation at Biomet and the new setup at
%       Micromet.
% June 6, 2022 (Sara K)
%   - Added path for ECCC data (commented out for now)
%
% Apr 11, 2022 (Zoran)
%   - fixed a bug where ini_file_default was not used properly
%   - fixed issues with filesep (MacOS vs Windows)
%   - replaced findstr with strfind calls
% Apr 6, 2022 (Zoran)
%   - fixed bug in setting up default parameters. Switched all:
%       if ~exist('sourceDB') | isempty(sourceDB)
%     testing to:
%       arg_default()
% Apr 22, 2020 (Zoran)
%   - Matlab 2020 syntax updates. Case-sensitivity. Changed
%     fr_current_SiteID to fr_current_siteID
%   - changed waitbar_ubc to waitbar
%
% July 2, 2010
%   -Nick added to handle hourly UBC Totem historical climate data, July
%    2, 2010
% Jan 24,2007 : Nick modified the loading of trace_str.timeVector to handle
%               high frequency data


%-------------------------------------------------------------------------------------
% Set argument defaults
bgc = [0 0.36 0.532];

yearNow = year(datetime);
arg_default('yearIn',yearNow)

% Added by June Skeeter to read SiteID_config.yml files
fn = fullfile(db_pth_root,"Calculation_Procedures/TraceAnalysis_ini",SiteID,strcat(SiteID,"_config.yml"));
if isfile(fn)
    configYAML = yaml.loadFile(fn);
else
    configYAML.Metadata = NaN;
end

ini_file_default = biomet_path('Calculation_Procedures\TraceAnalysis_ini',SiteID);
ini_file_default = setFolderSeparator(fullfile(ini_file_default,[SiteID '_FirstStage.ini']));
arg_default('ini_file',ini_file_default)
ini_file = setFolderSeparator(ini_file);    % in case that ini_file has wrong folder separators
arg_default('options','none')
arg_default('sourceDB','database')

%-------------------------------------------------------------------------------------
% Handle the path - all site specific generation should be done via function in
% biomet_path('Calculation_Procedures\TraceAnalysis_ini',SiteID,'Derived_Variables')
addpath( biomet_path('Calculation_Procedures\TraceAnalysis_ini',SiteID,'Derived_Variables'))

%-------------------------------------------------------------------------------------
%Open initialization file if it is present:
if exist('ini_file','var') & ~isempty(ini_file) %#ok<*AND2>
    fid = fopen(ini_file,'rt');						%open text file for reading only.
    if (fid < 0)
        disp(['File, ' ini_file ', is invalid']);
        trace_str = [];
        return
    end
    % Read ini file
    trace_str = read_ini_file(fid,yearIn);
    fclose(fid);
    if isempty(trace_str)
        return
    end
end

% Fill in the empty year
if ~exist('SiteID','var') | isempty(SiteID)
    SiteID = upper(trace_str(1).SiteID);
end

% Make SiteID current
% (added try-catch-end on July 18, 2022 to stop the program from crashing
% on Micromet server while keeping compatibility with Biomet operation)
try
    if ~strcmpi(fr_current_siteID,SiteID)
        fr_set_site(SiteID,'network');
    end
catch
end

%Itterate through all traces
error_count = 0;								%counts the number of errors encountered during reading
currentFlag = 0;								%flag for determining if the current traces should be saved to the workspace

%Break up search path into correct parts
if isfield(trace_str(1),'searchPath') && ~isempty(trace_str(1).searchPath)
    [searchPath, remainder] = strtok( strrep(trace_str(1).searchPath, ',', ' ' ));
else
    searchPath = [];
end

%Determine which path to load into DB
while ~isempty( searchPath )
    switch searchPath
  	  case 'low_level'
          pth_full = biomet_path(yearIn,SiteID,'cl');
          ind_y = strfind(pth_full,num2str(1999));
          if ~isempty(ind_y)
              pth_full(ind_y:ind_y+3) = num2str(yearIn);
          end
          pth_full = pth_full(1:end-8);
          initializeWorkSpaceTraces( [pth_full 'Climate\Clean\'] ); %load all the traces into the workspace, used by second stage reading
          initializeWorkSpaceTraces( [pth_full 'Profile\Clean\'] ); %load all the traces into the workspace, used by second stage reading
          initializeWorkSpaceTraces( [pth_full 'Flux\Clean\'] ); %load all the traces into the workspace, used by second stage reading
          %Added February 2, 2006 (dgg)
          initializeWorkSpaceTraces( [pth_full 'Chambers\Clean\'] ); %load all the traces into the workspace, used by second stage reading
          %Added June 6, 2011 (Nick)
          initializeWorkSpaceTraces( [pth_full 'Flux_Logger\Clean\'] ); %load all the traces into the workspace, used by second stage reading
          %Added Apr 6, 2022 (Zoran)
          initializeWorkSpaceTraces( [pth_full 'Met\Clean\'] ); %load all the traces into the workspace, used by second stage reading
          % Added Jun 6, 2022 (Sara K)
          %initializeWorkSpaceTraces( biomet_path(yearIn,'ECCC') ); %load all the traces into the workspace, used by second stage reading

        case 'high_level'
            for pth = trace_str(1).high_level_path
                pth_full = biomet_path(yearIn,SiteID,char(pth));
                ind_y = strfind(pth_full,num2str(1999));
                if ~isempty(ind_y)
                    pth_full(ind_y:ind_y+3) = num2str(yearIn);
                end
                initializeWorkSpaceTraces(pth_full); %load all the traces into the workspace, used by second stage reading
            end
        case 'current'
            %currently not used as when the trace is evaluated it is saved in the current workspace,
            %  over-writing any variable with the same name (ie current is always on, with the highest priority)
            currentFlag = 1;
        case 'auto'
            % Use this option in the future if you want to initialize all Clean variables
            % from the FirstStage.ini.
            % The program reads the siteID_FirstStage.ini file and initializes all folders
            foldersToInitialize = db_find_folders_to_clean(yearIn,SiteID,1);
            for cntFolders = 1:length(foldersToInitialize)
                folderName = fullfile(db_pth_root,char(foldersToInitialize{cntFolders}));
                initializeWorkSpaceTraces( folderName );
            end
            % Check if this is third stage cleaning and, if it is, load up the
            % traces from Clean/SecondStage
            %iniFileName = char(arrayfun(@fopen, fid, 'UniformOutput', 0));
            if contains(ini_file,'_ThirdStage.ini')
                pth_full = biomet_path(yearIn,SiteID);
                initializeWorkSpaceTraces( fullfile(pth_full,'Clean/SecondStage') );
            end
        otherwise
            % Also a future-proof option. In can be used in addition to 'auto'
            % Enables adding new sites and folders without
            % need to edit this file. Phases out 'low_level'
            % The input is the name of the folder ('Flux/Clean','Met/Clean','Profile/Clean',...)
            % First letter of the name should be caps followed
            searchPath(searchPath=='\' | searchPath == '/') = filesep; % insure that all file separators are correct for this OS
            % also make all first letters of the folder name caps.
            folderName = lower(searchPath);
            folderName(1) = upper(folderName(1));
            % and all first letters after filesep should be caps too
            indCaps = find(folderName == filesep)+1;
            if indCaps(end) > length(folderName)
                indCaps(end)=[];
            end
            folderName(indCaps) = upper(folderName(indCaps));
            % complete full folder path
            folderName = fullfile(biomet_path(yearIn,SiteID),folderName);
            % initialize the folder
            initializeWorkSpaceTraces( folderName );
    end

    [searchPath, remainder] = strtok( remainder );
end

%Verify that the clean_tv structure is loaded
s = whos('clean*tv');
lsttv = {s.name}';
% 
%if isempty(lsttv) & isfield(trace_str(1).ini,'Evaluate1') chaged Sep 13, 2024
if isempty(lsttv) & endsWith(ini_file,'_SecondStage.ini','Ignorecase',true)
    disp('Warning: Unable to find clean tv trace, output traces may not contain fields DOY or timeVector');
end
if isempty(lsttv)
    addTimeInfo = 0;
else
    addTimeInfo = 1;
end

% Cycle thru traces
numberTraces = length(trace_str);

% Create waitbar --added name of trace to waitbar (crs)
h = waitbar(0,'Reading traces from database ...','DefaultTextInterpreter','none');
set(h,'Color',bgc);
set(h,'Name','Reading traces from database ...');
set(get(h,'Children'),'Color',bgc,'LineWidth',0.5);
set(get(get(h,'Children'),'Title'),'Color',[1 1 1])

fprintf(1,'Reading traces from database...\n');

for countTraces = 1:numberTraces

    trace_out = trace_str(countTraces);

    %Load the next trace into trace_out
    if isfield(trace_str(countTraces),'ini')								%make sure it has ini field.
        % if 1st stage, read the trace from the data base
        if strcmpi(trace_out.stage,'first')
            trace_out = read_single_trace( trace_out, sourceDB);   					%read raw data from the database
            % Add current trace into the workspace so it can be available for
            % the first stage Evaluate statement (introduced Apr 29, 2024)
            eval(sprintf('%s = trace_out.data;',trace_out.variableName));
        end
        % Run evaluate statement for the current trace
        if isfield(trace_str(countTraces).ini,'Evaluate1')       %if the data needs to be evaluated
            trace_out = evaluate_trace( trace_out );	  %evaluate the trace (second stage only)
        end
    end

    %If the trace has data (ie it was loaded) then save it to the trace structure
    % otherwise output an error message and don't save the trace to the trace structure
    if trace_out.Error == 0
        %disp(['Loaded Trace: ' trace_str(countTraces).ini.variableName]);
        trace_str(countTraces) = trace_out;

        if addTimeInfo == 1 & (length(trace_str(countTraces).data) == 17520 | length(trace_str(countTraces).data) == 17568)
   	     %Add the time Vector
         trace_str(countTraces).timeVector = clean_tv;
         %Add Day of Year (DOY) vector
         trace_str(countTraces).DOY = convert_tv( clean_tv,'doy' );         
        elseif addTimeInfo == 1 & (length(trace_str(countTraces).data) == 175200 | length(trace_str(countTraces).data) == 175680)
            % handles FSP 3min PAR data
            trace_str(countTraces).timeVector = clean_3min_tv;
            trace_str(countTraces).DOY = convert_tv( clean_3min_tv,'doy' );            
        elseif addTimeInfo == 1 & (length(trace_str(countTraces).data) == 52560 | length(trace_str(countTraces).data) == 52704)
            % Nick added to handle Mark Johnson's WaterQ 10 min data
            trace_str(countTraces).timeVector = clean_10min_tv;
            trace_str(countTraces).DOY = convert_tv( clean_10min_tv,'doy' );
        elseif addTimeInfo == 1 & (length(trace_str(countTraces).data) == 8760 | length(trace_str(countTraces).data) == 8784)
            % Nick added to handle hourly UBC Totem historical climate data, July
            % 2, 2010
            trace_str(countTraces).timeVector = clean_hourly_tv;
            trace_str(countTraces).DOY = convert_tv( clean_hourly_tv,'doy' );
        end

        %Set the data_old to data
        trace_str(countTraces).data_old = trace_str(countTraces).data;

    else
        %if there is an error display an error message for the users information
        disp(['*** Read Error: ' trace_str(countTraces).ini.variableName ' not loaded']);
        error_count = error_count + 1;
    end

end

% Round timeVector
for countTraces = 1:numberTraces
    if mean(diff(trace_str(countTraces).timeVector)) > 1/48-1/86400 & mean(diff(trace_str(countTraces).timeVector)) < 1/48+1/86400 ...
            & ~exist('timeVector','var')
        timeVector = fr_round_hhour(trace_str(1).timeVector);
    end
    if mean(diff(trace_str(countTraces).timeVector)) > 1/48-1/86400 & mean(diff(trace_str(countTraces).timeVector)) < 1/48+1/86400
        trace_str(countTraces).timeVector = timeVector;
    end
end

%Close the status bar window
if ishandle(h)
    close(h);
end

fprintf(1,'   Done reading traces.\n');

