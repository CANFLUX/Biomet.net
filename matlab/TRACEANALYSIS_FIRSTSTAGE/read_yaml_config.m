function trace_yaml_config = read_yaml_config(fid)

% Ideally we'd just pass the filepath beause that is what the yaml parser wants ...
% But to conform with the legacy approach, for now it will get the filename (which is already known elsewehre) from the fid number
ymlFileName = char(arrayfun(@fopen, fid, 'UniformOutput', 0));
keyboard
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


trace_str = [];

trace_str.stage = 'none';  %stage of cleaning, used later by cleaning functions ('none' = no cleaning, 'first' = first stage cleaning, 'second' = second stage cleaning)
trace_str.Error = 0;       %default error code, 0=no error, 1=read error

trace_str.Site_name = '';
trace_str.variableName = '';
trace_str.ini = [];
trace_str.SiteID = '';
trace_str.Year = '';
trace_str.Diff_GMT_to_local_time = '';
trace_str.Last_Updated = '';
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

% Define which fileds in the ini must exist
required_common_ini_fields = {'variableName', 'title', 'units'};
required_first_stage_ini_fields = {'inputFileName', 'measurementType', 'minMax'};
required_second_stage_ini_fields = {'Evaluate1'};

%Read each line of the ini_file given by the file ID number, 'fid', and for each trace
%listed, store into an array of structures:
countTraces = 0;

yml_ini = yaml.loadFile(ymlFileName);


countTraces = length(fieldnames(yml_ini.Trace));
countTraces

% Read includes and add them to default traces
for nInclude = 1:length(yml_ini.include)



trace_yaml_config = trace_str;

% // trace_str_yml = [];