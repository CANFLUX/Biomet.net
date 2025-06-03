function tableOut = saveDatabaseToAmeriFluxCSV(siteID,yearIn,outputPath)
% tableOut = saveDatabaseToAmeriFluxCSV(siteID,yearIn)
%
% Create a table of all Ameriflux variables that exist under
% clean\SecondStage folder for one site and for one year.
% This table can then be saved as a csv file and uploaded to 
% Ameriflux database.
%
% Note: Only file names that follow standart Ameriflux naming convention
%       will be included. All other SecondStage variables will be skipped.
%
%  siteID       - a site ID using Biomet/Micromet naming convention ('YF','DSM'...)
%  yearIn       - a year for which the output will be generated
%  outputPath   - path where to save CSV file. If omitted, no file will be saved.
%
%
% Example call:
%  1. Load up 2022 DSM data into a table (without saving):
%       tableOut = saveDatabaseToAmeriFluxCSV('DSM',2022);
%  2. Save 2022 DSM data into a file with proper AF name under p:\test folder
%       saveDatabaseToAmeriFluxCSV('DSM',2022,'p:\test');
%
%
% Zoran Nesic               File created:       Oct 20, 2022
%                           Last modification:  Jun  3, 2025
%

%
% Revisions:
%
% Jun 3, 2025 (Zoran)
%   - Added an option for getting the AmerifluxID from a site-specific yml file.
% Feb 23, 2023 (Zoran)
%   - function will create outputPath if it doesn't exist.
% Nov 25, 2022 (Zoran)
%   - For the current year program now exports only data up to yesterday.
%     Ameriflux doesn't like data files that contain only -9999.
% Nov 4, 2022 (Zoran)
%   - Changed to proper way of finding database root path (function db_pth_root).
% Oct 21, 2022 (Zoran)
%   - corrected site names' typo ("CC-" -> "CA-")
%   - added option to pass third stage variables to the table

arg_default('outputPath',[]);
pthDatabase = biomet_path(yearIn,siteID);

pthDataIn{1} = fullfile(pthDatabase,'Clean','SecondStage');
pthListOfVarNames{1} = fullfile(db_pth_root,'Calculation_Procedures','AmeriFlux');
afListOfVarNames{1} = readtable(fullfile(pthListOfVarNames{1},'flux-met_processing_variables_20221020.csv'));

pthDataIn{2} = fullfile(pthDatabase,'Clean','ThirdStage');
pthListOfVarNames{2} = fullfile(db_pth_root,'Calculation_Procedures','AmeriFlux');
afListOfVarNames{2} = readtable(fullfile(pthListOfVarNames{2},'Micromet_ThirdStageNames.txt'));

% create an empty output structure
structOut = struct;
% Add time stamps.
tv = datetime(read_bor(fullfile(pthDataIn{1},'clean_tv'),8),'convertfrom','datenum');
structOut.TIMESTAMP_START = datestr(tv-1/48,'yyyymmddhhMM');
structOut.TIMESTAMP_END = datestr(tv,'yyyymmddhhMM');
% cycle through both Second and Third stage
for cntStage = 1:2
    % cycle through all Ameriflux variable names
    for cntVar = 1:size(afListOfVarNames{cntStage},1)
        varType = char(afListOfVarNames{cntStage}.Type(cntVar));
        % skip time-keeping variables (we'll create our own)
        if ~strcmp(varType,'TIMEKEEPING')
            varName = char(afListOfVarNames{cntStage}.Variable(cntVar));
            % see if such a variable exists in the second stage
            % or in the third stage (but only with qualifiers '_*'
            % that why there is: " && ~strcmp(varType,'PI')" below
            if (~isempty(dir(fullfile(pthDataIn{cntStage},varName)))&& ~strcmp(varType,'PI')) ...
               || ~isempty(dir(fullfile(pthDataIn{cntStage},[varName '_*'])))
               % get all the variables that match that wildcard
               if ~strcmp(varType,'PI')
                    allSecondStageVars = [dir(fullfile(pthDataIn{cntStage},varName));...
                                          dir(fullfile(pthDataIn{cntStage},[varName '_*']))];
               else
                    allSecondStageVars = dir(fullfile(pthDataIn{cntStage},[varName '_*']));
               end
               % load all SecondStage variables into structOut
               for cntSecStgVars = 1: length(allSecondStageVars)
                   % get variable name
                   ssVarName = char(allSecondStageVars(cntSecStgVars).name);
                   % read data from database
                   ssData = read_bor(fullfile(pthDataIn{cntStage},ssVarName));
                   % replace NaN-s with -9999
                   ssData(isnan(ssData)) = -9999;
                   % store output
                   structOut.(ssVarName) = ssData;
               end
            end
        end
    end
end
% Convert output structure to a table
tableOut = struct2table(structOut);
indThisYear = find(tv < datetime('today'));
tableOut = tableOut(indThisYear,:); %#ok<FNDSB>

% See if the there is a siteID-specific yml file with AmerifluxID in it
fn = fullfile(db_pth_root,'Calculation_Procedures','TraceAnalysis_ini',siteID,[siteID '_config.yml']);
if isfile(fn)
    configYAML = yaml.loadFile(fn);
else
    configYAML.Metadata = NaN;
end
if isfield(configYAML.Metadata,'AmerifluxID')
    siteNameAF = configYAML.Metadata.AmerifluxID;
else
    siteNameAF = ['CA-' upper(siteID)];
end
% export only data that older from today

% if outputPath is given then save the table
if ~isempty(outputPath)
    outputPath = fullfile(outputPath);  % sorting out MacOS vs Windows issues
    % outputPath does not exist, create it
    if ~exist(outputPath,'dir')
        mkdir(outputPath)
    end
    fileName = sprintf('%s_HH_%s_%s.csv',siteNameAF,...
                             datestr(tv(1)-1/48,'yyyymmdd0000'),...
                             datestr(tv(end),'yyyymmdd0000'));
    writetable(tableOut,fullfile(outputPath,fileName));
end

