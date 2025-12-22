function shadeBadZone(yLimits)
% shadeBadZone(yLimits) - shade the out-of-limits zones of a plot
%
% Inputs
%   yLimits - [axesMin axesMax]
%
%
%
% Zoran Nesic               File created:       Dec 22, 2025
%                           Last modification:  Dec 22, 2025

% Revisions:
%

% Get the yData from the current axis

h = get(gca,'children');
if ~isempty(h)
    for cntLines = 1:length(h)
        hLine = get(h(cntLines));
        if ~isempty(hLine) && strcmpi(hLine.Type,'line')
            yData = hLine.YData;
            % to avoid some short refrence lines messing up the 
            % min/max calculation make sure that the number of 
            % points is (much) larger than 2
            if length(yData) > 48
                allYDataMax(cntLines) = max(yData); %#ok<*AGROW>
                allYDataMin(cntLines) = min(yData);
            end
        end
    end
end

yMax =Inf;
yMin = -Inf;
if ~isempty(allYDataMax)
    yMax = max(allYDataMax);
end
if ~isempty(allYDataMin)
    yMin = min(allYDataMin);
end

% Find if the limits need to be drawn. 
xl=xlim;
yl=ylim;    
% if yMax (the highest y-point) is between axis max: yl(2)
% and the user set limit: yLimits(2) then (at least) one bad point
% is visible on the plot and the plot should be shaded
if yl(2)>= yMax && yLimits(2) < yMax
    patch([xl(1) xl(2) xl(2) xl(1)],[ yLimits(2) yLimits(2) yl(2) yl(2) ],...
          'r','facealpha',0.1,'edgecolor','none',...
          'HandleVisibility', 'off')
    yline(yLimits(2),'r--','Max','HandleVisibility', 'off')
end
% if yMin (the lowest y-point) is between axis min: yl(1)
% and the user set limit: yLimits(1) then (at least) one bad point
% is visible on the plot and the plot should be shaded
if yl(1)<= yMin && yLimits(1) > yMin
    patch([xl(1) xl(2) xl(2) xl(1)],[ yl(1) yl(1) yLimits(1) yLimits(1)  ],...
          'r','facealpha',0.1,'edgecolor','none',...
          'HandleVisibility', 'off')
    yline(yLimits(1),'r--','Min','HandleVisibility', 'off')
end
    
