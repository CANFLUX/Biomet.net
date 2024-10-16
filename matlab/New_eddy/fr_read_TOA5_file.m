function [EngUnits, Header,tv,outStruct] = fr_read_TOA5_file(fileName,assign_in,varName)
%  fr_read_TOA5_file - reads Campbell TOA5 files
% 
% Inputs:
%   fileName            - data file
%   assign_in           - 'caller', 'base' - assignes the data to the
%                         actual column header names (logger variables)
%                         ither in callers space or in the base space.
%                         If empty or 0 no
%                         assignments are made
%   varName             - Used with 'caller'. Sets the name of the structure
%                         for the output variables. If
%                         empty the default name will be 'LGR' (LGR.tv,
%                         LGR.CH4_ppm...)
%
%
% NOTE 1: The original file used until Oct 15, 2024 is saved as fr_read_TOA5_file_old.m
%         If some of the old scripts fail, try renaming all calls to fr_read_TOA5_file
%         to fr_read_TOA5_file_old.
%
%
% (c) Zoran Nesic                   File created:       Oct 15, 2024
%                                   Last modification:  Oct 15, 2024
%

% Revisions (last one first):
%

arg_default('assign_in',[]);
arg_default('varName','Stats');
arg_default('varName',[]);

try
    assignIn = [];
    dateColumnNum = 1;
    timeInputFormat = {[],'HH:mm:ss'};
    colToKeep = [5 Inf];
    structType = 1;
    inputFileType = 'delimitedtext';
    modifyVarNames = 0;
    VariableNamesLine = 2;
    rowsToRead = [];
    isTimeDuration =[];
    [EngUnits,Header,tv,outStruct] = fr_read_generic_data_file(fileName,assignIn,...
                     varName, dateColumnNum,timeInputFormat ,colToKeep,structType,inputFileType,modifyVarNames,VariableNamesLine,rowsToRead,isTimeDuration);
    if strcmpi(assign_in,'CALLER')
        assignin('caller',varName,outStruct);
    end
catch ME %#ok<CTCH>
    fprintf(2,'\nError reading file: %s. \n',fileName);
    fprintf(2,'%s\n',ME.message);
    fprintf(2,'Error on line: %d in %s\n\n',ME.stack(1).line,ME.stack(1).file);
    EngUnits = [];
    Header = [];
    tv = [];
end       
