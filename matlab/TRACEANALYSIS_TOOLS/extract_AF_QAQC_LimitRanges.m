function limitsQAQC = extract_AF_QAQC_LimitRanges(traceNames,QAQC_limit_filename)
% Extract minMax limits from Ameriflux QAQC file.
%
% Example (finding limits for one trace):
%       limitsQAQC = extract_AF_QAQC_LimitRanges('FC','E:\Pipeline_Projects\Ameriflux_raw\QAQC_limits_ranges_info.csv')
%    returns
%       limitsQAQC with fields:
%          minMax: [0 100]
%      minMaxBuff: [-5 105]
%           units: {'%'}
%
% Example (finding limits for all 1st stage traces):
%           trace_str = readIniFileDirect(yearIn,siteID,1);
%           traceNames = {trace_str(:).variableName};
%           QAQC_limit_filename = 'E:\Pipeline_Projects\Ameriflux_raw\QAQC_limits_ranges_info.csv';
%           limitsQAQC = extract_AF_QAQC_LimitRanges(traceNames,QAQC_limit_filename)
%
%
% Zoran Nesic               File created:           Mar 12, 2025
%                           Last modification:      Mar 12, 2025

% Revisions:
%

% Read Ameriflux QAQC
% Notes from the file:
%     Ameriflux QAQC information
%     Extracted from variable "FP_ls" when running amf_chk_run.R/amfqaqc_main.R
%     Rosie Howard
QC=readtable(QAQC_limit_filename,"NumHeaderLines",6);

% limitsQAQC=[];
%%
for cntAFvar = 1:length(QC.Name)

    afVarName = char(QC.Name(cntAFvar));
    matchInd=[];
    matchCnt = 0;
    
    % first find the traceNames that match exactly Ameriflux variable names without _d_d_d
    % there could only be one exact match (if ini file does not have duplicates which we
    % test for when loading the data)
    flags = find(strcmpi(traceNames,afVarName) | startsWith(traceNames,[afVarName '_']));
    for cntFlags = 1:length(flags)
        % Save matches
        matchCnt = matchCnt + 1;
        matchInd(matchCnt) = flags(cntFlags);
        limitsQAQC(flags(cntFlags)).minMax     = [QC.Min(cntAFvar)      QC.Max(cntAFvar)];
        limitsQAQC(flags(cntFlags)).minMaxBuff = [QC.Min_buff(cntAFvar) QC.Max_buff(cntAFvar)];
        limitsQAQC(flags(cntFlags)).units = QC.Units(cntAFvar);
    end

    % if ~isempty(matchInd)
    %     fprintf('%10s  ',afVarName);
    %     fprintf('%d ',matchInd);
    %     fprintf('   minMax = [%f %f]',limitsQAQC(1).minMax)
    %     fprintf('\n');
    % end
    % 
    % 
end



