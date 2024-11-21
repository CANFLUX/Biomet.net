# Ini file for HOGG annual uncertainty analysis
# By Sara Knox
# Aug 28, 2022

#paths
fx_path <- "/Users/sara/Code/Biomet.net/R/database_functions/" # Specify path for loading functions
basepath <- "/Users/sara/Library/CloudStorage/OneDrive-McGillUniversity/Database" # Specify base path

# Specify data path, years, level, and variables 
yrs <- c(2021,2022) # for multiple years use c(year1,year2)
site <- "HOGG"
level_in <- "Clean/ThirdStage_REddyProc_RF_Full" #which folder you are loading variables from
vars <- list.files(path = paste(basepath,"/",yrs[1],"/",site,"/",level_in,sep = "")) # Assumes variables are the same for all years
tv_input <- "clean_tv"
start_dates <- c(as.Date("2021-06-01"),as.Date("2022-06-01")) # GENERALIZE TO LOOP OVER MULTIPLE YEARS
end_dates <- c(as.Date("2022-06-01"),as.Date("2023-06-01")) # GENERALIZE TO LOOP OVER MULTIPLE YEARS

# FCH4 uncertainty
FCH4_uncertainty <- 1 # 0 (no) or 1 (yes) to calculate FCH4 uncertainty. Note this can take a while to run.
level_RF_FCH4 <- "clean/ThirdStage" # which folder you are loading variables from for RF gap-filling
# variable we need for FCH4 gap-filling (if implementing)
# FCH4 should be quality controlled. Other variables should be fully gap-filled. Should be the same a the third stage variables
predictors_FCH4 <- c("FCH4", "USTAR","NEE_PI_F_MDS","LE_PI_F_MDS","H_PI_F_MDS","SW_IN_1_1_1","TA_1_1_1","TS_1",
                     "RH_1_1_1","VPD_1_1_1","PA_1_1_1")
plot_RF_results <- 0
export <- 0 # 1 to save a csv file of the data, 0 otherwise
