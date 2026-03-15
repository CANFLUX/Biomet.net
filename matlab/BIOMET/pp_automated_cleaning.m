function pp_automated_cleaning(yearsIn,sitesIn,stages)
%  pp_automated_cleaning(yearsIn,sitesIn,stages) - run parallel computing on fr_automated_cleaning() 
%
% This function will attempt to run fr_automate_cleaning 
% using Parallel Computing Toolbox.
% If the toolbox is not available, it will run fr_automated_cleaning() 
% as usual (using 1 logical processor).
% 
% Inputs:
%   yearsIn             - the range of years to run the processing on (default: current year)
%   sitesIn             - a cell array of siteID-s. Default all sites in the project
%   stages              - processing stages (default: [1 2])
%
% 
%
% Zoran Nesic           File created:       Mar 15, 2026
%                       Last modification:  Mar 15, 2026

%
% Revisions:
%

% the defaults are:
% - all sites, current year, stages 1 and 2
arg_default('yearsIn',year(datetime))
arg_default('sitesIn',get_TAB_site_names)
arg_default('stages',[1 2])


% Check if Parallel Processing toolbox exists
allToolboxes = ver;
toolboxON = contains([allToolboxes(:).Name],'Parallel Computing');

% if there is no PC toolbox or there is only one site and one year of data, 
% call the regular fr_automated_cleaning:
if ~toolboxON || (isscalar(sitesIn) && isscalar(years))
    fprintf('Using regular cleaning\n');
    fr_automated_cleaning(yearsIn,sitesIn,stages);
    return
end

% If there are multiple sites, parallel process across the sites
% and return
if length(sitesIn) > 1 %#ok<*UNRCH>
    fprintf('Using parallel by sites\n');
    parfor cntSites = 1:length(sitesIn)
        fr_automated_cleaning(yearsIn,sitesIn(cntSites),stages);
    end
    return
end

% If there is a single site, parallel process across the years
% and return
if length(yearsIn) > 1
    fprintf('Using parallel by years\n');
    parfor cntYears = 1:length(yearsIn)
        fr_automated_cleaning(yearsIn(cntYears),sitesIn,stages);
    end
    return
end
