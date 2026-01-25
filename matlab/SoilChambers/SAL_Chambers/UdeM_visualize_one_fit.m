function UdeM_visualize_one_fit(dataOut,chNum,slopeNum,fitType,gasType,figNumIn,flagVerbose,refFitType) %#ok<*INUSL>
    arg_default('fitType','exp_L')
    arg_default('refFitType','lin_C')
    arg_default('flagVerbose',false);
    arg_default('figNumIn',99)
    
    % Compatibility with the old saved data that does not have the "analyzer" field. 
    % Assume LGR because only UdeM calcs before 2025 don't have that in the ini file.
    if ~isfield(dataOut.configIn,'analyzer')
        dataOut.configIn.analyzer = 'LGR';
    end
    % save default font sizes
    originalAxesFontSize = get(0,'defaultAxesFontSize');
    originalTextFontSize = get(0,'defaultTextFontSize');
    % set figures own font sizes
    axesFontSize = 8;
    textFontSize = 8;
    set(0,'defaultAxesFontSize',axesFontSize);
    set(0,'defaultTextFontSize',textFontSize);
    
    switch lower(gasType)
        case 'co2'
            gasName = findRawTraceName(dataOut.configIn,chNum,'co2_dry');
            unitGain = 1;
            strYlabel  = 'CO_2 (ppm s^{-1})';
            strYlabel1 = 'CO_2 (ppm)';
        case 'ch4'
            gasName = findRawTraceName(dataOut.configIn,chNum,'ch4_dry');   
            unitGain = 1000;
            strYlabel  = 'CH_4 (ppb s^{-1})';  % dcdt is shown in different units!
            strYlabel1 = 'CH_4 (ppm)';
        case 'n2o'
            gasName = findRawTraceName(dataOut.configIn,chNum,'n2o_dry');
            unitGain = 1;
            strYlabel  = 'N_2O (ppm s^{-1})';
            strYlabel1 = 'N_2O (ppm)';            
    end    
    try
        fitOut  = dataOut.chamber(chNum).sample(slopeNum).flux.(gasType).(fitType).fitOut;
        gof     = dataOut.chamber(chNum).sample(slopeNum).flux.(gasType).(fitType).gof;
        fCO2    = dataOut.chamber(chNum).sample(slopeNum).flux.(gasType).(fitType).fCO2;
        switch fitType
            case {'exp_L','exp_B'}
                optionsIn.skipPoints        = dataOut.configIn.chamber(chNum).(gasType).fit_exp.skipPoints;            
                optionsIn.deadBand          = dataOut.configIn.chamber(chNum).(gasType).fit_exp.deadBand;                      
                optionsIn.pointsToTest      = dataOut.configIn.chamber(chNum).(gasType).fit_exp.pointsToTest;         
                optionsIn.timePeriodToFit   = dataOut.configIn.chamber(chNum).(gasType).fit_exp.timePeriodToFit;
            case 'lin_B'
                optionsIn.skipPoints        = dataOut.configIn.chamber(chNum).(gasType).fit_lin.skipPoints;            
                optionsIn.deadBand          = dataOut.configIn.chamber(chNum).(gasType).fit_lin.deadBand;                      
                optionsIn.pointsToTest      = dataOut.configIn.chamber(chNum).(gasType).fit_lin.pointsToTest;         
                optionsIn.timePeriodToFit   = dataOut.configIn.chamber(chNum).(gasType).fit_lin.timePeriodToFit;
            case 'quad_B'
                optionsIn.skipPoints        = dataOut.configIn.chamber(chNum).(gasType).fit_quad.skipPoints;            
                optionsIn.deadBand          = dataOut.configIn.chamber(chNum).(gasType).fit_quad.deadBand;                      
                optionsIn.pointsToTest      = dataOut.configIn.chamber(chNum).(gasType).fit_quad.pointsToTest;         
                optionsIn.timePeriodToFit   = dataOut.configIn.chamber(chNum).(gasType).fit_quad.timePeriodToFit;
        end        

        tv = dataOut.rawData.analyzer.(dataOut.configIn.analyzer).tv;
        ch_time_hours_analyzer = (tv-tv(1))*24;
        indX = dataOut.indexes.analyzer.(dataOut.configIn.analyzer)(chNum).start';
        indY = dataOut.indexes.analyzer.(dataOut.configIn.analyzer)(chNum).end';
        t_oneSlope_hours = ch_time_hours_analyzer(indX(slopeNum):indY(slopeNum));
        c_oneSlope = dataOut.rawData.analyzer.(dataOut.configIn.analyzer).(gasName)(indX(slopeNum):indY(slopeNum));

        dcdt = fitOut.dcdt; %#ok<*SAGROW>
        rmse_exp = fitOut.rmse;
        c0 = fitOut.c0;
        t0 = fitOut.t0;
        N_optimum = fitOut.N_optimum;
        t0All = fitOut.t0All;
        c0All = fitOut.c0All;
        dcdtAll = fitOut.dcdtAll;
        rmseAll = fitOut.rmseAll;       
        
        [t_oneSlope_sec,c_oneSlope,t_curvefit,gas_curvefit] = ...
                          UdeM_findPointsToFit(t_oneSlope_hours/24,c_oneSlope,...
                                         optionsIn.skipPoints,optionsIn.deadBand,optionsIn.timePeriodToFit);

        switch fitType
            case {'exp_L','exp_B'}
                cs = fCO2{N_optimum}.cs;
                A = fCO2{N_optimum}.A;
                c_fit = cs+(c0-cs)*exp(A*(t_oneSlope_sec-t0));
            case 'lin_B'
                c_fit = c0 + dcdt * (t_oneSlope_sec-t0);
            case 'quad_B'
                coeffAll = fitOut.coeffAll;
                c_fit = polyval(coeffAll(N_optimum,:),t_oneSlope_sec);
        end
        
        switch refFitType
            case 'lin_C'
                % Calculate the "classic" linear fit, to be plotted alongside of the fitType for comparison
                % Use the already calculated dcdt,t0... from lin_B and assume that the
                % "classic" fit would just pick the middle of the search window (usually 10th of 20
                % estimates, see ind_middle calculation below)
                fitOut_C  = dataOut.chamber(chNum).sample(slopeNum).flux.(gasType).lin_B.fitOut;
                fCO2_C    = dataOut.chamber(chNum).sample(slopeNum).flux.(gasType).lin_B.fCO2;
                ind_middle = round(length(fCO2_C)/2);
                c0_c = fitOut_C.c0All(ind_middle);
                dcdt_c = fitOut_C.dcdtAll(ind_middle);
                t0_c = fitOut_C.t0All(ind_middle);
                c_fit_c = c0_c + dcdt_c * (t_oneSlope_sec-t0_c);
            otherwise
                % use any of the other results as a reference
                % and pick the N_optimum fit
                fitOut_C  = dataOut.chamber(chNum).sample(slopeNum).flux.(gasType).(refFitType).fitOut;
                fCO2_C    = dataOut.chamber(chNum).sample(slopeNum).flux.(gasType).(refFitType).fCO2;
                N_optimum_C = fitOut_C.N_optimum;                
                c0_c = fitOut_C.c0All(N_optimum_C);
                dcdt_c = fitOut_C.dcdtAll(N_optimum_C);
                t0_c = fitOut_C.t0All(N_optimum_C);
                c_fit_c = c0_c + dcdt_c * (t_oneSlope_sec-t0_c);                
        end

        if flagVerbose
            fprintf('ch: %d  h: %d  rmse: %6.4f  dcdt: %6.4f   c0: %6.2f  t0: %6.2f\n\n',...
                     chNum,slopeNum,rmse_exp*unitGain,dcdt*unitGain,c0,t0)
        end

        % ==================================================
        % Select the current figure and plot 
        % ==================================================
        figNum = figNumIn;
        figure(figNum);
        set(figNum,'Name',sprintf('%s  Chamber %d, hour = %d        %s',...
             upper(gasType),chNum,slopeNum,datestr(floor(tv(1)))),...
             'numbertitle','off','menubar','none');
        clf
        % ==================================================
        % First subplot contains the data fits plots 
        % ==================================================
        % plot data and the fit
        subplot(1,2,1)
        legend_handle_data = plot(t_oneSlope_sec,c_oneSlope,'.','MarkerSize',10);
        hold on
        legend_handle_selected_points = plot(t_curvefit,gas_curvefit,'o','MarkerSize',6);
        legend_handle_fit = plot(t_oneSlope_sec,c_fit,'LineWidth',2);
        
        hold off
        xlabel('t (sec)')
        ylabel(strYlabel1)
        title(sprintf('%s       Chamber %d, hour = %d',datestr(floor(tv(1))),chNum,slopeNum))
        % Shade skipped region and deadband region
        ax=axis;
        xlim(ax(1:2));
        ylim(ax(3:4));
        if ax(4) > 1000 & strcmpi(gasType,'co2') %#ok<*AND2>
            axis([ax(1:2) min(c_oneSlope) max(c_oneSlope)])
        elseif ax(4) > 5 & strcmpi(gasType,'ch4')
            axis([ax(1:2) min(c_oneSlope) max(c_oneSlope)])        
        end
        ax = axis;
        v = [0 ax(3);
            0 ax(4);
            optionsIn.deadBand ax(4);
            optionsIn.deadBand ax(3)];
        f=[1 2 3 4];
        legend_handle_patch_deadband=patch('Vertices',v,'faces',f,'facecolor','g','edgecolor','none','facealpha',0.2); %#ok<*NASGU>

        v2 = [ax(1) ax(3);ax(1) ax(4);0 ax(4);0 ax(3)];
        f2=[1 2 3 4];
        legend_handle_patch_skipped=patch('Vertices',v2,'faces',f2,'facecolor','y','edgecolor','none','facealpha',0.3);

        v3 = [0                         max(ax(3),c0-10);
              0                         min(ax(4),c0+10);
              optionsIn.pointsToTest    min(ax(4),c0+10);
              optionsIn.pointsToTest    max(ax(3),c0-10)];
        f3=[1 2 3 4];
        legend_handle_search = patch('Vertices',v3,'faces',f3,'facecolor','none','edgecolor','#0072BD','facealpha',0.7,'linewidth',1);
        
        % Add start (+) marker
        legend_handle_t0 =line(t0,c0,'marker','+','markersize',10,'color',...
                              '#D95319','markerfacecolor','#D95319',...
                              'linestyle','none','linewidth',2);              
        legend_handle_fit_dcdt = line([t0 max(t_oneSlope_sec)],...
                                      [c0 dcdt*(max(t_oneSlope_sec)-t0)+c0] ,...
                                      'linewidth',2,'color','g');

        % -------------------------------------------
        % Use previously calculated line fit parameters
        % for comparison (use "classic" linear fit, using lin_B{mid_point}).
        % -------------------------------------------
        legend_handle_clasic_line_dcdt = line(t_oneSlope_sec,c_fit_c,'linewidth',2,'color','k');
        zoom on
        all_legend_handles = [ ...
            legend_handle_data ...
            legend_handle_fit...
            legend_handle_selected_points...
            legend_handle_patch_deadband ...
            legend_handle_patch_skipped ...
            legend_handle_search ...
            legend_handle_t0 ...
            legend_handle_fit_dcdt ...
            legend_handle_clasic_line_dcdt ...
            ];
        legend(all_legend_handles,...
            'Data','fit','Select','deadband','skipped','t0 search','t0',...
            sprintf('dcdt_{%s}',fitType),...
            sprintf('dcdt_{%s}',refFitType),...
            'location','northeast')
        
        dy = ax(4)-ax(3);
        dx = ax(2)-ax(1);
        text(ax(1)+dx*0.4,ax(3)+19*dy/20,sprintf('dcdt_{%s} = %6.4f %s',fitType,dcdt*unitGain,strYlabel))
        text(ax(1)+dx*0.4,ax(3)+18*dy/20,sprintf('dcdt_{%s}  = %6.4f %s',refFitType,dcdt_c*unitGain,strYlabel))

        subplot(1,2,2)

        yyaxis left
        plot(fitOut.t0All,fitOut.rmseAll,'-',fitOut.t0All(N_optimum),fitOut.rmseAll(N_optimum),'o'  )
        %axis square
        xlabel('t_0')
        ylabel('rmse')
        yyaxis right
        plot(fitOut.t0All,fitOut.dcdtAll,'-',fitOut.t0All(N_optimum),fitOut.dcdtAll(N_optimum),'o'  )
        ylabel('dcdt')
        zoom on

    catch
        fprintf('Error in UdeM_visualize_one_fit.m. chNum = %d, slopeNum = %d, fitType = %s, gastType = %s\n',chNum,slopeNum,fitType,gasType);
    end

    % return default font sizes
    set(0,'defaultAxesFontSize',originalAxesFontSize);
    set(0,'defaultTextFontSize',originalTextFontSize);