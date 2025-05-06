function f1 = save_bor(file_name, data_type, data, flagLen)
%******************************************************************************
% THIS MATLAB FUNCTION SAVES DATA FROM MATLAB INTO THE BOREAS DATABASE
%
%       function f1 = save_bor(file_name, data_type, data, flagLen);
%
%       file_name       the output file name
%       data_type       1 - for single precision numbers (default)
%                       2 - flag1
%                       3 - flag2 
%                       4 - date string (not supported)
%                       5 - time string (not supported)
%                       6 - integers
%                       7 - long integer
%                       8 - double precision numbers ( _tv files)
%
%       flagLen         length of the flag1 in bytes per raw 
%                       ( 10-channel data needs 2 bytes = 8 bits from the first byte 
%                         and 2 from the second byte)
%                       This parameter is required when flag data is loaded.
%       data            data to be saved
%       f1              the number of elements successfully written
%
%
%   Written by Zoran Nesic, July 24, 1995
%
%   Last Rev.:   Feb 15, 2024
%******************************************************************************

% Revisions:
%
%   Feb 15, 2024 (Zoran)
%       - removed some eval statements that were not needed.
%   Sep 10, 1998
%       -   added option 8 for saving of double precision numbers (Matlab time vectors)
%   Dec 28, 1997
%       -   modifications to make this program Matlab5.1 compatible
%           changed: data_type == [] to isempty(data_type)
%
%   Aug 9, 1995
%       -   ????

f1 = [];
if nargin < 3
    error 'Too few parameters'
elseif isempty(data_type)
    data_type = 1;
end

fid = fopen(file_name ,'w');
if fid == -1 
    error('*** Error! File: "%s" cannot be opened!\n',file_name);
else
    if data_type == 1
        f1 = fwrite(fid, data, 'float32');
    elseif data_type == 2
        if nargin < 4
            error 'Required parameter is missing!'
        elseif ~isstr(data)
            data = setstr(data);
            [m,n] = size(data);
            if m > n 
                data = data';
            end
            f1 = fwrite(fid, data, 'char');
        else
            [m,n] = size(data);
            if m > n 
                data = data';
            end
            f1 = fwrite(fid, data, 'char');
        end
    elseif data_type == 3
        if ~isstr(data)
            data = setstr(data);
            f1 = fwrite(fid, data, 'char');
        else
            f1 = fwrite(fid, data, 'char');
        end
    elseif data_type == 6
        f1 = fwrite(fid, data, 'int16');    
    elseif data_type == 7
        f1 = fwrite(fid, data, 'int32');
    elseif data_type == 8
        f1 = fwrite(fid, data, 'float64');
    else
        error 'Not supported data types';
    end
    fclose(fid);
end 
