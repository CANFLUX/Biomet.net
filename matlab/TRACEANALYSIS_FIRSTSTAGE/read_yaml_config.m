function trace_yaml_config = read_yaml_config(fid,yearIn)
% written by June Skeeter 2025-08-29
% A function to read yaml files which hopefully replace stage 1/2 ini files
% A corresponding python function for converting custom ini to standard yml
% has been developed to transalte existing ini files


arg_default('yearIn',year(datetime()));
trace_yaml_config = '';

% Ideally we'd just pass the filepath beause that is what the yaml parser wants ...
% But to conform with the legacy code it will get the filename from the fid number

ymlFileName = char(arrayfun(@fopen, fid, 'UniformOutput', 0));
% Extract the ini file type ('first','second','third')
[iniFilePath,iniFileType,~] = fileparts(ymlFileName);
[~,iniFileType,~] = fileparts(iniFileType);
if endsWith(iniFileType,'FirstStage','ignorecase',true) || endsWith(iniFileType,'FirstStage_include','IgnoreCase',true)
    iniFileType = 'first';
elseif endsWith(iniFileType,'SecondStage','ignorecase',true)|| endsWith(iniFileType,'SecondStage_include','IgnoreCase',true)
    iniFileType = 'second';  
elseif endsWith(iniFileType,'ThirdStage','ignorecase',true)|| endsWith(iniFileType,'ThirdStage_include','IgnoreCase',true)
    % 'second' is NOT a bug. Let it be.
    iniFileType = 'second';    
end

% Declarations pulled from read_ini_file.m

trace_str = [];

trace_str.stage = iniFileType;  %stage of cleaning, used later by cleaning functions ('none' = no cleaning, 'first' = first stage cleaning, 'second' = second stage cleaning)
trace_str.Error = 0;       %default error code, 0=no error, 1=read error

trace_str.Site_name = '';
trace_str.variableName = '';
trace_str.ini = [];
trace_str.SiteID = '';
trace_str.Year = yearIn;
trace_str.Diff_GMT_to_local_time = '';
% Added even though only declared in original read_ini_file for first stage?
% Diff_GMT_to_local_time is only assigned in first stage, but is was
% declared globally here in read_ini_file ... so I don't think it will
% cause an issue?
trace_str.Timezone = '';
trace_str.Last_Updated = char(datetime("now"));
trace_str.data = [];
trace_str.DOY = [];
trace_str.timeVector = [];
trace_str.data_old = [];

%First stage cleaning specific fields
trace_str.stats = [];				%holds the stats about the cleaning
trace_str.runFilter_stats = [];     %holds the stats about the filtering
trace_str.pts_restored = [];		%holds the pts that were restored
trace_str.pts_removed = [];		    %holds the pts that were removed

%Second Stage specific fields
trace_str.data = [];                %holds calculated data from Evalutation routine
trace_str.searchPath = '';          %holds the options used to determine the path of the second stage data
trace_str.input_path = '';          %holds the path of the database of the source data
trace_str.output_path = '';         %holds the path where output data is dumped
trace_str.high_level_path = '';


trace_str.iniFileName = ymlFileName;
trace_str.iniFileLineNum = 0;

% Define which fileds in the ini must exist
required_common_ini_fields = {'variableName', 'title', 'units'};
required_first_stage_ini_fields = {'inputFileName', 'measurementType', 'minMax'};
required_second_stage_ini_fields = {'Evaluate1'};

% %Read each line of the ini_file given by the file ID number, 'fid', and for each trace
% %listed, store into an array of structures:
% countTraces = 0;
% 
% % Opperations adapted for working with yaml format (recursion & eval (mostly) not required)
yml_ini = read_and_check_types(ymlFileName);
% base-level fields in the yaml file
yml_fields = fieldnames(yml_ini);
% base-level fields in trace_str
base_fields = fieldnames(trace_str);

% Add whatever is possible from the get go
% This won't work for ini lines where names don't match the codebase ... but
% now is the perfect time to fix that, by translating the chainges in the
% python YAML parser!
for i = 1:length(yml_fields)
    yml_fn = yml_fields{i};
    if ismember(yml_fn,base_fields)
        trace_str.(yml_fn) = yml_ini.(yml_fn);
    end
end

% Next read the include traces
if isfield(yml_ini,"Include")
    % Read includes and add them to default traces
    for nInclude = 1:length(yml_ini.Include)
        includeName = yml_ini.Include(nInclude);
        includePath = fileparts(iniFilePath);
        includePath = fullfile(includePath,strcat(includeName{1},'.yml'));
        yml_ini_include = read_and_check_types(includePath);
        addTraces = fieldnames(yml_ini_include.Trace);
        for nadd = 1:numel(addTraces)
            yml_ini.Trace.(addTraces{nadd}) = yml_ini_include.Trace.(addTraces{nadd});
        end
    end
end

variableNames = fieldnames(yml_ini.Trace);
nTraces = length(variableNames);

% Update from global Trace variables
global_trace_updates = fieldnames(yml_ini.globalVars.Trace);
for trace_update = global_trace_updates'
    % keyboard
    trace_global = yml_ini.globalVars.Trace.(char(trace_update));
    if isfield(yml_ini.Trace,char(trace_update))
        for fld=fieldnames(trace_global(:))'
            if isfield(yml_ini.Trace.(char(trace_update)),fld)
                yml_ini.Trace.(char(trace_update)).(char(fld)) = trace_global.(char(fld));
            end
        end
    end
end

% Then update from global instrument variables
global_instrument_updates = fieldnames(yml_ini.globalVars.Instrument);
fns = fieldnames(yml_ini.Trace);
types = cellfun(@(f) yml_ini.Trace.(f).instrumentType, fns, 'UniformOutput', false);
for instrumentType = global_instrument_updates(:)'
    % Find variableNames for given instrument types
    idx = strcmp(types, instrumentType);
    keys = cellfun(@(f) yml_ini.Trace.(f).variableName, fns(idx), 'UniformOutput', false);
    update_props = fieldnames(yml_ini.globalVars.Instrument.(char(instrumentType)));
    enable = 0;
    for prop=update_props(:)'
        prop_val = yml_ini.globalVars.Instrument.(char(instrumentType)).(char(prop));
        if strcmp(prop,'Enable')
            enable = prop_val;
        else
            for key=keys'
                yml_ini.Trace.(char(key)).(char(prop)) = prop_val;
            end
        end
    end
end


% Now iteratively dump traces to trace_str

for nm = fieldnames(yml_ini)'
    nm = char(nm);
    if isfield(trace_str,nm)
        trace_str.(nm) = yml_ini.(nm);
    end
end
for nth_trace=1:nTraces
    trace_str(nth_trace) = trace_str(1);
    temp_trace = yml_ini.Trace.(variableNames{nth_trace});
    trace_str(nth_trace).variableName = temp_trace.variableName;
    trace_str(nth_trace).ini = yml_ini.Trace.(variableNames{nth_trace});

    % if globalVars.other exist, store them under the ini.globalVars.other field
    if isfield(yml_ini,'globalVars') && isfield(yml_ini.globalVars,'other')
        trace_str(nth_trace).ini.globalVars.other = yml_ini.globalVars.other;
    end
% 
%     %Test for required fields that the initialization file must have.
%     curr_fields = fieldnames(trace_str(nth_trace).ini);												%get current fields
%     chck_common = ismember(required_common_ini_fields,curr_fields);				    %check to see if the fields that are common to both stages are present
%     chck_first_stage = ismember(required_first_stage_ini_fields,curr_fields);		%check to see if the fields that are common to both stages are present
%     chck_second_stage = ismember(required_second_stage_ini_fields,curr_fields);		%check to see if the fields that are common to both stages are present
%     if all(chck_common)
%         if all(chck_first_stage)
%             if strcmp(iniFileType,'first')
%                 stage = 'first';
%                 trace_str(nth_trace).stage = 'first';
%             else
%                 error('Ini file is for the stage: %s but the stage: %s is detected based on the required field names. ',iniFileType,stage);
%             end
%         end
%         if all(chck_second_stage)
%             if strcmp(iniFileType,'second')
%                 stage = 'second';
%                 trace_str(nth_trace).stage = 'second';
%             else
%                 error('*Warning: Ini file is for the stage: *%s* but the *second* stage is detected based on the required field names. Line: %d\n',iniFileType,countLines);
%             end
%         end
%     else
%         error(2,'Error in ini file, common required field(s) do not exist.');
%         trace_str_out = '';
%         return
%     end
% 
end

trace_yaml_config = trace_str;
% 
% 
end
% 
function yml_out = read_and_check_types(ymlFileName)
    %YAML will parse differenty than the custom ini eval statements which
    %were developed with older versions of matlab so we need to do some
    %conversions to ensure all types match

    yml_ini = yaml.loadFile(ymlFileName);
    % yaml reads all text as strings, convert to char arrays (where posssible)
    yml_ini = convertContainedStringsToChars(yml_ini);
    yml_ini.Trace = check_types(yml_ini.Trace);
    if isfield(yml_ini,'globalVars')
        if isfield(yml_ini.globalVars,'Trace')
            yml_ini.globalVars.Trace = check_types(yml_ini.globalVars.Trace);
        end
        if isfield(yml_ini.globalVars,'Instrument')
            yml_ini.globalVars.Instrument = check_types(yml_ini.globalVars.Instrument);
        end
    end
    yml_out = yml_ini;
end
function block_out = check_types(block_in)
    % e.g., yaml lists as are read as as cell arrays instead of character/numeric arrays
    % so we need to convert field values where appropriate

    % Certainly a more elegant way to do this, would ideally pull from the template repo
    % For now just hardcoding the expected types for traces.  Default is
    % char if not listed here
    cell_array = {'inputFileName'};
    % Forced to double, will check if strings are datetimes first
    double_array = {'Enable','minMax','clamped_minMax','zeroPt','inputFileName_dates','loggedCalibration','currentCalibration'};
    % double_array_wdatenum = {'inputFileName_dates','loggedCalibration','currentCalibration'};
    % First apply to trace blocks
    trace_name = fieldnames(block_in);
    for tr = trace_name(:)'
        tr_flds = fieldnames(block_in.(char(tr)));
        for tf = tr_flds(:)'
            v = block_in.(char(tr)).(char(tf));
            if ismember(char(tf),cell_array) & ~ isa(v,'cell')
                block_in.(char(tr)).(char(tf)) = {v};
            elseif ismember(char(tf),double_array) & ~ isa(v,'double')
                values = block_in.(char(tr)).(char(tf));
                if isempty(values)
                    values = [];
                else
                    if iscell(values) && all(cellfun(@iscell, values))
                        values = [values{:}];   % concatenate all 1×4 cells (when multiple calibraitons exist)
                    end
                    for i = 1:length(values)
                        if isa(values{i},'cell')
                            'cell flag'
                            keyboard
                        elseif isa(values{i},'char')
                            values{i} = datenum(datetime(values{i}));
                        else
                            values{i} = double(values{i});
                        end
                    end
                    % keyboard
                end
                if isa(values,'cell')
                    values = [values{:}];
                % else
                %     keyboard
                end
                block_in.(char(tr)).(char(tf)) = values;
                
            % % all date objects have been converted to string format in the
            % % yaml files, go back to depreciated datenum for matlab
            % % compatibility
            % elseif ismember(char(tf),double_array_wdatenum) & ~ isa(v,'double')
                % if strcmp(char(tf), 'inputFileName_dates')
                %     % inputFileName_dates are all dates
                %     inputFileName_dates = double([]);
                %     for i = 1:length(v)
                %         inputFileName_dates(i) = datenum(datetime(v(i)));
                %     end
                %     block_in.(char(tr)).(char(tf)) = inputFileName_dates;
                % else
                %     % others contain calibration settings and dates,
                %     % requires parsing
                %     mixed_double = double([]);
                %     if iscell(v) && all(cellfun(@iscell, v))
                %         v = [v{:}];   % concatenate all 1×4 cells (when multiple calibraitons exist)
                %     else
                %         v = v;
                %     end
                %     for i = 1:length(v)
                %         if (mod(i,4) == 0) | (mod(i,4) == 3)
                %             mixed_double(i) = datenum(datetime(v(i)));
                %         else
                %             mixed_double(i) = cell2mat(v(i));
                %         end
                %     end
                %     if length(mixed_double)>4
                %         mixed_double = reshape(mixed_double,4,[])';
                %     end
                %     block_in.(char(tr)).(char(tf)) = mixed_double;
                % end
            else  
                % Handle nulls and other edge cases
                if strcmp(class(v),'yaml.Null')
                    block_in.(char(tr)).(char(tf)) = '';
                elseif ~isa(v,'char') & ~isa(v,'double')
                    if isa(v,'cell')
                        block_in.(char(tr)).(char(tf)) = [v{:}];
                    end
                    % Paths read as cell arrays with globalVars (which may
                    % contain dobules pointing to ECCC station codes)
                    for w=1:length(v)
                        if isa(v{w},'double')
                            v{w}=num2str(v{w});
                        end
                    end
                    v = [v{:}];
                    block_in.(char(tr)).(char(tf)) = char(v);
                end
            end
        end
    end

    block_out = block_in;
end
    