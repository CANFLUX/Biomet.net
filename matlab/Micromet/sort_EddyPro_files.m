function sortedNames = sort_EddyPro_files(inputPath,wildCard)
%  sort_EddyPro_files - produces a sorted list of EddyPro file names in inputPath folder
%
%
% Inputs:
%   inputPath           - folder with EdduPro _full_output_ files
%   wildCard            - optional, pattern to search for 
%                         the default is: 'eddypro_*_full_output_*.csv'
%                         The time stamps have to be between '_full_output_' and '_adv'
%
%
%
% (c) Zoran Nesic                   File created:       Mar 19, 2025
%                                   Last modification:  Mar 19, 2025
%

% Revisions:
%

arg_default('wildCard','eddypro_*_full_output_*.csv')

allFiles = dir(fullfile(inputPath,wildCard));
strDate = extractBetween({allFiles(:).name},'_full_output_','_adv');
[~,indSorted] = sort(strDate);

sortedNames = allFiles(indSorted);

