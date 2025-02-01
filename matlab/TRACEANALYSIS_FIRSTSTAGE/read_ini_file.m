function trace_str_out = read_ini_file(fid,yearIn,fromRootIniFile)
% This function creates an array of structures based on the parameters in the
% initialization file.  This structure is used throughout the rest of the
% program.
% Input:
%           'fid'           -   this is the file id number associated with the
%                               initialization file now open for reading.
%           'yearIn'        -   this is the year to be added to the year-independent
%                               initialization file being read
%           fromRootIniFile -   this is a structure that only exists if this function
%                               is called recursively and it's used to pass these
%                               variables between the two ini files:
%                               fromRootIniFile.Site_name
%                               fromRootIniFile.SiteID
%                               fromRootIniFile.Difference_GMT_to_local_time
% Ouput:
%           'trace_str_out' -   This is the array of structures representing all
%						        the information for each trace in the initialization file.
%						        Each field of the traces structure MUST be added here ... see
%						        bellow for the places to enter new trace structure fields.
%                               Note that new fields MUST be added in two distinct places within
%                               the function, again see bellow

%
% Basic functionality:
%	Read each line of the initialization file.  Then, for each [TRACE]->[END] block
%	create a stucture and add the fields listed.  Each of these structure is then
%   added to an array of structures and returned in 'trace_str_out'.

%-------------------------------------------------------------------------------------
% Setup Trace Structure trace_str_default, contains all the fields that
%   are used in the trace structure, note that any changes to trace_str
%   need to be refelected bellow where trace_str is defined for each itteration

% Revisions
%
% Jan 10, 2024 (Zoran)
%   - Bug fix: Disabled the property globalVars.Instrument.otherTraces
%     It caused too many issues by overwriting properties of all traces that
%     had their instrumentType == ''. Too many unintended consequences to keep track of. Better to just 
%     disable it.
% Dec 19, 2024 (Zoran)
%   - bug fix: the program was not properly overwriting globalVars.traceName.Evaluate fields.
% Sep 13, 2024 (Zoran)
%   - Added more error reporting
% Sep 2, 2024 (Zoran)
%   - Improved error reporting. The function now shows which ini file
%     has an error in it.
%   - Error messages are now in red color
% Aug 14, 2024 (Zoran)
%   - Saved globalVars.other under the field .ini.globalVars.other. That way the globalVars can be used in
%     other parts of the program if needed. One example would be globalVars.other.singlePointInterpolation = 'on'.
% June 7/8, 2024 (Zoran)
%   - Removed the warning message saying that the first stage ini file should be second stage.
%     This warning/error was introduced when "Evaluate" option was added to the first stage.
%   - Set the search path for include files to be 1-current folder, 2-fullpath, 3-TraceAnalisys_ini,
%           4-TraceAnalisys_ini\siteID 
%     The idea is that the global include files like EC_FirstStage_include.ini will be in 3.
%   - Added some code in an attempt to enable using #include with the second stage files but
%     that needs more work. Currently #include in 2nd stage does not work!
% June 5, 2024 (Zoran)
%   - Bug fix: the function would not work with the ini files that didn't have 
%     the new variable "globalVars" defined. The program now tests the existance of the variable
%     before trying to use it.
% June 3, 2024 (Zoran)
%   - changed naming of global variables. Introduced globalVars.Instrument and globalVars.Trace. 
%     having a prefix "globalVars" made it easier to create dynamically any instruments that are
%     needed. The original version had the instruments hard coded (LI7200, LI7700, Anemometer, EC).
%     Not anymore.
%   - introduced parameter Timezone. For PST the Timezone == 8. 
%       if Timezone == 0 then the database is in UTC/GMT 
%       if Timezone == Difference_GMT_to_local_time then the database is in local standard time.
%     To keep legacy software working, the default Timezone==0 (UTC).
% May 24, 2024 (Zoran)
%   - Made sure that both SecondStage.ini and ThirdStage.ini assign: iniFileType = 'second';
%     otherwise bad things happen.
% May 10, 2024 (Zoran)
%   - Bug fix. Used exists() instead of exist() when looking for a template ini file.
%   - Bug fix related to Matlab 2024a. Matlab 2024a gave a warning about this being an error in
%     future releases.
%     Needed to replace:
%       curr_line(1:posEq-1...
%     with:
%       curr_line(1:posEq(1)-1...
% Apr 29, 2024 (Zoran)
%   - added the ini file stage to the "Reading ini file" message.
% Apr 27, 2024 (Zoran)
%   - Fixed a bug in the stage detection (iniFileType). Previously the program would not
%     properly detect the stage (first, second) if the siteID had an "_" in the name.
% Apr 9, 2024 (Zoran)
%   - added processing of global instrument-specific and trace-specific variables used
%     for overwriting the default parameters from the templates used with #include.
% Apr 7, 2024 (Zoran)
%   - syntax fixing and updating. reformatting text.
%   - Introduced #include statement that lets ini files include other standard ini files
%     to minimize the site-specific edits.
%   - Did a workaround for an interesting Matlab bug. This line would
%     not "shortcircuit" if the first condition is true (and it's supposed to)
%       if isempty(sngle_qt) | (sngle_qt(1) > comment_ln(1)) | (sngle_qt(2) < comment_ln(1))
%     If you check the same condition using || instead of | the line works the way it should.
%     If there is a good reason for this, I don't get it.
% Mar 4, 2024 (Zoran, June)
%   - Removed minMax from the required parameters for all stages. It's now
%     required for the first stage only.
% May 10, 2023 (Zoran)
%  - Fixed a bug with the dates selection when weeding out obsolete traces
%    (inputFileName_dates)
% Feb 11, 2023 (Zoran)
%  - added testing of the trace_str_out to weed out all the traces that do
%    not belong to the current year (do not belong to the range:
%    inputFileName_dates)
%  - added detecting the ini name and printing it
%

% If the year is missing then set it to empty
arg_default('yearIn',[])
% If this is not a recursive call to this function the set this parameter to []
arg_default('fromRootIniFile',[])

% Check if this is a recursive call
if isempty(fromRootIniFile)
    flagRecursiveCall = false;
else
    flagRecursiveCall = true;
    % load globalVars if they exist.
    if isfield(fromRootIniFile,'globalVars')
        globalVars = fromRootIniFile.globalVars;
    end    
end

% Legacy issue. The old ini files didn't have Timezone parameter and it was assumed that
% data base is always kept in GMT/UTC. So, just in case, set Timezone to 0.
% All the new ini files will have this parameters included so this value will
% be overwriten
Timezone = 0;

iniFileName = char(arrayfun(@fopen, fid, 'UniformOutput', 0));
% Extract the ini file type ('first','second','third')
[iniFilePath,iniFileType,~] = fileparts(iniFileName);
[~,iniFileType,~] = fileparts(iniFileType);
if endsWith(iniFileType,'FirstStage','ignorecase',true) || endsWith(iniFileType,'FirstStage_include','IgnoreCase',true)
    iniFileType = 'first';
elseif endsWith(iniFileType,'SecondStage','ignorecase',true)|| endsWith(iniFileType,'SecondStage_include','IgnoreCase',true)
    iniFileType = 'second';  
elseif endsWith(iniFileType,'ThirdStage','ignorecase',true)|| endsWith(iniFileType,'ThirdStage_include','IgnoreCase',true)
    % 'second' is NOT a bug. Let it be.
    iniFileType = 'second';    
end

if ~flagRecursiveCall
    fprintf('Reading %s stage ini file: \n   %s \n',iniFileType, iniFileName);
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
countLines = 1;
tm_line = 'There were no lines read!';  % this is the default in case fgetl below fails.
try
    % Set some locally used variables
    tm_line=fgetl(fid);
    while ischar(tm_line)
        temp_var = '';
        tm_line = strtrim(tm_line);             % remove leading and trailing whitespace chars
        temp = find(tm_line~=32 & tm_line~=9);  %skip white space outside [TRACE]->[END] blocks
        if isempty(temp) | strcmp(tm_line(temp(1)),'%')
            % if tm_line is empty or a comment line, do nothing
        elseif startsWith(tm_line,'#include ','IgnoreCase',1)
            % this is an #include statement. Load the new ini file.
            % First check if the include file is either in the current Matlab folder
            % or given with a full path.
            includeFileName = tm_line(10:end);
            if exist(includeFileName,'file')
                fidInclude = fopen(includeFileName,'r');
                if fidInclude < 1
                    error('Could not open #include file: %s. Line: %d',includeFileName,countLines);
                end
            else
                % 
                % Then assume that the include file is in directly under TraceAnalysis_ini folder
                % and it's common for all sites
                indSep = find(iniFilePath==filesep);
                if indSep(end) == length(iniFilePath)
                    % There is an extra filesep at the end of the path. Remove
                    iniFilePath = iniFilePath(1:end-1);
                    newPath = iniFilePath(1:indSep(end-1)-1);
                else
                    newPath = iniFilePath(1:indSep(end)-1);
                end
                if exist(fullfile(newPath,includeFileName),'file')
                    fidInclude = fopen(fullfile(newPath,includeFileName),'r');
                    if fidInclude < 1
                        error('Could not open #include file: %s. Line: %d',includeFileName,countLines);
                    end
                else
                    % If the full file path is not given
                    % maybe the file name does not give the full path. Use the same path as for the current ini file
                    if exist(fullfile(iniFilePath,includeFileName),'file')
                        fidInclude = fopen(fullfile(iniFilePath,includeFileName),'r');
                        if fidInclude < 1
                            error('Could not open #include file: %s. Line: %d',includeFileName,countLines);
                        end
                    else
                        error('The #include file: %s does not exist. Line: %d',includeFileName,countLines);
                    end
                end                

            end
            % Call this function recursively to extract the new traces
            % but first the variables below will need to be passed to the function
            fromRootIniFile.Site_name               = Site_name;
            fromRootIniFile.SiteID                  = SiteID;
            if strcmpi(iniFileType,'first')
                % Only load these if doing the first stage ini file
                fromRootIniFile.Diff_GMT_to_local_time  = Difference_GMT_to_local_time;
                fromRootIniFile.Timezone                = Timezone;
                if exist('globalVars','var')
                    fromRootIniFile.globalVars              = globalVars;
                end
            end
            fprintf('   Reading included file: %s. \n',fopen(fidInclude));
            trace_str_inlude = read_ini_file(fidInclude,yearIn,fromRootIniFile);
            for cntIncludeTraces = 1:length(trace_str_inlude)
                countTraces = countTraces+1;
                trace_str(countTraces) = trace_str_inlude(cntIncludeTraces);
            end
        elseif strncmp(tm_line,'[Trace]',7)
            %------------------------------------locate each [TRACE]->[END] block in ini_file
            % save the line # for error reporting
            traceFieldLineNum = countLines;
            %update which trace this is(used only for error messages):
            countTraces = countTraces+1;
            %Read the first line inside the [TRACE]->[END] block:
            tm_line = fgetl(fid);
            countLines = countLines + 1;
            eval_cnt = 0;
            while ~strncmp(tm_line,'[End]',5)
                %Until the [END] block is found, read each line and add the assigned variables
                %to a temporary structure that will be added to the array of all structures:
                curr_line = tm_line;
                %initial indices of spaces and comments:
                temp_cm = [];
                if ~isempty(curr_line)
                    %ignore white space characters by locating first and last non-white space:
                    temp_sp = find(curr_line~=32 & curr_line~=9);
                    if ~isempty(temp_sp)
                        curr_line = curr_line(temp_sp(1):temp_sp(end));
                    else
                        curr_line = '';
                    end
                    %Find the indices of comment signs:
                    if ~isempty(curr_line)
                        temp_cm = find(curr_line == '%');
                    end
                end
                if ~isempty(curr_line)
                    %Find all single quotes on the current line:
                    qt = find(curr_line == 39); % all quotes
                    % Only quotes that are not follwed by another quote are single
                    % quotes:
                    if ~isempty(qt)
                        dble_qt = find(diff(qt) == 1);
                        sngle_qt = setdiff(qt,[qt(dble_qt) qt(dble_qt+1)]);
                    else
                        sngle_qt = [];
                    end

                    if length(sngle_qt) == 1 & (isempty(temp_cm) | sngle_qt < temp_cm(1))
                        %A single quote is found, which is not within a comment string.
                        %Either an error, OR variable assignment extends over multiple lines.
                        %Get the next lines until either the last quote is found or
                        %a '=' sign is found.(in this case the single quote is an error):
                        eqlind = find(curr_line == '=');
                        %Added February 6, 2006 (dgg)
                        %A bug in code was preventing normal behavior of this function
                        %!!!!Temporary fix!!!!:
                        eqlindTMP = find(curr_line == '=');
                        %Get the string after the '=' sign.
                        mkstr = curr_line(eqlind(1)+1:end);
                        if ~isempty(eqlind)
                            fin_str = '';			%initial final string is empty
                            last_sngl_qt = 0;		%flag indicating when last single quote is found
                            while last_sngl_qt == 0
                                %get indices of comment and equal signs:
                                comnt = find(mkstr == '%');
                                eqlind = find(mkstr == '=');
                                %if an equal sign comes before the closing single quote then an
                                %error has occured(unless the line is an "Evaluate" keyword):
                                %Added February 6, 2006 (dgg)
                                %A bug in code was preventing normal behavior of this function
                                %!!!!Temporary fix!!!!:
                                %                     if ~isempty(eqlind) & isempty(findstr(curr_line(1:eqlind(1)),'Evaluate'))
                                if ~isempty(eqlind) & ~contains(curr_line(1:eqlindTMP(1)),'Evaluate')
                                    if isempty(comnt) | (eqlind(1) < comnt(1))
                                        disp(['Missing variable assignment in trace #' num2str(countTraces) ' on line number: ' num2str(countLines-1) '!']);
                                        trace_str_out='';
                                        return
                                    end
                                    %Continue if no equal sign before a comment
                                end
                                %get rid of the comments if they exist:
                                if ~isempty(comnt)
                                    mkstr = mkstr(1:comnt(1)-1);
                                end
                                %get rid of surrounding white space:
                                indchrs = find(mkstr~=32 & mkstr~=9);
                                if length(indchrs)>1
                                    mkstr = mkstr(indchrs(1):indchrs(end));
                                end
                                %Avoid having multiple commas(although this is caught further on):
                                if length(mkstr)>1 & mkstr(1) == ','
                                    mkstr = mkstr(2:end);
                                end
                                %append to the final string:
                                fin_str = [fin_str mkstr];
                                %if the last quote is found exit while loop:

                                if fin_str(end) == 39 || contains(fin_str,'[End]')
                                    last_sngl_qt = 1;
                                else
                                    %make sure commas separate each line added:
                                    if ~isempty(mkstr) & fin_str(end)~=','
                                        fin_str = [fin_str ','];
                                    end
                                    %get next line and continue while loop:
                                    mkstr = fgetl(fid);
                                    countLines = countLines + 1;
                                end
                            end
                            %exit the while loop and reset the current line to include all strings
                            %extending over multiples lines:
                            eqlind = find(curr_line == '=');
                            %update the curr_line variable assignment with the full string:
                            if ~isempty(eqlind)
                                curr_line = [curr_line(1:eqlind(1)) fin_str];
                            else
                                disp(['Missing variable assignment in trace #' num2str(countTraces) ' on line number: ' num2str(countLines)  '!']);
                                trace_str_out='';
                                return
                            end
                        else
                            %there is no '=' sign which is not allowed
                            disp(['Missing equal sign ''='' in trace #' num2str(countTraces) ' on line number: ' num2str(countLines)  '!']);
                            trace_str_out='';
                            return
                        end
                    else
                        %in the case of zero or double quotes, evaluate the string as listed
                        %in the intialization file without comments(if present):
                        if ~isempty(temp_cm)
                            if temp_cm(1)==1
                                curr_line = '';
                            elseif isempty(sngle_qt)
                                curr_line = curr_line(1:temp_cm(1)-1);
                            elseif (sngle_qt(1) > temp_cm(1)) || (sngle_qt(2) < temp_cm(1))
                                curr_line = curr_line(1:temp_cm(1)-1);
                            elseif (sngle_qt(1) < temp_cm(1)) || (sngle_qt(2) > temp_cm(1))
                                curr_line = curr_line(1:sngle_qt(2));
                            end
                        end
                    end

                    if ~isempty(curr_line)
                        %User 'eval' to add the variable assignment listed in curr_line
                        %to the temporary structure:
                        try
                            if strncmp(curr_line, 'Evaluate',8)
                                eval_cnt = eval_cnt + 1;
                                curr_line = ['Evaluate' num2str(eval_cnt) curr_line(9:end)];
                                curr_line = curr_line(curr_line~=32 & curr_line~=9);
                            end
                            posEq = strfind(curr_line,'=');                         % Find where "=" is
                            newFieldName = strtrim(curr_line(1:posEq(1)-1));
                            temp_var.(newFieldName) = eval(curr_line(posEq(1)+1:end)); % assign the value
                            %eval(['temp_var.' curr_line ';']);
                        catch ME
                            %Any error's are caught in the try-catch block:
                            fprintf(2,'Error in trace #%d on line number: %d!\n', countTraces,countLines);
                            fprintf(2,'In file: %s\n',iniFileName)
                            disp(ME);
                            trace_str_out='';
                            return
                        end
                    end
                end
                %Get next line:
                tm_line = fgetl(fid);
                countLines = countLines + 1;
            end

            %Test for required fields that the initialization file must have.
            curr_fields = fieldnames(temp_var);												%get current fields
            chck_common = ismember(required_common_ini_fields,curr_fields);				    %check to see if the fields that are common to both stages are present
            chck_first_stage = ismember(required_first_stage_ini_fields,curr_fields);		%check to see if the fields that are common to both stages are present
            chck_second_stage = ismember(required_second_stage_ini_fields,curr_fields);		%check to see if the fields that are common to both stages are present

            if all(chck_common)
                if all(chck_first_stage)
                    if strcmp(iniFileType,'first')
                        stage = 'first';
                        trace_str(countTraces).stage = 'first';
                    else
                        error('Ini file is for the stage: %s but the stage: %s is detected based on the required field names. Line: %d',iniFileType,stage,countLines);
                    end
                end
                if all(chck_second_stage)
                    if strcmp(iniFileType,'second')
                        stage = 'second';
                        trace_str(countTraces).stage = 'second';
                    else
                        %fprintf('*Warning: Ini file is for the stage: *%s* but the *second* stage is detected based on the required field names. Line: %d\n',iniFileType,countLines);
                        %error('');
                    end
                end
            else
                fprintf(2,'Error in ini file, common required field(s) do not exist. Line: %d\n',countLines);
                trace_str_out = '';
                return
            end

            %Update the current trace with ini_file information listed outside the
            %[TRACE]->[END] blocks:

            % If this is call to the function is reading an included ini file (#include statement)
            % then the following variables need to be passed from the main ini file down.
            % if fromRootIniFile is not empty load up the variables
            if ~isempty(fromRootIniFile)
                Site_name                       = fromRootIniFile.Site_name;
                SiteID                          = fromRootIniFile.SiteID;
                if strcmpi(iniFileType,'first')
                    % Only load these two if doing the first stage ini file
                    Difference_GMT_to_local_time    = fromRootIniFile.Diff_GMT_to_local_time;
                    Timezone                        = fromRootIniFile.Timezone;
                end
            end
            %**** Trace structure defined for each itteration of the array ******
            trace_str(countTraces).Error = 0;
            trace_str(countTraces).Site_name = Site_name;
            trace_str(countTraces).variableName = temp_var.variableName;
            trace_str(countTraces).ini = temp_var;
            trace_str(countTraces).SiteID = SiteID;
            trace_str(countTraces).Year = yearIn;
            trace_str(countTraces).Diff_GMT_to_local_time = '';
            trace_str(countTraces).Last_Updated = '';
            trace_str(countTraces).data = [];
            trace_str(countTraces).DOY = [];
            trace_str(countTraces).timeVector = [];
            trace_str(countTraces).data_old = [];

            trace_str(countTraces).stats = [];
            trace_str(countTraces).runFilter_stats = [];
            trace_str(countTraces).pts_restored = [];
            trace_str(countTraces).pts_removed = [];

            switch trace_str(countTraces).stage
                case 'first'
                    trace_str(countTraces).Diff_GMT_to_local_time = Difference_GMT_to_local_time;
                    trace_str(countTraces).Timezone = Timezone;
                    trace_str(countTraces).Last_Updated = char(datetime("now"));

                case 'second'
                    % kai* 14 Dec, 2000
                    % inserted the measurement_type field to facilitate easier output
                    % end kai*

                    trace_str(countTraces).ini.measurementType = 'high_level';
                    trace_str(countTraces).searchPath = searchPath;

                    if ~isempty(input_path) & input_path(end) ~= '\'
                        input_path = [input_path filesep];
                    end
                    if ~isempty(output_path) & output_path(end) ~= '\'
                        output_path = [output_path filesep];
                    end

                    %Elyn 08.11.01 - added year-independent path name option
                    ind_year = strfind(lower(input_path),'yyyy');
                    if isempty(ind_year) & length(ind_year) > 1
                        error 'Year-independent paths require a wildcard: yyyy!'
                    end
                    if ~isempty(ind_year) & length(ind_year) == 1
                        input_path(ind_year:ind_year+3) = num2str(yearIn);
                    end

                    trace_str(countTraces).input_path = input_path;
                    trace_str(countTraces).output_path = output_path;
                    trace_str(countTraces).high_level_path = high_level_path;
                    trace_str(countTraces).Last_Updated = char(datetime("now"));
            end
            %---------------Finished reading the trace information between [TRACE]->[END] block
            
            % At this point a new trace_str(countTraces) is fully created. This could be a trace with 
            % a same name as a previously created trace. This could be a mistake (a duplicate trace)
            % or one could be doing it on purpose with a goal of overwriting a trace defined.
            % Let's check:
            %

            % Get the Overwrite status for the trace. If it doesn't exist set it to 0 - can be overwritten                        
            if isfield(trace_str(countTraces),'Overwrite') & ~isempty(trace_str(countTraces).Overwrite)
                flagOverwriteNew = trace_str(countTraces).Overwrite;
            else
                flagOverwriteNew = 0;
            end  
            if ~ismember(flagOverwriteNew,[0 1])
                % flag can have only two possible values [0 1])
                error('      Overwrite property value can be only [0 1]. Trace: %s has Overwrite = %d\n',trace_str(countTraces).variableName,flagOverwriteNew);
            end
            trace_str(countTraces).Overwrite = flagOverwriteNew;
        elseif isletter(tm_line(1))
            %read other variables in the ini_file not between [TRACE]->[END] blocks:
            %These variable need to begin with a character:
            sngle_qt = find(tm_line == 39);				%indices of single quotes
            comment_ln = find(tm_line == '%');			%indices of comments
            if ~isempty(comment_ln)
                %if comments exist, check where the single quotes are:
                if isempty(sngle_qt) || (sngle_qt(1) > comment_ln(1)) ||...
                        (sngle_qt(2) < comment_ln(1))
                    tm_line = tm_line(1:comment_ln(1)-1);
                end
            end
            if contains(tm_line,'searchPath')
                tm_line = tm_line(tm_line~=32 & tm_line~=9);
            end
            %Evaluate the current variable assingment into the current workspace:
            eval([tm_line ';'])		%(siteID,site_name, etc).
        end
        tm_line = fgetl(fid);		%get next line of ini_file
        countLines = countLines + 1;
    end
catch ME
    fprintf(2,'Error while processing: \n%s\n on line:\n     %d:  (%s)\nExiting read_ini_file() ...\n\n\n',iniFileName,countLines,tm_line);
    rethrow(ME);
end

%--------------------- Global variables -------------------------------------
% The ini file could have a set of global variables that are used
% to populate (and overwrite if needed) the existing Trace definitions
% that belong to large groups of traces:
% instrumentTypes: LI7200, LI7700, Anemometer, EC

% Global variables will be processed only in the main body of the ini file, 
% skip if this is a recursive call.
if ~flagRecursiveCall   
    for cntTrace = 1:length(trace_str)
        % go one trace at the time and see if anything needs to be overwritten
        if isfield(trace_str(cntTrace).ini,'instrumentType') && ~isempty(trace_str(cntTrace).ini.instrumentType)
            instrumentType = trace_str(cntTrace).ini.instrumentType;
            % Proces global variable if enabled
            if isfield(globalVars.Instrument.(instrumentType),'Enable') && globalVars.Instrument.(instrumentType).Enable == 1
                fNames = fieldnames(globalVars.Instrument.(instrumentType));
                for cntFields = 1:length(fNames)
                    curName = char(fNames(cntFields));
                    if ~strcmpi(curName,'Enable')
                        trace_str(cntTrace).ini.(curName) = globalVars.Instrument.(instrumentType).(curName);
                    end
                end
            end
        else
            % Process all defaults (instrumentType ='') using otherTraces variables    
            if exist('globalVars','var') && isfield(globalVars,'Instrument') && isfield(globalVars.Instrument,'otherTraces') ...
               && isfield(globalVars.Instrument.otherTraces,'Enable') && globalVars.Instrument.otherTraces.Enable == 1
                % The property otherTraces caused too many issues by overwriting properties of all traces that
                % had their instrumentType == ''. Too many unintended consequences to keep track of. Better to just 
                % cancel it. Zoran 20250110
                fprintf(2,'Property globalVars.Instrument.otherTraces.Enable = 1 is not supported anymore. Please set to 0 or remove.\n');
                if 1==2
                    % keeping it here for the future reference. It will never be used.
                    fNames = fieldnames(globalVars.Instrument.otherTraces);
                    for cntFields = 1:length(fNames)
                        curName = char(fNames(cntFields));
                        if ~strcmpi(curName,'Enable')
                            trace_str(cntTrace).ini.(curName) = globalVars.Instrument.otherTraces.(curName);
                        end
                    end                    
                end
            end
        end
        % if globalVars.other exist, store them under the ini.globalVars.other field
        if exist('globalVars','var') && isfield(globalVars,'other')
            trace_str(cntTrace).ini.globalVars.other = globalVars.other;
        end
    end
    
    %--------------------- Trace variables -------------------------------------
    % The ini file could have a set of global variables that are used
    % to populate (and overwrite if needed) the existing Trace definitions
    % for individual traces
    if exist('globalVars','var') && isfield(globalVars,'Trace')
        % Find all traces that need to be overwritten
        tracesToOverwrite = fieldnames(globalVars.Trace);
        for cntTrace = 1:length(trace_str)
            % go one trace at the time and see if anything needs to be overwritten
            variableName = trace_str(cntTrace).variableName;
            indTrace = ismember(tracesToOverwrite,variableName);
            if any(indTrace)
                allFieldsToOverwrite = fieldnames(globalVars.Trace.(variableName));
                for cntOverwrite = 1:length(allFieldsToOverwrite)
                    fieldToOverwrite = char(allFieldsToOverwrite(cntOverwrite));
                    if strcmpi(fieldToOverwrite,'Evaluate')
                        % special handling is required when overwriting Evaluate field
                        % Multiple instances of Evaluate fields are possible (Evaluate1, Evaluate2...)
                        % so the first step is erase all fields that start with Evaluate
                        % NOTE: due to how the globalVars work, the new 'Evaluate' field
                        %       will only have one valid 'Evaluate' field. 
                        
                        % Erase all existing 'Evaluate' fields 
                        allTraceFields = fieldnames(trace_str(cntTrace).ini);
                        for cntErase = 1:length(allTraceFields)
                            currentField = char(allTraceFields(cntErase));
                            if startsWith(currentField,'Evaluate','IgnoreCase',true)
                                trace_str(cntTrace).ini = rmfield(trace_str(cntTrace).ini,currentField);
                            end
                        end
                        % rename 'Evaluate' to 'Evaluate1' to stay compatible with the naming convention                        
                        newName = sprintf('%s%d',fieldToOverwrite,1);
                        trace_str(cntTrace).ini.(newName) = globalVars.Trace.(variableName).(fieldToOverwrite);
                    else
                        trace_str(cntTrace).ini.(fieldToOverwrite) = globalVars.Trace.(variableName).(fieldToOverwrite);
                    end
                end
            end
        end
    end
end
%-------------------- remove traces not used in the current year ---------------
% Before exporting the list of traces, go through inputFileName_dates for
% each trace (if it exists) and remove the traces that fall outside of the
% given range. That will insure that only the traces that were present
% in this Year are left in trace_str_out. (added Feb 11, 2023, Zoran)

cntGoodTrace = 0;
strYearDate = datenum(yearIn,1,1,0,30,0);
endYearDate = datenum(yearIn+1,1,1,0,0,0);
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
if ~flagRecursiveCall
    % Deal with duplicate traces. Sometimes the duplicates are made in error.
    % Sometimes we want the duplicate trace to overwrite an existing trace
    % (Example: siteID_FirstStage.ini [Trace] overwritting a global #include ini file)

    % Loop through all traces
    trace_str_unique = struct([]);
    allTraceNames = {trace_str_out(:).variableName};
    uniqueTraceNames = unique(allTraceNames,'stable');
    for cntTraces = 1:length(uniqueTraceNames)
        % First find out if the trace is unique. Need at least two traces.
        currentTrace = char(uniqueTraceNames(cntTraces));
        indDuplicate = find(ismember(allTraceNames,currentTrace));
        if length(indDuplicate) > 1
            % if a duplicate exists, check if the new copy has the property "Overwrite = 1"
            % new Overwrite had to be > old Overwrite. If not, report an error, 
            % suggest using "Overwrite = 1" and then ignore the new copy.
    
            % get Overwrite status of the original trace. 
            flagOverwriteOld = trace_str_out(indDuplicate(1)).Overwrite;

            % Now loop through all duplicates
            for cntDuplicates = 2:length(indDuplicate)
                % get Overwrite status of the duplicate trace. 
                flagOverwriteNew = trace_str_out(cntDuplicates).Overwrite;
                % test if the overwritting is allowed
                if flagOverwriteNew == 1 && flagOverwriteOld == 0
                    % All good, trace can be overwritten. Proceed
                    fprintf(1,'      Found a duplicate trace: %s \n',currentTrace);
                    fprintf(1,'        Overwritting the old trace with this one.\n');
                    trace_str_unique(cntTraces) = trace_str_out(indDuplicate(cntDuplicates));
                else       % if flagOverwriteOld >= flagOverwriteNew
                    fprintf(2,'      Found a duplicate trace: %s \n',currentTrace);
                    fprintf(2,'        The trace cannot be overwritten. flagOverwriteOld = %d, flagOverwriteNew = %d\n',flagOverwriteOld,flagOverwriteNew);
                    fprintf(2,'        flagOverwriteOld has to be smaller than flagOverwriteNew. Ignoring the duplicate.\n');                    
                    % keep the original trace
                    if cntTraces == 1
                        trace_str_unique            = trace_str_out(indDuplicate(1));
                    else
                        trace_str_unique(cntTraces) = trace_str_out(indDuplicate(1));
                    end
                end
            end
        else
            % This trace is unique. Just store it.
            if cntTraces == 1
                trace_str_unique = trace_str_out(indDuplicate);
            else
                trace_str_unique(cntTraces) = trace_str_out(indDuplicate);
            end
        end
    end
    % Now store filtered list back into the output structure
    trace_str_out = trace_str_unique;

    % Final message after finishing ini file parsing:
    fprintf('   %d traces read from the ini file. \n',length(trace_str));
    fprintf('   %d traces exist in the year %d.\n',cntGoodTrace,yearIn);
    fprintf('   %d unique trace are kept for processing\n',length(trace_str_out));
end
