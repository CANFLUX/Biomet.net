function ax = ta_plot_parents(figNum,trace_str,trace_name)
% Plot all parent traces for the given trace
%
% Input:
%   figNum          - figure number. If missing a new figure will be created
%   trace_str       - a structure array of all traces 
%   trace_name      - variable name of the trace to plot
%
% Output:
%   ax              - axes handle for the plot. It can be used to link
%                     additional axes so the user can zoom in all figures 
%                     at the same time.
%
% Example:
%   Plot trace 'T_SONIC' from the first stage clean data
%   and all its parents.
%       trace_str = fr_cleaning_siteyear(2023,'DSM',1);
%       ax = plot_parents(2,trace_str,'T_SONIC');
%
%       
% Zoran Nesic                       File created:       Apr 17, 2024
%                                   Last modification:  Sep  5, 2024
%

% Revisions:
%
% Oct 10, 2024 (Paul)
%   - Asthetic changes. For plots with many parents, the use of 1/2 screen
%       height made the figure really bunched up. Figure size is now
%       dependent on the number of parents.
%   - To highlight where parents don't overlap with missing data in the
%       dependent, two different point sizes have been implemented.
% Sep 5, 2024 (Zoran)
%   - Bug fix: it wouldn't plot traces with no parents because tv trace was
%     indexed improperly.
%   - removed an orphaned "clear" statement
%   - added 'var' to exist statement
% Jun 3, 2024 (Zoran)
%   - adjusted the figure size 
%

    if ~exist('figNum','var') || isempty(figNum)
        figNum = figure;
    end
    
    % 
    [~,indTraceName,indParents] = findParents(trace_str,trace_name);
    
    %indTraceName = find_trace(trace_str,trace_name);
    sLegend = {['  0 - SELF (' trace_name ')']};
    %allParents = [];
    indMissingPoints = isnan(trace_str(indTraceName).data_old) | trace_str(indTraceName).data_old==-9999;
    allParents(:,1) = double(indMissingPoints)*0;
    allParents(~indMissingPoints,1) = NaN;
    
    for cParent = 1:length(indParents)
        allParents(:,cParent+1) = isnan(trace_str(indParents(cParent)).data)+cParent-1;
        allParents(~isnan(trace_str(indParents(cParent)).data),cParent+1) = NaN;
        sLegend{cParent+1} = sprintf('%3d - %s',cParent,trace_str(indParents(cParent)).variableName);
    end
    tvd = datetime(trace_str(indTraceName).timeVector,'convertfrom','datenum');
    minMax = trace_str(indTraceName).ini.minMax;

    % Position the figure to be 1/2 to 3/4 of screen height and stretched almost all the width
    sSize = get(0,'ScreenSize');
    sSize(4) = sSize(4)-30;     % account for the Windows toolbar at the bottom
    sLength = sSize(3)-100;
    
    if length(indParents)<=10
        devisor = 2;
    elseif length(indParents)<=20
        devisor = 1.5;
    else
        devisor = 1.25;
    end
    sHeight = round(sSize(4)/devisor);
    sXpos = 50;
    sYpos = 100;
    figure(figNum)
    set(figNum,'outerpos',[sXpos sYpos sLength sHeight]);

    
    x = [trace_str(indTraceName).data_old trace_str(indTraceName).data] ;
    x(x==-9999) = NaN;
    tiledlayout(2,1,"TileSpacing","none")
    nexttile
    p1 = plot(tvd,x,'.','MarkerSize',20);
    hold on
    % Add minMax
    vAx = xlim;
    line(vAx, [minMax(1) minMax(1)],'linewidth',5)
    line(vAx, [minMax(2) minMax(2)],'linewidth',5)
    hold off
    legend(p1,'Raw','Clean','Location','eastoutside','Interpreter','none')
    set(gca,'XtickLabel',{})
    ax(1) = gca; 
    title(trace_name,'Interpreter','none')
    ylabel(trace_str(indTraceName).ini.units)
    nexttile

    % plot(tvd,allParents(:,end:-1:1),'.','MarkerSize',20)
    ph1 = plot(tvd(~indMissingPoints),allParents(~indMissingPoints,end:-1:1),'.','MarkerSize',20);
    hold on; box on
    % plot(tvd,allParents(:,1),'.','MarkerSize',20)
    ph2 = plot(tvd(indMissingPoints),allParents(indMissingPoints,end:-1:1),'.','MarkerSize',10);
    for i=1:length(ph1)
        set(ph2(i),'color',ph1(i).Color)
        if i==length(ph1)
            set(ph2(i),'MarkerSize',20)
        end
    end
    hold off
    ax(2)=gca;
    ylabel([trace_name ' - parents'],'Interpreter','none')
    legend(sLegend(end:-1:1),"Interpreter","none",'Location','eastoutside')
    ylim([-1 max(allParents(:))+1])
    linkaxes(ax,'x')
    zoom on

end

%-----------------------------------------------------------------------
% Local function to extract indexes of all parent variables (indParents)
% as well as the index of the traces with variableName == cVarName
%
% Input:
%   trace_str       - a structure array of all traces 
%   cVarName        - variable name of the trace 
% Output:
%   varNames        - cell array of all parent variableNames
%   varInd          - index of the cVarName (cVarName == trace_str(varInd).variableName
%   indParents      - index of all parent traces 
%

function [varNames,indVar,indParents] = findParents(trace_str,cVarName)
    indVar = 0;
    for cntTraces = 1:length(trace_str)
        if strcmp(trace_str(cntTraces).variableName,cVarName)
            indVar = cntTraces;
            break
        end
    end
    if indVar == 0
        indParents = [];
        varNames = [];
        indVar = [];
        return
    end
    indParents = trace_str(cntTraces).ind_parents;
    varNames = {trace_str(indParents).variableName};
end





