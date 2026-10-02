function result = isTimeVectorType(strName)
%  result = isTimeVectorType(strName) - returns true if strName matches 
%                                       one of database trace names of datatype 8 (time vector)
%
% 
% Input
%   strName         - character vector or a cell array with file names: {'PA_1_1_1','clean_tv'}
%
% Example:
%   s = dir('v:\Database\2023\HOGG\Flux'); 
%   {s(isTimeVectorType({s.name})).name}'
% Returns 3 file names that contain datatype 8 (datenum type):
%      3×1 cell array
%       {'TimeVector'}
%       {'clean_tv'  }
%       {'recalcTime'}
%
% Zoran Nesic           File created:       Oct  1, 2026
%                       Last modification:  Oct  1, 2026
%

% Revisions
%


cellDefaultTimeVectors = {'clean_tv','TimeVector','sample_tv','recalcTime','Time_vector'};
result = contains(strName,cellDefaultTimeVectors,IgnoreCase=true);
