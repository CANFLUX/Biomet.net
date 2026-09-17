function driveOption = availableDriveLetter

% [~, res] = system('wmic logicaldisk get caption');
% Checks what physical and virtual drive letters are in use. The old 'wmic'
%   command is no longer available in Windows 11. 'fsutil' is backwards
%   compatible to Windows 2000. (P. Moore - 2026-09-11)
[flag,fsutil_output]=system('fsutil fsinfo drives');

if flag==0
    % Convert output to a string array, remove empty spaces
    tmp = strtrim(string(splitlines(fsutil_output)));
    tmp = tmp(tmp ~= "");
    tmp = split(tmp,' ');
    usedDrives = tmp(~contains(tmp, "Drives:"));
    
    % Check letters C through Z
    allLetters = 'C':'Z';
    availableLetters = [];
    
    for i = 1:length(allLetters)
        if ~any(contains(usedDrives, [allLetters(i) ':']))
            availableLetters = [availableLetters, allLetters(i)];
        end
    end
    
    driveOption = char([availableLetters(end) ':']);
else
    disp(fsutil_output)
end