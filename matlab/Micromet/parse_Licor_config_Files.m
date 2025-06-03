function [structCal,nFiles] = parse_Licor_config_Files(folderIn,processSubFolders) 
%  outStruct = parse_Licor_config(strIn)
% 
% Outputs:
%   structCal               - Structure with the information from all processed config files
%   nFiles                  - The number of files that were found.
% Inputs:
%   folderIn                -  folder containing Licor configuration files
%   processSubFolders       -  false (default): process only files in folderIn
%                              true:            process files in folderIn and all subfolders
%                          
%
% (c) Zoran Nesic                   File created:       Jun  2, 2025
%                                   Last modification:  Jun  2, 2025
%

% Revisions (last one first):
%

arg_default('processSubFolders','false')

if processSubFolders
    allFiles = dir(fullfile(folderIn,'**','*.l7x'));
else
    allFiles = dir(fullfile(folderIn,'*.l7x'));
end
structCal = [];
nFiles = length(allFiles);
for cntFile = 1:nFiles
    fileName = fullfile(allFiles(cntFile).folder,allFiles(cntFile).name);
    fid = fopen(fileName);
    strIn = fgetl(fid);
    fclose(fid);
    [structOutTemp,structCalTemp] = parse_Licor_config_str(strIn);
    if ~isempty(structOutTemp)
        if ~isempty(structCalTemp.SN)
            SN = ['SN' replace(structCalTemp.SN,'-','')];
            structCal.(SN).SN = structCalTemp.SN;
            if isfield(structCal.(SN),'CO2')
                cntItems = length(structCal.(SN).CO2.Zero.Val)+1;
            else
                cntItems = 1;
            end
            structCal.(SN).CO2.Zero.Datetime(cntItems) = structCalTemp.CO2.Zero.Datetime;
            structCal.(SN).CO2.Zero.Val(cntItems)      = structCalTemp.CO2.Zero.Val;
            structCal.(SN).CO2.Span.Datetime(cntItems) = structCalTemp.CO2.Span.Datetime;
            structCal.(SN).CO2.Span.Val(cntItems)      = structCalTemp.CO2.Span.Val;
            structCal.(SN).CO2.Span.Target(cntItems)   = structCalTemp.CO2.Span.Target;

            structCal.(SN).H2O.Zero.Datetime(cntItems) = structCalTemp.H2O.Zero.Datetime;
            structCal.(SN).H2O.Zero.Val(cntItems)      = structCalTemp.H2O.Zero.Val;            
            structCal.(SN).H2O.Span.Datetime(cntItems) = structCalTemp.H2O.Span.Datetime;
            structCal.(SN).H2O.Span.Val(cntItems)      = structCalTemp.H2O.Span.Val;
            structCal.(SN).H2O.Span.Target(cntItems)   = structCalTemp.H2O.Span.Target;
        end
    end
end
