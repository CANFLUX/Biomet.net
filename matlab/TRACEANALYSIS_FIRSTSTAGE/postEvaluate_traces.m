function trace_str_out = postEvaluate_traces(trace_str)
% This function processes postEvaluate fields after the first stage cleaning
%
%	INPUT:
%			'trace_str'		- An array of structure containing all traces' info 
%	OUTPUT:
%			'trace_str_out'	-Updated trace array
%
%
% (c) Zoran Nesic               File created:       Feb  3, 2025
%                               Last modification:  Feb  3, 2025

% 
% Revisons:
%

% first expand all data into local variables so they 
% will be made avalable for postEvaluate calculations 
% (evaluate_trace function expects these variables to be here)
for cntTraces=1:length(trace_str)
    sCmd = [trace_str(cntTraces).variableName '= trace_str(cntTraces).data;'];
    eval(sCmd);
end

% loop through traces and process postEvaluate statements
for cntTraces = 1:length(trace_str)
    if isfield(trace_str(cntTraces).ini,'postEvaluate') && ~isempty(trace_str(cntTraces).ini.postEvaluate)
        trace_str(cntTraces) = evaluate_trace( trace_str(cntTraces),'postEvaluate' );	% evaluate the trace
    end
end

% put all trace variables back into trace_str().data
for cntTraces=1:length(trace_str)
    sCmd = [ 'trace_str(cntTraces).data = ' trace_str(cntTraces).variableName ';']; 
    eval(sCmd);
end

% set the output
trace_str_out = trace_str;
