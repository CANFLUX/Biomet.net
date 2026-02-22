function db_update_Manitoba_WTD(yearIn,sitesIn)
% Convert Manitoba water table depth files to database (read_bor()) files
%
%
% Zoran Nesic       File created:       Feb 22, 2026
%                   Last modification:  Feb 22, 2026 
% 


% Revisions:
%


    arg_default('yearIn',year(datetime));
    arg_default('sites',{'YOUNG','HOGG','OHM'});
    
    if exist('biomet_sites_default.m','file')
        sitePath = biomet_sites_default;
    else
        sitePath = 'p:\Sites';
    end
    
    missingPointValue = NaN;            % For Micromet sites we'll use NaN to indicate missing values (new feature since Oct 20, 2019)
    
    pth_db = db_pth_root; 
    
    if ~iscellstr(sitesIn) %#ok<ISCLSTR>
        % Assume it is a string with a single SiteId
        sitesIn = cellstr(sitesIn);
    end
    
    for cntYear=1:length(yearIn)
        for cntSites=1:length(sitesIn)
            siteID = char(sitesIn(cntSites));
            fprintf('\n**** Processing WTD for year: %d, Site: %s   *************\n',yearIn(cntYear),siteID);
       
            % Path to Flux Database
            outputPath = fullfile(pth_db,'yyyy',siteID,'Met','WTD');                     
            % Path to the source files
            inputFileName = fullfile(sitePath,siteID,'Met',['WTD_' siteID '_' num2str(yearIn(cntYear)) '.csv']);
            % Process the new files
            structIn = load_WTD_file(yearIn(cntYear),inputFileName);

            db_struct2database(structIn,outputPath,0,[],'30MIN',missingPointValue,1,1);
            fprintf('%s  Processed: %s\n',siteID,inputFileName);
            
        end %j  site counter
        
    end %k   year counter
end


% helper functions
function outStruct = load_WTD_file(yearIn,inputFileName)
    % 1) Read the datetime column as string (text) first
    opts = detectImportOptions(inputFileName, 'Delimiter', ',', 'TextType', 'string');
    % Assume the datetime is in column 2; adjust names/indices as needed
    opts = setvartype(opts, 2, 'string');
    opts = setvartype(opts, 3, 'double');
    T = readtable(inputFileName, opts);
    
    % 2) Convert with two input formats depending on whether time is present
    dt = NaT(height(T),1);
    hasTime = contains(T{:,2}, ':');  % rows that have HH:mm
    
    try
        dt(hasTime)  = datetime(T{hasTime,2}, 'InputFormat','yyyy-MM-dd HH:mm');
        dt(~hasTime) = datetime(T{~hasTime,2}, 'InputFormat','yyyy-MM-dd');
    catch
        dt(hasTime)  = datetime(T{hasTime,2}, 'InputFormat','dd-MM-yyyy HH:mm:ss');
        dt(~hasTime) = datetime(T{~hasTime,2}, 'InputFormat','dd-MM-yyyy');
    end
    % 3) Replace the original text column with the parsed datetime
    T{:,2} = dt;
    TimeVectorIn = datenum(dt);
    WTD = T{:,3};
    tv30minfull = fr_round_time(datenum(yearIn,1,1,0,30,0):1/48:datenum(yearIn+1,1,1))';
    outStruct.WTD = interp1(TimeVectorIn,WTD,tv30minfull);
    outStruct.TimeVector = tv30minfull;
end
