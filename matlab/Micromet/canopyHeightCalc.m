function canopy_height = canopyHeightCalc(measuredSensorH,WTD,wind_speed,ustar,zdL,optionsIn)
% db_struct2database - creates a sparse database (database that does not contain all hhour values)
%
% eg. [structIn,dbFileNames, dbFieldNames,errCode] = ...
%             db_struct2database(Stats,'v:\database\2023\BBS\Chambers',[],[],[],NaN);
%       would update the database using for the year 2023.
%
% Inputs:
%       measuredSensorH         - EC sensor height in (meters)
%       WTD                     - water table debth (meters)
%       wind_speed              - wind speed (m/s)
%       ustar                   - ustar 
%       zdL                     - Obukhov length (m) 
%       optionsIn               - a structure with the following options:
%          .k                     - default: 0.4
%          .min_Ustar             - default  0.2
%          .max_zdL               - default  0.01
%          .max_canopyH           - default  3 m
%          .smooth_method         - if ~empty then it's type of smooth() filtering. default: []
%                                   other suggested option: "rloess"
%          .smooth_span           - number of point or the fraction of all points (see "help smooth")
%
% Outputs:
%       canopy_height           - (filtered) canopy_height
%
%
% NOTE: 
%
%
% (c) Zoran Nesic               File created:       Mar 11, 2026
%                               Last modification:  Mar 11, 2026

% Revisions:
% 

defaultOptionsIn.k              = 0.4;
defaultOptionsIn.min_Ustar      = 0.2;
defaultOptionsIn.max_zdL        = 0.01;
defaultOptionsIn.max_canopyH    = 3;
defaultOptionsIn.smooth_method  = [];
defaultOptionsIn.smooth_span    = 480;
if exist('optionsIn',"var") & ~isempty(optionsIn)
    % if optionsIn exists then
    % combine defaultOptionsIn and optionsIn
    % bacause qaqcin may not have all the required parameters
    fldNames = fieldnames(optionsIn);
    for cntF = 1:length(fldNames)
        fN = char(fldNames(cntF));
        defaultOptionsIn.(fN) = optionsIn.(fN);
    end
end
optionsIn = defaultOptionsIn;

indGood =   abs(zdL) < optionsIn.max_zdL ...
          & ustar    > optionsIn.min_Ustar;
 
sensorH = measuredSensorH - WTD;
canopy_height = NaN(size(wind_speed));
k = optionsIn.k;
canopy_height(indGood) = sensorH(indGood)./(0.6 + 0.1*exp((k*wind_speed(indGood))./ustar(indGood)));
canopy_height(canopy_height>optionsIn.max_canopyH) = NaN;

% check if smoothing is needed
if ~isempty(optionsIn.smooth_method)
    %notNan = ~isnan(canopy_height);
    %heightTmp = smooth(canopy_height(notNan),optionsIn.smooth_span,optionsIn.smooth_method);
    canopy_height = smooth(canopy_height,optionsIn.smooth_span,optionsIn.smooth_method,'omitnan');
    %canopy_height(notNan) = heightTmp;
end
