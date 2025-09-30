function BB_webupdate(siteNames,outputPath)

% BB_webupdate
%
% Sara Knox             File created:       Oct 21, 2019
%                       Last modification:  Sep 30, 2025

% This file is intended to create csv files to export data for web plots
% for Burns Bog (https://ibis.geog.ubc.ca/~micromet/data/burnsbog.html#)

% Revisions (latest first):
%
% Sep 30, 2025 (Zoran)
%   - Bug fix: remove signal strenghts larger than 1000 to prevent csv_save from crashing.
% Jan 9, 2023 (Zoran)
%   - replaced all 'datetime(datestr(tv))'  with much (90x) faster
%     'tv_datetime'. Saved ~9s per occurrence.
% Nov 29, 2022 (Zoran)
%   - There was a bug in the data cleaning for records csv file:
%     I commented out this line which caused the problem (erased all data):
%       data(abs(data)>=9999)=NaN;
% Sep  2, 2022 (Zoran)
%   - added fr_round_time() when dealing with the data from xlsx file for
%     DSM site. See below.
% Apr 15, 2020 (Rick)
%   - added TC_Batt_Avg to BBXTA plot
% Apr 6, 2020 (Rick)
%   - corrected var names for var2,3,4 for BB2 - BBXTA plots
% Jan 14, 2020 (Sara K.)
%   - Edited field width for some variables & added basic filtering to
%   these variables
% Nov 25, 2019 (Sara K.)
%   - Edited time range (i.e. starts Nov. 13, 2019 and ends with current date)
%   - Edited script to independantly filter data for each site
%   - Edited script to
% Nov 13, 2019 (Sara K.)
%   - Edited to create separate variables for BB2
% Nov 9, 2019 (Zoran)
%   - Debugging.
%        - Fixed the missing data handling in load_data
%          function. (all flux csv files were empty)
%        - In cutting and pasting many multiple variable csv files had their
%          variable names repeated.
% Nov 5, 2019 (Zoran)
%   - tried to make the program universal so we can use it with BB and BB2
%   - rewrote csv_save to speed up the saving
%   - removed use of year_append. Used read_bor with 'yyyy' parameter (see
%     read_bor_primar.m for details on how to load up multiple years).

arg_default('siteNames',{'BB','BB2'});
arg_default('outputPath','P:\Micromet_web\www\webdata\resources\csv\'); %outputPath = 'P:\Micromet_web\zoran_test\';

fprintf('*** Started processing at %s\n',datetime(datestr(now)))
for siteNum = 1:length(siteNames)
    siteID = char(siteNames(siteNum));
    %% Define path & csv output path, current time, and date range
    pth = biomet_path('yyyy',siteID);
    pth_BB2 = biomet_path('yyyy','BB2'); % Set path for BB2 to ismport into csv file for web plotting with BB
    
    % Current time & year
    c = clock;
    Year_now = c(1);
    
    % Define date range (i.e. years of interest)
    switch siteID
        case 'BB'
            Years = 2014:Year_now;
        case 'BB2'
            Years = 2019:Year_now;
		case 'DSM'
            Years = 2021:Year_now;
        case 'RBM'
            Years = 2022:Year_now;
        otherwise
            error('Wrong site name!')
    end
    
    % plot figures?
    plot_fig = 0; %0 for no, 1 for yes
    
    %% Load time vector
    var = 'clean_tv';
	if strcmp(siteID,'DSM')||strcmp(siteID,'RBM')
		tv=read_bor(fullfile(pth,'Flux',var),8,[],Years);
	else
		tv=read_bor(fullfile(pth,'MET',var),8,[],Years);
    end
    
    tv_datetime = datetime(tv,'convertfrom','datenum');
	
    %tv = year_append(Years,'BB','Met',var,pth,8);
    
    % Define start and end indices for web plots
    inde = find(tv_datetime == dateshift(datetime(c),'start','hour'));
    if strcmp(siteID,'BB2')
        inds = find(tv_datetime == datetime(2019,11,13));
    end
    
    formatOut = 'yyyy-mm-dd HH:MM:SS';
    tv_export = datestr(tv,formatOut);
    

    %% Air temperature (BBDTA)
    
    switch siteID  
        case 'BB'
            var1_name = 'MET_HMP_T_2m_Avg';
            var2_name = 'MET_HMP_T_30cm_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            cHeader = {'Time (PST)' 'Air Temperature (2.05m)' 'Air Temperature (0.38m)' 'BB2 Air Temperature (2.05m)'}; % Include BB2 variable here
            cFormat = '%12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'DTA.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'MET_HMP_T_2m_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'MET_HMP_T_2m_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            cHeader = {'Time (PST)' 'Air Temperature (2.05m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'DTA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
			
		case 'DSM'            
            var1_name = 'TA_1_1_1';
			var2_name = 'TA_1_2_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
			varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            
            cHeader = {'Time (PST)' 'Air Temperature (2m)' 'Air Temperature (3.5m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'DTA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'TA_1_1_1';
            var2_name = 'TA_1_2_1';
            clear varStruct  

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Air Temperature (4m)' 'Air Temperature (6m)'};
            cFormat = '%12.6f, %12.6f\n';

            fileName = [siteID 'DTA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% Relative humidity (BBRHA)
    switch siteID
        
        case 'BB'
            var1_name = 'MET_HMP_RH_2m_Avg';
            var2_name = 'MET_HMP_RH_30cm_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            cHeader = {'Time (PST)' 'Relative Humidity (2.05m)' 'Relative Humidity (0.38m)' 'BB2 Relative Humidity (2.05m)'};
            cFormat = '%12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'RHA.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'MET_HMP_RH_2m_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'MET_HMP_RH_2m_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            cHeader = {'Time (PST)' 'Relative Humidity (2.05m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'RHA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
			
		case 'DSM'
            var1_name = 'RH_1_1_1';
			var2_name = 'RH_1_2_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
			varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Relative Humidity (2m)' 'Relative Humidity (3.5m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'RHA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            
          var1_name = 'RH_1_1_1';
          var2_name = 'RH_1_2_1';
          clear varStruct 

          varStruct(1).name = var1_name;varStruct(1).type= 'Met/clean';
          varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
          cHeader = {'Time (PST)' 'Relative Humidity (4m)' 'Relative Humidity (6m)'};
          cFormat = '%12.6f, %12.6f\n';
          fileName = [siteID 'RHA.csv'];
          data = load_data(varStruct,pth,Years);
          data = data(1:inde,:);
          
          if plot_fig == 1
              plot(tv, data)
          end
          
          % Export as csv file
          csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)            
    end
    
    
    %% Radiation (BBRAD)
    switch siteID
        
        case 'BB'
            var1_name = 'MET_CNR1_SWi_Avg';
            var2_name = 'MET_CNR1_SWo_Avg';
            var3_name = 'MET_CNR1_LWi_Avg';
            var4_name = 'MET_CNR1_LWo_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'MET';
            varStruct(4).name = var4_name;varStruct(4).type = 'MET';
            cHeader = {'Time (PST)' 'Shortwave Irradiance (4.25m)' 'Shortwave Reflectance (4.25m)'...
                'Longwave Downward Radiation (4.25m)' 'Longwave Upward Radiation (4.25m)' ...
                'BB2 Shortwave Irradiance (3.00m)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'RAD.csv'];
            data = load_data(varStruct,pth,Years);
            
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'MET_CNR1_SWi_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,21,14,0,0);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'MET_CNR1_SWi_Avg';
            var2_name = 'MET_CNR1_SWo_Avg';
            var3_name = 'MET_CNR1_LWi_Avg';
            var4_name = 'MET_CNR1_LWo_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'MET';
            varStruct(4).name = var4_name;varStruct(4).type = 'MET';
            cHeader = {'Time (PST)' 'Shortwave Irradiance (3.00m)' 'Shortwave Reflectance (3.00m)'...
                'Longwave Downward Radiation (3.00m)' 'Longwave Upward Radiation (3.00m)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'RAD.csv'];
            
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            % Filter bad data
            ind_bad = datetime(datestr(tv(inds:inde,:))) <= datetime(2019,11,21,14,0,0);
            data(ind_bad,:) = NaN;
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'SW_IN_1_1_1';
            var2_name = 'SW_OUT_1_1_1';
            var3_name = 'LW_IN_1_1_1';
            var4_name = 'LW_OUT_1_1_1';
            var5_name = 'NETRAD_1_1_1';
            
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            varStruct(3).name = var3_name;varStruct(3).type = 'Met/clean';
            varStruct(4).name = var4_name;varStruct(4).type = 'Met/clean';
            varStruct(5).name = var5_name;varStruct(5).type = 'Met/clean';

            cHeader = {'Time (PST)' 'Shortwave Irradiance (3.5m)' 'Shortwave Reflectance (3.5m)'...
                'Longwave Downward Radiation (3.5m)' 'Longwave Upward Radiation (3.5m)' 'Net radiation'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'RAD.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)

        
        case 'RBM'
            var1_name = 'SW_IN_1_1_1';
            var2_name = 'SW_OUT_1_1_1';
            var3_name = 'LW_IN_1_1_1';
            var4_name = 'LW_OUT_1_1_1';
            var5_name = 'NETRAD_1_1_1';
            
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            varStruct(3).name = var3_name;varStruct(3).type = 'Met/clean';
            varStruct(4).name = var4_name;varStruct(4).type = 'Met/clean';
            varStruct(5).name = var5_name;varStruct(5).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Shortwave Irradiance (6m)' 'Shortwave Reflectance (6m)'...
                'Longwave Downward Radiation (6m)' 'Longwave Upward Radiation (6m)' 'Net radiation'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'RAD.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
       end    
    
    %% PAR (BBPAR)
    switch siteID
        
        case 'BB'
            var1_name = 'MET_PARin_Avg';
            var2_name = 'MET_PARout_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            cHeader = {'Time (PST)' 'Incoming Photosynthetic Active Radiation (1.80m)'...
                'Reflected Photosynthetic Active Radiation (4.25m)' 'BB2 Incoming Photosynthetic Active Radiation (3.00m)'};
            cFormat = '%12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'PAR.csv'];
            
            data = load_data(varStruct,pth,Years);
            
            % Filter data before June 9th
            ind_bad = tv_datetime <= datetime(2015,6,9);
            data(ind_bad,:) = NaN;
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'MET_PARin_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,21,14,0,0);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'MET_PARin_Avg';
            var2_name = 'MET_PARout_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            cHeader = {'Time (PST)' 'Incoming Photosynthetic Active Radiation (3.00m)' 'Reflected Photosynthetic Active Radiation (3.00m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'PAR.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            % Filter bad data
            ind_bad = datetime(datestr(tv(inds:inde,:))) <= datetime(2019,11,21,14,0,0);
            data(ind_bad,:) = NaN;
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'

            var1_name = 'PPFD_IN_2_1_1';   % total PAR (BF5)
            var2_name = 'PPFD_DIF_1_1_1';  % Diffuse PAR (BF5)
            var3_name = 'PPFD_IN_1_1_1';   % PAR in (PQSL-1)
            var4_name = 'PPFD_OUT_1_1_1';  % PAR out (LI-190)
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            varStruct(3).name = var3_name;varStruct(3).type = 'Met/clean';
            varStruct(4).name = var4_name;varStruct(4).type = 'Met/clean';        
            cHeader = {'Time (PST)' ...
                'BF5 Incoming Total Photosynthetic Active Radiation (3.5m)'...
                'BF5 Incoming Diffuse Photosynthetic Active Radiation (3.5m)'...
                'Incoming Photosynthetic Active Radiation (3.5m)'...
                'Reflected Photosynthetic Active Radiation (3.5m)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'PAR.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
        
            var1_name = 'PPFD_IN_2_1_1';   % total PAR (BF5)
            var2_name = 'PPFD_DIF_1_1_1';  % Diffuse PAR (BF5)
            var3_name = 'PPFD_IN_1_1_1';   % PAR in (PQSL-1)
            var4_name = 'PPFD_OUT_1_1_1';  % PAR out (LI-190)
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            varStruct(3).name = var3_name;varStruct(3).type = 'Met/clean';
            varStruct(4).name = var4_name;varStruct(4).type = 'Met/clean';        
            cHeader = {'Time (PST)' ...
                'BF5 Incoming Total Photosynthetic Active Radiation (3.5m)'...
                'BF5 Incoming Diffuse Photosynthetic Active Radiation (3.5m)'...
                'Incoming Photosynthetic Active Radiation (3.5m)'...
                'Reflected Photosynthetic Active Radiation (3.5m)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'PAR.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% Wind velocity (BBWVA)
    switch siteID
        
        case 'BB'
            var1_name = 'MET_Young_WS_WVc1'; % - ADD CR1000 data. Also, used MET_Young_WS_WVc1 instead of MET_Young_WS_Avg since that's where I did the vector averaging.
            var2_name = 'wind_speed';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux';
            cHeader = {'Time (PST)' 'Wind Velocity Cup Anemometer (5.00m)' 'Wind Velocity EC System 2 [Smartflux] (1.80m)'...
                'BB2 Wind Velocity Cup Anemometer (5.00m)' 'BB2 Wind Velocity EC System [Smartflux] (2.50m)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'WVA.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'MET_Young_WS_WVc1';
            var2_name = 'wind_speed';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad,:) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'MET_Young_WS_WVc1';
            var2_name = 'wind_speed';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux';
            cHeader = {'Time (PST)' 'Wind Velocity Cup Anemometer (5.00m)' 'Wind Velocity EC System [Smartflux] (2.50m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'WVA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'MET_Young_WS_WVc1'; % RM Young 
            var2_name = 'wind_speed';        % EC
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'Wind Velocity Cup Anemometer (3.5m)' 'Wind Velocity EC System [Smartflux] (1.8m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'WVA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
        
        case 'RBM'
            var1_name = 'MET_Young_WS_WVc1'; % RM Young 
            var2_name = 'wind_speed';        % EC
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'Wind Velocity Cup Anemometer (6m)' 'Wind Velocity EC System [Smartflux] (4m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'WVA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)

    end
    
    %% Wind direction (BBWDA)
    switch siteID
        
        case 'BB'
            var1_name = 'MET_Young_WS_WVc2'; % - ADD CR1000 data
            var2_name = 'wind_dir';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux';
            cHeader = {'Time (PST)' 'Wind Direction Cup Anemometer (5.00m)' 'Wind Direction EC System 2 [Smartflux] (1.80m)'...
                'BB2 Wind Direction Cup Anemometer (5.00m)' 'BB2 Wind Direction EC System [Smartflux] (2.50m)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'WDA.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'MET_Young_WS_WVc2';
            var2_name = 'wind_dir';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad,:) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'MET_Young_WS_WVc2';
            var2_name = 'wind_dir';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux';
            cHeader = {'Time (PST)' 'Wind Direction Cup Anemometer (5.00m)' 'Wind Direction EC System [Smartflux] (2.50m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'WDA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
        
        case 'DSM'
            var1_name = 'MET_Young_WS_WVc2';
            var2_name = 'wind_dir';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'Wind Direction Cup Anemometer (3.5m)'...
                'Wind Direction EC System [Smartflux] (1.8m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'WDA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'MET_Young_WS_WVc2';
            var2_name = 'wind_dir';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'Wind Direction Cup Anemometer (6m)'...
                'Wind Direction EC System [Smartflux] (4m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'WDA.csv'];
            data = load_data(varStruct,pth,Years);  
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)            
    end
    
    %% Turbulent Kinteric Energy (BBTKE)
    switch siteID
        
        case 'BB'
            var1_name = 'TKE';  %- ADD CR1000 data
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'TKE EC System 2 [Smartflux] (1.80m)' 'BB2 TKE EC System [Smartflux] (2.50m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'TKE.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'TKE';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'TKE';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'TKE EC System [Smartflux] (2.50m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'TKE.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case {'DSM','RBM'}
            var1_name = 'TKE';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'TKE EC System [Smartflux] (1.80m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'TKE.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
     end
    
    %% Barometric Pressure (BBPSA)
    switch siteID
        
        case 'BB'
            var1_name = 'air_pressure'; % - ADD CR1000 data
            var2_name = 'MET_Barom_Press_kPa_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            cHeader = {'Time (PST)' 'Barometric Pressure EC System 2 [Air] (1.80m)' ...
                'Barometric Pressure Barometer (1.5m)' 'BB2 Barometric Pressure Barometer (1.5m)'};
            cFormat = '%12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'PSA.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'MET_Barom_Press_kPa_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Units conversion
            data(:,1) = data(:,1)./1000;
            
            % Basic filtering
            data(data<95) = NaN;
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'air_pressure'; % - ADD CR1000 data
            var2_name = 'MET_Barom_Press_kPa_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            cHeader = {'Time (PST)' 'Barometric Pressure EC System [Air] (2.50m)' ...
                'Barometric Pressure Barometer (1.5m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'PSA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            % Unit conversion
            data(:,1) = data(:,1)./1000;
            
            % Basic filtering
            data(data<95) = NaN;
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'air_p_mean'; % EC
            var2_name = 'PA_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Barometric Pressure EC System [Air](1.8m)' ...
                'Barometric Pressure Barometer (CS106) (1.2m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'PSA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);


            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)            
                    
        case 'RBM'
            var1_name = 'air_p_mean'; % EC
            var2_name = 'PA_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Barometric Pressure EC System [Air](4m)' ...
                'Barometric Pressure Barometer (CS106) (2.5m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'PSA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);


            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% Precipitation (BBPCT)
    switch siteID
        
        case 'BB'
            var1_name = 'MET_RainTips_Tot';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            cHeader = {'Time (PST)' 'Precipitation (1.00m)' 'BB2 Precipitation (1.00m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'PCT.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Fix precip data for period of (Dec 2, 2014 - April 29, 2015)
            ind_fix = tv_datetime >= datetime(2014,12,2) & tv_datetime <= datetime(2015,04,29);
            data(ind_fix) = data(ind_fix).*0.4;
            
            % Load BB2 data
            var1_name = 'MET_RainTips_Tot';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,30);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'MET_RainTips_Tot';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            cHeader = {'Time (PST)' 'Precipitation (1.00m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'PCT.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            % Filter bad data
            ind_bad = datetime(datestr(tv(inds:inde,:))) <= datetime(2019,11,30);
            data(ind_bad,:) = NaN;
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'P_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Precipitation (1.05m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'PCT.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:); 
                        
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'P_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Precipitation (1.60m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'PCT.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:); 
                        
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% SVWC (BBSMA)
    switch siteID
        
        case 'BB'
            var1_name = 'MET_616_VolW_Avg';
            
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            cHeader = {'Time (PST)' 'Soil Volumetric Water Content' 'BB2 Soil Volumetric Water Content'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'SMA.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'MET_616_VolW_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'MET_616_VolW_Avg';
            
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            cHeader = {'Time (PST)' 'Soil Volumetric Water Content'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'SMA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
     end
    
    %% SHF (BBSHA)
    switch siteID
        
        case 'BB'
            var1_name = 'MET_SHFP_1_Avg';
            var2_name = 'MET_SHFP_2_Avg';
            var3_name = 'MET_SHFP_3_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'MET';
            cHeader = {'Time (PST)' 'Soil Heat Flux Density (uncorrected) (-0.05m) 1' ...
                'Soil Heat Flux Density (uncorrected) (-0.05m) 2' 'Soil Heat Flux Density (uncorrected) (-0.05m) 3'};
            cFormat = '%12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'SHA.csv'];
            data = load_data(varStruct,pth,Years);
            
            % Fix SHFP data for period of (Dec 2, 2014 - April 17, 2015)
            ind_fix = find(tv_datetime >= datetime(2014,12,2) & tv_datetime <= datetime(2015,04,17));
            
            %SHFP coefficients
            calib_shf1_neg = 61.142;
            calib_shf1_pos = 72.413;
            calib_shf2_neg = 61.142;
            calib_shf2_pos = 72.413;
            calib_shf3_neg = 50.2513;
            calib_shf3_pos = 49.7512;
            
            %Polynomials coefficients
            c0 = 0;
            c1 = 3.8748106364E1;
            c2 = 3.329222788E-2;
            c3 = 2.0618243404E-4;
            c4 = -2.1882256846E-6;
            c5 = 1.0996880928E-8;
            c6 = -3.0815758772E-11;
            c7 = 4.547913529E-14;
            c8 = -2.7512901673E-17;
            
            % Load panel temp
            var1_name = 'SYS_PANELT_AM25T_AVG';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            SYS_PANELT_AM25T_AVG = load_data(varStruct,pth,Years);
            SYS_PANELT_AM25T_AVG = SYS_PANELT_AM25T_AVG(ind_fix);
            
            % first revert from W m-2 to temperatures
            raw_shfp1_temp = NaN(size(ind_fix == 1));
            ind = data(ind_fix,1) > 0;
            raw_shfp1_temp(ind) = data(ind_fix(ind),1)./calib_shf1_pos;
            ind = data(ind_fix,1) < 0;
            raw_shfp1_temp(ind) = data(ind_fix(ind),1)./calib_shf1_neg;
            
            raw_shfp2_temp = NaN(size(ind_fix == 1));
            ind = data(ind_fix,2) > 0;
            raw_shfp2_temp(ind) = data(ind_fix(ind),2)./calib_shf2_pos;
            ind = data(ind_fix,2) < 0;
            raw_shfp2_temp(ind) = data(ind_fix(ind),2)./calib_shf2_neg;
            
            raw_shfp3_temp = NaN(size(ind_fix == 1));
            ind = data(ind_fix,3) > 0;
            raw_shfp3_temp(ind) = data(ind_fix(ind),3)./calib_shf3_pos;
            ind = data(ind_fix,3) < 0;
            raw_shfp3_temp(ind) = data(ind_fix(ind),3)./calib_shf3_neg;
            
            V_ref = 0.001.*(c1.*(SYS_PANELT_AM25T_AVG) + c2.*(SYS_PANELT_AM25T_AVG.^2) + c3.*(SYS_PANELT_AM25T_AVG.^3) + c4.*(SYS_PANELT_AM25T_AVG.^4) + c5.*(SYS_PANELT_AM25T_AVG.^5)+ c6.*(SYS_PANELT_AM25T_AVG.^6) + c7.*(SYS_PANELT_AM25T_AVG.^7) + c8.*(SYS_PANELT_AM25T_AVG.^8));
            V_total_1 = 0.001.*(c1.*(raw_shfp1_temp) + c2.*(raw_shfp1_temp.^2) + c3.*(raw_shfp1_temp.^3) + c4.*(raw_shfp1_temp.^4) + c5.*(raw_shfp1_temp.^5)+ c6.*(raw_shfp1_temp.^6) + c7.*(raw_shfp1_temp.^7) + c8.*(raw_shfp1_temp.^8));
            V_total_2 = 0.001.*(c1.*(raw_shfp2_temp) + c2.*(raw_shfp2_temp.^2) + c3.*(raw_shfp2_temp.^3) + c4.*(raw_shfp2_temp.^4) + c5.*(raw_shfp2_temp.^5)+ c6.*(raw_shfp2_temp.^6) + c7.*(raw_shfp2_temp.^7) + c8.*(raw_shfp2_temp.^8));
            V_total_3 = 0.001.*(c1.*(raw_shfp3_temp) + c2.*(raw_shfp3_temp.^2) + c3.*(raw_shfp3_temp.^3) + c4.*(raw_shfp3_temp.^4) + c5.*(raw_shfp3_temp.^5)+ c6.*(raw_shfp3_temp.^6) + c7.*(raw_shfp3_temp.^7) + c8.*(raw_shfp3_temp.^8));
            
            V_tc_1 = V_total_1 - V_ref;
            V_tc_2 = V_total_2 - V_ref;
            V_tc_3 = V_total_3 - V_ref;
            
            
            %calculate the true flux (mV to w m-2)
            ind = find(V_tc_1> 0);
            data(ind_fix(ind),1) = V_tc_1(ind).*calib_shf1_pos;
            ind = find(V_tc_1< 0);
            data(ind_fix(ind),1) = V_tc_1(ind).*calib_shf1_neg;
            
            ind = find(V_tc_2> 0);
            data(ind_fix(ind),2) = V_tc_2(ind).*calib_shf2_pos;
            ind = find(V_tc_2< 0);
            data(ind_fix(ind),2) = V_tc_2(ind).*calib_shf2_neg;
            
            ind = find(V_tc_3> 0);
            data(ind_fix(ind),3) = V_tc_3(ind).*calib_shf3_pos;
            ind = find(V_tc_3< 0);
            data(ind_fix(ind),3) = V_tc_3(ind).*calib_shf3_neg;
            
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'MET_SHFP_1_Avg';
            var2_name = 'MET_SHFP_2_Avg';
            var3_name = 'MET_SHFP_3_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'MET';
            cHeader = {'Time (PST)' 'Soil Heat Flux Density (uncorrected) (-0.05m) 1' ...
                'Soil Heat Flux Density (uncorrected) (-0.05m) 2' 'Soil Heat Flux Density (uncorrected) (-0.05m) 3'};
            cFormat = '%12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'SHA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            % Filter bad data
            ind_bad = datetime(datestr(tv(inds:inde,:))) <= datetime(2019,11,30);
            data(ind_bad,:) = NaN;
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'G_1_1_1';
            var2_name = 'G_2_1_1';
            var3_name = 'G_3_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            varStruct(3).name = var3_name;varStruct(3).type = 'Met/clean';    
            cHeader = {'Time (PST)' 'Soil Heat Flux Density (5cm east) 1' ...
                'Soil Heat Flux Density (5cm west) 2'...
                'Soil Heat Flux Density(5cm south) 3'};
            cFormat = '%12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'SHA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
                        
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'G_1_1_1';
            var2_name = 'G_2_1_1';
            var3_name = 'G_3_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            varStruct(3).name = var3_name;varStruct(3).type = 'Met/clean';         
            cHeader = {'Time (PST)' 'Soil Heat Flux Density (5cm east) 1' ...
                'Soil Heat Flux Density (5cm west) 2'...
                'Soil Heat Flux Density(5cm south) 3'};
            cFormat = '%12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'SHA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
                        
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% Soil temperatures (BBSTA)
    switch siteID
        
        case 'BB'
            var1_name = 'MET_SoilT_5cm_Avg';
            var2_name = 'MET_SoilT_10cm_Avg';
            var3_name = 'MET_SoilT_50cm_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'MET';
            cHeader = {'Time (PST)' 'Soil Temperature (-0.05m)' ...
                'Soil Temperature (-0.10m)' 'Soil Temperature (-0.50m)'};
            cFormat = '%14.6f, %14.6f, %14.6f\n'; % Changed from 12 to 14 to accomodate large positive/negative values
            fileName = [siteID 'STA.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            data(data>100) = NaN;
            
            % Basic filtering
            ind_bad = data(:,3) == 0;
            data(ind_bad,3) = NaN;
            
            data(data < -10^4) = NaN;
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'MET_SoilT_P1_5cm_Avg';
            var2_name = 'MET_SoilT_P1_10cm_Avg';
            var3_name = 'MET_SoilT_P1_30cm_Avg';
            var4_name = 'MET_SoilT_P1_50cm_Avg';
            var5_name = 'MET_SoilT_P2_5cm_Avg';
            var6_name = 'MET_SoilT_P2_10cm_Avg';
            var7_name = 'MET_SoilT_P2_30cm_Avg';
            var8_name = 'MET_SoilT_P2_50cm_Avg';
            var9_name = 'MET_SoilT_P3_5cm_Avg';
            var10_name = 'MET_SoilT_P3_10cm_Avg';
            var11_name = 'MET_SoilT_P3_30cm_Avg';
            var12_name = 'MET_SoilT_P3_50cm_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'MET';
            varStruct(4).name = var4_name;varStruct(4).type = 'MET';
            varStruct(5).name = var5_name;varStruct(5).type = 'MET';
            varStruct(6).name = var6_name;varStruct(6).type = 'MET';
            varStruct(7).name = var7_name;varStruct(7).type = 'MET';
            varStruct(8).name = var8_name;varStruct(8).type = 'MET';
            varStruct(9).name = var9_name;varStruct(9).type = 'MET';
            varStruct(10).name = var10_name;varStruct(10).type = 'MET';
            varStruct(11).name = var11_name;varStruct(11).type = 'MET';
            varStruct(12).name = var12_name;varStruct(12).type = 'MET';
            cHeader = {'Time (PST)' 'Soil Temperature Profile 1 (-0.05m)' ...
                'Soil Temperature Profile 1 (-0.10m)' 'Soil Temperature Profile 1 (-0.30m)' 'Soil Temperature Profile 1 (-0.50m)' ...
                'Soil Temperature Profile 2 (-0.05m)' 'Soil Temperature Profile 2 (-0.10m)' ...
                'Soil Temperature Profile 2 (-0.30m)' 'Soil Temperature Profile 2 (-0.50m)' ...
                'Soil Temperature Profile 3 (-0.05m)' 'Soil Temperature Profile 3 (-0.10m)' ...
                'Soil Temperature Profile 3 (-0.30m)' 'Soil Temperature Profile 3 (-0.50m)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'STA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            % Filter bad data
            ind_bad = datetime(datestr(tv(inds:inde,:))) <= datetime(2019,11,30);
            data(ind_bad,:) = NaN;
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'TS_1_1_1';
            var2_name = 'TS_1_2_1';
            var3_name = 'TS_1_3_1';
            var4_name = 'TS_1_4_1';            
            var5_name = 'TS_2_1_1';
            var6_name = 'TS_2_2_1';
            var7_name = 'TS_2_3_1';
            var8_name = 'TS_2_4_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            varStruct(3).name = var3_name;varStruct(3).type = 'Met/clean';
            varStruct(4).name = var4_name;varStruct(4).type = 'Met/clean';
            varStruct(5).name = var5_name;varStruct(5).type = 'Met/clean';
            varStruct(6).name = var6_name;varStruct(6).type = 'Met/clean';
            varStruct(7).name = var7_name;varStruct(7).type = 'Met/clean';
            varStruct(8).name = var8_name;varStruct(8).type = 'Met/clean';
            cHeader = {'Time (PST)'...
                'Soil Temperature Profile 1 (-0.05m)' 'Soil Temperature Profile 1 (-0.10m)' ...
                'Soil Temperature Profile 1 (-0.20m)' 'Soil Temperature Profile 1 (-0.50m)' ...
                'Soil Temperature Profile 2 (-0.05m)' 'Soil Temperature Profile 2 (-0.10m)' ...
                'Soil Temperature Profile 2 (-0.20m)' 'Soil Temperature Profile 2 (-0.50m)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'STA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'TS_1_1_1';
            var2_name = 'TS_1_2_1';
            var3_name = 'TS_1_3_1';
            var4_name = 'TS_1_4_1';            
            var5_name = 'TS_2_1_1';
            var6_name = 'TS_2_2_1';
            var7_name = 'TS_2_3_1';
            var8_name = 'TS_2_4_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            varStruct(3).name = var3_name;varStruct(3).type = 'Met/clean';
            varStruct(4).name = var4_name;varStruct(4).type = 'Met/clean';
            varStruct(5).name = var5_name;varStruct(5).type = 'Met/clean';
            varStruct(6).name = var6_name;varStruct(6).type = 'Met/clean';
            varStruct(7).name = var7_name;varStruct(7).type = 'Met/clean';
            varStruct(8).name = var8_name;varStruct(8).type = 'Met/clean';
            cHeader = {'Time (PST)'...
                'Soil Temperature Profile 1 (-0.05m)' 'Soil Temperature Profile 1 (-0.10m)' ...
                'Soil Temperature Profile 1 (-0.20m)' 'Soil Temperature Profile 1 (-0.50m)' ...
                'Soil Temperature Profile 2 (-0.05m)' 'Soil Temperature Profile 2 (-0.10m)' ...
                'Soil Temperature Profile 2 (-0.20m)' 'Soil Temperature Profile 2 (-0.50m)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'STA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% Water temperatures (BBWTA)
    switch siteID
        
        case 'BB'
            var1_name = 'MET_WaterT_10cm_Avg';
            var2_name = 'MET_WaterT_30cm_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            cHeader = {'Time (PST)' 'Water Temperature (-0.10m)' ...
                'Water Temperature (-0.30m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'WTA.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'MET_WaterT_P1_5cm_Avg';
            var2_name = 'MET_WaterT_P2_5cm_Avg';
            var3_name = 'MET_WaterT_P3_5cm_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'MET';
            cHeader = {'Time (PST)' 'Water Temperature Profile 1 (+0.05m)' ...
                'Water Temperature Profile 2 (+0.05m)' 'Water Temperature Profile 3 (+0.05m)'};
            cFormat = '%12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'WTA.csv'];
            
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            % Filter bad data
            ind_bad = datetime(datestr(tv(inds:inde,:))) <= datetime(2019,11,30);
            data(ind_bad,:) = NaN;
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'TW_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Water Temperature'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'WTA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

             if plot_fig == 1
                plot(tv, data)
             end

            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'TW_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Water Temperature'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'WTA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end

            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% Oxidation Reduction Potential (BBORP)
    switch siteID
        
        case 'BB'
            var1_name = 'MET_WaterORP_10cm_Avg';
            var2_name = 'MET_WaterORP_30cm_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            cHeader = {'Time (PST)' 'Oxidation Reduction Potential (-0.10m)' ...
                'Oxidation Reduction Potential (-0.30m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'ORP.csv'];
            
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
        case 'DSM'
            var1_name = 'ORP_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Oxidation Reduction Potential (-2m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'ORP.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'ORP_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Oxidation Reduction Potential (-2m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'ORP.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end

    %% Water table depth & bog height (BBWPT)
    switch siteID
        
        case 'BB'
            var1_name = 'MET_WaterLevel_Avg';
            var2_name = 'MET_Bog_Height_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            cHeader = {'Time (PST)' 'Water Table Height (-1.00m)' ...
                'Bog Height (1.00m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'WPT.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Basic filtering
            data(data > 500 | data < -300) = NaN;
            
            % add offset
            data(:,1) = data(:,1) - 100;
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'MET_WaterLevel_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            cHeader = {'Time (PST)' 'Water Table Height (-1.00m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'WPT.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            % add offset
            data(:,1) = data(:,1) - 113.5;
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'WTD_1_1_1';    
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            cFormat = '%12.6f\n';
            cHeader = {'Time (PST)' 'WTH (-2m)'};    
            fileName = [siteID 'WPT.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end

            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
                    
        case 'RBM'
            var1_name = 'WTD_1_1_1';    
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            cFormat = '%12.6f\n';
            cHeader = {'Time (PST)' 'WTH (-2m)'};    
            fileName = [siteID 'WPT.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end

            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% Water ph (*WpH) New device at DSM/RBM
    switch siteID

        case 'DSM'
            var1_name = 'pH_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Water pH (-2m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'WpH.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'pH_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Water pH (-2m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'WpH.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    %% Water Conductivity (*WCd) New device at DSM/RBM    
    switch siteID     

        case 'DSM'
            var1_name = 'COND_WATER_1_1_1';
            var2_name = 'Salinity';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Clean/SecondStage';
            cHeader = {'Time (PST)' 'Water conductivity (mS/cm) (-2m)' 'Salinity (ppt) (-2m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'WCd.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            data(:,1)=data(:,1)/1000; % convert cond_water_1_1_1 unit from microSeimens/cm to milliSeimens/cm
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'COND_WATER_1_1_1';
            var2_name = 'Salinity';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Clean/SecondStage';
            cHeader = {'Time (PST)' 'Water conductivity (mS/cm) (-2m)' 'Salinity (ppt) (-2m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'WCd.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            data(:,1)=data(:,1)/1000; % convert cond_water_1_1_1 unit from microSeimens/cm to milliSeimens/cm
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    %% Water Dissolved Oxygen(*WDO) New device at DSM/RBM   
    switch siteID      

        case 'DSM'
            var1_name = 'DO_1_1_1';
            var2_name = 'DOperc_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Water dissolve oxygen (-2m)' 'Water dissolve oxygen percentage (-2m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'WDO.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'DO_1_1_1';
            var2_name = 'DOperc_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Met/clean';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met/clean';
            cHeader = {'Time (PST)' 'Water dissolve oxygen (-2m)' 'Water dissolve oxygen percentage (-2m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'WDO.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)    
    end
    

    %% NDVI (*NDVI) New device at DSM/RBM       
    switch siteID    

        case 'DSM'
            var1_name = 'MET_REDin_Avg';
            var2_name = 'MET_REDout_Avg';
            var3_name = 'MET_NIRin_Avg';
            var4_name = 'MET_NIRout_Avg';
            var5_name = 'NDVI_1_1_1';            
            clear varStruct          

            varStruct(1).name = var1_name;varStruct(1).type = 'Met';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met';
            varStruct(3).name = var3_name;varStruct(3).type = 'Met';
            varStruct(4).name = var4_name;varStruct(4).type = 'Met';
            varStruct(5).name = var5_name;varStruct(5).type = 'Met/clean';            
            cHeader = {'Time (PST)'...
                'Incoming RED light (W/m^2 nm)' 'Reflected RED light (W/m^2 nm)'...
                'Incoming NIR light (W/m^2 nm)' 'Reflected NIR light (W/m^2 nm)'...
                'NDVI'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'NDVI.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'MET_REDin_Avg';
            var2_name = 'MET_REDout_Avg';
            var3_name = 'MET_NIRin_Avg';
            var4_name = 'MET_NIRout_Avg';
            var5_name = 'NDVI_1_1_1';            
            clear varStruct          

            varStruct(1).name = var1_name;varStruct(1).type = 'Met';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met';
            varStruct(3).name = var3_name;varStruct(3).type = 'Met';
            varStruct(4).name = var4_name;varStruct(4).type = 'Met';
            varStruct(5).name = var5_name;varStruct(5).type = 'Met/clean';            
            cHeader = {'Time (PST)'...
                'Incoming RED light (W/m^2 nm)' 'Reflected RED light (W/m^2 nm)'...
                'Incoming NIR light (W/m^2 nm)' 'Reflected NIR light (W/m^2 nm)'...
                'NDVI'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'NDVI.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end

    %% PRI (*PRI) New device at DSM/RBM       
    switch siteID        

        case 'DSM'
            var1_name = 'MET_532in_Avg';
            var2_name = 'MET_532out_Avg';
            var3_name = 'MET_570in_Avg';
            var4_name = 'MET_570out_Avg';
            var5_name = 'PRI_1_1_1';            
            clear varStruct         

            varStruct(1).name = var1_name;varStruct(1).type = 'Met';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met';
            varStruct(3).name = var3_name;varStruct(3).type = 'Met';
            varStruct(4).name = var4_name;varStruct(4).type = 'Met';
            varStruct(5).name = var5_name;varStruct(5).type = 'Met/clean';
            cHeader = {'Time (PST)'...
                'Incoming nm532 (W/m^2 nm)' 'Reflected nm532 (W/m^2 nm)'...
                'Incoming nm570 (W/m^2 nm)' 'Reflected nm570 (W/m^2 nm)'...
                'PRI'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'PRI.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'MET_532in_Avg';
            var2_name = 'MET_532out_Avg';
            var3_name = 'MET_570in_Avg';
            var4_name = 'MET_570out_Avg';
            var5_name = 'PRI_1_1_1';            
            clear varStruct         

            varStruct(1).name = var1_name;varStruct(1).type = 'Met';
            varStruct(2).name = var2_name;varStruct(2).type = 'Met';
            varStruct(3).name = var3_name;varStruct(3).type = 'Met';
            varStruct(4).name = var4_name;varStruct(4).type = 'Met';
            varStruct(5).name = var5_name;varStruct(5).type = 'Met/clean';
            cHeader = {'Time (PST)'...
                'Incoming nm532 (W/m^2 nm)' 'Reflected nm532 (W/m^2 nm)'...
                'Incoming nm570 (W/m^2 nm)' 'Reflected nm570 (W/m^2 nm)'...
                'PRI'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'PRI.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data) 
    end
    
    %% Sensible heat flux (BBQHB) - ADD CR1000 data
    switch siteID
        
        case 'BB'
            var1_name = 'H';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'Sensible Heat Flux (Best available) (1.80m) 2' 'BB2 Sensible Heat Flux [Smartflux] (2.50m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'QHB.csv'];
            
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'H';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'H';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'Sensible Heat Flux [Smartflux] (2.50m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'QHB.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'H';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'Sensible Heat Flux [Smartflux] (1.8m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'QHB.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'H';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'Sensible Heat Flux [Smartflux] (4m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'QHB.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% Latent heat flux (BBQEB) - ADD CR1000 data
    switch siteID
        
        case 'BB'
            var1_name = 'LE';
            
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'Latent Heat Flux (Best available) (1.80m) 2' 'BB2 Latent Heat Flux [Smartflux] (2.50m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'QEB.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'LE';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'LE';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'Latent Heat Flux [Smartflux] (2.50m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'QEB.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'LE';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'Latent Heat Flux [Smartflux] (1.8m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'QEB.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)

        case 'RBM'
            var1_name = 'LE';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'Latent Heat Flux [Smartflux] (4m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'QEB.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)            
    end
    
    %% Evapotranspiration (BBETB)
    switch siteID
        
        case 'BB'
            var1_name = 'ET'; %- ADD CR1000 data
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'Evapotranspiration EC System 2 [Smartflux] (1.80m)' 'BB2 Evapotranspiration [Smartflux] (2.50m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'ETB.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'ET';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'ET';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'Evapotranspiration [Smartflux] (2.50m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'ETB.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'ET';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'Evapotranspiration [Smartflux] (1.8m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'ETB.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
        
        case 'RBM'
            var1_name = 'ET';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'Evapotranspiration [Smartflux] (4m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'ETB.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% CO2 mixing ratio (BBC2A)
    switch siteID
        
        case 'BB'
            var1_name = 'co2_mixing_ratio'; %- ADD CR1000 data
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'CO2 Mixing Ratio EC System 2 [Smartflux] (1.80m)' 'BB2 CO2 Mixing Ratio [Smartflux] (2.50m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'C2A.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'co2_mixing_ratio';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Some basic filtering
            data(data>10000) = NaN;
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'co2_mixing_ratio'; %- ADD CR1000 data
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'CO2 Mixing Ratio [Smartflux] (2.50m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'C2A.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            % Some basic filtering
            data(abs(data)>=9999)=NaN;
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'CO2_MIXING_RATIO'; 
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'CO2 Mixing Ratio (1.8m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'C2A.csv'];
            data = load_data(varStruct,pth,Years);  
            data = data(1:inde,:);     
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
        
        case 'RBM'
            var1_name = 'CO2_MIXING_RATIO'; 
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'CO2 Mixing Ratio (4m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'C2A.csv'];
            data = load_data(varStruct,pth,Years);  
            data = data(1:inde,:);    
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% CO2 flux (BBFCA)
    switch siteID
        
        case 'BB'
            var1_name = 'co2_flux'; %- ADD CR1000 data
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'CO2 Flux Corrected EC System 2 [Smartflux] (1.80m)' 'BB2 CO2 Flux [Smartflux] (2.50m)'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'FCA.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'co2_flux';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'co2_flux'; %- ADD CR1000 data
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'CO2 Flux [Smartflux] (2.50m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'FCA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'FC'; % Corrected CO2 flux
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'CO2 Flux [Smartflux] (1.8m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'FCA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'FC'; % Corrected CO2 flux
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'CO2 Flux [Smartflux] (4m)'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'FCA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)            
    end
    
    %% Methane mixing ratios (BBC4A)
    switch siteID
        
        case 'BB'
            var1_name = 'ch4_mixing_ratio';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'CH4 Mixing Ratio EC System 2 [Smartflux] (1.80m)' 'BB2 CH4 Mixing Ratio [Smartflux] (2.50m)'}; %#ok<*NASGU>
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'C4A.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'ch4_mixing_ratio';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % basic filtering
            data(data > 10^46 | data < -10^4) = NaN;
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'ch4_mixing_ratio';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'CH4 Mixing Ratio [Smartflux] (2.50m)'}; %#ok<*NASGU>
            cFormat = '%12.6f\n';
            fileName = [siteID 'C4A.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'CH4_MIXING_RATIO';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'CH4 Mixing Ratio (1.8m)'}; 
            cFormat = '%12.6f\n';
            fileName = [siteID 'C4A.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
       
         case 'RBM'
            var1_name = 'CH4_MIXING_RATIO';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'CH4 Mixing Ratio (4m)'}; 
            cFormat = '%12.6f\n';
            fileName = [siteID 'C4A.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% Methane flux (BBFMA)
    switch siteID
        
        case 'BB'
            var1_name = 'ch4_flux';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'CH4 Flux Corrected EC System 2 [Smartflux] (1.80m)' 'BB2 CH4 Flux [Smartflux] (2.50m)'}; %#ok<*NASGU>
            cFormat = '%18.6f, %18.6f\n';
            fileName = [siteID 'FMA.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Load BB2 data
            var1_name = 'ch4_flux';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            data_BB2 = load_data(varStruct,pth_BB2,Years);
            
            % Filter bad data from BB2
            ind_bad = tv_datetime <= datetime(2019,11,13);
            data_BB2(ind_bad) = NaN;
            
            % Merge BB and BB2
            data = [data, data_BB2];
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % basic filtering
            data(data > 10^4 | data < -10^4) = NaN;
            
            data = data.*1000; % convert from umol m-2 s-1 to nmol m-2 s-1
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'ch4_flux';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            cHeader = {'Time (PST)' 'CH4 Flux [Smartflux] (2.50m)'}; %#ok<*NASGU>
            cFormat = '%18.6f\n';
            fileName = [siteID 'FMA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            data = data.*1000; % convert from umol m-2 s-1 to nmol m-2 s-1
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'FCH4';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'CH4 Flux (1.8m)'}; 
            cFormat = '%18.6f\n';
            fileName = [siteID 'FMA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
 
        case 'RBM'
            var1_name = 'FCH4';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux/clean';
            cHeader = {'Time (PST)' 'CH4 Flux (4m)'}; 
            cFormat = '%18.6f\n';
            fileName = [siteID 'FMA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)            
    end

    
    
    %% Voltage (BBBVA)
    switch siteID
        
        case 'BB'
            var1_name = 'SYS_CR1000_Batt_Volt_Avg';
            var2_name = 'SYS_PBox_Batt_Volt_Avg';
            var3_name = 'SYS_PBox_Batt_Volt2_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'MET';
            cHeader = {'Time (PST)' 'Logger Voltage' 'Battery Voltage 1' 'Battery Voltage 2'};
            cFormat = '%12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'BVA.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Basic filtering
            data(data > 50 | data < 5) = NaN;
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'SYS_CR1000_Batt_Volt_Avg';
            var2_name = 'SYS_PBox_Batt_Volt_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            cHeader = {'Time (PST)' 'Logger Voltage' 'Battery Voltage'};
            cFormat = '%12.6f,  %12.6f\n';
            fileName = [siteID 'BVA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            % Basic filtering
            data(data > 50 | data < 5) = NaN;
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'SYS_CR1000_Batt_Volt_Avg';
            var2_name = 'SYS_PBox_Batt_Volt_Avg';
            var3_name = 'SysCR1000BV_1_1_1';
            var4_name = 'SysPBoxBattVolt_1_1_1';            
            clear varStruct            

            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'Flux';
            varStruct(4).name = var4_name;varStruct(4).type = 'Flux';            
            cHeader = {'Time (PST)' 'Logger Voltage' 'Battery Voltage'...
                '[Smartflux] Logger Voltage' '[Smartflux] Battery Voltage' };
            cFormat = '%12.6f,  %12.6f,  %12.6f,  %12.6f\n';
            fileName = [siteID 'BVA.csv'];
            data = load_data(varStruct,pth,Years);
            
            % Time Shift Correction (fixed at 2021-Nov-11 09:30 am)            
            tsc=find(tv<=datenum(2021,11,11,09,30,0));            
            data(tsc(1:end-1),3:4) = data(tsc(2:end),3:4);
            
            data = data(1:inde,:);
            
            % Basic filtering
            data(data > 50 | data < 5) = NaN;
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'SYS_CR1000_Batt_Volt_Avg';
            var2_name = 'SYS_PBox_Batt_Volt_Avg';
            var3_name = 'SysCR1000BV_1_1_1';
            var4_name = 'SysPBoxBattVolt_1_1_1';            
            clear varStruct            

            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'Flux';
            varStruct(4).name = var4_name;varStruct(4).type = 'Flux';            
            cHeader = {'Time (PST)' 'Logger Voltage' 'Battery Voltage'...
                '[Smartflux] Logger Voltage' '[Smartflux] Battery Voltage' };
            cFormat = '%12.6f,  %12.6f,  %12.6f,  %12.6f\n';
            fileName = [siteID 'BVA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            % Basic filtering
            data(data > 50 | data < 5) = NaN;
            
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% Power System Current (BBBCR)
    switch siteID
        
        case 'BB'
            var1_name = 'SYS_Batt_DCCurrent_Avg';
            var2_name = 'SYS_Batt_DCCurrent2_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            data = load_data(varStruct,pth,Years);
            cHeader = {'Time (PST)' 'Battery Current 1' 'Battery Current 2'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'BCR.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1, plot(tv, data);end
            
            % Block off battery curent2 data after 2021-Nov-10
            tsc=find(tv>=datenum(2021,11,10,0,0,0));            
            data(tsc,2) = NaN;
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            data = -data;
            
            % Flip sign for battery current 1 before June 10 2015
            ind_bad = tv_datetime <= datetime(2015,6,9);
            data(ind_bad,1) = -data(ind_bad,1);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'SYS_Batt_DCCurrent_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            data = load_data(varStruct,pth,Years);
            cHeader = {'Time (PST)' 'Battery Current'};
            cFormat = '%12.6f\n';
            fileName = [siteID 'BCR.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1, plot(tv, data);end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'SYS_Batt_DCCurrent_Avg';
            var2_name = 'SysBattDCC_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux';
            data = load_data(varStruct,pth,Years);
            cHeader = {'Time (PST)' 'Battery Current' '[Smartflux] Battery Current'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'BCR.csv'];
            data = load_data(varStruct,pth,Years);
            
            % Time Shift Correction (fixed at 2021-Nov-11 09:30 am)            
            tsc=find(tv<=datenum(2021,11,11,09,30,0));            
            data(tsc(1:end-1),2) = data(tsc(2:end),2);
            
            data = data(1:inde,:);
            
            if plot_fig == 1, plot(tv, data);end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'RBM'
            var1_name = 'SYS_Batt_DCCurrent_Avg';
            var2_name = 'SysBattDCC_1_1_1';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux';
            data = load_data(varStruct,pth,Years);
            cHeader = {'Time (PST)' 'Battery Current' '[Smartflux] Battery Current'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'BCR.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1, plot(tv, data);end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% System temperatures (BBXTA)
    switch siteID
        
        case 'BB'
            var1_name = 'SYS_PanelT_CR1000_Avg';
            var2_name = 'SYS_BatteryBoxTC_Avg';
            var3_name = 'SYS_BatteryBoxTC2_Avg';
            var4_name = 'MET_CNR1_TC_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'MET';
            varStruct(4).name = var4_name;varStruct(4).type = 'MET';
            cHeader = {'Time (PST)' 'Panel Temperature' 'Battery Box Temperature 1' ...
                'Battery Box Temperature 2' 'Case Temperature (4.25m)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'XTA.csv'];
            data = load_data(varStruct,pth,Years);
            
            if plot_fig == 1, plot(tv, data);end
            
            % Block off cuurent2 data after 2021-Nov-10
            tsc=find(tv>=datenum(2021,11,10,0,0,0));            
            data(tsc,3) = NaN;
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'SYS_PanelT_CR1000_Avg';
            var2_name = 'TC_chrgr_body_Avg';
            var3_name = 'TC_chrgr_space_Avg';
            var4_name = 'TC_ref_Avg';
            var5_name = 'TC_Batt_Avg';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'MET';
            varStruct(4).name = var4_name;varStruct(4).type = 'MET';
            varStruct(5).name = var5_name;varStruct(5).type = 'MET';
            cHeader = {'Time (PST)' 'Panel Temperature' 'Battery Charger Body Temperature' ...
                'Battery Charger Space Temperature' 'AM16_32 Reference Temperature' 'Battery Temperature'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'XTA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1, plot(tv, data);end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
            
        case 'DSM'
            var1_name = 'SYS_PanelT_CR1000_Avg';
            var2_name = 'SYS_PanelT_AM25T_Avg';
            var3_name = 'SYS_chargerTC_Avg';
            var4_name = 'SYS_BatteryBoxTC_Avg';           
            var5_name = 'MET_HMP_T_350cm_Avg';
            var6_name = 'MET_CNR4_TC_Avg';            
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'MET';
            varStruct(4).name = var4_name;varStruct(4).type = 'MET';
            varStruct(5).name = var5_name;varStruct(5).type = 'MET';
            varStruct(6).name = var6_name;varStruct(6).type = 'MET';
            cHeader = {'Time (PST)' 'CR1000 Panel Temperature' 'AM25T Panel Temperature' ...
                'Charger Box Temperature' 'Battery Temperature' ...
                'Case Temperature 1 (HMP@3.5m)' 'Case Temperature 2 (CNR4@3.5m)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'XTA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            data(abs(data)>100)=NaN; % Weird data @ 2021-Sep-03            
            if plot_fig == 1, plot(tv, data);end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)

        case 'RBM'
            var1_name = 'SYS_PanelT_CR1000_Avg';
            var2_name = 'SYS_PanelT_AM25T_Avg';
            var3_name = 'SYS_chargerTC_Avg';
            var4_name = 'SYS_BatteryBoxTC_Avg';           
            var5_name = 'MET_HMP_T_6m_Avg';
            var6_name = 'MET_CNR4_TC_Avg';           
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'MET';
            varStruct(2).name = var2_name;varStruct(2).type = 'MET';
            varStruct(3).name = var3_name;varStruct(3).type = 'MET';
            varStruct(4).name = var4_name;varStruct(4).type = 'MET';
            varStruct(5).name = var5_name;varStruct(5).type = 'MET';
            varStruct(6).name = var6_name;varStruct(6).type = 'MET';
            cHeader = {'Time (PST)' 'CR1000 Panel Temperature' 'AM25T Panel Temperature' ...
                'Charger Box Temperature' 'Battery Temperature' ...
                'Case Temperature 1 (HMP@6m)' 'Case Temperature 2 (CNR4@6m)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'XTA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            data(abs(data)>100)=NaN; % Weird data @ 2021-Sep-03            
            if plot_fig == 1, plot(tv, data);end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
    
    %% Gas analyzer signal strengths (BBSSA)
    switch siteID
        
        case 'BB'
            var1_name = 'avg_signal_strength_7200_mean';
            var2_name = 'rssi_77_mean';
            var3_name = 'co2_signal_strength_7200_mean';
            var4_name = 'h2o_signal_strength_7200_mean';
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux';
            varStruct(3).name = var3_name;varStruct(3).type = 'Flux';
            varStruct(4).name = var4_name;varStruct(4).type = 'Flux';
            
            cHeader = {'Time (PST)' 'Average Signal Strength of LI-7200 (1.80m)'...
                'Average Signal Strength Li-7700 (1.80m)'...
                'CO2 Signal Strength of LI-7200 (1.80m)'...
                'H2O Signal Strength of LI-7200 (1.80m)'
                };
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'SSA.csv'];
            data = load_data(varStruct,pth,Years);
            % remove too high numbers
            data(abs(data)>=1000) = NaN;
            
            if plot_fig == 1, plot(tv, data);end
            
            % Remove empty days from end of file
            data = data(1:inde,:);
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
        case 'BB2'
            var1_name = 'avg_signal_strength_7200_mean';
            var2_name = 'rssi_77_mean';
            var3_name = 'co2_signal_strength_7200_mean';
            var4_name = 'h2o_signal_strength_7200_mean';          
            clear varStruct
            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux';
            varStruct(3).name = var3_name;varStruct(3).type = 'Flux';
            varStruct(4).name = var4_name;varStruct(4).type = 'Flux';
            cHeader = {'Time (PST)' 'Average Signal Strength of LI-7200 (1.80m)'...
                'Average Signal Strength Li-7700 (1.80m)'...
                'CO2 Signal Strength of LI-7200 (1.8m)'...
                'H2O Signal Strength of LI-7200 (1.8m)'};
            cFormat = '%14.6f, %14.6f, %14.6f, %14.6f\n';
            fileName = [siteID 'SSA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(inds:inde,:);
            
            if plot_fig == 1, plot(tv, data);end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(inds:inde,:)),cFormat,data)
        
        case 'DSM'
            var1_name = 'avg_signal_strength_7200_mean';
            var2_name = 'rssi_77_mean';
            var3_name = 'co2_signal_strength_7200_mean';
            var4_name = 'h2o_signal_strength_7200_mean';            
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux';
            varStruct(3).name = var3_name;varStruct(3).type = 'Flux';
            varStruct(4).name = var4_name;varStruct(4).type = 'Flux';            
            cHeader = {'Time (PST)' 'Average Signal Strength of LI-7200 (1.8m)'...
                'Average Signal Strength LI-7700 (1.8m)'...
                'CO2 Signal Strength of LI-7200 (1.8m)'...
                'H2O Signal Strength of LI-7200 (1.8m)'};
            cFormat = '%14.6f, %14.6f,%14.6f, %14.6f\n';
            fileName = [siteID 'SSA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            data(abs(data)>=9999)=NaN;
            
            if plot_fig == 1, plot(tv, data);end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
         case 'RBM'
            var1_name = 'avg_signal_strength_7200_mean';
            var2_name = 'rssi_77_mean';
            var3_name = 'co2_signal_strength_7200_mean';
            var4_name = 'h2o_signal_strength_7200_mean';                        
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux';
            varStruct(3).name = var3_name;varStruct(3).type = 'Flux';
            varStruct(4).name = var4_name;varStruct(4).type = 'Flux';            
            cHeader = {'Time (PST)' 'Average Signal Strength of LI-7200 (4m)'...
                'Average Signal Strength LI-7700 (4m)'...
                'CO2 Signal Strength of LI-7200 (4m)'...
                'H2O Signal Strength of LI-7200 (4m)'};
            cFormat = '%14.6f, %14.6f,%14.6f, %14.6f\n';
            fileName = [siteID 'SSA.csv'];
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            data(abs(data)>=9999)=NaN;
            
            if plot_fig == 1, plot(tv, data);end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)            
            
    end
    
    
    %% LI-7200 Flow rate and Flow Drive (*DSA.csv)
    switch siteID
        case 'BB'
            var1_name =  sprintf('%s1.flowRate.avg',siteID);
            var2_name =  sprintf('%s1.flowRate.max',siteID);
            var3_name =  sprintf('%s1.flowRate.min',siteID);
            var4_name =  sprintf('%s1.flowDrive.avg',siteID);
            var5_name =  sprintf('%s1.flowDrive.max',siteID);
            var6_name =  sprintf('%s1.flowDrive.min',siteID);
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'monitorSites';
            varStruct(2).name = var2_name;varStruct(2).type = 'monitorSites';
            varStruct(3).name = var3_name;varStruct(3).type = 'monitorSites';
            varStruct(4).name = var4_name;varStruct(4).type = 'monitorSites';
            varStruct(5).name = var5_name;varStruct(5).type = 'monitorSites';
            varStruct(6).name = var6_name;varStruct(6).type = 'monitorSites';
            cHeader = {'Time (PST)'...
                'FlowRate Avg (slpm)' 'FlowRate Max (slpm)' 'FlowRate Min (slpm)'...
                'FlowDrive Avg (%)' 'FlowDrive Max (%)' 'FlowDrive Min (%)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'DSA.csv']; % first diagnostic signal file
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            %data(:,1) = data(:,1)*60000; % unit: cubic-meters/sec -> liter/min
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)         
        case {'BB2','DSM','RBM'}
            %var1_name = 'flowrate_mean';
            var1_name =  sprintf('%s.flowRate.avg',siteID);
            var2_name =  sprintf('%s.flowRate.max',siteID);
            var3_name =  sprintf('%s.flowRate.min',siteID);
            var4_name =  sprintf('%s.flowDrive.avg',siteID);
            var5_name =  sprintf('%s.flowDrive.max',siteID);
            var6_name =  sprintf('%s.flowDrive.min',siteID);
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'monitorSites';
            varStruct(2).name = var2_name;varStruct(2).type = 'monitorSites';
            varStruct(3).name = var3_name;varStruct(3).type = 'monitorSites';
            varStruct(4).name = var4_name;varStruct(4).type = 'monitorSites';
            varStruct(5).name = var5_name;varStruct(5).type = 'monitorSites';
            varStruct(6).name = var6_name;varStruct(6).type = 'monitorSites';            
            cHeader = {'Time (PST)'...
                'FlowRate Avg (slpm)' 'FlowRate Max (slpm)' 'FlowRate Min (slpm)'...
                'FlowDrive Avg (%)' 'FlowDrive Max (%)' 'FlowDrive Min (%)'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'DSA.csv']; % first diagnostic signal file
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            %data(:,1) = data(:,1)*60000; % unit: cubic-meters/sec -> liter/min
            if plot_fig == 1
                plot(tv, data)
            end
            
            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end    
    %% File record number (*DSB.csv)  
    switch siteID
        case {'BB','BB2','DSM','RBM'}
            var1_name = 'file_records';
            var2_name = 'used_records';
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'Flux';
            varStruct(2).name = var2_name;varStruct(2).type = 'Flux';
            cHeader = {'Time (PST)' 'File records in the GHG file' 'Used records in the GHG file'};
            cFormat = '%12.6f, %12.6f\n';
            fileName = [siteID 'DSB.csv']; % second diagnostic signal file
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);
            
            if plot_fig == 1, plot(tv, data);end

            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
    end
   

    %% LI-7200 Thermocouples (*DSC.csv)
    switch siteID
        case 'BB'
            var1_name = sprintf('%s1.tempIn.avg',siteID);
            var2_name = sprintf('%s1.tempIn.max',siteID);
            var3_name = sprintf('%s1.tempIn.min',siteID);
            var4_name = sprintf('%s1.tempOut.avg',siteID);
            var5_name = sprintf('%s1.tempOut.avg',siteID);
            var6_name = sprintf('%s1.tempOut.min',siteID);
            clear varStruct            

            varStruct(1).name = var1_name;varStruct(1).type = 'monitorSites';
            varStruct(2).name = var2_name;varStruct(2).type = 'monitorSites';
            varStruct(3).name = var3_name;varStruct(3).type = 'monitorSites';
            varStruct(4).name = var4_name;varStruct(4).type = 'monitorSites';
            varStruct(5).name = var5_name;varStruct(5).type = 'monitorSites';
            varStruct(6).name = var6_name;varStruct(6).type = 'monitorSites';
            cHeader = {'Time (PST)'...
                'Intake Temp Avg' 'Intake Temp Max' 'Intake Temp Min'...
                'Outlet Temp Avg' 'Outlet Temp Max' 'Outlet Temp Min'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'DSC.csv']; % third diagnostic signal file
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1, plot(tv, data);end

            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
            
        case {'BB2','DSM','RBM'}
            var1_name = sprintf('%s.tempIn.avg',siteID);
            var2_name = sprintf('%s.tempIn.max',siteID);
            var3_name = sprintf('%s.tempIn.min',siteID);
            var4_name = sprintf('%s.tempOut.avg',siteID);
            var5_name = sprintf('%s.tempOut.avg',siteID);
            var6_name = sprintf('%s.tempOut.min',siteID);            
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'monitorSites';
            varStruct(2).name = var2_name;varStruct(2).type = 'monitorSites';
            varStruct(3).name = var3_name;varStruct(3).type = 'monitorSites';
            varStruct(4).name = var4_name;varStruct(4).type = 'monitorSites';
            varStruct(5).name = var5_name;varStruct(5).type = 'monitorSites';
            varStruct(6).name = var6_name;varStruct(6).type = 'monitorSites';
            cHeader = {'Time (PST)'...
                'Intake Temp Avg' 'Intake Temp Max' 'Intake Temp Min'...
                'Outlet Temp Avg' 'Outlet Temp Max' 'Outlet Temp Min'};
            cFormat = '%12.6f, %12.6f, %12.6f, %12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'DSC.csv']; % third diagnostic signal file
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1, plot(tv, data);end

            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
    end
    
        %% LI-7200 head sensor pressure (*DSd.csv)
    switch siteID
        case 'BB'
            var1_name = sprintf('%s1.Phead.avg',siteID);
            var2_name = sprintf('%s1.Phead.max',siteID);
            var3_name = sprintf('%s1.Phead.min',siteID);  
            clear varStruct

            varStruct(1).name = var1_name;varStruct(1).type = 'monitorSites';
            varStruct(2).name = var2_name;varStruct(2).type = 'monitorSites';
            varStruct(3).name = var3_name;varStruct(3).type = 'monitorSites';
            cHeader = {'Time (PST)' 'Head Pressure Avg'...
                'Head Pressure Max' 'Head Pressure Min'};
            cFormat = '%12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'DSD.csv']; % third diagnostic signal file
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1, plot(tv, data);end

            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
            
        case {'BB2','DSM','RBM'}
            var1_name = sprintf('%s.Phead.avg',siteID);
            var2_name = sprintf('%s.Phead.max',siteID);
            var3_name = sprintf('%s.Phead.min',siteID);            
            clear varStruct
            
            varStruct(1).name = var1_name;varStruct(1).type = 'monitorSites';
            varStruct(2).name = var2_name;varStruct(2).type = 'monitorSites';
            varStruct(3).name = var3_name;varStruct(3).type = 'monitorSites';
            cHeader = {'Time (PST)' 'Head Pressure Avg'...
                'Head Pressure Max' 'Head Pressure Min'};
            cFormat = '%12.6f, %12.6f, %12.6f\n';
            fileName = [siteID 'DSD.csv']; % third diagnostic signal file
            data = load_data(varStruct,pth,Years);
            data = data(1:inde,:);

            if plot_fig == 1, plot(tv, data);end

            % Export as csv file
            csv_save(cHeader,outputPath,fileName,cellstr(tv_export(1:inde,:)),cFormat,data)
            
    end

end % for siteNum

end % function

