function [EngUnits, Header,tv,outStruct] = fr_read_EddyPro_file(fileName,assign_in,varName,optionsFileRead)
%  fr_read_EddyPro_file - reads EddyPro _full_output and _biomet_ files
%
% 
% Inputs:
%   fileName            - data file
%   assign_in           - 'caller', 'base' - assignes the data to the
%                           actual column header names (logger variables)
%                           either in callers space or in the base space.
%                           If empty or 0 no
%                           assignments are made
%   varName             - Used with 'caller'. Sets the name of the structure
%                         for the output variables. If
%                         empty the default name will be 'LGR' (LGR.tv,
%                         LGR.CH4_ppm...)
%   optionsFileRead     - Structure that can contail any of the input
%                         options for fr_read_generic_file. Any field that
%                         exists in this structure overwrites the default
%                         values used in this function. 
%
%
% (c) Zoran Nesic                   File created:       Aug 25, 2022
%                                   Last modification:  Jan  4, 2025
%

% Revisions (last one first):
%
% Jan 4, 2025 (Zoran)
%   - Improvement: Added "rowsToRead = [3 Inf];" when reading EP summary files.
% Sep 10, 2024 (Zoran)
%   - New feature: using optionsFileRead.flagFileType user can specify the EddyPro file 
%     type directly (options = {'biomet','fulloutput','summary'}). Otherwise program will
%     try to "guess" the file type based on the data file name. 
% Sep 2, 2024 (Zoran)
%   - Added a new input parameter: optionsFileRead 
% Aug 25, 2024 (Zoran)
%   - For full_output files, changed from:
%        colToKeep = [2 Inf];
%      to:
%        colToKeep = [5 Inf];
%      That removed some input columns that were always set to NaN (time,date,filename).
% Feb 16, 2024 (Zoran)
%   - Fixed handling of flags with NaN values. dec2base does not like NaNs.
% Feb 14, 2024 (Zoran)
%   - Big changes. Speed improvements in orders of magnitude.
%       - Switched to using fr_read_generic_data_file.
%       - improved flag creation
%       - Added outStruct to the outputs.
%   - This function now handles _full_output, _biomet_ AND EP_Summary files.
%     This should make fr_read_SmartFlux_file obsolete.
% Jul 22, 2023 (Zoran)
%   - added modifications to be able to process _biomet_ files too.
% Aug 30, 2022 (Zoran)
%   - converted all the *_hf flag variables from 9 to -9999 to make it
%     easer to deal with them in the FirstStage
% Aug 26, 2022 (Zoran)
%   - added spliting flag variables into multiple variables.
%

    arg_default('assign_in',[]);
    arg_default('varName','Stats');
    arg_default('optionsFileRead',[])

    % flagFileType can be given either explicitly using optionsFileRead.flagFileType
    % or it can be "guessed" based on the file name (former is preferred).
    % flagFileType = {'biomet','fulloutput','summary'}
    if ~isempty(optionsFileRead) && isfield(optionsFileRead,'flagFileType')
        flagFileType = optionsFileRead.flagFileType;
        if ~any(strcmpi({'biomet','fulloutput','summary'},flagFileType))
            error('Wrong flagFileType in optionsFileRead (%s)',flagFileType);
        end
    elseif contains(fileName,'_biomet_','IgnoreCase',true)
        flagFileType = 'biomet';
    elseif contains(fileName,'_full_output_','IgnoreCase',true)
        flagFileType = 'fulloutput';
    elseif contains(fileName,'_EP-Summary.txt','IgnoreCase',true)
        flagFileType = 'summary';
    else
        error ('Wrong file type input to fr_read_EddyPro_file')
    end

    try

        
        if strcmpi(flagFileType,'fulloutput')
            timeInputFormat = {[],'HH:mm'}; 
            dateColumnNum = [2 3];
            colToKeep = [4 Inf];
            structType = 1;
            inputFileType = 'delimitedtext';
            modifyVarNames=0;
            VariableNamesLine = 2;       
            if ~isempty(optionsFileRead)
                fNames = fieldnames(optionsFileRead);
                for cntFields = 1:length(fNames)
                    cName = char(fNames(cntFields));
                    sCMD = [char(cName) ' = optionsFileRead.(cName);'];
                    try
                        eval(sCMD);
                    catch ME
                        disp ME
                    end
                end
            end

            % [EngUnits, Header,tv,outStruct] = fr_read_generic_data_file(fileName,...
            %                                                '',...
            %                                                 [], [2 3],timeInputFormat,[4 Inf],1,'delimitedtext',0,2);           
            [EngUnits,Header,tv,outStruct] = fr_read_generic_data_file(fileName,...
                                                             [],[], dateColumnNum, timeInputFormat,colToKeep,structType,...
                                                             inputFileType,modifyVarNames,VariableNamesLine);            
        elseif strcmpi(flagFileType,'biomet')
            timeInputFormat = {[],'HH:mm'}; 
            dateColumnNum = [1 2];
            colToKeep = [3 Inf];
            structType = 1;
            inputFileType = 'delimitedtext';
            modifyVarNames=0;
            VariableNamesLine = 1;        
            if ~isempty(optionsFileRead)
                fNames = fieldnames(optionsFileRead);
                for cntFields = 1:length(fNames)
                    cName = char(fNames(cntFields));
                    sCMD = [char(cName) ' = optionsFileRead.(cName);'];
                    try
                        eval(sCMD);
                    catch ME
                        disp ME
                    end
                end
            end            
            [EngUnits,Header,tv,outStruct] = fr_read_generic_data_file(fileName,...
                                                             [],[], dateColumnNum, timeInputFormat,colToKeep,structType,...
                                                             inputFileType,modifyVarNames,VariableNamesLine);            
            % [EngUnits, Header,tv,outStruct] = fr_read_generic_data_file(fileName,...
            %                                                '',[], [1 2],timeInputFormat,[3 Inf],1,'delimitedtext',0,1);          
        elseif strcmpi(flagFileType,'summary')
            timeInputFormat = {[],'HH:mm:ss'};
            dateColumnNum = [3 4];
            colToKeep = [5 Inf];
            rowsToRead = [3 Inf];
            structType = 1;
            inputFileType = 'delimitedtext';
            modifyVarNames=0;
            VariableNamesLine = 1;
            [EngUnits,Header,tv,outStruct] = fr_read_generic_data_file(fileName,...
                                                             [],[], dateColumnNum, timeInputFormat,colToKeep,structType,...
                                                             inputFileType,modifyVarNames,VariableNamesLine,rowsToRead);
        end

        % Extract individual flags from flag variables
        if strcmpi(flagFileType,'summary') || strcmpi(flagFileType,'fulloutput')            
            flagVariables = {'spikes_hf','amplitude_resolution_hf','drop_out_hf',...
                             'absolute_limits_hf','skewness_kurtosis_hf','skewness_kurtosis_sf',...
                             'discontinuities_hf','discontinuities_sf','timelag_hf',...
                             'timelag_sf','attack_angle_hf','non_steady_wind_hf'};
            for j=1:size(outStruct,1)
                for cntFlagsVars = 1:length(flagVariables)
                    flagField = char(flagVariables{cntFlagsVars});
                    flagVals = outStruct(j,1).(flagField);
                    % NaN's are not appropriate inputs to dec2bin
                    % replace them with 99..999.
                    % use the first non-nan value to establish how many 9s is needed
                    indGood = find(~isnan(flagVals));
                    % Find the number of digits that should be set to 9
                    numOfDigit9 = round(log10(flagVals(indGood(1))));
                    % set all NaNs to numOfDigit9 9s (999999)
                    flagVals(isnan(flagVals)) = base2dec(char(ones(1,numOfDigit9)*9+'0'),10);
                    Ndigits = dec2base(flagVals,10) - '0';
                    for cntFlags = 1:size(Ndigits,2)                
                        flagNum = Ndigits(:,cntFlags);
                        flagNum(flagNum ==9) = -9999; 
                        outStruct.(sprintf('%s_%d',flagField,cntFlags)) = flagNum;
                    end
                end
            end
        end

        if strcmpi(assign_in,'CALLER')
            assignin('caller',varName,outStruct);
        end

    catch ME %#ok<CTCH>
        fprintf(2,'\nError reading file: %s. \n',fileName);
        fprintf(2,'%s\n',ME.message);
        fprintf(2,'Error on line: %d in %s\n\n',ME.stack(1).line,ME.stack(1).file);
        EngUnits = [];
        Header = [];
        tv = [];
    end       
end





%-------------------------------------------------------------------
% function replace_string
% replaces string findX with the string replaceX and padds
% the replaceX string with spaces in the front to match the
% length of findX.
% Note: this will not work if the replacement string is shorter than
%       the findX.
function strOut = replace_string(strIn,findX,replaceX)
    % find all occurances of findX string
    ind=strfind(strIn,findX);
    strOut = strIn;
    N = length(findX);
    M = length(replaceX);
    if ~isempty(ind)
        %create a matrix of indexes ind21 that point to where the replacement values
        % should go
        x=0:N-1;
        ind1=x(ones(length(ind),1),:);
        ind2=ind(ones(N,1),:)';
        ind21=ind1+ind2;

        % create a replacement string of the same length as the strIN 
        % (Manual procedure - count the characters!)
        strReplace = [char(ones(1,N-M)*' ') replaceX];
        strOut(ind21)=strReplace(ones(length(ind),1),:);
    end    
    
end