function [StatsAll,dbFileNames, dbFieldNames] = db_save_struct(StatsAll,pthOut,verbose_flag,excludeSubStructures,timeUnit,missingPointValue)
%
% eg. db_save_struct(StatsAll,'\\annex001\database\yyyy\cr\flux\');
%
%   This function updates Biomet data base for the input given in StatsAll.
%   StatsAll structure has to have field TimeVector
%   
% Inputs:
%       StatsAll             -  input data structure
%       pthOut               -   data base location for the output data
%       verbose_flag         - 1 -ON, otherwise OFF
%       excludeSubStructures - cell array or a string with names or a name
%                               of the substructure within Stats or HHour that should not be
%                               processed.  Setting excludeSubStructures to 'DataHF' will remove
%                               the high frequency data from the ACS data set.
%       timeUnit             - minutes in the sample period (spacing between two
%                               consecutive data points. Default 30 (hhour)
% Outputs:
%       k                    - number of files processed
%
% (c) Zoran Nesic               File created:       Apr  3, 2022
%                               Last modification:  Jan 23, 2025

% Revisions:
%
%   Jan 23, 2025 (Zoran)
%       - made check_or_create_path() OS independent and streamlined.
%   Jan 21, 2025 (Rosie)
%       - edited the function so it works on Mac as
%       well as windows (added pthOut = fullfile(pthOut) to make sure that proper 
%       folder separator is used).
%   Jul 27, 2022 (Zoran)
%       - changed Clean_tv into clean_tv
%   Apr 3, 2022 (Zoran)
%       - function based on less generic db_new_eddy
%       - removed all the legacy stuff and cleaned up the syntax 
%

arg_default('verbose_flag',1);              % default 1 (ON)
arg_default('excludeSubStructures',[]);     % default exclude none
arg_default('timeUnit',30);                 % default is 30 minutes
arg_default('missingPointValue',0);         % default is 0 (legacy Biomet value). Newer setups should use NaN

% Make sure that pthOut is OS independent (fix filesep issues):
pthOut = fullfile(pthOut);

% Output path has to have "yyyy" in the string. That's where the year goes.
% Return if the path string is incorrect.
if ~contains(pthOut,'yyyy')
    fprintf('File path has to contain year place holder "yyyy". Aborting\n');
    return
end



% Remove any topmost fields that don't need to be converted to the data
% base format:
if ~isempty(excludeSubStructures)
    StatsAll = rmfield(StatsAll,excludeSubStructures);
end

%
% extract the time vector and index it to the current year
%
tic;
tv = fr_round_time(get_stats_field(StatsAll,'TimeVector'),'min',1); % round to the nearest minute
%
% Keep only tv that are numbers
% (added Feb 11, 2008)
ind_finite = find(isfinite(tv));
StatsAll = StatsAll(ind_finite);
tv = tv(ind_finite);
%
% Remove all tv==0 values
ind_not_zeros = find(tv~=0);
StatsAll = StatsAll(ind_not_zeros);
tv = tv(ind_not_zeros);

% Make sure there are no duplicate entries.
[tv,IA]=unique(tv);
StatsAll = StatsAll(IA);

% Sort the time vector (there is no guarantee that the files will be 
% loaded in any particular order so we have to assume that the dates
% are mixed up.
[tv,ind] = sort(tv);
% sort the entire structure accordingly
StatsAll = StatsAll(ind);

% At this point the data could be part of multiple years. 
% Process each year separatelly
[years,~,~] = datevec(tv);
years = unique(years);          
yearRange = years(1)-1:years(end)+1;   % make sure you don't miss some data (add one year before and after) 

for currentYear = yearRange
    % get the index of all points in tv that belong to the year currentYear
    indCurrentYear = find(tv >= datenum(currentYear,1,1,0,timeUnit,0) ...
             & tv <= datenum(currentYear+1,1,1,0,0,0));  %#ok<*EFIND>
    % if there is any data that belongs to current year process it
    % otherwise skip
    if ~isempty(indCurrentYear)
        % Extract StatsAll that belong to the current year
        currentYearStatsAll = StatsAll(indCurrentYear); %#ok<*FNDSB>
        % create a time vector for the year (all half hours)
        % and find where the data belongs
        nDays = datenum(currentYear+1,1,1) - datenum(currentYear,1,1);
        fullYearTv = datenum(currentYear,1,1,0,timeUnit:timeUnit:nDays*24*60,0)';
        if timeUnit == 30
            [~,indTv] = intersect(fr_round_time(fullYearTv,'30min',1),fr_round_time(tv,'30min',1));
            % intersect(fr_round_hhour(fullYearTv),fr_round_hhour(tv));
        else
            % assume that timeUnit is in minutes (which is what it should be)
            [~,indTv] = intersect(fr_round_time(fullYearTv,'min',1),fr_round_time(tv,'min',1));
        end
        %
        %--------------------------------------------------------------------------------
        % Start storing the variables, first analyze the ones we know are 
        % always there, then go for the generic names
        %--------------------------------------------------------------------------------

        if length(currentYearStatsAll)>=2
            for l = 2:length(currentYearStatsAll) % Skip the first entry since it contains Configuration if data extracted from a flux file
                dum = currentYearStatsAll(l); %#ok<NASGU>
                s(l) = whos('dum'); %#ok<*AGROW>
            end
            [~,i_max] = max([s(:).bytes]);
            dbFileNamesTmp = recursiveStrucFieldNames(currentYearStatsAll,i_max+1);
        else % we have only one hhour to process
            dum = currentYearStatsAll(1); %#ok<NASGU>
            s(1) = whos('dum');
            %[dum,i_max] = max([s(:).bytes]);
            dbFileNamesTmp = recursiveStrucFieldNames(currentYearStatsAll,1);
        end

        nFiles = length(dbFileNamesTmp);
        dbFileNames = [];
        dbFieldNames = [];
        % Insert the current year into the output path. Check if the resulting
        % path exists. If not, create it.
        currentPthOut = pthOut;
        currentPthOut = regexprep(currentPthOut,'yyyy',sprintf('%4d',currentYear));
        currentPthOut = check_or_create_path(currentPthOut);
        % Create all output file names
        for i=1:nFiles
           % create file and field namesnames
           fieldName = char(dbFileNamesTmp(i));
           [fileNameX] = replaceControlCodes(fieldName);
           dbFileNames{i}=fullfile(currentPthOut,fileNameX);
           dbFieldNames{i} = fieldName;
        end
        % Save the data
        errCode = saveAll(currentYearStatsAll,dbFileNames,dbFieldNames,fullYearTv,indTv,missingPointValue);
        % report time
        tm = toc;
        if errCode ~= 0 
           fprintf('***  %d errors during processing. ***\n',errCode);
        end
    end
end

if verbose_flag,fprintf('%i database entries generated in %4.3f seconds.\n',([length(StatsAll) tm]));end


%===============================================================
%
% check_or_create_path
%
%===============================================================
function pthOut = check_or_create_path(pthOut)
    if ~exist(pthOut,'dir')
       fprintf(1,'Directory %s does not exist!... ',pthOut);
       fprintf(1,'Creating new folder!... ');
       [successFlag] = mkdir(pthOut);
       if successFlag
           fprintf(1,'New folder created!\n');
       else
           fprintf(1,'Error creating folder!\n');
           error('Error creating folder!');
       end
    end

%===============================================================
%
% Save all files
%
%===============================================================
function errCode = saveAll(Stats,fileNamesIn,fieldNamesIn,fullYearTv,indTv,missingPointValue)

errCode = 0;
for i=1:length(fileNamesIn)
   fileName = char(fileNamesIn(i));
   fieldName = char(fieldNamesIn(i));
   try
       dataIn = get_stats_field(Stats,fieldName);
       if ~isempty(dataIn)
          if ~exist(fileName,'file')
             % if the file doesn't exist  
             % create it (dbase initialization)
             % special handling of TimeVector (always store full year)
             % in double precision
             % Also create clean_tv == TimeVector to provide compatibility with
             % database reading programs (Zoran, June 19, 2005)
             if contains(fileName,'TimeVector')
                save_bor(fileName,8,fullYearTv);
                ind = strfind(fileName,'TimeVector');
                save_bor([fileName(1:ind-1) 'clean_tv'],8,fullYearTv);
             elseif contains(fileName,'RecalcTime')
                dataTemp = missingPointValue * zeros(size(fullYearTv));
                dataTemp(indTv) = dataIn;
                save_bor(fileName,8,dataTemp);
             else
                dataTemp = missingPointValue * zeros(size(fullYearTv));
                dataTemp(indTv) = dataIn;
                save_bor(fileName,1,dataTemp);                
             end
          else 
             % if file already exist just write the new data at the
             % proper spot
             if ~contains(fileName,'TimeVector')
                if contains(fileName,'RecalcTime')
                   jumpInd = 8;
                   formatX = 'float64';
                else
                   jumpInd = 4;
                   formatX = 'float32';
                end % findstr(fileName,'RecalcTime')
                fid = fopen(fileName,'rb+');
                if fid ~= -1
                    % First make sure the index has consecutive points only
                    if all(diff(indTv)== 1)
                        % if they are consecutive use the fast saving option
                        status = fseek(fid,jumpInd*(indTv(1)-1),'bof');
                        if status == 0
                            fwrite(fid,dataIn,formatX); 
                        else
                            disp('Error doing FSEEK')
                            errCode = errCode + 1;
                        end
                    else
                        % if not, use the slow way
                        for countIndTv = 1:length(indTv)
                           status = fseek(fid,jumpInd*(indTv(countIndTv)-1),'bof');
                           if status == 0
                                fwrite(fid,dataIn(countIndTv),formatX); 
                           else
                                disp('Error doing FSEEK')
                                errCode = errCode + 1;
                           end
                        end
                    end
                else
                   disp(['Error opening: ' fileName]);
                   errCode = errCode + 1;
                end
                fclose(fid);                
             end % ~findstr(fileName,'TimeVector')
          end % ~exist(fileName,'file')
       end % ~isempty(dataIn)
   catch
       disp(['Error while processing: ' fieldName]);
       errCode = errCode + 1;
   end %try
end % i=1:length(fileNamesIn)
%end % of function

%===============================================================
%
% replace control codes
%
%===============================================================

function [fileName] = replaceControlCodes(oldName)
% replace all the brackets and commas using the following table
% '('  -> '_'
% ','  -> '_'
% ')'  -> []
ind = find(oldName == '(' | oldName == ',');
oldName(ind) = '_';
ind = find(oldName == ')');
oldName(ind) = [];
fileName = oldName;
%end % of function


%===============================================================
%
% Recursive structure field name search
%
%===============================================================

function dbFileNames = recursiveStrucFieldNames(StatsAll,n_template)
arg_default('n_template',1);
dbFileNames = [];
nFiles = 0;
statsFieldNames = fieldnames(StatsAll);
for i = 1:length(statsFieldNames)
   fName = char(statsFieldNames(i));
   % load the first element of StatsAll to 
   % examine the structure type
   fieldTmp = getfield(StatsAll,{n_template},fName);
   % skip fields 'Configuration', 'Spectra' and all character and cell fields
   if ~strcmp(fName,'Configuration') & ~ischar(fieldTmp) & ~iscell(fieldTmp) & ~strcmp(fName,'Spectra') %#ok<*AND2>
      % is it a vector or not
      nLen = length(fieldTmp);
      if nLen > 1
         [nCol, nRow] = size(fieldTmp);
         for j = 1:nCol
            for j1 = 1:nRow
               nFiles = nFiles + 1;
               if nCol == 1 | nRow == 1 
                  % if it's a one dimensional vector use only one index
                  jj = max(j,j1);
                  dbFileNames{nFiles} = [fName '(' num2str(jj) ')' ];
               else
                  % for two dimensional vectors use two 
                  dbFileNames{nFiles} = [fName '(' num2str(j) ',' num2str(j1) ')' ];
               end % if nCol == 1 or nRow == 1 
               % test if it's a structure and do a recursive call
               if isstruct(fieldTmp)
                  %-------------------------
                  % recursive call goes here
                  %-------------------------
                  %                    fieldI = get_stats_field(StatsAll,fName);
                  if nCol == 1 | nRow == 1  %#ok<*OR2>
                     % if it's a one dimensional vector use only one index
                     jj = max(j,j1);
                     dbFileNamesTmp = recursiveStrucFieldNames(fieldTmp(jj));
                  else
                     % for two dimensional vectors use two 
                     dbFileNamesTmp = recursiveStrucFieldNames(fieldTmp(j,j1));
                  end % if nCol == 1 or nRow == 1 
                  
                  mFiles = length(dbFileNamesTmp);
                  dbFileNamesBase = char(dbFileNames{nFiles});
                  % move the pointer back to overwrite the last entry
                  nFiles = nFiles - 1;                            
                  for k=1:mFiles
                     nFiles = nFiles + 1;
                     dbFileNames{nFiles}=[dbFileNamesBase '.' char(dbFileNamesTmp(k))];
                  end % i=1:nFiles
               end % if isstruc(fieldTmp)
            end % for j1=1:nRow
         end % j = 1:nCol
      else
         % save new file name
         nFiles = nFiles + 1;
         dbFileNames{nFiles} = fName;
         % test if it's a structure and do a recursive call
         if isstruct(fieldTmp)
            %-------------------------
            % recursive call goes here
            %-------------------------
            %                    fieldI = get_stats_field(StatsAll,fName);
            dbFileNamesTmp = recursiveStrucFieldNames(fieldTmp);
            mFiles = length(dbFileNamesTmp);
            dbFileNamesBase = char(dbFileNames{nFiles});
            % back out the index by one (over-write the last fName entry)
            nFiles = nFiles - 1;
            for k=1:mFiles
               nFiles = nFiles + 1;
               dbFileNames{nFiles}=[dbFileNamesBase '.' char(dbFileNamesTmp(k))];
            end % i=1:nFiles
         end % if isstruc(fieldTmp)
      end % nLen > 1
   end % fName ~= 'Configuration'
end % for i = 

