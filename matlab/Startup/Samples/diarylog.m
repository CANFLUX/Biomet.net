% diarylog.m  
% 
% Last edit: Jan 4, 2022 (Zoran)
%
% Comments: 
%           This script does create a log file in the \matlab\ subdirectory. The file name
%       is in the form: YYMMDD.LOG  . This file will contain all the input/outputs during
%       all the Matlab sessions for that day.
%
%   Zoran Nesic, BIOMET, UBC
%

% Revisions:
%
% Nov 22, 2023 (Zoran)
%   - added Matlab proces PID to the output.
% Feb 28, 2022
%   - added userData.instance. This variable will be used to 
%     indicate when a particular instance of Matlab has closed.
%     Matlab function "finish.m" will be used for that.
% Jan 4, 2022 (Zoran)
%   - Removed displaying Matlab version. It was taking too much space
%   - Improved file name handling
%   - improved Timer object handling and naming (see also fr_updatediary
%

% stop the old diary if it's running
diary off
% stop the timer function if running
t = timerfind('Name','diarylog');
if ~isempty(t)
    delete(t)
end

% PAOA001 computer runs many scheduled Matlab scripts so it's better to
% keep all the logs in the one daily file. Other PCs open one log file per
% Matlab session
pcName = fr_get_pc_name;
if strcmpi(pcName,'PAOA001')
    diaryFileName = fullfile('d:\met-data\log\matlab\', [datestr(now,'yyyymmdd') '.log']);
    diary(diaryFileName);
else
    diaryFileName = fullfile('d:\met-data\log\matlab\', [datestr(now,30) '.log']);
    diary(diaryFileName);
end
    
verMat = ver;
v = [];
for i=1:length(verMat)
    if strcmpi(verMat(i).Name,'MATLAB')
       v = verMat(i).Release;
    end
end

matlabInstance = datestr(now,30);
disp('********************************************************************************');
fprintf('Start at: %s\n', datestr(now));
fprintf('Matlab instance: %s v%s\n',matlabInstance,v);
fprintf('PID: %d\n',feature('getpid'));
disp('********************************************************************************');

% Auto-save diary file 5 minutes
% Set a new timer.
t = timer('timerfcn',@fr_updatediary,...
'period',300,...
'ExecutionMode','fixedRate',...
'Name','diarylog');

start(t)

% Keep the timer handle under UserData
UserData = get(0,'UserData');
UserData.DiaryTimer = t; 
% Keep the Diary file name under user data too
% It will be used to refresh the file name
% This is important because the diary can be hijacked
% by other Biomet programs that run in the Scheduler
UserData.DiaryFileName = get(0,'DiaryFile');
% record the Matlab instance:
UserData.instance = matlabInstance;
set(0,'UserData',UserData);
diary on
clear x Year Month Day Minutes Hour UserData i pcName v


