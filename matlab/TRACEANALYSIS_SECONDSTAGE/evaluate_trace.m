function trace_out = evaluate_trace(trace_in,evalType)
% evaluate_trace - runs Evaluate statements from 1st and 2nd stage ini files
%
%
%
% various authors                   File created:      probably 2002
%                                   Last modification:  Feb  1, 2025
%

% Revisions:
%
% Feb 1, 2025 (Zoran)
%   - added an option parameter evalType so the same function can be used for 
%     processing Evaluate and postEvaluate fields. 
%     Default is 'Evaluate'
% Apr 30, 2024 (Zoran)
%   - Added this header
%   - removed an unused input parameter from the function call (countTraces)
%   - improved error handling and cleaned up syntax

arg_default('evalType','Evaluate')

%Get all the field names from the ini file
allFields = fieldnames( trace_in.ini );

%Itterate over all the commands within the ini file for specified trace
for cntFields =1:length(allFields)
    cFieldName = char(allFields(cntFields));
    %Execute only the Evaluate commands
    if startsWith(cFieldName,evalType,'IgnoreCase',true)   %strncmp( char(allFields(cntFields)) , 'Evaluate', 8 )
        commandLine = getfield( trace_in.ini, cFieldName);    %get the command line

        %Process the command line
        commandLine = strrep(commandLine, '...,', '');   %remove ',...' from the command line
        commandLine = strrep(commandLine, ',,', ',');    %make sure that there are no comma repetitions
        commandLine = strrep(commandLine, ';,', '; ');   %remove ';,' from the command line
        commandLine = strrep(commandLine, '+,', '+');
        commandLine = strrep(commandLine, '-,', '-');
        commandLine = strrep(commandLine, '/,', '/');
        commandLine = strrep(commandLine, '*,', '*');

        try
            %execute the command(s) within the callers workspace, errors output to Error in callers workspace
            evalin('caller',commandLine);  
            %retrieve the data from the callers workspace
            try
                trace_in.data = evalin('caller',trace_in.variableName);
            catch ME
                fprintf(2,'Error in ini file: variable name in evaluate statement does not match trace.variableName (%s) \n' ,trace_in.variableName );
                fprintf(2,'Matlab error message: %s\n',ME.message);
                trace_in.Error = 1;
            end
        catch ME
            trace_in.Error = 1;
            trace_in.data = [];
            fprintf(2,'Error processing trace.variableName: %s\n', trace_in.variableName); 
            fprintf(2,'Unable to evaluate: %s\n', commandLine);    %evalutate the command
            fprintf(2,'Matlab error message: %s\n', ME.message);            
        end
    end
end

%Set trace_out to trace_in
trace_out = trace_in;
