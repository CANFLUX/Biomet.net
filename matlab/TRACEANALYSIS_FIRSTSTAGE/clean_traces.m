function data_out = clean_traces(trace_str,interp_flag)
% This function provides optional cleaning procedures to a single trace structure,
% or an array of structures.
% An extra field called stats is created for each trace.
% This field contains various statistics about the cleaning procedures.
%
% Input:			
%   trace_str:		Either one single trace, or an array of structures.
%
% Output:		
%   data_out:		Either one single cleaned trace, or an array of trace
%					structures.

% Revisions:
%
% Apr 8, 2024 (Zoran)
%  - fixed a bug where the function didn't test if a field was empty before trying to 
%    access it as an array. It affected "clampedMinMax".
% Apr 5, 2024 (Zoran)
%  - edited header by removing old definitions of Input:
%  - Improved handling of the current year future dates
%    (replacing any points beyond the current date with NaNs)
%    so it now uses datetime.
%
% Nov 25, 2022 (Zoran)
%  - The previous fix, caused an unintended issue where the
%    clean_flags, after initially being set based on zeroPt 
%    would be overwritten by this line in MinMax cleaning:
%       clean_flags = ta_set_ind(indmin,indmax,'union')
%    Hence, the zeroPt cleaning would be applied to the current trace but
%    not to its dependents.
%    I split the line above into two to keep track of the removed zeroPt-s:
%           clean_flags = ta_set_ind(clean_flags,indmax,'union')
%           clean_flags = ta_set_ind(clean_flags,indmin,'union')
%  - Extracted the index of NaNs that are present in the original trace.
%    Previously, the function would've ignored those points because they
%    had been alread "clean". But that had consenquences on the dependent traces.
%    Without saving the index of the existing NaNs the cleaning based on 'dependent'
%    option would not touch those points in the dependent traces.
%  - Saved the index of NaNs (.stats.index.indexPtsNaN)
% Aug 30, 2022 (Zoran)
%   - move zeroPt filtering before calibrations so that the data
%     can be cleaned from -9999s and such before being calibrated
%
% Apr 22, 2020 (Zoran)
%      - Syntax cleanup while upgrading to Matlab 2020.
%        - commented out waitbar statements that are not compatible
%        anymore.
% Aug 18/2010 (Nick) 
%       -changed indtimeBefore test to look for non_NaN data-- precip traces can
%        have zeroes and be current!

if(nargin<1)
   error('not enough arguments');
end
if ~exist('interp_flag','var')
   % kai*, Nov 21, 2001
   % Disabled the interpolation
   interp_flag ='no_interp';
   % end kai*
end

%If trace_str is a single trace(has ini field),then call the helper function directly.
%If trace_str is a structure of traces, call helper function sequentially with each
%trace variable inside the structure.
%if isfield(trace_str,'ini')
if length(trace_str) == 1
   data_out = clean_one_trace(trace_str,interp_flag);
else
   
   bgc = [0 0.36 0.532];
   disp('Automated cleaning ....');
   h = waitbar(0,'Automated cleaning ....');
   set(h,'Color',bgc);
   set(get(h,'Children'),'Color',bgc,'LineWidth',0.5);
   set(get(get(h,'Children'),'Title'),'Color',[1 1 1])
%    h1 = get(get(h,'Children'),'Children');
%    set(h1(1),'Color',[1 1 1]);
   ct = length(trace_str);
   data_out = trace_str;
   for i=1:ct
      data_out(i) = clean_one_trace(trace_str(i),interp_flag);		%used for cleaning an array of traces
      waitbar(i/ct);         
   end
   
   if ishandle(h)
      close(h);
   end
   
end


%Internal helper funtion to clean each trace.
function trace_out = clean_one_trace(trace_in,interp_flag)
%this function cleans a single trace,keeps track of statistics, and returns the cleaned
%trace structure.
indexInterpPts = [];						%variables used for cleaning statistics
indexPtsNotCleaned = []; %#ok<NASGU>
indexPtsDespiked = [];
indexPtsClampedMax = [];
indexPtsClampedMin = [];
indexPtsZero = [];
indexDependClean = [];
indmin = [];
indmax = [];
indtime = [];

numPtsCleaned = 0;					
numPtsNotCleaned = 0; %#ok<NASGU>
numPtsDespiked = 0;
numPtsZero = 0;
numDependClean = 0;
OutsideMin = 0;
OutsideMax = 0;

clean_flags = [];

%Replace any points beyond the current date with NaNs:
if isfield(trace_in, 'Year') & trace_in.Year == year(datetime) %#ok<*AND2>
   curr_day = day(datetime,"dayofyear");
   indtimeAfter = find(trace_in.DOY >= curr_day);
  
  %*********************************************************************
  % Aug 18/2010: changed indtimeBefore test to look for non NaN data-- 
  % instead of non-zero data; precip traces can have zeroes and be current!
  % indtimeBefore = find(trace_in.DOY < curr_day & trace_in.data ~= 0);
   indtimeBefore = find(trace_in.DOY < curr_day &  ~isnan(trace_in.data));
  %*******************************************************************
   
   % kai*  07.09.00
   % Before, this read
   %  indtime = [indtimeBefore(end)+2:indtimeAfter(end)];  
   %  trace_in.data(indtime) = NaN;  
   % If all values in data are 0 => indtimeBefore = [] and indtime cannot
   % be assigned. Therefore, drop the second condition in this case in this case
   if isempty(indtimeBefore)
      indtimeBefore = find(trace_in.DOY < curr_day);
   end
   % If timeser is only part of the year indtimeAfter might be empty
   if ~isempty(indtimeAfter) 
      indtime = indtimeBefore(end)+2:indtimeAfter(end);  
      trace_in.data(indtime) = NaN;  
   end
   % end kai*
end

%Remove impossible data points from each trace (either = to 0.000 or set in ini file)
if isfield(trace_in.ini,'zeroPt')
    if ~isempty(trace_in.ini.zeroPt)      
        indexPtsZero = find(trace_in.data == trace_in.ini.zeroPt);
        numPtsZero = length(indexPtsZero);  
        trace_in.data(indexPtsZero) = NaN;
        clean_flags = ta_set_ind(clean_flags,indexPtsZero,'union');	%used when dependent traces need to be cleaned
    end
else
   indexPtsZero = find(trace_in.data == 0);%default that no points can be exactly 0
   numPtsZero = length(indexPtsZero);  
   trace_in.data(indexPtsZero) = NaN;
   clean_flags = ta_set_ind(clean_flags,indexPtsZero,'union');	%used when dependent traces need to be cleaned
end


%If necessary, remove programmed coefficients and apply true calibration coefficients
%to trace 
if isfield(trace_in.ini,'currentCalibration')
   if ~isempty(trace_in.ini.currentCalibration)
      if ~isa(trace_in.ini.loggedCalibration,'double')
         loggedCalibration = eval(trace_in.ini.loggedCalibration);
      else
         loggedCalibration = trace_in.ini.loggedCalibration;
      end
      if ~isa(trace_in.ini.currentCalibration,'double')
         currentCalibration = eval(trace_in.ini.currentCalibration);
      else
         currentCalibration = trace_in.ini.currentCalibration;
      end
      for i = 1:size(loggedCalibration,1)
         ind = find( trace_in.timeVector >= loggedCalibration(i,3) & ...
            trace_in.timeVector < loggedCalibration(i,4));
         trace_in.data(ind) = (trace_in.data(ind) - ...
            loggedCalibration(i,2))./...
            loggedCalibration(i,1);
      end
      for i = 1:size(currentCalibration,1)
         ind = find( trace_in.timeVector >= currentCalibration(i,3) & ...
            trace_in.timeVector < currentCalibration(i,4));
         trace_in.data(ind) = trace_in.data(ind).*...
            currentCalibration(i,1) +...
            currentCalibration(i,2);
      end
   end
end

%If necessary, apply a half hourly calibration to trace 
if isfield(trace_in.ini,'hhourCalibration')
   try
      % The only case where is feature is used is this in the cr firststage
      % file:
      % hhourCalibration = {'\\annex001\database\1999\CR\flux\clean\Tbench_correction_irga1'}
      [temp_data,timeVector] = read_db(trace_in.Year,trace_in.SiteID,...
        'flux\clean','Tbench_correction_irga1'); %#ok<*ASGLU>
      % hhourcal = read_bor(char(trace_in.ini.hhourCalibration),[],[],trace_in.Year,[]);       
      trace_in.data = (trace_in.data.*hhourcal);
    catch ME
        disp (ME.message);
        disp(ME.stack(1));
   end    
end

%Replace points outside limits indicated in the ini_file with NaN's.
if isfield(trace_in.ini,'minMax') && ~isempty(trace_in.ini.minMax)
   indmin = find(trace_in.data < trace_in.ini.minMax(1));
   OutsideMin = length(indmin);  
   indmax = find(trace_in.data > trace_in.ini.minMax(2));
   OutsideMax= length(indmax);
   trace_in.data(indmin) = NaN;
   trace_in.data(indmax) = NaN; 
   clean_flags = ta_set_ind(clean_flags,indmax,'union');
   clean_flags = ta_set_ind(clean_flags,indmin,'union');   
end

%Replace points that are not NaNs, and fall outside the clamped parameters, with
%the clamped values:
if isfield(trace_in.ini,'clamped_minMax') && ~isempty(trace_in.ini.clamped_minMax)
   clm_indmin = find(trace_in.data < trace_in.ini.clamped_minMax(1));
   clm_indmax = find(trace_in.data > trace_in.ini.clamped_minMax(2));
   trace_in.data(clm_indmin) = trace_in.ini.clamped_minMax(1);
   trace_in.data(clm_indmax) = trace_in.ini.clamped_minMax(2);
   indexPtsClampedMax = clm_indmax;
   indexPtsClampedMin = clm_indmin; 
end


% Find the points that are NaNs and keep their index
% Those need to be removed from the dependent traces   (Added Nov 25, 2022)
indexPtsNaN = find(isnan(trace_in.data));
clean_flags = ta_set_ind(clean_flags,indexPtsNaN,'union');	%used when dependent traces need to be cleaned

%Use the single point despiking routine to interpolate the data.
if isfield(trace_in.ini,'threshold_const')
   temp_noNan = find(~isnan(trace_in.data));
   [y,j,indx]= rn_fr_despike(trace_in.data(temp_noNan),1,0,trace_in.ini.threshold_const);
   indexPtsDespiked = temp_noNan(indx);
   trace_in.data(indexPtsDespiked) = NaN;
   numPtsDespiked = length(indexPtsDespiked);   
   clean_flags = ta_set_ind(clean_flags,indexPtsDespiked,'union');
end

%Use running mean and std to replace spikes with NaNs.
if isfield(trace_in.ini,'runningFilter')
   filt_len = trace_in.ini.runningFilter(:,1);			%values located in the ini_file
   num_std = trace_in.ini.runningFilter(:,2);
   filt_opt = trace_in.ini.runningFilter(:,3);
   num_rep = length(num_std);
   trace_in = calc_runMeanStd(trace_in,filt_len,num_std,filt_opt,num_rep);
   clean_flags = ta_set_ind(clean_flags,trace_in.runFilter_stats.ind_filtered,'union');   
end

%This field lists all the indices of points removed while cleaning dependent traces:
if isfield(trace_in,'stats') & isfield(trace_in.stats,'index') &...
      isfield(trace_in.stats.index,'PtsDependClean') & ...
      ~isempty(trace_in.stats.index.PtsDependClean)
   indexDependClean = ta_set_ind(trace_in.stats.index.PtsDependClean,clean_flags,'diff');   
   trace_in.data(indexDependClean) = NaN;
   numDependClean = length(indexDependClean);   
end

if ~strcmp(interp_flag,'no_interp')
   %Interpolate over the missing data points:
   indNan = find(isnan(trace_in.data)); %#ok<*EFIND>
   if ~isempty(indNan)   
      if ~isfield(trace_in.ini,'interpLength') | isempty(trace_in.ini.interpLength) %#ok<*OR2>
         %interpolate using the default value of interpolation length=1:      
         [data_out,index] = ta_interp_points(trace_in.data,1);
         trace_in.data = data_out;  
      else
         %If 'interpLength' is set in the ini_file, then use it to interpolate over
         %the indicated length of sequences of NaNs:
         try
            interp_err = 0;
            [data_out,index] = ta_interp_points(trace_in.data,trace_in.ini.interpLength);
         catch
            interp_err = 1;
            disp(['Warning: could not interpolate the trace: ' trace_in.variableName '!'])         
         end
         if interp_err == 0
            trace_in.data = data_out;
         end      
      end   
      %Update all the statistics information:     
      indexInterpPts = index;   							%interpolation indices
      indexPtsNotCleaned = find(isnan(trace_in.data));		%indices of remaining NaNs
      numPtsCleaned = length(indexInterpPts);				%length of interpolated
      numPtsNotCleaned = length(indexPtsNotCleaned);     	%length of NaNs
   end
end
indexPtsClampedMax = ta_set_ind(indexPtsClampedMax,clean_flags,'diff');
indexPtsClampedMin = ta_set_ind(indexPtsClampedMin,clean_flags,'diff');
indexPtsClampedMax = ta_set_ind(indexPtsClampedMax,indexDependClean,'diff');
indexPtsClampedMin = ta_set_ind(indexPtsClampedMin,indexDependClean,'diff');

%Update trace structure with statistics.
trace_in.stats.numpts.Interpolated = numPtsCleaned;
trace_in.stats.numpts.outsideMin = OutsideMin;
trace_in.stats.numpts.outsideMax = OutsideMax;
trace_in.stats.numpts.despiked = numPtsDespiked;
trace_in.stats.numpts.clampedMin = length(indexPtsClampedMin);
trace_in.stats.numpts.clampedMax = length(indexPtsClampedMax);
trace_in.stats.numpts.zeroPt = numPtsZero;
trace_in.stats.numpts.dependCleaned = numDependClean;
trace_in.stats.numpts.pastCurrentDate = length(indtime);
if isempty(indexInterpPts)
   trace_in.stats.index.PtsInterpolated = [];
else
   trace_in.stats.index.PtsInterpolated = indexInterpPts;
end

trace_in.stats.index.indexPtsNaN = indexPtsNaN;
trace_in.stats.index.PtsOutsideMin = indmin;
trace_in.stats.index.PtsOutsideMax = indmax;
trace_in.stats.index.PtsDespiked = indexPtsDespiked;
trace_in.stats.index.PtsClampedMin = indexPtsClampedMin;
trace_in.stats.index.PtsClampedMax = indexPtsClampedMax;
trace_in.stats.index.PtsZero = indexPtsZero;
trace_in.stats.index.PtsDependClean = indexDependClean;
trace_in.stats.index.PtsPastCurrentDate = indtime;
if isfield(trace_in,'runFilter_stats') & ~isempty(trace_in.runFilter_stats)
   trace_in.stats.index.PtsFiltered = trace_in.runFilter_stats.ind_filtered;
   env_temp = sum(trace_in.runFilter_stats.pts_per_envelope);
   trace_in.stats.numpts.outsideFilter = env_temp;   
else
   trace_in.stats.index.PtsFiltered = [];
   trace_in.stats.numpts.outsideFilter = 0;
end
trace_in.stats.clean_flags = clean_flags;

%Return finished trace:
trace_out = trace_in;
