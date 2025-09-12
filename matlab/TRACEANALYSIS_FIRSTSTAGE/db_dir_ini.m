function db_dir_ini(years,SiteId,base_dir,stages,dir,use_yaml)
% db_dir_ini - Generate empty clean database structure
% 
% db_dir_ini(years,SiteId,base_dir) Makes all necessary directories
% putting years into basedir if the directories exist in the biomet
% database. If a directory already exists its contents are deleted.
%
% db_dir_ini(years,SiteId,base_dir,stages), where stages can be a vector
% with elements 1 2 and 3, creates/deletes only the dir structure for the
% stages listed in the vector
%
% db_dir_ini(years,SiteId,base_dir,3,dir), where dir is a string containing
% a directory name, creates/deletes this directory in the database 
% structure as a third-stage output directory. The dir argument will be
% ignored for stages other than 3 

% Revisions
%
% Jan 25, 2023 (Zoran)
%   - Added standard db_pth_root function instead of 3-line hack below
%   - fixed the bug created in the previous revision (20220921) that stopped creation
%     of the missing SecondStage and ThirdStage folders (they need to be
%     created if they don't exist).
%   - automated cleaning of the FirstStage Clean folders. Program now find
%     which folders to empty based on the FirstStage ini files not on the 
%     hardcoded entries here.
% 

arg_default('stages',[1 2 3]);
arg_default('dir','');
arg_default('use_yaml',false)

% db_pth = biomet_path('1111','xx');
% ind = find(db_pth == filesep);
% db_pth = db_pth(1:ind(end-2));
db_pth = db_pth_root;

for currentYear = years

    yyyy = num2str(currentYear);

   if find(stages == 1)
        % Find folders to empty based on the ones actually used in the ini files
        foldersToClean = db_find_folders_to_clean(currentYear,SiteId,1,use_yaml);
        for cntFolders = 1:length(foldersToClean)
            do_dir(db_pth,base_dir,char(foldersToClean(cntFolders)));
        end
                % The above replaces all these lines for the past, the present and the
                % future sites:
                % 
                %         do_dir(db_pth,base_dir,fullfile(yyyy,SiteId,'Flux','Clean'));  
                %         if ismember(SiteId,{'MPB1','MPB2','MPB3','HP09','HP11'})
                %            do_dir(db_pth,base_dir,fullfile(yyyy,SiteId,'Flux_Logger','Clean')); 
                %         end
                %         if ismember(SiteId,{'BB','BB2','DSM','RBM','HOGG','YOUNG'})
                %            do_dir(db_pth,base_dir,fullfile(yyyy,SiteId,'Met','Clean'));
                %         else
                %            do_dir(db_pth,base_dir,fullfile(yyyy,SiteId,'Climate','Clean'));
                %            do_dir(db_pth,base_dir,fullfile(yyyy,SiteId,'Profile','Clean'));
                %         end       
   end
   
   if find(stages == 2)
       do_dir(db_pth,base_dir,fullfile(yyyy,SiteId,'Clean','SecondStage')); 
   end
   
   if find(stages == 3)
       if isempty(dir)
           do_dir(db_pth,base_dir,fullfile(yyyy,SiteId,'Clean','ThirdStage')); 
       else
           do_dir([],base_dir,fullfile(yyyy,SiteId,'Clean',dir)); 
       end
   end
   
end

function do_dir(db_pth,base_dir,pth)
% db_pth   - input database (used to test existance of dir)
% base_dir - output database
% pth      - relative path in database to be initialized

% If input database has the pth OR if input and output are the same, initialize
% On paoa001 input is \\annex001\database, output is Y:\database
% On all other computers, default in and out is \\annex001, which is read-only and 
% won't work.

% 20230125 (Zoran)
%   - changed 
%      strcmpi(db_pth,base_dir) 
%     to
%      strcmpi(fullfile(db_pth,filesep),fullfile(base_dir,filesep)) 
%     Fixed bug that made the db_pth ~= base_dir look different if one of them
%     but not both had a filesep at the end.
%     This bug was created after 20220921 revision.
%
% 20220921 (Zoran)
% Removed the following lines. Not needed when using fullfile but causing trouble
% on MacOS by adding the wrong filesep ('\').
% if base_dir(end) ~= '\'
%     base_dir = [base_dir '\'];
% end
% if db_pth(end) ~= '\'
%     db_pth = [db_pth '\'];
% end

if  isempty(db_pth) ...
  || exist(fullfile(db_pth,pth),'file')==7 ...
  || strcmpi(fullfile(db_pth,filesep),fullfile(base_dir,filesep)) 
  % Using fullfile(db_pth,filesep) adds filesep at the end of the
  % string but only if needed. That enables comparison db_pth == base_dir
        if exist(fullfile(base_dir,pth),'file')==7
            warning off;
            delete(fullfile(base_dir,pth,'*'));
            warning on;
            disp(['Deleted contents of ' fullfile(base_dir,pth)]);
        else
            mkdir(base_dir,pth)
            disp(['Created ' fullfile(base_dir,pth)]);
        end
end

