# Package names
packages <- c("ggplot2", "dplyr", "shiny", "patchwork", "plotly", "gapminder", "shinycssloaders", "readxl", "stringi", "shinythemes", "cowplot",
              "imager", "naniar", "GGally", "shinydashboard", "tidyr", "tibble", "epitools", "lubridate", "hms", "forecast", "reshape2", 
              "stringr", "data.table", "ggpmisc", "ggrepel")

# Install packages not yet installed
installed_packages <- packages %in% rownames(installed.packages())
if (any(installed_packages == FALSE)) {
  install.packages(packages[!installed_packages])
}

# Packages loading
invisible(lapply(packages, library, character.only = TRUE))

# reactiveConsole(T) # allows the csv file to be used properly
# “install.packages(“igraph”, type=“binary”) - uncomment if receiving a “there is no package called ‘igraph’” error when loading imager
# for imager may need to download quartz to be able to run this library properly (https://www.xquartz.org) & may need to use install.packages("igraph", type="binary")

# List all directories and subdirectories
dir_list <- list.dirs(main_dir,full.names = TRUE,  
                      recursive = TRUE)

# From that list, get site names
dir_length <- lengths(strsplit(dir_list, "/"))
dir_years <- dir_list[grepl("/\\d{4}$", dir_list)] # directories ending with a year.
dir_sites <- list.dirs(dir_years, full.names = TRUE, recursive = FALSE)
sites <- unique(sapply(strsplit(dir_sites, "/"), '[[', length(strsplit(dir_sites, "/")[[1]]))) 

# load all necessary functions
fx_path <- paste0(arg,'functions',sep ="")
p <- sapply(list.files(fx_path,pattern="*.R$", full.names=TRUE), source)

# 2. LOAD DATA ----- 
# Load site data from first site when app initializes 
site <- sites[1]
# Find which years are available
yrs <- yrs_included(basepath,site,level[1])
data <- read_data_all_years(basepath,yrs,site,level,tv_input)
data_units <- var_units(colnames(data),UnitCSVFilePath)

# CREATE DATASET TO PLOT ALL SITES AT ONCE
# Only a few variables
var_of_interest <- c('datetime',
                     'FC', 'FCH4', # Ecosystem productivity and C fluxes
                     'VPD', 'RH',  'TA', 'PPFD_IN', 'SW_IN', # Meteorological variables
                     'USTAR', # Atmospheric stability / roughness length approximation (proxy for 'good' EC conditions)
                     'LE','H', 'NETRAD', 'G' # Surface energy balance
)

data_all <- data.frame()

# Loop through all sites to create a dataframe with data from all sites

for (i in 1:length(sites)) {
  # Open data at site
  site <- sites[i]
  
  yrs <- yrs_included(basepath,site,level)
  
  # Load data
  data_in <- read_data_all_years(basepath,yrs,site,level,tv_input)
  
  cols <- colnames(data_in) # Get column names
  
  # remove HVR qualifiers
  vars <- gsub("_[[:digit:]]", "", cols) 
  colnames(data_in) <- vars
  
  # Create empty column for missing variables of interest
  data_in[var_of_interest[!(var_of_interest %in% vars)]] = NA
  
  # Get index of each column of variable of interest
  indexvar <- c()
  k <- 0
  for (j in 1:length(var_of_interest)) {
    k <- k+1
    indexvar[k] <- which(names(data_in) %in% var_of_interest[j])
  }
  indexvar <- na.omit(indexvar)
  
  data_subset <- data_in[,indexvar]
  
  # Add 'site' variable to dataframe
  data_subset$site <- site
  
  # Merge with other sites
  if (i == 1){
    data_all <- data_subset
  } else {data_all <- merge(data_all, data_subset, all = T)
  }
  
  print(unique(data_subset$site))
}

# Define units for plot with all sites
data_units_all <- var_units(colnames(data_all),UnitCSVFilePath)

# X variable names (all sites)
xvars <- var_of_interest
# Y variable names (all sites)
yvars <- var_of_interest[-length(var_of_interest)]

# Load site coordinates
sites_coordinates <- read_excel(coordinatesXLSXFilePath,sheet=1,col_names= TRUE)

# save data to app folder
save(list = ls(), file = paste0(arg,'data_tmp/all_data.RData',sep =""))
