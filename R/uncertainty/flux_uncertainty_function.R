# Written to calculate uncertainty for fluxes for annual sums
# Based on 'Aggregating uncertainty to daily and annual values' (see: https://github.com/bgctw/REddyProc/blob/master/vignettes/aggUncertainty.md)
# By Sara Knox
# Aug 26, 2022
# Modified July 11, 2023 to create function and loop over years

# Inputs
# site (all caps). e.g., "HOGG"
# ini_path = path to ini file. e.g., "/Users/sara/Code/Biomet.net/R/uncertainty/ini_files/"


# NOTES:
# 1) Could create as a function
# 2) Generalize to loop over years
# 3) Add daytime partitioning
# 4) Modify for CH4 and check variable names for random error for NEE

# Make sure to create ini file first

output <- function(site,ini_path) {
  
  # Load required libraries
  library("dplyr")
  library("lubridate")
  library("plotly")
  
  # Run ini file first 
  source(paste0(ini_path,site,"_annual_uncertainty_ini.R",sep = ""))
  
  # Read function for loading data
  p <- sapply(list.files(pattern="read_database_generalized.R", path=fx_path, full.names=TRUE), source)
  p <- sapply(list.files(pattern="RF_gf", path=fx_path, full.names=TRUE), source)
  
  # Create data frame for years & variables of interest to import into REddyProc
  df <- read_data_generalized(basepath,yrs,site,level_in,vars,tv_input,export)
  
  # Loop over years
  mean_sdAnnual_gCO2_all <- data.frame()
  mean_sdAnnual_gC_all <- data.frame()
  
  for (i in length(start_dates)) {
    start_ind <- which(df$datetime==start_dates[i])+1 #+1 added to start at 30 min 
    end_ind <- which(df$datetime==end_dates[i])
    data <- df[c(start_ind:end_ind), ]
    
    # NEE uncertainty
    
    # Random error
    # Considering correlations
    
    # REddyProc flags filled data with poor gap-filling by a quality flag in NEE_<uStar>_fqc > 0 but still reports the fluxes. 
    # For aggregation we recommend computing the mean including those gap-filled records, i.e. using NEE_<uStar>_f instead of NEE_orig. 
    # However, for estimating the uncertainty of the aggregated value, the the gap-filled records should not contribute to the reduction of uncertainty due to more replicates.
    # Hence, first we create a column 'NEE_orig_sd' similar to 'NEE_uStar_fsd' but where the estimated uncertainty is set to missing for the gap-filled records.
    data <- data %>% 
      mutate(
        NEE_orig_sd = ifelse(
          is.finite(NEE_uStar_orig), NEE_uStar_fsd, NA), # NEE_orig_sd includes NEE_uStar_fsd only for measured values
        NEE_uStar_fgood = ifelse(
          NEE_uStar_fqc <= 1, is.finite(NEE_uStar_f), NA), # Only include filled values for the most reliable gap-filled observations. Note that is.finite() shouldn't be used here.
        resid = ifelse(NEE_uStar_fqc == 0, NEE_uStar_orig - NEE_uStar_fall, NA)) # quantify the error terms, i.e. data-model residuals (only using observations (i.e., NEE_uStar_fqc == 0 is original data) and exclude also
    # "good" gap-filled data)
    # plot_ly(data = data, x = ~datetime, y = ~NEE_uStar_f, name = 'filled', type = 'scatter', mode = 'markers',marker = list(size = 3)) %>%
    #   add_trace(data = data, x = ~datetime, y = ~NEE_uStar_orig, name = 'orig', mode = 'markers') %>% 
    #   toWebGL()
    
    # visualizing data
    plot_ly(data = data, x = ~datetime, y = ~NEE_U2.5_orig, name = 'U2.5', type = 'scatter', mode = 'markers',marker = list(size = 3)) %>%
      add_trace(data = data, x = ~datetime, y =~NEE_uStar_orig, name = 'uStar', mode = 'markers') %>% 
      add_trace(data = data, x = ~datetime, y =~NEE_U97.5_orig, name = 'U97.5', mode = 'markers') %>% 
      toWebGL()
    
    plot_ly(data = data, x = ~datetime, y = ~NEE_U2.5_fall, name = 'U2.5 fall', type = 'scatter', mode = 'markers',marker = list(size = 3)) %>%
      #add_trace(data = data, x = ~datetime, y =~NEE_U2.5_fall, name = 'U2.5 fall', mode = 'markers') %>% 
      #add_trace(data = data, x = ~datetime, y =~NEE_uStar_f, name = 'uStar fill', mode = 'markers') %>% 
      add_trace(data = data, x = ~datetime, y =~NEE_uStar_fall, name = 'uStar fall', mode = 'markers') %>% 
      #add_trace(data = data, x = ~datetime, y =~NEE_U97.5_f, name = 'U97.5 fill', mode = 'markers') %>% 
      add_trace(data = data, x = ~datetime, y =~NEE_U97.5_fall, name = 'U97.5 fall', mode = 'markers') %>% 
      add_trace(data = data, x = ~datetime, y =~NEE_uStar_orig, name = 'uStar orig', mode = 'markers',marker = list(size = 5)) %>% 
      toWebGL()
    
    autoCorr <- lognorm::computeEffectiveAutoCorr(data$resid)
    nEff <- lognorm::computeEffectiveNumObs(data$resid, na.rm = TRUE)
    c(nEff = nEff, nObs = sum(is.finite(data$resid))) 
    
    # Note, how we used NEE_uStar_f for computing the mean, but NEE_orig_sd instead of NEE_uStar_fsd for computing the uncertainty.
    resRand <- data %>% summarise(
      nRec = sum(is.finite(NEE_orig_sd))
      , NEEagg = mean(NEE_uStar_f, na.rm = TRUE)
      , varMean = sum(NEE_orig_sd^2, na.rm = TRUE) / nRec / (!!nEff - 1)
      , sdMean = sqrt(varMean) 
      , sdMeanApprox = mean(NEE_orig_sd, na.rm = TRUE) / sqrt(!!nEff - 1)
    ) %>% dplyr::select(NEEagg, sdMean, sdMeanApprox)
    
    # can also compute Daily aggregation -> but not done here.
    
    # u* threshold uncertainty
    ind <- which(grepl("NEE_U*", names(data)) & grepl("_f$", names(data)))
    column_name <- names(data)[ind] 
    
    #calculate column means of specific columns
    NEEagg <- colMeans(data[ ,column_name], na.rm=T)
    
    #compute uncertainty across aggregated values
    sdNEEagg_ustar <- sd(NEEagg)
    
    # Combined aggregated uncertainty
    
    #Assuming that the uncertainty due to unknown u*threshold is independent from the random uncertainty, the variances add.
    NEE_sdAnnual <- data.frame(
      sd_NEE_Rand = resRand$sdMean,
      sd_NEE_Ustar = sdNEEagg_ustar,
      sd_NEE_Comb = sqrt(resRand$sdMean^2 + sdNEEagg_ustar^2) 
    )
    
    data.mean_NEE_uStar_f <- data.frame(mean(data$NEE_uStar_f, na.rm = TRUE))
    colnames(data.mean_NEE_uStar_f) <- 'mean_NEE_uStar_f'
    NEE_sdAnnual <- cbind(data.mean_NEE_uStar_f,NEE_sdAnnual)
    
    # GPP uncertainty (only u* for now) 
    
    # Nighttime
    ind <- which(grepl("GPP_U*", names(data)) & grepl("_f$", names(data)))
    column_name <- names(data)[ind] 
    
    #calculate column means of specific columns
    GPPagg_NT <- colMeans(data[ ,column_name], na.rm=T)
    
    #compute uncertainty across aggregated values
    sd_GPP_Ustar_NT<- sd(GPPagg_NT)
    sd_GPP_Ustar_NT <- data.frame(sd_GPP_Ustar_NT)
    
    # Daytime
    ind <- which(grepl("GPP_DT*", names(data)) & !grepl("_SD$", names(data)))
    column_name <- names(data)[ind] 
    
    #calculate column means of specific columns
    GPPagg_DT <- colMeans(data[ ,column_name], na.rm=T)
    
    #compute uncertainty across aggregated values
    sd_GPP_Ustar_DT<- sd(GPPagg_DT)
    sd_GPP_Ustar_DT <- data.frame(sd_GPP_Ustar_DT)
    
    # Reco uncertainty (only u* for now)
    
    # Nighttime
    # Rename column names to compute uncertainty
    col_indx <- grep(pattern = '^Reco_U.*', names(data))
    for (i in 1:length(col_indx)) {
      colnames(data)[col_indx[i]] <-
        paste(colnames(data)[col_indx[i]], "_f", sep = "")
    }
    
    ind <- which(grepl("Reco_U*", names(data)) & grepl("_f$", names(data)))
    column_name <- names(data)[ind] 
    
    #calculate column means of specific columns
    Recoagg_NT <- colMeans(data[ ,column_name], na.rm=T)
    
    #compute uncertainty across aggregated values
    sd_Reco_Ustar_NT <- sd(Recoagg_NT)
    sd_Reco_Ustar_NT <- data.frame(sd_Reco_Ustar_NT)
    
    # Daytime
    ind <- which(grepl("Reco_DT*", names(data)) & !grepl("_SD$", names(data)))
    column_name <- names(data)[ind] 
    
    #calculate column means of specific columns
    Recoagg_DT <- colMeans(data[ ,column_name], na.rm=T)
    
    #compute uncertainty across aggregated values
    sd_Reco_Ustar_DT<- sd(Recoagg_DT)
    sd_Reco_Ustar_DT <- data.frame(sd_Reco_Ustar_DT)
    
    # Create output data frame
    mean_sdAnnual <- NEE_sdAnnual %>%
      mutate(mean_GPP_uStar_f = mean(data$GPP_uStar_f, na.rm = TRUE),
             sd_GPP_Ustar_NT = sd_GPP_Ustar_NT,
             mean_Reco_uStar_f = mean(data$Reco_uStar, na.rm = TRUE),
             sd_Reco_Ustar_NT = sd_Reco_Ustar_NT,
             mean_GPP_DT_uStar = mean(data$GPP_DT_uStar, na.rm = TRUE),
             sd_GPP_Ustar_DT = sd_GPP_Ustar_DT,
             mean_Reco_DT_uStar = mean(data$Reco_DT_uStar, na.rm = TRUE),
             sd_Reco_Ustar_DT = sd_Reco_Ustar_DT)
    mean_sdAnnual
    
    # Run USTAR & gap-filling uncertainty for FCH4
    
    # FCH4 uncertainty
    
    # Random error
    # Considering correlations
    
    # REddyProc flags filled data with poor gap-filling by a quality flag in NEE_<uStar>_fqc > 0 but still reports the fluxes. 
    # For aggregation we recommend computing the mean including those gap-filled records, i.e. using NEE_<uStar>_f instead of NEE_orig. 
    # However, for estimating the uncertainty of the aggregated value, the the gap-filled records should not contribute to the reduction of uncertainty due to more replicates.
    # Hence, first we create a column 'NEE_orig_sd' similar to 'NEE_uStar_fsd' but where the estimated uncertainty is set to missing for the gap-filled records.
    data <- data %>% 
      mutate(
        NEE_orig_sd = ifelse(
          is.finite(NEE_uStar_orig), NEE_uStar_fsd, NA), # NEE_orig_sd includes NEE_uStar_fsd only for measured values
        NEE_uStar_fgood = ifelse(
          NEE_uStar_fqc <= 1, is.finite(NEE_uStar_f), NA), # Only include filled values for the most reliable gap-filled observations. Note that is.finite() shouldn't be used here.
        resid = ifelse(NEE_uStar_fqc == 0, NEE_uStar_orig - NEE_uStar_fall, NA)) # quantify the error terms, i.e. data-model residuals (only using observations (i.e., NEE_uStar_fqc == 0 is original data) and exclude also
    # "good" gap-filled data)
    # plot_ly(data = data, x = ~datetime, y = ~NEE_uStar_f, name = 'filled', type = 'scatter', mode = 'markers',marker = list(size = 3)) %>%
    #   add_trace(data = data, x = ~datetime, y = ~NEE_uStar_orig, name = 'orig', mode = 'markers') %>% 
    #   toWebGL()
    
    # visualizing data
    plot_ly(data = data, x = ~datetime, y = ~NEE_U2.5_orig, name = 'U2.5', type = 'scatter', mode = 'markers',marker = list(size = 3)) %>%
      add_trace(data = data, x = ~datetime, y =~NEE_uStar_orig, name = 'uStar', mode = 'markers') %>% 
      add_trace(data = data, x = ~datetime, y =~NEE_U97.5_orig, name = 'U97.5', mode = 'markers') %>% 
      toWebGL()
    
    plot_ly(data = data, x = ~datetime, y = ~NEE_U2.5_fall, name = 'U2.5 fall', type = 'scatter', mode = 'markers',marker = list(size = 3)) %>%
      #add_trace(data = data, x = ~datetime, y =~NEE_U2.5_fall, name = 'U2.5 fall', mode = 'markers') %>% 
      #add_trace(data = data, x = ~datetime, y =~NEE_uStar_f, name = 'uStar fill', mode = 'markers') %>% 
      add_trace(data = data, x = ~datetime, y =~NEE_uStar_fall, name = 'uStar fall', mode = 'markers') %>% 
      #add_trace(data = data, x = ~datetime, y =~NEE_U97.5_f, name = 'U97.5 fill', mode = 'markers') %>% 
      add_trace(data = data, x = ~datetime, y =~NEE_U97.5_fall, name = 'U97.5 fall', mode = 'markers') %>% 
      add_trace(data = data, x = ~datetime, y =~NEE_uStar_orig, name = 'uStar orig', mode = 'markers',marker = list(size = 5)) %>% 
      toWebGL()
    
    autoCorr <- lognorm::computeEffectiveAutoCorr(data$resid)
    nEff <- lognorm::computeEffectiveNumObs(data$resid, na.rm = TRUE)
    c(nEff = nEff, nObs = sum(is.finite(data$resid))) 
    
    # Note, how we used NEE_uStar_f for computing the mean, but NEE_orig_sd instead of NEE_uStar_fsd for computing the uncertainty.
    resRand <- data %>% summarise(
      nRec = sum(is.finite(NEE_orig_sd))
      , NEEagg = mean(NEE_uStar_f, na.rm = TRUE)
      , varMean = sum(NEE_orig_sd^2, na.rm = TRUE) / nRec / (!!nEff - 1)
      , sdMean = sqrt(varMean) 
      , sdMeanApprox = mean(NEE_orig_sd, na.rm = TRUE) / sqrt(!!nEff - 1)
    ) %>% dplyr::select(NEEagg, sdMean, sdMeanApprox)
    
    # can also compute Daily aggregation -> but not done here.
    
    if (FCH4_uncertainty == 1) {
      
      # Load variables for gap-filling
      # Create data frame for years & variables of interest to import into REddyProc
      df_FCH4 <- read_data_generalized(basepath,yrs,site,level_RF_FCH4,predictors_FCH4,tv_input,export)
      
      df_FCH4 <- df_FCH4[c(start_ind:end_ind), ]
      
      ind <- which(grepl("FCH4_U*", names(data)) & grepl("_orig", names(data)))
      column_name <- names(data)[ind] 
      
      # Create empty dataframe 
      df_gap_filled_FCH4 <- data.frame(matrix(nrow = nrow(df_FCH4), ncol = length(column_name)))
      colnames(df_gap_filled_FCH4) <- column_name
      for (j in 1:length(ind)){ 
        
        # Create new data frame for each USTAR threshold + variables used for gap-filling
        data_RF <- cbind(df_FCH4[,1],data[,ind[j]],df_FCH4[,c(3:length(df_FCH4))])
        colnames(data_RF)[c(1,2)] <- c('datetime','FCH4')
        datetime <- df_FCH4$datetime
        
        gap_filled_FCH4 <- RF_gf(data_RF,predictors_FCH4[1],predictors_FCH4,plot_RF_results,datetime)
        
        df_gap_filled_FCH4[,j] <- gap_filled_FCH4[,1]
      }
    }
    
    #PLOT ALL ROWS! then calc uncertainty
    #calculate column means of specific columns
    FCH4agg <- colMeans(data[ ,column_name], na.rm=T)
    
    #compute uncertainty across aggregated values
    sdFCH4agg_ustar <- sd(FCH4agg)
    
    # Combined aggregated uncertainty
    
    #Assuming that the uncertainty due to unknown u*threshold is independent from the random uncertainty, the variances add.
    FCH4_sdAnnual <- data.frame(
      sd_NEE_Rand = resRand$sdMean,
      sd_NEE_Ustar = sdFCH4agg_ustar,
      sd_NEE_Comb = sqrt(resRand$sdMean^2 + sdNEEagg_ustar^2) 
    )
    
    data.mean_NEE_uStar_f <- data.frame(mean(data$NEE_uStar_f, na.rm = TRUE))
    colnames(data.mean_NEE_uStar_f) <- 'mean_NEE_uStar_f'
    NEE_sdAnnual <- cbind(data.mean_NEE_uStar_f,NEE_sdAnnual)
    
    # Convert to annual sums
    conv_gCO2 <- 1/(10^6)*44.01*60*60*24*length(data$NEE_uStar_f)/48 # Converts umol to mol, mol to gCO2, x seconds in a year
    conv_gC <- 1/(10^6)*12.011*60*60*24*length(data$NEE_uStar_f)/48 # Converts umol to mol, mol to gCO2, x seconds in a year
    
    # g CO2
    mean_sdAnnual_gCO2 <- mean_sdAnnual*conv_gCO2
    mean_sdAnnual_gCO2
    
    mean_sdAnnual_gCO2_all <- rbind(mean_sdAnnual_gCO2_all,mean_sdAnnual_gCO2)
    
    # g C
    mean_sdAnnual_gC <- mean_sdAnnual*conv_gC
    mean_sdAnnual_gC
    mean_sdAnnual_gC_all <- rbind(mean_sdAnnual_gC_all,mean_sdAnnual_gC)
  }
  
  # List output!
}
