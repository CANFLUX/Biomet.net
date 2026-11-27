import cdsapi, sys, os, time
from pathlib import Path

# https://cds.climate.copernicus.eu/how-to-api
# Input argument order:
# [0] script; [1] start year; [2] end year; [3] start month; [4] end month
#   [5] latitude; [6] longitude [7] output path [8] single variable [9] ERA5 dataset

month_default = list(("01", "02", "03",
                    "04", "05", "06",
                    "07", "08", "09",
                    "10", "11", "12"))

# Baseline request to be modified by input arguments
request = {
    "variable": ["surface_solar_radiation_downwards"],
    "year": "2024",
    "month": "01",
    "day": [
        "01", "02", "03",
        "04", "05", "06",
        "07", "08", "09",
        "10", "11", "12",
        "13", "14", "15",
        "16", "17", "18",
        "19", "20", "21",
        "22", "23", "24",
        "25", "26", "27",
        "28", "29", "30",
        "31"
    ],
    "time": [
        "00:00", "01:00", "02:00",
        "03:00", "04:00", "05:00",
        "06:00", "07:00", "08:00",
        "09:00", "10:00", "11:00",
        "12:00", "13:00", "14:00",
        "15:00", "16:00", "17:00",
        "18:00", "19:00", "20:00",
        "21:00", "22:00", "23:00"
    ],
    "data_format": "netcdf",
    "download_format": "unarchived",
    "area": [45.75, -110.25, 45.25, -109.75]
}

if len(sys.argv)>1:
    yr_st = int(sys.argv[1])
    yr_end = int(sys.argv[2])
    mnth_st = int(sys.argv[3])
    mnth_end = int(sys.argv[4])
    lat_1 = float(sys.argv[5])
    lat_2 = float(sys.argv[5])
    lon_1 = float(sys.argv[6])
    lon_2 = float(sys.argv[6])
else:
    yr_st = 2021
    yr_end = 2024
    mnth_st = 1
    mnth_end = 12
    lat_1 = 45.1
    lat_2 = 44.9
    lon_1 = -110.1
    lon_2 = -109.9

if len(sys.argv)>8:
    var_str = list([str(sys.argv[8])])
    dataset = str(sys.argv[9])
else:
    # Variable names if single variable not specified as input
    var_str = list(("2m_dewpoint_temperature",
            "2m_temperature",
            "surface_solar_radiation_downwards",
            "total_precipitation",
            "10m_u_component_of_wind",
            "10m_v_component_of_wind"))
    dataset = "reanalysis-era5-land"

if dataset=="reanalysis-era5-land":
    resolution = 0.1
elif dataset=="reanalysis-era5-single-levels":
    resolution = 0.25
    request["product_type"] = "reanalysis"
    
    
# range(start,stop) -> from start to stop, not including stop
year_rng = list(range(yr_st,yr_end+1))

mnth_rng = list(range(mnth_st,mnth_end+1))




#client = cdsapi.Client()
client = cdsapi.Client(wait_until_complete=False, delete=False)
request["area"] = [lat_1+resolution, lon_1-resolution, lat_2-resolution, lon_2+resolution]

for i in range(len(var_str)):
    variable = var_str[i]
    for j in range(len(year_rng)):
        year = str(year_rng[j])
        
        if j==0:
            month = list(range(mnth_st,13))
            month = [str(x) for x in month]
        elif j==(len(year_rng)-1):
            month = list(range(1,mnth_end+1))
            month = [str(x) for x in month]
        else:
            month = list(range(1,13))
            month = [str(x) for x in month]
        
        for k in range(len(month)):
        
            month_str = str(month[k])
            filename = "{v}_{y}_{m}.nc".format(v=variable, y=year, m=month_str)
            out_pth = Path(str(sys.argv[7]))
            target = os.path.join(out_pth, filename)
            request["variable"] = variable
            request["month"] = month_str
            request["year"] = year
            
            fileExists = os.path.isfile(target)
            
            if not fileExists:
                print(f"\nStarting download for {filename} -> {target}")
                result = client.retrieve(dataset, request)
                
                try:
                    result.download(target)
                    print(f"\nFinished download for {filename}")
                    time.sleep(1)
                except:
                    print(f"\nNo data found for {filename} or API error")
            else:
                print(f"\n{target} already exits.")
