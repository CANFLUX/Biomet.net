function run_ECCC_climate_station_update(yearsIn,monthsIn,stationIDs,dbase_pth)
% run_ECCC_climate_station_update(yearsIn,monthsIn,stationIDs)
%
% Process ECCC climate station data. 
%
% yearsIn   - range of years to process (default current year)
% monthsIn  - range of months to process (default previous and the current
%             month.
% stationIDs    - a vector of station IDs. They can be found here:
%                 https://drive.google.com/drive/folders/1WJCDEU34c60IfOnG4rv5EPZ4IhhW9vZH
%                 File: "Station Inventory EN.csv"
% dbase_pth     - Optional data base path
%
% Zoran Nesic                   File created:               2022
%                               Last modification:  Nov 21, 2024

% Revisions
%
% Nov 21, 2024 (Zoran)
%   - changed the time period input for db_ECCC_climate_station
%     from a number (60) to a string ('60MIN')
% Aug 1, 2024 (Zoran)
%   - Added Winipeg St. Andrew stations (55463) to the list.
% Sep 11, 2023 (Zoran)
%   - Added Stony Mountain Manitoba weather station to the list of defaults (ID:3678)
% Jun 15, 2023 (Zoran)
%  - Switch to using db_pth_root instead of biomet_database_default. 
%    The new may is more generic and it should always work.
%  - added an optional database path (dbase_pth)
% Nov 29, 2022 (Zoran)
%  - Program now defaults to processing stations:[49088 10927 925 51357 51442]
%    Used to default to 49088 only.
% Oct 19, 2022 (Zoran)
%  - Added a generic option to create a station under yyyy\ECCC\stationID
%    for all new stations except BB (49088) and Hogg (10927)
% Sep 7, 2022 (Zoran)
%  - added input option for stationIDs
%  - added calls for Manitoba station

[yearNow,monthNow,~]= datevec(now);
monthRange = monthNow-1:monthNow;
arg_default('yearsIn',yearNow)
arg_default('monthsIn',monthRange)
arg_default('stationIDs',[49088 10927 925 51357 51442 3678 55463] )
arg_default('dbase_pth',db_pth_root);

for cntStations = 1:length(stationIDs)
    sID = stationIDs(cntStations);
    switch sID
        % case 49088
        %     % Burns Bog station
        %     pathECCC = 'yyyy\BB\Met\ECCC';
        case 10927
            % Hogg station
            pathECCC = 'yyyy\Hogg\Met\ECCC';
        otherwise
            % Group all other stations under \ECCC\stationID
            pathECCC = fullfile('yyyy','ECCC',num2str(sID));
%         otherwise
%             fprintf('station ID out of range!\n');     
%             pathECCC = '';
    end
    if ~isempty(pathECCC)
        try
            db_ECCC_climate_station(yearsIn,monthsIn,sID,...
                                    fullfile(dbase_pth,pathECCC),'60MIN');
        catch
            fprintf('Error processing station: %d (year: %d, month: %d)\n',sID,yearsIn,monthsIn(end));
        end
    end
end