function ALB = calcAlb(SW_IN,SW_OUT)
%   - Calculate albedo (%) from individual components: SW_IN, SW_OUT
%   - Designed for use in second stage cleaning to estimate albedo from 
%     first-stage cleaned individual components. 
%   - Applies min/max values.
%
% Rosie Howard
% 8 Dec 2025
%
% Inputs:   SW_IN = incoming shortwave radiation (W/m^2)
%           SW_OUT = outgoing shortwave radiation (W/m^2)
%
% Output:   ALB = albedo in %

% define minMax values
minVal = 1E-05;     % default minimum value below which data points will be truncated 
maxVal = 100;       % default maximum value above which data points will be truncated

ALB = 100 * SW_OUT./SW_IN;  % calculate albedo (%)

% apply minMax values
ALB(ALB < minVal) = NaN;
ALB(ALB > maxVal) = NaN;

% EOF