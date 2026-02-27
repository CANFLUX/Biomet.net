function [t,x] = mpb_pl(ind, year, SiteID, select, fig_num_inc,pause_flag)
% MPB_pl - plotting program for MPB sites
%
%
%

% Revisions
%
% Dec 18, 2025 (Zoran)
%   - small adjustement of the 24V axes.
% Dec 31, 2022 (Zoran)
%   - It now uses 'yyyy' when creating paths instad of year. 
%   - Prevented program from trying to plot data past "now". 
%     See variable: time_now
%   - added a bunch of try-catch-end statements
% Oct 27, 2022 (Zoran)
%   - Cumulative Precip for MPB1 was wrong. It had a multiplier of 2.54
%     embeded into plt_msig. 
% Oct 15, 2022 (Zoran)
%   - Added plotting of 3 new soil heatflux plates
% Jan 23, 2022 (Zoran)
%   - changed to match datetime version of pl_msig
%   - a lot of minor fixes
% Sep 28, 2021 (Zoran)
%   - adjusted the number of samples range to accomodate new 20Hz
%   measurements (since July 15, 2021)
% July 17, 2021 (Zoran)
%   - added plots for power, voltage and temperatures for new power system
%   installed on July 14, 2021 (24V)
% Apr 16/17, 2020 (Zoran)
%   - multiple syntax fixes to improve compatibility with Matlab 2014->
%       - mostly switching from "SiteID=='MPBx'" to "strcmpi(SiteID,'MPBx')"
% Oct 29, 2018 (Zoran)
%   - added try-catch for energy balance closure.
% Nov 2, 2011
%   -added plots for LI-7500 diagnostic flags
% Oct 4, 2011 (Nick)
%   -added plots for CO2 and H2O mixing ratios
% Sept 20, 2011 (Nick)
%   -added energy balance closure plot 
% June 1, 2011 (Amanda)
%  - add new soil profile (soil moisture and soil temp p2) to mpb3
% May 25, 2011
%   -changed H2O flux plot to LE (multiply rotated E by dry air density)
%       (see line 317 of fr_calc_eddy).
% April 19, 2011 (Nick)
%   -CO2 and H2O rotated fluxes changed to 'THREE' from 'TWO' to reflect
%       HF data rotation.
%April 5, 2011 (Amanda)
%   - replaced bad logger net radiation trace with calculated net
%   - put Sonic and RMYoung Wind direction on same graph
% Feb 21, 2011
%   -reduced size of rotation matrixes to ind rather than one whole year!
%   Jan 19, 2011 (Zoran)
%       - Fixed plotting of MPB3 BattBoxTemp
%   Jan 12, 2010 (Amanda)
%  - added try-catch statement for missing hf data
%   Dec 16, 2010
%   -typo fixed in function call to apply_WPL_correction; c_v was passed by
%   error instead of H_w (Nick)
%
%    August 1, 2010 (Amanda)
%  - added WPL rotated and unrotated CO2 and H2O flux
%  - edited units and titles of plots

%   Dec, 4, 2007 (Zoran)
%       - added cumulative Ahours
%       - added cup wind speed for CSAT and RMYoung on the same plot
%  

if ind(1) > datenum(0,4,1) & ind(1) < datenum(0,10,15) %#ok<*AND2>
    WINTER_TEMP_OFFSET = 0;
else
    WINTER_TEMP_OFFSET = 20;
end

colordef white

arg_default('pause_flag',0);
arg_default('fig_num_inc',1);
arg_default('select',0);
foo = datevec(now);
arg_default('year',foo(1));

if nargin < 1 
    error 'Too few imput parameters!'
end


GMTshift = 1/3;                                  % offset to convert GMT to CST

%pthCtrl = [];

axis1 = [340 400]; %#ok<*NASGU>
axis2 = [-10 5];
axis3 = [-50 250];
axis4 = [-50 250];    

% setup properly the start and end times
time_now = datetime('now', 'TimeZone', 'GMT', 'Format','d-MMM-y HH:mm:ss Z');
st = min(ind);                                   % first day of measurements
ed = min(max(ind)+1,datenum(time_now)-datenum(year,1,0));               % last day of measurements (cannot be from the "future")
ind = st:ed;

datesTmp = datenum(year,1,[st ed]);
[rangeYears,~,~,~,~,~] = datevec(datesTmp);
rangeYears = [rangeYears(1):rangeYears(2)];
% year = rangeYears(end);                         % seems crazy to do this but view_sites uses
%                                                 % last year for regular plotting (now-7, now-14, now-30)
%                                                 % but uses the *first* year when using selected start/stop dates
%                                                 % this solves the issue and makes sure that years is the last 
%                                                 % year in the range.
                                                
pthClim = biomet_path('yyyy',SiteID,'cl');         % get the climate data path
pthEC   = biomet_path('yyyy',SiteID,'fl');         % get the eddy data path
pthEC   = fullfile(pthEC,'Above_Canopy');
pthFl   = biomet_path('yyyy',SiteID,'Flux_Logger'); 

fileName = fullfile(pthClim,'clean_tv');

tv_all = fr_round_time(read_bor(fileName,8,[],rangeYears));
t = tv_all - datenum(year,1,0)-GMTshift;            % convert decimal tv (GMT) to 
                                                    % decimal DOY (local time)                                                    
t_all = t;                                          % save time trace for later

ind = find( t_all >= st & t_all <= ed );            % extract the requested period in *local* time
t = t_all(ind);
%t = fr_round_time(t);
fig_num = 1 - fig_num_inc;
indAxes = 0;
%whitebg('w'); 

currentDate = datenum(year,1,ind(1));
c = fr_get_init(SiteID,currentDate);
IRGAnum = c.System(1).Instrument(2);
SONICnum = c.System(1).Instrument(1);

%----------------------------------------------------------
% Air Temp
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: Air Temperature';
%trace_path  = char(fullfile(pthClim,'HMP_T_Avg'),fullfile(pthFl,'Eddy_Tc_Avg'),fullfile(pthFl,'Tsonic_Avg'));
trace_path  = char(fullfile(pthClim,'HMP_T_Avg'),fullfile(pthFl,'Tsonic_Avg'));
%trace_legend= char('HMPTemp_{Avg}','Eddy_{Tc}','Sonic_{Tc}');
trace_legend= char('HMPTemp_{Avg}','Sonic_{Tc}');
trace_units = '(\circC)';
%y_axis      = [-5 30]-WINTER_TEMP_OFFSET;
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% Battery Voltage 12V
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: Logger Voltage';
trace_path  = char(fullfile(pthClim,'BattVolt_Avg'),fullfile(pthClim,'BattVolt_Min'),fullfile(pthClim,'BattVolt_Max'));
trace_legend= char('BattVolt_{Avg}','BattVolt_{Min}','BattVolt_{Max}');
trace_units = '(V)';
y_axis      = [11.5 16];
fig_num = fig_num + fig_num_inc;
BattVolt_12V = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
originalXlim = xlim;
if pause_flag == 1;pause;end


%----------------------------------------------------------
% Battery Voltage 24V
%----------------------------------------------------------
try
    trace_name  = 'Climate/Diagnostics: Battery Voltage 24V';
    trace_path  = char(fullfile(pthClim,'BattVolt_24V_Avg'),fullfile(pthClim,'BattVolt_24V_Min'),fullfile(pthClim,'BattVolt_24V_Max'));
    trace_legend= char('BattVolt_{Avg}','BattVolt_{Min}','BattVolt_{Max}');
    trace_units = '(V)';
    y_axis      = [23 30];
    fig_num = fig_num + fig_num_inc;
    BattVolt_24V = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end
catch
end

%----------------------------------------------------------
% Battery Current
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: Battery Current';
trace_path  = char(fullfile(pthClim,'BattCurrent_Avg'),fullfile(pthClim,'BattCurrent_Min'),fullfile(pthClim,'BattCurrent_Max'),...
                fullfile(pthClim,'LowPowerMode_Avg'),fullfile(pthClim,'LI7500Power_Avg'));
trace_legend= char('BattCurrent_{Avg}','BattCurrent_{Min}','BattCurrent_{Max}','LowPowerMode on','LowPowerMode(-5=off)');
trace_units = '(A)';
y_axis      = [-10 20];
fig_num = fig_num + fig_num_inc;
battCurrent = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num,[1 1 1 1 1],[0 0 0 (4.9) (5)] );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% Battery Current Cumulative
%----------------------------------------------------------
try
    trace_name  = 'Climate/Diagnostics: Cumulative Battery Current';
    trace_legend= char('BattCurrent_{Avg}');
    trace_units = '(Ah)';
    y_axis      = []; %y_axis      = [-100 100];
    ax = xlim;
    [x1,tx_new] = read_sig(trace_path(1,:), ind,year, t,0);
    fig_num = fig_num + fig_num_inc;
    indBadData =  find(x1==-999 | x1 > 50);
    indGoodData = find(x1~=-999 & x1 <= 50);
    x1(indBadData) = interp1(indGoodData,x1(indGoodData),indBadData);
    indCharging = find(x1>0);
    x1(indCharging) = x1(indCharging)*0.85;  % use 85 percent efficiency in charging
    x1 = x1* 30/60;                         % convert from Amps to AmpHours
    x = plt_msig( [cumsum(x1)], ind, trace_name, [], year, trace_units, y_axis, t, fig_num,[2.54]);
    %plt_sig1( tx_new, [cumsum(x1)], trace_name, year, trace_units, ax, y_axis, fig_num ); %#ok<*NBRAK>
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end
catch
end    

%----------------------------------------------------------
% Battery Power 24V
%----------------------------------------------------------
if year < 2021
    try
        trace_name  = 'Climate/Diagnostics: Battery Power';
        trace_path  = BattVolt_12V(:,1).*battCurrent(:,1);
        trace_legend= [];
        trace_units = '(W)';
        y_axis      = [];
        fig_num = fig_num + fig_num_inc;
        battPower = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
        indAxes = indAxes+1; allAxes(indAxes) = gca;
        if pause_flag == 1;pause;end
    catch
    end
elseif year > 2021
    try
        trace_name  = 'Climate/Diagnostics: Battery Power 24V System';
        trace_path  = BattVolt_24V(:,1).*battCurrent(:,1);
        trace_legend= [];
        trace_units = '(W)';
        y_axis      = [];
        fig_num = fig_num + fig_num_inc;
        battPower = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
        indAxes = indAxes+1; allAxes(indAxes) = gca;
        if pause_flag == 1;pause;end
    catch
    end
else
    % year 2021 is a mixed year (both 12V and 24V were active during the
    % year)
    ind12V = find(t <194);
    ind24V = find(t>=194);
     try
        trace_name  = 'Climate/Diagnostics: Battery Power';
        trace_path  = [(BattVolt_12V(ind12V,1).*battCurrent(ind12V,1)); (BattVolt_24V(ind24V,1).*battCurrent(ind24V,1))];
        trace_legend= [];
        trace_units = '(W)';
        y_axis      = [];
        fig_num = fig_num + fig_num_inc;
        battPower = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
        indAxes = indAxes+1; allAxes(indAxes) = gca;
        if pause_flag == 1;pause;end
    catch
    end   
    
end


%----------------------------------------------------------
% Cumulative Battery Energy 
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: Energy Consumption';
trace_legend= [];
trace_units = '(Wh)';
trace_path = cumsum(battPower)/2;  % divide by 2 to get Wh from W_30min
y_axis      = []; 
fig_num = fig_num + fig_num_inc;
x= plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num ); %#ok<*NBRAK>
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% Battery Temperature
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: Battery Temperature';
if strcmpi(SiteID, 'MPB3')
    trace_path  = char(fullfile(pthClim,'BattBoxTemp_Avg'));
    trace_legend= [];    
else
    trace_path  = char(fullfile(pthClim,'BattBoxTemp_Avg'),fullfile(pthClim,'BattHeatTemp_Avg'),...
                  fullfile(pthClim,'HeaterPower_Avg'));
    trace_legend= char('BattBoxTemp','BattHeatTemp','Heater ON\\OFF');              
end

trace_units = '(\circC)';
y_axis      = [];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% Logger Temp
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: Logger Temperature';
trace_path  = char(fullfile(pthClim,'LoggerRefTemp_Avg'),fullfile(pthFl,'ref_temp_Avg'),...
              fullfile(pthClim,'AM25T_RefT_Avg'),fullfile(pthClim,'HMP_T_Avg'),fullfile(pthClim,'PowerBoxTemp_Avg'));
trace_legend= char('Clim Logger','Eddy Logger','AM25T','HMP','Power Box');
trace_units = '(\circC)';
y_axis      = []; %[0 50]-WINTER_TEMP_OFFSET;
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end


%----------------------------------------------------------
% Phone Status
%----------------------------------------------------------
% trace_name  = 'Climate/Diagnostics: Phone Diagnostics';
% if SiteID== 'MPB3'
%     trace_path  = char(fullfile(pthClim,'PhonePower_Avg'));
%     trace_legend= char('Phone Schedule');
%     y_axis      = [0 5];
% else
%     trace_path  = char(fullfile(pthClim,'PhoneStatus_Avg'));
%     trace_legend= char('Phone ON\OFF');
%     y_axis      = [0 50]-WINTER_TEMP_OFFSET;
% end
% 
% trace_units = '1=ON';
% %y_axis      = [0 50]-WINTER_TEMP_OFFSET;
% fig_num = fig_num + fig_num_inc;
% x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
% if pause_flag == 1;pause;end

%----------------------------------------------------------
% IRGA Diagnostic
%----------------------------------------------------------
indAxesOld = indAxes; % save this one and use it to remove all bad axes in case try-catch
                      % catches an error
try
    trace_name  = 'Climate/Diagnostics: IRGA diag';
    trace_path  = char(fullfile(pthEC,'Instrument_1.Avg_4'),fullfile(pthFl,'Idiag_Avg'),fullfile(pthFl,'Idiag_Max'),fullfile(pthFl,'Idiag_Min'));
    trace_legend= char('Idiag EC','Idiag logger_{Avg}','Idiag logger_{Max}','Idiag logger_{Min}');
    trace_units = '';
    y_axis      = [240 260];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end

    % break up diagnostic flag by binary bit
    Idiag_lgr    = read_sig(fullfile(pthFl,'Idiag_Avg'), ind,year, t,0);
    Idiag_lgrmax = read_sig(fullfile(pthFl,'Idiag_Max'), ind,year, t,0);
    Idiag_lgrmin = read_sig(fullfile(pthFl,'Idiag_Min'), ind,year, t,0);
    IdiagEC      = read_sig(fullfile(pthEC,'Instrument_1.Avg_4'), ind,year, t,0);

    nptsChopper  = read_sig(fullfile(pthEC,'Instrument_5.MiscVariables.Chopper_Sum_Bad'), ind,year, t,0);
    nptsDetector = read_sig(fullfile(pthEC,'Instrument_5.MiscVariables.Detector_Sum_Bad'), ind,year, t,0);
    nptsPLL      = read_sig(fullfile(pthEC,'Instrument_5.MiscVariables.PLL_Sum_Bad'), ind,year, t,0);
    nptsSync     = read_sig(fullfile(pthEC,'Instrument_5.MiscVariables.Sync_Sum_Bad'), ind,year, t,0);
    
    ind_bad= find( Idiag_lgr==-999 | isnan(Idiag_lgr));
    Idiag_lgr(ind_bad)=0; %#ok<*FNDSB>
    
    ind_bad= find( Idiag_lgrmax==-999| isnan(Idiag_lgrmax));
    Idiag_lgrmax(ind_bad)=0;
    
    ind_bad= find( Idiag_lgrmin==-999| isnan(Idiag_lgrmin));
    Idiag_lgrmin(ind_bad)=0;
    
    ind_bad= find( IdiagEC==-999| isnan(IdiagEC));
    IdiagEC(ind_bad)=0;

    diag_rawlgr  = dec2bin(round(Idiag_lgr));
    Chopper_lgr  = bin2dec(diag_rawlgr(:,1));
    Detector_lgr = bin2dec(diag_rawlgr(:,2));
    PLL_lgr      = bin2dec(diag_rawlgr(:,3));
    Sync_lgr     = bin2dec(diag_rawlgr(:,4));
    AGC_lgr      = bin2dec(diag_rawlgr(:,5:end))*6.25;

    diag_rawlgrmax  = dec2bin(round(Idiag_lgrmax));
    Chopper_lgrmax  = bin2dec(diag_rawlgrmax(:,1));
    Detector_lgrmax = bin2dec(diag_rawlgrmax(:,2));
    PLL_lgrmax     = bin2dec(diag_rawlgrmax(:,3));
    Sync_lgrmax     = bin2dec(diag_rawlgrmax(:,4));
    AGC_lgrmax      = bin2dec(diag_rawlgrmax(:,5:end))*6.25;
    
     diag_rawlgrmin  = dec2bin(round(Idiag_lgrmin));
    Chopper_lgrmin  = bin2dec(diag_rawlgrmin(:,1));
    Detector_lgrmin = bin2dec(diag_rawlgrmin(:,2));
    PLL_lgrmin      = bin2dec(diag_rawlgrmin(:,3));
    Sync_lgrmin     = bin2dec(diag_rawlgrmin(:,4));
    AGC_lgrmin      = bin2dec(diag_rawlgrmin(:,5:end))*6.25;
    
    diag_rawEC  = dec2bin(round(IdiagEC));
    Chopper_EC  = bin2dec(diag_rawEC(:,1));
    Detector_EC = bin2dec(diag_rawEC(:,2));
    PLL_EC      = bin2dec(diag_rawEC(:,3));
    Sync_EC     = bin2dec(diag_rawEC(:,4));
    AGC_EC      = bin2dec(diag_rawEC(:,5:end))*6.25;

    % diagnostic plots

    % Chopper
    trace_name  = 'Climate/Diagnostics: IRGA diagnostics, Chopper (OK = 1)';
    trace_legend= char('logger_{AVG}','logger_{MAX}','logger_{MIN}+0.1','EC_{AVG}');
    trace_units = '';
    y_axis      = [0 1.2];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( [Chopper_lgr Chopper_lgrmax Chopper_lgrmin+0.1 Chopper_EC], ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end

    % Detector
    trace_name  = 'Climate/Diagnostics: IRGA diagnostics, Detector (OK = 1)';
    trace_legend= char('logger_{AVG}','logger_{MAX}','logger_{MIN}+0.1','EC_{AVG}');
    trace_units = '';
    y_axis      = [0 1.2];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( [Detector_lgr Detector_lgrmax Detector_lgrmin+0.1 Detector_EC], ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end

    % PLL--Chopper Motor
    trace_name  = 'Climate/Diagnostics: IRGA diagnostics, PLL/Chopper Motor (OK = 1)';
    trace_legend= char('logger_{AVG}','logger_{MAX}','logger_{MIN}+0.1','EC_{AVG}');
    trace_units = '';
    y_axis      = [0 1.2];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( [PLL_lgr PLL_lgrmax PLL_lgrmin+0.1 PLL_EC], ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end

    % Sync
    trace_name  = 'Climate/Diagnostics: IRGA diagnostics, Sync (OK = 1)';
    trace_legend= char('logger_{AVG}','logger_{MAX}','logger_{MIN}+0.1','EC_{AVG}');
    trace_units = '';
    y_axis      = [0 1.2];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( [Sync_lgr Sync_lgrmax Sync_lgrmin+0.1 Sync_EC], ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end

    % AGC
    trace_name  = 'Climate/Diagnostics: IRGA diagnostics, AGC (window clarity %)';
    trace_legend= char('logger_{AVG}','logger_{MAX}','logger_{MIN}','EC_{AVG}');
    trace_units = '';
    y_axis      = [0 100];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( [AGC_lgr AGC_lgrmax AGC_lgrmin AGC_EC], ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end
    
    % Number of bad points per hhour by type
    
     fig_num = fig_num + fig_num_inc;
     figure(fig_num);
     plot(t,nptsChopper,'rd',t,nptsDetector,'bs',t,...
           nptsPLL,'go',t,nptsSync,'y^','MarkerSize',10,'Linewidth',2);
     trace_name=[SiteID ' Climate/Diagnostics: IRGA errors per half-hour by type'];
     title(trace_name);
     set(fig_num,'menubar','none',...
            'numbertitle','off',...
            'Name',trace_name);
     legend('Chopper','Detector','PLL','Sync');
     %set(gca,'YLim',[0 20])
     grid on;
    if pause_flag == 1;pause;end
catch
    % If error happens remove all the (possibly bad) axes from allAxes
    indAxes = indAxesOld;
    allAxes(indAxes+1:end) = [];
end

%--------------------------------------------------------
% Number of Samples (sample frequency)
%--------------------------------------------------------

try
    instrumentString = sprintf('Instrument_%d.',IRGAnum);
    sonicString =  sprintf('Instrument_%d.',SONICnum);

%     numOfSamplesIRGA = read_bor([pthEC '\' instrumentString 'MiscVariables.NumOfSamples']);
%     numOfSamplesSonic = read_bor([pthEC '\' sonicString 'MiscVariables.NumOfSamples']);
%     numOfSamplesEC = read_bor([pthEC '\' SiteID '.MiscVariables.NumOfSamples']);
    trace_path = char([pthEC '\' instrumentString 'MiscVariables.NumOfSamples'],...
                      [pthEC '\' sonicString 'MiscVariables.NumOfSamples'],...
                      [pthEC '\' SiteID '.MiscVariables.NumOfSamples']);
    trace_legend = char('Sonic','IRGA','EC'); 
    trace_name  = 'Climate/Diagnostics: Number of Samples';
    trace_units = '';
    y_axis = [];
    fig_num = fig_num+1;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
catch
    close(fig_num);
    fig_num = fig_num -1 ;
end

%----------------------------------------------------------
% CO2 density
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: CO2 density';
trace_path  = char(fullfile(pthEC,'Instrument_5.Avg_1'),fullfile(pthEC,'Instrument_5.Min_1'),fullfile(pthEC,'Instrument_5.Max_1')...
    ,fullfile(pthFl,'CO2_Avg'));
trace_legend= char('CO2_{Avg}','CO2_{Min}','CO2_{Max}','CO2_{Avg Logger}');
trace_units = '(mmol CO_{2} m^{-3})';
y_axis      = [-5 40];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% CO2 mixing ratio
%----------------------------------------------------------
try
    trace_name  = 'Climate/Diagnostics: CO2 mixing ratio';
    trace_units = '(\mumol CO_{2} mol^{-1} dry air)';
    y_axis      = [350 600];
    co2_avg = read_sig(fullfile(pthFl,'CO2_Avg'), ind,year, t,0);
    co2_max = read_sig(fullfile(pthFl,'CO2_Max'), ind,year, t,0);
    co2_min = read_sig(fullfile(pthFl,'CO2_Min'), ind,year, t,0);
    h2o_avg = read_sig(fullfile(pthFl,'H2O_Avg'), ind,year, t,0);
    h2o_max = read_sig(fullfile(pthFl,'H2O_Max'), ind,year, t,0);
    h2o_min = read_sig(fullfile(pthFl,'H2O_Min'), ind,year, t,0);

    Tair = read_sig(fullfile(pthFl,'Tsonic_Avg'), ind,year, t,0);
    pbar = read_sig(fullfile(pthFl,'Irga_P_Avg'), ind,year, t,0);


    [Cmix_avg, Hmix_avg,Cmolfr_avg, Hmolfr_avg] = fr_convert_open_path_irga(co2_avg,h2o_avg,Tair,pbar); %#ok<*ASGLU>
    [Cmix_max,Hmix_max,junk,junk]               = fr_convert_open_path_irga(co2_max,h2o_max,Tair,pbar);
    [Cmix_min,Hmix_min,junk,junk]               = fr_convert_open_path_irga(co2_min,h2o_min,Tair,pbar);

    trace_legend= char('CO2_{Avg}','CO2_{Min}','CO2_{Max}');

    fig_num = fig_num + fig_num_inc;
    x = plt_msig( [Cmix_avg Cmix_min Cmix_max ], ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end
catch
end

%----------------------------------------------------------
% H2O density
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: Water vapour density';
trace_path  = char(fullfile(pthEC,'Instrument_5.Avg_2'),fullfile(pthEC,'Instrument_5.Min_2'),fullfile(pthEC,'Instrument_5.Max_2')...
    ,fullfile(pthFl,'H2O_Avg'));
trace_legend= char('H2O_{Avg}','H2O_{Min}','H2O_{Max}','H2O_{Avg logger}');
trace_units = '(mmol H_{2}O m^{-3})';
y_axis      = [0 700];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% H2O mixing ratio
%----------------------------------------------------------
try
    trace_name  = 'Climate Diagnistics: H2O mixing ratio';
    trace_units = '(mmol H_{2}O mol^{-1} dry air)';
    y_axis      = [0 25];
    trace_legend= char('H2O_{Avg}','H2O_{Min}','H20_{Max}');

    fig_num = fig_num + fig_num_inc;
    x = plt_msig( [Hmix_avg Hmix_min Hmix_max ], ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end
catch
end
%----------------------------------------------------------
% Sonic Diagnostic
%----------------------------------------------------------
trace_name  = [SiteID '-Sonic diag'];
%trace_path  = char(fullfile(pthEC,'Instrument_1.Avg_9'),fullfile(pthFl,'Sdiag_Avg'));
trace_path  = char(fullfile(pthFl,'Sdiag_Avg'),fullfile(pthFl,'Sdiag_Max'),fullfile(pthFl,'Sdiag_Min'),...
    fullfile(pthEC,'Instrument_2.Avg_5'));
%trace_legend= char('Sdiag','Sdiag logger');
trace_legend= char('Sdiag logger_{avg}','Sdiag logger_{max}','Sdiag logger_{min}','Sdiag EC_{avg}');
trace_units = '';
y_axis      = [-10 700];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

try
    npts_Apm_Low_Sum_Bad     = read_sig(fullfile(pthEC,'Instrument_2.MiscVariables.BadPointsFlag.Apm_Low_Sum_Bad'), ind,year, t,0);
    npts_Apm_Hi_Sum_Bad      = read_sig(fullfile(pthEC,'Instrument_2.MiscVariables.BadPointsFlag.Apm_Hi_Sum_Bad'), ind,year, t,0);
    npts_Poor_Lock_Sum_Bad   = read_sig(fullfile(pthEC,'Instrument_2.MiscVariables.BadPointsFlag.Poor_Lock_Sum_Bad'), ind,year, t,0);
    npts_Path_Length_Sum_Bad = read_sig(fullfile(pthEC,'Instrument_2.MiscVariables.BadPointsFlag.Path_Length_Sum_Bad'), ind,year, t,0);
    npts_Pts_Sum_Bad         = read_sig(fullfile(pthEC,'Instrument_2.MiscVariables.BadPointsFlag.Pts_Sum_Bad'), ind,year, t,0);

    % Number of bad points per hhour by type
    try
        fig_num = fig_num + fig_num_inc;
        figure(fig_num);
        plot(t,npts_Apm_Low_Sum_Bad,'rd',t,npts_Apm_Hi_Sum_Bad,'bs',t,...
            npts_Poor_Lock_Sum_Bad,'go',t,npts_Path_Length_Sum_Bad,'y^',...
            t,npts_Pts_Sum_Bad,'m>','MarkerSize',10,'Linewidth',2);
        trace_name=[SiteID ' Climate/Diagnostics: Sonic errors per half-hour by type'];
        title(trace_name);
        set(fig_num,'menubar','none',...
            'numbertitle','off',...
            'Name',trace_name);
        legend('Apm_{Low}','Apm_{Hi}','Poor Lock','Path Length','Pts');
        %set(gca,'YLim',[0 20])
        grid on;
        if pause_flag == 1;pause;end
    catch
        close (fig_num);
        fig_num=fig_num-1;
    end
catch
end
%----------------------------------------------------------
% Sonic wind speed logger
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: CSAT Wind Speed Logger';
trace_path  = char(fullfile(pthFl,'u_wind_Avg'),fullfile(pthFl,'v_wind_Avg'),fullfile(pthFl,'w_wind_Avg'));
trace_legend= char('u wind','v wind','w wind');
trace_units = '(m s^{-1})';
y_axis      = [-10 10];
fig_num = fig_num + fig_num_inc;
x_CSAT = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% Wind speed (RM Young)
%----------------------------------------------------------
trace_name  = 'Climate: Wind Speed Averages (RM Young)';
trace_path  = char(fullfile(pthClim,'WS_ms_S_WVT'));
trace_legend = char('CSAT','RMYoung (avg)');
trace_units = '(m s^{-1})';
y_axis      = [0 10];
fig_num = fig_num + fig_num_inc;
x_RMYoung = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
clf
x = plt_msig( [sqrt(sum(x_CSAT'.^2))' x_RMYoung], ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end


%----------------------------------------------------------
% Precipitation - needs a multiplier
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: Rainfall';
trace_path  = char(fullfile(pthClim,'RainFall_Tot'));
trace_legend= char('Rainfall_{tot}');
trace_units = '(mm halfhour^{-1})';
y_axis      = [0 4];
fig_num = fig_num + fig_num_inc;
if strcmpi(SiteID,'MPB1') || strcmpi(SiteID,'MPB3')
    x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
else
    x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num,[2.54]);
end
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% Cumulative Precipitation
%----------------------------------------------------------
try
    indx = find( t_all >= 1 & t_all <= ed );                    % extract the period from
    tx = t_all(indx);                                           % the beginning of the year
    indNew = [1:length(indx)]+round(GMTshift*48);               % use GMTshift to align the data with time vector

    trace_name  = 'Climate: Cumulative Rain';
    trace_units = '(mm)';
    y_axis      = [];
    ax = [st ed];
    [x1,tx_new] = read_sig(trace_path(1,:), indNew,year, tx,0);

    if strcmpi(SiteID,'MPB2')
       x1 = x1*2.54;
    else
       x1 = x1*1;   
    end
    fig_num = fig_num + fig_num_inc;

    %plt_sig1( tx_new, [cumsum(x1)], trace_name, year, trace_units, ax, y_axis, fig_num );
    x = plt_msig( [cumsum(x1)], indNew, trace_name, [], rangeYears(end), trace_units, y_axis, tx_new, fig_num);
    xlim(originalXlim);
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end
catch
end    

%----------------------------------------------------------
% CNR1 temperature
%----------------------------------------------------------
trace_name  = 'CNR1 temperature';
trace_path  = char(fullfile(pthClim,'cnr1_Temp_avg'), fullfile(pthClim,'HMP_T_Avg'));
trace_legend = char('CNR1_{PRT}','T_{HMP}');
trace_units = '(degC)';
y_axis      = []; %[0 50] - WINTER_TEMP_OFFSET;
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
T_CNR1 = x(:,1);
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%-----------------------------------
% Net radiation SW and LW
%-----------------------------------
try
    trace_name  = 'Radiation Above Canopy';
    LongWaveOffset =(5.67E-8*(273.15+T_CNR1).^4);
    %Net_cnr1_AVG = read_bor(fullfile(pthClim,'CNR_net_avg'));
    S_upper_AVG = read_sig(fullfile(pthClim,'swd_Avg'), ind,year, t,0);
    S_lower_AVG = read_sig(fullfile(pthClim,'swu_Avg'), ind,year, t,0);
    lwu = read_sig(fullfile(pthClim,'lwu_Avg'), ind,year, t,0);
    lwd = read_sig(fullfile(pthClim,'lwd_Avg'), ind,year, t,0);

    trace_legend = char('swd Avg','swu Avg','lwd Avg','lwu Avg','Net_{calc}');
    trace_units = '(W m^{-2})';
    y_axis      = [-200 1400];

    if strcmpi(SiteID,'MPB1')
        L_upper_AVG = lwd + LongWaveOffset;
        L_lower_AVG = lwu + LongWaveOffset;
    elseif strcmpi(SiteID,'MPB2')
        %reverse up and down and change signs
        L_upper_AVG = -lwu + LongWaveOffset;
        L_lower_AVG = -lwd + LongWaveOffset;
        % reverse up and down
        S_upper_AVG = read_sig(fullfile(pthClim,'swu_Avg'), ind,year, t,0);
        S_lower_AVG = read_sig(fullfile(pthClim,'swd_Avg'), ind,year, t,0);
    else
        L_upper_AVG = lwd + LongWaveOffset;
        L_lower_AVG = lwu + LongWaveOffset;
    end
    Net_cnr1_calc = L_upper_AVG - L_lower_AVG  + S_upper_AVG - S_lower_AVG;
    trace_path = [S_upper_AVG S_lower_AVG L_upper_AVG L_lower_AVG Net_cnr1_calc];

    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num);
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end
catch
end

%----------------------------------------------------------
% Barometric Pressure
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: Barometric Pressure';
trace_path  = char(fullfile(pthEC,'MiscVariables.BarometricP'),fullfile(pthFl,'Irga_P_Avg'));
trace_legend= char('Pressure','Pressure logger');
trace_units = '(kPa)';
y_axis      = [30 110];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end





%------------------------------------------
if select == 1 %diagnostics only
    linkaxes(allAxes,'x');
    if pause_flag ~= 1
        childn = get(0,'children');
        childn = sort(childn);
        N = length(childn);
        for i=1:N
            if i < 200 
                figure(i);
%                if i ~= childn(N-1)
                    pause;
%                end
            end
        end
    end
    return
end

%----------------------------------------------------------
% HMP Temp
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: HMP Temperature';
trace_path  = char(fullfile(pthClim,'HMP_T_Avg'),fullfile(pthFl,'HMP_T_Min'),fullfile(pthClim,'HMP_T_Max'));
trace_legend= char('HMPTemp_{Avg}','HMPTemp_{Min}','HMPTemp_{Max}');
trace_units = '(\circC)';
y_axis      = []; %[0 40]-WINTER_TEMP_OFFSET;
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% HMP RH
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: HMP Relative Humidity';
trace_path  = char(fullfile(pthClim,'HMP_RH_Avg'),fullfile(pthClim,'HMP_RH_Min'),fullfile(pthClim,'HMP_RH_Max'));
trace_legend= char('HMP_RH_{Avg}','HMP_RH_{Min}','HMP_RH_{Max}');
trace_units = '(%)';
y_axis      = [0 100];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% Soil moisture
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: Soil water content';
if strcmpi(SiteID,'MPB3')
    trace_path  = char(fullfile(pthClim,'H2Opercent_3cm_Avg'),fullfile(pthClim,'H2Opercent_20cm_Avg'),fullfile(pthClim,'H2Opercent_50cm_Avg'),...
                          fullfile(pthClim,'H2Opercent_100cm_Avg'), fullfile(pthClim,'H2Opercent_p2_3cm_Avg'), fullfile(pthClim,'H2Opercent_p2_20cm_Avg'),...
                          fullfile(pthClim,'H2Opercent_p2_50cm_Avg'));
    trace_legend= char('H2O% 3cm','H2O% 20cm','H2O% 50cm','H2O% 100cm', 'H2O% 3cm p2', 'H2O% 20cm p2', 'H2O% 50cm p2');
else
    trace_path  = char(fullfile(pthClim,'H2Opercent_Avg1'),fullfile(pthClim,'H2Opercent_Avg2'),fullfile(pthClim,'H2Opercent_Avg3'));
    trace_legend= char('H2O%_{1}','H2O%_{2}','H2O%_{3}');
end

trace_units = '(m^{3} m^{-3})';

if strcmpi(SiteID,'MPB1') || strcmpi(SiteID,'MPB3')
   y_axis      = [0 1];
else
   y_axis      = [0 600];   
end

fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% Air Temp vs. Surface Temp
%----------------------------------------------------------
if strcmpi(SiteID,'MPB3')
    trace_name  = 'Climate/Diagnostics: Air Temp vs. Surface Temp (IR Thermometer)';
    trace_path  = char(fullfile(pthClim,'HMP_T_Avg'),fullfile(pthClim,'Surf_Soil_temp_Avg'));
    trace_legend= char('HMPTemp_{Avg}','Apogee SI-111');
    trace_units = '(\circC)';
    y_axis      = []; %[0 40]-WINTER_TEMP_OFFSET;
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end
end
%----------------------------------------------------------
% Soil temperature
%----------------------------------------------------------
if year == 2006

    trace_name  = 'Climate/Diagnostics: Soil temperature';
    % trace_path  = char(fullfile(pthClim,'soil_temperature_Avg'),fullfile(pthClim,'soil_tempera_Avg1'),fullfile(pthClim,'soil_tempera_Avg2'),fullfile(pthClim,'soil_tempera_Avg3'),fullfile(pthClim,'soil_tempera_Avg4'),fullfile(pthClim,'Soil_temp_Avg1'),fullfile(pthClim,'Soil_temp_Avg2'),fullfile(pthClim,'Soil_temp_Avg3'),fullfile(pthClim,'Soil_temp_Avg4'),fullfile(pthClim,'Soil_temp_Avg5'),fullfile(pthClim,'Soil_temp_Avg6'));
    % trace_legend= char('T_{s}','T_{s1}','T_{s2}','T_{s3}','T_{s4}','Ts_{1}','Ts_{2}','Ts_{3}','Ts{4}','Ts{5}','Ts{6}');

    trace_path  = char(fullfile(pthClim,'soil_temperature_Avg'),fullfile(pthClim,'soil_tempera_Avg1'),...
                  fullfile(pthClim,'soil_tempera_Avg2'),fullfile(pthClim,'soil_tempera_Avg3'),fullfile(pthClim,'soil_tempera_Avg4'));
    trace_legend= char('T_{sx}','T_{s20}','T_{s10}','T_{s2}','T_{s50}');
    trace_units = '(\circC)';
    y_axis      = [-15 30];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end
else
    trace_name  = 'Climate/Diagnostics: Soil temperature';
    % trace_path  = char(fullfile(pthClim,'Soil_temp_Avg1'),fullfile(pthClim,'Soil_temp_Avg2'),...
    %                fullfile(pthClim,'Soil_temp_Avg3'),fullfile(pthClim,'Soil_temp_Avg4'),fullfile(pthClim,'Soil_temp_Avg5'),fullfile(pthClim,'Soil_temp_Avg6'));
    % trace_legend= char('Ts_{20}','Ts_{10}','Ts_{2}','Ts{50}','Ts{5}','Ts{6}');
    if strcmpi(SiteID,'MPB3')
        trace_path  = char(fullfile(pthClim,'Soil_temp_3cm_Avg'),fullfile(pthClim,'Soil_temp_10cm_Avg'),...
                  fullfile(pthClim,'Soil_temp_20cm_Avg'),fullfile(pthClim,'Soil_temp_50cm_Avg'),fullfile(pthClim,'Soil_temp_100cm_Avg'),...
                  fullfile(pthClim,'Soil_temp_p2_3cm_Avg'), fullfile(pthClim,'Soil_temp_p2_10cm_Avg'), fullfile(pthClim,'Soil_temp_p2_20cm_Avg'), fullfile(pthClim,'Soil_temp_p2_50cm_Avg'));
        trace_legend= char('T_{s} 3cm','T_{s} 10cm','T_{s} 20cm','T_{s} 50cm','T_{s} 100cm', 'T_{s} 3cm p2', 'T_{s} 10cm p2', 'T_{s} 20cm p2', 'T_{s} 50cm p2');
    else
       trace_path  = char(fullfile(pthClim,'Soil_temp_Avg1'),fullfile(pthClim,'Soil_temp_Avg2'),fullfile(pthClim,'Soil_temp_Avg3'),...
                          fullfile(pthClim,'Soil_temp_Avg4'),fullfile(pthClim,'Soil_temp_Avg5'));
       if strcmpi(SiteID,'MPB1')
          trace_legend= char('Ts_{50}','Ts_{5}','Ts_{10}','Ts{20}','');
       else              
          trace_legend= char('Ts_{2}','Ts_{5}','Ts_{10}','Ts{30}','Ts{50}');
       end
    end
    trace_units = '(\circC)';
    y_axis      = [-15 30];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end
end

% added covs and Fc Nick and Amanda June 15, 2010.
%----------------------------------------------------------
% Covariances
%----------------------------------------------------------
trace_name  = 'Covariances: w*CO2 (raw)';
trace_path  = char(fullfile(pthFl,'CO2_cov_Cov5'));
trace_legend= char('wco2_cov_{Avg}');
trace_units = '(mmol CO_{2} m^{-2} s^{-1})';
y_axis      = [-0.05 0.05];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% Covariances
%----------------------------------------------------------
trace_name  = 'Covariances: w*H2O (raw)';
trace_path  = char(fullfile(pthFl,'CO2_cov_Cov9'));
trace_legend= char('wh2o_cov_{Avg}');
trace_units = '(mmol H_{2}O m^{-2} s^{-1})';
y_axis      = [-0.5 5];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% Covariances
%----------------------------------------------------------
trace_name  = 'Covariances: w*T (kinematic)';
trace_path  = char(fullfile(pthFl,'Tc_Temp_cov_Cov4'),fullfile(pthFl,'Tsonic_cov_Cov4'));
trace_legend= char('wTceddy_cov_{Avg}','wTsonic_cov_{Avg}');
trace_units = '(\circC m s^{-1})';
y_axis      = [-0.05 0.5];
fig_num = fig_num + fig_num_inc;
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% add prelim Fc calculation (link to Amanda's function)
% %----------------------------------------------------------
% trace_name  = 'Fc unrotated, WPL-corrected';
% trace_legend= char('Fc_{raw}');
% trace_units = '(\mumol m^{-2} s^{-1})';
% 
% [Fc,E] = WPLcorrection(SiteID,year);
% 
% fig_num = fig_num + fig_num_inc;
% 
% y_axis      = [-15 20];
% x = plt_msig( Fc, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
% 
% if pause_flag == 1;pause;end



%----------------------------------------------------------
%  CO2 Flux (from high frequency data, WPL rotated and unrotated from raw
%  covariances)
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: CO2 Flux'; 

%load mean wind vector
% u = read_bor(fullfile(pthFl, 'u_wind_Avg'));
% v = read_bor(fullfile(pthFl, 'v_wind_Avg'));
% w = read_bor(fullfile(pthFl, 'w_wind_Avg'));
u = read_sig( fullfile(pthFl, 'u_wind_Avg'), ind,year, t,0 );
v = read_sig( fullfile(pthFl, 'v_wind_Avg'), ind,year, t,0 );
w = read_sig( fullfile(pthFl, 'w_wind_Avg'), ind,year, t,0 );
 
meansIn = [u v w];

% load raw covariances 

% % c, H, u, v, w
% c_c = read_bor(fullfile(pthFl, 'CO2_cov_Cov1'));
% %pthFl = biomet_path(year,SiteID,'Flux_Logger'); 
% c_H = read_bor(fullfile(pthFl,'CO2_cov_Cov2'));
% c_u = read_bor(fullfile(pthFl,'CO2_cov_Cov3'));
% c_v = read_bor(fullfile(pthFl,'CO2_cov_Cov4')); 
% c_w = read_bor(fullfile(pthFl,'CO2_cov_Cov5'));   
% H_H = read_bor(fullfile(pthFl,'CO2_cov_Cov6')); 
% H_u = read_bor(fullfile(pthFl,'CO2_cov_Cov7'));
% H_v = read_bor(fullfile(pthFl,'CO2_cov_Cov8'));
% H_w = read_bor(fullfile(pthFl,'CO2_cov_Cov9'));
% u_u = read_bor(fullfile(pthFl,'CO2_cov_Cov10'));
% u_v = read_bor(fullfile(pthFl,'CO2_cov_Cov11'));
% u_w = read_bor(fullfile(pthFl,'CO2_cov_Cov12'));
% v_v = read_bor(fullfile(pthFl,'CO2_cov_Cov13'));
% v_w = read_bor(fullfile(pthFl,'CO2_cov_Cov14'));
% w_w = read_bor(fullfile(pthFl,'CO2_cov_Cov15'));

% c, H, u, v, w
c_c = read_sig(fullfile(pthFl, 'CO2_cov_Cov1'), ind,year, t,0);
%pthFl = biomet_path(year,SiteID,'Flux_Logger'); 
c_H = read_sig(fullfile(pthFl,'CO2_cov_Cov2'), ind,year, t,0);
c_u = read_sig(fullfile(pthFl,'CO2_cov_Cov3'), ind,year, t,0);
c_v = read_sig(fullfile(pthFl,'CO2_cov_Cov4'), ind,year, t,0); 
c_w = read_sig(fullfile(pthFl,'CO2_cov_Cov5'), ind,year, t,0);   
H_H = read_sig(fullfile(pthFl,'CO2_cov_Cov6'), ind,year, t,0); 
H_u = read_sig(fullfile(pthFl,'CO2_cov_Cov7'), ind,year, t,0);
H_v = read_sig(fullfile(pthFl,'CO2_cov_Cov8'), ind,year, t,0);
H_w = read_sig(fullfile(pthFl,'CO2_cov_Cov9'), ind,year, t,0);
u_u = read_sig(fullfile(pthFl,'CO2_cov_Cov10'), ind,year, t,0);
u_v = read_sig(fullfile(pthFl,'CO2_cov_Cov11'), ind,year, t,0);
u_w = read_sig(fullfile(pthFl,'CO2_cov_Cov12'), ind,year, t,0);
v_v = read_sig(fullfile(pthFl,'CO2_cov_Cov13'), ind,year, t,0);
v_w = read_sig(fullfile(pthFl,'CO2_cov_Cov14'), ind,year, t,0);
w_w = read_sig(fullfile(pthFl,'CO2_cov_Cov15'), ind,year, t,0);

% % Tsonic, u, v, w
T_T = read_sig(fullfile(pthFl,'Tsonic_cov_Cov1'), ind,year, t,0);
T_u = read_sig(fullfile(pthFl,'Tsonic_cov_Cov2'), ind,year, t,0);
T_v = read_sig(fullfile(pthFl,'Tsonic_cov_Cov3'), ind,year, t,0);
T_w = read_sig(fullfile(pthFl,'Tsonic_cov_Cov4'), ind,year, t,0);

cc = read_sig(fullfile(pthFl,'CO2_Avg'), ind,year, t,0);              % cc is molar CO2 density (mmol/m3)
cv = read_sig(fullfile(pthFl,'H2O_Avg'), ind,year, t,0);              % cv is molar water vapour density (mmol/m3)
T = read_sig(fullfile(pthFl,'Tsonic_avg'), ind,year, t,0);   % load T and P
P = read_sig(fullfile(pthFl,'Irga_P_Avg'), ind,year, t,0);

% rotation of raw covariances
C1 = [u_u  u_v  v_v  u_w  v_w  w_w  c_u  c_v  c_w  c_c  H_u  H_v  H_w  c_H  H_H ];
C2 = [u_u  u_v  v_v  u_w  v_w  w_w  T_u  T_v  T_w  T_T];


[wT_rot, wH_rot, wc_rot] = rotate_cov_matrices(meansIn, C1, C2, T_w);

% WPL for rotated and unrotated covariances
[Fc_wpl, E_wpl] = apply_WPL_correction(c_w, H_w, T_w, cc, cv, T, P);  %unrotated, fixed typo Dec 16, 2010 (Nick)
[Fc_rot, E_rot] = apply_WPL_correction(wc_rot, wH_rot, wT_rot, cc, cv, T, P);  %rotated


trace_units = '(\mumol CO_{2} m^{-2} s^{-1})';
y_axis      = [-10 15];
fig_num = fig_num + fig_num_inc;

% prevent graph from closing if trace is missing (Amanda, Jan 2011)
try
    Fc_hf = read_sig(fullfile(pthEC,[SiteID '.Three_Rotations.AvgDtr.Fluxes.Fc']), ind,year, t,0);
    trace_legend= char('CO_{2} 3 rotations (high freq)', 'CO_{2} WPL 3 rotations (raw)', 'CO_{2} WPL unrotated (raw)');
    x = plt_msig( [Fc_hf Fc_rot Fc_wpl],ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
catch
%     FCfnstr = fullfile(pthEC,[SiteID '.Three_Rotations.AvgDtr.Fluxes.Fc']);
%     disp(['Could not load ' FCfnstr ]);
%     disp(lasterr);
%     trace_legend= char('CO_{2} WPL 3 rotations (raw)', 'CO_{2} WPL unrotated (raw)');
%     x = plt_msig( [Fc_rot Fc_wpl], ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
end

if pause_flag == 1;pause;end

%----------------------------------------------------------
% add  prelim H20 flux WPL calculation (link to Amanda's function)
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: LE flux';
%trace_legend= char('LE WPL 3 rotations (raw)', 'LE WPL unrotated (raw)');
trace_units = '(W m^{-2} )';

BarometricP_logger           = read_sig(fullfile(pthFl,'Irga_P_Avg'), ind,year, t,0);
Tair_logger                  = read_sig(fullfile(pthClim,'HMP_T_Avg'), ind,year, t,0);

[Cmix, Hmix, C, H] = fr_convert_open_path_irga(cc, cv, Tair_logger, BarometricP_logger);

R     = 8.31451; 
ZeroK = 273.15;
%mol_density_dry_air_EC   = (BarometricP./(1+h2o_bar_EC/1000)).*(1000./(R*(Tair_EC+ZeroK)));
mol_density_dry_air_logger   = (BarometricP_logger./(1+Hmix/1000)).*(1000./(R*(Tair_logger+ZeroK)));

LE_rot = E_rot.*mol_density_dry_air_logger;
LE_wpl = E_wpl.*mol_density_dry_air_logger;
LE_hf = read_sig(fullfile(pthEC,[SiteID '.Three_Rotations.AvgDtr.Fluxes.LE_L']), ind,year, t,0);

fig_num = fig_num + fig_num_inc;
y_axis      = [0 200];
trace_legend= char('LE 3 rotations (high freq)', 'LE WPL 3 rotations (raw)', 'LE WPL unrotated (raw)');
x = plt_msig( [LE_hf LE_rot LE_wpl],ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end


%----------------------------------------------------------
% Sonic wind direction
%----------------------------------------------------------
% trace_name  = 'Climate/Diagnostics: Wind Direction';
% trace_path  = char(fullfile(pthEC,'Instrument_2.MiscVariables.WindDirection'));
% trace_legend= char('Wind Dir');
% trace_units = '(^o)';
% y_axis      = [-10 700];
% fig_num = fig_num + fig_num_inc;
% x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
% if pause_flag == 1;pause;end

%----------------------------------------------------------
% Wind direction (RM Young)
%----------------------------------------------------------
trace_name  = 'Climate: Wind Direction';
trace_path  = char(fullfile(pthEC,'Instrument_2.MiscVariables.WindDirection'), fullfile(pthClim,'WindDir_D1_WVT'),fullfile(pthClim,'WindDir_SD1_WVT'));
trace_legend = char('Wind dir (Sonic)', 'wdir 25m (Rm Young)','wdir stdev 25m (Rm Young)');
trace_units = '(^o)';
y_axis      = [0 360];
fig_num = fig_num + fig_num_inc;
if strcmpi(SiteID,'MPB3')
    x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
else
    x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
end
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%----------------------------------------------------------
% Soil Heat Flux
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: Soil Heat flux';
if strcmpi(SiteID,'MPB1')
    if rangeYears(1)>= 2022
        trace_path  = char(fullfile(pthClim,'Sheat_flux_Avg1'),fullfile(pthClim,'Sheat_flux_Avg2')...
            ,fullfile(pthClim,'Sheat_flux_Avg3'),fullfile(pthClim,'Sheat_flux_Avg4')...
            ,fullfile(pthClim,'SoilHeatflux','SHFP_F246_Avg'),fullfile(pthClim,'SoilHeatflux','SHFP_G242_Avg')...
            ,fullfile(pthClim,'SoilHeatflux','SHFP_G243_Avg')...
            );
        trace_legend= char('sheat_{1}','sheat_{2}','sheat_{3}','sheat_{4}','SHFP_{F246}','SHFP_{G242}','SHFP_{G243}');
    else
        trace_path  = char(fullfile(pthClim,'Sheat_flux_Avg1'),fullfile(pthClim,'Sheat_flux_Avg2')...
            ,fullfile(pthClim,'Sheat_flux_Avg3'),fullfile(pthClim,'Sheat_flux_Avg4'));
        trace_legend= char('sheat_{1}','sheat_{2}','sheat_{3}','sheat_{4}');
    end
else
    trace_path  = char(fullfile(pthClim,'Sheat_flux_Avg1'),fullfile(pthClim,'Sheat_flux_Avg2'),fullfile(pthClim,'Sheat_flux_Avg3'));
    trace_legend= char('sheat_{1}','sheat_{2}','sheat_{3}');   
end
trace_units = '(W m^{-2})';
y_axis      = [-200 200];
fig_num = fig_num + fig_num_inc;
if strcmpi(SiteID,'MPB1')
   x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num,[-1 1 1 1 1 1 1]);
elseif strcmpi(SiteID,'MPB2')
   x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num,[-1 -1 1 -1]);  
else
   x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num,[1 1 1 1]); 
end
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

% -----------------------
% Energy Balance Closure
% -----------------------
try
    if strcmpi(SiteID,'MPB1')

        SHFP1 = read_sig(fullfile(pthClim,'Sheat_flux_Avg1'), ind,year, t,0);
        SHFP2 = read_sig(fullfile(pthClim,'Sheat_flux_Avg2'), ind,year, t,0);
        SHFP3 = read_sig(fullfile(pthClim,'Sheat_flux_Avg3'), ind,year, t,0);
        SHFP4 = read_sig(fullfile(pthClim,'Sheat_flux_Avg4'), ind,year, t,0);

        G     = mean([SHFP1 SHFP2 SHFP3 SHFP4 ],2);

    else 

        SHFP1 = read_sig(fullfile(pthClim,'Sheat_flux_Avg1'), ind,year, t,0);
        SHFP2 = read_sig(fullfile(pthClim,'Sheat_flux_Avg2'), ind,year, t,0);
        SHFP3 = read_sig(fullfile(pthClim,'Sheat_flux_Avg3'), ind,year, t,0);

        G     = mean([SHFP1 SHFP2 SHFP3 ],2);

    end

    Rn = Net_cnr1_calc; 

    WaterMoleFraction = Hmix./(1+Hmix./1000); 
    rho_moist_air = rho_air_wet(Tair_logger,[],BarometricP_logger,WaterMoleFraction);
    Cp_moist = spe_heat(Hmix);

    % calculate sensible heat (Tsonic) from wT_rot (see fr_calc_eddy)
    H  = wT_rot .* rho_moist_air .* Cp_moist;

    Le = LE_rot;

    fig_num = fig_num+fig_num_inc;
    trace_path = [Rn-G H+Le];
    trace_units = 'W m^{-2}';
    trace_name  = 'Eddy Correlation: Energy budget';
    trace_legend = char('Rn-G','H+LE');
    EBax = [-200 800];
    x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, EBax, t, fig_num); 
    indAxes = indAxes+1; allAxes(indAxes) = gca;
catch
    disp('...EBC plot failed');
end

try
    A = Rn-G;
    T = H+Le;
    %[C,IA,IB] = intersect(datestr(tv),datestr(t),'rows');
    %A = A(IA);
    %T = T(IB);
    cut = find(isnan(A) | isnan(T) | A > 700 | A < -200 | T >700 | T < -200 |...
        H == 0 | Le == 0 | Rn == 0 );
    A = clean(A,1,cut);
    T = clean(T,1,cut);
    %Rn_clean = clean(Rn(ind),1,cut);
    %G_clean = clean(G(ind),1,cut);
    [p, R2, sigma, s, Y_hat] = polyfit1(A,T,1);

    fig_num = fig_num+fig_num_inc;figure(fig_num);clf;
    plot(Rn-G,H+Le,'.',...
        A,T,'o',...
        EBax,EBax,...
        EBax,polyval(p,EBax),'--');
    text(-100, 400, sprintf('T = %2.3fA + %2.3f, R2 = %2.3f',p,R2));
    xlabel('Ra (W/m2)');
    ylabel('H+LE (W/m2)');
    title({'Eddy Correlation: ';'Energy budget'});
    h = gca;
    set(h,'YLim',EBax,'XLim',EBax);
    grid on;zoom on;
catch
    disp('...EBC regression plot failed');
end
%----------------------------------------------------------
% PAR
%----------------------------------------------------------
trace_name  = 'Climate/Diagnostics: PAR';
if strcmpi(SiteID,'MPB1')
% trace_path  = char(fullfile(pthClim,'Quantum_Avg'),fullfile(pthClim,'Quantum_Avg1'),fullfile(pthClim,'Quantum_Avg2'),...
%               fullfile(pthClim,'Quantum_Avg3'));
trace_path  = char(fullfile(pthClim,'Quantum_Avg1'),fullfile(pthClim,'Quantum_Avg2'),fullfile(pthClim,'Quantum_Avg3'),...
               fullfile(pthClim,'Quantum_Avg3'));
trace_legend= char('Quantum_{Avg}','Quantum_{Avg1}','Quantum_{Avg2}','Quantum_{Avg3}');
elseif strcmpi(SiteID,'MPB2')
  trace_path  = char(fullfile(pthClim,'Quantum_Avg1'),fullfile(pthClim,'Quantum_Avg2'),fullfile(pthClim,'Quantum_Avg3'));
  trace_legend= char('Quantum_{Avg1}','Quantum_{Avg2}','Quantum_{Avg3}');    
else
  trace_path  = char(fullfile(pthClim,'PAR_up_30m_Avg'),fullfile(pthClim,'PAR_down_30m_Avg'),fullfile(pthClim,'PAR_up_3m_Avg'));
  trace_legend= char('PAR_{dw 30m}','PAR_{uw 30m}','PAR_{dw 3m}');
end
trace_units = '(\mumol photons m^{-2} s^{-1})';
y_axis      = [-5 2500];
fig_num = fig_num + fig_num_inc;
% if strcmpi(SiteID,'MPB1')
x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end


%-----------------------------------
% Net radiation - net radiation is calculated in view sites and is NOT the trace from logger! (Amanda, April 2011)
%-----------------------------------
trace_name  = 'Net-Radiation Above Canopy';
%trace_path  = char(fullfile(pthClim,'CNR_net_Avg'),fullfile(pthClim,'CNR_net_Max'),fullfile(pthClim,'CNR_net_Min'));
%trace_legend = char('Net Avg','Net Max','Net Min');
trace_legend = char('Net Avg');
trace_units = '(W m^{-2})';
y_axis      = [-200 1400];
fig_num = fig_num + fig_num_inc;
x = plt_msig( Net_cnr1_calc, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
indAxes = indAxes+1; allAxes(indAxes) = gca;
if pause_flag == 1;pause;end

%-----------------------------------
% SW comparison: CNR1 and Dave's Eppley
%-----------------------------------
if strcmpi(SiteID,'MPB3')
    trace_name  = 'SW comparison: CNR1 and Dave''s Eppley';
    trace_path  = char(fullfile(pthClim,'swu_3m_Avg'),fullfile(pthClim,'swu_Avg'));
    trace_legend = char('Eppley swu 3m','CNR1 swu 30m');
    trace_units = '(W m^{-2})';
    y_axis      = [-10 150];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num,[110.1 1],[0 0]);
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end
end

%-----------------------------------
% Snow Tc
%-----------------------------------
% if SiteID=='MPB3'
%     trace_name  = 'Snow Thermocouple';
%     trace_path  = char(fullfile(pthClim,'Snow_tc_Avg'),fullfile(pthClim,'Snow_tc_Max'),fullfile(pthClim,'Snow_tc_Min'));
%     trace_legend = char('Tc Avg','Tc Max','Tc Min');
%     trace_units = '(^oC)';
%     y_axis      = [-20 20];
%     fig_num = fig_num + fig_num_inc;
%     x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num );
%     if pause_flag == 1;pause;end
% end

%-----------------------------------
% Snow Depth
%-----------------------------------
if strcmpi(SiteID,'MPB3')
    trace_name  = 'Snow Depth';
    trace_path  = char(fullfile(pthClim,'SnowDepth_Avg'),fullfile(pthClim,'SnowDepth_Max'),fullfile(pthClim,'SnowDepth_Min'));
    trace_legend = char('Snowdepth Avg','Snowdepth Max','Snowdepth Min');
    trace_units = '(m)';
    y_axis      = [0 5];
    fig_num = fig_num + fig_num_inc;
    x = plt_msig( trace_path, ind, trace_name, trace_legend, year, trace_units, y_axis, t, fig_num,[-1 -1 -1],[-3.6 -3.6 -3.6] );
    indAxes = indAxes+1; allAxes(indAxes) = gca;
    if pause_flag == 1;pause;end
end
%colordef white
if pause_flag ~= 1
    linkaxes(allAxes,'x');
    childn = get(0,'children');
    childn = sort(childn);
    N = length(childn);
    for i=1:N
        if i < 200 
            figure(i);
%            if i ~= childn(N-1)
                pause;
%            end
        end
    end
end

function set_figure_name(SiteID)
     title_string = get(get(gca,'title'),'string');
     set(gcf,'Name',[ SiteID ': ' char(title_string(2))],'numbertitle','off')   


