function run_EP_API(siteID,startDay,endDay,EP_template)
%% main_EP_API_processing script/function

%% Input and Setup parameters:
% NOTE: the following call to get_TAB_projects reads the config file
%       from this local computer not from the main data server.
%       I may want to have an option to load up the main TAB_config file.
%       One option is that the local get_TAB_configuration on HF data-processing
%       computers has only the paths to the local scripts and folders 
%       AND then it loads up the config file from the data server to get
%       the site names and setups 


structProject = get_TAB_project;
% setup python environment and run pyBatchFileName
% batch file: Scripts/main_EP_API_script.bat needs to be created manually
% 
mainBatchFileName = fullfile(structProject.path,'Scripts','main_EP_API_script.bat');      

% Create temporary batch file
create_EP_API_batch_file(siteID,startDay,endDay,EP_template)

% run the main batch file
[status,cmdout] = system(mainBatchFileName);

% Rename files and put them in the shared folder
% test status/cmdout before calling the next step
pthEPAPI_main = structProject.EPAPI_output;
pthEP_main = structProject.EP_output;
flagCreate = true;
flagOverwrite = [];
process_EP_API_fulloutput({siteID},pthEPAPI_main,pthEP_main,flagCreate,flagOverwrite)