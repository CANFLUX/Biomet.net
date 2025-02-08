function mergeMicrometDumpAndHF_folders
% mergeMicrometDumpAndHF_folders - it works on NAS folders and does what its name says
%
% NOTE: Year is hard coded for BC sites. Needs to be edited once per year.
%
%
% Zoran Nesic               File created:       Sep 25, 2023
%                           Last modification:  Feb 10, 2024

% Revisions:
%

% BC sites
mergeSmartFluxUSBdata('DSM','2025_Flux');
mergeSmartFluxUSBdata('RBM','2025_Flux');
mergeSmartFluxUSBdata('BB','2025_Flux');
mergeSmartFluxUSBdata('BB2','2025_Flux');

% Manitoba sites
ManitobaSites = {'HOGG','YOUNG','OHM'};

for cntSite = 1:length(ManitobaSites)
    folderToCopy = ['P:\Sites\' char(ManitobaSites(cntSite)) '\HighFrequencyData\raw'];
    mergedDataFolder = ['\\137.82.55.154\highfreq\' char(ManitobaSites(cntSite)) '\raw'];
    fprintf('Merging: %s with %s\n',folderToCopy,mergedDataFolder);        
    cmdStr = sprintf('robocopy %s %s /R:3 /W:3 /E /REG /NDL /NFL /NJH',folderToCopy,mergedDataFolder);
    system(cmdStr);
end