function view_CERF(dateRange,siteIDs,flgPause)
% view_CERF(dateRange,siteIDs)
%
% "view_sites" for all CERF sites
%
% Examples: 
% view_CERF (plots CERF1 and 2 data for the last 10 days)
% view_CERF(datenum(2026,1,1):now) (plots CERF1 and 2 data for the year 2026 to today)
% view_CERF([],{'CERF1'}) (plots CERF1 data for the last 10 days)
%
% Zoran Nesic           File created:       Sep 16, 2026
%                       Last modification:  Sep 16, 2026

% Revisions
%

arg_default('dateRange',now-10:now)
arg_default('siteIDs',{'CERF1','CERF2'})
arg_default('flgPause',1)

% get the year and the index. The index is DOY+1 to match
% view_sites indexing.
[yearX,~] = datevec(dateRange(end));
indDataRange = dateRange - datenum(yearX,1,1);

% cycle through the sites
close all
for cntSite = 1:length(siteIDs)
    siteID = char(siteIDs{cntSite});
    cerf_pl(indDataRange,yearX,siteID,flgPause);
    if flgPause == 1
        runAndWait
    end
end
     
    
function runAndWait    %(sFunction)

% evalin('caller',sFunction);   
title_figure('Close all?')
pause
close all

%------------------------------

function title_figure(title_1)
    figure
    axes
    set(gca,'box','off','position',[0 0 1 1])
    text(0.1,0.5,title_1,'fontsize',28)
    drawnow
    