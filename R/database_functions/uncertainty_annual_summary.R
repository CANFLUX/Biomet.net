# Written to calculate uncertainty for fluxes for annual sums
# Based on 'Aggregating uncertainty to daily and annual values' (see: https://github.com/bgctw/REddyProc/blob/master/vignettes/aggUncertainty.md)
# By Sara Knox
# Aug 26, 2022
# Modified July 11, 2023 to create function and loop over years
# Modified Nov, 2024 to include in third stage

# NOTE: It's calculated with var_orig as default for consistency with different re-run (so that we always use the same variable to compare annual sums)

# To do:
# Add RF (MDS)

uncertainty_annual_summary <- function(data,NEE_var,LE_var,H_var,AE_var,H_LE_var) {
  #browser()
  # Update names for subset and save to main third stage folder
  siteID <- config$Metadata$siteID
  level_out <- config$Database$Paths$AnnualSummary
  tv_input <- config$Database$Timestamp$name
  db_root <- config$Database$db_root
  
  # Join the incoming data to the inputs incase needed for future use (e.g., ReddyPro outputs in RF)
  #input_data <- input_data %>% left_join(., data, by = c('DateTime' = 'DateTime'))
  
  # Loop over years
  for (year in config$years){
    print(sprintf('Uncertainty for %i',year))
    # Create new directory, or clear existing directory
    dpath <- file.path(db_root,as.character(year),siteID) 
    if (!dir.exists(file.path(dpath,level_out))) {
      dir.create(file.path(dpath,level_out), showWarnings = FALSE)
    }
    
    #df <- data[data$Year.x == year, ]
    df <- data[data$Yearx == year, ]
    
    # NEE uncertainty
    
    # Random error
    
    # Considering correlations
    
    # REddyProc flags filled data with poor gap-filling by a quality flag in NEE_<uStar>_fqc > 0 but still reports the fluxes. 
    # For aggregation we recommend computing the mean including those gap-filled records, i.e. using NEE_<uStar>_f instead of NEE_orig. 
    # However, for estimating the uncertainty of the aggregated value, the the gap-filled records should not contribute to the reduction of uncertainty due to more replicates.
    # Hence, first we create a column 'NEE_orig_sd' similar to 'NEE_uStar_fsd' but where the estimated uncertainty is set to missing for the gap-filled records.
    df <- df %>% 
      mutate(
        NEE_orig_sd = ifelse(
          is.finite(.data[[paste0(NEE_var, "_orig")]]), 
          .data[[paste0(NEE_var, "_fsd")]], 
          NA
        ), # NEE_orig_sd includes NEE_uStar_fsd only for measured values - REPLACE with more generic name
        NEE_fgood = ifelse(
          .data[[paste0(NEE_var, "_fqc")]] <= 1, 
          is.finite(.data[[paste0(NEE_var, "_f")]]), 
          NA
        ), # Only include filled values for the most reliable gap-filled observations. Note that is.finite() shouldn't be used here.
        resid = ifelse(
          .data[[paste0(NEE_var, "_fqc")]] == 0, 
          .data[[paste0(NEE_var, "_orig")]] - .data[[paste0(NEE_var, "_fall")]], 
          NA
        )) # quantify the error terms, i.e. data-model residuals (only using observations (i.e., NEE_uStar_fqc == 0 is original data) and exclude also
    # "good" gap-filled data)
    
    # Plots to visualize the data
    #plot_ly(data = df, x = ~DateTime, y = ~NEE_PI_SC_JSZ_MAD_RP_uStar_f, name = 'filled', type = 'scatter', mode = 'markers',marker = list(size = 3)) %>%
    #  add_trace(data = df, x = ~DateTime, y = ~NEE_PI_SC_JSZ_MAD_RP_uStar_orig, name = 'orig', mode = 'markers') %>% 
    #  toWebGL()
    
    # visualizing data
    #plot_ly(data = df, x = ~DateTime, y = ~NEE_PI_SC_JSZ_MAD_RP_U2.5_orig, name = 'U2.5', type = 'scatter', mode = 'markers',marker = list(size = 3)) %>%
    #  add_trace(data = df, x = ~DateTime, y = ~NEE_PI_SC_JSZ_MAD_RP_uStar_orig, name = 'uStar', mode = 'markers') %>% 
    #  add_trace(data = df, x = ~DateTime, y = ~NEE_PI_SC_JSZ_MAD_RP_U97.5_orig, name = 'U97.5', mode = 'markers') %>% 
    #  toWebGL()
    
    #plot_ly(data = df, x = ~DateTime, y = ~NEE_PI_SC_JSZ_MAD_RP_U2.5_fall, name = 'U2.5 fall', type = 'scatter', mode = 'markers',marker = list(size = 3)) %>%
    #add_trace(data = data, x = ~datetime, y =~NEE_U2.5_fall, name = 'U2.5 fall', mode = 'markers') %>% 
    #add_trace(data = data, x = ~datetime, y =~NEE_uStar_f, name = 'uStar fill', mode = 'markers') %>% 
    #  add_trace(data = df, x = ~DateTime, y =~NEE_PI_SC_JSZ_MAD_RP_uStar_fall, name = 'uStar fall', mode = 'markers') %>% 
    #add_trace(data = df, x = ~datetime, y =~NEE_U97.5_f, name = 'U97.5 fill', mode = 'markers') %>% 
    #   add_trace(data = df, x = ~DateTime, y =~NEE_PI_SC_JSZ_MAD_RP_U97.5_fall, name = 'U97.5 fall', mode = 'markers') %>% 
    #   add_trace(data = df, x = ~DateTime, y =~NEE_PI_SC_JSZ_MAD_RP_uStar_orig, name = 'uStar orig', mode = 'markers',marker = list(size = 5)) %>% 
    #   toWebGL()
    
    autoCorr <- lognorm::computeEffectiveAutoCorr(df$resid)
    nEff <- lognorm::computeEffectiveNumObs(df$resid, na.rm = TRUE)
    c(nEff = nEff, nObs = sum(is.finite(df$resid))) 
    
    # Update the summarise function to use dynamic column names
    resRand <- df %>% summarise(
      nRec = sum(is.finite(NEE_orig_sd)),
      NEEagg = mean(.data[[paste0(NEE_var, "_f")]], na.rm = TRUE),
      varMean = sum(NEE_orig_sd^2, na.rm = TRUE) / nRec / (!!nEff - 1),
      sdMean = sqrt(varMean),
      sdMeanApprox = mean(NEE_orig_sd, na.rm = TRUE) / sqrt(!!nEff - 1)
    ) %>% dplyr::select(NEEagg, sdMean, sdMeanApprox)
    
    # can also compute Daily aggregation -> but not done here.
    
    # u* threshold uncertainty
    ind <- which(grepl(paste0(gsub("_uStar$", "", NEE_var),"_U*"), names(df)) & grepl("_f$", names(df)))
    column_name <- names(df)[ind] 
    
    #calculate column means of specific columns
    NEEagg <- colMeans(df[ ,column_name], na.rm=T)
    
    #compute uncertainty across aggregated values
    sdNEEagg_ustar <- sd(NEEagg)
    
    # Combined aggregated uncertainty
    
    #Assuming that the uncertainty due to unknown u*threshold is independent from the random uncertainty, the variances add.
    NEE_sdAnnual <- data.frame(
      sd_NEE_Rand = resRand$sdMean,
      sd_NEE_Ustar = sdNEEagg_ustar,
      sd_NEE_Comb = sqrt(resRand$sdMean^2 + sdNEEagg_ustar^2) 
    )
    
    mean_column_name <- paste0(NEE_var, "_f")
    
    # Calculate the mean and store it in a data frame
    df.mean_NEE_f <- data.frame(mean(df[[mean_column_name]], na.rm = TRUE))
    colnames(df.mean_NEE_f) <- paste0("mean_", mean_column_name)
    
    NEE_sdAnnual <- cbind(df.mean_NEE_f,NEE_sdAnnual)
    
    # GPP uncertainty (only u* for now) 
    
    # Nighttime
    ind <- which(grepl("GPP_U*", names(df)) & grepl("_f$", names(df)))
    column_name <- names(df)[ind] 
    
    #calculate column means of specific columns
    GPPagg_NT <- colMeans(df[ ,column_name], na.rm=T)
    
    #compute uncertainty across aggregated values
    sd_GPP_Ustar_NT<- sd(GPPagg_NT)
    sd_GPP_Ustar_NT <- data.frame(sd_GPP_Ustar_NT)
    
    # Daytime
    ind <- which(grepl("GPP_DT*", names(df)) & !grepl("_SD$", names(df)))
    column_name <- names(df)[ind] 
    
    #calculate column means of specific columns
    GPPagg_DT <- colMeans(df[ ,column_name], na.rm=T)
    
    #compute uncertainty across aggregated values
    sd_GPP_Ustar_DT<- sd(GPPagg_DT)
    sd_GPP_Ustar_DT <- data.frame(sd_GPP_Ustar_DT)
    
    # Reco uncertainty (only u* for now)
    
    # Nighttime
    # Rename column names to compute uncertainty
    col_indx <- grep(pattern = '^Reco_U.*', names(df))
    for (i in 1:length(col_indx)) {
      colnames(df)[col_indx[i]] <-
        paste(colnames(df)[col_indx[i]], "_f", sep = "")
    }
    
    ind <- which(grepl("Reco_U*", names(df)) & grepl("_f$", names(df)))
    column_name <- names(df)[ind] 
    
    #calculate column means of specific columns
    Recoagg_NT <- colMeans(df[ ,column_name], na.rm=T)
    
    #compute uncertainty across aggregated values
    sd_Reco_Ustar_NT <- sd(Recoagg_NT)
    sd_Reco_Ustar_NT <- data.frame(sd_Reco_Ustar_NT)
    
    # Daytime
    ind <- which(grepl("Reco_DT*", names(df)) & !grepl("_SD$", names(df)))
    column_name <- names(df)[ind] 
    
    #calculate column means of specific columns
    Recoagg_DT <- colMeans(df[ ,column_name], na.rm=T)
    
    #compute uncertainty across aggregated values
    sd_Reco_Ustar_DT<- sd(Recoagg_DT)
    sd_Reco_Ustar_DT <- data.frame(sd_Reco_Ustar_DT)
    
    # Create output data frame
    mean_sdAnnual <- NEE_sdAnnual %>%
      mutate(mean_GPP_uStar_f = mean(df$GPP_uStar_f, na.rm = TRUE),
             sd_GPP_Ustar_NT = sd_GPP_Ustar_NT,
             mean_Reco_uStar_f = mean(df$Reco_uStar, na.rm = TRUE),
             sd_Reco_Ustar_NT = sd_Reco_Ustar_NT,
             mean_GPP_DT_uStar = mean(df$GPP_DT_uStar, na.rm = TRUE),
             sd_GPP_Ustar_DT = sd_GPP_Ustar_DT,
             mean_Reco_DT_uStar = mean(df$Reco_DT_uStar, na.rm = TRUE),
             sd_Reco_Ustar_DT = sd_Reco_Ustar_DT)
    mean_sdAnnual
    
    # Convert to annual sums
    conv_gCO2 <- 1/(10^6) * 44.01 * 60 * 60 * 24 * length(df[[paste0(NEE_var, "_f")]]) / 48 # Converts umol to mol, mol to gCO2, x seconds in a year
    conv_gC <- 1/(10^6) * 12.011 * 60 * 60 * 24 * length(df[[paste0(NEE_var, "_f")]]) / 48 # Converts umol to mol, mol to gC, x seconds in a year
    # g CO2
    
    mean_sdAnnual_gCO2 <- mean_sdAnnual*conv_gCO2
    mean_sdAnnual_gCO2
    
    # g C
    mean_sdAnnual_gC <- mean_sdAnnual*conv_gC
    mean_sdAnnual_gC
    
    mean_sdAnnual_gC$year <- year # Add year
    mean_sdAnnual_gC <- mean_sdAnnual_gC[, c(ncol(mean_sdAnnual_gC), 1:(ncol(mean_sdAnnual_gC) - 1))] # Move year to first column
    
    # LE uncertainty
    
    # Random error
    
    # Considering correlations
    df <- df %>% 
      mutate(
        LE_orig_sd = ifelse(
          is.finite(.data[[paste0(LE_var, "_orig")]]), 
          .data[[paste0(LE_var, "_fsd")]], 
          NA
        ), # NEE_orig_sd includes NEE_uStar_fsd only for measured values - REPLACE with more generic name
        LE_fgood = ifelse(
          .data[[paste0(LE_var, "_fqc")]] <= 1, 
          is.finite(.data[[paste0(LE_var, "_f")]]), 
          NA
        ), # Only include filled values for the most reliable gap-filled observations. Note that is.finite() shouldn't be used here.
        resid = ifelse(
          .data[[paste0(LE_var, "_fqc")]] == 0, 
          .data[[paste0(LE_var, "_orig")]] - .data[[paste0(LE_var, "_fall")]], 
          NA
        )) # quantify the error terms, i.e. data-model residuals (only using observations (i.e., LE_uStar_fqc == 0 is original data) and exclude also
    # "good" gap-filled data)
    
    autoCorr <- lognorm::computeEffectiveAutoCorr(df$resid)
    nEff <- lognorm::computeEffectiveNumObs(df$resid, na.rm = TRUE)
    c(nEff = nEff, nObs = sum(is.finite(df$resid))) 
    
    # Update the summarise function to use dynamic column names
    resRand <- df %>% summarise(
      nRec = sum(is.finite(LE_orig_sd)),
      LEagg = mean(.data[[paste0(LE_var, "_f")]], na.rm = TRUE),
      varMean = sum(LE_orig_sd^2, na.rm = TRUE) / nRec / (!!nEff - 1),
      sdMean = sqrt(varMean),
      sdMeanApprox = mean(LE_orig_sd, na.rm = TRUE) / sqrt(!!nEff - 1)
    ) %>% dplyr::select(LEagg, sdMean, sdMeanApprox)
    
    # can also compute Daily aggregation -> but not done here.
    
    # u* threshold uncertainty
    ind <- which(grepl(paste0(gsub("_uStar$", "", LE_var),"_U*"), names(df)) & grepl("_f$", names(df)))
    column_name <- names(df)[ind] 
    
    #calculate column means of specific columns
    LEagg <- colMeans(df[ ,column_name], na.rm=T)
    
    #compute uncertainty across aggregated values
    sdLEagg_ustar <- sd(LEagg)
    
    # Combined aggregated uncertainty
    
    #Assuming that the uncertainty due to unknown u*threshold is independent from the random uncertainty, the variances add.
    LE_sdAnnual <- data.frame(
      sd_LE_Rand = resRand$sdMean,
      sd_LE_Ustar = sdLEagg_ustar,
      sd_LE_Comb = sqrt(resRand$sdMean^2 + sdLEagg_ustar^2) 
    )
    
    mean_column_name <- paste0(LE_var, "_f")
    
    # Calculate the mean and store it in a data frame
    df.mean_LE_f <- data.frame(mean(df[[mean_column_name]], na.rm = TRUE))
    colnames(df.mean_LE_f) <- paste0("mean_", mean_column_name)
    
    LE_sdAnnual <- cbind(df.mean_LE_f,LE_sdAnnual)
    
    # Convert to annual sums
    conv_MJ <- 1/(10^6) * 60 * 60 * 24 * length(df[[paste0(LE_var, "_f")]]) / 48 # Converts w/M2 to MJ/yr
    LE_sdAnnual_MJ <- LE_sdAnnual*conv_MJ

    # H uncertainty
    
    # Random error
    
    # Considering correlations
    df <- df %>% 
      mutate(
        H_orig_sd = ifelse(
          is.finite(.data[[paste0(H_var, "_orig")]]), 
          .data[[paste0(H_var, "_fsd")]], 
          NA
        ), # NEE_orig_sd includes NEE_uStar_fsd only for measured values - REPLACE with more generic name
        H_fgood = ifelse(
          .data[[paste0(H_var, "_fqc")]] <= 1, 
          is.finite(.data[[paste0(H_var, "_f")]]), 
          NA
        ), # Only include filled values for the most reliable gap-filled observations. Note that is.finite() shouldn't be used here.
        resid = ifelse(
          .data[[paste0(H_var, "_fqc")]] == 0, 
          .data[[paste0(H_var, "_orig")]] - .data[[paste0(H_var, "_fall")]], 
          NA
        )) # quantify the error terms, i.e. data-model residuals (only using observations (i.e., H_uStar_fqc == 0 is original data) and exclude also
    # "good" gap-filled data)
    
    autoCorr <- lognorm::computeEffectiveAutoCorr(df$resid)
    nEff <- lognorm::computeEffectiveNumObs(df$resid, na.rm = TRUE)
    c(nEff = nEff, nObs = sum(is.finite(df$resid))) 
    
    # Update the summarise function to use dynamic column names
    resRand <- df %>% summarise(
      nRec = sum(is.finite(H_orig_sd)),
      Hagg = mean(.data[[paste0(H_var, "_f")]], na.rm = TRUE),
      varMean = sum(H_orig_sd^2, na.rm = TRUE) / nRec / (!!nEff - 1),
      sdMean = sqrt(varMean),
      sdMeanApprox = mean(H_orig_sd, na.rm = TRUE) / sqrt(!!nEff - 1)
    ) %>% dplyr::select(Hagg, sdMean, sdMeanApprox)
    
    # can also compute Daily aggregation -> but not done here.
    
    # u* threshold uncertainty
    ind <- which(grepl(paste0(gsub("_uStar$", "", H_var),"_U*"), names(df)) & grepl("_f$", names(df)))
    column_name <- names(df)[ind] 
    
    #calculate column means of specific columns
    Hagg <- colMeans(df[ ,column_name], na.rm=T)
    
    #compute uncertainty across aggregated values
    sdHagg_ustar <- sd(Hagg)
    
    # Combined aggregated uncertainty
    
    #Assuming that the uncertainty due to unknown u*threshold is independent from the random uncertainty, the variances add.
    H_sdAnnual <- data.frame(
      sd_H_Rand = resRand$sdMean,
      sd_H_Ustar = sdHagg_ustar,
      sd_H_Comb = sqrt(resRand$sdMean^2 + sdHagg_ustar^2) 
    )
    
    mean_column_name <- paste0(H_var, "_f")
    
    # Calculate the mean and store it in a data frame
    df.mean_H_f <- data.frame(mean(df[[mean_column_name]], na.rm = TRUE))
    colnames(df.mean_H_f) <- paste0("mean_", mean_column_name)
    
    H_sdAnnual <- cbind(df.mean_H_f,H_sdAnnual)
    
    # Convert to annual sums
    conv_MJ <- 1/(10^6) * 60 * 60 * 24 * length(df[[paste0(H_var, "_f")]]) / 48 # Converts w/M2 to MJ/yr
    H_sdAnnual_MJ <- H_sdAnnual*conv_MJ    
    
    # Calculate EBC
    # Create new df for EBC
    vars_idx <- which(colnames(df) %in% AE_var)
    vars_found <- length(vars_idx)
    if (vars_found>0){
      if(any(AE_var == "") | vars_found==1){
        AE_total <- df[, which(colnames(df) %in% AE_var[1]), drop = TRUE]} 
      else {
        #AE_total = rowSums(df[, which(colnames(df) %in% AE_var), drop = TRUE])
        Rn <- df[, which(colnames(df) %in% AE_var[1])]
        G <- df[, which(colnames(df) %in% AE_var[2])]
        AE_total <- Rn - G
      }
      df.EBC <- data.frame(AE = AE_total)
      df.EBC$H_LE <- rowSums(df[, which(colnames(df) %in% H_LE_var), drop = TRUE])
         
      #plot_ly(data = df.EBC, x = ~AE, y = ~H_LE, name = 'filled', type = 'scatter', mode = 'markers',marker = list(size = 3))
      
      model <- lm(H_LE ~ AE, data = df.EBC)
      slope <- coef(model)["AE"]
      r_squared <- summary(model)$r.squared
      
      EBC <- data.frame(slope,r_squared)
      colnames(EBC) <- c("half hourly EBC", "EBC R2")
      
      # Final output file - combine CO2, H, LE uncertainty
      all_data <- cbind(mean_sdAnnual_gC,LE_sdAnnual_MJ,H_sdAnnual_MJ,EBC)
    } 
    else{
      # Final output file - combine CO2, H, LE uncertainty
      all_data <- cbind(mean_sdAnnual_gC,LE_sdAnnual_MJ,H_sdAnnual_MJ)
    }
    
    
    write.csv(round(all_data,2), paste0(dpath,'/',level_out,"/annual_summary_",year,"_",format(Sys.time(), "%Y%m%d%H%M%S"),".csv"), row.names = FALSE)
    
    # Still need to add FCH4 and EBC
    
  }
  
}
