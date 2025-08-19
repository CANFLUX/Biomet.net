function tableOut = create_AMF_BADM_Variable_Aggregation(siteID,yearIn,outputPath,siteIDamf,oneFluxVarNames)
% tableOut = create_AMF_BADM_Variable_Aggregation(siteID,yearIn,outputPath)
%
% Create an Ameriflux BADM Variable Aggregation file from siteID_SecondStage.ini
%
%
%  siteID       - a site ID using TAB naming convention ('YF','DSM'...)
%                 OR
%                 full file name to a SecondStage ini file (in case the default paths are not set)
%                 If using a file name then siteIDamf is required!
%  yearIn       - a year for which the output will be generated
%  outputPath   - path where to save CSV file. If omitted, no file will be saved.
%  siteIDamf    - in case the default AMF site ID is not defined in siteID_config.yml file
%                 you can use your own name
%
%
% Example call:
%  1. Create an output table for site RBM and year 2025 (without saving):
%       tableOut = create_AMF_BADM_Variable_Aggregation('RBM',2025);
%  2. Save AMF BADM Variable Aggregation file for year 2025 and site RBM into p:\test.csv
%       saveDatabaseToAmeriFluxCSV('DSM',2022,'p:\test.csv');
%
%
% Zoran Nesic               File created:       Aug  7, 2025
%                           Last modification:  Aug 18, 2025
%

%
% Revisions:
%

% File header:
fileHeader{1} = 'SITE_ID,AMF_VAR_AGG_VARNAME,AMF_VAR_AGG_MEMBERS,AMF_VAR_AGG_STATISTIC,AMF_VAR_AGG_DATE,AMF_VAR_AGG_COMMENT';
fileHeader{2} = 'XX-yyy,Variable Code,list separated by semicolons,LIST(AGG_STATISTIC),YYYYMMDDHHMM,Free text';
fileHeader{3} = 'Required,Required,Required,Required,Optional,Optional';

arg_default('outputPath',[]);

%pthListOfVarNames = fullfile(db_pth_root,'Calculation_Procedures','AmeriFlux');
%afListOfVarNames = readtable(fullfile(pthListOfVarNames,'flux-met_processing_variables_20221020.csv'));
oneFluxVarNamesDefaults = {'CO2','FC','H','LE','WS','USTAR','TA','RH','PA', 'SW_IN','PPFD_IN',...
                   'SC','G','NETRAD','PPFD_IN','LW_IN','P','SWC','TS',...
                   'WD','PPFD_DIF','PPFD_OUT','SW_DIF','SW_OUT','LW_OUT'};
arg_default('oneFluxVarNames',oneFluxVarNamesDefaults)
oneFluxVarNames = oneFluxVarNames(:)';

% Load up trace and site info
% If the siteID is a full path to an ini file then just load up that file
% Otherwise, load up the default ini file based on the siteID and stage num=2
if exist(siteID,'file')
    trace_str= readIniFileDirect(yearIn,siteID);
    siteID = trace_str(1).SiteID;
else
    trace_str= readIniFileDirect(yearIn,siteID,2);
end
allTraces = {trace_str(:).variableName};
% confirm that all the trace names are unique
[uniqueNames, first_occurrence_indices] = unique(allTraces,'first');
if length(allTraces) > length(uniqueNames)
    % There are some duplicate names. Alert user
    fprintf(2,'Duplicate variable names found in the SecondStage.ini file:\n');
    is_duplicate = ~ismember(1:numel(allTraces), first_occurrence_indices); % Identify non-first occurrences
    repeated_traces_with_duplicates = allTraces(is_duplicate); % Extract the actual duplicate values    
    for cntDuplicates = 1:length(repeated_traces_with_duplicates)
        fprintf('     %s\n',char(repeated_traces_with_duplicates(cntDuplicates)));
    end
    fprintf(2,'Ignoring the duplicates.\n');
    allTraces = uniqueNames;
end

if ~(exist('siteIDamf','var') && ~isempty(siteIDamf))
    try
        structProject = get_TAB_project;
        siteIDamf = get_TAB_AMF_siteID(structProject,siteID);
    catch
        fprintf(2,'Could not find AMF site ID. Using the default:%s\n',siteID);
        siteIDamf = string(siteID);
    end
else
    siteIDamf = string(siteIDamf);
end
% cycle through all OneFlux variable names
% and create all the colums
cntRows = 0;
for cntVar = 1:size(oneFluxVarNames,2)
    varName = char(oneFluxVarNames(cntVar));
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
            col4(cntRows,1) = "Do not know";  %find_observation_type(trace_str(indAllMatchingVarnames)); %"Single observation";  % *** TO BE PROPERLY ESTABLISHED (Single or Mean)***
        else
            col3(cntRows,1) = string(allTraces(indAllMatchingVarnames));
            col4(cntRows,1) = find_observation_type(trace_str(indAllMatchingVarnames)); %"Single observation";  % *** TO BE PROPERLY ESTABLISHED (Single or Mean)***
        end
        
        col5(cntRows,1) = string();
        col6(cntRows,1) = string();
        %fprintf('%3d %8s %20s %40s\n',cntRows,col1(cntRows,1),col2(cntRows,1),col3(cntRows,1));
    end
end

% create the tableOut
tableOut = table(col1,col2,col3,col4,col5,col6);
% if outputPath is given then save the table
if ~isempty(outputPath)
    fid = fopen(outputPath,'w');
    if fid > 0
        % print the header first
        fprintf(fid,'%s\n',fileHeader{1});
        fprintf(fid,'%s\n',fileHeader{2});
        fprintf(fid,'%s',fileHeader{3});
        fclose(fid);
        writetable(tableOut, outputPath, 'WriteVariableNames', false, 'WriteMode', 'append');
    end
end


function sType = find_observation_type(trace_str)
    setupIni = trace_str.ini;
    tName = trace_str.variableName;
    fNames = fieldnames(setupIni);
    % Find all Evaluate lines: (Evaluate1,Evaluate2...)
    indE = find(startsWith(fNames,'Evaluate'));
    % and loop through them (skip if none exist)
    for cntE = 1:length(indE)
        evalStr = char(fNames(indE(cntE)));
        % get the string in one single Evaluate line
        aLine = setupIni.(evalStr);
        %fprintf('%4d %20s %s\n',cntTraces,tName,aLine);   
        % search for a pattern 'varName=...'
        tstStr = [tName '=.'] ;
        sEval = trace_str.ini.(evalStr);
        xx=regexpi(sEval,tstStr);
        % given that the aLine can have multiple assignments,
        % pick only the last one
        xx = xx(end);
        % extract the part after "="
        strLastCalc = sEval((xx+length(tstStr))-1:end);
         
        % within the leftover string find (if exists) the string
        % [....] presumably containing all the traces that are 
        % being used/averaged to calculate this tName
        yy = char(regexpi(strLastCalc,'(\[.*\])','match'));
        % If there are no items in [] then this is (most likely)
        % a single observation
        sType = "Single observation";
        if ~isempty(yy)
            %sType = [sType '*'];  % add '*' if single observation but inside of []
            % if not empty it should contain one or more trace names
            % split the string using ',' as delimiter
            subTrace=split(yy(2:end-1),',');
            % the output will be at least one trace name. Store it in strOut
            strOut = char(subTrace(1));
            % if there are more trace names, cycle through them and append to strOut
            for cnt = 2:length(subTrace)
                strOut = strOut + ","  + string(subTrace{cnt});
                sType = 'Mean';
            end
            %fprintf('     ===>  %20s   ',sType);
            %fprintf('     ===>  %s\n', strOut);
        end
        %fprintf('%4d %20s %20s  %s\n',tName,sType,strLastCalc);                 
    end




% % cycle through all Ameriflux variable names
% % and create all the colums
% cntRows = 0;
% for cntVar = 1:size(afListOfVarNames,1)
%     varType = char(afListOfVarNames.Type(cntVar));
%     % skip time-keeping variables (we'll create our own)
%     if ~strcmp(varType,'TIMEKEEPING')
%         varName = char(afListOfVarNames.Variable(cntVar));
%         % see if such a variable exists in the second stage
%         indAllMatchingVarnames = find(strcmpi(allTraces,varName) | startsWith(allTraces,[varName '_']));
%         if ~isempty(indAllMatchingVarnames)
%             cntRows = cntRows + 1;
%             col1(cntRows,1) = siteIDamf; %#ok<*AGROW>
%             col2(cntRows,1) = string(varName);
%             if length(indAllMatchingVarnames) > 1
%                 col3(cntRows,1) = string(allTraces(indAllMatchingVarnames(1)));
%                 for cntMatchingNames = indAllMatchingVarnames(2:end)
%                     col3(cntRows,1) = col3(cntRows,1) + "," + string(allTraces(cntMatchingNames));
%                 end
%             else
%                 col3(cntRows,1) = string(allTraces(indAllMatchingVarnames));
%             end
%             col4(cntRows,1) = "Single observation";  % *** TO BE PROPERLY ESTABLISHED (Single or Mean)***
%             col5(cntRows,1) = string();
%             col6(cntRows,1) = string();
%             %fprintf('%3d %8s %20s %40s\n',cntRows,col1(cntRows,1),col2(cntRows,1),col3(cntRows,1));
%         end
%     end
% end