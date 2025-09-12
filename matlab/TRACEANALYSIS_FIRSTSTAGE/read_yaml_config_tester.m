% A script for testing
function out = read_yaml_config_tester(SiteID,stage,yearIn,db_ini)


% ------------Nick's fix for using a local copy of the database---------------
if exist('biomet_database_default','file') == 2
    db_pth = biomet_database_default;
else
    db_pth = db_pth_root;
end
%--------------------------------------------------------------------------

arg_default('yearIn',2024)
arg_default('db_ini',db_pth);


if ~isa(SiteID,'cell')
    SiteID = {SiteID};
end
if ~isa(stage,'cell')
    stage = {stage};
end

for site = SiteID
    for current_stage = stage
        current_stage = char(current_stage);        
        
        % Open the ini file for comparison
        ini_path = fullfile(db_ini,"Calculation_Procedures","TraceAnalysis_ini",site,strcat(site,"_",current_stage,".ini"));
        tic;
        fid = fopen(ini_path,'rt');						%open text file for reading only.   
        trace_str_ini = read_ini_file(fid,yearIn);
        fclose(fid);
        ini_time = toc;
        fprintf('Read ini file in %f\n',ini_time)


        fprintf('Cleaninig and reading database using ini file in \n')
        fr_automated_cleaning(yearIn,site,current_stage)
        
        for i = 1:numel(trace_str_ini)
            if strcmp(stage,'firststage')
                subpath = fullfile(char(trace_str_ini(i).ini.measurementType),'Clean');
            else
                subpath = fullfile('Clean','SecondStage');
            end
            vname = char(trace_str_ini(i).variableName);
            if ~strcmp(vname,'clean_tv')
                [trace,clean_tv] = read_db([yearIn],char(site),subpath,vname);
                trace_str_ini(i).data = trace;
            end
        end

        yaml_path = fullfile(db_ini,"Calculation_Procedures","TraceAnalysis_ini",site,strcat(site,"_",current_stage,".yml"));

        tic;
        trace_str_yml = read_yaml_config(yaml_path,yearIn);
        yml_time = toc;
        fprintf('Read yaml file in %f\n',yml_time)


        fprintf('Cleaninig and reading database using yaml file in \n')
        fr_automated_cleaning(yearIn,site,current_stage)

        for i = 1:numel(trace_str_yml)
            if strcmp(stage,'firststage')
                subpath = fullfile(char(trace_str_yml(i).ini.measurementType),'Clean');
            else
                subpath = fullfile('Clean','SecondStage');
            end
            vname = char(trace_str_yml(i).variableName);
            if ~strcmp(vname,'clean_tv')
                [trace,clean_tv] = read_db([yearIn],char(site),subpath,vname);
                trace_str_yml(i).data = trace;
            end
        end
                
        if length(trace_str_yml) ~= length(trace_str_ini)
            fprintf("\nyml length %d vs ini_lenght %d\n",length(trace_str_yml), length(trace_str_ini))
            for i =1:length(trace_str_yml)
                if ~strcmp(trace_str_yml(i).variableName, trace_str_ini(i).variableName)
                    fprintf('\nyml #%i:%s ini #%i:%s\n',i, trace_str_yml(i).variableName,i, trace_str_ini(i).variableName)
                end
            end
            fprintf('\nTrace lengths do not match!!!\nChecking for duplicates in ini file')

            test = {};
            for i = 1:length(trace_str_ini)
                test{i} = trace_str_ini(i).variableName;
            end
            [unique_ids, ~, idx] = unique(test);
            counts = histcounts(idx, numel(unique_ids));
            
            % Find IDs that appear more than once
            duplicated_ids = unique_ids(counts > 1);
            if numel(duplicated_ids)>0
                fprintf('%d duplicates present in ini trace_str which were not handled by read_ini.m')
                duplicated_ids
                error('Consider using postEvaluate instead of repeating the trace processing?')
            end
        end
        fprintf('\n\nPerfoming comparison\n site: %s  stage: %s\n',char(site),char(current_stage))
        inicomp(trace_str_ini,trace_str_yml)
        fprintf('\n\nEnd of comparison\n')
    end
end
out = [];
out.trace_str_ini = trace_str_ini;
out.trace_str_yml = trace_str_yml;
end
function inicomp(ini_all,yml_all,message)
    arg_default('message','')
    % Order of fieldnames should not matter for comparisson
    % Only row order matters
    % Makes comparisson easier
    ini_all = orderfields(ini_all);
    ini_fields = fieldnames(ini_all);
    yml_all = orderfields(yml_all);
    yml_fields = fieldnames(yml_all);
    
    % Check fields
    if ~isequal(ini_fields,yml_fields)
        extra = ~ismember(yml_fields,ini_fields);
        % These are allowed to be missing (but are written by default from
        % yml converter)
        mute = {'instrumentType'};
        if sum(extra)>0
            tmp = yml_fields;
            for mf = tmp(find(extra))'
                if ~ismember(mf,mute)
                    fprintf('Missing in ini file: %s\n',char(mf))
                end
            end
        end
        missing = ~ismember(ini_fields,yml_fields);
        if sum(extra)>0
            tmp = ini_fields;
            for mf = tmp(find(missing))'
                fprintf('Missing in yml file: %s\n',char(mf))
            end
        end
    end
    % Check number of elements
    if ~isequal(length(ini_all),length(yml_all))
        fprintf('Different number of elements')
        keyboard
    end
    % Theses are allowed/expected to be different
    % The yaml parser will take the values explicityl defined
    % Except for "Overwrite" which will defualt to 1 for includes 
    % (as should be the intention of an include)
    mute = {'iniFileLineNum','iniFileName','Last_Updated','instrumentType','Overwrite'};
    for i = 1:numel(ini_all)
        for f = ini_fields'
            fn = char(f);
            if strcmp(fn,'data')
                if isequaln(ini_all(i).data,yml_all(i).data)
                    fprintf('Data traces are equal for: %s\n',yml_all(i).variableName)
                else
                    fprintf('Data traces are NOT equal for: %s\n',yml_all(i).variableName)
                end
            elseif ~isequal(ini_all(i).(fn),yml_all(i).(fn)) & ~ismember({fn},mute)
                if ismember({'iniFileLineNum'},ini_fields)
                    message = sprintf('\n\n%s are not equal:\n\nDiscrepancy in trace %s\nStarts online: %d in file\n%s\n', ...
                        fn,ini_all(i).variableName,ini_all(i).iniFileLineNum,ini_all(i).iniFileName);
                end
                if isa(ini_all(i).(fn),'struct')
                    inicomp(ini_all(i).(fn),yml_all(i).(fn),message)
                else
                    % Ignore discrepancy if yml is a double array and ini
                    % is a char array of datenums yet to be evaluated
                    if isa(ini_all(i).(fn),"char") & contains(ini_all(i).(fn),'datenum') & isequal(yml_all(i).(fn),eval(ini_all(i).(fn)))
                        message = '';
                    else
                        fprintf('%s',message)
                        message = '';
                        fprintf('Fieldname: %s\n',fn)
                        fprintf('ini = %s\n',strjoin(string(ini_all(i).(fn)),' '))
                        fprintf('yml = %s\n',strjoin(string(yml_all(i).(fn)),' '))
                    end
                end
            end
        end
    end
end

