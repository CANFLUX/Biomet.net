%%
%% test how to convert UdeM chamber results from complex structures to
%  database files

% Load an example data files (1 day of data)
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

%ignoreFields = {'configIn','rawData','tv','indexes','quad_B','gof','fCO2','t0All','c0All','coeffAll','dcdtAll','rmseAll'};
ignoreFields = {'configIn','rawData','tv','indexes','quad_B','gof','t0All','c0All','coeffAll','dcdtAll','rmseAll'};
goodResults = {};
cStr = 0;
for cntResults = 1:length(results)
    if ~contains(results{cntResults}.fileName,ignoreFields)
        cStr = cStr + 1;
        goodResults{cStr} = results{cntResults};
    end
end

for cntResults = 1:length(goodResults)
    if iscell(goodResults{cntResults}.data)
        fprintf(2,'%d %s\n',cntResults,goodResults{cntResults}.fileName);
    end
end


%%
dbFileNames = Test_recursiveStrucFieldNames(out,[],ignoreFields);

length(dbFileNames)

%%

ignoreFields = {'configIn','rawData','indexes','quad_B','t0All','c0All','coeffAll','dcdtAll','rmseAll'};
dbFileNames = Test_recursiveStrucFieldNames(dataStruct.chamber(1),[],ignoreFields);

length(dbFileNames)

%%
In MATLAB how do I go from
s.x(1).t.a = 1;
s.x(1).t.b = 2;
s.x(2).t.a = 3;
s.x(2).t.b = 4;

to

t.a = [1 3];
t.b = [2 4];

%% Using current SAL HHour outputs
load 'T:\Research_Groups\Sean_Smukler\SALdata\GHGdata\SAL Picarro All Data\met-data\hhour\260111.picACS.mat'
% Remove fields that are not used
%ignoreFields = {'DataHF','HhourFileName','Configuration','Chamber'};
ignoreFields = {'DataHF','HhourFileName','Configuration','Picarro','Ambient','Logger'};
for cntFields=1:length(ignoreFields)
    HHour = rmfield(HHour,char(ignoreFields{cntFields}));
end
%%
out = collapseSamplesWithFlattenedInnerArrays(HHour);
% create a list of file names (results{1}.fileName)
% and data arrays (results{1}.data) that go with the names
%prefix = sprintf('chamber_%d',chNum);
prefix = '';
results = extractLeafArrays(out,prefix);
results{1}

