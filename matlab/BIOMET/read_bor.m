function y = read_bor(fileName,data_type, flagLen,yearIn,indOut,override_1999)
%******************************************************************************
% THIS MATLAB FUNCTION READS DATA FROM THE BOREAS DATABASE INTO MATLAB
%
%       function data = read_bor(data,data_type, flagLen,year,indOut)
%
%       fileName        the column file name representing the data you want
%       data_type       1 - for single precision numbers (default)
%                       2 - flag1
%                       3 - flag2 
%                       4 - date string
%                       5 - time string
%                       6 - integers
%                       7 - long integers (EDDY: num.of.lines)
%                       8 - double precision numbers ('_tv' files)
%
%       flagLen         length of the flag1 in bytes per raw 
%                       ( 10-channel data needs 2 bytes = 8 bits from the first byte 
%                         and 2 from the second byte)
%                       This parameter is required when flag data is loaded.
%       year            an optional parameter. Used to append multiple years to
%                       a single output. See read_bor_primar for usage examples
%       indOut          an optional parameter. Used to extract a data period without
%                       reading the entire file. See read_bor_primar for usage examples
%		  override_1999	When set to 0 the program assumes that 1996-1999 are all in one folder
%								(also default when flag not present). When set to 1 it is assumed that
%								the data of each of the years 1996-1999 is in a different folder.
%
%   Written by Peter Blanken, July 8, 1995
%
%   Last Rev.:   Mar 18, 2025
%******************************************************************************

%
% Revisions:
%
%   Mar 18, 2025 (Zoran)
%       - Bug fix: the special case handling of database setup for Biomet-UBC for year < 1999 had been
%         messing up the databases created for other groups that had data from before 1999.
%         Added a check if the siteID belongs to one of the legacy Biomet-UBC sites and, if not,
%         the program would treat every year the same way (override_1999 = 1). 
%       - replaced the obsolete findstr with strfind.
%       - replaced datevec(now) with yearIn = year(datetime)
%       - replaced obsolete setstr() with char()
%   Feb 15, 2024 (Zoran)
%       - profiled this function and improved a few bottlenecks.
%         Mainly added arg_default instead of individual testion
%       - updated some syntax
%   Sep 14, 2001
%       - fixed bug that prevented the function from using override_1999 = 1 option
%         Changed:
%           if ~exist('override_1999') | ~isempty(override_1999) 
%         to
%           if ~exist('override_1999') | isempty(override_1999) 
%   Nov 24, 2000
%        - added the override_1999 flag
%   Feb 8, 2000
%        - removed a bug in the if statement for data_type = 2 
%           (there were 2 ifs: "if if data_type...")
%   Jan 10, 2000
%       - added two optional input parameters: year and indOut.
%   May 11, 1998
%       -   added data_type=8, double precision numbers. This enables the program
%           to load timeVector files ("_tv")
%   Apr 7, 1998
%       -   changed type "char" to type "uchar" for data_type(s) 2 and 3
%

% Make sure that the input fileName has all file separators set correctly (Win: '\', Unix: '/')
fileName = fullfile(fileName);

% Create site path patterns for legacy sites. It will be used for special handling of years < 1999
% for the Biomet group's legacy sites (BS, PA, CR, UBC_TOTEM)
legacySites = {[filesep 'BS' filesep],[filesep 'PA' filesep],...
               [filesep 'JP' filesep],[filesep 'CR' filesep],...
               [filesep 'UBC_TOTEM' filesep]}; % These are sites that are handled differently for yyyy < 1999

if ~exist('data_type','var') || isempty(data_type)
    data_type = 1;
end

if contains(upper(fileName),legacySites)
    if ~exist('override_1999','var') || isempty(override_1999)
        override_1999 = 0;
    end
else
    % if this site is not one of the legacy sites override the special handling of 1999
    override_1999 = 1;
end

if ~exist('indOut','var') 
    indOut = [];
end

if  ~exist('yearIn','var')  || isempty(yearIn)  
    yearIn = year(datetime);
end

ind=strfind(lower(fileName),'yyyy');
if isempty(ind) & length(yearIn) > 1
    error 'Multiple years require a wildcard: yyyy!'
end

if ~isempty(indOut) 
    indSkip = indOut(1)-1;
else
    indSkip = 0;
end

if any(yearIn>=1996 & yearIn <=1999) && override_1999 == 0
	% if user has requested years 1996->1999
	% convert them all to 1999
   ind1 = find(yearIn>=1996 & yearIn <=1999);
   yearIn(ind1) = 1999; %#ok<FNDSB>
   % keep only one of 1999s
   yearIn = unique(yearIn);
end

y = [];
for i = 1:length(yearIn)    
        if ~isempty(ind) & isscalar(ind)            
            fileName(ind:ind+3) = num2str(yearIn(i));
        end
        fid = fopen(fileName);

        if fid == -1 
            error('*** Error! File: "%s" does not exist!\n',fileName);
        else
            if data_type == 1
                if i == 1 
                    fseek(fid,indSkip*4,'bof');
                end
                x = fread(fid,'float32');
            elseif data_type == 2
                if exist('flagLen','var')~= 1 | isempty(flagLen) 
                    error 'Required parameter is missing!'
                else
                    if i == 1 
                        fseek(fid,indSkip*flagLen,'bof');
                    end
                    x = fread(fid,[ flagLen Inf ],'uchar' )';
                end
            elseif data_type == 3
                if i == 1 
                    fseek(fid,indSkip*10,'bof');
                end
                x = fread(fid,[ 10 Inf ],'uchar')';        
            elseif data_type == 4
                if i == 1 
                    fseek(fid,indSkip*10,'bof');
                end
                x = char( fread(fid,[ 10 Inf ],'char')' );
            elseif data_type == 5
                if i == 1 
                    fseek(fid,indSkip*8,'bof');
                end
                x = char( fread(fid,[ 8 Inf ],'char')' );
            elseif data_type == 6
                if i == 1 
                    fseek(fid,indSkip*2,'bof');
                end
                x = fread(fid,'int16');
            elseif data_type == 7
                if i == 1 
                    fseek(fid,indSkip*4,'bof');
                end
                x = fread(fid,'int32');
            elseif data_type == 8
                if i == 1 
                    fseek(fid,indSkip*8,'bof');
                end
                x = fread(fid,'float64');
            else
                x = [];
            end
            fclose(fid);
        end 
        y = [y ;x ]; %#ok<AGROW>
end
if ~isempty(indOut) 
    y = y(indOut-indOut(1)+1);
end
