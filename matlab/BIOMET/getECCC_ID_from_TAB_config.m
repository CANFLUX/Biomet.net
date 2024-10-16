function stationID = getECCC_ID_from_TAB_config(SiteID,stNum)
% getECCC_ID_from_TAB_config - returns ECCC stationID from a TAB configuration file
% (see also: get_TAB_project_configuration)
%
%
% Zoran Nesic               File created:       Sep 14, 2024
%                           Last modification:  Sep 14, 2024

% Revisions:
%

arg_default('stNum',1)
stationID = 0;
try
    projectPath = fileparts(pwd);
    structProject = get_TAB_project_configuration(projectPath);
    stationID = structProject.sites.(SiteID).dataSources.eccc(stNum).stationsID;
catch
end
