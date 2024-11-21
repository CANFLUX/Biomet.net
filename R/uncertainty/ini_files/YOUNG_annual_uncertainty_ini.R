# Ini file for HOGG annual uncertainty analysis
# By Sara Knox
# Aug 28, 2022

#paths
fx_path <- "/Users/sara/Code/Biomet.net/R/database_functions/" # Specify path for loading functions
basepath <- "/Users/sara/Library/CloudStorage/OneDrive-McGillUniversity/database" # Specify base path

# Specify data path, years, level, and variables 
yrs <- c(2021,2022) # for multiple years use c(year1,year2)
site <- "YOUNG"
level_in <- "Clean/ThirdStage_REddyProc_RF_Full" #which folder you are loading variables from
vars <- list.files(path = paste(basepath,"/",yrs[1],"/",site,"/",level_in,sep = "")) # Assumes variables are the same for all years
tv_input <- "clean_tv"
start_dates <- as.Date("2021-06-01") # GENERALIZE TO LOOP OVER MULTIPLE YEARS
end_dates <- as.Date("2022-06-01") # GENERALIZE TO LOOP OVER MULTIPLE YEARS

export <- 0 # 1 to save a csv file of the data, 0 otherwise
