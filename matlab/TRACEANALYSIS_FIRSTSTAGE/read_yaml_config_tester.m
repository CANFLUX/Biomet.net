% A script for testing
SiteID = 'BB'
stage = 'firststage'
root = "C:\Database\Calculation_Procedures\TraceAnalysis_ini\"
ini_path = strcat(root,SiteID,"\",SiteID,"_",stage,".ini")

% Open the ini file for comparison
fid = fopen(ini_path,'rt');						%open text file for reading only.   
trace_str_ini = read_ini_file(fid,2024);
fclose(fid);

yaml_path = strcat(root,SiteID,"\",SiteID,"_",stage,".yml")
if exist(yaml_path, 'file')
    % Since the old method only provides a fid ....
    fid = fopen(yaml_path,'rt');
    trace_str_yml = read_yaml_config(fid)
    fclose(fid);
end

