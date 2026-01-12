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

    if ~isstruct(samples)
        error('Input must be a struct array.');
    end

    % 1) Normalize each sample: flatten inner struct arrays into suffixed fields
    normSamples = arrayfun(@normalizeSampleMD, samples);

    % 2) Collapse across the outer sample dimension only
    out = collapseAcrossSamples(normSamples);
end

% --- Normalize one sample: split any nested struct arrays (multi-D) into suffixed fields
function sOut = normalizeSampleMD(sIn)
    sOut = struct();
    fn = fieldnames(sIn);

    for k = 1:numel(fn)
        f = fn{k};
        v = sIn.(f);

        if isstruct(v)
            if isscalar(v)        % scalar nested struct: recurse preserving the name
                sOut.(f) = normalizeSampleMD(v);
            else
                % Multi-D struct array: create f_<i1>_<i2>_... for each element
                sz = size(v);
                nd = ndims(v);
                subs = cell(1, nd);
                for lin = 1:numel(v)
                    [subs{:}] = ind2sub(sz, lin); % subs = {i1, i2, ...}
                    idxStrs   = cellfun(@(x) num2str(x), subs, 'UniformOutput', false);
                    fj        = sprintf('%s_%s', f, strjoin(idxStrs, '_'));
                    sOut.(fj) = normalizeSampleMD(v(lin));
                end
            end
        else
            % Leaf (non-struct): copy as-is
            sOut.(f) = v;
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

% --- Collapse an array of struct cells (per sample) into a single nested struct
function out = collapseAcrossSamplesStructCells(vals)
    % Build union of nested fieldnames from non-empty structs only
    nonEmpty   = vals(~cellfun(@isempty, vals));
    if isempty(nonEmpty)
        out = struct(); return;
    end
    neFnCells  = cellfun(@(v) fieldnames(v), nonEmpty, 'UniformOutput', false);
    nestedFields = unique( vertcat(neFnCells{:}) );

    out = struct();
    for k = 1:numel(nestedFields)
        nf = nestedFields{k};
        % Collect nf from each sample's struct (if present)
        subVals = cellfun(@(v) iff(~isempty(v) && isfield(v, nf), v.(nf), []), vals, 'UniformOutput', false);

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

