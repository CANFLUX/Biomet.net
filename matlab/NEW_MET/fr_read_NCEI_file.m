function [dataOut,dataIn,Header] = fr_read_NCEI_file(fileName,targetVarsIn,targetVarsOut,PbarMult)
% Adapted from fr_read_ECCC_climate_station
% 
% Inputs:
%   fileName            - NCEI annual data file in ASCII/csv format
%   targetVarsIn        - Env Canada var names (see defaults in the program, create your own if needed)
%   targetVarsOut       - Desired output var names (see defaults in the program, create your own if needed)
%   PbarMult            - conversion factor for air Pressure. Default is 1000 so the units of Pbar are Pa)
%
% Outputs:
%     dataOut           - Selecte output variables
%           .tv        time
%           .Tair      deg C
%           .DewPoint  deg C
%           .RH        [%]
%           .WindDir   degrees
%           .WindSpeed m/s
%           .Pbar      Pa
%
%     dataIn    -  Original file output structure
%     Header    -  File header info
%
%
%   Paul Moore                      File created:       Jan 09, 2025
%                                   Last modification:  
%

% Revisions (last one first):
%


targetVarsInDefault = {'WND','TMP','DEW','SLP'};
targetVarsOutDefault = {'Tair','DewPoint',...
                    'WindSpeed','WindDir',...
                    'Pbar'};
arg_default('targetVarsIn',targetVarsInDefault);
arg_default('targetVarsOut',targetVarsOutDefault);
arg_default('PbarMult',10);

fid = fopen(fileName);
if fid > 0
    % read the first two lines in the file (each line is one cell)
    headerLine = textscan(fid,'%q',1,'headerlines',0,'Delimiter','\n','whitespace','\b\t');%,'BufSize',20000);
    %headerLine = fgetl(fid);
    fclose(fid);
    headerLine = char(headerLine{1}); 
    % go through the header and find the column names and the number of
    % variables
    %indComma = find(headerLine==',');
    indQuote = find(headerLine=='"');
    
    % For some reason, the first column (STATION) doesn't have quotes
    %   around it, so it doesn't get tagged as a variable name.
    for i = 1:2:length(indQuote)-1
        %Header.variableNames(i) = headerLine(st+1:indComma(i)-1);
        tmp = headerLine(indQuote(i)+1:indQuote(i+1)-1);
        % filter the characters that cannot be part of var name
        %tmp = tmp(find(tmp>33 & tmp<122)); %#ok<*FNDSB>
        %tmp(find(tmp=='(' |tmp==')' | tmp=='/' | tmp=='%')) = '_'; 
        %Header.variableNames{st} = tmp(find(tmp>33 & tmp<122));
        Header.variableNames{(i+1)/2} = tmp;
    end
else
    fprintf('\n*** File %s could not be opened!\n',fileName);
    dataOut=[];
    dataIn=[];
    Header=[];
    return
end
Header.numOfVars = length(Header.variableNames);
% at this point the number and the names of variables are extracted
% next: create the format string 
formatStr=[];
for kkk=1:Header.numOfVars
    formatStr=[formatStr '%q'];
end

% Load the file with each column being an array of cell strings
fid = fopen(fileName);
if fid > 0
    % read the first two lines in the file (each line is one cell)
    dataIn = textscan(fid,formatStr,'headerlines',1,'Delimiter',',','MultipleDelimsAsOne',1,'whitespace','\t'); %,'BufSize',20000);
    %headerLine = fgetl(fid);
    fclose(fid);
end

% Find time vector column number
varInd = find(startsWith(Header.variableNames,"DATE")) + 1;
TimeVector = datenum(datetime(dataIn{varInd})); %#ok<DATNM>
N = length(TimeVector);

% Loop through all targetVarsOut and extract data
for cntVars = 1:length(targetVarsOut)
    varOut = char(targetVarsOut{cntVars});
    switch varOut
        case 'Tair'
            varInd = find(startsWith(Header.variableNames,"TMP")) + 1;
            ind_start = 1;
            ind_end = 5;
            multiplier = 0.1;
            nanVal = 9999;

        case 'DewPoint'
            varInd = find(startsWith(Header.variableNames,"DEW")) + 1;            
            ind_start = 1;
            ind_end = 5;
            multiplier = 0.1;
            nanVal = 9999;

        case 'WindSpeed'
            varInd = find(startsWith(Header.variableNames,"WND")) + 1;
            ind_start = 9;
            ind_end = 12;
            multiplier = 0.1;
            nanVal = 9999;

        case 'WindDir'
            varInd = find(startsWith(Header.variableNames,"WND")) + 1;
            ind_start = 1;
            ind_end = 3;
            multiplier = 1;
            nanVal = 999;

        case 'Pbar'
            varInd = find(startsWith(Header.variableNames,"SLP")) + 1;
            multiplier = 10;
            ind_start = 1;
            ind_end = 5;
            nanVal = 99999;

        otherwise           
    end
    
    for cntRows = 1:N
        tmp = dataIn{varInd};
        tmp = tmp{cntRows};
        tmp = str2double(tmp(ind_start:ind_end));
        if tmp==nanVal
            tmp = NaN;
        end
        tmpData.(varOut)(cntRows,1) = tmp .* multiplier;
    end
end

if isfield(tmpData,'Tair') && isfield(tmpData,'DewPoint')
    % Magnus approximation for vapour pressure
    %--> https://doi.org/10.1175/1520-0450(1996)035<0601:IMFAOS>2.0.CO;2
    vap_press = sat_vp(tmpData.DewPoint);
    sat_vap_press = sat_vp(tmpData.Tair);
    tmpData.RH = 100.* vap_press ./ sat_vap_press;
end

% Create the output structure (P.Moore -- not sure what the point of this is).
fieldNames = fieldnames(tmpData);
nFields = length(fieldNames);
typeInd = find(startsWith(Header.variableNames,"REPORT_TYPE")) + 1;
type = dataIn{typeInd};
for cntFields = 1:nFields
    t = 1;
    for cntRow=1:length(TimeVector)
        if strcmp(type(cntRow),'FM-15')
            dataOut(t).TimeVector = TimeVector(cntRow); %#ok<*AGROW>
        
            currentFieldName = char(fieldNames{cntFields});
            dataOut(t).(currentFieldName) = tmpData.(currentFieldName)(cntRow);

            t = t + 1;
        end
    end
end