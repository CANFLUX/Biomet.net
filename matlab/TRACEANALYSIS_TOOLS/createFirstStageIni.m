function createFirstStageIni(structSetup)
% Create the first stage ini defaults for the given site database (traces have to already exist in the database)
%
% For the given site, the function searches through the folder named in structSetup.allMeasurementTypes
% and creates skeleton [Trace]...[End] for each database file. User then has to populate many
% of the values.
%
% The output ini file will be stored as outputPath/Site_ID_FirstStage_Template.ini. If the outputPath is []
% the file is saved in the current folder.
%
%
% Example of the input structure:
% structSetup.startYear = 2021;
% structSetup.startMonth = 1;
% structSetup.startDay = 1;
% structSetup.endYear = 2999;
% structSetup.endMonth = 12;
% structSetup.endDay = 31;
% structSetup.Site_name = 'Delta Site Marsh';
% structSetup.siteID = 'DSM';
% structSetup.allMeasurementTypes = {'MET','Flux'};
% structSetup.Difference_GMT_to_local_time = 8;  % local+Difference_GMT_to_local_time -> GMT time
% structSetup.outputPath = []; % keep it in the local directory
%
% Zoran Nesic               File created:           Mar 20, 2024
%                           Last modification:      Mar 12, 2025

% Revisions:
%
% Mar 12, 2025 (Zoran)
%   - Added automatic minMax range and units setup using AF QAQC limits file created by Rosie Howard.
% Feb 25, 2025 (Zoran)
%   - had a hard coded "\" in the path. Fixed it.
% Feb 24, 2025 (Zoran)
%   - renamed .SiteID to .siteID.
% Feb 21, 2025 (Zoran)
%   - Added time-offset info
% Oct 28, 2024 (Zoran)
%   - Removed obsolete properties.
%   - Added instrumentType property
% May 10, 2024 (Zoran)
%   - Formatting improvements.
% Apr 19, 2024 (Zoran)
%   - Bug fix: LoggedCalibrations and CurrentCalibrations did not have span and offset include. ([1 0]).
%   - Added proper handling of the quality control traces (minMax and dependent fields).

if isfield(structSetup,'isTemplate') && ~structSetup.isTemplate
    outputIniFileName = fullfile(biomet_database_default,...
                                'Calculation_Procedures','TraceAnalysis_ini',...
                                structSetup.siteID, ...
                                [structSetup.siteID '_FirstStage.ini']);
   if exist(outputIniFileName,'file')
        ButtonName = questdlg(sprintf('File: %s already exist!',outputIniFileName), ...
                     'Confirm Overwrite', ...
                     'Overwrite', 'Cancel',  'Cancel');
        if strcmpi(ButtonName,'Cancel')
            error('File already exists. User cancelled the processing.');
        end
   end
else
    outputIniFileName = fullfile(structSetup.outputPath, [structSetup.siteID '_FirstStage_Template.ini']);
end

% Find the location of QAQC limits file
qaqcFileName = fullfile(biomet_database_default,'Calculation_Procedures','AmeriFlux','QAQC_limits_ranges_info.csv');

fprintf('---------------------------\n');
fprintf('Creating template file: %s\n',outputIniFileName);
fid = fopen(outputIniFileName,'w');

% Header output
fprintf(fid,'%%\n%% File generated automatically on %s\n%%\n\n',datetime('today'));
fprintf(fid,'Site_name = ''%s''\n',structSetup.Site_name);
fprintf(fid,'SiteID = ''%s''\n\n',structSetup.siteID);
fprintf(fid,'Difference_GMT_to_local_time = %d   %% timezone that your site is located in, in hours (GMT - local time), opposite of what you wrote in config.yml\n',structSetup.Difference_GMT_to_local_time);
fprintf(fid,'Timezone                     = %d   %% timezone that your data is reported in (UTC, standard time, or daylight saving time), in hours\n\n',structSetup.Difference_GMT_to_local_time);


for cntMeasurementTypes = 1:length(structSetup.allMeasurementTypes)
    measurementType = char(structSetup.allMeasurementTypes(cntMeasurementTypes));
    fprintf(fid,'\n\n%%-----------------------------------------\n');
    fprintf(fid,    '%%    Measurement type: %s\n',measurementType);
    fprintf(fid,    '%%-----------------------------------------\n\n');
    inputFolder = biomet_path(structSetup.startYear,structSetup.siteID,measurementType);
    allFiles = dir(inputFolder);

    % Extract the Ameriflux QAQC limits and units
    try
        limitsQAQC = extract_AF_QAQC_LimitRanges({allFiles(:).name},qaqcFileName);
    catch
        limitsQAQC =[];
    end
    fprintf('Processing %d traces in: %s\n',length(allFiles),inputFolder)
    
    for cntFiles = 1:length(allFiles)
        if ~allFiles(cntFiles).isdir
            try
                variableName = allFiles(cntFiles).name;
                fprintf(fid,'[Trace]\n');
                fprintf(fid,'    variableName         = ''%s''\n',variableName);
                fprintf(fid,'    title                = ''Title goes here''\n');
                fprintf(fid,'    inputFileName        = {''%s''}\n',variableName);
                fprintf(fid,'    inputFileName_dates  = [ datenum(%d,%d,%d) datenum(%d,%d,%d)]\n',...
                                                        structSetup.startYear,structSetup.startMonth,structSetup.startDay,...
                                                        structSetup.endYear,structSetup.endMonth,structSetup.endDay);
                        
                fprintf(fid,'    measurementType      = ''%s''\n',measurementType);
                if cntFiles <= length(limitsQAQC) && ~isempty(limitsQAQC(cntFiles).units)
                    fprintf(fid,'    units                = ''%s''\n',char(limitsQAQC(cntFiles).units));
                else
                    fprintf(fid,'    units                = ''''\n');
                end
                fprintf(fid,'    instrument           = ''''\n');
                fprintf(fid,'    instrumentSN         = ''''\n');
                fprintf(fid,'    instrumentType       = ''''\n');
                fprintf(fid,'    loggedCalibration    = [ 1 0 datenum(%d,%d,%d) datenum(%d,%d,%d)]\n',...
                                                        structSetup.startYear,structSetup.startMonth,structSetup.startDay,...
                                                        structSetup.endYear,structSetup.endMonth,structSetup.endDay);
                fprintf(fid,'    currentCalibration   = [ 1 0 datenum(%d,%d,%d) datenum(%d,%d,%d)]\n',...
                                                        structSetup.startYear,structSetup.startMonth,structSetup.startDay,...
                                                        structSetup.endYear,structSetup.endMonth,structSetup.endDay);
                fprintf(fid,'    comments             = ''''\n');
                % If this is a standard QC variable, then create known minMax and dependency fields
                % Otherwise use defaults
                switch upper(variableName)
                    case {'FC_SSITC_TEST','QC_CO2_FLUX'}                
                        fprintf(fid,'    minMax               = [0,1]\n');
                        fprintf(fid,'    dependent            = ''FC,rand_err_co2_flux''\n');
                    case {'FCH4_SSITC_TEST','QC_CH4_FLUX'}
                        fprintf(fid,'    minMax               = [0,1]\n');
                        fprintf(fid,'    dependent            = ''FCH4,rand_err_co2_flux''\n');
                    case {'H_SSITC_TEST','QC_H'}
                        fprintf(fid,'    minMax               = [0,1]\n');
                        fprintf(fid,'    dependent            = ''H,rand_err_H''\n');
                    case {'LE_SSITC_TEST','QC_LE'}
                        fprintf(fid,'    minMax               = [0,1]\n');
                        fprintf(fid,'    dependent            = ''LE,rand_err_LE''\n');
                    case {'TAU_SSITC_TEST','QC_TAU'}
                        fprintf(fid,'    minMax               = [0,1]\n');
                        fprintf(fid,'    dependent            = ''TAU,rand_err_Tau''\n');
                    otherwise
                        if cntFiles <= length(limitsQAQC) && ~isempty(limitsQAQC(cntFiles).minMaxBuff)
                            fprintf(fid,'    minMax               = [%f, %f]\n',limitsQAQC(cntFiles).minMaxBuff);
                        else
                            fprintf(fid,'    minMax               = [-Inf,Inf]\n');                            
                        end
                        fprintf(fid,'    dependent            = ''''\n');                        
                end
                fprintf(fid,'    zeroPt               = -9999\n');   
                fprintf(fid,'[End]\n\n');
            catch ME
            end
        end
    end
end
fclose all;
fprintf('Template created: %s\n',outputIniFileName);
end

