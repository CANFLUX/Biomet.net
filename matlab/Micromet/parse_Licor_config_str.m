function [structOut,structStatus] = parse_Licor_config_str(strIn) 
%  outStruct = parse_Licor_config(strIn)
% 
% Inputs:
%   strIn               -  Licor configuration string ("*.l7x")
%                          
%
% (c) Zoran Nesic                   File created:       Jun  2, 2025
%                                   Last modification:  Jun  2, 2025
%

% Revisions (last one first):
%

    try
        structOut = [];
        currentStruct = 'structOut';
        while length(strIn)>1 
            
            indO = strfind(strIn,'(');
            indC = strfind(strIn,')');
            
            if length(indO)> 1 && indO(2) < indC(1)
                % if '(' is not followed by a ')' then this is a new structur field
                newField = strIn(indO(1)+1:indO(2)-1);
                currentStruct = [currentStruct '.' goodFieldName(newField)]; %#ok<AGROW>
                strIn = strIn(indO(2):end);
            elseif indC(1) == 1
                % if the first item is ')' then move one field back
                indDot = strfind(currentStruct,'.');
                currentStruct = currentStruct(1:indDot(end)-1);
                strIn = strIn(2:end);
            else
                % if '(' is followed by ')' then it should be a two parameter entry
                % the first parameter (before a <SPACE>) is the field name,
                % the second (everything after <SPACE> is the value (it could be a string or a number)
                newItem = strIn(indO(1)+1:indC(1)-1);
                strIn = strIn(indC(1)+1:end);
                indSpc = strfind(newItem,' ');
                if ~isempty(indSpc)
                    newField = newItem(1:indSpc(1)-1);
                    newValue = newItem(indSpc(1)+1:end);
                else
                    newField = newItem;
                    newValue = [];
                end
                oldStruct = currentStruct;
                currentStruct = [currentStruct '.' goodFieldName(newField)]; %#ok<AGROW>
                
                if ~isnan(str2double(newValue))            
                    tmp = str2double(newValue);
                    cmdStr = sprintf('%s = %s;',currentStruct,num2str(tmp));
                else           
                    cmdStr = sprintf('%s = ''%s'';',currentStruct,newValue);
                end
                %fprintf('%s\n',cmdStr);
                eval(cmdStr);
                currentStruct = oldStruct;
            end
            if length(indO) == 1 %#ok<ISCL>
                break
            end
        end
        % Extract some misc important information
        structStatus.SN = structOut.Coef.Current.SerialNo;
        structStatus.CO2.Zero.Datetime = convertDate(structOut.Calibrate.ZeroCO2.Date);
        structStatus.CO2.Zero.Val      = checkNum(structOut.Calibrate.ZeroCO2.Val);
        structStatus.CO2.Span.Datetime = convertDate(structOut.Calibrate.SpanCO2.Date);
        structStatus.CO2.Span.Val      = checkNum(structOut.Calibrate.SpanCO2.Val);
        structStatus.CO2.Span.Target   = checkNum(structOut.Calibrate.SpanCO2.Target);        
        structStatus.H2O.Zero.Datetime = convertDate(structOut.Calibrate.ZeroH2O.Date);
        structStatus.H2O.Zero.Val      = checkNum(structOut.Calibrate.ZeroH2O.Val);
        structStatus.H2O.Span.Datetime = convertDate(structOut.Calibrate.SpanH2O.Date);
        structStatus.H2O.Span.Val      = checkNum(structOut.Calibrate.SpanH2O.Val);
        structStatus.H2O.Span.Target   = checkNum(structOut.Calibrate.SpanH2O.Target);
        structStatus.BW = structOut.Outputs.BW;
    catch
        %fprintf(2,'Error parsing Licor config string\n');
        structOut = [];
        structStatus = [];
    end
end

function goodName = goodFieldName(fieldName)
    if ~isnan(str2double(fieldName(1)))
        goodName = ['a' fieldName];
    else
        goodName = fieldName;
    end
end

function validDate = convertDate(dateIn)
    try
        validDate = datetime(dateIn,'inputformat',['MMM d uuuu ''at'''  'H:m:s']);
    catch
        validDate = NaT;
    end
end

function validNum = checkNum(Val)
    if isnumeric(Val)
        validNum = Val;
    else
        validNum = NaN;
    end
end