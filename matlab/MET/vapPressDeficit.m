function VPD = vapPressDeficit(T,RH)
% Calculate vapour pressure deficit (hPa) from met data
% Rosie Howard
% 8 Dec 2025
%
% Reference 
% Stull, 2017: Practical Meteorology, pp.89-92
%
% Inputs:   T = temperature (degC)
%           RH = relative humidity (%)
%
% Output:   VPD = vapour pressure deficit in hPa

[e_H,ea_H] = vapPressMet(T,RH);     % return vapour pressure and saturated vapour pressure
                                    % vapPressMet is a Biomet function
VPD = ea_H - e_H;                   % calculate vapour pressure deficit
VPD = VPD*10;                       % convert units to hPa (in line with Ameriflux)
VPD(VPD < 0) = 0;                   % truncate negative values to zero

% EOF