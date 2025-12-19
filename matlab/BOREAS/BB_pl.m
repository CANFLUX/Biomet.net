function [t,x] = BB_pl(ind, yearIn, siteID, select, fig_num_inc,flgPause) 
%
% [t,x] = BB_pl(ind, yearIn,siteID, select, fig_num_incflgPause)
%
%   This function plots selected data from the data-logger files. It reads from
%   the UBC data-base formated files.
%
% (c) c) Nesic Zoran         File created:       May 11, 2021      
%                            Last modification:  Jan  2, 2025
%           
%

% Revisions:
%
% Jan 2, 2025 (Zoran)
%   - Bug fix: There were some issues with the plotting of cumulative precipitation
%     when plotting the first few days of a new yearIn. Patched it up with try-catch-end.
%     If there is time, this could be fixed properly.
% Jul 16, 2024 (Zoran)
%   - Added Precip plots
% Jan 5, 2024 (Zoran)
%   - tried to find a proper 24V battery voltage measurement for Manitoba sites but, given
%     the specifics of that system, there isn't a good way to do this. EddyPro does not
%     capture the LI-7500 Vin and LI-7700 doesn't even has that measurements.
% Oct 15, 2023 (Zoran)
%   - Changed the plotting of OHM site signal strengths. OHM is currently not supported 
%     by "monitorSites" app so I had to remove those traces so the legend does not get confused.
% Aug 30, 2023 (Zoran)
%   - Added RH_1_1_1 plotting to Manitoba sites
% Aug 25, 2023 (Zoran)
%   - Added plotting of OHM site.
% Feb 26, 2023 (Zoran)
%   - added time-lag plot
% July 18, 2022 (Zoran)
%   - changed the variable for plotting RH at RBM from MET_HMP_RH_2m to MET_HMP_RH_4m 
% Apr 2, 2022 (Zoran)
%   - Fixed hard-coded paths into the usual biomet path selection
% Mar 1, 2022 (Zoran)
%   - fixed a bug in power calculation for BB2 and DSM. 
%     changed "sysVoltage .* sysCurrent" to "sysVoltage(:,1) .* sysCurrent"  
% Jan 20, 2022 (Zoran)
%   - added flgPause that can overwrite cycling through figures
% Jan 19, 2022 (Zoran)
%   - added Young and Hogg sites
% Sep 21, 2021 (Zoran)
%   - added DSM site


if ind(1) > datenum(0,3,15) & ind(1) < datenum(0,11,15) %#ok<*AND2>
    WINTER_TEMP_OFFSET = 0;
else
    WINTER_TEMP_OFFSET = 10;
end

%colordef white %#ok<COLORDEF>
arg_default('fig_num_inc',1);
arg_default('select',1);
arg_default('siteID','BB2');
arg_default('flgPause',1);              % default is show one figure and pause

yearX = year(datetime);             % if parameter "yearIn" not given
arg_default('yearIn',yearX);              % assume current yearIn

% create default database path
% NOTE: make sure that there is a file
%       /UBC_PC_Setup/PC_Specific/micromet_database_default.m
%       that has the correct database path set here:
%       x = 'p:/DATABASE';
%       (use the correct path to Database folder for your system)

db_path = biomet_path('yyyy',siteID);

if nargin < 1 
    error 'Too few imput parameters!'
end

GMTshift = 0/24;                            % offset to convert GMT to PST
siteID = upper(siteID);                     % convert to uppercase
if strcmpi(siteID,'BB')
    siteID = 'BB1';                         % first BB site can be ID-ed as BB or BB1
end
switch siteID
    case 'BB1'
        pthSite = db_path(1:end-2);         % just remove the "1" from "BB1"
        %pthSite = '//vinimet.geog.ubc.ca/projects/Database/yyyy/BB';    % get the climate data path
    otherwise
        pthSite = db_path;                  % get the climate data path
end
st = min(ind);                              % first day of measurements
ed = max(ind)+1;                            % last day of measurements (approx.)
ind = st:ed; %#ok<*NASGU>

datesTmp = datenum(yearIn,1,[st ed]);
[rangeYears,~,~,~,~,~] = datevec(datesTmp);
rangeYears = rangeYears(1):rangeYears(2);

switch siteID
    case {'HOGG','YOUNG','OHM'}
        tv=fr_round_time(read_bor(fullfile(pthSite,'flux','Clean_tv'),8,[],rangeYears));     % get time from the data base
    otherwise
        tv=fr_round_time(read_bor(fullfile(pthSite,'MET','TimeVector'),8,[],rangeYears)); % get time from the data base
end

t = tv - datenum(yearIn,1,0) - GMTshift;               % convert decimal time to
                                                    % decimal DOY local time
t_all = t;                                          % save time trace for later                                                    
ind = find( t >= st & t <= ed );                    % extract the requested period
t = t(ind);
fig_num = 1 - fig_num_inc;

allAxes = [];
indAxes = 0;
%----------------------------------------------------------
% HMP air temperatures
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Air Temperature');
switch siteID
    case {'HOGG','YOUNG','OHM'}
        trace_path  = char(fullfile(pthSite,'Flux','air_temperature'),...
                           fullfile(pthSite,'Flux','TA_1_1_1'),...
                           fullfile(pthSite,'Flux','sonic_temperature')...
            );
        tempOffset = [ 1 1 1]*273.15;    % convert K to C
        trace_legend = char('airT','TA 1.1.1','SonicT');
    otherwise
        trace_path  = char(fullfile(pthSite,'MET','MET_HMP_T_2m_Avg'),...
                           fullfile(pthSite,'Flux','air_temperature'),...
                           fullfile(pthSite,'Flux','sonic_temperature')...
                           );
        tempOffset = [0 273.15 273.15];
        trace_legend = char('T_{HMP}','airT','SonicT');
end

trace_units = 'T_{air}(degC)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,[],tempOffset );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% HMP RH
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Relative Humidity');
switch siteID
    case {'HOGG','YOUNG','OHM'}
        trace_path  = char(fullfile(pthSite,'flux','RH_1_1_1'),...
                           fullfile(pthSite,'flux','RH'));
        trace_legend = char('MET','LI-7500');
    case{'RBM'}
        trace_path  = char(fullfile(pthSite,'MET','MET_HMP_RH_4m_Avg'));
        trace_legend = [];
    otherwise
        trace_path  = char(fullfile(pthSite,'MET','MET_HMP_RH_2m_Avg'));
        trace_legend = [];
end

trace_units = 'RH (%)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% Rain gauges
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,'Precipitation');
switch siteID
    case {'HOGG','YOUNG','OHM'}
        trace_path  = char(fullfile(pthSite,'flux','P_RAIN_1_1_1'));
        trace_legend = char('MET','LI-7500');
        unitMult = 1000;
    otherwise
        trace_path  = char(fullfile(pthSite,'MET','MET_RainTips_Tot'));
        trace_legend = [];
        unitMult = 1;
end

trace_units = 'Precipitation (mm/30-min)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,unitMult );
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
switch siteID
    case {'HOGG','YOUNG','OHM'}
        trace_path  = char(fullfile(pthSite,'flux','P_RAIN_1_1_1'));
        trace_legend = char('MET','LI-7500');
    otherwise
        trace_path  = char(fullfile(pthSite,'MET','MET_RainTips_Tot'));
        trace_legend = [];
end

trace_units = 'Precipitation (mm)';
[x1,tx_new] = read_sig(trace_path(1,:), indNew,yearIn, tx,0); %#ok<*ASGLU>
x1(isnan(x1)) = 0; % replace NaNs with 0 so that cumsum can work
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( cumsum(x1), ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,unitMult );
try
    % sometimes at the begining of new yearIn this causes an error. Ignore. (20250102 Zoran)
    xlim(originalXlim);
    indAxes = indAxes+1; allAxes(indAxes) = gca;
catch
    close(fig_num);
    fig_num = fig_num - fig_num_inc;
end


%----------------------------------------------------------
% Samples collected
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Samples in 30min');
trace_path  = char(fullfile(pthSite,'flux','file_records'),fullfile(pthSite,'flux','used_records'));
trace_legend = char('Collected','Used');
trace_units = '# of Samples';
y_axis      = [34000 37000];
fig_num = fig_num + fig_num_inc;
[x, dTV]= plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indNans = find(isnan(sum(x,2)));
if ~isempty(indNans)
    line(dTV(indNans,1),ones(length(indNans),1)*36000,...
        'LineStyle','none','Marker','x','Color','k','MarkerSize',10,...
        'DisplayName','Missing')
end
indAxes = indAxes+1; allAxes(indAxes) = gca;


%----------------------------------------------------------
% 24V Battery Voltage
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Battery Voltage');
switch siteID
    case {'HOGG','YOUNG','OHM'}
        trace_path  = char(fullfile(pthSite,'flux','DRM_V_MAIN_1_1_1'), ...
                           fullfile(pthSite,'monitorSites',sprintf('%s.DSIVin.avg',siteID)));
        trace_legend = char('DRM_V_MAIN_1_1_1','DSIVin.avg');
    otherwise
        trace_path  = char(fullfile(pthSite,'MET','SYS_PBox_Batt_Volt_Avg'));
        trace_legend = [];
end

trace_units = '24V Battery Voltage (V)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% Battery Current
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Battery Current');
switch siteID
    case 'BB1'
        trace_path  = char(fullfile(pthSite,'MET','SYS_Batt_DCCurrent_Avg'),...
                           fullfile(pthSite,'MET','SYS_Batt_DCCurrent2_Avg')...
                           );
        trace_legend = char('Battery #1','Battery #2');
        coeffSign = -1;
    case {'BB2','DSM','RBM'}
        trace_path  = char(fullfile(pthSite,'MET','SYS_Batt_DCCurrent_Avg'));
        trace_legend = [];   
        coeffSign = 1;
    case {'HOGG','YOUNG','OHM'}
        coeffSign = 0;
        trace_path = [];     % this indicates that trace is not available
        fig_num = fig_num-1;
end

trace_units = '24V Battery Current (Amps)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
sysCurrent = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,[1 1]*coeffSign ); 
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% Cumulative Battery Current
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Cumulative Battery Current');
switch siteID
    case 'BB1'
        Ibb1 = -read_sig( fullfile(pthSite,'MET', 'SYS_Batt_DCCurrent_Avg'), ind,yearIn, t, 0 );
        Ibb1(isnan(Ibb1)) = 0;
        if tv(ind(1))<datenum(2021,11,17)
            % For this period, process the second battery box too.
            Ibb2 = -read_sig( fullfile(pthSite,'MET', 'SYS_Batt_DCCurrent2_Avg'), ind,yearIn, t, 0 );
            Ibb2(isnan(Ibb2)) = 0;
            trace_path = (1+cumsum([Ibb1/600 Ibb2/800]/2))*100;  % Ah / Ah
        else
            trace_path = (1+cumsum(Ibb1/2/1200))*100;  % Ah / Ah
            %trace_path = cumsum(Ibb1)/2;
        end

        trace_legend = char('Batt 1','Batt 2');

    case {'BB2','DSM','RBM'}
        Ibb1 = read_sig( fullfile(pthSite,'MET', 'SYS_Batt_DCCurrent_Avg'), ind,yearIn, t, 0 );
        Ibb1(isnan(Ibb1))=0;
        trace_path = (1+cumsum(Ibb1/2)/2600)*100;    % Ah / Ah
        trace_legend = [];
    case {'HOGG','YOUNG','OHM'}
        trace_path = [];
        fig_num = fig_num-1;
end
trace_units = 'Cummulative Current (%)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;


%----------------------------------------------------------
% System Voltage
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Instrument Voltage');
switch siteID
    case 'BB1'
        trace_path  = char(fullfile(pthSite,'MET','SYS_PBox_Batt_Volt_Avg'),...
                           fullfile(pthSite,'MET','SYS_PBox_Batt_Volt2_Avg'),...
                           fullfile(pthSite,'MET','SYS_CR1000_Batt_Volt_Avg')...
                      );
        trace_legend = char('Battery #1','Battery #2','Logger');
    case {'BB2','DSM','RBM'}
        trace_path  = char(fullfile(pthSite,'MET','SYS_PBox_Batt_Volt_Avg'),...
                          fullfile(pthSite,'MET','SYS_CR1000_Batt_Volt_Avg')...                           
                      );
        trace_legend = char('Power Supply','Logger');
    case {'HOGG','YOUNG','OHM'}
        trace_path  = char(fullfile(pthSite,'flux','DRM_V_BATTERY_1_1_1'),...
                           fullfile(pthSite,'flux','VIN_1_1_1'),...
                           fullfile(pthSite,'flux','vin_sf_mean')...
                      );
        trace_legend = char('DRM V BATTERY','V_{IN} 1.1.1','vin sf mean');      
end

trace_units = 'System Voltage (V)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
sysVoltage = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% System Power
%----------------------------------------------------------

trace_name  = sprintf('%s: %s',siteID,' System Power');
switch siteID
    case 'BB1'
        if tv(ind(1))<datenum(2021,11,17)
            trace_path = sum(-sysVoltage(:,1:2).*sysCurrent(:,1:2),2,'omitnan');
        else
            trace_path = sum(-sysVoltage(:,1).*sysCurrent(:,1),2,'omitnan');
        end
    case {'BB2','DSM','RBM'}
        trace_path = sum(sysVoltage(:,1).*sysCurrent,2,'omitnan');
    case {'HOGG','YOUNG','OHM'}
        trace_path = [];
        fig_num = fig_num-1;
end
trace_units = 'System Power (W)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
sysPower = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% System Energy
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' System Energy');
switch siteID
    case {'HOGG','YOUNG','OHM'}
        trace_path = [];
        fig_num = fig_num-1;
    otherwise
        trace_path = cumsum(sysPower/2,'omitnan');
end
trace_units = 'System Energy (Wh)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
sysEnergy = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% System Temperatures
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' System Temperatures');
switch siteID
    case 'BB1'
        if tv(ind(1))<datenum(2021,11,17)
            trace_path  = char(fullfile(pthSite,'MET','SYS_BatteryBoxTC_Avg'),...  
                       fullfile(pthSite,'MET','SYS_BatteryBoxTC2_Avg'),...  
                       fullfile(pthSite,'MET','MET_CNR1_TC_Avg'),...
                       fullfile(pthSite,'MET','SYS_PanelT_CR1000_Avg')...
                       );
             trace_legend = char('Battery Box 1','Battery Box 2','CNR1','CR1000');
        else
            trace_path  = char(fullfile(pthSite,'MET','SYS_BatteryBoxTC_Avg'),...  
                       fullfile(pthSite,'MET','SYS_PowerBoxTC_Avg'),...  
                       fullfile(pthSite,'MET','MET_CNR1_TC_Avg'),...
                       fullfile(pthSite,'MET','SYS_PanelT_CR1000_Avg')...
                       );
             trace_legend = char('Battery Box 1','Battery Box 2','CNR1','CR1000');
        end
    case 'BB2'
        trace_path  = char(fullfile(pthSite,'MET','TC_Batt_Avg'),...  
                   fullfile(pthSite,'MET','SYS_PanelT_CR1000_Avg'),...  
                   fullfile(pthSite,'MET','TC_ref_Avg'),...
                   fullfile(pthSite,'MET','TC_chrgr_body_Avg'),...
                   fullfile(pthSite,'MET','TC_chrgr_space_Avg')...
                   );
        trace_legend = char('Battery Box','CR1000','TC Reference','Charger body','Charger Space');
    case {'DSM','RBM'}
        trace_path  = char(fullfile(pthSite,'MET','SYS_BatteryBoxTC_Avg'),...  
                   fullfile(pthSite,'MET','SYS_PanelT_CR1000_Avg'),...  
                   fullfile(pthSite,'MET','SYS_PanelT_AM25T_Avg'),...
                   fullfile(pthSite,'MET','SYS_chargerTC_Avg')...
                   );
        trace_legend = char('Battery Box','CR1000','TC Reference','Charger Space');
    case {'HOGG','YOUNG','OHM'}
        trace_path = [];
        fig_num = fig_num-1;
end
trace_units = 'Temperature (\circC)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% CNR4 components
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' CNR4 components');
switch siteID
    case {'BB1','BB2'}
        trace_path  = char(fullfile(pthSite,'Met','MET_CNR1_SWi_Avg'),...
                           fullfile(pthSite,'Met','MET_CNR1_SWo_Avg'),...
                           fullfile(pthSite,'Met','MET_CNR1_LWi_Avg'),...
                           fullfile(pthSite,'Met','MET_CNR1_LWo_Avg')...
                           );
    case {'DSM','RBM'}
        trace_path  = char(fullfile(pthSite,'Met','MET_CNR4_SWi_Avg'),...
                           fullfile(pthSite,'Met','MET_CNR4_SWo_Avg'),...
                           fullfile(pthSite,'Met','MET_CNR4_LWi_Avg'),...
                           fullfile(pthSite,'Met','MET_CNR4_LWo_Avg')...
                           );
    case {'HOGG','YOUNG','OHM'}
        trace_path  = char(fullfile(pthSite,'Flux','SWIN_1_1_1'),...
                           fullfile(pthSite,'Flux','SWOUT_1_1_1'),...
                           fullfile(pthSite,'Flux','LWIN_1_1_1'),...
                           fullfile(pthSite,'Flux','LWOUT_1_1_1')...
                           );
end
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
switch siteID
    case {'BB1','BB2'}
        trace_path  = char(fullfile(pthSite,'MET','MET_CNR1_Net_Avg'));
    case {'DSM','RBM'}
        trace_path  = char(fullfile(pthSite,'MET','MET_CNR4_Net_Avg'));
    case {'HOGG','YOUNG','OHM'}
        trace_path  = char(fullfile(pthSite,'Flux','RN_1_1_1'));
end

trace_legend = [];
trace_units = '(µmol/m2/s)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% PPFD
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' PPFD');
switch siteID
    case {'DSM','RBM','BB1','BB2'}
        trace_path  = char(fullfile(pthSite,'MET','MET_PARin_Avg'),...
                           fullfile(pthSite,'MET','MET_PARout_Avg')...
                           );
    case {'HOGG','YOUNG','OHM'}
        trace_path  = char(fullfile(pthSite,'Flux','PPFD_1_1_1'));
end

trace_legend = char('PPFD_{IN}','PPFD_{OUT}');
trace_units = '(µmol/m2/s)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% Wind Speed
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,'Wind Speed');
switch siteID
    case {'DSM','RBM','BB1','BB2'}
        trace_path  = char(fullfile(pthSite,'MET','MET_Young_WS_WVc1'));
    case {'HOGG','YOUNG','OHM'}
        trace_path  = char(fullfile(pthSite,'Flux','wind_speed'));
end
trace_units = '(m/s)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% Wind Direction
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,'Wind Direction');
switch siteID
    case {'DSM','RBM','BB1','BB2'}
        trace_path  = char(fullfile(pthSite,'MET','MET_Young_WS_WVc2'),fullfile(pthSite,'Flux','wind_dir'));
        trace_legend = char('MET','Sonic');
    case {'HOGG','YOUNG','OHM'}
        trace_path  = char(fullfile(pthSite,'Flux','wind_dir'));
        trace_legend = char('EC');
end

trace_units = 'deg';
unitCorrection = [1 1];
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,unitCorrection );
indAxes = indAxes+1; allAxes(indAxes) = gca;



%----------------------------------------------------------
% LI-7200 Thermocouples
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' LI-7200 Thermocouples');
switch siteID
    case {'HOGG','YOUNG','OHM'}
        trace_path = [];
        fig_num = fig_num-1;
    otherwise
        trace_path  = char(fullfile(pthSite,'monitorSites',sprintf('%s.tempIn.avg',siteID)),...
                           fullfile(pthSite,'monitorSites',sprintf('%s.tempOut.avg',siteID)));
end
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


%----------------------------------------------------------
% Diagnostics
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Diagnostics');
switch siteID
    case {'HOGG','YOUNG','OHM'}
        trace_path  = char(fullfile(pthSite,'Flux','chopper_LI_7500'),...
                          fullfile(pthSite,'Flux','detector_LI_7500'),...
                          fullfile(pthSite,'Flux','pll_LI_7500'),...
                          fullfile(pthSite,'Flux','sync_LI_7500'),...
                          fullfile(pthSite,'Flux','not_ready_LI_7700'),...
                          fullfile(pthSite,'Flux','no_signal_LI_7700'),...
                          fullfile(pthSite,'Flux','bad_temp_LI_7700'),...
                          fullfile(pthSite,'Flux','laser_temp_unregulated_LI_7700'),...
                          fullfile(pthSite,'Flux','motor_failure_LI_7700'),...
                          fullfile(pthSite,'Flux','block_temp_unregulated_LI_7700')...
                           );
        trace_legend = char('chopper_{LI-7500}','detector_{LI-7500}',...
                            'pll_{LI-7500}','sync_{LI-7500}','notReady_{LI-7700}',...
                            'nosignal_{LI-7700}','badTemp_{LI-7700}',...
                            'laserTemp_{LI-7700}','motor_{LI-7700}',...
                            'blockTemp_{LI-7700}');
    otherwise
        trace_path  = char(fullfile(pthSite,'Flux','head_detect_LI_7200'),...
                          fullfile(pthSite,'Flux','t_in_LI_7200'),...
                          fullfile(pthSite,'Flux','t_out_LI_7200'),...
                          fullfile(pthSite,'Flux','chopper_LI_7200'),...
                          fullfile(pthSite,'Flux','detector_LI_7200'),...
                          fullfile(pthSite,'Flux','pll_LI_7200'),...
                          fullfile(pthSite,'Flux','sync_LI_7200'),...
                          fullfile(pthSite,'Flux','not_ready_LI_7700'),...
                          fullfile(pthSite,'Flux','no_signal_LI_7700'),...
                          fullfile(pthSite,'Flux','bad_temp_LI_7700'),...
                          fullfile(pthSite,'Flux','laser_temp_unregulated_LI_7700'),...
                          fullfile(pthSite,'Flux','motor_failure_LI_7700'),...
                          fullfile(pthSite,'Flux','block_temp_unregulated_LI_7700')...
                           );
        trace_legend = char('head_{LI-7200}','Tin_{LI-7200}',...
                            'Tout_{LI-7200}','chopper_{LI-7200}',...
                            'detector_{LI-7200}','pll_{LI-7200}','sync_{LI-7500}',...                            
                            'detector_{LI-7700}',...
                            'nosignal_{LI-7700}','badTemp_{LI-7700}',...
                            'laserTemp_{LI-7700}','motor_{LI-7700}',...
                            'blockTemp_{LI-7700}');
end
trace_units = 'Num of errors';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% Signal Strength
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Signal Strength');
switch siteID
    case {'HOGG','YOUNG'}
        trace_path = char(fullfile(pthSite,'monitorSites',sprintf('%s.signalStrength7200.avg',siteID)),...
                           fullfile(pthSite,'monitorSites',sprintf('%s.signalStrength7700.avg',siteID)),...
                           fullfile(pthSite,'Flux','mean_value_LI_7500'),...
                          fullfile(pthSite,'Flux','rssi_77_mean')...
                          );
        trace_legend = char('7500_{MO}','7700_{MO}','7500_{EP}','7700_{EP}');
    case {'OHM'}
        trace_path = char(fullfile(pthSite,'Flux','mean_value_LI_7500'),...
                          fullfile(pthSite,'Flux','rssi_77_mean')...
                          );
        trace_legend = char('7500_{EP}','7700_{EP}');
    otherwise
        trace_path  = char(fullfile(pthSite,'monitorSites',sprintf('%s.signalStrength7200.avg',siteID)),...
                           fullfile(pthSite,'monitorSites',sprintf('%s.signalStrength7700.avg',siteID)),...
                           fullfile(pthSite,'Flux','avg_signal_strength_7200_mean'),...
                           fullfile(pthSite,'Flux','rssi_77_mean')...                           
                           );
        trace_legend = char('7200_{MO}','7700_{MO}','7200_{EP}','7700_{EP}');
end
trace_units = 'Signal Strength (%)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% LI700 Washer pump
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' LI-7700 Washer pump');
trace_path  = char(fullfile(pthSite,'Flux','pump_on_LI_7700'));
trace_legend = [];
trace_units = 'Washer Pump ON (Samples)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,[],[],char('o') );
% Add a shaded area where the trace should not exist (above 500)
shadeBadZone(500)
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% LI7700 spin motor
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' LI7700 spin motor');
trace_path  = char(fullfile(pthSite,'Flux','motor_spinning_LI_7700'));
trace_legend = [];
trace_units = 'Spin Motor ON (Samples)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,[],[],char('o') );
% Add a shaded area where the trace should not exist (above 500)
shadeBadZone(700)
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% LI7700 heaters
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' LI7700 Heaters');
trace_path  = char(fullfile(pthSite,'Flux','top_heater_on_LI_7700'),...
                  fullfile(pthSite,'Flux','bottom_heater_on_LI_7700')...
                  );
trace_legend = char('Top','Bottom');
trace_units = 'Heaters ON (Samples)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,[],[],char('o','d') );
% Add a shaded area where the trace should not exist (above 500)
shadeBadZone(37000)
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% Delay times
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Delay Times');
trace_path  = char(fullfile(pthSite,'Flux','h2o_time_lag'),...
                   fullfile(pthSite,'Flux','co2_time_lag'),...
                   fullfile(pthSite,'Flux','ch4_time_lag')...
                   );
trace_legend = char('h_2o','co_2','ch_4');
trace_units = 'Delay Times (Seconds)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num,[],[],char('o','d','x') );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% Soil moisture
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' Soil Moisture');

trace_path  = char( fullfile(pthSite,'met','a_CS650_1_1_1_Avg'),...
                    fullfile(pthSite,'met','a_CS650_1_2_1_Avg'),...
                    fullfile(pthSite,'met','a_CS650_1_3_1_Avg'),...
                    fullfile(pthSite,'met','a_CS650_1_4_1_Avg')...
                   );

trace_legend = char('1','2','3','4');
trace_units = '(%)'; 
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% CO2
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' CO_2');

trace_path  = char( fullfile(pthSite,'flux','co2_mixing_ratio')...
                   );

trace_legend = [];
trace_units = '(umol/mol)'; 
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% CH4
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' CH_4');

trace_path  = char( fullfile(pthSite,'flux','ch4_mixing_ratio')...
                   );

trace_legend = [];
trace_units = '(umol/mol)'; 
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;

%----------------------------------------------------------
% H2O
%----------------------------------------------------------
trace_name  = sprintf('%s: %s',siteID,' H_2O');

trace_path  = char( fullfile(pthSite,'flux','h2o_mixing_ratio')...
                   );

trace_legend = [];
trace_units = '(mmol/mol)'; 
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, yearIn, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;


linkaxes(allAxes,'x');


if flgPause ~= 1
    return
end
%------------------------------------------
if select == 1 %diagnostics only
    childn = get(0,'children');
    childn = sort(childn);
    N = length(childn);
    for i=1:N
        if i < 200
            figure(i);
            pause;
        end
    end
    return
end

end


function shadeBadZone(maxY)
    xl=xlim;
    yl=ylim;    
    if yl(2)> maxY
        patch([xl(1) xl(2) xl(2) xl(1)],[ maxY maxY yl(2) yl(2) ],...
              'r','facealpha',0.1,'edgecolor','none',...
              'HandleVisibility', 'off')
        yline(maxY,'r--','Max','HandleVisibility', 'off')
    end
end