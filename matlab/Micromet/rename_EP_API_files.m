function cntFiles = rename_EP_API_files(siteID,inputPath,outputPath,flagOverwrite)
%  rename_EP_API_files - Renames EddyPro files produced by June Skeeter's API
%
%
% Inputs:
%   siteID              - siteID
%   inputPath           - folder with API outputs
%   outputPath          - output folder. Files with the same names will be overwritten!
%
% Notes:
% EddyPro API currently (Mar 2025) produces file names that are not
% the same as the ones produced by the GUI version of EddyPro. 
% To enable the use of the same file name filtering on the API files that
% we do on the regular EddyPro files, the files need to be renamed.
%
% Example of before and after:
%      eddypro_group_9_fcc_full_output_2024-09-27T102955_adv.csv
%      eddypro_BB_20201008_20210921_full_output_2024-09-27T102955_adv.csv
%
%
% (c) Zoran Nesic                   File created:       Mar 19, 2025
%                                   Last modification:  Mar 19, 2025
%

arg_default('flagOverwrite',0);

optionsFileRead.flagFileType = 'fulloutput';
allFiles = dir(fullfile(inputPath,'*_full_output_*.csv'));
nFiles = length(allFiles);
for cntFiles = 1:nFiles
    fileName = fullfile(allFiles(cntFiles).folder,allFiles(cntFiles).name);
    % strGroupNumber = char(extractBetween(allFiles(cntFiles).name,'eddypro_group_','_fcc_full_output'));
    strDate = char(extractBetween(allFiles(cntFiles).name,'_full_output_','_adv'));
    % load file so we can extract the dates
    [~, ~,~,outStruct] = fr_read_EddyPro_file(fileName,[],[],optionsFileRead);
    tv_dt = datetime(outStruct.TimeVector,'ConvertFrom','datenum');
    newFileName = ['eddypro_' siteID '_' char(datetime(tv_dt(1),'format','yyyyMMdd')) ...
                   '_' char(datetime(tv_dt(end),'format','yyyyMMdd')) '_full_output_' ...
                   strDate '_adv.csv'  ];
%                   strDate '_grp' strGroupNumber '_adv.csv'  ];    
    fprintf('(%3d/%3d) - %s\n',cntFiles,nFiles,allFiles(cntFiles).name);
    fprintf('            %s\n',newFileName);
    newFileNameFull = fullfile(outputPath, newFileName);
    fileExist = exist(newFileNameFull,'file');
    if fileExist && ~flagOverwrite
        fprintf(2,'    Skipping. %s already exists at the destination.\n',newFileName);
        fprintf(2,'              (To force overwrite use flagOverwrite=1.) \n');
    elseif fileExist && flagOverwrite
        fprintf(2,'    Overwriting: %s\n',newFileName);
        copyfile(fileName,newFileNameFull)
    else
        copyfile(fileName,newFileNameFull)
    end
end