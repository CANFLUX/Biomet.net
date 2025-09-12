function trace_yaml_config = read_yaml_config(ymlFileName,yearIn)
% written by June Skeeter 2025-08-29
% A function to read yaml files which hopefully replace stage 1/2 ini files
% A corresponding python function for converting custom ini to standard yml
% has been developed to transalte existing ini files


arg_default('yearIn',year(datetime()));
trace_yaml_config = '';

% Ideally we'd just pass the filepath beause that is what the yaml parser wants ...
% But to conform with the legacy code it will get the filename from the fid number

% ymlFileName = char(arrayfun(@fopen, fid, 'UniformOutput', 0));
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
if strcmp(iniFileType,'first')
    trace_str.Timezone = '';
end
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
trace_str.high_level_path = [''];     % Modified from tempalte to conform with expected type from parsing an empyt high_level_path = {}


trace_str.iniFileName = char(ymlFileName);
trace_str.iniFileLineNum = 0;

% Opperations adapted for working with yaml format (recursion & eval (mostly) not required)
yml_ini = read_and_check_types(ymlFileName);

% Add whatever is possible from the get go
% Base variables from inis without tags are coded as "metadata"
% This won't work for ini lines where names don't match the codebase ... but
% now is the perfect time to fix that, by translating the chainges in the
% python YAML parser!
% base-level fields in the yaml file
metadata = fieldnames(yml_ini.metadata);
% base-level fields in trace_str
base_fields = fieldnames(trace_str);
cell_array = {'high_level_path'};
for i = 1:length(metadata)
    md_fn = metadata{i};
    if ismember(md_fn,base_fields)
        value = yml_ini.metadata.(md_fn);
        if ~isempty(value) & ~isa(value,'yaml.Null')
            if ismember({md_fn},cell_array)
                trace_str.(md_fn) = {value};
            else
                trace_str.(md_fn) = value;
            end
        end
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
        existingTraces = fieldnames(yml_ini.Trace);
        for nadd = 1:numel(addTraces)
            % find overlaps, base ini file should overwrite anything in the
            % include
            addVar = addTraces{nadd};
            addTrace = yml_ini_include.Trace.(addTraces{nadd});
            if ismember(addVar,existingTraces)
                current = yml_ini.Trace.(addVar);
                if current.Overwrite>=addTrace.Overwrite
                    if current.Overwrite == 2
                        % Current will overwrite include and not move postions
                        continue
                    else
                        % Current will overwrite inclue (at position of include)
                        addTrace = yml_ini.Trace.(addVar);
                        yml_ini.Trace = rmfield(yml_ini.Trace,addVar);
                        yml_ini.Trace.(addVar) = addTrace;
                    end
                else
                end

            end
            yml_ini.Trace.(addTraces{nadd}) = addTrace;
        end
    end
end

% Some modified legacy code, Don't think its used in current version? but
% just incase, modify input path
if ~isempty(trace_str.input_path) & trace_str.input_path(end) ~= '\'
    trace_str.input_path = [trace_str.input_path filesep];
end
if ~isempty(trace_str.output_path) & trace_str.output_path(end) ~= '\'
    trace_str.output_path = [trace_str.output_path filesep];
end
%Elyn 08.11.01 - added year-independent path name option
ind_year = strfind(lower(trace_str.input_path),'yyyy');
if isempty(ind_year) & length(ind_year) > 1
    error 'Year-independent paths require a wildcard: yyyy!'
end
if ~isempty(ind_year) & length(ind_year) == 1
    trace_str.input_path(ind_year:ind_year+3) = num2str(yearIn);
end

% Update from global Trace variables
if isfield(yml_ini,'globalVars') & isfield(yml_ini.globalVars,'Trace')
    global_trace_updates = fieldnames(yml_ini.globalVars.Trace);
else
    global_trace_updates = {};
end
for trace_update = global_trace_updates'
    trace_global = yml_ini.globalVars.Trace.(char(trace_update));
    if isfield(yml_ini.Trace,char(trace_update))
        for fld=fieldnames(trace_global(:))'
            yml_ini.Trace.(char(trace_update)).(char(fld)) = trace_global.(char(fld));
        end
    end
end

% Then update from global instrument variables
if isfield(yml_ini,'globalVars') & isfield(yml_ini.globalVars,'Instrument')
    global_instrument_updates = fieldnames(yml_ini.globalVars.Instrument);
    fns = fieldnames(yml_ini.Trace);
    types = cellfun(@(f) yml_ini.Trace.(f).instrumentType, fns, 'UniformOutput', false);
else
    global_instrument_updates = {};
end
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
% filter for inputFilename_Dates first if possible
variableNames = fieldnames(yml_ini.Trace);
nTraces = length(variableNames);
mth_trace_added = 0;
strYearDate = datenum(yearIn,1,1,0,30,0); %#ok<*DATNM>
endYearDate = datenum(yearIn+1,1,1,0,0,0);
tvYear = fr_round_time(strYearDate:1/48:endYearDate); % contains all 30-min points in the current year
for nth_trace=1:nTraces
    temp_trace = yml_ini.Trace.(variableNames{nth_trace});
    bool_no_inputFileName_dates = (~isfield(temp_trace,'inputFileName_dates') ...
        || isempty(temp_trace.inputFileName_dates));
    if bool_no_inputFileName_dates
        bool_validTrace = 1;
    else
        bool_validTrace = 0;
        datesMatrix = temp_trace.inputFileName_dates;

        for cntRows = 1:size(datesMatrix,1)
            % if any of the data points beween one of input_FileName_dates pairs
            % belong to the current year then keep the trace
            if   any(tvYear > temp_trace.inputFileName_dates(cntRows,1) & ...
                tvYear <= temp_trace.inputFileName_dates(cntRows,2)) 
                bool_validTrace = 1;
                break
            end
        end
    end
    if bool_validTrace
        mth_trace_added = mth_trace_added + 1;
        trace_str(mth_trace_added) = trace_str(1);
        trace_str(mth_trace_added).variableName = temp_trace.variableName;
        trace_str(mth_trace_added).ini = yml_ini.Trace.(variableNames{nth_trace});
    
        % if globalVars.other exist, store them under the ini.globalVars.other field
        if isfield(yml_ini,'globalVars') && isfield(yml_ini.globalVars,'other')
            trace_str(mth_trace_added).ini.globalVars.other = yml_ini.globalVars.other;
        end
        if strcmp(iniFileType,'second')
            trace_str(mth_trace_added).ini.measurementType = 'high_level';
        end
    
    else
        fprintf('\nSkipping %s due to filename date filter\n',temp_trace.variableName )
    end

end

trace_yaml_config = trace_str;
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
    double_array = {'Overwrite','Enable','minMax','clamped_minMax','zeroPt','inputFileName_dates','loggedCalibration','currentCalibration'};
    % First apply to trace blocks
    trace_name = fieldnames(block_in);
    flagOverwriteDefault = 0;
    flagOverwriteNew = flagOverwriteDefault;
    for tr = trace_name(:)'
        tr_flds = fieldnames(block_in.(char(tr)));
        for tf = tr_flds(:)'
            v = block_in.(char(tr)).(char(tf));
            if strcmp(char(tf),'Overwrite')
                flagOverwriteNew = block_in.(char(tr)).(char(tf));
                if ~ismember(flagOverwriteNew,[0 1 2])
                    % flag can have only 3 possible values [0 1 2])
                    error('      Overwrite property value can be only [0 1 2]. Trace: %s has Overwrite = %d\n',trace_str(mth_trace_added).variableName,flagOverwriteNew);
                end
            end
            if ismember(char(tf),cell_array) & ~ isa(v,'cell')
                block_in.(char(tr)).(char(tf)) = {v};
            elseif ismember(char(tf),cell_array)
                block_in.(char(tr)).(char(tf)) = v;
            elseif strcmp(char(tf),'Evaluate') | strcmp(char(tf),'postEvaluate')
                % Parse to match the expectation of the legacy code
                lines = splitlines(v);
                for k = 1:numel(lines)
                    c = split(lines{k},'%');
                    lines{k} = regexprep(strtrim(c{1}),'\s+','');
                end
                v = strjoin(lines,',');
                if v(1) == "'" & v(end) == "'"
                    v = v(2:end-1);
                end

                if strcmp(char(tf),'Evaluate')
                    % Rename for legacy reasons
                    block_in.(char(tr)).('Evaluate1') = v;
                    block_in.(char(tr)) = rmfield(block_in.(char(tr)),'Evaluate');
                else
                    block_in.(char(tr)).('postEvaluate') = v;
                end

            elseif ismember(char(tf),double_array) & ~ isa(v,'double')
                values = block_in.(char(tr)).(char(tf));
                rshape = 0;
                if isempty(values)
                    values = [];
                else
                    if iscell(values) && all(cellfun(@iscell, values))
                        rshape = numel(values{1});
                        for k = values
                            if ~numel(k) == rshape
                                error('inconsistent sizing in sub arrays')
                            end
                        end
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
                end
                if isa(values,'cell')
                    values = [values{:}];
                    if rshape
                        values = reshape(values,rshape,[]).';
                    end
                end
                block_in.(char(tr)).(char(tf)) = values;
                
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
        block_in.(char(tr)).('Overwrite') = flagOverwriteNew;
    end
    block_out = block_in;
end
    