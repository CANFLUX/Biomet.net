function DBASE_PATH = biomet_path(yearIn,siteID,type_of_measurements)
%
% Create paths for different sites/years/types of measurements.
%
% inputs
%       Year            =1999   ' for 1996->1999 period
%                       =xxxx   ' for years >=2000, default is the current year
%                       =yyyy   ' for a wildcard (it will return 'yyyy' while a year 
%                               ' would otherwise go)
%       SiteID          'XX'    where xx stands for 'CR', 'JP', 'BS', 'PA' sites
%                               default is obtained by running FR_current_site_id.m
%       type_of_measurements    = 'fl' for flux, 'cl' for climate, 'ch' for chambers
%
% If a function biomet_database_default exists in the path that returns the localtion
% of the database it will be used, otherwise it is assumed that the database it in
% '\\annex001\database'
%
% (c) Zoran Nesic               File created:             , 1998
%                               Last modification:  Mar 18, 2025
%

% Revisions:
%
%   Mar 18, 2025 (Zoran)
%     - Bug fix: for the files that contained data from before 1999 the program 
%       handled the database structure differently (all data before 1999 was pushed into a 
%       one folder == 1999). This settings should've applied only for the 
%       legacy Biomet sites. See the variable "legacySites" below.
%       That is how it works now. The setting does not apply for any other sites.
%   Aug 26, 2022 (Zoran)
%    - fixed both this function and arg_default so they can work together.
%    - cleaned up syntax
%   Apr 11, 2022 (Zoran)
%   - made the program compatible with MacOS by using setFolderSeparator()
%   Jul 2, 2010
%   -checks to see if UBC_TOTEM is the siteId before changing years <1996
%   to 1999 (since Totem data exists back to 1990)
%   Feb 2, 2004
%       - added use of biomet_database_default
%   Feb 7, 2002
%       - added option to call any folder name eg. biomet_path(2002,'cr','Clean\SecondStage')
%   Jun 11, 2001
%       - added profile type and folder
%   Jan 10, 2000
%       - added an option of inserting a wildcard: yyyy. See the syntax of read_bor and
%         the tutorial file read_bor_primar for a proper usage.
%   Nov 24, 2000
%       - added 'highlevel' as possible type of measurement

% if exist('type_of_measurements') ~= 1 | isempty(type_of_measurements) %#ok<*OR2>
%    type_of_measurements = ''; 
% end
arg_default('type_of_measurements','')
legacySites = {'BS','PA','JP','CR','UBC_TOTEM'}; % These are sites that are handled differently for yyyy < 1999

[yearNow,~,~]=datevec(now);
arg_default('yearIn',yearNow)
arg_default('siteID',fr_current_siteID); % if SiteID is missing/empty assume siteID

if ismember(upper(siteID),legacySites)
    % if this is one of the legacy sites do the special processing
    if ~ischar(yearIn)
        if yearIn < 1996 & ~strcmpi(siteID,'UBC_TOTEM') %#ok<*AND2>
            error 'Wrong input: (year<1996)'
        elseif yearIn <= 1999 & strcmpi(type_of_measurements,'HIGH_LEVEL') == 0 ...
                           & ~strcmpi(siteID,'UBC_TOTEM')
            yearIn = 1999;                        % for non high level and years 1997 -> 1999 use year 1999
        end
    end
end

if exist('biomet_database_default','file')
   DBASE_DISK = biomet_database_default;
else
   DBASE_DISK = '\\annex001\DATABASE';
end

switch upper(type_of_measurements)
    case 'CL', folderName = 'Climate';
    case 'CH', folderName = 'Chambers';
    case 'FL', folderName = 'Flux';
    case 'PR', folderName = 'Profile';
    case 'MISC', folderName = 'Misc';
    case 'HIGH_LEVEL', folderName = 'Clean\ThirdStage';
    otherwise, folderName = type_of_measurements;
end

DBASE_PATH = fullfile(DBASE_DISK, num2str(yearIn), upper(siteID), folderName, filesep);
% to keep compatibility with MacOS, adjust folder separators
DBASE_PATH = setFolderSeparator(DBASE_PATH);
