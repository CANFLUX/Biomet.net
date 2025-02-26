function cntAllNanFiles = findAllNaNfiles(siteID,yearIn,stageNum)
% This function finds database files that contain only NaN values.
% It can be called by specifying the siteID, yearIn and the stageNum (1/2) 
%    cntAllNanFiles = findAllNaNfiles('DSM',2025,2);
% or by giving it a full path to a folder containing database files
%   cntAllNanFiles = findAllNaNfiles('E:\Pipeline_Projects\vinimet\database\2024\DSM\Clean\SecondStage');
%
%
% Input:	
%			sideID          - site ID or the full path to the database folder
%           yearIn          - if the siteID is not a path then specify the year
%			stageNum        - the number for the stage (1 - FirstStage, 2 - SecondStage)
%
% Output: 
%           cntAllNanFiles  - The number of database traces with all NaNs
%
%
% Zoran Nesic                   File Created:      Feb  12, 2025
%                               Last modification: Feb  25, 2025

% Revisions
%
% Feb 25, 2025 (Zoran)
%   - Bug fix: There was a hard coded 'DSM' instead of siteID.
%

if exist(siteID,'dir')
    % if the full file is given instead of a site ID 
    % then just load all the files from that folder into trace_str
    allFiles = dir(siteID);
    cntTraces = 0;
    for cntFiles = 1:length(allFiles)
        if ~allFiles(cntFiles).isdir
            cntTraces = cntTraces + 1;
            fileName = allFiles(cntFiles).name;
            if ismember(fileName,{'clean_tv','TimeVector'})
                dataType = 8;
            else
                dataType = 1;
            end
            traceFileName = fullfile(allFiles(cntFiles).folder,fileName);
            trace_str(cntTraces).data = read_bor(traceFileName,dataType);
            trace_str(cntTraces).variableName = fileName;
        end
    end
else
    % Load up the data using the site ini files
    if stageNum == 1
        iniFile = sprintf('%s_FirstStage.ini',siteID);
    else
        iniFile = sprintf('%s_SecondStage.ini',siteID);
    end
    iniFileName = fullfile(biomet_database_default,'Calculation_Procedures','TraceAnalysis_ini',siteID,iniFile);
    trace_str = read_data(yearIn, siteID,iniFileName);
end

cntAllNanFiles = 0;
for cntTraces=1:length(trace_str)
    dataIn = trace_str(cntTraces).data;
    if all(isnan(dataIn))
        fprintf(2,'%20s - all NaNs\n',trace_str(cntTraces).variableName)
        cntAllNanFiles=cntAllNanFiles+1;
    end
end
if cntAllNanFiles>0
    fprintf(2,'============\nFound %d traces containing all NaNs\n',cntAllNanFiles);
else
    fprintf(1,'============\nFound 0 traces containing all NaNs\n');
end