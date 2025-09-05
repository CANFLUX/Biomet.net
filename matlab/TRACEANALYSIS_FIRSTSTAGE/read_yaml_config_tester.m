

% A script for testing
SiteID = 'BB';
stage = 'secondstage';
% stage = 'firststage';
root = "C:\Database\Calculation_Procedures\TraceAnalysis_ini\";
ini_path = strcat(root,SiteID,"\",SiteID,"_",stage,".ini");


% Open the ini file for comparison
fid = fopen(ini_path,'rt');						%open text file for reading only.   
trace_str_ini = read_ini_file(fid,year(datetime()));
fclose(fid);

yaml_path = strcat(root,SiteID,"\",SiteID,"_",stage,".yml");
if exist(yaml_path, 'file')
    % Since the old method only provides a fid ....

    % fid = fopen(yaml_path,'rt');
    trace_str_yml = read_yaml_config(yaml_path,year(datetime()));
    % fclose(fid);
end

if length(trace_str_yml) ~= length(trace_str_ini)
    fprintf("yml length %d vs ini_lenght %d",length(trace_str_yml), length(trace_str_ini))
    error('Trace lengths do not match!!!')
end
inicomp(trace_str_ini,trace_str_yml)

function inicomp(inm,ynm)
    inm = orderfields(inm);
    ynm = orderfields(ynm);
    if isequal(fieldnames(inm),fieldnames(ynm))
        fprintf('Fieldnames are equal\n')
    end
    for fn = fieldnames(inm)'
        fn = char(fn);
        if ~isfield(ynm,fn)
            fprintf('\n\n%s is missing in the yaml ini\n\n',fn)
            continue
        end
        itmp = inm.(fn);
        ytmp = ynm.(fn);
        if isequal(itmp,ytmp)
            fprintf('%s are equal\n',fn)
            continue
        elseif ~isequal(class(itmp),class(ytmp))
            fn
            class(itmp),class(ytmp)
            keyboard
            error('Classes do not match')
        elseif isa(itmp,'char')
            fprintf('\n\n%s are not equal\nini= %s\nyml= %s\n\n',fn,itmp,ytmp)
            continue
        elseif isa(itmp,'double')
            fprintf('\n\n%s are not equal\nini= %d\nyml= %d\n\n',fn,itmp,ytmp)
            continue
        elseif isa(itmp,'struct')
            fprintf('\n\n%s are not equal, digging deeper\n\n~~~~~~~~~~~~~~`',fn)
            for i = 1:length(inm)
                try
                    fprintf('Testing %s',char(inm(i).variableName))
                catch
                    fprintf('Unexpected recursion?')
                    keyboard
                end
                inicomp(inm(i).(fn),ynm(i).(fn))
            end
            fprintf('\n\nend summary of %s\n\n~~~~~~~~~~~~~~~~\n\n',fn)
            continue
        end
        keyboard
        error('Something?')
    end
end

