function take_Phenocam_picture(siteID,netCam_Link,pictureTakingHours)
% take_Phenocam_picture - calls WebCam_Picture.m with appropriate input
% parameters.
%
% (c) Zoran Nesic               File created:       May  6, 2024
%                               Last modification:  May  6, 2024

% Revisions
%
arg_default('pictureTakingHours',5:22);
pthSites = biomet_sites_default;

out_path = fullfile(pthSites,siteID,'Phenocam',[siteID '_']);

WebCam_Picture(pictureTakingHours,netCam_Link,out_path);
