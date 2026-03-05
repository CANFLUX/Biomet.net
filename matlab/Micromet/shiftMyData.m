function shiftedData = shiftMyData(clean_tv,originalData,offsetStartDate,offsetEndDate,offsetMinutes)
% Revisions: 
%   Rosie Howard (4 March 2026):
%       Adapted from site-specific versions (notes below)

%   Generalized time-shift function for Biomet to use at any site, applied
%   in first stage cleaning, given:
%       
%   Inputs:
%       clean_tv:           time vector
%       originalData:       variable to be shifted in time
%       offsetStartDate:    datetime to begin shift
%       offsetEndDate:      datetime to end shift
%       offsetMinutes:      length of time to shift data by in minutes,
%                           positive = shift forwards, negative = shift
%                           backwards

% Example of use in evaluate statement (first stage): 
%       Evaluate = 'LW_IN_1_1_1 = shiftMyData(clean_tv,LW_IN_1_1_1,datenum(2021,1,1,0,0,0),datenum(2021,11,07,03,00,0),-60);'
%       Will shift LW_IN_1_1_1 between very start of 2021 and 3am on 7th November
%       2021 BACKWARDS by 60 minutes, i.e., 3:00am data point will be moved to 2:00am
%   

%---------------------------
% OLD Memo:   Adapted from Tzu-Yi Lu script. Applied to Young and Hogg 
%         sites to fix 1-hour offset from daylight savings
% OLD site-specific revisions: 
% Feb 4, 2023 (Tzu-Yi)
%    - added memo (details about timestamp lag problem)
%    - removed the 'run_std_dev' part from this script.
% Mar 23, 2023 (Darian)
%    - Altered script inputs to allow specifications for offset date and 
%    # of 30-minute offsets.
%---------------------------

offset = offsetMinutes/30; 
tsc=find(clean_tv>=offsetStartDate & clean_tv<=offsetEndDate); 
if ~isempty(tsc) & offset < 0   % negative offset = shift backwards
    originalData(tsc(1:end+offset)) = originalData(tsc(1-offset:end));
    shiftedData=originalData;
elseif ~isempty(tsc) & offset > 0   % positive offset = shift forwards
    originalData(tsc(1+offset:end)) = originalData(tsc(1:end-offset));
    shiftedData=originalData;
else
    shiftedData=originalData;
end