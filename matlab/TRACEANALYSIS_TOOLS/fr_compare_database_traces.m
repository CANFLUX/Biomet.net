function fr_compare_database_traces(siteID,yearX,path_old,path_new,dataType,flagPlotAll,flagIgnore9999)
%  fr_compare_database_traces - compare two UBC database folder
%
% This function is used to compare two database folders containing the same
% traces. Most often it's used to compare before and after folders after
% doing data recalculations or after changes in data cleaning procedures.
% Helpful when needed to assess how many traces and by what magnitude have
% been affected.
%
% Inputs:
%  siteID   - site ID
%  yearX    - year 
%  path_old - usually data base path ('//annex001/database/')
%  path_new - usually a local path ('D:/met-data/database/')
%  data_type - subfolder for the data:
%                       ('Clean/SecondStage','Climate/Clean',...)
%  flagPlotAll - 1 [default] - plot traces as you go and wait
%                0 - keep going without waiting for user input
%  flagIgnore9999 - 0 [default] - treated as different from -9999
%                   1 - NaN treated the same as -9999 (all -9999 converted to NaNs before comparison)
%
%
%
% Example:
%   Start by cleaning MPB1 site for year 2015 and store the results locally (in d:\met-data\database\)
%     fr_automated_cleaning(2015,'MPB1', 1:3,'d:\met-data\database\')
%
%   Then compare the old and the new clean traces (first the second, then the third stage):
%     fr_compare_database_traces('MPB1',2019,'//annex001/database/',...
%                              'D:/met-data/database/','Clean/SecondStage')
%     fr_compare_database_traces('MPB1',2019,'//annex001/database/',...
%                              'D:/met-data/database/','Clean/ThirdStage')
%   Treat all -9999 as NaNs and skip the plotting
%     fr_compare_database_traces('MPB1',2019,'//annex001/database/',...
%                              'D:/met-data/database/','Clean/ThirdStage',0,1)
%      
%
%
%
% Zoran Nesic                   File created:       May 11, 2020
%                               Last modifications: Jun  3, 2024

% Revisions:
%
% Jun  3, 2024 (Zoran)
%   - Changed the UI from using uifigure to using uicontrol to enable better control of the
%     button location.
% Feb 16, 2024 (Zoran)
%   - Added printing of file counters (cntFiles,N_files) to better see what is going on.
% Feb 14, 2024 (Zoran)
%   - Added two new input options:
%       - flagPlotAll
%       - flagIgnore9999
% Aug 25, 2022 (Zoran)
%   - Increase the thicknes of the line for new data from 2 to 3
% Jul 29, 2022 (Zoran)
%   - Corrected how the differences are found. In the past, the points that were NaNs in both
%     x_new and x_old traces AND if at least one non-zero&non-NaN difference existed
%     all those points were counted as differences but not shown on the plots (because
%     of them being NaNs). That created some strange looking plots where the
%     function reported 5000+ differences but shown only 3 green circles 
%     (those 3 being the true differences).
% Jul 28, 2022 (Zoran)
%   - Introduced the back "<<" button
% Jul 27, 2022 (Zoran)
%   - Changed the plotting to GUI. 
%   - Introduced 1:1 plots
% Mar 14, 2022 (Zoran)
%   - added "Interpreter",'none' to "title"
% Jun 22, 2020 (Zoran)
%   - fixed a bug where the Nans in New didn't show up if they didn't exist
%     in the Old data.
%
arg_default('flagPlotAll',1);
arg_default('flagIgnore9999',0);

    fig = [];
    filePath_new = fullfile(path_new,...
                            sprintf('%d/%s',yearX,siteID),...
                            dataType);                      % Set path
    filePath_old = fullfile(path_old,...
                            sprintf('%d/%s',yearX,siteID),...
                            dataType);                      % Set path
    s_all_old_files = dir(filePath_old);                    % find all files in the old folder
    if isempty(s_all_old_files) 
        error ('0 files found in %s. Program stopped.',filePath_old);
    elseif isempty(dir(filePath_new))
        error ('0 files found in %s. Program stopped.',filePath_new);
    end

    % Create time vector (do not assume that it exists, assume 30min data)
    tv = fr_round_time(datenum(yearX,1,1,0,30,0):1/48:datenum(yearX+1,1,1)); 
    tv_dt = datetime(tv,'convertfrom','datenum');

    % Cycle through all files found in the OLD folder and compater with the
    % files with same names in the NEW folder
    allOK = true;
    N = 0;
    badN = 0;
    cntFiles=1;
    oldCnt = 0;
    badFileList = [];
    N_files = length(s_all_old_files);
    while cntFiles < N_files
        flagDiffFound = 0;
        currentFile = fullfile(filePath_new,s_all_old_files(cntFiles).name);
        if ~exist(currentFile,'dir')
            try
                N = N+1;
                x_new = [];
                x_new = read_bor(currentFile);
                currentFile_old = fullfile(filePath_old,s_all_old_files(cntFiles).name);
                x_old = [];
                x_old = read_bor(currentFile_old);
                if flagIgnore9999 == 1
                    % if asked to ignore -9999 convert all of them to NaNs
                    x_new(x_new==-9999) = NaN;
                    x_old(x_old==-9999) = NaN;
                end
                nansInNew = isnan(x_new);
                nansInOld = isnan(x_old);
                indSameNans = nansInNew & nansInOld;
                indDiff = find((x_new - x_old ~= 0) & ~indSameNans);
                % Test differences for:
                %   - Nans that exist in one trace but not another
                %   - Non-nan values that are not the same
                diffNans = xor(nansInNew,nansInOld);
                diffButNotNanPoints = x_old(~indSameNans)-x_new(~indSameNans);
                if any(diffNans) ...
                       | ~all(diffButNotNanPoints==0 )   %#ok<*OR2,*AND2>
                    %---------------------
                    % Differences found!
                    %---------------------
                    allOK = false;
                    badN = badN+1;
                    flagDiffFound = 1;
                    badFileList(badN) = cntFiles; %#ok<*AGROW>
                    if isempty(fig)
                        sSize = get(0,'ScreenSize');
                        fig = figure('Position',[50 round(sSize(4)/2.5) sSize(3)-100 round(sSize(4)/2.5)]);
                        UserData.cnt = 0;
                        UserData.next=0;
                        set(fig,'UserData',UserData);
                        ah = axes(fig); 
                        hExitButton = uicontrol(fig,'style','pushbutton',...
                            'String','Exit',...
                            'Position',[20, 60, 80, 30],...
                            'Callback', @(hExitButton,event)  exitButtonPushed(hExitButton,fig)); 
                        hNextButton = uicontrol(fig,'style','pushbutton',...
                            'String','>>',...
                            'Position',[60, 164, 40, 30],...
                            'Callback', @(hNextButton,event) nextButtonPushed(hNextButton,fig)); 
                        hPreviousButton = uicontrol(fig,'style','pushbutton',...
                            'String','<<',...
                            'Position',[20, 164,40, 30],...
                            'Callback', @(hPreviousButton,event) previousButtonPushed(hPreviousButton,fig)); 
                        
                        
                        hDropDown = uicontrol(fig,...
                            'Style','popupmenu',...
                            'Position',[20 122 100 40],...
                            'String',{'Time plot','1:1 plot'},...
                            'Callback',@(hDropDown,event) optionSelected(hDropDown,fig));   
                        % 
                        % fig = uifigure;
                        % UserData.cnt = 0;
                        % UserData.next=0;
                        % set(fig,'UserData',UserData);
                        % ah = axes(fig); %#ok<LAXES>
                        % hExitButton = uibutton(fig,'push',...
                        %     'Text','Exit',...
                        %     'Position',[20, 60, 100, 40],...
                        %     'ButtonPushedFcn', @(hExitButton,event) exitButtonPushed(hExitButton,fig)); %#ok<NASGU>
                        % hDropDown = uidropdown(fig,...
                        %     'Editable','on',...
                        %     'Position',[20 122 100 40],...
                        %     'Items',{'Time plot','1:1 plot'},...
                        %     'ItemsData',[1 2],...
                        %     'Value',1,'ValueChangedFcn',@(hDropDown,event) optionSelected(hDropDown,fig));               
                        % hNextButton = uibutton(fig,'push',...
                        %     'Text','>>',...
                        %     'Position',[70, 184, 50, 40],...
                        %     'ButtonPushedFcn', @(hNextButton,event) nextButtonPushed(hNextButton,fig)); %#ok<NASGU>
                        % hPreviousButton = uibutton(fig,'push',...
                        %     'Text','<<',...
                        %     'Position',[20, 184,50, 40],...
                        %     'ButtonPushedFcn', @(hPreviousButton,event) previousButtonPushed(hPreviousButton,fig)); %#ok<NASGU>
                    else
                        % every time drop down is used the UserData.cnt goes to -1
                        % which in turn causes the same plot to be replotted
                        % but with different view (Time Plot or 1:1)
                        % default is to advance to the next plot(cnt = 0)
                        UserData.cnt = 0;
                        UserData.next=0;
                        set(fig,'UserData',UserData);
                    end

                    if hDropDown.Value == 1
                        %plot(doy,[x_new x_old])
                        plot(ah,tv_dt,x_new,'linewidth',5,'color','#0072BD')

                        hold(ah,'on')
                        plot(ah,tv_dt,x_old,'linewidth',3,'color','#D95319')
                        plot(ah,tv_dt(indDiff),x_new(indDiff),'og','MarkerSize',8,'linewidth',3)
                        % The above will not plot NaNs in x_new. So plot 'x' at 0 for
                        % those
                        x_new_isnan = find(isnan(x_new(indDiff))& ~isnan(x_old(indDiff)));
                        plot(ah,tv_dt(indDiff(x_new_isnan)),zeros(size(indDiff(x_new_isnan))),'x','MarkerSize',9,'linewidth',4,'color','#6B4C9A')                        
                        grid(ah,'on')
                        zoom(ah,'on')
                        title(ah,sprintf('Year: %d       Trace: %s;      # of diff: %d ',...
                               yearX, s_all_old_files(cntFiles).name,length(indDiff)),...
                               'Interpreter','None')                             
                        if ~isempty(x_new_isnan)
                            legend(ah,{['NEW data=>' path_new],['OLD data=>' path_old],'Different new points','NaNs only in NEW'},'Interpreter','none');
                        else
                            legend(ah,{['NEW data=>' path_new],['OLD data=>' path_old],'Different new points'},'Interpreter','none');
                        end 
                        hold(ah,'off')
                    else
                        [old_filtered,new_filtered, p1_org,p2_org, slopeCoeff]= ...
                            ta_clean_1to1_trace(x_old,x_new,2); %#ok<*ASGLU>
                        plot(ah,x_old,x_new,'o',old_filtered,new_filtered,'o')
                        newMin = min(new_filtered);
                        if isnan(newMin)
                            newMin = min(old_filtered);
                        end
                        newMax = max(new_filtered);
                        if isnan(newMax)
                            newMax = max(old_filtered);
                        end
                        if ~isnan(newMin) && ~isnan(newMax)
                            axis(ah,[newMin newMax newMin newMax])                        
                        end
                        xlabel(ah,'Old')
                        ylabel(ah,sprintf('New = %6.2f * Old + %6.2f\n',p2_org(1),p2_org(2)))
                        grid(ah,'on')
                        zoom(ah,'on')
                        legend(ah,{'Removed outliers','"Good" data'});
                        title(ah,sprintf('Year: %d       Trace: %s;      # of diff: %d ',...
                               yearX, s_all_old_files(cntFiles).name,length(indDiff)),...
                               'Interpreter','None')                        
                    end
                    % print only once 
                    if  oldCnt ~= cntFiles
                        fprintf('%6d differences exist in the file (%d/%d): %s \n',length(indDiff),cntFiles,N_files, s_all_old_files(cntFiles).name);
                        oldCnt = cntFiles;
                    end                  
                    while UserData.next==0 && flagPlotAll==1
                        % loop here until user request re-plot by changing the
                        % plot type or by clicking on the "Next" button 
                        UserData = get(fig,'UserData');
                        drawnow
                    end
                    % if the button that was pressed was "Exit"                    
                    if UserData.next==2
                        fprintf('User stopped program. Exiting...\n');
                        close(fig)
                        return
                    end                                    
                end
            catch
                if isempty(x_new)
                    fprintf('File does not exist: (%d/%d) %s.!\n',cntFiles,N_files,currentFile);
                elseif isempty(x_old)
                    fprintf('File does not exist: (%d/%d) %s.!\n',cntFiles,N_files,currentFile_old);
                else
                    fprintf('Error while processing file: (%d/%d) %s.!\n',cntFiles,N_files,currentFile);
                end
            end
        end
        if flagDiffFound > 0 && flagPlotAll==1
            % if differences were found check if user 
            % requsted a change in plotting
            UserData = get(fig,'UserData');
            switch UserData.cnt
                case 0
                    % do nothing
                case -1
                    % will repeat the same plot. Compensate
                    cntFiles = cntFiles - 1;
                    badFileList(badN) = [];                    
                    badN = badN -1;
                case -2
                    % have to go back to the last set of different traces                    
                    if badN <= 1
                        cntFiles = badFileList(1)-1;
                        if cntFiles < 0
                            cntFiles = 0;
                        end
                        badN = 0;                        
                        badFileList = [];
                    else
                        badFileList(badN) = [];
                        badN = badN - 1;
                        cntFiles = badFileList(badN)-1;
                        badFileList(badN) = [];
                        badN = badN - 1;
                    end                                       
            end

            % set
        end
        cntFiles = cntFiles + 1;
    end
    if allOK
        fprintf('%d files checked and there are no differences\n',N);
    else
        fprintf('%d files checked and there are %d files with differences\n',N,badN);
    end
    if ~isempty(fig)
        close(fig);
    end
end

% Ymax limit changed
function hMaxChanged(hYmax,fig)
    oldLim = ylim;
    ylim([oldLim(1) hYmax.value])
end


% Create ValueChangedFcn callback
function optionSelected(hDropDown,fig)
    val = hDropDown.Value; %#ok<NASGU>
    UserData = get(fig,'UserData');
    % if only the type of plot changed
    % return the file counter back by one so the program
    % plots the same plot again (cnt=-1)
    UserData.cnt = -1;
    UserData.next = 1;
    set(fig,'UserData',UserData)
end

% Create the function for the ButtonPushedFcn callback
function nextButtonPushed(btn,fig) %#ok<INUSL>
    UserData = get(fig,'UserData');
    UserData.next = 1;
    UserData.cnt = 0;
    set(fig,'UserData',UserData);
end

% Create the function for the ButtonPushedFcn callback
function previousButtonPushed(btn,fig) %#ok<INUSL>
    UserData = get(fig,'UserData');
    UserData.next = 1;
    UserData.cnt = -2;
    set(fig,'UserData',UserData);
end

% Create the function for the ExitButtonPushedFcn callback
function exitButtonPushed(btn,fig) %#ok<INUSL>
    UserData = get(fig,'UserData');
    UserData.next = 2;
    set(fig,'UserData',UserData);
end