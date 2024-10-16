function data_cleaned = fr_cleaning_siteyear(Year,SiteId,stage,db_ini)
% data_cleaned = fr_cleaning_siteyear(Year,SiteId,stage,db_ini)
%
% Run one stage of cleaning
%
%    fr_automated_cleaning with no arguments runs all stages for all sites 
%    for the current year and exits
% 
%    fr_automated_cleaning(Years,Sites,stages) allows to select Years (vector 
%    of years), Sites (cellstring array) and stages (vector of [1 2 3]). 
%    Defaults are the current year, all sites and all stages.
%    
%    If stages contains a 4 all cleaning stages are run and the data is
%    then exported in FCRN format to \\paoa003\BERMS
%
%    fr_automated_cleaning(Years,Sites,stages,db_out) writes the cleaned data 
%    into a different database with base path db_out. 
%    This option can be used to copy the cleaned database
%    using the standard biomet ini-files
%
%    fr_automated_cleaning(Years,Sites,stages,db_out,db_ini) uses db_ini as
%    a dabase base path to find the inifiles. This allows to update
%    a user specific database in db_out using the inifiles in db_ini and
%    data from the biomet database. 
% 
%    The default input and output database is y:\database on PAOA001 and
%    the biomet_path database on all other PCs. Use biomet_database_default
%    to use a local copy of the database.


% kai* Dec 19, 2007
%
% Revisions:
%
% Aug 14, 2024 (Zoran)
%   - Added year string to SiteId_yyyy_FirstStage_stats.mat otherwise only
%     the last year's data that's been cleaned would be kept.
%   - added testing if single point interpolation is required (globalVars.other.singlePointInterpolation='on')
% Aug 6, 2024 (Zoran)
%   - Added saving the cleaning stats to Derived_Variables folder under
%     SiteId_FirstStage_stats.mat
% May 10, 2024 (Zoran)
%   - Removed some legacy code used to find Database path
%   - Syntax cleanup
% Apr 14, 2024 (Zoran)
%   - added ind_parents to each trace. This indexes should be useful 
%     for troubleshooting of why certain data points were removed by
%     find which parent caused that.
% Apr 11, 2022 (Zoran)
%   - added call to setFolderSeparator() to deal with MacOS paths.
% Apr 22, 2020 (Zoran)
%   - fixed some case sensitive names to make it Matlab 2020 compatible
%     fr_current_siteid -> fr_current_siteID
% dec 19, 2007: db_pth_root used instead of hardwiring db path (Nick)
% Nov 18, 2004
% Added FCRN export
% Oct 21, 2004
% Added HJP75 & FEN
% Sep 09, 2004
% Implemented db_out and db_ini option and use of db_dir_ini

Year_cur = year(datetime);
arg_default('Year',Year_cur(1));
db_pth = db_pth_root;

% Make sure SiteId input exists
arg_default('SiteId','')
if isempty(SiteId)
    error 'SiteId is required when calling fr_cleaning_siteyear!'
end

arg_default('stage',1);
arg_default('db_ini',db_pth);

yy_str = num2str(Year(1));

%------------------------------------------------------------------
% Get ini file names
%------------------------------------------------------------------
pth_proc = setFolderSeparator(fullfile(db_ini,'Calculation_Procedures\TraceAnalysis_ini',SiteId,''));

ini_file_first  = fullfile(pth_proc,[SiteId '_FirstStage.ini']);
ini_file_second = fullfile(pth_proc,[SiteId '_SecondStage.ini']);
ini_file_third  = fullfile(pth_proc,[SiteId '_ThirdStage.ini']);

%------------------------------------------------------------------
% Do first stage cleaning and exporting
%------------------------------------------------------------------
if stage == 1
    % Load first stage manual cleaning results
    mat_file = fullfile(pth_proc,...
        [SiteId '_' num2str(yy_str) '_FirstStage.mat']);
    if exist(mat_file,"file")==2
        mat = load(mat_file);
    else
        mat = [];
    end
    
    data_raw    = read_data(Year(1),SiteId,ini_file_first);
    
    % find dependents to clean
    [data_auto,ct] = find_all_dependent(data_raw);
    % add the field ind_parents to each trace in data_auto
    data_auto = find_all_parents(data_auto);
    % clean dependents
    data_depend = clean_all_dependents(data_auto,[],ct);
    
    % Clean traces
    % Use the optional globalVars.other.singlePointInterpolation to control 
    % the single missing point interpolation.
    if     isfield(data_depend(1).ini,'globalVars') ...
        && isfield(data_depend(1).ini.globalVars,'other') ...
        && isfield(data_depend(1).ini.globalVars.other,'singlePointInterpolation')
        interp_flag = data_depend(1).ini.globalVars.other.singlePointInterpolation;
    else
        interp_flag = 'no_interp';
    end
    data_depend   = clean_traces( data_depend,interp_flag );
    
    if ~isempty(mat)
        %   data_out = compare_trace_str(trace_str,old_structure,lc_path)
        data_cleaned = addManualCleaning(data_depend,mat.trace_str);
    else
        data_cleaned = data_depend;
    end

    % Save cleaning stats under Derived_variables. First remove
    % data fields to save space.    
    data_1st_stage_stats = rmfield(data_cleaned,'DOY');
    data_1st_stage_stats = rmfield(data_1st_stage_stats,'data');
    data_1st_stage_stats = rmfield(data_1st_stage_stats,'data_old');
    data_1st_stage_stats = rmfield(data_1st_stage_stats,'timeVector');
    pth_stats = fullfile(pth_proc,'Derived_Variables',[SiteId '_' yy_str '_FirstStage_stats']);
    save(pth_stats,"data_1st_stage_stats");    
end

%------------------------------------------------------------------
% Do second stage cleaning and exporting
%------------------------------------------------------------------
if stage == 2
    data_cleaned = read_data(Year(1),SiteId,ini_file_second);
end

%------------------------------------------------------------------
% Do third stage automated cleaning and exporting
%------------------------------------------------------------------
if stage == 3
    data_cleaned = read_data(Year(1),SiteId,ini_file_third);
end


