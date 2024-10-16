function [rad_pot,T,sin_psi] = test_potential_radiation(tv,latitude,longitude)
% [rad_pot,T,sin_psi] = potential_radiation(tv,latitude,longitude)
%
% Calculates the potential downwelling shortwave radiation at the surface
% according to Stull(1988), 7.3.1 (p.257) assuming no cloud cover
%
% tv is a Matlab time vector in GMT, latitude (positive north) and 
% longitude (positive west) are the coordinates in degrees.

% Created June 7, 2002 by kai*

%tv = tv-15/1440;
% Generate DOY and hour of the day
[yy,mm,dd] = datevec(tv);
doy = floor(tv - datenum(yy,1,1));
tv_hh = mod(tv.*24,24);

% Convert coordinates to radians
lat_rad  = 2*pi*(latitude/360);
long_rad = 2*pi*(longitude/360);

% Solar declination angle (Stull, 7.3.1d)
dec_s = 0.409 .* cos(2*pi.*(doy-173)/365.25);

% Solar elevation angle (Stull, 7.3.1c)
sin_psi = sin(lat_rad)*sin(dec_s) - cos(lat_rad)*cos(dec_s) .* cos(pi.*tv_hh/12-long_rad);

% Transmissivity of the atmosphere assuming no cloud cover (Stull, 7.3.1a)
T = (0.6 + 0.2 .* sin_psi);

% Potential downwelling radiation (Stull, 7.3.1b)
S = 1370; % W/m^2, mean solar irradiance

rad_pot = NaN .* ones(size(tv));
ind_day = find(sin_psi > 0);
rad_pot(ind_day) = S .* T(ind_day) .* sin_psi(ind_day);

ind_nig = find(sin_psi <= 0);
rad_pot(ind_nig) = 0;




