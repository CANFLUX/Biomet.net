function trace_str_out = read_ini_file_update(fid,Year)

% Create by June Skeeter (March 1, 2024)
% Intended to repalce existing string parsing method with a function that
% works with using the **standardized** ini file format.  Outputs should be
% backwards compatible with original read_ini_file() function
% 
% As is, this takes roughly twice as long to read an ini file compared to
% thw old procedure.  But some of of the processes here are only necessary
% for making the ouptut directly compatible to the old procedre.  There
% are time saving to be had if needed.

% Input:		'fid' -this is the file id number associated with the
%						initialization file now open for reading.
%           'year' -this is the year to be added to the year-independent 
%                       initialization file being read
% Ouput:		'trace_str_out' -This is the array of structures representing all
%						the information for each trace in the initialization file.
%						Each field of the traces structure MUST be added here ... see
%						bellow for the places to enter new trace structure fields.
%                 Note that new fields MUST be added in two distinct places within
%                 the function, again see bellow

iniFileName = char(arrayfun(@fopen, fid, 'UniformOutput', 0));
ini = ini2struct(iniFileName);

fprintf('Reading ini file: \n   %s \n',iniFileName);

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
trace_str.runFilter_stats = [];  %holds the stats about the filtering
trace_str.pts_restored = [];		%holds the pts that were restored
trace_str.pts_removed = [];		%holds the pts that were removed

%Second Stage specific fields
trace_str.data = [];        %holds calculated data from Evalutation routine
trace_str.searchPath = '';  %holds the options used to determine the path of the second stage data
trace_str.input_path = '';  %holds the path of the database of the source data
trace_str.output_path = ''; %holds the path where output data is dumped
trace_str.high_level_path = '';
% If the year is missing then set it to empty
if~exist('Year','var') || isempty(Year)
   Year = '';						
end

% Define which fileds in the ini must exist
required_common_ini_fields = {'variableName'; 'title'; 'units'}; 
required_first_stage_ini_fields = {'inputFileName'; 'measurementType'; 'minMax'};
required_second_stage_ini_fields = {'Evaluate1'};


Metadata = ini.Metadata;
ini = rmfield(ini,'Metadata');

fn = fieldnames(ini);
for i=1:length(fn)
    % Set variable name and trace parameters
    variableName = char(fn(i));
    trace_str(i).variableName=variableName;

    var_ini = getfield(ini,variableName);
    infn = fieldnames(var_ini);
    % Count evaluate statements (should only be 1? at leas for stage 2) but
    % for backwards compatibility, the eval statement need to be numbered
    eval_cnt=0;
    nufn = {};
    for n = 1:length(infn)
        if strcmp(infn{n},'Evaluate')
            eval_cnt=eval_cnt+1;
            nufn{n}=strcat(char(infn{n}),sprintf('%i',eval_cnt));
            var_ini.Evaluate = strrep(var_ini.Evaluate,' ','');
        else
            nufn{n}=char(infn{n});
        end
    end
    if i >5
        a=1;
    end
    trace_str(i).ini = cell2struct( struct2cell(var_ini), nufn);

    trace_str(i).Error = 0;  
    % Set Metadata from header
    trace_str(i).Site_name = Metadata.Site_name;
    trace_str(i).SiteID=Metadata.SiteID;
    % set remaining variables
    trace_str(i).Year=Year;
    trace_str(i).Last_Updated = datestr(now);  

    %get current fields
    curr_fields = fieldnames(trace_str(i).ini);
    

    chck_common = ismember(required_common_ini_fields,curr_fields);						%check to see if the fields that are common to both stages are present
    chck_first_stage = ismember(required_first_stage_ini_fields,curr_fields);		%check to see if the fields that are common to both stages are present
    chck_second_stage = ismember(required_second_stage_ini_fields,curr_fields);		%check to see if the fields that are common to both stages are present

    if all(chck_common) 
        if all(chck_first_stage)
            trace_str(i).stage = 'first';
        end
        
        if all(chck_second_stage)
            trace_str(i).stage = 'second';
        end         
        else
            disp(['Error in ini file, common required field(s) do not exist']);
            trace_str_out = '';
        return
    end

    switch trace_str(i).stage
    case 'first'
        trace_str(i).Diff_GMT_to_local_time = Metadata.Difference_GMT_to_local_time;
    
    case 'second'
        trace_str(i).ini.measurementType = 'high_level';
        trace_str(i).searchPath = Metadata.searchPath;  
    
        if ~isempty(Metadata.input_path) & Metadata.input_path(end) ~= '\'
            Metadata.input_path = [Metadata.input_path filesep];
        end
        if ~isempty(Metadata.output_path) & Metadata.output_path(end) ~= '\'
            Metadata.output_path = [Metadata.output_path filesep];
        end
    
        %Elyn 08.11.01 - added year-independent path name option
        ind_year = findstr(lower(Metadata.input_path),'yyyy');
        if isempty(ind_year) & length(ind_year) > 1
            error 'Year-independent paths require a wildcard: yyyy!'
        end
        if ~isempty(ind_year) & length(ind_year) == 1            
            input_path(ind_year:ind_year+3) = num2str(Year);
        end
        
        trace_str(i).input_path = Metadata.input_path;
        trace_str(i).output_path = Metadata.output_path;
        trace_str(i).high_level_path = eval(Metadata.high_level_path);
    end

    if strcmp(trace_str(end).stage,'none')
        disp(['Error: Unrecognized ini file format']);
        trace_str_out = '';
        return
    end


end

cntGoodTrace = 0;
strYearDate = datenum(Year,1,1,0,30,0);
endYearDate = datenum(Year+1,1,1,0,0,0);
for cntTrace = 1:length(trace_str)
    % logic test. True if inputFileName_dates field doesn't exists or it's empty.
    bool_no_inputFileName_dates = (~isfield(trace_str(cntTrace).ini,'inputFileName_dates') ...
            || isempty(trace_str(cntTrace).ini.inputFileName_dates));
    if bool_no_inputFileName_dates 
        % Check if the trace exists in the current year
        
        cntGoodTrace = cntGoodTrace+1;
        trace_str_out(cntGoodTrace) = trace_str(cntTrace);		% store relevant traces
    else
        % non-empty matrix inputFileName_dates exists.
        % Extract the period that this trace was relevant for
        % The matrix can have multiple rows. At least one period needs to 
        % belong to the curent year
        bool_validTrace = 0;
        datesMatrix = trace_str(cntTrace).ini.inputFileName_dates;
        
        for cntRows = 1:size(datesMatrix,1)
            % if start of the year belongs to a period in
            % inputFileName_dates or the end of the year does then keep the
            % trace
            if   (datesMatrix(cntRows,1) < strYearDate && strYearDate < datesMatrix(cntRows,2)) ...
              || (datesMatrix(cntRows,1) < endYearDate && endYearDate < datesMatrix(cntRows,2))
                bool_validTrace = 1;
                break
            end
        end
        if bool_validTrace == 1
            % store relevant traces
            cntGoodTrace = cntGoodTrace+1;
            trace_str_out(cntGoodTrace) = trace_str(cntTrace);  %#ok<*AGROW>
        end        
    end
end
fprintf('   %d traces read from the ini file. \n',length(trace_str));
fprintf('   %d traces that exist in year %d are kept for processing.\n',cntGoodTrace,Year);

function Result = ini2struct(FileName)

% Slight tweak of code from here: https://www.mathworks.com/matlabcentral/fileexchange/17177-ini2struct
% by June Skeeter

Result = [];                            % we have to return something
CurrMainField = '';                     % it will be used later
f = fopen(FileName,'r');                % open file
while ~feof(f)                          % and read until it ends
    s = strtrim(fgetl(f));              % Remove any leading/trailing spaces
    s=strrep(s,'%%','%'); % ini files want these charactes escaped, remove the doulbe % for compatibility
    if isempty(s)
        continue;
    end;
    if (s(1)==';')                      % ';' start comment lines
        continue;
    end;
    if (s(1)=='#')                      % '#' start comment lines
        continue;
    end;
    if ( s(1)=='[' ) && (s(end)==']' )
        % We found section
        CurrMainField = genvarname(s(2:end-1));
        Result.(CurrMainField) = [];    % Create field in Result
    else
        % ??? This is not a section start
        [par,val] = strtok(s, '=');
        evaluate=0;
        % Eval just the selected optoins, return other as strings
        % These probably shouldn't be hard-coded, but doing for a quick
        % solution

                           
        if sum(strcmp(par,{'Difference_GMT_to_local_time','inputFileName','inputFileName_dates', ...
                            'loggedCalibration','currentCalibration', ...
                            'minMax','clamped_minMax','zeroPt'}))>0
            evaluate = 1;
        end
        val = CleanValue(val,evaluate);
        if ~isempty(CurrMainField)
            % But we found section before and have to fill it
            Result.(CurrMainField).(genvarname(par)) = val;
        else
            % No sections found before. Orphan value
            Result.(genvarname(par)) = val;
        end
    end
end
fclose(f);
return;

function res = CleanValue(s,evaluate)
arg_default('evaluate',0)
res = strtrim(s);
if strcmpi(res(1),'=')
    res(1)=[];
end
res = strtrim(res);
% Added by June Skeeter to adapt to our needs since some variables are
% shoul be read as ints (e.g., zeroPt) or arrays (e.g.,
% inputFileName_dates) or cells (e.g., inputFileName)
% The rest should be kept as strings
if evaluate == 1
    try
        evalc(['res =' res ';']);
    catch
    end
end
return;
