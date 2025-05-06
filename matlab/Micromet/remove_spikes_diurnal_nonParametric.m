function [data_out,outlier_index,cutoff_upper, cutoff_lower] = ...
    remove_spikes_diurnal_nonParametric(data_in,tv_in,window,thresh,thresh_type)
%
%--------------------------------------------------------------------------
% Outlier detection using diurnal variation in the median +/- a multiple of 
%   the median absolute deviation using a moving window. Diurnal variation
%   is constructed by treating each half-hour of the day independently. 
%   Consequently, the moving window considers a particular half-hour across
%   multiple days (i.e. +/- 1/2 window size number of days).
%
%--------------------------------------------------------------------------

% Default arguments
arg_default('thresh',5);
% arg_default('thresh_type','movmedian');
arg_default('window',60);

% Extract hour and minute from time vector (assumes half-hourly data)
[~,~,~,hr,mn] = datevec(tv_in);
hhr = hr+mn/60; % Decimal hour
hhr = round(hhr.*2); % Numeric half hour of day (i.e. 1:48)
hhr(hhr==0) = 48;

% Values above or below cutoff are considered outliers
cutoff_upper = nan(size(data_in));
cutoff_lower = nan(size(data_in));

for i=1:48
    % Index of half-hours
    idx_hhr = hhr==i;

    % Get all data for a given half hour
    ydata = data_in(idx_hhr);

    % Generate upper and lower bounds for outliers
    q_mov_75 = movquant(ydata,0.75,window,1,'omitnan','truncate');
    q_mov_50 = movquant(ydata,0.50,window,1,'omitnan','truncate');
    q_mov_25 = movquant(ydata,0.25,window,1,'omitnan','truncate');
    
    % Add bounds to time series for outliers cutoff values
    cutoff_upper(idx_hhr) = q_mov_75 + thresh.*(q_mov_75-q_mov_50);
    cutoff_lower(idx_hhr) = q_mov_25 - thresh.*(q_mov_50-q_mov_25);
end

% Adjust cutoff for variables which are systematically zero at night
%--> Make adjustment dependent on magnitude of data being filtered. 
%--> Assumes contamination by noise is less than 25% of data set.
cutoff_thresh =  0.005 .* prctile(data_in,75);
idx_zeroDiff = (cutoff_upper-cutoff_lower)<1E-04;
cutoff_upper(cutoff_upper<cutoff_thresh & idx_zeroDiff) = cutoff_thresh;
cutoff_lower(cutoff_lower>-cutoff_thresh & idx_zeroDiff) = -cutoff_thresh;

% Smooth cutoffs
cutoff_lower = smoothdata(cutoff_lower,'rlowess',12);
cutoff_upper = smoothdata(cutoff_upper,'rlowess',12);

data_out = data_in;
data_out(data_out>cutoff_upper) = NaN;
data_out(data_out<cutoff_lower) = NaN;

outlier_index = data_in>cutoff_upper | data_in<cutoff_lower;