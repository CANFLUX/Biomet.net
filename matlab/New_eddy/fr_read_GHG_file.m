function [EngUnits,Header,tv,dataOut] = fr_read_GHG_file(pathToGHGfile)
% [EngUnits,Header,tv,dataOut] = fr_read_GHG_file(pathToGHGfile)
% 
% Inputs:
%   pathToGHGfile        - file name for Licor GHG file
%
% Outputs:
%   EngUnits            - output data matrix
%   Header              - file header
%   tv                  - datenum time vector
%   dataOut             - output data structure 
%
%
% (c) Zoran Nesic                   File created:       Jan 20, 2022
%                                   Last modification:  Mar  9, 2024
%

% Revisions (last one first):
%
% Mar 9, 2024 (Zoran)
%   - program now automatically detects the date column instead of testing
%     the file name which is unreliable. 
%   - added proper input parameters for fr_read_generic_file(....,'delimitedtext',0,8);
% Jan 26, 2024 (Zoran)
%   - added modifyVarNames = 1 in the call to fr_read_generic_data_file
% Jan 20, 2024 (Zoran)
%   - changed file loading from a custom program to using readtable
% Feb 14, 2023 (Zoran)
%   - added option for the program to find '7z.exe' (if it's available 
%     anywhere on Matlab's path. We keep it under Biomet.net\Matlab\Micromet     
%   - Added a check of OS. This works on PC only!

if ismac
    error('This function supports only Windows OS! For MacOS we need to replace 7z.exe with a MacOS version.')
end

pathToHF = fullfile(tempdir,'MatlabTemp');
if ~exist(pathToHF,'dir')
    mkdir(pathToHF);
end

% create filePath that points to the extraced *.data file
pathToGHGfile = fullfile(pathToGHGfile);                    % make sure the file separator is set properly
[folderPath,fileName,fileExt] = fileparts(pathToGHGfile);
filePath = fullfile(pathToHF,[fileName '.data']);

% Extract GHG data from the compressed files
% Note 7z.exe has to be visible to Matlab (Biomet.net?)
exeFile = which('7z.exe');
if isempty(exeFile)
    error('Cannot find 7z.exe');
end
sCMD = [exeFile ' x ' pathToGHGfile ' -o' pathToHF  ' -r -y'];
[~,~] = dos(sCMD);

% Detect the options to figure out where the date column is
opts = detectImportOptions(filePath,'FileType','delimitedtext');
indDate = find(strcmpi(opts.VariableTypes,'datetime'));
dateColNum = [indDate(1) indDate(1)+1];
timeInputFormat = {[],'HH:mm:ss:SSS'};

[EngUnits,Header,tv,dataOut] = fr_read_generic_data_file(filePath,'caller',[], dateColNum,timeInputFormat,[2 Inf],1,'delimitedtext',0,8);

if exist(pathToHF,'dir')
    rmdir(pathToHF,'s');
end



%% Parts of the old version

% fid = fopen(filePath);
% if fid>0
%     try
%         % first read header only into a string array
%         headerLines = 8;
%         Header = textscan(fid,'%s',headerLines,'Delimiter','\n');
%         varNamesAndUnits = textscan(Header{1}{headerLines},'%s','delimiter','\t');
%         % remove DATAH from the list of names
%         varNamesAndUnits{1}=varNamesAndUnits{1}(2:end);
%         nVariables = length(varNamesAndUnits{1});
%         % extract units from variable names
% %         varNames = zeros(nVariables,1).*[];
% %         varUnits(1:nVariables) = [];
%         varNames = "";
%         varUnits = "";
%         for varCnt = 1:nVariables
%             cVarAndUnits = char(varNamesAndUnits{1}{varCnt});
%             x=regexp(cVarAndUnits,'[^()]*','match');
%             cTmp = deblank(char(x(1)));
%             % replace spaces and '-' in the names with '_'
%             cTmp(strfind(cTmp,' ')) = '_';  
%             varNames(varCnt) =  cTmp;
%             cTmp(strfind(cTmp,'-')) = '_'; 
%             % remove multiple consecutive '_' from the varNames
%             ind = strfind(cTmp,'_');
%             cTmp(ind(diff(ind)==1))=[];
%             % store the name
%             varNames(varCnt) =  cTmp;            
%             if length(x)>1
%                 varUnits(varCnt) = deblank(char(x(2)));            
%             else
%                 varUnits(varCnt) = "";
%             end
%         end
%         % in their wisdom, Matlab people have let multiple traces have
%         % the same names like: CO2 (mmol/m^3)	CO2 (mg/m^3)
%         % but then they do this too: CO2 (umol/mol)	CO2 dry(umol/mol)
%         % Those will be renamed as:
%         % CO2_1 (mmol/m^3)	CO2_2 (mg/m^3) CO2_3 (umol/mol)	CO2 dry(umol/mol)
% 
%         % Renaming fields
%         varNamesUnique = unique(varNames);         % find all unique names            
%         for varCnt = 2:length(varNamesUnique)      % cycle through unique names    
%             indVarName = ismember(varNames,varNamesUnique(varCnt));
%             nNameUsage = sum(indVarName);          % how many times the same name is used
%             if  nNameUsage > 1                     % if the name repeats rename occurancies
%                 ind = find(indVarName);            % find location of the occurancies
%                 for repCnt = 1:nNameUsage          % rename them
%                     varNames(ind(repCnt)) = sprintf('%s_%d',varNamesUnique(varCnt),repCnt);
%                 end
%             end
% 
%         end
%         % prepare format string for loading up the data matrix    
%         formatStr = 'DATA%d%d%d%d%d%s%s';
%         for columnCnt = 1:nVariables-6
%             formatStr = [formatStr ' %f']; %#ok<*AGROW>
%         end
%         % "rewind" the file
%         fseek(fid,0,-1);
%         % load the data
%         c = textscan(fid,formatStr,'headerlines',headerLines,'Delimiter','\t');
%     catch ME
%         c = [];
%         disp(ME)
%     end
%     fclose(fid);
% end



% EngUnits = NaN(length(c{1}),nVariables);
% varOutCnt = 0;
% for varCnt = 1:nVariables
%     fieldName = (varNames(varCnt));
%     dataOut.data.(fieldName) = c{varCnt};
%     if ~(strcmpi(fieldName,'Date') || strcmpi(fieldName,'Time'))
%         varOutCnt = varOutCnt + 1;
%         EngUnits(:,varOutCnt) = double(c{varCnt});
%     end
% end

% % Convert time to datetime
% strDate = [char(dataOut.data.Date) ' '*ones(length(dataOut.data.Date),1) char(dataOut.data.Time)];
% dataOut.data.dtv = datetime(strDate,'inputformat','yyy-MM-dd HH:mm:ss:SSS');
% % add new variable to varNames and varUnits
% dataOut.varNames = varNames;
% dataOut.varNames(length(varNames)+1) = 'dtv';
% dataOut.varUnits = varUnits;
% dataOut.varUnits(length(varUnits)+1) = 'datetime';

% % create EngUnits and tv 
% % for compatibility with Biomet HF data processing files
% tv = datenum(dataOut.data.dtv);



