function outputFilesAndData = db_struct2filenames(outStruct,prefix)
% outputFilesAndData = db_struct2filenames(outStruct,prefix)
%
% Converts the structure type 1:
%                          Struct.Variable(ind)
% to an cell array with cells in the format:
%    outputFilesAndData{n}.fileName ->  structure name converted to a valid file name
%    outputFilesAndData{n}.data     ->  double array
%
% Input
%   outStruct           - type 0 structure
%   prefix              - optional prefix to be added to each file name
%
% Output:
%   outputFilesAndData  - cell array of data structures with fields fileName and data
%
%
% Notes:
%   The original function was created by Copilot (extractLeafArrays.m)
%   to handle chamber data output structure.
%
% Zoran Nesic               File created:       Feb 16, 2026
%                           Last modification:  Feb 16, 2026

% Revisions:
%


% Original comments
% extractLeafArrays  Return all leaf field paths and their data from a nested struct.
%   results = extractLeafArrays(outStruct)
%   Each element of results is a struct with fields:
%       .fileName  - full dotted path (e.g., 'out.flux_1.ch4.exp_B_1.fitOut.N_optimum')
%       .data      - the leaf value (numeric/logical/string/cell/etc.)
%
% Works with the output of db_convert_structType_0_to_1().

    arg_default('prefix',[]);

    if ~isstruct(outStruct)
        error('Input must be a struct.');
    end

    outputFilesAndData = collectLeaves(outStruct, prefix);  % prefix the file names if needed
end

function acc = collectLeaves(s, prefix)
    acc = {};
    fns = fieldnames(s);

    for k = 1:numel(fns)
        f = fns{k};
        v = s.(f);
        if ~isempty(prefix)
            pathX = sprintf('%s.%s', prefix, f);
        else
            pathX = f;
        end
        if isstruct(v)
            % Recurse into nested struct
            accChild = collectLeaves(v, pathX);
            acc = [acc; accChild]; %#ok<AGROW>
        else
            % Leaf node: record as result
            item.fileName = pathX;
            item.data = v;
            acc = [acc; {item}]; %#ok<AGROW>
        end
    end
end
