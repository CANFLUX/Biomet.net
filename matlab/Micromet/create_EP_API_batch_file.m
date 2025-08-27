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
%                           Last modification:  Aug 26, 2025

% Revisions
%
% Aug 26, 2025 (Zoran)
%   - Improvements: moved more lines from main_EP_API_script.bat into 
%     the batch file:batchFileName  created by this function. 

structProject = get_TAB_project;
ind=strfind(structProject.EPAPIpath,':');
if isfield(structProject,'EPAPIpath') && ~isempty(ind)
    diskName = structProject.EPAPIpath(1:ind(1));
else
    error('Field structProject.EPAPIpath does not exist or it does not contain disk name (c:...).');
end


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
fprintf(fid,'@%s \n',diskName);
fwrite(fid,['@cd ' structProject.EPAPIpath newline],"uchar");
fprintf(fid, '@CALL .venv\\Scripts\\activate \n');
%@CALL C:\Projects\Scripts\EP_API_call.bat
% python eddyProAPI.py --siteID UQAM_3 --biometUser True --eddyProStaticConfig Templates/ClosedPathStandard.eddypro --dateRange 2025-4-10 2025-7-21 --sourceDir U:/Sites/UQAM_3/HighFrequencyData/raw/2025 --runMode 2
fprintf(fid,'python eddyProAPI.py --siteID %s --biometUser True --eddyProStaticConfig %s --dateRange %s %s --sourceDir %s %s --runMode 2\n',siteID,EP_template,startDay,endDay,sourceDirStart,sourceDirEnd);
fprintf(fid,'@CALL .venv\\Scripts\\deactivate \n'); 
fprintf(fid,'ECHO Finished with Python \n');
fclose(fid);
