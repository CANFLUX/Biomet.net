function canopy_height = canopyHeightCalc(measuredSensorH,WTD,wind_speed,ustar,zdL,optionsIn)
% canopy_height = canopyHeightCalc(measuredSensorH,WTD,wind_speed,ustar,zdL,optionsIn)
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
%          .smooth_method         - if ~empty then it's a type of filtering. default: []
%                                   Suggested options: "filtfilt" (recommended) ,"rloess","moving"
%                                    - if "filtfilt" use the filtfilt() function. 
%                                    - otherwise pass the options to  smooth() function.
%          .smooth_span           - 60-120 works well with "filtfilt" (higher number -> more smooting)
%                                   when using smooth(), it's the number of point or the fraction (0-1) of all points 
%                                   480 (default) works well with "rloess" or "moving"
%          .smooth_omitnan        - 'omitnan' (default), otherwise use smooth() without option 'omitnan'.
%                                   (see "help smooth")  for more info on smooth() function
%          .extrap                - 'extrap' (default) is to extrapolate the end points if missing
%                                    or, if it's a double value then use that as "default_canopy_height" for the end points
%                                     (see interp1() for more info)
%                                   
%
% Outputs:
%       canopy_height           - (optionaly filtered) canopy_height
%
% Example:
%       optionsIn.smooth_method = "filtfilt";
%       optionsIn.smooth_span = 120;
%       canopy_height_filter = canopyHeightCalc(measuredSensorH,WTD,wind_speed,ustar,zdL,optionsIn)
%
%
% NOTE: 
%       - When using "rloess" it can take a very long time to get the result (>10s compared to a few ms). 
%       - The default max_canopyH limit might be very low for agricultural fields.
%
%
% (c) Zoran Nesic               File created:       Mar 11, 2026
%                               Last modification:  Mar 12, 2026

% Revisions:
% 
% Mar 12, 2026 (Zoran)
%   - added filtfilt option

defaultOptionsIn.k              = 0.4;
defaultOptionsIn.min_Ustar      = 0.2;
defaultOptionsIn.max_zdL        = 0.01;
defaultOptionsIn.max_canopyH    = 3;
defaultOptionsIn.smooth_method  = [];
defaultOptionsIn.smooth_span    = 480;
defaultOptionsIn.smooth_omitnan = 'omitnan';
defaultOptionsIn.extrap         = 'extrap';

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
    if ~strcmpi(optionsIn.smooth_method,'filtfilt')
        % use smooth()
        if strcmpi(defaultOptionsIn.smooth_omitnan,'omitnan')
            % ignore NaNs
            canopy_height = smooth(canopy_height,optionsIn.smooth_span,optionsIn.smooth_method,'omitnan');
        else
            canopy_height = smooth(canopy_height,optionsIn.smooth_span,optionsIn.smooth_method);
        end
    else
        % use filtfilt()
        N = defaultOptionsIn.smooth_span;
        % start with an array of NaNs
        canopy_height_ff = nan(size(canopy_height));
        % run the filter on all notNan values
        notNan = ~isnan(canopy_height);
        indAll = (1:length(canopy_height))';
        canopy_height_ff(notNan)= filtfilt(ones(1,N)/N,1,canopy_height(notNan));
        % interpolate the NaN values      
        if isnumeric(optionsIn.extrap)
            % fix the start and the end of the canopy height to match the default height during *winter*
            % (this improves the trace edges where we usually miss a lot of data due to winter conditions)
            canopy_height_ff(1:optionsIn.smooth_span)       = optionsIn.extrap;
            canopy_height_ff(end-optionsIn.smooth_span+1:end) = optionsIn.extrap;
        end
        canopy_height = interp1(indAll(notNan),canopy_height_ff(notNan),indAll,'linear',optionsIn.extrap);
    end

end
