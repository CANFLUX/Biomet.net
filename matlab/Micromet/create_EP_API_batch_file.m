function create_EP_API_batch_file(siteID,startDay,endDay,EP_template,sourceDirMain,batchFileName)
% create_EP_API_batch_file - create a batch file that processes a range of days in EddyPro API
% create_EP_API_batch_file(siteID,startDay,endDay,EP_template,sourceDirMain,batchFileName)
% Arguments
%
%   siteID         - site ID
%   startDay       - First day that is being processed 
%   endDay         - Last day that is being processed
%   EP_template    - EddyPro templated to be used for processing
%   sourceDirMain  - Path to raw data: *sourceDirMain*/siteID/HighFrequencyData/raw/yyyy
%   batchFileName  - Name of the bach file that will be called from a Python environment
%
%
%
% Zoran Nesic               File created:       Aug 14, 2025
%                           Last modification:  Aug 14, 2025

% Revisions
%

fid = fopen(batchFileName,'w');
if fid<0 
    error ('File: %s cannot be created. Check the path.\n');
end

startDay = datetime(startDay,"Format","uuuu-M-d");
endDay   = datetime(endDay  ,"Format","uuuu-M-d");

%fid=1;
sourceDirStart = fullfile(sourceDirMain,siteID,'HighFrequencyData','raw',string(year(datetime(startDay))));
sourceDirStart = regexprep(sourceDirStart,'\','/');

sourceDirEnd   = fullfile(sourceDirMain,siteID,'HighFrequencyData','raw',string(year(datetime(endDay))));
sourceDirEnd   = regexprep(sourceDirEnd,'\','/');

fprintf(fid,'ECHO Running Matlab-generated Python call \n');
% python eddyProAPI.py --siteID UQAM_3 --biometUser True --eddyProStaticConfig Templates/ClosedPathStandard.eddypro --dateRange 2025-4-10 2025-7-21 --sourceDir U:/Sites/UQAM_3/HighFrequencyData/raw/2025 --runMode 2
fprintf(fid,'python eddyProAPI.py --siteID %s --biometUser True --eddyProStaticConfig %s --dateRange %s %s --sourceDir %s %s --runMode 2\n',siteID,EP_template,startDay,endDay,sourceDirStart,sourceDirEnd);
fprintf(fid,'ECHO Finished with Python \n');
fclose(fid);
