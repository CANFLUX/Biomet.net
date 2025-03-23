function allFiles = sort_EddyPro_files(wildCardPath)  %(inputPath,wildCard)
%  sort_EddyPro_files - produces a sorted list of EddyPro file names in inputPath folder
%
% Inputs:
%   wildCardPath       - a path with a wildcard to a folder with EdduPro files
%
% Outputs
%   allFiles            - list of file matching wildCardPath sorted by time (see below)
%
%
%
% The EddyPro recalculation outputs from different runs can often reside in the
% same folder even if they cover the same days of data. In such cases, the safest
% way to approach the conversion of the files to data base (if we are starting 
% reprocessing from scratch and there is no file progress list (see fr_EddyPro_database.m
% for the usage of progress lists)) is to process the files starting from the 
% dates of re-processing. EddyPro usually time-stamps the output files so
% the function uses these time-stamps to sort the files in ascending order
% so the data is processed properly.
%
% Note:
%   This sorting is applied to _full_output_ and _biomet_ files saved 
%   using default EP output file names (with time stamps). The other files
%   will be sorted in the ascending order based on their "modification dates".
%
% (c) Zoran Nesic                   File created:       Mar 22, 2025
%                                   Last modification:  Mar 22, 2025
%

% Revisions:
%

% Load up all files
allFiles = dir(wildCardPath);
fileNames = {allFiles(:).name};

try
    % To be able to sort the files by the time of re-processing
    % the files have to be in a one of these two formats
    % 1. '*_full_output_yyyy-mm-ddThhmmss_???.csv' or '*_biomet_yyyy-mm-ddThhmmss_???.csv'
    % 2. '*_EP-Summary.txt'
    % if not, the files be sorted out by the file time-stamp which is probably
    % not the bestj but, still better or equal to loading them as the OS sends them
    patTimeStamp = regexpPattern('[12]\d\d\d-\d\d-\d\dT\d{6}');
    patFulloutput = regexpPattern("(_full_output_|_biomet_)");
    patFileName = regexpPattern('_(adv|exp).csv');
    % find if all file names that end with this pattern
    if all(endsWith(fileNames(:),patFulloutput+patTimeStamp+patFileName))
        % Then extract the time stamps only and sort the file names based on those
        cTimestamps = extract(fileNames(:),patTimeStamp);
        [~,indTimestamps] = sort(cTimestamps);
        allFiles = allFiles(indTimestamps);
    elseif all(~endsWith(fileNames(:),'_EP-Summary.txt','IgnoreCase',true))
        % check if the files are NOT EP-Summary.txt type. 
        % If they are not, sorte them by the file OS time-stamp
        [~,indTimestamps] = sort(cell2mat({allFiles(:).datenum}));
        allFiles = allFiles(indTimestamps);
    else
        % These are the summary files so they don't need to be sorted
        % They all contain one day of data each and are unique.
        %fprintf('Summary files only!\n')
    end
catch ME
    fprintf(2,'    Failed to sort EddyPro files. \n\n\n');
    error ME
end
