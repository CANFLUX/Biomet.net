# This is our external R script for the analyses being called in the R markdown file

## @knitr LoadData

# Load data
opts_knit$set(root.dir = "C:/Biomet.net/R/data_visualization") # Specify directory

basepath <- "C:/Users/User/PostDoc_Work/database"
yrs <- c(2021:2021) # Make sure to include the most recent year
site <- "BB"
level <- c("Clean/SecondStage","Met/clean")
vars <- c("WD_1_1_1","wind_dir","WS_1_1_1","wind_speed","USTAR","W_SIGMA",
          "ts","TA_1_1_1","TA_1_2_1","air_temperature","air_t_mean","sonic_temperature","RH_1_1_1","RH_1_2_1","RH","e","es","es",
          "SW_IN_1_1_1","SW_OUT_1_1_1","LW_IN_1_1_1","LW_OUT_1_1_1","NETRAD_1_1_1","PPFD_IN_1_1_1","PPFD_OUT_1_1_1",
          "air_pressure","PA_1_1_1",
          "P_1_1_1","G_1_1_1","G_2_1_1","G_3_1_1",
          "TW_1_1_1","TS_1_1_1","TS_1_2_1","TS_1_3_1","WTD_1_1_1", 
          "NEE","FC","H","LE","FCH4")
tv_input <- "clean_tv"

export <- 0 # 1 to save a csv file of the data, 0 otherwise

# load all necessary functions
fx_path <- "C:/Biomet.net/R/data_visualization"
p <- sapply(list.files(pattern="*.R$", path=fx_path, full.names=TRUE), source)

# Load functions from 'database_functions' folder
source("C:/Biomet.net/R/database_functions/read_database.R")

# Create dataframe for years & variables of interest
# Path to function to load data
data1 <- read_database(basepath,yrs,site,level,vars,tv_input,export)

# Load traces just for plotting that aren't in clean
level <- c("Flux")
vars_other <- c("air_temperature","air_t_mean","RH","air_pressure","air_p_mean","pitch",
                "avg_signal_strength_7200_mean","rssi_77_mean","flowrate_mean","file_records","used_records")  
tv_input <- "Clean_tv"
data2 <- read_database(basepath,yrs,site,level,vars_other,tv_input,export)

# Merge dataframes
data <- merge(data1,data2, by=c("datetime"))

if (sum(which(vars %in% colnames(df) == FALSE)) > 0) {
  cat("variables: ", vars[which(vars %in% colnames(data) == FALSE)],"are not included in the dataframe", sep="\n")
}

# Make sure there are no duplicate column names & stop script if there are duplicate names
duplicate <- !duplicated(colnames(data))
ind_duplicate <- which(duplicate==FALSE)

if(length(ind_duplicate) > 0) {
  stop("Make sure to remove duplicate columns names in data dataframe")    
}

# Remove missing data (should be -9999)
data <- replace(data, data == -9999, NA)

# Specify end date if using current year - usually today's date
inde <- which(Sys.Date() == data$datetime)

if (!identical(inde, integer(0))) {
  data <- data[c(1:inde), ] # Remove NaN for dates beyond today's date
} else {
  data <- data[1:nrow(data)-1, ] # Remove the last data point so that the last data point doesn't start the following year.
}

# Create year & DOY column
data$year <- year(data$datetime)
data$DOY <- yday(data$datetime)

# Load third stage fluxes
level <- c("Clean/ThirdStage")
vars_other <- c("NEE","FC","H","LE","FCH4","NEE_PI_F_MDS",
                "FC_PI_F_MDS","H_PI_F_MDS","LE_PI_F_MDS","FCH4_PI_F_MDS","FCH4_PI_F_RF","G_1","NETRAD_1_1_1")
tv_input <- "clean_tv"
data_thirdstage <- read_database(basepath,yrs,site,level,vars_other,tv_input,export)

# Remove missing data (should be -9999)
data_thirdstage <- replace(data_thirdstage, data_thirdstage == -9999, NA)

# Specify end date - usually today's date
inde <- which(Sys.Date() == data_thirdstage$datetime)

if (!identical(inde, integer(0))) {
  data_thirdstage <- data_thirdstage[c(1:inde), ] # Remove NaN for dates beyond today's date
} else {
  data_thirdstage <- data_thirdstage[1:nrow(data_thirdstage)-1, ] # Remove the last data point so that the last data point doesn't start the following year.
}

# Create year & DOY column
data_thirdstage$year <- year(data_thirdstage$datetime)
data_thirdstage$DOY <- yday(data_thirdstage$datetime)

# Specify variables for sonic_plots.R
vars_WS <- c("wind_speed","WS_1_1_1") # Include sonic wind speed first
vars_WD <- c("wind_dir","WD_1_1_1")
vars_other_sonic <- c("USTAR","pitch") # include u* first
units_other_sonic <- c("m/s","degrees")
pitch_ind <- 2

wind_std <- "W_SIGMA"

# Specify variables for temp_RH_data_plotting.R

# Temperature variables
# Make sure that all temperature variables are in the same units (e.g., Celsius)
data$sonic_temperature_C <- data$sonic_temperature-273.15
# data$air_t_mean_C <- data$air_t_mean-273.15
# Filter air_t_mean_C
# data$air_t_mean_C[(data$air_t_mean_C>60 | data$air_t_mean_C< -60) & !is.na(data$air_t_mean_C)] <- NA
# data$air_temperature_C <- data$air_temperature-273.15

# Now specify variables
vars_temp <- c("TA_1_1_1","TA_1_2_1") # Order should be HMP, sonic temperature, 7700 temperature (NOTE - make sure to include sonic temperature!!) - c("AIR_TEMP_2M","sonic_temperature_C","air_t_mean_C")

# RH variables

# Now specify variables
vars_RH <- c("RH_1_1_1","RH_1_2_1") # Order should be HMP then 7200 (CONFIRM SENSORS!)

# Radiation variables
vars_radiometer <- c("SW_IN_1_1_1","SW_OUT_1_1_1","LW_IN_1_1_1","LW_OUT_1_1_1") # note that SW_IN and SW_OUT should always be listed as variables 1 and 2, respectively
vars_NETRAD <- "NETRAD_1_1_1"
vars_PPFD <- c("PPFD_IN_1_1_1","PPFD_OUT_1_1_1") #Note incoming PAR should always be listed first.

# Calculate potential radiation
# define the standard meridian for DSM
Standard_meridian <- -120

# Define long/lat
long <- -122.8942
Lat <- 49.0886

# Calculate potential radiation
data$potential_radiation <- potential_rad_generalized(Standard_meridian,long,Lat,data$datetime,data$DOY)
data$potential_radiation[is.na(data$SW_IN_1_1_1)] <- NA
var_potential_rad <- "potential_radiation"

# Pressure variables
# Make sure that all pressure variables are in the same units (e.g., kPa)
data$air_pressure_kPa <- data$air_pressure/1000
data$air_p_mean_kPa <- data$air_p_mean/1000

#vars_pressure <- c("air_pressure_kPa","air_p_mean_kPa","PA_1_5M","PA_EC_AIR2_5M") # note that 

# Other variables to plot (can also include vegetation indices and water quality data)
# Note that if needed, you can change the line 'Row {data-width=600}' below the line 
# 'Other met {data-orientation=rows}' to better view all the data (i.e., increase the data-width)

# Precip variables
vars_precip <- "P_1_1_1"

# Soil heat flux
vars_G <- c("G_1_1_1","G_2_1_1","G_3_1_1")

vars_WTD <- "WTD_1_1_1"

# Water and soil temperature variables - note go with decreasing height/depth from highest measurement
vars_TS <- c("TW_1_1_1","TS_1_1_1","TS_1_2_1","TS_1_3_1","TS_1_4_1",
             "TS_2_1_1","TS_2_2_1","TS_2_3_1","TS_2_4_1") 

var_other <- list(as.list(vars_G),as.list(vars_precip),as.list(vars_WTD),as.list(vars_TS))
yaxlabel_other <- c("G (W/m2)","Precipiataion (mm)", "Water table depth (m)","Temperature (°C)")

flux_vars <- c("FC","H","LE","FCH4") # List flux variables to plot (to compare Second and Third stages)
flux_vars_gf <- c("NEE_PI_F_MDS","FC_PI_F_MDS","H_PI_F_MDS","LE_PI_F_MDS","FCH4_PI_F_MDS","FCH4_PI_F_RF") # List flux variables to plot (to compare Second and Third stages)

vars_flux_diag <- c("avg_signal_strength_7200_mean","rssi_77_mean","flowrate_mean","file_records","used_records") # This list should be consistent across all sites and the order should be the same

vars_EBC_AE <- c("NETRAD_1_1_1","G_1") # Include all terms for available energy. it should always include net radiation. Other terms to include if available are G, and other key storage terms.
