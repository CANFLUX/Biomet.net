function [Eddy_results,Eddy_HF_data_OUT,miscVariables] = fr_calc_eddy(Eddy_HF_data_IN, Eddy_delays, RotationType, BarometricP, Krypton, Tair,miscVariables,configIn, SystemNum)
% fr_calc_eddy  - calculation of eddy correlation values from raw data for ONE data period (usually 1/2 hour)
%                 
%=================================================================================
%
%   Inputs:
%       Eddy_HF_data_IN -  high frequency data in engineering units
%                          Matrix has the following columns:
%                           - U V W T CO2 H2O TC1 TC2 Aux1 Aux2 ... AuxN
%                          where Aux1..N are auxilary SCALAR inputs (like Krypton)
%       Eddy_delays     - a vector of delays for each channel (in units of samples)
%                         (default a vector of zeros - no delays)
%       RotationType    - a character: 'N' for Natural or 'C' for canopy rotation
%       BarometricP     - the value for barometric pressure (the mean for this hhour)
%                         (default 94.5kPa - good for BERMS)
%       Krypton         - krypton channel number (one of the AUX inputs). Default is 0
%                         which means that there isn't any krypton measurements
%       Tair            - air temperature (hhour mean). Default is the mean Sonic temp.
%       configIn        - (optional) EC configuration file
%       SystemNum       - (optional) EC system number
%
%
% References: Stull, R.B., 1995.  Meteorology Today for Scientists and Engineers, 
%                 West Publ. Co.
%             Stull, R.B., 1988.  Boundary Layer Meteorology, Kluwer Academic Publ.
%             Wallace and Hobbs(1977) Atmospheric Science - An Introductory Survey,
%                 Academic Press Inc.
%=================================================================================
%
% (c) Zoran Nesic               File created:       Jun  4, 2000
%                               Last modification:  Apr  3, 2023
%

%       -   The Eddy_results structure has the
%           following components:
%			  |.SourceInstrumentNumber
%			  |.SourceInstrumentChannel
%			  |.MiscVariables|
%							 |.NumOfSamples
%							 |.WaterUseEfficiency
%							 |.Penergy
%			  |.Delays|
%					  |.Calculated
%             |.Zero_Rotations. |
%             |.Three_Rotations.|
%								|.Angles|
%										|.eta
%										|.theta
%										|.beta
%								|.VarNames
%                               |.Avg
%                               |.Min
%                               |.Max
%                               |.Std
%                               |.LinDtr|
%                               |.AvgDtr|
%                                       |Cov
%                                       |.Fluxes|
%                                               |.Hs
%                                               |.Htc1
%                                               |.Htc2
%                                               |.LE_L
%                                               |.LE_K
%                                               |.Fc

%
% Revisions: 
%
%   April 3, 2023 (Zoran)
%	- Sets a default H2O_bar value if there is no IRGA to allow sonics to still be rotated
%   Nov 14, 2017 (Zoran)
%   -   Added configIn as an input parameter.  If it doesn't exist, the
%       function should work as in the past.  If it does exist, then the
%       configIn should be used to figure out if CH4, N2O and additional LE
%       calculations need to be performed and the new fluxes will be added to
%       .Flux branch.
%    May 5, 2009 (Zoran)
%      - Set p and R2s to NaN if the vector is full of NaNs
%               p(i,:) = NaN;
%               R2s(i) = NaN;
%      - June 26, 2008 
%                        Nick and Zoran - miscVariables added as new input and output
%                        parameter so that actual Pbar and Tair used in calculation is
%                        recorded in the Stats structure
%
%            04.05.01 E.Humphreys - added fr_rotatc as an option, added in 
%            26.09.01 E.Humphreys - increased precision on constants, added documentation, references
%            08.10.02 E.Humphreys - rearranged output structure
%            01.08.03 E.Humphreys - changed input var to h2o_bar from WaterMoleFraction in spe_heat.m
%            08.29.03 E.Humphreys - changed pressure used in kinematic flux conversions to partial pressure for dry air
%            02.03.05 kai* - Added shifted HF data as output
%            

% read in CONSTANTS
UBC_biomet_constants;


% INPUT parameter defaults
arg_default('configIn',[]);             % configIn does not exist as input set it to []
arg_default('RotationType','Three');    % default rotation is is 'natural' (three rotations)
arg_default('BarometricP',94.5);        % default pressure is 94.5kPa
arg_default('Krypton',0);               % default Krypton channel is 0 (no Krypton measurements)
arg_default('Tair',[]);                 % if Tair is empty Sonic temp. will be used

% if exist('RotationType') ~= 1 | isempty(RotationType)
%     RotationType = 'Three';                             % default rotation type is 'natural' (three rotations)
% end 
if BarometricP < 89 || BarometricP > 105 
    BarometricP = 94.5;                            % check if the pressure makes sense
end                                                 % default pressure is 94.5kPa
% if exist('Krypton') ~= 1 | isempty(Krypton)
%     Krypton = 0;                                    % default Krypton channel is 0 (no Krypton measurements)
% end 
% if exist('Tair') ~= 1 
%     Tair = [];                                      % if Tair is empty Sonic temp. will be used
% end 

%----------------------------------------------------------------------
%              Delay specified eddy instruments
%              (ie. adjust wind velocity traces to match co2, h2o traces)
%----------------------------------------------------------------------

[Eddy_results.MiscVariables.OrigNumOfSamples,m]  = size(Eddy_HF_data_IN);  % save the number of data points
% in the original data set
if exist('Eddy_delays') ~= 1 | isempty(Eddy_delays) %#ok<*OR2,*EXIST>
    Eddy_delays = zeros(1,m);
end 

Eddy_HF_data            = fr_shift(Eddy_HF_data_IN, Eddy_delays);  % remove the delay times from Eddy_HF_data_IN

if nargout > 1 % Export data as used in statistics
    Eddy_HF_data_OUT = Eddy_HF_data;
end

[n,nVariables]          = size(Eddy_HF_data);
Eddy_results = setfield(Eddy_results, {1}, 'MiscVariables', 'NumOfSamples',n);


%----------------------------------------------------------------------
%             Basic statistics before rotation on non-detrended data
%                (means, max, min, and std)
%----------------------------------------------------------------------

Eddy_results.Zero_Rotations.Avg  = mean(Eddy_HF_data);   % mean
Eddy_results.Zero_Rotations.Min  = min(Eddy_HF_data);    % min
Eddy_results.Zero_Rotations.Max  = max(Eddy_HF_data);    % max
Eddy_results.Zero_Rotations.Std  = std(Eddy_HF_data);    % std

%----------------------------------------------------------------------
%             Detrend before rotation, determine covariance matrices
%                
%----------------------------------------------------------------------

detrendVal                       = detrend(Eddy_HF_data);    % linear detrending
Eddy_results.Zero_Rotations.LinDtr.Cov ...
                                 = cov(detrendVal);
                             
[Slope, Offset, R2]              = fr_calc_detrend_slopes(Eddy_HF_data);  %characteristics of linear trends                           

detrendVal                       = detrend(Eddy_HF_data,0);  % block-average detrending 
Eddy_results.Zero_Rotations.AvgDtr.Cov ...
                                 = cov(detrendVal);

%----------------------------------------------------------------------
%                   Rotation
%----------------------------------------------------------------------
for detrendType = [{'AvgDtr'},{'LinDtr'}]                     % do calculations for both LinDtr and AvgDtr
    
    if strcmp(upper(RotationType),'N') | strcmp(upper(RotationType),'THREE') %#ok<*STCI>
        RotationType = 'Three';
    elseif strcmp(upper(RotationType),'C') | strcmp(upper(RotationType),'TWO')
        RotationType = 'Two';
    elseif strcmp(upper(RotationType),'ONE')
        RotationType = 'One';
    else
        disp('This rotation-type is unsupported'); break
    end

    [meansSr,statsSr,angles] = fr_rotate(Eddy_results.Zero_Rotations.Avg(1:3),...
        getfield(Eddy_results.Zero_Rotations,char(detrendType),'Cov'),...
        RotationType);                                        % perform rotation
         
    Eddy_results = setfield(Eddy_results,{1},[RotationType '_Rotations'],...
        char(detrendType), 'Cov', statsSr);              % and all the covariances
    
    Eddy_results = setfield(Eddy_results,{1},[RotationType '_Rotations'],...
        'Angles','Eta', angles(1));                                       
    Eddy_results = setfield(Eddy_results,{1},[RotationType '_Rotations'],...
        'Angles','Theta', angles(2));                                     
    Eddy_results = setfield(Eddy_results,{1},[RotationType '_Rotations'],...
        'Angles','Beta', angles(3));                      % store the rotation angles
     
end
  
  Eddy_results = setfield(Eddy_results,{1},[RotationType '_Rotations'],...
      'Avg',Eddy_results.Zero_Rotations.Avg);
  Eddy_results = setfield(Eddy_results,{1},[RotationType '_Rotations'],...
      'Avg', {1:3}, meansSr);                               % change only vector mean values
  Eddy_results = setfield(Eddy_results,{1},[RotationType '_Rotations'],...
      'Min',Eddy_results.Zero_Rotations.Min);
  Eddy_results = setfield(Eddy_results,{1},[RotationType '_Rotations'],...
      'Max',Eddy_results.Zero_Rotations.Max);
  Eddy_results = setfield(Eddy_results,{1},[RotationType '_Rotations'],...
      'Std',Eddy_results.Zero_Rotations.Std);
  
%-----------------------------------------------------------------------
%                   FLUX calculations
%-----------------------------------------------------------------------

% extract all the flux-calculation variables

% The air temperature is used for the air density calculations
% The old versions of Eddy flux calculations used to use the average temperatures
% measured by the sensors themself when Tair was needed (Tsonic for sonic H, Tc1 for Htc1...)
% This would introduce errors when comparing Sonic to a thermocouple sensible heat.
%
if isempty(Tair)                                            % this should be the "best" thermodynamic Tair temp.
    %    Tair    = Eddy_results.AfterRot.AvgMinMax(1,4) + ZeroK; % use Sonic if nothing else is available
    Tair = getfield(Eddy_results,char([RotationType '_Rotations']),'Avg',{4}) + ZeroK; % use Sonic if nothing else is available
else
    Tair    = Tair + ZeroK;                                 % convert to Kelvins
end

%===================================================
% June 26, 2008
% Return the Pbarometric and Tair used for the actual calculations back to
% the main program: Nick and Zoran, 
miscVariables.BarometricP = BarometricP;
miscVariables.Tair = Tair - ZeroK;
%===================================================

if length(Eddy_results.([RotationType '_Rotations']).Avg)>4
    h2o_bar = getfield(Eddy_results,char([RotationType '_Rotations']),'Avg',{6}); % mmol / mol of dry air
else
    % there is not H2O trace available, use a default value instead
    %
    h2o_bar = 12;
    fprintf('*** The system does not have h2o instrument. Using default value: %f ***\n',h2o_bar);
end
WaterMoleFraction = h2o_bar/(1+h2o_bar/1000);               % get mmol/mol of wet air


for rotation = [{char([RotationType '_Rotations'])}, {'Zero_Rotations'}]
    
    for detrendType = [{'AvgDtr'},{'LinDtr'}]                   % do calculations for both LinDtr and AvgDtr
        tmpCov = getfield(Eddy_results, char(rotation), char(detrendType), 'Cov');% extract either LinDtr or AvgDtr covariance matrix
        uw      = tmpCov(1,3);                                  % covariance u^w
        vw      = tmpCov(2,3);                                  % covariance v^w   
        wT      = tmpCov(3,4);                                  % covariance w^T (sonic temp)
 
        % Calculate sonic fluxes
        %
        % Ustar calculations
        %
        Ustar   = ( uw.^2 + vw.^2 ) ^ 0.25;                         % Ustar
        Eddy_results = setfield(Eddy_results,{1},char(rotation),...
            char(detrendType),'Fluxes','Ustar',Ustar);
        
        %Determine air characteristics for subsequent calculations
        rho_moist_air = rho_air_wet(Tair-ZeroK,[],BarometricP,WaterMoleFraction); % density of moist air
        L_v           = Latent_heat_vaporization(Tair-ZeroK)./1000;    % J/g latent heat of vaporization Stull (1988)             
        mol_density_dry_air   = (BarometricP/(1+h2o_bar/1000))*1000/(R*Tair);
        
        %
        % Sensible heat calculations
        %
        Cp_moist = spe_heat(h2o_bar); %specific heat of moist air
        
        SensibleSonic  = wT * rho_moist_air * Cp_moist;             % Sensible heat (Sonic)
        Eddy_results = setfield(Eddy_results,{1},char(rotation),...
            char(detrendType),'Fluxes','Hs',SensibleSonic);        
        % Legacy way of dealing with extra channels after u,v,w,T,c,h
        wc      = 0;                                            % default
        wh      = 0;                                            % default
        hh      = 0;                                            % default
        wTc1      = 0;                                          % default
        wTc2      = 0;                                          % default
        
        % If this is the new style setup use ini file values to 
        % determine how the fluxes get calculated
        if isfield(configIn.System(SystemNum),'FluxNames')
            % if this is the new style ini file use the FluxNames and
            % FluxTypes to create the fluxes
            
            % Create the obsolete fluxes to keep the output file consistent
                          
            Eddy_results = setfield(Eddy_results,{1},char(rotation),...
                char(detrendType),'Fluxes','Htc1',0); % Sensible heat (Tc1)      
            Eddy_results = setfield(Eddy_results,{1},char(rotation),...
                char(detrendType),'Fluxes','Htc2',0); % Sensible heat (Tc2)
            
            % Go through all scalars and calculate fluxes
            for fluxNum = 1:length(configIn.System(SystemNum).FluxNames)
                w_cov = tmpCov(3,4+fluxNum);  % get w^scalar covariance
                fluxName = char(configIn.System(SystemNum).FluxNames(fluxNum));
                temp = char(upper(configIn.System(SystemNum).FluxTypes(fluxNum)));
                switch temp
                    case 'GASS'
                        fluxTemp = w_cov * mol_density_dry_air;              
                        % Check if this is Fc flux. If it is, calculate
                        % Penergy
                        if strcmp(fluxName,'Fc')
                            % Store w_cov for later use (WaterEfficiency
                            % calc)
                            wc = w_cov;
                        end
                    case 'LE'
                        % Latent heat calculations
                        %
                        convH    = mol_density_dry_air.*Mw./1000;               % convert mmol h2o/mol dry air -> g h2o/m3 (refer to Pv = nRT)          
                        wh_g     = w_cov * convH;                               % convert m/s(mmol/mol) -> m/s(g/m^3)
                        fluxTemp  = wh_g * L_v;                                 % LE LICOR
                        % Check if this is LE_L (LICOR LE) flux.
                        % if it is, store w_cov for later use
                        if strcmp(fluxName,'LE_L')
                            wh = w_cov;
                            LELicor = fluxTemp;
                        end
                end %switch 
                
                % Store the calculated flux
                Eddy_results = setfield(Eddy_results,{1},char(rotation),...
                    char(detrendType),'Fluxes',fluxName,fluxTemp); % Store flux

            end % for fluxNum
            
        else
            % otherwise do it the old style by grabbing the hard-coded covs
            if nVariables > 4
                wc      = tmpCov(3,5);                              % covariance w^C                              
            end
            if nVariables > 5
                wh      = tmpCov(3,6);                              % covariance w^h
                hh      = tmpCov(6,6);                              % variance h^h
            end
            if nVariables>6
                wTc1    = tmpCov(3,7);                              % covariance w^Tc1 (first thermocouple)

            end 
            if nVariables>7
                wTc2    = tmpCov(3,8);                              % covariance w^Tc2 (second thermocouple)
            end 
        
            SensibleTc1    = wTc1 * rho_moist_air * Cp_moist;       % Sensible heat (Tc1)
            Eddy_results = setfield(Eddy_results,{1},char(rotation),...
                char(detrendType),'Fluxes','Htc1',SensibleTc1);

            SensibleTc2    = wTc2 * rho_moist_air * Cp_moist;       % Sensible heat (Tc2)
            Eddy_results = setfield(Eddy_results,{1},char(rotation),...
                char(detrendType),'Fluxes','Htc2',SensibleTc2);      
            %
            % CO2 flux calculations
            %
            convC = mol_density_dry_air;             % convert umol co2/mol dry air -> umol co2/m3 dry air (refer to Pv = nRT)

            Fc    = wc * convC;                      % CO2 flux (umol m-2 s-1)

            Eddy_results = setfield(Eddy_results,{1},char(rotation),...
                char(detrendType),'Fluxes','Fc',Fc);

            %
            % Latent heat calculations
            %
            convH    = mol_density_dry_air.*Mw./1000;               % convert mmol h2o/mol dry air -> g h2o/m3 (refer to Pv = nRT)

            wh_g     = wh * convH;                                  % convert m/s(mmol/mol) -> m/s(g/m^3)
            LELicor  = wh_g * L_v;                                  % LE LICOR

            Eddy_results = setfield(Eddy_results,{1},char(rotation),...
                char(detrendType),'Fluxes','LE_L',LELicor);
          
        end % ~isempty(configIn)

        %
        % P energy calculation
        %
        Penergy = -10.47 * wc;                                      % Penergy

        Eddy_results = setfield(Eddy_results,{1},char(rotation),...
            char(detrendType),'Fluxes','MiscVariables','Penergy',Penergy);

        %
        % Water-use efficiency
        %

        if wh == 0
            WaterUseEfficiency = 1e38;
        else
            WaterUseEfficiency = - wc / wh;                         % WaterUseEfficiency
        end

        Eddy_results = setfield(Eddy_results,{1},char(rotation),...
            char(detrendType),'Fluxes','MiscVariables','WUE',WaterUseEfficiency);

        mu       = Ma/Mw;                                       % ratio of the molecular weight of air to water

        if Krypton ~= 0                                         % if Krypton channel exists
            wkh2o   = tmpCov(3,Krypton);                        % covariance w^kh2o    
            hr      = tmpCov(8,Krypton);                        % covariance h^kh2o
            rr      = tmpCov(Krypton,Krypton);                  % variance kh2o^kh2o

            % Krypton WPL correction        
            Pa = 1e6 * BarometricP/ Rd/ Tair;
            sigma = h2o_bar*convH/Pa;
            wkh2o = (1 + mu*sigma)*(wkh2o + h2o_bar*convH/Tair*wT);
            % store corrected w^kh2o values in the covariance matrix if LinDtr
            if strcmp(detrendType,'LinDtr') 
                Eddy_results = setfield(Eddy_results,{1},char(rotation),...
                                char(detrendType),'Cov',{3,Krypton},wkh2o);      
                Eddy_results = setfield(Eddy_results,{1},char(rotation),...
                                char(detrendType),'Cov',{Krypton,3},wkh2o);
            end

            oxygen_corr = 2.542 * abs(c.KH2O_poly(1))/Tair*SensibleSonic;
            LEKrypton   = wkh2o * L_v + oxygen_corr;              % LE Krypton

            if hh == 0 | rr == 0
                HRcoeff = 1e38;
            else
                HRcoeff = hr / abs( hh * rr ) ^ 0.5;              % h-r correlation coeff
            end
        else
            HRcoeff = 1e38;
            LEKrypton = 0; 
        end

        Eddy_results = setfield(Eddy_results,{1},char(rotation),...
            char(detrendType),'Fluxes','LE_K',LEKrypton);

        Eddy_results = setfield(Eddy_results,{1},char(rotation),...
            char(detrendType),'Fluxes','MiscVariables','HR_coeff',HRcoeff);

        %
        % Bowen ratio calculations
        %
        if ~exist('LELicor','var') || LELicor == 0
            BowenRatioLICOR = 1e38;
        else

            BowenRatioLICOR = SensibleSonic / LELicor;              % BowenRation LICOR
        end

        Eddy_results = setfield(Eddy_results,{1},char(rotation),...
            char(detrendType),'Fluxes','MiscVariables','B_L',BowenRatioLICOR);

        if LEKrypton == 0
            BowenRatioKrypton = 1e38;
        else
            BowenRatioKrypton = SensibleSonic / LEKrypton;          % BowenRation Krypton
        end

        Eddy_results = setfield(Eddy_results,{1},char(rotation),...
            char(detrendType),'Fluxes','MiscVariables','B_K',BowenRatioKrypton);
    end % of detrendType
end %of rotationType

%-----------------------------------------------------------------------
%                   MISC calculations
%-----------------------------------------------------------------------
for rotation = [{char([RotationType '_Rotations'])}, {'Zero_Rotations'}]
    
    for detrendType = [{'AvgDtr'},{'LinDtr'}] 
        
        if strcmp(char(detrendType), 'LinDtr')
            Eddy_results = setfield(Eddy_results,{1},char(rotation),...
                char(detrendType),'MiscVariables','Slope',Slope);
            Eddy_results = setfield(Eddy_results,{1},char(rotation),...
                char(detrendType),'MiscVariables','Offset',Offset);
            Eddy_results = setfield(Eddy_results,{1},char(rotation),...
                char(detrendType),'MiscVariables','R2',R2);
        end
    end
end

%--------------------------------------------------------------------------------
function [Slopes, Offsets, R2s] = fr_calc_detrend_slopes(EngUnits)

for i = 1:min(size(EngUnits));
    if all(isnan(EngUnits(:,i)))
        p(i,:) = NaN; %#ok<*AGROW>
        R2s(i) = NaN;
    else
        [p(i,:), R2s(i)] = polyfit1((1:1:length(EngUnits(:,1)))',EngUnits(:,i),1);
    end
end

Offsets = p(:,2)';
Slopes  = p(:,1)';

    