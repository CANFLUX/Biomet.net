function trace_str = readIniFileDirect(yearIn,siteID,stageNum,newYAML)
% Reads a TraceAnalysis ini file
%
% trace_str = readIniFileDirect(year,SiteID,stageNum)
%
% Arguments
%
%   yearIn      - the year that requires processing
%   siteID      - site name (like 'DSM') or a full file name to an ini file
%   stageNum    - a number (1-3) of the cleaning stage number
%   newYAML     - boolean, false to keep old ini, true for new yaml format
%
%   trace_str   - a structure read from the ini file
%
%
% Zoran Nesic               File created:       Jan 25, 2023
%                           Last modification:  Aug  8, 2025

% Revisions
%
% Sep 4, 2025 (June)
%   - Added option to read new YAML first/second stage files if they exist
% Aug 8, 2025 (Zoran)
%   - changed function so it can now accept a full path to the ini file
%     instead of creating the iniFileName based on siteID and stageNum and default paths

arg_default('newYAML',true);
if exist(siteID,'file')
    iniFileName = siteID;
else
    arg_default('stageNum',1)
    switch stageNum
        case 1
            fileName = [siteID '_FirstStage.ini'];
        case 2
            fileName = [siteID '_SecondStage.ini'];
        case 3
            fileName = [siteID '_ThirdStage.ini'];
    end
    iniFileName = fullfile(db_pth_root,'Calculation_Procedures','TraceAnalysis_ini',siteID,fileName);
end
if newYAML
    tmp = strrep(iniFileName,'.ini','.yml')
    if exist(tmp,'file')
        iniFileName = tmp;
    else
        newYAML = false;
    end
end
%Open initialization file if it is present:
if newYAML
    fprintf('\n\nReading new yaml format\n\n')
    trace_str = read_yaml_config(iniFileName,yearIn);
elseif exist(iniFileName,'file')
   fid = fopen(iniFileName,'rt');						%open text file for reading only.   
   if (fid < 0)
      disp(['File, ' iniFileName ', is invalid']);
      trace_str = [];
      return
   end
    trace_str = read_ini_file(fid,yearIn);
    fclose(fid);
else
    fprintf('Could not open file: %s\n', iniFileName);
    return
end