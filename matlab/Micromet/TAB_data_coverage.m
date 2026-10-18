function TAB_data_coverage(siteID,allYears,hfPath)
% TAB_data_coverage - show info on data cleaning and coverage
%
% Inputs
%   siteID          - site ID
%   allYears        - range of years to be analyzed
%   hfPath          - if the user has permissions to view HF (GHG) data
%                     this is the path to this folder. Most of the time 
%                     this is not used.
% 
%
%
%
% Zoran Nesic           File created        Oct 18, 2026
%                       Last modification:  Oct 18, 2026
%

% Revisions:
%
 

arg_default('hfPath','')
% If this function is used at the server, pick the hfPath info from
% the usual way:
if isempty(hfPath)
    try %#ok<TRYNC>
        structProject=get_TAB_project;
        hfPath = structProject.hfPath;
    end
end

fprintf('\n\n\n==================================\n');
fprintf('Processing: %s\n',siteID);

for yearIn = allYears
    fprintf('Year : %d\n',yearIn);    
    pathIn = biomet_path(yearIn,siteID,'Flux');
    tv = read_bor(fullfile(pathIn,'clean_tv'),8,[],yearIn);
    tv_dt = datetime(tv,'ConvertFrom','datenum');
    x = read_bor(fullfile(pathIn,'air_p_mean'),[],[],yearIn);
    % to figure out if EP recalc have been done, try to load
    % recalcTime variable first (new feature > Oct 1, 2026)
    % If there is no recalcTime use air_p_mean_1 which is generated
    % by EP API exporting twice air_p_mean and our db_ program 
    % renaming the second appearance as air_p_mean_1
    trace_name = 'recalcTime';
    dataType = 8;
    if exist(fullfile(pathIn,trace_name),"file")
        x_recalcTime = read_bor(fullfile(pathIn,trace_name),dataType,[],yearIn);
    else
        x_recalcTime =  nan(size(x));
    end
    try
        trace_name = 'air_p_mean_1';
        dataType = [];
        x1 = read_bor(fullfile(pathIn,trace_name),dataType,[],yearIn);
    catch
        x1 = nan(size(x));
        fprintf(2,'No EP calcs.\n')
    end
    x2 = read_bor(fullfile(pathIn,'GHG','Data.Seconds.avg'),[],[],yearIn);
    
    % Find how much raw HF (GHG) data there is:
    if ~isempty(hfPath)
        if any(contains(get_TAB_site_names,'BB'))
            pathHF = fullfile(hfPath,'highfreq',siteID,'raw',num2str(yearIn));
        else
            pathHF = fullfile(hfPath,siteID,'HighFrequencyData','raw',num2str(yearIn));
        end
        
        s=dir(pathHF);
        allMonths = {s(find([s(:).isdir])).name};
        % remove '.' folders
        allMonths = sort(allMonths(~startsWith(allMonths,'.'))); %#ok<*FNDSB>
        pathHF_lastMonth = fullfile(pathHF,allMonths(end));
        s2=dir(char(fullfile(pathHF_lastMonth,[num2str(yearIn) '-*.ghg'])));
        allGHGnames = sort({s2.name});
        lastFile = char(allGHGnames(end));
        lastDate = datetime(lastFile(1:15),'InputFormat','uuuu-MM-dd''T''HHmm');
        lastDate = dateshift(lastDate,'start','day') + minutes(30) * round(timeofday(lastDate)/minutes(30));
        fprintf('Last date available:           %s\n',lastDate);
    else
        fprintf(2,'Path to GHG raw files not available. No info on the last stored GHG file.\n');
        lastDate = NaN;
    end
    
    % Gather information on when the last time the 1,2,7,8 stage cleaning was done
    pathIniFiles = fullfile(db_pth_root,'Calculation_Procedures','TraceAnalysis_ini',siteID);
    path1stStage = fullfile(pathIniFiles,[siteID '_FirstStage.ini']);
    path2ndStage = fullfile(pathIniFiles,[siteID '_SecondStage.ini']);
    path3rdStage = fullfile(pathIniFiles,[siteID '_config.yml']);
    
    pathClean1 = biomet_path(yearIn,siteID,'Flux');
    lastRun_1 = dir(fullfile(pathClean1,'clean','clean_tv'));
    iniInfo_1 = dir(path1stStage);
    if lastRun_1.datenum < iniInfo_1.datenum
        flagC = 2;
    else
        flagC = 1;
    end
    fprintf(flagC,'Last first stage cleaning  on: %s (ini file date :%s)\n',lastRun_1.date,iniInfo_1.date);
    pathClean = biomet_path(yearIn,siteID,'Clean');
    lastRun_2 = dir(fullfile(pathClean,'SecondStage','TA_1_1_1'));
    iniInfo_2 = dir(path2ndStage);
    if lastRun_2.datenum < iniInfo_2.datenum
        flagC = 2;
    else
        flagC = 1;
    end    
    fprintf(flagC,'Last second stage cleaning on: %s (ini file date :%s)\n',lastRun_2.date,iniInfo_2.date);
    lastRun_3 = dir(fullfile(pathClean,'ThirdStage_Default_Ustar','USTAR_uStar_Thres'));
    iniInfo_3 = dir(path3rdStage);
    if lastRun_3.datenum < iniInfo_3.datenum
        flagC = 2;
    else
        flagC = 1;
    end     
    fprintf(flagC,'Last third stage cleaning  on: %s (ini file date :%s)\n',lastRun_3.date,iniInfo_3.date);
    if lastRun_1.datenum > lastRun_2.datenum || lastRun_2.datenum > lastRun_3.datenum
        fprintf(2,'Cleaning executed out of order!\n');
    end

    % Print recalcTime info 
    allRecalcTimes = unique(x_recalcTime(~isnan(x_recalcTime)));
    if ~isempty(allRecalcTimes)
        fprintf('The EP API calculation times for this data set:\n');
        for cntRecalc = 1:length(allRecalcTimes)
            numOfPoints = length(find(x_recalcTime==allRecalcTimes(cntRecalc)));
            fprintf('  %03d -  %s (nPoints: %d)\n',cntRecalc,datestr(allRecalcTimes(cntRecalc)),numOfPoints); %#ok<*DATST>
        end
    end
    if now-lastRun_3.datenum > 180 %#ok<TNOW1>
        fprintf(2,'More than 180 days has passed since the last full cleaning!\n');
    end
    
    % Plottting
    figure(1)
    if ~isnan(lastDate)
        plot(tv_dt,isnan(x)+0.2,'.',tv_dt,isnan(x1)+0.1,'.',tv_dt,isnan(x2),'.',tv_dt,isnan(x_recalcTime)+0.3,'.', [lastDate lastDate],[-0.5 0.5],'-');
        legend('SF','EP','GHG - averages','recalcTime','GHG - last file')
    else
        plot(tv_dt,isnan(x)+0.2,'.',tv_dt,isnan(x1)+0.1,'.',tv_dt,isnan(x2),'.',tv_dt,isnan(x_recalcTime)+0.3,'.');
        legend('SF','EP','GHG - averages','recalcTime')
    end
    title(sprintf('%s (%s) \n',siteID,char(datetime)))
    ylim([-0.1 0.5])   
    zoom on
    if ~isscalar(allYears) && yearIn ~= allYears(end)
        pause
    end
end



