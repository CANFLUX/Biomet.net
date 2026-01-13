function out = collapseSamplesWithFlattenedInnerArrays(samples)
% collapseSamplesWithFlattenedInnerArrays
%   Collapses only the outer struct array (samples) into arrays per leaf field,
%   while flattening nested struct *arrays* of any dimensionality by renaming
%   them with index suffixes, e.g., exp_B(1,3) -> exp_B_1_3.
%
% Example:
%   % sample(1).flux(1).ch4.exp_B(1,3).fitOut.N_optimum = 10;
%   % sample(2).flux(1).ch4.exp_B(1,3).fitOut.N_optimum = 20;
%   % out = collapseSamplesWithFlattenedInnerArrays(sample);
%   % out.flux_1.ch4.exp_B_1_3.fitOut.N_optimum -> [10 20]
%
%   while flattening nested struct arrays of any dimensionality. If the nested
%   array is effectively 1-D (exactly one non-singleton dimension), only that
%   dimension's index is used in the suffix (e.g., a(1,2), a(1,3) -> a_2, a_3).
%
%   If >=2 dimensions are non-singleton, all indices are retained (exp_B_1_3).
%   
%   1-D numeric/logical leaf arrays are split into scalar fields with
%   suffixes (_1, _2, ...), e.g., T = [1 10 100] -> T_1=1, T_2=10, T_3=100.

    if ~isstruct(samples)
        error('Input must be a struct array.');
    end

    % 1) Normalize each sample: flatten inner struct arrays and split 1-D leaves
    normSamples = arrayfun(@normalizeSampleMD_dropSingletons_andSplitLeaves, samples);

    % 2) Collapse across the outer sample dimension only
    out = collapseAcrossSamples(normSamples);

end


% --- Normalize one sample: handle nested structs/arrays and split 1-D leaves ---
function sOut = normalizeSampleMD_dropSingletons_andSplitLeaves(sIn)
    sOut = struct();
    fn = fieldnames(sIn);

    for k = 1:numel(fn)
        f = fn{k};
        v = sIn.(f);

        if isstruct(v)
            if isscalar(v)
                % Scalar nested struct: recurse preserving the name
                sOut.(f) = normalizeSampleMD_dropSingletons_andSplitLeaves(v);
            else
                % Multi-D struct array: create f_<indices> for each element
                sz = size(v);
                nd = ndims(v);
                nonSingDims = find(sz > 1);

                if isempty(nonSingDims)
                    sOut.(f) = normalizeSampleMD_dropSingletons_andSplitLeaves(v); % safety
                    continue;
                end

                useAllDims = numel(nonSingDims) >= 2;
                subs = cell(1, nd);
                for lin = 1:numel(v)
                    [subs{:}] = ind2sub(sz, lin); % subs = {i1, i2, ..., i_nd}

                    if useAllDims
                        idxs = cellfun(@(x) num2str(x), subs, 'UniformOutput', false);
                    else
                        % Keep only the single varying dimension’s index
                        d = nonSingDims;  % scalar index of the varying dim
                        idxs = { num2str(subs{d}) };
                    end

                    fj = sprintf('%s_%s', f, strjoin(idxs, '_'));
                    sOut.(fj) = normalizeSampleMD_dropSingletons_andSplitLeaves(v(lin));
                end
            end
        else
            % --- Leaf (non-struct): optionally split 1-D numeric/logical vectors ---
            if (isnumeric(v) || islogical(v)) && isvector(v) && ~isscalar(v)
                % Split into per-element scalar fields: f_1, f_2, ...
                for i = 1:numel(v)
                    sOut.(sprintf('%s_%d', f, i)) = v(i);
                end
            else
                % Copy other leaves as-is (scalars, strings, matrices, cells, etc.)
                sOut.(f) = v;
            end
        end
    end
end

% --- Collapse leaf fields across the outer sample array (normSamples)
function out = collapseAcrossSamples(S)
    out = struct();

    % Union of fieldnames across samples (handles ragged normalization)
    fnCells   = arrayfun(@(s) fieldnames(s), S, 'UniformOutput', false);
    if isempty(fnCells)
        return;
    end
    allFields = unique( vertcat(fnCells{:}) );

    for k = 1:numel(allFields)
        f = allFields{k};
        hasF = arrayfun(@(s) isfield(s, f), S);

        % Collect values per sample (missing -> [])
        vals = arrayfun(@(s, hf) iff(hf, s.(f), []), S, hasF, 'UniformOutput', false);

        % If the field is struct in any non-empty sample, recurse
        firstNonEmpty = find(~cellfun(@isempty, vals), 1);
        if ~isempty(firstNonEmpty) && isstruct(vals{firstNonEmpty})
            out.(f) = collapseAcrossSamplesStructCells(vals);
        else
            out.(f) = collapseLeaf(vals);
        end
    end
end


function out = collapseAcrossSamplesStructCells(vals)
% collapseAcrossSamplesStructCells  Collapses an array of per-sample struct cells
% into a single nested struct, safely handling missing fields and empties.
%
%   vals : 1xN cell array, each cell contains a struct (possibly empty []).

    % Filter to non-empty struct cells
    isStructCell = ~cellfun(@isempty, vals) & cellfun(@isstruct, vals);
    nonEmptyStructs = vals(isStructCell);

    % If no non-empty structs, return empty struct
    if isempty(nonEmptyStructs)
        out = struct();
        return;
    end

    % Build union of nested fieldnames from non-empty structs only
    fnCells = cellfun(@(v) fieldnames(v), nonEmptyStructs, 'UniformOutput', false);
    nestedFields = unique( vertcat(fnCells{:}) );

    out = struct();

    for k = 1:numel(nestedFields)
        nf = nestedFields{k};

        % Collect nf from each sample's struct (missing -> [])
        subVals = cell(size(vals));
        for i = 1:numel(vals)
            vi = vals{i};
            if ~isempty(vi) && isstruct(vi) && isfield(vi, nf)
                subVals{i} = vi.(nf);
            else
                subVals{i} = [];  % placeholder for missing
            end
        end

        % Determine whether to recurse (struct in any non-empty sample)
        firstNonEmpty = find(~cellfun(@isempty, subVals), 1);
        if ~isempty(firstNonEmpty) && isstruct(subVals{firstNonEmpty})
            out.(nf) = collapseAcrossSamplesStructCells(subVals);
        else
            out.(nf) = collapseLeaf(subVals);
        end
    end
end


% --- Collapse leaf cells across samples into vectors/matrices/strings/cells
function outVal = collapseLeaf(vals)
    empties = cellfun(@isempty, vals);

    % Prototype from first non-empty
    idxProto = find(~empties, 1);
    if isempty(idxProto)
        outVal = vals; % all empty; return cell array
        return;
    end
    proto = vals{idxProto};

    % Numeric/logical scalars -> row vector (empties -> NaN)
    if all(cellfun(@(x) isempty(x) || ((isnumeric(x) || islogical(x)) && isscalar(x)), vals))
        vCell  = cellfun(@(x) iff(isempty(x), NaN, double(x)), vals, 'UniformOutput', false);
        outVal = cell2mat(vCell(:)).'; % row vector [v1 v2 ...]
        return;
    end

    % Numeric/logical arrays of SAME size -> stack along 1st dimension
    if (isnumeric(proto) || islogical(proto)) ...
            && all(cellfun(@(x) isnumericOrLogicalOrEmptySameSize(x, proto), vals))
        filled = cellfun(@(x) fillEmptyLike(x, proto), vals, 'UniformOutput', false);
        try
            outVal = cat(1, filled{:}); % samples as rows
        catch
            outVal = filled;            % fallback
        end
        return;
    end

    % Strings/chars -> string array (empties -> "")
    if isstring(proto) || ischar(proto)
        outVal = string( cellfun(@(x) iff(isempty(x), "", x), vals, 'UniformOutput', false) );
        return;
    end

    % Otherwise, keep as cell array (heterogeneous or variable sizes)
    outVal = vals;
end

% --- Helpers ---
function tf = isnumericOrLogicalOrEmptySameSize(x, proto)
    tf = isempty(x) || ((isnumeric(x) || islogical(x)) && isequal(size(x), size(proto)));
end

function y = fillEmptyLike(x, proto)
    if ~isempty(x), y = x; return; end
    if isnumeric(proto)
        y = nan(size(proto));
    elseif islogical(proto)
        y = false(size(proto));
    else
        y = [];
    end
end

function y = iff(cond, a, b)
    if cond, y = a; else, y = b; end
end

