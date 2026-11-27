function [Corrected_WTD] = BB_WTH_Corrections_v2(SiteID,db_year,well_number,inspect)

    % Written by June Skeeter
    % - Get continuous WT data from First Stage database and correct raw
    %   measurements using manually measured data to output water table
    %   depth.
    % - This function is called from a Second Stage .ini file using an
    %   Evaluate statement.
    % - The raw continuous measurements are from a vented pressure
    %   transducer, and thus represent the height of water above the
    %   sensor.

    % Revisions:
    %
    % Nov. 2026 (Paul)
    %   - Added additional comments and diagram
    %   - BB2 WTD now estimated prior to 2023 despite no pipe height 
    %     measurements for that period. Relies on surface adjustments (mire
    %     breathing) being small at BB2 (Full_Offset calculation).
    % Apr 29, 2025 (Rosie)
    %   - Fixed bug by adding condition to exit for years prior to 2016 
    %     (for BB) where WTD and PH data does not exist

%
%                         PH   WTD_manual
%           =========      ^       ^
%           ||  |  ||      |       |
%           ||  |  ||      |       |
%           ||  |  ||      |       |
%           ||  |  ||      |       |
%           ||  |  ||      v       |     SURFACE
%—————————————————————————————————————————————————
%  WTD  ^   ||  |  ||              |
%       |   ||  |  ||              |        WT
%       |   ||  |  ||              |        __
%       v   ||  |  ||              v        \/
%- - - - - - - - - - - - - - - - - - - - - - - - -
%   ^       ||  |  ||
%   |       ||  |  ||
%   |       ||  |  ||
%   |       ||  |  ||
%   v WTH   ||  @  ||
%           =========


    current_year = year(datetime);

    arg_default('SiteID','BB');
    arg_default('db_year',current_year);
    arg_default('well_number','1');
    arg_default('inspect',0);
    
    % Trace names from FirstStage
    full_tv = [];
    % Water table height measured by the vented pressure transducer (continuous)
    WTH = [];
    WTH_name = strcat('WTH_',num2str(well_number),'_1_1');
    % Manual water table depth measured from top of well pipe
    WTD_man = [];
    WTD_name = strcat('WTD_',num2str(well_number),'_1_1');
    % Manual pipe height measured from peat surface
    PH_man = [];
    PH_name = strcat('Pipe_Height_',num2str(well_number),'_1_1');

    % Default is 2016 for now
    switch SiteID
        case 'BB'
            start_year = 2016;
            
            % For BB1: Correct the historic data prior before Oct 27, 2017
            Periods = [[datetime("2017-10-27 12:00:00","InputFormat","yy-MM-dd HH:mm:ss"),datetime("now")];
            [datetime("2017-01-20 13:00:00","InputFormat","yy-MM-dd HH:mm:ss"),datetime("2017-10-26 23:00:00","InputFormat","yy-MM-dd HH:mm:ss")];
            [datetime("2015-07-28 12:00:00","InputFormat","yy-MM-dd HH:mm:ss"),datetime("2017-01-01 00:00:00","InputFormat","yy-MM-dd HH:mm:ss")];
            ];

        case 'BB2'
            % No manual pipe height measurements prior to 2023. However,
            %   since surface adjustments (mire-breathing) at BB2 are
            %   small, we can make some simplifying assumptions to be able
            %   to calculate WTD prior to 2023.
            start_year = 2020;
            % start_year = 2023;

            Periods = [[datetime("2019-01-01 12:00:00","InputFormat","yy-MM-dd HH:mm:ss"),datetime("now")];];
        otherwise
            disp('Currently only set up for BB and BB2')
            return
    end

    % Read all data available
    for i=start_year:current_year
        [a,clean_tv] = read_db(i,SiteID,'Met/Clean',WTH_name);
        % data only begins for WTD and PH in 2016 for BB, and in 2020 for BB2, exit function with NaNs for earlier years
        if strcmp(SiteID,'BB') & db_year < start_year
            Corrected_WTD = NaN(1,length(clean_tv));
            return
        elseif strcmp(SiteID,'BB2') & db_year < start_year
            Corrected_WTD = NaN(1,length(clean_tv));
            return
        end
        if i == db_year
            db_year_clean_tv = clean_tv;
        end
        if sum(isnan(a)) ~= length(a)
            [b,clean_tv] = read_db(i,SiteID,'Met/Clean',WTD_name);
            [c,clean_tv] = read_db(i,SiteID,'Met/Clean',PH_name);
            full_tv = [full_tv;clean_tv];
            WTH = [WTH;a];
            WTD_man = [WTD_man;b];
            PH_man = [PH_man;c];
        end
    end
    DT = datetime(full_tv,"ConvertFrom","datenum"); 
    
    % Flag manual data for exclusion
    z_flag = 2;
    % Added an additional condition where WTD_man~=PH_man. The cases where
    %   the two are equal for BB2 I believe are erroneous. (P.Moore --
    %   2026-10-29)
    Obs = isfinite(WTD_man) & isfinite(PH_man) & WTD_man~=PH_man;
    X = WTD_man(Obs);
    y = PH_man(Obs);
    [ph_correction,sig_a,r,y_cl95] = linreg(X,y);
    y_err = y-(X*ph_correction(1)+ph_correction(2));
    Z = abs((y_err-mean(y_err))/std(y_err));
    Flag = false(size(Z));
    Flag(Z>z_flag)=1;
    tv_Flag = full_tv(Obs);
    [~, Drop_Flag] = intersect(full_tv,tv_Flag(Flag),"stable");
    PH_man(Drop_Flag)=NaN;
    WTD_man(Drop_Flag)=NaN;
    WTD_man_surface_correced = WTD_man-PH_man;

    
    
    % Filter continuous data (special cases for BB data)
    Periods_index = cell(length(Periods),1);
            
    for (period = 1:size(Periods,1))
        P = isbetween(DT,Periods(period,1),Periods(period,2));
        % Remove Spikes - for good data periods, filter out jump/drops, for bad periods, filter out very large local deviations then get the moving 48-hr median
        % --> This ends up filtering WT rise due to 'large' rainfall events...(P.Moore -- 2026-11-27)
        if period == 1
            WTH(P) = SpikeFilter(WTH(P),full_tv(P),1,[-.5 1],"natural");
            WTH(P) = SpikeFilter(WTH(P),full_tv(P),0,4,"z-score",14);
        else 
            % Special cases for BB
            WTH(P) = SpikeFilter(WTH(P),full_tv(P),0,4,"z-score",14);
            WTH(P) = movmedian(WTH(P),48,'includenan');
        end
    end
    
    
    % Find offset for drift correction
    % --> Under ideal conditions, WTD + WTH should be constant and
    %       represents the height of the reference point (lip of well
    %       casing) above the water level sensor. Linear interpolation
    %       makes sense if manual measurements are frequent, and manual
    %       measurement error is small relative to WT fluctuations. Obvious
    %       erroneous stepwise changes ought to be corrected separately
    %       (and prior to the procedure below).
    Offset = WTD_man + WTH;
    ix = ~isnan(Offset);
    
    switch SiteID
        case 'BB'
            Full_Offset = interp1(full_tv(ix),Offset(ix),full_tv,'linear');
        case 'BB2'
            % Surface adjustment (mire breathing) at BB2 is fairly small.
            %   There is slight seasonality which could be modelled to
            %   reduce error introduced by using linear trend.
            % The difference in method from BB1 allows for calculation of
            %   WTD prior to 2023 and relies on surface adjustments being
            %   minimal and position of the logger relative to a fixed
            %   datum being unchanged.
            p = robustfit(full_tv(Obs),WTD_man(Obs)+WTH(Obs));
            Full_Offset = p(1).*full_tv + p(2);
    end
    WTD_cont_drift_corrected = Full_Offset-WTH;

    Obs = and(isfinite(PH_man),isfinite(WTD_man));
    X = WTD_man(Obs);
    y = PH_man(Obs);
    [ph_correction,sig_a,r,y_cl95] = linreg(X,y);
    PH_cont_est = (WTD_cont_drift_corrected*ph_correction(1)+ph_correction(2));
    WTD_surface_correced_estimate = WTD_cont_drift_corrected-PH_cont_est;
    % oix = full_tv == db_year_clean_tv;
    [~,oix,~]=intersect(full_tv,db_year_clean_tv,"stable");
    % oix = [oix(end);oix(1:end-1)];
    
    Corrected_WTD = WTD_surface_correced_estimate(oix);

    if inspect == 1

        Comp = and(isfinite(WTD_surface_correced_estimate),isfinite(WTD_man_surface_correced));
        y = WTD_surface_correced_estimate(Comp);
        X = [ones(size(y)),WTD_man_surface_correced(Comp)];
        b = X\y;
        yCalc1 = X*b;
        close all
        figure
        hold on
        DT = datetime(full_tv,"ConvertFrom","datenum");
        plot(DT,WTD_surface_correced_estimate)
        scatter(DT,WTD_man_surface_correced)
        grid on
        RMSE = mean((y -yCalc1).^2).^.5;
        Rsq1 = 1 - sum((y - yCalc1).^2)/sum((y - mean(y)).^2);

        figure
        hold on
        scatter(X(:,2),y)
        grid on
        legend(sprintf('Correction line of best fit: offset %.4f, slope (WTH %.4f)\nRMSE %.4f r2 %.4f',b(1),b(2),RMSE,Rsq1))
    end
end