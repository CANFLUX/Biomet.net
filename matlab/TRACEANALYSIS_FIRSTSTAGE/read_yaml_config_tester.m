% A script for testing
function out = read_yaml_config_tester(dbRoot,SiteID,stage)

if ~isa(SiteID,'cell')
    SiteID = {SiteID}
end
if ~isa(stage,'cell')
    stage = {stage}
end

for site = SiteID
    for current_stage = stage
        current_stage = char(current_stage);
        
        
        % Open the ini file for comparison
        tic;
        ini_path = strcat(dbRoot,site,"\",site,"_",current_stage,".ini");
        fid = fopen(ini_path,'rt');						%open text file for reading only.   
        trace_str_ini = read_ini_file(fid,year(datetime()));
        fclose(fid);
        ini_time = toc;
        fprintf('Read ini file in %f\n',ini_time)


        yaml_path = strcat(dbRoot,site,"\",site,"_",current_stage,".yml");
        tic;
        trace_str_yml = read_yaml_config(yaml_path,year(datetime()));
        yml_time = toc;
        fprintf('Read yaml file in %f\n',yml_time)
                
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
out = [trace_str_ini,trace_str_yml];
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
            if ~isequal(ini_all(i).(fn),yml_all(i).(fn)) & ~ismember({fn},mute)
                if ismember({'iniFileLineNum'},ini_fields)
                    message = sprintf('\n\n%s are not equal:\n\nDiscrepancy in trace %s\nStarts online: %d in file\n%s\n', ...
                        fn,ini_all(i).variableName,ini_all(i).iniFileLineNum,ini_all(i).iniFileName);
                end
                if isa(ini_all(i).(fn),'struct')
                    inicomp(ini_all(i).(fn),yml_all(i).(fn),message)
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

