# This is our external R script for the analyses being called in the R markdown file

## @knitr LoadData

# Load data
opts_knit$set(root.dir = "/Users/sara/Code/MLABcode/data_visualization") # Specify directory

basepath <- "/Volumes/GoogleDrive/My Drive/UBC/Micromet Lab/database"
yrs <- c(2019:2022)
site <- "BB2"
level <- "L3"
vars <- c("wind_dir","wind_speed","u_","pitch","year","w_var","WIND_VELOCITY_CUP","WIND_VELOCITY_EC",
          "sonic_temperature","AIR_TEMP_2M","air_temperature","air_t_mean","RH_2M","RH","e","es_x","es_y",
          "SHORTWAVE_IN","SHORTWAVE_OUT","LONGWAVE_IN","LONGWAVE_OUT","NR","INCOMING_PAR","REFLECTED_PAR",
          "air_pressure","air_p_mean","PA_1_5M","PA_EC_AIR2_5M",
          "PRECIP","SHFP_1","SHFP_2","SHFP_3","SVWC",
          "WATER_TEMP_1_5CM","WATER_TEMP_2_5CM","WATER_TEMP_3_5CM",
          "SOIL_TEMP_1_5CM","SOIL_TEMP_1_10CM","SOIL_TEMP_1_30CM","SOIL_TEMP_1_50CM",
          "SOIL_TEMP_2_5CM","SOIL_TEMP_2_10CM","SOIL_TEMP_2_30CM","SOIL_TEMP_2_50CM",
          "SOIL_TEMP_3_5CM","SOIL_TEMP_3_10CM","SOIL_TEMP_3_30CM","SOIL_TEMP_3_50CM")

export <- 0 # 1 to save a csv file of the data, 0 otherwise

# Create dataframe for years & variables of interest
# Path to function to load data
source("/Users/sara/Code/MLABcode/database_functions/read_database.R")

data <- load.export.data(basepath,yrs,site,level,vars,export)

# Make sure there are no duplicate column names & stop script if there are duplicate names
duplicate <- !duplicated(colnames(data))
ind_duplicate <- which(duplicate==FALSE)

if(length(ind_duplicate) > 0) {
  stop("Make sure to remove duplicate columns names in data dataframe")    
}

# Remove missing data (should be -9999)
data <- replace(data, data == -9999, NA)

# Remove empty columns for the end of the year (and start in some cases)
ind <- !is.nan(data$year)
data <- data[ind, ]

# Path to plotting functions
data_visualization_path <- "/Users/sara/Code/MLABcode/data_visualization/"

p <- sapply(list.files(pattern="[.]R$", path=data_visualization_path, full.names=TRUE), source)

# Specify variables for sonic_data_plotting.R
vars_WS <- c("wind_speed","WIND_VELOCITY_CUP") # Include sonic wind speed first
vars_WD <- "wind_dir"
vars_other_sonic <- c("u_","pitch") # include u* (u_) first
units_other_sonic <- c("m/s","degrees")
pitch_ind <- 2

# Specify other sonic variables
wind_variance <- "w_var" # If using all variances, make sure w_var is first

# Specify variables for temp_RH_data_plotting.R

# Temperature variables
# Make sure that all temperature variables are in the same units (e.g., Celsius)
data$sonic_temperature_C <- data$sonic_temperature-273.15
data$air_t_mean_C <- data$air_t_mean-273.15
data$air_temperature_C <- data$air_temperature-273.15

# Now specify variables
vars_temp <- c("AIR_TEMP_2M","sonic_temperature_C","air_t_mean_C") # Order should be HMP, sonic temperature, 7700 temperature

# RH variables

# Now specify variables
vars_RH <- c("RH_2M","RH") # Order should be HMP then 7200

# Radiation variables
vars_radiometer <- c("SHORTWAVE_IN","SHORTWAVE_OUT","LONGWAVE_IN","LONGWAVE_OUT") # note that SW_IN and SW_OUT should always be listed as variables 1 and 2, respectively
vars_NETRAD <- "NR"
vars_PPFD <- c("INCOMING_PAR","REFLECTED_PAR") #Note incoming PAR should always be listed first.

# Pressure variables
# Make sure that all pressure variables are in the same units (e.g., kPa)
data$air_pressure_kPa <- data$air_pressure/1000
data$air_p_mean_kPa <- data$air_p_mean/1000

vars_pressure <- c("air_pressure_kPa","air_p_mean_kPa","PA_1_5M","PA_EC_AIR2_5M") # note that 

# Precip variables
precip <- "PRECIP"

# Soil heat flux
vars_G <- c("SHFP_1","SHFP_2","SHFP_3")

# Volumetric water content
vars_VWC <- "SVWC"

# Water and soil temperature variables - note go with decreasing height/depth from highest measurement
vars_TS <- c("WATER_TEMP_3_5CM","WATER_TEMP_2_5CM","WATER_TEMP_3_5CM",
             "SOIL_TEMP_1_5CM","SOIL_TEMP_1_10CM","SOIL_TEMP_1_30CM","SOIL_TEMP_1_50CM",
             "SOIL_TEMP_2_5CM","SOIL_TEMP_2_10CM","SOIL_TEMP_2_30CM","SOIL_TEMP_2_50CM",
             "SOIL_TEMP_3_5CM","SOIL_TEMP_3_10CM","SOIL_TEMP_3_30CM","SOIL_TEMP_3_50CM") 

# Specify variables for Additional meteorological variables output
var_other <- list(as.list(vars_G),as.list(vars_TS))
yaxlabel_other <- c("G (W/m2)","Temperature (°C)")

# define the standard meridian for Burns Bog
Standard_meridian <- -120

# Define long/lat
long <- -122.9849
Lat <- 49.1293

# Path to function to load data
source("/Users/sara/Code/MLABcode/potential_rad.R")

potential_rad <- potential_rad(Standard_meridian,long,Lat)

df <- data.frame(data$datetime, potential_rad,data$SHORTWAVE_IN)
p <- ggplot() +
  geom_line(data = df, aes(x = data.datetime, y = potential_rad), color = "steelblue") +
  geom_line(data = df, aes(x = data.datetime, y = data.SHORTWAVE_IN), color = "red")

 p <-      ggplotly(p) %>%
    toWebGL()
p

# Compute mean diurnal pattern for 15 day moving window
source("/Users/sara/Code/MLABcode/diurnal_composite_moving_window.R")
diurnal.composite <- diurnal.composite(data$datetime,potential_rad,data$SHORTWAVE_IN,15,48)

p <- ggplot() +
  geom_point(data = diurnal.composite, aes(x = time, y = potential_radiation), color = "steelblue",size = 0.5) +
  geom_point(data = diurnal.composite, aes(x = time, y = SW_IN), color = "red",linetype="dashed",size = 0.5) +
  geom_point(data = diurnal.composite, aes(x = time, y = exceeds), color = "black",size = 0.75)+
  scale_x_datetime(breaks="6 hours", date_labels = "%R")

p <- ggplotly(p+ facet_wrap(~as.factor(firstdate))) %>% toWebGL()
p

# Calculate % of instances when SW_IN > potential_radiation (for daytime only)

# Find daytime indices
ind_day <- which(diurnal.composite$SW_IN > 20)

# Find periods when SW_IN > potential_radiation
ind_exceeds <- which(diurnal.composite$SW_IN[ind_day] > diurnal.composite$potential_radiation[ind_day])

exceeds <- length(ind_exceeds)/length(ind_day)*100

ccf_obj <- ccf(diurnal_composite$potential_radiation, diurnal_composite$SW_IN)

Find_Max_CCF(diurnal_composite$potential_radiation, diurnal_composite$SW_IN)

Find_Max_CCF<- function(a,b)
{
  d <- ccf(a, b, plot = FALSE)
  cor = d$acf[,,1]
  lag = d$lag[,,1]
  res = data.frame(cor,lag)
  res_max = res[which.max(res$cor),]
  return(res_max)
}

# Plot diurnal pattern with moving window
source("/Users/sara/Code/MLABcode/diurnal_pattern_moving_window.R")
diurnal.summary <- diurnal.summary(data$datetime, data$SHFP_1, 30, 48)
diurnal.summary.composite <- diurnal.summary %>%
  group_by(firstdate,HHMM) %>%
  dplyr::summarize(var = median(var, na.rm = TRUE),
                   HHMM = first(HHMM))
diurnal.summary.composite$time <- as.POSIXct(as.character(diurnal.summary.composite$HHMM), format="%R", tz="UTC")

p <- ggplot() +
  geom_point(data = diurnal.summary, aes(x = time, y = var),color = 'Grey',size = 0.1) +
  geom_line(data = diurnal.summary.composite, aes(x = time, y = var),color = 'Black') +
  scale_x_datetime(breaks="6 hours", date_labels = "%R")

p <- ggplotly(p+ facet_wrap(~as.factor(firstdate))) %>% toWebGL()
p

# Long-term trend or step change
p.SW_IN<- ggplot() +
  geom_point(data = data, aes(x = datetime, y = SHORTWAVE_IN),color = 'Grey',size = 0.1)

p.PPFD_IN <- ggplot() +
  geom_point(data = data, aes(x = datetime, y = INCOMING_PAR),color = 'Grey',size = 0.1)

p <- grid.arrange(p.SW_IN, p.PPFD_IN, # Second row with 2 plots in 2 different columns
             nrow = 2)                       # Number of rows

# Specify variables to keep
data_keep_columns <- c("year","SHORTWAVE_IN", "INCOMING_PAR")

df_subset <- data[ ,colnames(data) %in% data_keep_columns]  # Extract columns from data
df <- na.omit(df_subset) # renove NA values

data.by.year.R2 <- df %>%
  group_by(year) %>%
  dplyr::summarize(R2 = cor(SHORTWAVE_IN, INCOMING_PAR)^2)

data.by.year.slope <- df %>%
  group_by(year) %>% # You can add here additional grouping variables if your real data set enables it
  do(mod = lm(SHORTWAVE_IN ~ INCOMING_PAR, data = .)) %>%
  mutate(slope = summary(mod)$coeff[2]) %>%
  select(-mod)

data.by.year <- merge(data.by.year.R2,data.by.year.slope,by="year")

# Create plot of timeseries of R2 and slope
multivariate_comparison_trend(data.by.year)

# Plot data availability
plot_datayear(data)
