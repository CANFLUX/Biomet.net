function tableOut = create_AMF_BADM_Variable_Aggregation(siteID,yearIn,outputPath,siteIDamf)
% tableOut = create_AMF_BADM_Variable_Aggregation(siteID,yearIn,outputPath)
%
% Create an Ameriflux BADM Variable Aggregation file from siteID_SecondStage.ini
%
%
%  siteID       - a site ID using TAB naming convention ('YF','DSM'...)
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
% Zoran Nesic               File created:       Aug  7, 2025
%                           Last modification:  Aug  7, 2025
%

%
% Revisions:
%

% File header:
fileHeader{1} = 'SITE_ID,AMF_VAR_AGG_VARNAME,AMF_VAR_AGG_MEMBERS,AMF_VAR_AGG_STATISTIC,AMF_VAR_AGG_DATE,AMF_VAR_AGG_COMMENT';
fileHeader{2} = 'XX-yyy,Variable Code,list separated by semicolons,LIST(AGG_STATISTIC),YYYYMMDDHHMM,Free text';
fileHeader{3} = 'Required,Required,Required,Required,Optional,Optional';

arg_default('outputPath',[]);
pthDatabase = biomet_path(yearIn,siteID);

pthDataIn = fullfile(pthDatabase,'Clean','SecondStage');
pthListOfVarNames = fullfile(db_pth_root,'Calculation_Procedures','AmeriFlux');
afListOfVarNames = readtable(fullfile(pthListOfVarNames,'flux-met_processing_variables_20221020.csv'));

% Load up trace and site info
trace_str= readIniFileDirect(yearIn,siteID,2);
allTraces = {trace_str(:).variableName};
% confirm that all the trace names are unique
uniqueNames = unique(allTraces);
if length(allTraces) > length(uniqueNames)
    % There are some duplicate names. Alert user
    fprintf(2,'Duplicate variable names found in the SecondStage.ini file.\n');
    fprintf(2,'Ignoring the duplicates.\n');
    allTraces = uniqueNames;
end
structProject = get_TAB_project;
if ~(exist('siteIDamf','var') && ~isempty(siteIDamf))
    siteIDamf = get_TAB_AMF_siteID(structProject,siteID);
end

% cycle through all Ameriflux variable names
% and create all the colums
cntRows = 0;
for cntVar = 1:size(afListOfVarNames,1)
    varType = char(afListOfVarNames.Type(cntVar));
    % skip time-keeping variables (we'll create our own)
    if ~strcmp(varType,'TIMEKEEPING')
        varName = char(afListOfVarNames.Variable(cntVar));
        % see if such a variable exists in the second stage
        indAllMatchingVarnames = find(strcmpi(allTraces,varName) | startsWith(allTraces,[varName '_']));
        if ~isempty(indAllMatchingVarnames)
            cntRows = cntRows + 1;
            col1(cntRows,1) = siteIDamf; %#ok<*AGROW>
            col2(cntRows,1) = string(varName);
            if length(indAllMatchingVarnames) > 1
                col3(cntRows,1) = string(allTraces(indAllMatchingVarnames(1)));
                for cntMatchingNames = indAllMatchingVarnames(2:end)
                    col3(cntRows,1) = col3(cntRows,1) + "," + string(allTraces(cntMatchingNames));
                end
            else
                col3(cntRows,1) = string(allTraces(indAllMatchingVarnames));
            end
            col4(cntRows,1) = "Single observation";  % *** TO BE PROPERLY ESTABLISHED (Single or Mean)***
            col5(cntRows,1) = string();
            col6(cntRows,1) = string();
            fprintf('%3d %8s %20s %40s\n',cntRows,col1(cntRows,1),col2(cntRows,1),col3(cntRows,1));
        end
    end
end

% if outputPath is given then save the table
if ~isempty(outputPath)
    fid = fopen(outputPath,'w');
    if fid > 0
        % print the header first
        fprintf(fid,'%s\n',fileHeader{1});
        fprintf(fid,'%s\n',fileHeader{2});
        fprintf(fid,'%s',fileHeader{3});
        fclose(fid);
        tableOut = table(col1,col2,col3,col4,col5,col6);
        writetable(tableOut, outputPath, 'WriteVariableNames', false, 'WriteMode', 'append');
        % for cntOutput = 1:cntRows
        %     fprintf(fid,'%s,%s,%s,$s,%s,%s\n',col1(cntOutput),col2(cntOutput),col3(cntOutput)...
        %                                      ,col4(cntOutput),col5(cntOutput),col6(cntOutput));
        % end
    end
end

