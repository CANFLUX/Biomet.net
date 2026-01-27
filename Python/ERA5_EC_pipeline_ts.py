import cdsapi, sys, os, time
# https://cds.climate.copernicus.eu/how-to-api
# Input argument order:
# [0] script; [1] start date; [2] end date; [3] latitude;
#    [4] longitude [5] output path

# Variable names
var_str = list(("2m_dewpoint_temperature",
        "2m_temperature",
        "surface_solar_radiation_downwards",
        "surface_pressure",
        "total_precipitation"))

if len(sys.argv)>1:
    date_st = str(sys.argv[1])
    date_end = str(sys.argv[2])
    lat = float(sys.argv[3])
    lon = float(sys.argv[4])
else:
    date_st = '2020-01-01'
    date_end = '2025-12-31'
    lat = 45.1
    lon = -110.1

dataset = "reanalysis-era5-land-timeseries"
# Dummy request to be modified by input arguments
request = {
    "variable": ["surface_solar_radiation_downwards"],
    "location": {"longitude": -80.6, "latitude": 45.5},
    "date": ["1990-01-01/2026-01-07"],
    "data_format": "netcdf"
}

#client = cdsapi.Client()
client = cdsapi.Client(wait_until_complete=False, delete=False)

# This could be updated so that all variables are downloaded with one API 
#   request instead of one per variable, but it works and the rest of the 
#   pipeline assumes a separate .zip file per variable, so should only be done 
#   if there's some other efficiency gain.
for i in range(len(var_str)):
    variable = var_str[i]
    
    filename = "{v}.zip".format(v=variable)
    out_pth = str(sys.argv[5])
    target = os.path.join(out_pth, filename)
    request["variable"] = variable
    request["location"]["longitude"] = lon
    request["location"]["latitude"] = lat
    request["date"] = date_st + '/' + date_end
            
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
