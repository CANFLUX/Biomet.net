
function out = collapseSamplesWithFlattenedInnerArrays(samples)
% collapseSamplesWithFlattenedInnerArrays
%   Collapses only the outer struct array (samples) into arrays per leaf field,
%   while flattening nested struct *arrays* by renaming them with index
%   suffixes, e.g., flux(2) -> flux_2.
%
% Example:
%   % If you have:
%   % sample(1).flux(2).ch4.exp_B(1).fitOut.N_optimum = 10;
%   % sample(2).flux(2).ch4.exp_B(1).fitOut.N_optimum = 20;
%   % Then after collapse:
%   % out.flux_2.ch4.exp_B_1.fitOut.N_optimum -> [10 20]

    if ~isstruct(samples)
        error('Input must be a struct array.');
    end

    % 1) Normalize each sample: flatten inner struct arrays into suffixed fields
    normSamples = arrayfun(@normalizeSample, samples);

    % 2) Collapse across the outer sample dimension only
    out = collapseAcrossSamples(normSamples);
end

% --- Normalize one sample: split any nested struct arrays into suffixed fields
function sOut = normalizeSample(sIn)
    sOut = struct();
    fn = fieldnames(sIn);

    for k = 1:numel(fn)
        f = fn{k};
        v = sIn.(f);

        if isstruct(v)
            if numel(v) == 1
                % Scalar nested struct: recurse preserving the field name
                sOut.(f) = normalizeSample(v);
            else
                % Struct array: create f_1, f_2, ... with normalized contents
                for j = 1:numel(v)
                    fj = sprintf('%s_%d', f, j);
                    sOut.(fj) = normalizeSample(v(j));
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
    allFields = unique( vertcat(fieldnames(S(:))) );

    for k = 1:numel(allFields)
        f = allFields{k};
        % Gather presence per sample
        hasF = arrayfun(@(s) isfield(s, f), S);

        if ~any(hasF)
            continue;
        end

        % If the field is a struct in at least one sample, handle recursively.
        % We’ll treat missing as empty struct.
        vals = cell(numel(S), 1);
        for i = 1:numel(S)
            if hasF(i)
                vals{i} = S(i).(f);
            else
                vals{i} = struct(); % placeholder to keep shape
            end
        end

        if isstruct(vals{ find(hasF,1) })
            % Recurse for nested structs (still collapsing only outer dimension)
            out.(f) = collapseAcrossSamplesStructCells(vals);
        else
            % Leaf values: collapse into arrays/cells depending on type
            out.(f) = collapseLeaf(vals);
        end
    end
end

% --- Collapse an array of struct cells (per sample) into a single nested struct
function out = collapseAcrossSamplesStructCells(vals)
    % Build union of nested fieldnames
    nestedFields = unique( vertcat(fieldnames([vals{:}])) );
    out = struct();
    for k = 1:numel(nestedFields)
        nf = nestedFields{k};
        % Collect nf from each sample's struct (if present)
        subVals = cellfun(@(v) iff(isfield(v, nf), v.(nf), []), vals, 'UniformOutput', false);

        % Determine if nf is struct in any non-empty sample
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
    % Replace empties with [] for consistency
    empties = cellfun(@isempty, vals);
    if any(empties)
        % Keep empties; they’ll produce NaN/[] or empty strings as needed
        % We won’t force-fill unless requested
    end

    % Determine prototype
    idxProto = find(~empties, 1);
    if isempty(idxProto)
        outVal = vals; % all empty; return cell array
        return;
    end
    proto = vals{idxProto};

    % Numeric/logical scalars -> row vector
    if all(cellfun(@(x) (isempty(x) || ((isnumeric(x) || islogical(x)) && isscalar(x))), vals))
        % Convert empties to NaN for numeric/logical, keep empties if none numeric
        % Here we assume numeric/logical; empties -> NaN
        v = cellfun(@(x) iff(isempty(x), NaN, x), vals);
        outVal = cell2mat(num2cell(v(:))).'; % row vector
        return;
    end

    % Numeric/logical arrays of SAME size -> stack along 1st dimension
    if (isnumeric(proto) || islogical(proto)) ...
            && all(cellfun(@(x) isnumericOrLogicalOrEmptySameSize(x, proto), vals))
        % Replace empties with NaN array of proto size
        filled = cellfun(@(x) fillEmptyLike(x, proto), vals, 'UniformOutput', false);
        try
            outVal = cat(1, filled{:});
        catch
            outVal = filled; % fallback
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
