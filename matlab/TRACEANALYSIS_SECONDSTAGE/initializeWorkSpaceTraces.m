function tmp_traces = initializeWorkSpaceTraces(path_to_load)
%
%
%

% Revisions
%
% Jan 26, 2023 (Zoran)
%  - Added 'Reading data from:...' display line to improve troubleshooting

% Added Apr 11, 2022 to handle MacOS folder separators
path_to_load = setFolderSeparator(path_to_load);
fprintf('Reading data from: \n    %s\n',path_to_load);

%load all traces located in the current path 
[chck, tmp_traces] = get_traces_db('','','','read_all',path_to_load);

numTracesToAdd = length(tmp_traces);

if( chck == 1 )
   for i = 1:numTracesToAdd
      if ~isempty( tmp_traces(i).variableName ) & ~isempty( tmp_traces(i).data ) %weed out the empty traces
         assignin('caller', tmp_traces(i).variableName, tmp_traces(i).data);
      end
    end
end

