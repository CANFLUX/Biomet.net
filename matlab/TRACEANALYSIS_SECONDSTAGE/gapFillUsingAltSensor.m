function [gapFilledMeasurement,qaqcOut] = gapFillUsingAltSensor(mainSensor,altSensor,stdMultiplier,qaqcIn,flagVerbose)
% This function does gap filling using alternative sensor
% It works for the two traces that are known to be linearly dependan.
%
% The function will find the outliers that are more than stdMultiplier * standard deviation of residuals
% times further away from the linear fit line and remove them before providing the final fit: qaqcOut.poly_af). 
% (For more information see: ta_clean_1to1_trace.m)
%
% NOTE: if qaqcIn is not provided the defaults below will be used. If it's provided,
%       only its provided properties will be used. No other properties will be tested!
%
% Inputs:
%   mainSensor          - main trace, possibly with gaps (NaN-s)
%   altSensor           - second trace, must have a strong linear dependance with mainSensor
%  stdMultiplier        - the std(resudues) multiplier
%  qaqcIn               - a structure to control the qaqc:
%                         Not all properties are requred:
%    properties:   
%      enable           - if true do the testing based on the other properties
%      gapFillOverwrite - if true it will force gap filling even if the fit is not good enough (default: false)
%      r2min            - minimum acceptable r^2
%      minSlope         - minimum acceptable slope
%      maxSlope         - maximum acceptable slope (Default: 1.05)
%      maxRMSE          - maximum acceptable RMSE  (Default: Inf)
% flagVerbose           - ==1 when additinal function comments are requested
%
% Outputs:
%   gapFilledMeasurement - gap filled measurements (if the fit was of a good quality or forced, 
%                          otherwise it's equal to mainSensor)
%   qaqcOut              - A structure with the following fields:
%                          r2       - r^2
%                          rmse     - rmse of the fit
%                          flag     - true:good fit; false:bad fit
%                          msg      - output message
%                          poly_bf  - polynomial coefficients of the fit *before* outliers are removed
%                          poly_af  - polynomial coefficients of the fit *after* outliers are removed
%                          nGaps    - the number of gap-filled points
%                          indGaps  - index of the points that were gap-filled
%
%
% Zoran Nesic                       File created:       Sep  2, 2020
%                                   Last modification:  Sep  2, 2022

% Revisions
%

arg_default('stdMultiplier',5)

defQAQC.enable = true;              % test for acceptable quality of gap filling
defQAQC.gapfillOverwrite = false;   % if the fit is not good enough: 
                                    %    false (default) - do not gap fill
                                    %    true - do gap fill
defQAQC.r2min = 0.95;               % default min acceptable r2
defQAQC.minSlope = 0.95;            % default min acceptable slope fit
defQAQC.maxSlope = 1.05;            % default max acceptable slope fit
defQAQC.maxRMSE = Inf;              % default: no limit for max RMSE
arg_default('qaqcIn',defQAQC)
arg_default('flagVerbose',false)

[~, ~, qaqcOut.poly_bf, qaqcOut.poly_af] = ta_clean_1to1_trace(altSensor,mainSensor,stdMultiplier);

qaqcOut.indGaps = find(isnan(mainSensor));
qaqcOut.nGaps = length(qaqcOut.indGaps);
gapFilledMeasurement = mainSensor;
gapFilledMeasurement(qaqcOut.indGaps) = polyval(qaqcOut.poly_af,altSensor(qaqcOut.indGaps));

%% Calculate some AAQC parameters and test the results:
% - is minSlope < slope < maxSlope
% - is minOffset < offset < maxOffset
% - is RMSE low enough (should I use _filtered traces to test this?)
% - is R2 high enough
y = mainSensor;
x = altSensor;
% use only points when x and y are ~nan
indGood = find(~isnan(x) & ~isnan(y));
x = x(indGood);
y = y(indGood);

% return if qaqc is not enabled
if ~qaqcIn.enable
    return
end

% QAQC tests
y_fit = polyval(qaqcOut.poly_af,x);
mainSensor_res = y - y_fit;
SSresid = sum(mainSensor_res.^2);
SStotal = (length(mainSensor)-1) * var(y);
qaqcOut.r2 = 1 - SSresid/SStotal;
qaqcOut.rmse = sqrt(mean(mainSensor_res.^2));

% Defaults: all good.
qaqcOut.msg = "";
qaqcOut.flag = true;  % good fit

% tests
% Minimum R2
if isfield(qaqcIn,'r2min') && qaqcOut.r2 < qaqcIn.r2min
    qaqcOut.flag = false;
    qaqcOut.msg = sprintf('%s     %s (%6.3f < %6.3f)\n',qaqcOut.msg,'r2 too low!',qaqcOut.r2,qaqcIn.r2min);
end
% Minimum slope
if isfield(qaqcIn,'minSlope') && qaqcOut.poly_af(1) < qaqcIn.minSlope
    qaqcOut.flag = false;
    qaqcOut.msg = sprintf('%s     %s (%6.3f < %6.3f)\n',qaqcOut.msg,'Slope too low!',qaqcOut.poly_af(1),qaqcIn.minSlope);
end
% Maximum slope
if isfield(qaqcIn,'minSlope') && qaqcOut.poly_af(1) > qaqcIn.maxSlope
    qaqcOut.flag = false;
    qaqcOut.msg = sprintf('%s     %s (%6.3f < %6.3f)\n',qaqcOut.msg,'Slope too high!',qaqcOut.poly_af(1),qaqcIn.minSlope);
end

% Maximum RMSE
if isfield(qaqcIn,'maxRMSE') && qaqcOut.rmse > qaqcIn.maxRMSE
    qaqcOut.flag = false;
    qaqcOut.msg = sprintf('%s     %s (%6.3f > %6.3f)\n',qaqcOut.msg,'RMSE is too high!',qaqcOut.rmse,qaqcIn.maxRMSE);
end

% verbose mode and bad fit, print a message (consider also not gap-filling!)
if ~qaqcOut.flag
    % print the message if requested
    if flagVerbose
        fprintf(2,qaqcOut.msg);
    end
    % if ~gapfillOverwrite return the original data
    if ~qaqcIn.gapfillOverwrite
        gapFilledMeasurement = mainSensor;
        fprintf(2,'     No gap-filling due to a poorly matched alternative trace. Returning the original trace.\n');
    else
        fprintf(2,'     Forcing gap-filling with a poorly matched alternative trace.\n');
    end
end






