function [Status1,Message1,MessageID1] = ClimateStation_movefile(fid)
% ClimateStation_movefile - Moves ClimateStation data files from the DropBox folder
%                           into the c:\sites\ubc\csi_net folder. Files are
%                           date-stamped. It uses fr_movefile to
%                           safely handle files with the same names.
%                  
%
% (c) Zoran Nesic       File created:   Oct  6, 2014
%                       Last modified:  Oct 20, 2024


% Revisions
%
% Oct 20, 2024
%   - changed the filePath to the new destination.
% Aug 3, 2024 (Zoran)
%   - finally remembered to change the source folder-name for the
%   ubcraw.dat file. They've been on the T: drive for a while now.
% Nov 18, 2023 (Zoran)
%   - Added an optional fid input parameter.
% Nov 2, 2023 (Zoran)
%   - Removed modal messages that could lock the Matlab when running in the
%     Task Scheduler.
% Aug 7, 2023 (Zoran)
%   - Added renaming of the CR1000 files.
% Jan 4, 2022 (Zoran)
%   - added try-catch statement
% April 19, 2012 (Nick)
%   -file extensions up to 256 now available

% for compatibility by default print in command window
arg_default('fid',1)

fprintf(fid,'========== Started:%s (%s) =========\n',mfilename,datestr(now));
try
    fileName = 'UBRAW.dat';
    
    %filePath = 'D:\Sites\Sync\Sync\ClimateStation_to_UBC'; % Changed Aug 3, 2024
    % filePath = 'T:\Research_Groups\BioMet\ClimateStation'; % chaged Oct 20, 2024
    filePath = '\\annex001\Climate-UBC';
    destinationPath = 'D:\SITES\ubc\CSI_NET';
    fileExt = datestr(now,30);
    fileExt = fileExt(1:8);

    sourceFile       = fullfile(filePath,fileName);
    destinationFile1 = fullfile(destinationPath,[fileName(1:end-3) fileExt]);
    [Status1,Message1,MessageID1] = fr_movefile(sourceFile,destinationFile1);
%     if Status1 ~= 1
%         uiwait(warndlg(sprintf('Message: %s\nSource path: %s\nDestination path: %s',...
%             Message1,sourceFile,destinationFile1),'Moving DropBox files to d:\Sites failed','modal'))
%     end %if
catch
    fprintf(fid,'*** Error in: %s ***\n',mfilename);
end
try
    fileName = 'TF-ClimateStation_CR1000_Clim_30m.dat';
    filePath = 'D:\Sites\ubc\CSI_NET';
    destinationPath = 'D:\SITES\ubc\CSI_NET\OLD';
    fileExt = datestr(now,30);
    fileExt = fileExt(1:8);

    sourceFile       = fullfile(filePath,fileName);
    destinationFile1 = fullfile(destinationPath,[fileName(1:end-3) fileExt]);
    [Status1,Message1,MessageID1] = fr_movefile(sourceFile,destinationFile1);
%     if Status1 ~= 1
%         uiwait(warndlg(sprintf('Message: %s\nSource path: %s\nDestination path: %s',...
%             Message1,sourceFile,destinationFile1),'Moving CR1000 files to d:\Sites failed','modal'))
%     end %if
catch
    fprintf(fid,'*** Error in: %s ***\n',mfilename);
end
fprintf(fid,'Finished: %s (%s)\n',mfilename,datestr(now));


        
        