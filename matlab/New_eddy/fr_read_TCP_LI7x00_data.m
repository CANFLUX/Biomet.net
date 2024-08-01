function [dataOut, cError,allData] = fr_read_TCP_LI7x00_data(addressIP,portNum,timeOut)
%  [dataOut, cError,allData] = fr_read_TCP_LI7x00_data(addressIP,portNum,timeOut)
%
% This function contacts LI7x00 instruments in a real time and downloads one
% data sample. If data is missing, the function returns a structure dataOut
% with all its fields set to ''. cError returns the error and allData returns the 
% raw data sample (ASCII line).
% 
% The output fields are defined in the private variable fieldsNew
%
% Input parameters:
%   addressIP           - IP address of the site ("173.181.138.49")
%   portNum             - TCP port where LI7x00 can be found (usually 7200)
%   timeOut             - max length of time (s) waiting for server response (default 20s)
%
% Output parameters:
%   dataOut             - a structure with the fields defined by local variable fieldsNew
%   cErrror             - error flag. Empty ([]) if no error.
%   allData             - ASCII data collected during the call to the instrument
%
% Zoran Nesic               File created        Jan 22, 2022
%                           Last modification:  Jul 29, 2024

% Revisions:
%
% Jul 29, 2024 (Zoran)
%   - Changed from:
%       oneLine(indSt+fieldLen+1:indSt+fieldLen+indEnd)
%     to:
%       oneLine(indSt+fieldLen+1:indSt+fieldLen+indEnd(1))
%     The previous one was issuing warnings in Matlab2024a
% Jan 10, 2024 (Zoran)
%  - returned to pulling VolFlowRate  instead of MeasFlowRate. For 5 days
%    we pulled MeasFlowRate which is more constant (matches set flow more closely)
%    but that's not what EddyPro outputs so it is confusing when comparing app traces to EP traces.
% Jan 5, 2024 (Zoran)
%  - added fields: 'SFVin' and 'DSIVin'
% Mar 19, 2022 (Zoran)
%   - fixed spelling of signalStrength7200
% Feb 10, 2022 (Zoran)
%   - added TimeVector extraction
% Jan 25, 2022 (Zoran)
%   - added comments
%

%%
    arg_default('portNum',7200);
    arg_default('timeOut',5);  

    % these are the fields of the output structure dataOut
    fieldsNew = char('Ndx','Diag','diagVal2','Pair','Phead','CO2',...
                 'H2O','tempIn','tempOut','signalStrength7200','flowRate',...
                 'flowPressure','flowDrive','CH4','signalStrength7700','diag7700','SFVin','DSIVin'); 
    % set all outputs to empty
    cError = [];
    allData = [];
    dataOut = fillWithEmpty(fieldsNew);
    
    % Open server link
    try
        t = tcpclient(addressIP,portNum,"Timeout",timeOut,"ConnectTimeout",timeOut);
    catch ME
        %disp(ME);
        cError = sprintf("Error while connecting to tcp server %s",addressIP);
        return
    end
    
    % read a line and parse it
    try
        tic;
        flagDone = false;
        while toc< timeOut && ~flagDone
            if t.BytesAvailable>0 
                data = read(t, t.BytesAvailable, 'char'); 
                allData = [allData data];    %#ok<*AGROW>
                %fprintf('%d%s',length(allData),char(13));
                oneLine = dataParsing(allData);
                if ~isempty(oneLine)
                    dataOut = processLine(oneLine,fieldsNew);
                    if ~isnan(dataOut.Diag)
                        flagDone = true;
                        break
                    end
                end
            end
        end
        if ~flagDone
            cError = "Error: time-out while collecting data";
        end
    catch
        % if error, set all output values to NaN
        cError = "Error during read and parse while loop";
        dataOut = fillWithEmpty(fieldsNew);
    end
    % delete TCP object
    delete(t)
end

%% Data parsing
function oneLine = dataParsing(allData)
    % good line starts with "(Data ("
    %       and ends   with newline (OA)
    % return empty if a start followed by an end does not exist
    oneLine = [];
    try
        dataTemp = allData;
        % Find all line starts
        indStartAll = strfind(dataTemp,'(Data (');
        if ~isempty(indStartAll)
            % Find all line ends
            indLineEndAll = strfind(dataTemp,newline);
            if ~isempty(indLineEndAll)
                % search for complete lines that have a start
                % followed with an end
                for indStart = 1:length(indStartAll)
                    firstStart = indStartAll(indStart);
                    firstEnd = find(indLineEndAll > firstStart);
                    if ~isempty(firstStart) && ~isempty(firstEnd)
                        oneLine = dataTemp(firstStart:indLineEndAll(firstEnd(1)));
                        %fprintf('%s',oneLine);
                    end
                end
            end
        end
    catch
    end
end

%% Process one line
function dataOut = processLine(oneLine,fieldsNew)

    % Initiate dataOut as all NaNs
    dataOut = fillWithEmpty(fieldsNew);
    
    % Different versions of LI-7x00 and SmartFlux units produce different 
    % variable names. The program will decide how to translate variables here.
    % Each variable name is "translated" to the matching variable name 
    % at the same location in the array fieldsNew. (Ex. DaigVal -> dataOut.Diag)
    
    % First search for "VolFlowRate"
    % if contains(oneLine,'VolFlowRate')
    %     fieldsOriginal = char('Ndx','DiagVal','DiagVal2','APres','DPres','CO2MFd',...
    %                       'H2OMFd','TempIn','TempOut','AvgSS','VolFlowRate',...
    %                       'FlowPressure','FlowDrive','CH4','RSSI','DIAG','SFVin');
    if contains(oneLine,'MeasFlowRate')
        fieldsOriginal = char('Ndx','DiagVal','DiagVal2','APres','DPres','CO2MFd',...
                          'H2OMFd','TempIn','TempOut','AvgSS','VolFlowRate',...
                          'FlowPressure','FlowDrive','CH4','RSSI','DIAG','SFVin'); 
    elseif contains(oneLine,'CO2MF')
        % Probably LI-7500. Try this:
         fieldsOriginal = char('Ndx','DiagVal','DiagVal2','Pres','DPres','CO2MF',...
                          'H2OMF','Temp','TempOut','CO2SS','VolFlowRate',...
                          'FlowPressure','FlowDrive','CH4','RSSI','DIAG','SFVin','DSIVin');
    else
        % Unknown input. Return Nans
        return
    end
 
    % Extract the data
    for k = 1:size(fieldsOriginal,1)
        indSt = strfind(oneLine,['(' deblank(fieldsOriginal(k,:)) ' ']);
        if ~isempty(indSt)
            fieldLen = length(deblank(fieldsOriginal(k,:)));
            indEnd = strfind(oneLine(indSt+fieldLen:indSt+fieldLen+13),')')-2;
            if isempty(indEnd)
                return
            end
            oneNum = str2double(oneLine(indSt+fieldLen+1:indSt+fieldLen+indEnd(1)));
            dataOut.(deblank(fieldsNew(k,:))) = oneNum;
        end
    end
    % If the data extraction went well, then is should be safe to extract
    % the instrument date/time
    fieldLen  =length('Date');
    indSt = strfind(oneLine,'(Date ');
    indEnd = strfind(oneLine(indSt+fieldLen:indSt+fieldLen+13),')')-2; 
    dateIn = oneLine(indSt+fieldLen+1:indSt+fieldLen+indEnd);
    fieldLen  =length('Time');
    indSt = strfind(oneLine,'(Time ');
    indEnd = strfind(oneLine(indSt+fieldLen:indSt+fieldLen+15),')')-2; 
    timeIn = oneLine(indSt+fieldLen+1:indSt+fieldLen+indEnd);
    indCol = strfind(timeIn,':');
    timeIn = timeIn(1:indCol(end)-1);
    dataOut.TimeVector = datenum([dateIn ' ' timeIn]);
    
end

%%
function dataOut = fillWithEmpty(fieldsNew)
        % if error, set all output values to empty 
        for k = 1:size(fieldsNew,1)
            dataOut.(deblank(fieldsNew(k,:))) = [];
        end
end


