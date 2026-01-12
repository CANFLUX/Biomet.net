%===============================================================
%
% Recursive structure field name search
% *** NOT IMPLEMENTED - found a better option (see: test_convert_UdeM_data_to_database.m)
%
%===============================================================

function dbFileNames = Test_recursiveStrucFieldNames(StatsAll,n_template,ignoreFields)

arg_default('n_template',1);
arg_default('ignoreFields',{})
dbFileNames = [];
nFiles = 0;
statsFieldNames = fieldnames(StatsAll);
for i = 1:length(statsFieldNames)
    fName = char(statsFieldNames(i));
    if ~ismember(fName,ignoreFields)
        % load the first element of StatsAll to
        % examine the structure type
        fieldTmp = getfield(StatsAll,{n_template},fName);
        % skip fields 'Configuration', 'Spectra' and all character and cell fields
        if ~strcmp(fName,'Configuration') & ~ischar(fieldTmp) & ~iscell(fieldTmp) & ~strcmp(fName,'Spectra')
            % is it a vector or not
            nLen = length(fieldTmp);
            if nLen > 1
                [nCol, nRow] = size(fieldTmp);
                for j = 1:nCol
                    for j1 = 1:nRow
                        nFiles = nFiles + 1;
                        if nCol == 1 | nRow == 1
                            % if it's a one dimensional vector use only one index
                            jj = max(j,j1);
                            dbFileNames{nFiles} = [fName '(' num2str(jj) ')' ];
                        else
                            % for two dimensional vectors use two
                            dbFileNames{nFiles} = [fName '(' num2str(j) ',' num2str(j1) ')' ];
                        end % if nCol == 1 or nRow == 1
                        % test if it's a structure and do a recursive call
                        if isstruct(fieldTmp)
                            %-------------------------
                            % recursive call goes here
                            %-------------------------
                            %                    fieldI = get_stats_field_fast(StatsAll,fName);
                            if nCol == 1 | nRow == 1
                                % if it's a one dimensional vector use only one index
                                jj = max(j,j1);
                                dbFileNamesTmp = Test_recursiveStrucFieldNames(fieldTmp(jj),[],ignoreFields);
                            else
                                % for two dimensional vectors use two
                                dbFileNamesTmp = Test_recursiveStrucFieldNames(fieldTmp(j,j1),[],ignoreFields);
                            end % if nCol == 1 or nRow == 1
    
                            mFiles = length(dbFileNamesTmp);
                            dbFileNamesBase = char(dbFileNames{nFiles});
                            % move the pointer back to overwrite the last entry
                            nFiles = nFiles - 1;
                            for k=1:mFiles
                                nFiles = nFiles + 1;
                                dbFileNames{nFiles}=[dbFileNamesBase '.' char(dbFileNamesTmp(k))];
                            end % i=1:nFiles
                        end % if isstruc(fieldTmp)
                    end % for j1=1:nRow
                end % j = 1:nCol
            else
                % save new file name
                nFiles = nFiles + 1;
                dbFileNames{nFiles} = fName;
                % test if it's a structure and do a recursive call
                if isstruct(fieldTmp)
                    %-------------------------
                    % recursive call goes here
                    %-------------------------
                    %                    fieldI = get_stats_field_fast(StatsAll,fName);
                    dbFileNamesTmp = Test_recursiveStrucFieldNames(fieldTmp,[],ignoreFields);
                    mFiles = length(dbFileNamesTmp);
                    dbFileNamesBase = char(dbFileNames{nFiles});
                    % back out the index by one (over-write the last fName entry)
                    nFiles = nFiles - 1;
                    for k=1:mFiles
                        nFiles = nFiles + 1;
                        dbFileNames{nFiles}=[dbFileNamesBase '.' char(dbFileNamesTmp(k))];
                    end % i=1:nFiles
                end % if isstruc(fieldTmp)
            end % nLen > 1
        end % fName ~= 'Configuration'
    end % ~ismember
end % for i =
