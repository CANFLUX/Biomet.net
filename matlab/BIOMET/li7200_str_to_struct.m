function structConfig = li7200_str_to_struct(licorString)
% structConfig = li7200_str_to_struct(licorString)
% 
% Inputs:
%   licorString         - LICOR configuration string: (LI7200(Reg(Reg7 48)(Reg25 32768))... 
%
% Outputs:
%   structConfig        - structure containing info from the LICOR config file
%
%
% NOTE:
%   - Originaly created with Copilot.
%   - Copilot used nested functions (functions within functions)
%     which can have access to the main functions data space 
%     (like using global variables). See skipWS(). Consider changing this.
%
% (c) Zoran Nesic                   File created:       Feb 16, 2026
%                                   Last modification:  Feb 16, 2026
%


% Original comments
%LI7200_STR_TO_STRUCT Parse an LI-7200 style S-expression string into a MATLAB struct.
%
% Usage:
%   cfg = li7200_str_to_struct(txt);
%
% Features:
% - Parses nested parenthetical groups like (Key Value) and (Key (...)).
% - Converts TRUE/FALSE (any case) -> logical.
% - Converts numeric strings (incl. scientific notation) -> double.
% - Keeps empty values as ''.
% - Converts keys to valid MATLAB field names with matlab.lang.makeValidName.
% - If a key repeats at the same level, collects its values in a cell array.
%
% Notes/Assumptions:
% - Values with spaces (e.g., dates like 'Feb 14 2025 at 12:42:55') are
%   captured entirely up to the closing ')'.
% - Keys can start with digits; they will be prefixed by 'x' by makeValidName.
% - Empty groups like (HTCBoard ) become ''.
%
% Example:
%   txt = '(LI7200(Reg(Reg7 48))(Calibrate (ZeroCO2 (Val 1.1))))';
%   cfg = li7200_str_to_struct(txt);
%   disp(cfg.LI7200.Reg.Reg7)          % -> 48
%   disp(cfg.LI7200.Calibrate.ZeroCO2.Val) % -> 1.1

    % make sure licorString is 1 x n row char vector
    arguments
        licorString (1,:) char
    end

    s = strtrim(licorString);
    i = 1;
    [node, i] = parseNode(s, i);
    skipWS();

    if i <= numel(s)
        % If there’s trailing text, try to consume further nodes (rare).
        while i <= numel(s)
            if s(i) == '('
                [extra, i] = parseNode(s, i);
                node = mergeStructs(node, extra);
            else
                i = i + 1;
            end
            skipWS();
        end
    end

    structConfig = node;

    % --- Nested helpers ----------------------------------------------------
    function [out, idx] = parseNode(str, idx)
        % Parse a single group: (Name [Value or ChildGroups])
        idx = skipWSLocal(str, idx);
        assert(idx <= numel(str) && str(idx) == '(', 'Expected "(" at position %d', idx);
        idx = idx + 1; % consume '('
        idx = skipWSLocal(str, idx);

        [rawName, idx] = readToken(str, idx);
        fName = matlab.lang.makeValidName(rawName);
        idx = skipWSLocal(str, idx);

        % Three cases:
        % 1) Immediately ')' -> empty value
        % 2) Next char is not '(' and not ')' -> key-value with a single value up to ')'
        % 3) Next char is '(' -> nested groups

        if idx <= numel(str) && str(idx) == ')'
            % Empty group: (Key )
            idx = idx + 1; % consume ')'
            out = struct();
            out.(fName) = '';
            return;
        elseif idx <= numel(str) && str(idx) ~= '('
            % Simple value: (Key some value ... up to ')')
            [valText, idx] = readUntil(str, idx, ')');
            % idx is at ')' now
            idx = idx + 1; % consume ')'
            out = struct();
            out.(fName) = coerceValue(valText);
            return;
        else
            % Nested groups: (Key (...)(...)(...))
            child = struct();
            while idx <= numel(str) && str(idx) ~= ')'
                idx = skipWSLocal(str, idx);
                if idx <= numel(str) && str(idx) == '('
                    [sub, idx] = parseNode(str, idx);
                    child = mergeStructs(child, sub);
                else
                    % Defensive: if stray text appears, consume to next ')' (rare)
                    if idx <= numel(str) && str(idx) ~= ')'
                        [~, idx] = readUntil(str, idx, ')');
                    end
                end
                idx = skipWSLocal(str, idx);
            end
            assert(idx <= numel(str) && str(idx) == ')', 'Unbalanced parentheses near position %d', idx);
            idx = idx + 1; % consume ')'

            out = struct();
            out.(fName) = child;
            return;
        end
    end

    function v = coerceValue(t)
        tt = strtrim(t);
        if isempty(tt)
            v = ''; return;
        end

        % Booleans (case-insensitive)
        if strcmpi(tt, 'true')
            v = true; return;
        elseif strcmpi(tt, 'false')
            v = false; return;
        end

        % Numeric (incl. scientific notation)
        num = str2double(tt);
        if ~isnan(num)
            v = num; return;
        end

        % Otherwise keep string as-is
        v = tt;
    end

    function [tok, idx] = readToken(str, idx)
        % Reads a token up to whitespace or parentheses.
        start = idx;
        while idx <= numel(str)
            c = str(idx);
            if isspace(c) || c == '(' || c == ')'
                break;
            end
            idx = idx + 1;
        end
        tok = str(start:idx-1);
    end

    function [seg, idx] = readUntil(str, idx, stopper)
        % Reads text (including spaces) until 'stopper', not consuming it.
        start = idx;
        while idx <= numel(str) && str(idx) ~= stopper
            idx = idx + 1;
        end
        seg = str(start:idx-1);
    end

    function idx = skipWSLocal(str, idx)
        while idx <= numel(str) && isspace(str(idx))
            idx = idx + 1;
        end
    end

    function skipWS()
        while i <= numel(s) && isspace(s(i))
            i = i + 1;
        end
    end

    function merged = mergeStructs(a, b)
        % Merge struct b into struct a. If a field repeats, collect into cell.
        if isempty(fieldnames(a))
            merged = b; return;
        end
        if isempty(fieldnames(b))
            merged = a; return;
        end
        merged = a;
        fb = fieldnames(b);
        for k = 1:numel(fb)
            key = fb{k};
            val = b.(key);
            if isfield(merged, key)
                merged.(key) = appendValue(merged.(key), val);
            else
                merged.(key) = val;
            end
        end
    end

    function out = appendValue(existing, newVal)
        % If field repeats, make/extend a cell array to preserve all values.
        if iscell(existing)
            out = [existing, {newVal}];
        else
            out = {existing, newVal};
        end
    end
end