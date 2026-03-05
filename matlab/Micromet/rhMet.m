function RH = rhMet(T,Td)
% Calculate relative humidity (rh) from met data (drybulb and dewpoint temperatures)
% Rosie Howard
% 4 February 2026
%
% Reference 
% Stull, 2017: Practical Meteorology, pp.89-92
%
% Inputs:   T = temperature in degC
%           Td = dewpoint temperature in degC
%
% Output:   RH = relative humidity in %

% constants
Rv = 461;       % water vapour gas constant (J kg^-1 K^-1)
T0 = 273.15;    % reference temperature (K)
e0 = 0.6113;    % reference vapour pressure (kPa)
Lv = 2.5e6;     % latent heat of vaporization (J kg^-1)
% Ld = 2.83e6;    % latent heat of deposition (J kg^-1) 

T_K = T + 273.15;   % convert temperatures to Kelvin
Td_K = Td + 273.15;     

% calculate saturation vapour pressure and vapour pressure
e_sat = e0*exp((Lv/Rv) * ( (1/T0) - (T_K.^(-1)) ));        % Clausius-Clapeyron eqn.
e = e0*exp((Lv/Rv) * ( (1/T0) - (Td_K.^(-1)) ));        

% calculate rh
RH = (e./e_sat)*100;    % relative humidity as a percentage

% EOF