function createSecondStageIni(structSetup)
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
%
%
% Zoran Nesic               File created:           Feb 21, 2025
%                           Last modification:      Feb 25, 2025

% Revisions:
%
% Feb 25, 2025 (Zoran)
%   - had a hard coded "\" in the path. Fixed it.
% Feb 24, 2025 (Zoran)
%   - changed the input parametar to be the same as the input to 
%     createFirstStageIni. 

siteID = structSetup.siteID;
% Read the FirstStage.ini file (year should not matter for the template
trace_str = readIniFileDirect(2999,siteID,1);

if isfield(structSetup,'isTemplate') && ~structSetup.isTemplate
    outputIniFileName = fullfile(biomet_database_default,...
                                'Calculation_Procedures','TraceAnalysis_ini',...
                                structSetup.siteID, ...
                                [structSetup.siteID '_SecondStage.ini']);
   if exist(outputIniFileName,'file')
        ButtonName = questdlg(sprintf('File: %s already exist!',outputIniFileName), ...
                     'Confirm Overwrite', ...
                     'Overwrite', 'Cancel',  'Cancel');
        if strcmpi(ButtonName,'Cancel')
            error('File already exists. User cancelled the processing.');
        end
   end
else
    outputIniFileName = fullfile(structSetup.outputPath, [structSetup.siteID '_SecondStage_Template.ini']);
end
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

