function [EngUnits,Header,tv,dataOut,structConfig] = fr_read_GHG_file(pathToGHGfile)
% [EngUnits,Header,tv,dataOut] = fr_read_GHG_file(pathToGHGfile)
% 
% Inputs:
%   pathToGHGfile        - file name for Licor GHG file
%
% Outputs:
%   EngUnits            - output data matrix
%   Header              - file header
%   tv                  - datenum time vector
%   dataOut             - output data structure 
%   structConfig        - LI-7200 configuration structure
%
%
% (c) Zoran Nesic                   File created:       Jan 20, 2022
%                                   Last modification:  Feb 15, 2026
%

% Revisions (last one first):
%
% Feb 15, 2026 (Zoran)
%   - deleted some old comments from the end of the function.
%   - Added output: structConfig (LI-7200 configuration structure)
%     This structure contains summary of all avg,min,max,std values for all traces
%     and the configuration info from GHG files.
% Mar 9, 2024 (Zoran)
%   - program now automatically detects the date column instead of testing
%     the file name which is unreliable. 
%   - added proper input parameters for fr_read_generic_file(....,'delimitedtext',0,8);
% Jan 26, 2024 (Zoran)
%   - added modifyVarNames = 1 in the call to fr_read_generic_data_file
% Jan 20, 2024 (Zoran)
%   - changed file loading from a custom program to using readtable
% Feb 14, 2023 (Zoran)
%   - added option for the program to find '7z.exe' (if it's available 
%     anywhere on Matlab's path. We keep it under Biomet.net\Matlab\Micromet     
%   - Added a check of OS. This works on PC only!

if ~ispc
    error('This function supports only Windows OS! For MacOS we need to replace 7z.exe with a MacOS version.')
end

pathToHF = fullfile(tempdir,'MatlabTemp');
if ~exist(pathToHF,'dir')
    mkdir(pathToHF);
end

% create filePath that points to the extraced *.data file
pathToGHGfile = fullfile(pathToGHGfile);                    % make sure the file separator is set properly
[~,fileName,~] = fileparts(pathToGHGfile);
filePath = fullfile(pathToHF,[fileName '.data']);

% Extract GHG data from the compressed files
% Note 7z.exe has to be visible to Matlab (Biomet.net?)
exeFile = which('7z.exe');
if isempty(exeFile)
    error('Cannot find 7z.exe');
end
sCMD = [exeFile ' x ' pathToGHGfile ' -o' pathToHF  ' -r -y'];
[~,~] = dos(sCMD);

% Detect the options to figure out where the date column is
opts = detectImportOptions(filePath,'FileType','delimitedtext');
indDate = find(strcmpi(opts.VariableTypes,'datetime'));
dateColNum = [indDate(1) indDate(1)+1];
timeInputFormat = {[],'HH:mm:ss:SSS'};

% Read and process the HF data
[EngUnits,Header,tv,dataOut] = fr_read_generic_data_file(filePath,'caller',[], dateColNum,timeInputFormat,[2 Inf],1,'delimitedtext',0,8);

% Read and process LI-7200 config file
[fileFolder,fileName] = fileparts(filePath);
configFileName = fullfile(fileFolder,'system_config','co2app.conf');
try
    fid = fopen(configFileName);
    strConfig = char(fread(fid,'char'))';
    fclose(fid);
    structConfig = li7200_str_to_struct(strConfig);
catch
    fprintf(2,'Error reading: %s\n',configFileName);
end
% The TimeVector is based on the last point in HF data rounded up
structConfig.TimeVector = fr_round_time(dataOut.TimeVector(end),'30MIN',2);
% this could be an alternative option (it would need to be rounded up):
%    structConfig.TimeVector = datenum(fileName,'yyyy-mm-ddTHHMMSS');

% Read and process LI-7700 status file
statusFileName = fullfile(fileFolder,sprintf('%s-li7700.status',fileName));
% Not all sites have LI-7700. Skip the next line if the 7700 status file is missing.
if exist(statusFileName,'file')
    [structConfig.Status,structConfig.structHeader] = read_LI7700_status_file(statusFileName);
end
% Add calculated stats for all structOut fields to structConfig
structConfig.Data = calcStructStats([],dataOut);

if exist(pathToHF,'dir')
    rmdir(pathToHF,'s');
end


% Helper functions
function [structStatus,structHeader] = read_LI7700_status_file(filePath)
    tbTst = readtable(filePath,'FileType','delimitedtext');
    tbTst = tbTst(:,5:end);
    structIn = table2struct(tbTst);
    structStatus = struct;
    structStatus = calcStructStats(structStatus,structIn);

    % Open fileName again and read it line by line. Extract the values
    
    fid = fopen(filePath);

    curLine = fgetl(fid);
    tmp = extract(curLine,digitsPattern);
    if ~isempty(tmp)
        structHeader.model = str2double(char(tmp(end)));
    else
        structHeader.model = NaN;
    end
    
    curLine = fgetl(fid);
    tmp = extract(curLine,digitsPattern);
    if ~isempty(tmp)
        structHeader.SN = str2double(char(tmp(end)));
    else
        structHeader.SN = NaN;
    end
    
    curLine = fgetl(fid);
    curLine = fgetl(fid);
    curLine = fgetl(fid);
    tmp = extract(curLine,digitsPattern);
    if ~isempty(tmp)
        structHeader.version.main = str2double(char(tmp(1)));
        structHeader.version.rev = str2double(char(tmp(2)));
        structHeader.version.subrev = str2double(char(tmp(3)));
    else
        structHeader.version.main = NaN;
        structHeader.version.rev = NaN;
        structHeader.version.subrev = NaN;
    end
        
    fclose(fid);

    
function structOut = calcStructStats(structOut,structIn)
    % Calculate avg,min,max,std on all structIn fields
    if isempty(structOut)
        structOut = struct;
    end

    allVars = fieldnames(structIn);
    for cntVars = 1:length(allVars)
        varName = char(allVars(cntVars));
        dataIn = [structIn.(varName)];
        structOut.(varName).avg = mean(dataIn);
        structOut.(varName).max = max(dataIn);
        structOut.(varName).min = min(dataIn);
        structOut.(varName).std = std(dataIn);
    end
    
    
        









