%% test how to convert UdeM chamber results from complex structures to
%  database files (Zoran Jan 2026)
setup_UdeM_calc


%%  Load an example data files (1 day of data)
load E:\Site_DATA\WL\met-data\hhour\20210823_recalcs_UdeM.mat

%% Add correct TimeVector fields to all dataStruct.chamber().sample() fields
unitsIn = '60min';
nChambers = length(dataStruct.chamber);
for cntChambers = 1:nChambers
    nSamples = length(dataStruct.chamber(cntChambers).sample);
    TimeVector = NaN(nSamples,1);
    for cntSamples = 1:nSamples
        dataStruct.chamber(cntChambers).sample(cntSamples).TimeVector = fr_round_time(dataStruct.chamber(cntChambers).sample(cntSamples).tv,unitsIn,2);
    end
end

%% Pull one chamber out of the structure and convert it
chNum = 1;
c1= dataStruct.chamber(chNum);
out = collapseSamplesWithFlattenedInnerArrays(c1.sample);
% create a list of file names (results{1}.fileName)
% and data arrays (results{1}.data) that go with the names
prefix = sprintf('chamber_%d',chNum);
results = extractLeafArrays(out,prefix);
results{1}

%% Remove all results that contain diagnostic or rawData

ignoreFields = {'configIn','rawData','tv','indexes','quad_B','gof','fCO2','t0All','c0All','coeffAll','dcdtAll','rmseAll'};
%ignoreFields = {'configIn','rawData','tv','indexes','quad_B','gof','t0All','c0All','coeffAll','dcdtAll','rmseAll'};
goodResults = {};
cStr = 0;
for cntResults = 1:length(results)
    if ~contains(results{cntResults}.fileName,ignoreFields)
        cStr = cStr + 1;
        goodResults{cStr} = results{cntResults};
    end
end

k = 0;
for cntResults = 1:length(goodResults)
    if iscell(goodResults{cntResults}.data)
        k = k+1;
        fprintf(2,'%d %s\n',cntResults,goodResults{cntResults}.fileName);
    end
end
if k>0
    fprintf(2,'Found %d data traces that are not 1D (they are struct)\n',k)
else
    fprintf('All data traces contain only 1D data. All OK!\n')
end 

%% Testing the new function that incorporates the above with the 
%  database file saving
chNum = 1;
structIn= dataStruct.chamber(chNum).sample;


pthOut = 'E:\Junk\UdeM_database_test';
verbose_flag = 1;
excludeSubStructures = {'configIn','rawData','tv','indexes','quad_B','gof','fCO2','t0All','c0All','coeffAll','dcdtAll','rmseAll'};
prefix = sprintf('chamber_%d',chNum);
timeUnit = '60min';
missingPointValue = NaN;
UdeM_struct2database(structIn,pthOut,verbose_flag,excludeSubStructures,prefix, timeUnit,missingPointValue)
%[structOut,dbFileNames, dbFieldNames,errCode] = UdeM_struct2database(structIn,pthOut,verbose_flag,excludeSubStructures,prefix, timeUnit,missingPointValue)



