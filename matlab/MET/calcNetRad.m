function NETRAD = calcNetRad(SW_IN,SW_OUT,LW_IN,LW_OUT,minVal,maxVal)
%   - Calculate net radiation (W/m^2) from four individual components: SW_IN, SW_OUT, LW_IN, LW_OUT
%   - Designed for use in second stage cleaning to estimate net radiation from 
%     first-stage cleaned individual components. 
%   - Applies min/max values (default values match those in RAD_FirstStage_include.ini).
%
% Rosie Howard
% 8 Dec 2025
%
% Inputs:   SW_IN = incoming shortwave radiation (W/m^2)
%           SW_OUT = outgoing shortwave radiation (W/m^2)
%           LW_IN = incoming longwave radiation (W/m^2)
%           LW_OUT = outgoing longwave radiation (W/m^2)
%
%           Optional:
%           minVal = minimum value output will truncate to (optional input)
%           maxVal = maximum value output will truncate to (optional output)
%
% Output:   NETRAD = net radiation in W/m^2

arg_default('minVal',-200);     % default minimum value below which data points will be truncated 
arg_default('maxVal',1000);     % default maximum value above which data points will be truncated

NETRAD = SW_IN - SW_OUT + LW_IN - LW_OUT;
NETRAD(NETRAD < minVal) = NaN;
NETRAD(NETRAD > maxVal) = NaN;

% EOF