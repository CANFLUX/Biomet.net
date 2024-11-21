# Ini file for DSM annual uncertainty analysis
# By Sara Knox
# Aug 28, 2022

#paths
fx_path <- "/Users/sara/Code/Biomet.net/R/database_functions/" # Specify path for loading functions
basepath <- "/Users/sara/Library/CloudStorage/OneDrive-UBC/UBC/database" # Specify base path

# Specify data path, years, level, and variables 
yrs <- c(2021,2022) # for multiple years use c(year1,year2)
site <- "DSM"
level_in <- "Clean/ThirdStage_REddyProc_RF_Fast" #which folder you are loading variables from
vars <- list.files(path = paste(basepath,"/",yrs[1],"/",site,"/",level_in,sep = "")) # Assumes variables are the same for all years
tv_input <- "DateTime"
start_dates <- as.Date("2021-09-04") # GENERALIZE TO LOOP OVER MULTIPLE YEARS
end_dates <- as.Date("2022-09-04") # GENERALIZE TO LOOP OVER MULTIPLE YEARS

export <- 0 # 1 to save a csv file of the data, 0 otherwise
