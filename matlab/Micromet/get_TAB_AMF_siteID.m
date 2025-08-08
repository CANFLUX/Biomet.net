function siteIDamf = get_TAB_AMF_siteID(structProject,siteID)
% Extract AMF siteID from structProject and site: siteID
% 
%
%
% Zoran Nesic           File created:       Aug  8, 2025
%                       Last modification:  Aug  8, 2025

% Revisions
%

%siteIDamf = siteID;
if ~isfield(structProject,'sites')
    error('Field "sites" does not exist in structProject!');
end
if ~isfield(structProject.sites,siteID)
    error('Field %s does not exist in structProject.sites!',siteID);
end
if ~isfield(structProject.sites.(siteID),'Metadata')
    error('Field "Metadata" does not exist in structProject.sites.%s!',siteID);
end
if ~isfield(structProject.sites.(siteID).Metadata,'AmerifluxID')
    error('Field "AmerifluxID" does not exist in structProject.sites.%s.Metadata!',siteID);
end


siteIDamf = structProject.sites.(siteID).Metadata.AmerifluxID;

