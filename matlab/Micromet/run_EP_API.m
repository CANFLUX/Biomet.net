function run_EP_API(siteID,startDay,endDay,EP_template)
% run_EP_API - main call for EP_API 
%
% Inputs:
%   siteID          - (char) site ID
%   startDay        - (datenum or datetime) first day to process
%   endDay          - (datenum or datetime) last day to process
%   EP_template     - EddyPro template to use (default is the one from get_TAB_project_configuration)
%
%
% Zoran Nesic               File created:             , 2025
%                           Last modification:  Oct  7, 2026

% 
% Revisions
%
% Oct 7, 2026 (Zoran)
%   - This function now saves the log file after EP_API run

% confirm that all input arguments are correct
if ~ischar(siteID)
    error('siteID must be type:char');
end
if isnumeric(startDay)
    startDay = datetime(startDay,'ConvertFrom','datenum');
end
if isnumeric(endDay)
    endDay = datetime(endDay,'ConvertFrom','datenum');
end

structProject = get_TAB_project;

arg_default('EP_template','')
if isempty(EP_template)
    % if EP_template is not given, use the one 
    % from get_TAB_project_configuration file
    % if it exists.
    if structProject.ismain
        EP_template = structProject.sites.(siteID).EP_template;
    else
        EP_template = structProject.server.sites.(siteID).EP_template;
    end
end

% Start processing
stTime = datetime;
fprintf(1,'========================================\n');
fprintf(1,'%s\n',stTime);
fprintf(1,'siteID = %s\n',siteID);
fprintf(1,'Processing data for the period %s -> %s\n',startDay,endDay);

% setup python environment and run pyBatchFileName
% batch file: Scripts/main_EP_API_script.bat needs to be created manually
% 
mainBatchFileName = fullfile(structProject.path,'Scripts','main_EP_API_script.bat');      

% Create temporary batch file
fprintf(1,'Creating a temporary EP_API batch file... \n');
create_EP_API_batch_file(siteID,startDay,endDay,EP_template)
fprintf(1,'Done.\n');

% run the main batch file
fprintf(1,'Running EP_API batch file... \n');
[status,cmdout] = system(mainBatchFileName);
% test if the run was successful, stop if it wasn't
if status == 0
    fprintf(1,'Done.\n');
else
    fprintf(2,'Error running EP_API batch file\n');
    fprintf(2,'Batch file returned this output:\n');
    fprintf(2,'%s\n',cmdout);
    error('');
end

% Rename files and put them in the shared folder
pthEPAPI_main = structProject.EPAPI_output;
pthEP_main = structProject.EP_output;
flagCreate = true;
flagOverwrite = [];
fprintf(1,'Processing EP_API fulloutput files... \n');
process_EP_API_fulloutput({siteID},pthEPAPI_main,pthEP_main,flagCreate,flagOverwrite)

% Write the log file
logFileFolder = fullfile(pthEPAPI_main,siteID,'log');
if ~exist(logFileFolder,"dir")
    mkdir(logFileFolder);
end
logFileName = fullfile(logFileFolder,sprintf('EP_API_%s.log',datestr(datetime,30))); %#ok<DATST>
fprintf(1,'Writing the log file: %s\n',logFileName);
fid = fopen(logFileName,'Wt');
if fid>0
    fprintf(fid,'%s',cmdout);
    fclose(fid);
end

fprintf(1,'Done.\n');

fprintf(1,'Finished at: %s (run time: %s)\n\n',datetime,datetime-stTime);