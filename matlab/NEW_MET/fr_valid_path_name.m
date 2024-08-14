function pth_out = fr_valid_path_name(pthIn)
%
%
% Check if this is valid path name. Return the path name plus an optional
% '\' at the end if path is OK, else return an empty matrix
%
% (c) Zoran Nesic       File created:       Feb 22, 1998
%				        Last modification:	Aug 11, 2024
%

%
% Revisions:
%
% Aug 11, 2024 (Zoran)
%   - made sure that pthIn is a char not a string. 
%   - minor syntax cleanup.
% July 26, 2023 (Zoran)
%   - replaced '\' with filesep for MacOS compatibility

% First make sure that the pthIn is a char not a string
pthIn = char(pthIn);

if pthIn(length(pthIn)) ~= filesep          % path name must end with a '\'
    pthIn = [pthIn filesep];
end

if exist(pthIn,'dir')                 % check if the path exists (must be a
    pth_out = pthIn;                  % directory not a file!)
else
    pth_out = [];
end 

