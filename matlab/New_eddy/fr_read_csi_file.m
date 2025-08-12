function [EngUnits,Header,tv,dataOut] = fr_read_csi_file(fileName,chanInd,chanNames,tableID,timeUnit,roundType,tv_input_format) 
% [EngUnits,Header,tv] = fr_read_TOA5_file(fileName,chanInd,tableID,assign_in,timeUnit,roundType,tv_input_format) 
%
% Read CSI 23x files (ascii output tables from table based loggers)
% 
% Inputs:
% Inputs:
%       FileName        - full file name including path. Wild cards accepted
%       dateIn          - time vector to extract.  [] extracts all data
%       chanInd         - channels to extract. [] extracts all
%       chanNames       - a cell array of column names. 
%       tableID         - Table to be extracted
%       timeUnit        - nearest time unit that time will be rouned to (see
%                         fr_round_time). When rounding on the seconds function
%                         will assume that the time is in columns 2-5 otherwise
%                         2-4 (YEAR, DOY, HHMM, SECONDS)
%       roundType       - 1,2,3 -> see fr_round_time for details
%       tv_input_format -               [type arg1    arg2       arg3   ]
%                           21x files:  [1    yearCol DOYcol     timeCol]
%                           DecDOY:     [2    year    0.0-364.99 NA     ] not implemented                         
%                           DecDOY:     [3    year    1.0-365.99 NA     ] not implemented
%                           no yearCol: [4    year    DOYcol     timeCol] not implemented
%
%
% (c) Zoran Nesic                               File created:      Aug 27, 2023
%                                               Last modification: Aug 12, 2025
%

% Revisions:
%
% Aug 12, 2025 (Zoran)
%   - Added ,"FileType","delimitedtext" to readtable 
%   - added comments for chanNames in the function header
%   - added TimeVector to dataOut

% Default arguments
arg_default('timeUnit','30min');        % rounding to half hour
arg_default('roundType',2);             % rounding to the end of timeUnit
arg_default('tv_input_format',[1 2 3 4])% default is regular 21x format
arg_default('varName','dataOut');

switch tv_input_format(1)
    case 1
        timeChans = tv_input_format(2:end);
    case {2,3,4}
        error('fr_read_csi.m: type not implemented!')
    otherwise
        error('fr_read_csi.m: type not implemented!')
end

tv = [];

EngUnits = [];
Header = [];
tv = [];
dataOut = [];

% Find no of variables in file
if ~exist(fileName,'file')
    fprintf('File %s not found. (fr_read_csi_file.m).\n',fileName);
    return
end
try
    climateDataTable = readtable(fileName,"FileType","delimitedtext");
catch
    fprintf('Error reading file %s. (fr_read_csi_file.m).\n',fileName);
    return
end

% exit if there is no data to process
if isempty(climateDataTable)
    return
end
numOfVars = size(climateDataTable,2);
if ~exist('chanInd','var') || isempty(chanInd)
    chanInd = 1:numOfVars;
end

if exist('chanNames','var') && ~isempty(chanNames)
    climateDataTable.Properties.VariableNames = chanNames;
end

EngUnits = table2array(climateDataTable);
ind = find(EngUnits(:,1) == tableID);
EngUnits = EngUnits(ind,:);
climateDataTable = climateDataTable(ind,:);

 

    
% Export time vector if exists 
switch upper(timeUnit)
    case 'SEC'
        tv = fr_csi_to_timevector(EngUnits(:,[timeChans timeChans(end)+1]));      % if rounding on the seconds 
    otherwise
        tv = fr_csi_to_timevector(EngUnits(:,timeChans));
end

tv = fr_round_time(tv,timeUnit,roundType);
[tv,indSort] = sort(tv);
EngUnits = EngUnits(indSort,chanInd);


for cntFields = 1:numOfVars
    fieldName = char(climateDataTable.Properties.VariableNames{cntFields});
    dataOut.(fieldName) = EngUnits(:,cntFields);
end
dataOut.tv = tv;
dataOut.TimeVector = tv;
% 
% if strcmpi(assign_in,'caller')
%     assignin(assign_in,varName, dataOut);
% end

end



% =============================================================
% Local functions
%==============================================================

function tv = fr_csi_to_timevector(csiTimeMatrix)

if size(csiTimeMatrix,2) == 4
    secondX = csiTimeMatrix(:,4);
else
    secondX = 0;
end

tv = datenum( csiTimeMatrix(:,1),1 , csiTimeMatrix(:,2),...
              fix(csiTimeMatrix(:,3)/100),...
              (csiTimeMatrix(:,3)/100 - fix(csiTimeMatrix(:,3)/100))*100,secondX);
end
