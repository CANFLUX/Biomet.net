function [fitOut,fCO2,gof] = UdeM_exponential_fit(timeIn,co2_in,optionsIn,useLicorMethod, flagGasType,flagVerbose,useOriginalFit)
%
%  This function calculates dcdt for soil CO2 data. It is supposed to replicate  
%  LI-COR LI-8100A procedure (manual: year 2015). 
%  In addition to replicating LI-COR's procedure, there is an option to use
%  a modified method (Biomet method). The difference
%  between the Biomet method used here and the LI-COR one given in the manual is in the
%  calculations of t0 and co2_0.  The Biomet method does multiple exponential
%  fits, moving one point in time until it finds the best (lowest) RMSE.
%  The t0 for each iterration is assumed to be the first point of the
%  trace that for that iteration. The co2_0 is the previous 10 points
%  averaged.  If there are no 10 points to average 
%
%  For the given time and co2 signals the program fits an exponential curve
%  through the data and then calculates the dcdt at the initial point t0.  The
%  best fit is calculated repeatedly over a few (pointsToTest) points. All
%  calculated dcdt-s are returned (all pointsToTest of them) and the one
%  with the smallest error of fit is indicated (N_optimum). The full fit
%  model and the associated "goodness of the fit" (gof) for the optimal fit
%  are returned too.
%
%  The input data should be selected after the transitional chamber closure
%  period (bad period/skip points removed). The progam input data starts from the
%  moment just before chamber started closing until it started opening again 
%  (it should contain only one slope!).   
%
%  Input parameters:
%    timeIn             - time vector (Matlab time vector)
%    co2_in             - co2 concentrations (mixing ratios!) in ppm
%
%   optionsIn.
%    deadBand           - # of points to skip before grabing points for
%                         interpolation
%    timePeriodToFit    - the length of the co2 trace to consider (in seconds)
%    pointsToTest       - the range of possible delay times (t0 guesses) over which
%                         the best fit will be calculated
%    skipPoints         - points to skip from the begining of the co2_in
%
%

% Revisions:
%
% Jan 10, 2025 (Zoran)
%   - Added fitOut.cs and fitOut.A to the output (N_optimum cs and A)
% Aug 29, 2023 (Zoran)
%   - converted a chunk of code that extracts t_curvefit and co2_curvefit to 
%     a function (UdeM_findPointsToFit.m)
% Apr 21, 2023 (Zoran)
%   - found out that I've chosen bad limits for co2 (and possibly ch4) that caused
%     the exponential fits to completely miss the measured points (large RMSE).
%     co2:
%        before: [300 5000]  now: [0 3000]
%     ch4:
%        before: [1 5]  now: [0.5 10]
% Apr 20, 2023 (Zoran)
%   - added optionIn parameters: rmse_envelope_percent, functionTolerance
% Apr 19, 2023 (Zoran)
%   - added faster curve fitting (changed default fitting from "fit" 
%     to "lsqcurvefit". It's possible to revert back to "fit" by setting
%     useOriginalFit to a non-zero parameter
%   - optimized search for the best DCDT withing +rmse_envelope_percent% of the minRMSE
% Apr 14, 2023 (Zoran)
%   - reversed CO2 'StartPoint'
%      from: [ 400 -0.01]
%      to:   [ -0.01 400]
%     and CH4 'StartPoint'
%      from: [2 -0.01]
%      to:   [-0.01 2]
%     The original settings were wrong and may have slowed down calculations
%     and, occasionally, produced wrong fluxes (Sometimes it cased bad "A" estimates 
%     when dcdt was low. I don't know how often).
%
arg_default('flagGasType','co2');
arg_default('flagVerbose',false);
arg_default('useOriginalFit',false);

deadBand                = optionsIn.deadBand;
timePeriodToFit         = optionsIn.timePeriodToFit;
pointsToTest            = optionsIn.pointsToTest;
skipPoints              = optionsIn.skipPoints;
functionTolerance       = optionsIn.functionTolerance ;  % 0.01 seems to be 50% faster than 0.001
rmse_envelope_percent   = optionsIn.rmse_envelope_percent;

% Calculate the fit for 
dcdt= NaN*zeros(pointsToTest,1);
rmse_exp= NaN*zeros(pointsToTest,1);
t0= NaN*zeros(pointsToTest,1);
c0= NaN*zeros(pointsToTest,1);
N_optimum = 1;

try
    % Exponetial fit model (as per LI-COR LI-8100A theory of operation)
    co2fitType = fittype('cs+(c0-cs)*exp(A*(t-t0))','problem',{'t0','c0'},'independent','t');
    % Exponential fit options (differ by the gas choice)
    switch upper(flagGasType)
        case 'CO2'
            co2fitOptions = fitoptions('Method','NonlinearLeastSquares',...
                                    'Robust','off',...
                                    'StartPoint',[ -0.01 400],...
                                    'Lower',[-Inf 0],...
                                    'Upper',[0 3000],...
                                    'TolFun',1e-8,...
                                    'TolX',1e-8,...
                                    'MaxIter',600,...
                                    'DiffMinChange',1e-8,...
                                    'DiffMaxChange',0.1,...
                                    'MaxFunEvals',600);   %1600            
        case 'CH4'
            co2fitOptions = fitoptions('Method','NonlinearLeastSquares',...
                                    'Robust','off',...
                                    'StartPoint',[-0.01 2],...
                                    'Lower',[-Inf 0.5],...
                                    'Upper',[0 10],...
                                    'TolFun',1e-8,...
                                    'TolX',1e-8,...
                                    'MaxIter',600,...
                                    'DiffMinChange',1e-8,...
                                    'DiffMaxChange',0.1,...
                                    'MaxFunEvals',600);   %1600
    end

    % Extract time and gas concentration values to be used for curve fitting.
    [t,co2_in,t_curvefit,co2_curvefit] = UdeM_findPointsToFit(timeIn,co2_in,skipPoints,deadBand,timePeriodToFit);

% the code above replaced this chunk:
%     % Skip a predetermined # of points (avoid chamber transition/purging period)
%     timeIn =timeIn(skipPoints:end,1);
%     co2_in = co2_in(skipPoints:end,1);
% 
%     % Convert time to seconds. The first point starts at T = 0s
%     t =(timeIn - timeIn(1))*24*60*60;    % time starts at 0s
% 
%     %The x,y points to fit (t,co2) stay the same for the entire range of t0
%     % being tested. They go (in seconds) from deadBand to deadBand+timePeriodToFit.
%     % Here they are:
%     ind_curvefit = find(t>=deadBand & t< deadBand+timePeriodToFit);
%     t_curvefit = t(ind_curvefit);
%     co2_curvefit = co2_in(ind_curvefit);

    if useLicorMethod
        % This is the original Licor method where we grab 10 points starting from the
        % middle of pointToTest (assuming that t(pointsToTest/2) = t0) find C0 
        % by finding the intercept of the line fit through the 10 points and then 
        % do the exponential fit.
        indFirstPoint = round(pointsToTest/2); 
        t0 = t(indFirstPoint);
        p1 = polyfit(t(indFirstPoint+(0:9))-t(indFirstPoint),co2_in(indFirstPoint+(0:9)),1);
        c0 = p1(2);
        %-----------------
        % Fit the function
        %-----------------
        [fCO2{1},gof{1}] = fit(t_curvefit,co2_curvefit,co2fitType,co2fitOptions,'problem',{t0,c0}); %#ok<*AGROW>
        %--------------------
        % Calc dcdt and RMSE
        %--------------------
        dcdt = -fCO2{1}.A*(fCO2{1}.cs-c0);
        rmse_exp = gof{1}.rmse;               %sqrt(gof{i}.sse/length(t_curvefit));
        N_optimum = 1;
        %------------------
        % Print estimates
        %------------------
        if flagVerbose
            fprintf('Licor original: %d  dcdt: %6.4f rmse: %10.4f  r2: %6.4f\n',1,dcdt,gof.rmse,gof.rsquare)
        end

    else
        % use Biomet modified Licor method where t0 and C0 are found by doing multiple
        % exponential fits and looking for the minimal rmse
        % This method is slow but is seems to work better
        for i=pointsToTest:-1:1

            % --------------------------------------
            % Find t0, c0, and the x,y points to fit
            %---------------------------------------
            t0(i) = t(i);              % a range of t0 is being considered. This is the current one. 

            % Based on the current t0, find c0
            nn=10;
            p = polyfit(t(i:i+nn-1)-t(i),co2_in(i:i+nn-1),1);
            c0(i) = p(2);        
            %-----------------
            % Fit the function
            %-----------------
            % There are two options for doing a fit
            % One is to use Matlab Curvefitting toolbox function fit (useOriginalFit~=0)
            % It works but it has quite a bit of overhead and it's slow
            if useOriginalFit
                [fCO2{i},gof{i}] = fit(t_curvefit,co2_curvefit,co2fitType,co2fitOptions,'problem',{t0(i),c0(i)}); %#ok<*AGROW>
                %--------------------
                % Calc dcdt and RMSE
                %--------------------
                dcdt(i) = -fCO2{i}.A*(fCO2{i}.cs-c0(i));
                rmse_exp(i) = gof{i}.rmse;               %sqrt(gof{i}.sse/length(t_curvefit));
            else
                opt = optimoptions('lsqcurvefit','MaxFunctionEvaluations',1000,...
                                'FunctionTolerance',functionTolerance,...
                                'Display','off');
                fun_str = sprintf('fun=@(x,t)(x(2)+(%9.6f-x(2))*exp(x(1)*(t-%9.6f)));',c0(i),t0(i));
                eval(fun_str);
                [A_cs,resnorm,residual,exitflag,output] = lsqcurvefit(fun,co2fitOptions.StartPoint,t_curvefit,co2_curvefit,...
                                                                      co2fitOptions.Lower,co2fitOptions.Upper,opt); %#ok<ASGLU>
                if exitflag ~= 1
                    %fprintf('   lsqcurvefit exitflag = %d\n',exitflag);
                end
                A = A_cs(1);
                cs = A_cs(2);
                dcdt(i) = -A*(cs-c0(i));
                %c0(i) = polynomialCoefficients(1)*t0(i) + polynomialCoefficients(2);                                      %  c0 needs to be normalized to t0 location to match other fits
                rmse_exp(i) = rmse(co2_curvefit,fun(A_cs,t_curvefit));   
                fCO2{i}.cs = cs;
                fCO2{i}.A  = A;
            end

            %------------------
            % Print estimates
            %------------------
            if flagVerbose
                fprintf('Biomet: %d  dcdt: %6.4f rmse: %10.4f  r2: %6.4f\n',i,dcdt(i),gof{i}.rmse,gof{i}.rsquare)
            end
        end

        % find the optimum fit (min rmse)
        N_optimum = find_optimum_fit(rmse_exp,dcdt,rmse_envelope_percent);

    end
catch
    if flagVerbose
        fprintf('*** Error in UdeM_exponential_fit.m\n');
    end
    fCO2 = struct([]);
    gof = struct([]);
end

% Set fCO2 ang gof to stay compatible with other functions
if ~useOriginalFit
%     fCO2 = struct([]);
     gof = struct([]);
end

% create an output structure
fitOut.dcdtAll = dcdt;
fitOut.rmseAll = rmse_exp;
fitOut.c0All = c0;
fitOut.t0All = t0;
fitOut.N_optimum = N_optimum;
fitOut.dcdt = dcdt(N_optimum);
fitOut.rmse = rmse_exp(N_optimum);
fitOut.c0 = c0(N_optimum);
fitOut.t0 = t0(N_optimum);
if ~isempty(fCO2)
    fitOut.cs = fCO2{N_optimum}.cs;
    fitOut.A = fCO2{N_optimum}.A;
else
    fitOut.cs = NaN;
    fitOut.A = NaN;
end
%
%fprintf('\n ### Do not forget to calculate confidence intervals for dcdt! ###\n\n');
%plot(fCO2{N_optimum},t_curvefit,co2_curvefit)

function [N_optimum,maxDCDT] = find_optimum_fit(rmse_exp,dcdt,rmse_envelope_percent)
% 
% Find the index of the highest (by abs value) dcdt that still 
% has rmse within these boundaries
% minRMSE and minRMSE*(1+rmse_envelope_percent/100)
%
% 2023-04-19


  [min_RMSE] = min(rmse_exp);
  indLowRMSE = find(rmse_exp<= min_RMSE*(1+rmse_envelope_percent/100));
  [maxDCDT,ind_optimum] = max(abs(dcdt(indLowRMSE)));
  N_optimum = indLowRMSE(ind_optimum);
    
    