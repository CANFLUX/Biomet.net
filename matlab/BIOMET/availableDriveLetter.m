function driveOption = availableDriveLetter

[~, res] = system('wmic logicaldisk get caption');

% Convert output to a string array, remove empty spaces
usedDrives = strtrim(string(splitlines(res)));
usedDrives = usedDrives(usedDrives ~= "" & ~contains(usedDrives, "Caption"));

% Check letters D through Z
allLetters = 'D':'Z';
availableLetters = [];

for i = 1:length(allLetters)
    if ~contains(usedDrives, [allLetters(i) ':'])
        availableLetters = [availableLetters, allLetters(i)];
    end
end

driveOption = char([availableLetters(end) ':']);