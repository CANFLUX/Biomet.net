function simple_trace_summary(tv,input1,options)

if nargin<3
    options.title = '';
end

tv_dt = datetime(tv,'ConvertFrom','datenum');
% [~,~,~,HH] = datevec(tv); % Extract hour from time vector
idx = ~isnan(input1) & ~isinf(input1);

fh = figure('color','white','Name',options.title);

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
text(ah00,0,0,'Summarizing...')
drawnow
xpos_root = 0.09;

%--------------------------------------------------------------------------
% Plot trace to control data displayed in other panels
%--------------------------------------------------------------------------
ah11 = axes('position',[xpos_root 0.62 0.39 0.375]);
ah11.UserData = 11;
hold on; box on
plot(tv_dt, input1)
dtv = tv-tv(1);
span = find(dtv>=1,1,'first') - 1;
N = length(input1);
nod = ceil(N./span);
idx_daily = repmat((1:span)',1,nod) + repmat((0:(nod-1))*span,span,1);
input1_daily = mean(input1(idx_daily),1,'omitnan');
plot(tv_dt(span/2:span:end), input1_daily, 'r.')

%--> Used to store extra data to dynamically update other panels
plot(tv_dt,input1,'Visible','off') 
ylabel('Raw data')
set(gca,'YMinorTick','on','xgrid','on','ygrid','on')
legend('raw','Daily avg.','location','northoutside','numcolumns',2,'EdgeColor','w');

axtoolbar(ah11,{'pan','zoomin','zoomout'});

pan(ah11,'xon')
ph = pan(fh);
set(ph, 'ActionPostCallback', @mypostcallback_summary);

zoom(ah11,'on');
zh = zoom(ah11);
set(zh, 'ActionPostCallback', @mypostcallback_summary);

% Option on how to deal with 'restoreview'
% % step 1
% btn = axtoolbarbtn(app.sagittal_axes_tb, 'push');
% btn.Icon = 'restoreview';
% % step 2
% btn.ButtonPushedFcn = createCallbackFcn(app, @restoreview, true);
% % step 3
% function restoreview(app, event)
%     limits = [lower upper];
%     app.axis.XLim = limits;
%     app.axis.YLim = limits;
% end


% d = dataTipInteraction;
% z = zoomInteraction('Dimensions','y');

%--------------------------------------------------------------------------
% Boxplot to examine diurnal variation -- upper right panel
%--------------------------------------------------------------------------
ah12 = axes('position',[xpos_root+0.5 0.62 0.39 0.36]);

[~,~,~,HH,~,~] = datevec(tv);
boxplot(ah12, input1, HH)
ylabel(ah12,'Boxplot')
xlabel(ah12,'Hour of day')
set(ah12,'XMinorTick','on','YMinorTick','on','ygrid','on')
box(ah12,'on')

ah12.UserData = 12;
ah12.Toolbar.Visible='off';
ah12.HitTest = 0;
disableDefaultInteractivity(ah12)


%--------------------------------------------------------------------------
% Relative change per time step (help identify spikes)
%--------------------------------------------------------------------------
ah21 = axes('position',[xpos_root 0.1 0.39 0.375]);

y = input1;
% delta_y_norm = [0; diff(y)./y(1:end-1)];
delta_y = [0; diff(y)];

plot(ah21, tv_dt, delta_y)
% qqplot(ah21, input1(idx))
box(ah21,'on')
% xlims = get(gca,'xlim');
% ylims = get(gca,'ylim');
% plot(xlims, xlims,'k-') % Add 1:1 line
% fit = linreg(input1(idx), input2(idx));
% plot(xlims, fit(1).*xlims+fit(2), 'k--') % Add linear regression
% set(gca,'xlim',xlims,'ylim',ylims)
set(ah21,'xminortick','on','YMinorTick','on','xgrid','on','ygrid','on')
% xlabel('input1')
ylabel('y_{t} - y_{t-1}')
title(ah21,'')

% rsq = corr(input1(idx), input2(idx)).^2;
% xpos = xlims(1)+0.05*(xlims(2)-xlims(1));
% ypos = ylims(1)+0.91*(ylims(2)-ylims(1));
% text(xpos,ypos,char(['slope=' num2str(roundn(fit(1),-2))]))
% ypos = ylims(1)+0.8*(ylims(2)-ylims(1));
% text(xpos,ypos,char(['int.=' num2str(roundn(fit(2),-2))]))
% ypos = ylims(1)+0.69*(ylims(2)-ylims(1));
% text(xpos,ypos,char(['r^2=' num2str(roundn(rsq,-2))]))

ah21.UserData = 21;
ah21.Toolbar.Visible='off';
ah21.HitTest = 0;
disableDefaultInteractivity(ah21)


%--------------------------------------------------------------------------
% CDF - lower right panel
%--------------------------------------------------------------------------
ah22 = axes('position',[xpos_root+0.5 0.1 0.39 0.375]);

[f,x] = ecdf(input1(idx));
plot(ah22,x,f,'XDataSource','x','YDataSource','f')
pctls = prctile(input1(idx),[1 99]);
if diff(pctls)>0
    set(ah22,'xlim',pctls)
end
set(ah22,'XMinorTick','on','YMinorTick','on','ytick',0:0.2:1,'xgrid','on','ygrid','on')
ylabel(ah22,'CDF')
xlabel(ah22,'Raw values')

% Basic stats
% percentiles = prctile(input1,[1 99]);
mean_val = mean(input1(idx));
median_val = median(input1(idx));
xlims = get(ah22,'xlim');
xpos = xlims(1)+0.05*(xlims(2)-xlims(1));
text(ah22,xpos,0.9,char(['Prctl_{1st}=' num2str(roundn(pctls(1),-2))]))
text(ah22,xpos,0.8,char(['Prctl_{99th}=' num2str(roundn(pctls(2),-2))]))
text(ah22,xpos,0.7,char(['Mean=' num2str(roundn(mean_val,-2))]))
text(ah22,xpos,0.6,char(['Med.=' num2str(roundn(median_val,-2))]))

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
function mypostcallback_summary(h,eventdata)
xpos_root = 0.09;

if eventdata.Axes.UserData==11
    xlims = eventdata.Axes.XLim;
    tv_dt = eventdata.Axes.Children(end).XData;
    idx_window = tv_dt>=xlims(1) & tv_dt<=xlims(2);
    input_subset = eventdata.Axes.Children(1).YData(idx_window);
    xdata = eventdata.Axes.Children(1).XData(idx_window);
    [~,~,~,HH,~,~] = datevec(xdata);
    idx_subset = ~isnan(input_subset);
    input_subset = input_subset(idx_subset);
    HH = HH(idx_subset);
    % [c, lags] = xcov(input1(idx_nan), input2(idx_nan), 48, 'normalized'); %Store 28 in User data and retrieve
    [f,x] = ecdf(input_subset); %#ok<ASGLU>  --> Used by 'refreshdata()'
    
    % Get user data to identify panel
    ah = h.Children;
    UserData = NaN(length(ah),1);
    for i=1:length(ah)
        tmp = h.Children(i).UserData;
        if isnumeric(tmp) & ~isempty(tmp)
            UserData(i,1) = tmp;
        end
    end

    % Update time-difference plot
    ah = h.Children(UserData==21);
    % if size(input_subset,1)==1
    %     input_subset = input_subset';
    % end
    % if size(xdata,1)==1
    %     xdata = xdata';
    % end
    % plot(ah,xdata,[0; (input_subset(2:end)-input_subset(1:end-1))./input_subset(1:end-1)]) % Could just update x-axis zoom instead...
    set(ah,'xlim',xlims)
    % ylabel(ah,'y_{t} - y_{t-1}')
    % title(ah,'')
    % qh = ah.Children(end);
    % refreshdata(qh,'caller')
    %--> Update stats
    % fit = linreg(input1, input2);
    % ah.Children(1).String = char(['r^2=' num2str(roundn(corr(input1',input2').^2,-2))]);
    % ah.Children(2).String = char(['int.=' num2str(roundn(fit(2),-2))]);
    % ah.Children(3).String = char(['slope=' num2str(roundn(fit(1),-2))]);
    % xlims = get(ah,'XLim');
    % ah.Children(4).XData = xlims;
    % ah.Children(4).YData = fit(1).*xlims + fit(2);
    box(ah,'on')
    ah.UserData = 21;
    ah.Toolbar.Visible='off';
    ah.HitTest = 0;
    disableDefaultInteractivity(ah)
    
    % Update diurnal boxplot
    ah = h.Children(UserData==12);
    boxplot(ah,input_subset,HH)
    % bh = ah.Children(end);
    % refreshdata(bh,'caller')
    set(ah,'position',[xpos_root+0.5 0.62 0.39 0.36],'ygrid','on')
    ylabel(ah,'Boxplot')
    xlabel(ah,'Hour of day')
    ah.UserData = 12;
    ah.Toolbar.Visible='off';
    ah.HitTest = 0;
    disableDefaultInteractivity(ah)
    
    % Update CDF plot
    ah = h.Children(UserData==22);
    ch = ah.Children(end);
    refreshdata(ch,'caller')
    %--> Update stats
    percentiles = prctile(input_subset,[1 99]);
    mean_val = mean(input_subset);
    median_val = median(input_subset);
    ah.Children(1).String = char(['med.=' num2str(roundn(median_val,-2))]);
    ah.Children(2).String = char(['Mean=' num2str(roundn(mean_val,-2))]);
    ah.Children(3).String = char(['Prctl_{99th}=' num2str(roundn(percentiles(1),-2))]);
    ah.Children(4).String = char(['Prctl_{1st}=' num2str(roundn(percentiles(2),-2))]);
    ah.UserData = 22;
    ah.Toolbar.Visible='off';
    ah.HitTest = 0;
    disableDefaultInteractivity(ah)
else
    disp('No action taken!')
end

% disp(eventdata)