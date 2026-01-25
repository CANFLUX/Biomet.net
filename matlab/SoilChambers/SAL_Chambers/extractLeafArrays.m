
function results = extractLeafArrays(outStruct,prefix)
% extractLeafArrays  Return all leaf field paths and their data from a nested struct.
%   results = extractLeafArrays(outStruct)
%   Each element of results is a struct with fields:
%       .fileName  - full dotted path (e.g., 'out.flux_1.ch4.exp_B_1.fitOut.N_optimum')
%       .data      - the leaf value (numeric/logical/string/cell/etc.)
%
% Works with the output of collapseSamplesWithFlattenedInnerArrays().

    arg_default('prefix',[]);

    if ~isstruct(outStruct)
        error('Input must be a struct.');
    end

    results = collectLeaves(outStruct, prefix);  % prefix the file names if needed
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
