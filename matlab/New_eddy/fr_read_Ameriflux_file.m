function [EngUnits, Header,tv,outStruct] = fr_read_Ameriflux_file(fileName,assign_in,varName)
%  fr_read_Ameriflux_file - reads Ameriflux csv files
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
% (c) Zoran Nesic                   File created:       Mar  6, 2025
%                                   Last modification:  May 21, 2025
%

% Revisions (last one first):
%
% May 21, 2025 (Zoran)
%   - Added a check to differentiate between the two different Ameriflux file 
%     formats: with a header (downloaded files)
%     or without a header (files formatted for uploads)
%

    arg_default('assign_in',[]);
    arg_default('varName','outStruct');
    
    try
        % Test if the given fileName is an AmeriFlux downloaded file (it has a header 
        % starting with "#Site") or it's an upload version (no header)
        fid = fopen(fileName);
        if fid >2
            oneLine = fgetl(fid);
            fclose(fid);           
            if strfind(oneLine,"Site:")             
                VariableNamesLine = 3;
            else
                VariableNamesLine = 1;
            end
        else
            error('Cannot open file %s\n',fileName);
        end
        dateColumnNum = [2];
        timeInputFormat = {'uuuuMMddHHmm'};
        structType = 1;
        inputFileType = 'delimitedtext';
        modifyVarNames = 0;
        colToKeep = [3 Inf];
        rowsToRead = [];
        isTimeDuration =[];
        [EngUnits,Header,tv,outStruct] = fr_read_generic_data_file(fileName,assign_in,...
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
end

