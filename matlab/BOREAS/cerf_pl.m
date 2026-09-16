function [t,x] = cerf_pl(ind, yearIn, siteID, select, fig_num_inc,flgPause) 
%
% [t,x] = CERF_pl(ind, yearIn,siteID, select, fig_num_incflgPause)
%
%   This function plots selected data from the LI-710 files. It reads from
%   the UBC data-base formated files.
%
% (c) Nesic Zoran         File created:       Sep  8, 2026      
%                         Last modification:  Sep  8, 2026
%           
%

% Revisions:
%

arg_default('fig_num_inc',1);
arg_default('select',1);
arg_default('siteID','CERF1');
arg_default('flgPause',1);              % default is show one figure and pause

arg_default('yearIn',year(datetime));              % assume current yearIn

pthSite = biomet_path('yyyy',siteID);

if nargin < 1 
    error 'Too few imput parameters!'
end

GMTshift = 0/24;                            % offset to convert GMT to PST
siteID = upper(siteID);                     % convert to uppercase

st = min(ind);                              % first day of measurements
ed = max(ind)+1;                            % last day of measurements (approx.)
ind = st:ed; %#ok<*NASGU>

datesTmp = datenum(yearIn,1,[st ed]);
[rangeYears,~,~,~,~,~] = datevec(datesTmp);
rangeYears = rangeYears(1):rangeYears(2);

tv=fr_round_time(read_bor(fullfile(pthSite,'MET','TimeVector'),8,[],rangeYears)); % get time from the data base
t = tv - datenum(yearIn,1,0) - GMTshift;               % convert decimal time to
                                                    % decimal DOY local time
t_all = t;                                          % save time trace for later                                                    
ind = find( t >= st & t <= ed );                    % extract the requested period
t = t(ind);
fig_num = 1 - fig_num_inc;

colordef white

allAxes = [];
indAxes = 0;
%----------------------------------------------------------
% HMP air temperatures
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Air Temperature');

trace_path  = char(fullfile(pthSite,'MET','ta_l')...                   
                   );
%                    fullfile(db_pth_root,'yyyy\ECCC\10732\30min','Tair'),...
tempOffset = [0 273.15];   %273.15 273.15];
trace_legend = '' ; %char('T_{HMP-1}','SonicT');
trace_units = 'T_{air}(degC)';
y_axis      = [-20 40];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,[],tempOffset );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% HMP RH
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Relative Humidity');

trace_path  = char(fullfile(pthSite,'MET','RH_l')); 
trace_units = 'RH (%)';
y_axis      = [0 110];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;


%----------------------------------------------------------
% Rain gauges
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,'Precipitation');

trace_path  = char(fullfile(pthSite,'MET','Rain_mm_Tot')...
                   );
trace_legend = char('Site','ECCC');

trace_units = 'Precipitation (mm/30-min)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
% remember xlim, you'll need it to rescale cumulative rain
originalXlim = xlim;


%----------------------------------------------------------
% Cumulative rain
%----------------------------------------------------------
% *** in case of multiple-yearIn plots it plots only the last yearIn
indx = find( t_all >= 1 & t_all <= ed );                    % extract the period from
tx = t_all(indx);                                           % the beginning of the last yearIn
indNew = [1:length(indx)]+round(GMTshift*48);               % use GMTshift to align the data with time vector


trace_name  = sprintf('%s: %s',siteID,'Cumulative Rain (current yearIn only)');
trace_units = 'Precipitation (mm)';
trace_legend = char('Site');
y_axis      = [];

trace_path  = char(fullfile(pthSite,'MET','Rain_mm_Tot'));
[x1,tx_new] = read_sig(trace_path(1,:), indNew,yearIn, tx,0); %#ok<*ASGLU>
x1(isnan(x1)) = 0; % replace NaNs with 0 so that cumsum can work

% trace_path  = char(fullfile(db_pth_root,'yyyy\ECCC\10732\30min','Precip'));
% [x2,tx_new] = read_sig(trace_path(1,:), indNew,yearIn, tx,0); %#ok<*ASGLU>
% x2(isnan(x2)) = 0; % replace NaNs with 0 so that cumsum can work

fig_num = fig_num + fig_num_inc;
%x = plt_msig( [cumsum(x1) cumsum(x2)], ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
x = plt_msig( [cumsum(x1) ], ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
try
    xlim(originalXlim);
    indAxes = indAxes+1; allAxes(indAxes) = gca;
catch
    close(fig_num);
    fig_num = fig_num - fig_num_inc;
end

%----------------------------------------------------------
% CNR4 components
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' CNR4 components');

trace_path  = char(fullfile(pthSite,'MET','SWin_Avg'),...
                   fullfile(pthSite,'MET','SWout_Avg'),...
                   fullfile(pthSite,'MET','LWin_Avg'),...
                   fullfile(pthSite,'MET','LWout_Avg')...
                   );
trace_legend = char('SW_{IN}','SW_{OUT}','LW_{IN}','LW_{OUT}');
trace_units = '(W)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% NET radiation
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' NETRAD');

trace_path  = char(fullfile(pthSite,'MET','Rn_Avg')...
                   );
trace_legend = [];
trace_units = '(µmol/m2/s)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

% %----------------------------------------------------------
% % PPFD
% %----------------------------------------------------------
% trace_name  = sprintf('%s: %s',siteID,' PPFD');
% trace_path  = char(fullfile(pthSite,'MET','PAR_in'),...
%                    fullfile(pthSite,'MET','PAR_out')...
%     );
% trace_legend = char('PPFD_{IN}','PPFD_{OUT}');
% trace_units = '(µmol/m2/s)';
% y_axis      = [];
% fig_num = fig_num + fig_num_inc;
% x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
% indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% Wind Speed
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,'Wind Speed');
trace_path  = char(fullfile(pthSite,'Met','WS_ms_Avg'));
%trace_legend = char('MET (avg)','MET (max)','ECCC');
trace_legend = '';
trace_units = '(m/s)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% Wind Direction
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,'Wind Direction');
trace_path  = char(fullfile(pthSite,'Met','WS_ms_WVc_2'));
% fullfile(db_pth_root,'yyyy\ECCC\10732\30min','WindDir')...                   
% trace_legend = char('MET','ECCC');
trace_legend = '';
trace_units = 'deg';
unitCorrection = [1 10];
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,unitCorrection );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% Samples collected
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Samples in 30min');
trace_path  = char(fullfile(pthSite,'Met','LI710B_8'));
trace_legend = char('Collected','Used');
trace_units = '# of Samples';
y_axis= [];%[16000 20000];
fig_num = fig_num + fig_num_inc;
[x, dTV]= plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indNans = find(isnan(sum(x,2)));
if ~isempty(indNans)
    line(dTV(indNans,1),ones(length(indNans),1)*18000,...
        'LineStyle','none','Marker','x','Color','k','MarkerSize',10,...
        'DisplayName','Missing')
end
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% 24V Battery Voltage
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Battery Voltage');
trace_path  = char( fullfile(pthSite,'Met','LI710D_7')...
                   );
trace_legend = '';%char('hit-vin-mean','vin_sf_mean');
trace_units = 'Battery Voltage (V)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% Pump Voltage
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,'Pump Voltage');
coeffSign = 0;
trace_path  = char( fullfile(pthSite,'Met','LI710D_1')...
                   );
fig_num = fig_num + fig_num_inc;
trace_units = 'Pump Voltage (V)';
y_axis      = [];
sysCurrent = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,[1 1]*coeffSign ); 
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% Cell Pressure
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,'Cell Pressure');
coeffSign = 0;
trace_path  = char( fullfile(pthSite,'Met','LI710D_2')...
                   );
trace_units = 'Cell Pressure (kPa)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
sysCurrent = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,[1 1]*coeffSign ); 
indAxes = indAxes+1; allAxes(indAxes) = gca;

yetToDo = false;
if yetToDo 
    
    %----------------------------------------------------------
    % Cumulative Battery Current
    %----------------------------------------------------------
    trace_name  = sprintf('%s: %s',siteID,' Cumulative Battery Current');
    switch siteID
        case {'BB2','DSM','RBM'}
            Ibb1 = read_sig( fullfile(pthSite,'MET', 'SYS_Batt_DCCurrent_Avg'), ind,yearIn, t, 0 );
            Ibb1(isnan(Ibb1))=0;
            trace_path = (1+cumsum(Ibb1/2)/2600)*100;    % Ah / Ah
            trace_legend = [];
    end
    trace_units = 'Cummulative Current (%)';
    y_axis      = [];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    
    
    %----------------------------------------------------------
    % System Voltage
    %----------------------------------------------------------
    trace_name  = sprintf('%s: %s',siteID,'Logger Voltage');
    
    trace_path  = char(fullfile(pthSite,'flux','Voltage_12V_Avg'),...
        fullfile(pthSite,'met','SYS_Logger_Batt_Min'));
    trace_legend = char('Voltage 12V Avg','SYS Logger Batt Min');      
    trace_units = 'Instrument Voltage (V)';
    y_axis      = [];
    fig_num = fig_num + fig_num_inc;
    sysVoltage = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    
    
    %----------------------------------------------------------
    % System Temperatures
    %----------------------------------------------------------
    trace_name  = sprintf('%s: %s',siteID,' System Temperatures');
    trace_path  = char(fullfile(pthSite,'MET','SYS_Logger_Temp_Avg')...  
               );
    trace_legend = char('CR1000x');
    trace_units = 'Temperature (\circC)';
    y_axis      = [];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    
    %----------------------------------------------------------
    % LI-7200 Thermocouples
    %----------------------------------------------------------
    trace_name  = sprintf('%s: %s',siteID,' LI-7200 Thermocouples');
    trace_path  = char(fullfile(pthSite,'monitorSites',sprintf('%s.tempIn.avg',siteID)),...
                       fullfile(pthSite,'monitorSites',sprintf('%s.tempOut.avg',siteID)));
    trace_legend = char('T_{in}','T_{out}');
    trace_units = 'Temperature (\circC)'; % flowrate_min needs to be converted from m^3/sec *1000*60 (L/min)
    y_axis      = [];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, ...
                  trace_legend, yearIn, trace_units, ...
                  y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    
    
    %----------------------------------------------------------
    % LI-7200 Flow rate
    %----------------------------------------------------------
    trace_name  = sprintf('%s: %s',siteID,' LI-7200 Flow Rate');
    switch siteID
        case {'HOGG','YOUNG','OHM'}
            trace_path = [];
            fig_num = fig_num-1;
        otherwise
            trace_path  = char(fullfile(pthSite,'monitorSites',sprintf('%s.flowRate.avg',siteID)),...
                               fullfile(pthSite,'Flux','flowrate_mean'));
    end
    trace_legend = char('Monitor','EddyPro');
    trace_units = 'Flow (lpm)'; % flowrate_min needs to be converted from m^3/sec *1000*60 (L/min)
    y_axis      = [];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,[1 1000*60] );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    
    %----------------------------------------------------------
    % Flow Drive
    %----------------------------------------------------------
    trace_name  = sprintf('%s: %s',siteID,' Flow Drive');
    switch siteID
        case {'HOGG','YOUNG','OHM'}
            trace_path = [];
            fig_num = fig_num-1;
        otherwise
            trace_path  = char(fullfile(pthSite,'monitorSites',sprintf('%s.FlowDrive.avg',siteID)),...
                               fullfile(pthSite,'monitorSites',sprintf('%s.FlowDrive.min',siteID)),...
                               fullfile(pthSite,'monitorSites',sprintf('%s.FlowDrive.max',siteID))...
            );
            trace_legend = char('Avg','Min','Max');
    end
    trace_units = 'Flow Drive (%)';
    y_axis      = [];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    
    %----------------------------------------------------------
    % Head Pressure
    %----------------------------------------------------------
    trace_name  = sprintf('%s: %s',siteID,'Head Pressure');
    switch siteID
        case {'HOGG','YOUNG','OHM'}
            trace_path = [];
            fig_num = fig_num-1;
        otherwise
            trace_path  = char(fullfile(pthSite,'monitorSites',sprintf('%s.Phead.avg',siteID)),...
                               fullfile(pthSite,'monitorSites',sprintf('%s.Phead.min',siteID)),...
                               fullfile(pthSite,'monitorSites',sprintf('%s.Phead.max',siteID))...
            );
            trace_legend = char('Avg','Min','Max');
    end
    trace_units = 'Phead (kPa)';
    y_axis      = [];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    
    %----------------------------------------------------------
    % Air pressure
    %----------------------------------------------------------
    trace_name  = sprintf('%s: %s',siteID,' Air Pressure');
    trace_path  = char(fullfile(pthSite,'Flux','air_pressure'),...
                       fullfile(pthSite,'Flux','air_p_mean')...
        );
    trace_legend = char('air\_pressure','air\_P\_mean');
    trace_units = 'Barometric Pressure (kPa)';
    y_axis      = [];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num, [ 1 1] * 0.001 );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    
    %----------------------------------------------------------
    % Spikes
    %----------------------------------------------------------
    trace_name  = sprintf('%s: %s',siteID,' Spikes');
    trace_path = char(fullfile(pthSite,'Flux','w_spikes'),...
                      fullfile(pthSite,'Flux','ts_spikes'),...
                      fullfile(pthSite,'Flux','co2_spikes'),...
                      fullfile(pthSite,'Flux','h2o_spikes'),...
                      fullfile(pthSite,'Flux','ch4_spikes')...
                      );
    trace_legend = char('w_{spikes}','ts_{spikes}','co2_{spikes}','h2o_{spikes}','ch4_{spikes}');
    trace_units = 'Number of spikes';
    y_axis      = [];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;

end






linkaxes(allAxes,'x');


if flgPause ~= 1
    return
end
%------------------------------------------
if select == 1 %diagnostics only
    childn = get(0,'children');
    allFig = {childn.Number};
    allfFig = cell2mat(allFig);
    allfFig = sort(allfFig);
    N = length(allfFig);
    for i=1:N
        if i < 200
            figNum = get(allfFig(i),'number');
            figure(figNum);
            pause;
        end
    end
    return
end

end


