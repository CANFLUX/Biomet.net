function [EngUnits, Header,tv,outStruct] = fr_read_TOA5_file_new(fileName,assign_in,varName)
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
% (c) Zoran Nesic                   File created:       Oct 16, 2024
%                                   Last modification:  Oct 16, 2024
%

% Revisions (last one first):
%
% 

    arg_default('assign_in',[]);
    arg_default('varName','Stats');
    arg_default('varName',[]);
    
    try
        assignIn = [];
        dateColumnNum = 1;
        timeInputFormat = {[],'HH:mm:ss'};
        colToKeep = [2 Inf];
        structType = 1;
        inputFileType = 'delimitedtext';
        modifyVarNames = 0;
        VariableNamesLine = 2;
        rowsToRead = [];
        isTimeDuration =[];
        [EngUnits,Header,tv,outStruct] = fr_read_generic_data_file(fileName,assignIn,...
                         varName, dateColumnNum,timeInputFormat ,colToKeep,structType,inputFileType,modifyVarNames,VariableNamesLine,rowsToRead,isTimeDuration);
        % Add tv to outStruct to keep it compatible with the legacy software
        % (see: fr_read_TOA5_file_old)
        outStruct.tv = tv;
        % Extract the header info (also needed for some legacy processing)
        fid = fopen(fileName,'r');
        if fid > 0
            for cntHeaderLines = 1:4
                s_read = fgetl(fid);
                fldName = ['line' num2str(cntHeaderLines)];
                Header.(fldName) = split_line(char(s_read));
            end
            fclose(fid);
            % Extract some parameters from the header
            Header.loggerSN = str2double(char(Header.line1(4)));
            Header.loggerType = char(Header.line1(3));
            Header.loggerOS = char(Header.line1(5));
            Header.programName = char(Header.line1(6));
            Header.programName = Header.programName(5:end);    
            % var_names = Header.line2; %#ok<*NODEF>
            % var_names = regexprep(var_names,'\(','');
            % var_names = regexprep(var_names,'\)','');
            % var_names = regexprep(var_names,'[','');
            % var_names = regexprep(var_names,']','');
            % var_names = regexprep(var_names,'\.','_'); % added lines of code to catch decimal points in variable names: not allowed in matlab
            %
            
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

function line_cell = split_line(line_str)

%------------
% These lines are supposed to catch
% variables with names like P(1,2) (comma is not allowed as var name)
% and convert them to P_1_2 by removing first all the commas
% between brackets
ind1=find(line_str=='(');
ind2=find(line_str==')');
for i=1:length(ind1)
    ind = find(line_str(ind1(i)+1:ind2(i)-1)==',');
    line_str(ind1(i)+ind)='_';
end
line_str = regexprep(line_str,'"','');
ind = [0 strfind(line_str,',')];

for i = 1:length(ind)-1
    line_cell(i) = {line_str(ind(i)+1:ind(i+1)-1)}; %#ok<*AGROW>
end
line_cell(i+1) = {line_str(ind(end)+1:end)};
end

%-------------------------------------------------------------------
% function replace_string
% replaces string findX with the string replaceX and padds
% the replaceX string with spaces in the front to match the
% length of findX.
% Note: this will not work if the replacement string is shorter than
%       the findX.
function strOut = replace_string(strIn,findX,replaceX)
    % find all occurances of findX string
    ind=strfind(strIn,findX);
    strOut = strIn;
    N = length(findX);
    M = length(replaceX);
    if ~isempty(ind)
        %create a matrix of indexes ind21 that point to where the replacement values
        % should go
        x=0:N-1;
        ind1=x(ones(length(ind),1),:);
        ind2=ind(ones(N,1),:)';
        ind21=ind1+ind2;

        % create a replacement string of the same length as the strIN 
        % (Manual procedure - count the characters!)
        strReplace = [char(ones(1,N-M)*' ') replaceX];
        strOut(ind21)=strReplace(ones(length(ind),1),:);
    end    
    
end