
% ==========================================================
%  Setup parameters

kill
cd E:\Pipeline_Projects
% ----- Create a new project
% The input parameters
allNewSites = {'BR-Npw','CA-BOU'};
dbID = 'AMF';
sourcePath = 'E:\Pipeline_Projects\Ameriflux_raw';
projectPath = 'E:\Pipeline_Projects\Ameriflux_CH4_partial';
flagNewSites = false;
result = convertAmeriflux2TAB(allNewSites,dbID,sourcePath,projectPath,flagNewSites);

return
%-----------------------------------------
% Add one more site
allNewSites = {'BRT-Npw'};
dbID = 'AMF';
sourcePath = 'E:\Pipeline_Projects\Ameriflux_raw';
projectPath = 'E:\Pipeline_Projects\Ameriflux_CH4_partial';
flagNewSites = true;
result = convertAmeriflux2TAB(allNewSites,dbID,sourcePath,projectPath,flagNewSites);


return
