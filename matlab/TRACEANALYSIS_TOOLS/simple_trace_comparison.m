function simple_trace_comparison(tv,input1, input2, options)

if nargin<4
    options.input1.name = 'input1';
    options.input1.units = '';
    options.input2.name = 'input2';
    options.input2.units = '';
end

tv_dt = datetime(tv,'ConvertFrom','datenum');
% [~,~,~,HH] = datevec(tv); % Extract hour from time vector
idx = ~isnan(input1) & ~isnan(input2) & ~isinf(input1) & ~isinf(input2);
residuals = input1 - input2;

fh = figure('color','white');
allhandles = findall(fh);
menuhandles = findobj(allhandles,'type','uimenu');
deleteStr = {'figMenuTools','figMenuView','figMenuInsert'};
for i=1:length(deleteStr)
    handle2delete = findobj(menuhandles,'tag',deleteStr{i});
    delete(handle2delete)
end

% Temporary message while initial plot being constructed
ah00 = axes('position',[0.4 0.5 0.1 0.1]);
ah00.YColor = 'w';
ah00.XColor = 'w';
text(ah00,0,0,'Comparing...')
drawnow

%--------------------------------------------------------------------------
% Plot difference between inputs
%--------------------------------------------------------------------------
ah11 = axes('position',[0.1 0.62 0.39 0.375]);
ah11.UserData = 11;
hold on; box on
plot(tv_dt, residuals)
dtv = tv-tv(1);
span = find(dtv>=1,1,'first') - 1;
N = length(input1);
nod = ceil(N./span);
idx_daily = repmat((1:span)',1,nod) + repmat((0:(nod-1))*span,span,1);
residuals_daily = mean(residuals(idx_daily),1,'omitnan');
% residuals_smooth = smooth(residuals,span);
plot(tv_dt(span/2:span:end), residuals_daily, 'r.')
plot([tv_dt(1) tv_dt(end)], [0 0], 'k-')
%--> Used to store extra data to dynamically update other panels
plot(tv_dt,[input1 input2],'Visible','off')
yaxis_str = char([options.input1.name '-' options.input2.name]);
ylabel(yaxis_str)
set(gca,'YMinorTick','on','xgrid','on','ygrid','on')
legend('raw','24h run mean','location','northoutside','numcolumns',2,'EdgeColor','w');

axtoolbar(ah11,{'pan','zoomin','zoomout'});

pan(ah11,'xon')
ph = pan(fh);
set(ph, 'ActionPostCallback', @mypostcallback);

zoom(ah11,'on')
zh = zoom(ah11);
set(zh, 'ActionPostCallback', @mypostcallback);

% Here for option on how to deal with 'restoreview'


%--------------------------------------------------------------------------
% Cross-covariance to check for time lags
%--------------------------------------------------------------------------
ah12 = axes('position',[0.1+0.5 0.62 0.39 0.375]);
maxLags = 48;
[c,lags] = xcov(input1(idx), input2(idx), maxLags, 'normalized');
stem(lags,c,'XDataSource','lags','YDataSource','c')
ylabel('Normalized covariance')
xlabel('Lags')
set(gca,'ylim',[-1.1 1.1],'xtick',-48:12:48,'XMinorTick','on',...
    'YMinorTick','on')
box on

idx_maxVal = find(c==max(abs(c)));
bestLag = min(lags(idx_maxVal)); %#ok<FNDSB>
xlims = get(gca,'xlim');
text(xlims(1)+0.05.*diff(xlims),-0.95,char(['Lag_{best}=' num2str(roundn(bestLag,0))]))

ah12.UserData = 12;
ah12.Toolbar.Visible='off';
ah12.HitTest = 0;
disableDefaultInteractivity(ah12)


%--------------------------------------------------------------------------
% Scatter plot between inputs (heatmap hexscatter might be nice...)
%--------------------------------------------------------------------------
ah21 = axes('position',[0.1 0.1 0.39 0.375]);
hold on; box on
scatter(input1, input2, '.','XDataSource','input1','YDataSource','input2')
pcts = prctile(input1,[25 50 75]);
xlims = [pcts(2)-4.*(pcts(2)-pcts(1)) pcts(2)+4.*(pcts(3)-pcts(2))];
pcts = prctile(input2,[25 50 75]);
ylims = [pcts(2)-4.*(pcts(2)-pcts(1)) pcts(2)+4.*(pcts(3)-pcts(2))];
% xlims = get(gca,'xlim');
% ylims = get(gca,'ylim');
plot(xlims, xlims,'k-') % Add 1:1 line
fit = linreg(input1(idx), input2(idx));
plot(xlims, fit(1).*xlims+fit(2), 'k--') % Add linear regression
set(gca,'xlim',xlims,'ylim',ylims)
set(gca,'xminortick','on','YMinorTick','on','xgrid','on','ygrid','on')
xlabel_str = options.input1.name;
if ~strcmp(options.input1.units,'')
    xlabel_str = char([xlabel_str '(' options.input1.units ')']);
end
ylabel_str = options.input2.name;
if ~strcmp(options.input2.units,'')
    ylabel_str = char([ylabel_str '(' options.input2.units ')']);
end
xlabel(xlabel_str)
ylabel(ylabel_str)

rsq = corr(input1(idx), input2(idx)).^2;
xpos = xlims(1)+0.05*(xlims(2)-xlims(1));
ypos = ylims(1)+0.91*(ylims(2)-ylims(1));
slope_val = roundn(fit(1),-2);
if slope_val==0
    text(xpos,ypos,char(['slope=' num2str(fit(1),'%1.2E')]))
else
    text(xpos,ypos,char(['slope=' num2str(slope_val)]))
end
ypos = ylims(1)+0.8*(ylims(2)-ylims(1));
int_val = roundn(fit(2),-2);
if int_val==0
    text(xpos,ypos,char(['int.=' num2str(fit(2),'%1.2E')]))
else
    text(xpos,ypos,char(['int.=' num2str(int_val)]))
end
ypos = ylims(1)+0.69*(ylims(2)-ylims(1));
text(xpos,ypos,char(['r^2=' num2str(roundn(rsq,-2))]))

ah21.UserData = 21;
ah21.Toolbar.Visible='off';
ah21.HitTest = 0;
disableDefaultInteractivity(ah21)


%--------------------------------------------------------------------------
% CDF - lower right panel
%--------------------------------------------------------------------------
ah22 = axes('position',[0.1+0.5 0.1 0.39 0.375]);
ah22.UserData = 22;
[f,x] = ecdf(residuals(idx));
plot(x,f,'XDataSource','x','YDataSource','f')
pctls = prctile(residuals(idx),[1 99]);
if diff(pctls)>0
    set(gca,'xlim',pctls)
end
set(gca,'XMinorTick','on','YMinorTick','on','ytick',0:0.2:1,'xgrid','on','ygrid','on')
ylabel('CDF')
xlabel('Residuals')

% Basic stats
RMSD = sqrt(mean(residuals(idx).^2));
MAD = mean(abs(residuals(idx)));
mean_val = mean(residuals(idx));
median_val = median(residuals(idx));
xlims = get(gca,'xlim');
xpos = xlims(1)+0.05*(xlims(2)-xlims(1));
text(xpos,0.9,char(['RMSE=' num2str(roundn(RMSD,-2))]))
text(xpos,0.8,char(['MAD=' num2str(roundn(MAD,-2))]))
text(xpos,0.7,char(['Mean=' num2str(roundn(mean_val,-2))]))
text(xpos,0.6,char(['Med.=' num2str(roundn(median_val,-2))]))

ah22.UserData = 22;
ah22.Toolbar.Visible='off';
ah22.HitTest = 0;
disableDefaultInteractivity(ah22)


%--------------------------------------------------------------------------
% Remove message
%--------------------------------------------------------------------------
delete(ah00)


%--------------------------------------------------------------------------
% Subfunction
%--------------------------------------------------------------------------
function mypostcallback(h,eventdata)

if eventdata.Axes.UserData==11
    xlims = eventdata.Axes.XLim;
    tv_dt = eventdata.Axes.Children(end).XData;
    idx_window = tv_dt>=xlims(1) & tv_dt<=xlims(2);
    input1 = eventdata.Axes.Children(2).YData(idx_window);
    input2 = eventdata.Axes.Children(1).YData(idx_window);
    resid_vals = input1 - input2;
    idx_nan = ~isnan(resid_vals);
    resid_vals = resid_vals(idx_nan);
    [c, lags] = xcov(input1(idx_nan), input2(idx_nan), 48, 'normalized'); %#ok<ASGLU> --> Used by 'refreshdata()'
    [f,x] = ecdf(resid_vals); %#ok<ASGLU> --> Used by 'refreshdata()'
    
    % Get user data to identify panel
    ah = h.Children;
    UserData = NaN(length(ah),1);
    for i=1:length(ah)
        tmp = h.Children(i).UserData;
        if isnumeric(tmp) & ~isempty(tmp)
            UserData(i,1) = tmp;
        end
    end

    % Update scatter plot
    ah = h.Children(UserData==21);
    sh = ah.Children(end);
    refreshdata(sh,'caller') %--> Uses 'input1' and 'input2' to refresh
    %--> Update xlim and ylim -- simple for now
    pcts = prctile(input1,[25 50 75]);
    xlims = [pcts(2)-4.*(pcts(2)-pcts(1)) pcts(2)+4.*(pcts(3)-pcts(2))];
    pcts = prctile(input2,[25 50 75]);
    ylims = [pcts(2)-4.*(pcts(2)-pcts(1)) pcts(2)+4.*(pcts(3)-pcts(2))];
    set(ah,'ylim',ylims','xlim',xlims)
    %--> Update stats
    fit = linreg(input1, input2);
    ah.Children(1).String = char(['r^2=' num2str(roundn(corr(input1(idx_nan)',input2(idx_nan)').^2,-2))]);
    ah.Children(1).Position = [xlims(1)+0.05.*diff(xlims) ylims(2)-3.*0.09.*diff(ylims) 0];
    ah.Children(2).String = char(['int.=' num2str(roundn(fit(2),-2))]);
    ah.Children(2).Position = [xlims(1)+0.05.*diff(xlims) ylims(2)-2.*0.09.*diff(ylims) 0];
    ah.Children(3).String = char(['slope=' num2str(roundn(fit(1),-2))]);
    ah.Children(3).Position = [xlims(1)+0.05.*diff(xlims) ylims(2)-1.*0.09.*diff(ylims) 0];
    xlims = get(ah,'XLim');
    ah.Children(4).XData = xlims;
    ah.Children(4).YData = fit(1).*xlims + fit(2);
    ah.Children(5).XData = xlims;
    ah.Children(5).YData = xlims;
    ah.UserData = 21;
    ah.Toolbar.Visible='off';
    ah.HitTest = 0;
    disableDefaultInteractivity(ah)
    
    %Update covariance plot
    ah = h.Children(UserData==12);
    covh = ah.Children(end);
    refreshdata(covh,'caller')
    ah.UserData = 12;
    ah.Toolbar.Visible='off';
    ah.HitTest = 0;
    disableDefaultInteractivity(ah)
    
    % Update CDF plot
    ah = h.Children(UserData==22);
    ch = ah.Children(end);
    refreshdata(ch,'caller')
    %--> Update stats
    RMSD = sqrt(mean(resid_vals.^2));
    MAD = mean(abs(resid_vals));
    mean_val = mean(resid_vals);
    median_val = median(resid_vals);
    ah.Children(1).String = char(['med.=' num2str(roundn(median_val,-2))]);
    ah.Children(2).String = char(['Mean=' num2str(roundn(mean_val,-2))]);
    ah.Children(3).String = char(['MAD=' num2str(roundn(MAD,-2))]);
    ah.Children(4).String = char(['RMSE=' num2str(roundn(RMSD,-2))]);
    ah.UserData = 22;
    ah.Toolbar.Visible='off';
    ah.HitTest = 0;
    disableDefaultInteractivity(ah)
else
    disp('No action taken!')
end

% disp(eventdata)