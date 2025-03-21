function dataOut = SAL_read_one_day(dateIn,configIn)
%  dataOut = UdeM_read_one_day(dateIn,configIn) - loads one day of UdeM chamber
%                                         data (loggers and LGR)
%
% example:
%   dateIn = datenum(2023,8,25)
%   configIn = UdeM_init_all(dateIn);
%   dataOut = UdeM_read_one_day(dateIn,configIn); % load Aug 22, 2019 data
%
% Zoran Nesic                   File created:       Aug 25, 2023
%                               Last modification:  Sep  1, 2023
%

% Revisions (newest first):
%
% Sep 1, 2023 (Zoran)
%   - Added an option to calibrate/convert units (only polynomial conversion)


dataOut(1).configIn = configIn;
dateIn = dateIn(1);

%dataOut.tv = fr_round_time(dateIn);

% The data logger files are stored in daily files and labeled with the end
% time (today's date!). 
% The following creates the correct base file name: 'yymmdd'
dateInLogger = floor(dateIn);
dayStr = datestr(round(dateInLogger),'yyyymmdd');

% First load daily files (data logger data)
instrumentNum = 2;
fileName = fullfile(configIn.csi_path,dayStr(3:end),[dayStr(3:end) '_' configIn.Instrument(instrumentNum).fileName '.dat' ]);
tableID = configIn.Instrument(instrumentNum).tableID;
varNames_101 = configIn.Instrument(instrumentNum).tableVars;
timeUnit = 'SEC';
roundType = 1;
tv_input_format = configIn.Instrument(instrumentNum).tv_input_format;
chanInd = [];
[~,~,~,rawData.logger.CH_CTRL] = fr_read_csi_file(fileName,chanInd,varNames_101,tableID,timeUnit,roundType,tv_input_format);

instrumentNum = 3;
fileName = fullfile(configIn.csi_path,dayStr(3:end),[dayStr(3:end) '_' configIn.Instrument(instrumentNum).fileName '.dat' ]);
tableID = configIn.Instrument(instrumentNum).tableID;
varNames_102 = configIn.Instrument(instrumentNum).tableVars;
timeUnit = 'SEC';
roundType = 1;
tv_input_format = configIn.Instrument(instrumentNum).tv_input_format;
chanInd = [];
[~,~,~,rawData.logger.(configIn.Instrument(instrumentNum).varName)] = fr_read_csi_file(fileName,chanInd,varNames_102,tableID,timeUnit,roundType,tv_input_format);



% Create daily raw data files (each trace is one day long as
% oposed to 30 minutes). It could make more sense with 1-hour cycle (or
% longer) of chamber measurements.

% First store the logger data
%
dataOut.rawData.logger = rawData.logger;

% Then join the analyzer data
instrumentNum = 1;
instrumentVarName = configIn.Instrument(instrumentNum).varName;
dataOut.rawData.analyzer.(instrumentVarName)= struct('tv',[]);
for i = 1:48
    currentDate = floor(dateIn)+i/48;
    try
        [~,~,rawData.analyzer.(instrumentVarName)] = fr_read_BiometMat(currentDate,configIn,instrumentNum);
        for fieldName = fieldnames(rawData.analyzer.(instrumentVarName))'   
            fName = char(fieldName);
            if isfield(dataOut.rawData.analyzer.(instrumentVarName),fName)
                dataOut.rawData.analyzer.(instrumentVarName).(fName) = ...
                    [dataOut.rawData.analyzer.(instrumentVarName).(fName); ...
                     rawData.analyzer.(instrumentVarName).(fName)];
            else
                dataOut.rawData.analyzer.(instrumentVarName).(fName) = rawData.analyzer.(instrumentVarName).(fName);
            end
        end
    catch
        fprintf('Missing or bad file for: %s\n',datestr(currentDate));
    end
end

% At this point all the data is loaded into dataOut.RawData
% Sometimes some traces need to have their units changed or
% need a bit of calibration. There is an option to add
% calibration polynomials in the ini file when defining 
% configIn.chamber().traces. 
% The program will now look for the raw data that goes into
% the configIn.chamber().traces and runs it through the polynomials
% (if they exist).
for cntTraces = 1:size(configIn.chamber(1).traces,1)
    [strTraceName,strInstrumentName,strInstrumentType] = findRawTraceName(configIn,1,char(configIn.chamber(1).traces{cntTraces,1}));
    if ~isempty(strTraceName)
        calPoly = double(configIn.chamber(1).traces{cntTraces,5});
        dataOut.rawData.(strInstrumentType).(strInstrumentName).(strTraceName) = ...
            polyval(calPoly,dataOut.rawData.(strInstrumentType).(strInstrumentName).(strTraceName)) ;
    end
end


