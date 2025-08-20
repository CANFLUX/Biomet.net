function [tv,tv_dt] = convert_PCtime2UTC
% convert_PCtime2UTC - Converts current PC time to UTC time. Returns both datetime and datenum outputs.
%
% Inputs        - none
% Outputs
%   tv          - UTC time as datenum
%   tv_dt       - UTC time as datetime
%
%
% Zoran Nesic               File created:       Aug 20, 2025
%                           Last modification:  Aug 20, 2025

% Revisions
%
tv_dt = datetime(datetime,'TimeZone','Local'); 
tv_dt.TimeZone = 'UTC';
tv = datenum(tv_dt);
