% A test
ini_path = "C:\Database\Calculation_Procedures\TraceAnalysis_ini\SCL\SCL_FirstStage.ini"
yaml_path = "C:\Database\Calculation_Procedures\TraceAnalysis_ini\SCL\SCL_FirstStage.yml"


Site_name = 'ECCC'
fid = fopen(ini_path,'rt');						%open text file for reading only.   
trace_str_ini = read_ini_file(fid,2024);
fclose(fid);
trace_str_ini


fid = fopen(yaml_path,'rt')


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

f = yaml.loadFile(yaml_path);
f
trace_str_yml = [];