function allSites = get_TAB_site_names
% get all siteIDs in a TAB project. 
%
%
% Output:
%   allSites        - a 1-row cell array of siteIDs
%
%
% Zoran Nesic           File created:       Aug  6, 2025
%                       Last modification:  Aug 18, 2025

% Revisions
%
% Aug 18, 2025 (Zoran)
%   - Added an option to test if this project is running on the server or
%     on one of the recalculation PC. The recalc PCs would have an additional
%     field in structProjects called "server" which contains all the info
%     from the server's main get_TAB_project_configuration. In case
%     that allSites need to be extracted, they'll be in structProject.server 
%     structure. 

structProject = get_TAB_project;
if isfield(structProject,'server')
    allSites = fieldnames(structProject.server.sites);
else
    allSites = fieldnames(structProject.sites);
end
allSites = allSites(:)';