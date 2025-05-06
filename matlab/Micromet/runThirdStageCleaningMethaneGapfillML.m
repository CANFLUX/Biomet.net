function fidLog = runThirdStageCleaningMethaneGapfillML(yearIn,siteID);
% runThirdStageCleaningMethaneGapfillML(yearIn,siteID)
%
% This function invokes Micromet third-stage cleaning Python pipeline.
% Usually, it's called by fr_automated_cleaning()
%
% Arguments
%   yearIn          - year to clean
%   siteID          - site ID as a char
    
    pythonPath = findBiometPythonPath;
    scriptPath = fullfile(pythonPath, 'methaneGapfillML.py');
    databasePath = findDatabasePath;
    command = sprintf('python "%s" --site %s --year %s --db_path %s', ...
                      scriptPath, siteID, num2str(yearIn), databasePath);
    status = system(command, '-echo');
   
end
        
function biometPythonPath = findBiometPythonPath
    funA = which('read_bor');
    tstPattern = [filesep 'Biomet.net' filesep];
    indFirstFilesep=strfind(funA,tstPattern);
    biometPythonPath = fullfile(funA(1:indFirstFilesep-1), tstPattern, 'Python');
end

function databasePath = findDatabasePath
    databasePath = biomet_path('yyyy');
    indY = strfind(databasePath,'yyyy');
    databasePath = databasePath(1:indY-2); 
end