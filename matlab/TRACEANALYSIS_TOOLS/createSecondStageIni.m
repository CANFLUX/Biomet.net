function createSecondStageIni(siteID,outputPath)
% Create the second stage ini defaults for the given site database 
% Mainly used for "pass-through" second stage where the database 
% is going to be created based on some already "clean" data set
% like ICOS or Ameriflux data. In such cases the idea is that all (or most of) the
% traces from the database 1st stage will just go straight to the 2nd stage.
%
% For the given siteID, the function searches through all traces
% and creates skeleton [Trace]...[End] for each database 1st stage trace. 
% User can then edit the file manually.
%
% The output ini file will be stored as outputPath/Site_ID_SecondStage_Template.ini. 
% If the outputPath is [] the file is saved in the current folder.
%
%
% Zoran Nesic               File created:           Feb 21, 2025
%                           Last modification:      Feb 21, 2025

% Revisions:

% default otput is the current folder
arg_default('outputPath',pwd)

% Read the FirstStage.ini file (year should not matter for the template
trace_str = readIniFileDirect(2999,siteID,1);


outputIniFileName = fullfile(outputPath, [siteID '_SecondStage_Template.ini']);
fprintf('---------------------------\n');
fprintf('Creating template file: %s\n',outputIniFileName);
fid = fopen(outputIniFileName,'w');

% Header output
fprintf(fid,'%%\n%% File generated automatically on %s\n%%\n\n',datetime('today'));
fprintf(fid,'Site_name          = ''%s''\n',trace_str(1).Site_name);
fprintf(fid,'SiteID             = ''%s''\n',trace_str(1).SiteID);
fprintf(fid,'input_path         = ''''\n');
fprintf(fid,'output_path        = ''''\n');
fprintf(fid,'high_level_path    = ''''\n');
fprintf(fid,'searchPath         = ''auto''\n');
fprintf(fid,'\n\n\n');
for cntTraces = 1:length(trace_str)
    fprintf(fid,'[Trace]\n');
    fprintf(fid,'    variableName    = ''%s''\n',trace_str(cntTraces).variableName);
    fprintf(fid,'    title           = ''%s''\n',trace_str(cntTraces).ini.title);
    fprintf(fid,'    units           = ''%s''\n',trace_str(cntTraces).ini.units);
    fprintf(fid,'    Evaluate        = ''%s = %s;''\n',trace_str(cntTraces).variableName,trace_str(cntTraces).variableName);    
    fprintf(fid,'[End]\n\n');
end

fclose all;
fprintf('Template created: %s\n',outputIniFileName);

