function [x, tv] = get_stats_field_fast(Stats,fieldIn)
%   get_stats_field_fast
%   Function to loop through Stats structure to retrieve data (x) from specified fields.  
%
%   For tv (timevector) to be output correctly, Stats must have the field, "Stats.TimeVector".  
%   Note field names are case sensitive.
%
%   Example:  [x, tv] = get_stats_field_fast(Stats,'MainEddy.Three_Rotations.AvgDtr.Fluxes.Hs');
%
%
% Zoran Nesic               File created:              2023
%                           Last modification: Nov 15, 2026


% Revisions:
%
% Nov 25, 2026 (Zoran)
%   - bug fix: the function used to report an error if any of the elements
%     of field were missing in one of Stats(i). Now it just sets the
%     missing element to NaN
% Jan 18, 2024 (Zoran)
%   - bug fixes
%  Nov 16, 2023 (Zoran)
%   - wrote a new function based on get_stats_field. Working on making it
%     fully compatible with the original and faster.

err_flag = 1;
x  = [];
tv = [];

% Split fieldIn and pre-process matDim and mainField
% fieldIn = 'Instrument(1).Cov(1,3)' =>  fieldParts ={'Instrument(1)','Cov(1,3)'} 
% prt(1).currentPart = 'Instrument';    prt(1).matDim = 1
% prt(2).currentPart = 'Cov';           prt(2).matDim = [1 3]
fieldParts = split(fieldIn,'.');
for cntParts = 1:length(fieldParts)
    prt(cntParts).currentPart = char(fieldParts(cntParts)); 
    [prt(cntParts).matDim,prt(cntParts).mainField] = getArrayDimensions(prt(cntParts).currentPart);  
end

for cntStats = 1:length(Stats)
    % For each element of Stats
    try
        newStats = Stats(cntStats);
        for cntParts = 1:length(fieldParts)
            if ~isempty(newStats)
                currentPart = prt(cntParts).currentPart; 
                matDim      = prt(cntParts).matDim;
                mainField   = prt(cntParts).mainField;
               % dig through Stats one level at the time
               % until the newStats = the final number
               % newStats = Cov(1,3)
               if ~isempty(matDim)
                   try                    
                       newStats = newStats.(mainField);
                   catch
                       newStats = NaN;
                       % fprintf('Field "%s" does not exist in the structure. (Input field: "%s")\n',mainField,fieldIn);
                       % return
                   end               
                   if isscalar(matDim)
                        newStats = newStats(matDim);
                   elseif length(matDim) == 2
                        newStats = newStats(matDim(1),matDim(2));
                   else
                       fprintf('get_stats_field_Fast: Matrix can be only N x 1 or N x M\n');
                       return
                   end
               else 
                   try                    
                       newStats = newStats.(currentPart);
                   catch ME
                       newStats = NaN;
                       % fprintf('Field "%s" does not exist in the structure. (Input field: "%s")\n',currentPart,fieldIn);
                       % return
                   end               
               end
            end
        end
        if isempty(newStats)
            newStats = NaN;
        end
        %------------------------------------------------
        % This part of code could be just 
        % some legacy mess but I didn't have time to
        % fully troubleshoot it and to see what the possible
        % consenquencies of removing it could be. So it stays as is.
        % Zoran 20231116
        if length(size(newStats)) > 2
            newStats = squeeze(newStats);
        else         
            [m,n] = size(newStats); 
            if m ~= 1 
                newStats = newStats';
            end
            [m1, n1] = size(x); %check current size of x
            if n1 < n & n1 ~= 0          %#ok<*AND2> %if new data to add is more
                old_x = x;
                x = NaN.*ones(length(x),n);
                x(size(old_x)) = old_x;
            end

            % if all data sor far has been nan, blow it up.
            if length(find(isnan(x))) == m1*n1
                x = NaN .* ones(m1,m);
            end       
            %-----------------------------------------------
        end
        x(cntStats,1:size(newStats,2)) = newStats;       
        err_flag = 0;
    catch %#ok<*CTCH>
        x(cntStats,:) = NaN; 
    end
    try
        %eval(['tv(i,:) = Stats(i).TimeVector;']);
        tv(cntStats,:) = Stats(cntStats).TimeVector; %#ok<*AGROW>
    catch
        tv(cntStats) = NaN; 
    end
 end
 
 if err_flag
    disp(['Could not read ' fieldIn]);
 end

% Check if fieldParts is an array, a matrix or a variable
% examples:
%  fieldPart = 'TimeVector'         =>  matDim=[], mainField = 'TimeVector'
%  fieldPart = 'Instrument(1)'      =>  matDim = [1], mainField = 'Instrument'
%  fieldPart = 'cov(1,3)'           =>  matDim = [1 3], mainField = 'cov'
function [matDim,mainField] = getArrayDimensions(fieldPart)
    % find if this is a matrix by searching for ()
    lastFieldPart = char(fieldPart);
    indBrc1 = strfind(lastFieldPart,'(');
    matDim = [];
    mainField = [];
    if ~isempty(indBrc1)
        indBrc2 = strfind(lastFieldPart,')');
        if ~isempty(indBrc2)
            tmpStr = lastFieldPart(indBrc1(1)+1:indBrc2(1)-1);
            tmpStr = split(tmpStr);
            matDim = str2num(cell2mat(split(tmpStr))); %#ok<ST2NM>
        end
        mainField = lastFieldPart(1:indBrc1(1)-1);        
    end