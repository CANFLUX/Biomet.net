function [EngUnits, Header,tv,outStruct] = fr_read_Hydrology_file(fileName,assign_in,varName,flag30min)
%  fr_read_Hydrology_file - reads Carbonique Hydrology csv files
% 
% Inputs:
%   fileName            - data file
%   assign_in           - 'caller', 'base' - assignes the data to the
%                         actual column header names (logger variables)
%                         ither in callers space or in the base space.
%                         If empty or 0 no
%                         assignments are made
%   varName             - Used with 'caller'. Sets the name of the structure
%                         for the output variables. 
%   flag30min           - true:  convert to 30-min traces (default) 
%                         false: keep the original times
%
%
% (c) Zoran Nesic                   File created:       Jun 20, 2025
%                                   Last modification:  Jun 20, 2025
%

% Revisions (last one first):
%

    arg_default('assign_in',[]);
    arg_default('varName','outStruct');
    arg_default('flag30min',true);
    
    try
        timeInputFormat = {'','hh:mm:ss a'};
        dateColumnNum = [2 1];
        colToKeep = [6 Inf];
        structType = 1;
        inputFileType = [];
        modifyVarNames = 0;
        VariableNamesLine = [10];
        rowsToRead = [11 Inf];
        isTimeDuration =[];
        [EngUnits, Header,tv,outStructTmp] = fr_read_generic_data_file(fileName,assign_in,...
                         varName, dateColumnNum,timeInputFormat ,colToKeep,structType,inputFileType,modifyVarNames,VariableNamesLine,rowsToRead,isTimeDuration);
        if flag30min
            % The hydrology data is sampled in different intervals (15-min or 30-min). Convert to 30-min)
            % round up all the times to the end of 30-min periods
            tv = fr_round_time(tv,[],2);
            minTV = min(tv);
            outStructFields = fieldnames(outStructTmp);
            outStruct = [];
            cntPeriod = 0;
            while minTV <= max(tv)
                indPeriod = find(tv==minTV);
                if ~isempty(indPeriod)
                    cntPeriod = cntPeriod+1;
                    for cntFields=1:length(outStructFields)
                        fName = char(outStructFields(cntFields));
                        if strcmp(fName,'TimeVector')
                            outStruct.(fName)(cntPeriod,1) = outStructTmp.(fName)(indPeriod(end));
                        else
                            outStruct.(fName)(cntPeriod,1) = mean(outStructTmp.(fName)(indPeriod));
                        end
                    end        
                end
                minTV = fr_round_time(minTV+1/48,[],2);
            end
            % At this point the data is converted to 30-min averages
        else
            % leave the data as is 
            outStruct = outStructTmp;
        end
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

