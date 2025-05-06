function startup
%===================================================================
%
%        This is the standard startup.m file for Biomet.net
%
%===================================================================
%
%
% (c) Zoran Nesic           File created:        May 24, 2024
%                           Last modification:   May 24, 2024


fPath = mfilename('fullpath');
fPath = fileparts(fPath);
ind = find(fPath==filesep);
bnFolder = fPath(1:ind(end)); 

addpath(fullfile(bnFolder,'TRACEANALYSIS_FCRN_THIRDSTAGE'));
addpath(fullfile(bnFolder,'TRACEANALYSIS_TOOLS'));
addpath(fullfile(bnFolder,'TRACEANALYSIS_SECONDSTAGE'));
addpath(fullfile(bnFolder,'TRACEANALYSIS_FIRSTSTAGE'));
addpath(fullfile(bnFolder,'SoilChambers')); 
addpath(fullfile(bnFolder,'BOREAS'));
addpath(fullfile(bnFolder,'BIOMET'));      
addpath(fullfile(bnFolder,'NEW_MET'));      
addpath(fullfile(bnFolder,'MET'));    
addpath(fullfile(bnFolder,'New_eddy')); 
addpath(fullfile(bnFolder,'SystemComparison'));         % use this line on the workstations
addpath(fullfile(bnFolder,'Micromet'));


% add legacy paths if they exist
if exist('c:\UBC_PC_Setup\Site_specific','dir')
    path('c:\UBC_PC_Setup\Site_specific',path);      
end
if exist('c:\UBC_PC_Setup\PC_specific','dir')
    path('c:\UBC_PC_Setup\PC_specific',path);
end
% Run diarylog if available
if exist('diarylog','file')
    diarylog
end

% If the user wants to customize his Matlab environment he may create
% the localrc.m file in Matlab's main directory
if exist('localrc','file') ~= 0
    localrc
end

