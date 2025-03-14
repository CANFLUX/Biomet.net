function ET_export(yearIn,siteID,pathIn,pathExport)
% ET_export -> exports ET values for one site for a range of years
%
%   yearIn      -    one year or a range of years
%   siteID      -    site ID (char)
%   pathIn      -   path to the database input folder. Default the third stage folder for siteID
%   pathExport  -   path to the export folder. Default 'p:\temp')   
%
% Examples (the two lines are equivalent!):
%       ET_export(2021:2023,'HOGG','p:\database\yyyy\HOGG\Clean\ThirdStage','p:\temp')
%       ET_export(2021:2023,'HOGG')
%
% Zoran Nesic           File created:       Feb 7 ,2024
%                       Last modification:  Feb 7, 2024



% yearIn = 2021:2023;
% siteID = 'HOGG';

path3rd_def = fullfile('p:\Database\yyyy',siteID,'Clean\thirdStage');
pathExport_def = 'p:\temp';
arg_default('pathIn',path3rd_def)
arg_default('pathExport',pathExport_def)


tv = read_bor(fullfile(pathIn,'clean_tv'),8,[],yearIn);
LE = read_bor(fullfile(pathIn,'LE')      ,[],[],yearIn);
TA = read_bor(fullfile(pathIn,'TA_1_1_1'),[],[],yearIn);
ET =  LE ./ Latent_heat_vaporization(TA);

% filter some bad data if needed
% indBad = ET<0;  % I am not sure this is an appropriate filter so use it just as an example.
% ET(indBad) = NaN;

% % save the result in ThirdStage (this step will only run on vinimet because of the read-only settings for everyone else
% fileName = fullfile(sprintf('v:/Database/%d/YOUNG/Clean/ThirdStage',yearIn(1)),'ET');
% save_bor(fileName,1,ET);

% Save csv file
tic;
TIMESTAMP_START = datestr(fr_round_time(tv-1/48),'yyyymmddHHMM');
TIMESTAMP_END = datestr(fr_round_time(tv),'yyyymmddHHMM');
T = table(TIMESTAMP_START,TIMESTAMP_END,ET);
fileName = ['ET_' siteID sprintf('_%d-%d.csv',yearIn(1),yearIn(end))];
writetable(T,fullfile(pathExport,fileName));
fprintf('File: %s exported to: %s in %6.1f seconds.\n',fileName,pathExport,toc)
