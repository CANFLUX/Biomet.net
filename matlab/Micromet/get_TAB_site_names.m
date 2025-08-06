function allSites = get_TAB_site_names
% get all siteIDs in a TAB project. 
%
%
% Output:
%   allSites        - a 1-row cell array of siteIDs
%
%
% Zoran Nesic           File created:       Aug  6, 2025
%                       Last modification:  Aug  6, 2025

% Revisions
%
structProject = get_TAB_project;
allSites = fieldnames(structProject.sites);
allSites = allSites(:)';