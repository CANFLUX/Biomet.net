# This is our external R script for the analyses being called in the R markdown file

## @knitr LoadData

# Load data
opts_knit$set(root.dir = "/Users/sara/Code/MLABcode/data_visualization") # Specify directory

basepath <- "/Users/sara/Library/CloudStorage/OneDrive-UBC/UBC/database"
yrs <- c(2021:2022)
site <- "DSM"
level <- "Met/clean"
vars_met <- c("TA_1_1_1",'RH_1_1_1','G_1_1_1','SW_IN_1_1_1','SW_IN_1_1_1','LW_IN_1_1_1','LW_OUT_1_1_1','MET_CNR4_Alb_Avg','MET_RainTips_Tot',
          'RAW_RainTips_Tot','MET_WaterCond_Avg','MET_WaterDO_Avg','MET_WaterDO_perc_Avg','MET_WaterLevel_Avg','MET_WaterORP_Avg','MET_SoilT_P2_10cm_Avg',
          'MET_Barom_Press_kPa_Avg')

export <- 0 # 1 to save a csv file of the data, 0 otherwise

# Create dataframe for years & variables of interest
# Path to function to load data
source("/Users/sara/Code/MLABcode/database_functions/read_database.R")

data_met <- load.export.data(basepath,yrs,site,level,vars_met,"clean_tv",export)
           
# plot_ly(data = data, x = ~datetime, y = ~file_records, type = 'scatter', mode = 'lines')

level <- "Flux"
vars_flux <- c('file_records','used_records','spikes_hf','us','flowrate_mean','h2o_mixing_ratio',
          'u_rot','wind_speed','w_var','sonic_temperature',
         'max_wind_speed','w_ts_cov','w_h2o_cov','LE','co2_mole_fraction','h2o_mole_fraction',
         'Tau','ET','rand_err_Tau','rand_err_H','H_strg','co2_v_adv','co2_time_lag','co2_def_timelag',
          'h2o_time_lag','h2o_def_timelag','delta_signal_strength_7200_mean','ch4_spikes',
         'rand_err_Tau','ch4_mole_fraction','ch4_mixing_ratio','ch4_time_lag','air_temperature','sonic_temperature',
         'air_pressure','air_p_mean','water_vapor_density','e','es','air_density','RH','specific_humidity',
         'air_heat_capacity','air_molar_volume','dew_point_mean','Tdew','u_unrot','v_unrot','pitch','TKE',
         'L','zdL','ts','model','x_peak','x_offset','x_10p','x_30p','x_50p','x_70p','x_90p',
         'Tau_scf','H_scf','LE_scf','co2_scf','h2o_scf','ch4_scf','ch4_var','w_ch4_cov','ch4_tc_1_mean',
         'ch4_tc_2_mean','ch4_tc_3_mean','head_detect_LI_7200','t_out_LI_7200','co2_flux','chopper_LI_7200',
         'mean_value_RSSI_LI_7200','top_heater_on_LI_7700','motor_spinning_LI_7700')

export <- 0 # 1 to save a csv file of the data, 0 otherwise

# Create dataframe for years & variables of interest
# Path to function to load data
source("/Users/sara/Code/MLABcode/database_functions/read_database.R")

data_flux <- load.export.data(basepath,yrs,site,level,vars_flux,export)

# plot_ly(data = data_flux, x = ~datetime, y = ~motor_spinning_LI_7700, type = 'scatter', mode = 'lines')
# 
# plot_ly(data = data_flux, x = ~datetime, y = ~t_out_LI_7200, type = 'scatter', mode = 'lines',name = 'MET_HMP_T_2m_Avg') %>% 
#   add_trace(data = data_flux, x = ~datetime, y = ~co2_flux, mode = 'lines',name = 'air_7200') 


