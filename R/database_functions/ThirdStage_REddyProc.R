# Written to gap-fill and partition fluxes using REddyPro, and gap-fill using other R functions
# By Sara Knox
# Aug 11, 2022

# Inputs
# pathSetIni   - path to R function that sets up all the ini parameters
#                usually: 
#                  p:/database/Calculation_procedures/TraceAnalysis_ini/siteID/log/siteID_setThirdStageCleaningParameters.R"
#

ThirdStage_REddyProc <- function(pathSetIni) {
  
  # Package names
  packages <- c("REddyProc", "dplyr", "lubridate", "data.table")
  
  # Install packages not yet installed
  installed_packages <- packages %in% rownames(installed.packages())
  if (any(installed_packages == FALSE)) {
    install.packages(packages[!installed_packages])
  }
  
  # Packages loading
  invisible(lapply(packages, library, character.only = TRUE))
  
  # load input arguments from pathInputArgs file
  source(pathSetIni)
  
  # initiate path variables
  db_ini <- db_root # base path to find the files
  db_out <- db_root # base path where to save the files
  
  ini_path <- paste(db_root,"/Calculation_Procedures/","TraceAnalysis_ini/",site,sep="") # specify base path to where the ini files are
  
  # Specify folders
  
  # Output folder name for REddyProc and random forest output 
  level_REddyProc_Full <- 'Clean/ThirdStage_REddyProc_RF_Full'
  level_REddyProc_Fast <- 'Clean/ThirdStage_REddyProc_RF_Fast'
  
  # Folder where stage three variables should be save
  level_out <- "Clean/ThirdStage"
  
  # Run Stage Three for site
  ini_file_name <- paste(site,'_ThirdStage_ini.R',sep = "")
  pthIniFile <- paste(ini_path,"/",ini_file_name,sep="")
  
  # Load ini file
  source(pthIniFile)
  
  #Copy files from second stage to third stage (only if not from FLUXNET files)
  
  if (data_source != "FLUXNET") {
    for (j in 1:length(yrs)) {
      in_path <- paste(db_ini,"/",as.character(yrs[j]),"/",site,"/clean/SecondStage/", sep = "")
      copy_vars_full <- paste(in_path,copy_vars, sep="")
      
      out_path <- paste(db_ini,"/",as.character(yrs[j]),"/",site,"/",level_out, sep = "")
      
      if (file.exists(out_path)){
        setwd(out_path)
      } else {
        dir.create(out_path)
        setwd(out_path)
      }
      
      file.copy(copy_vars_full,out_path,overwrite = TRUE)
    }
  }
  
  # Read function for loading data
  p <- sapply(list.files(pattern="read_database.R", path=fx_path, full.names=TRUE), source)
  
  if (do_REddyProc == 1) {
    
    data <- data.frame()
    # Loop through each year and merge all years together
    for (j in 1:length(years_REddyProc)) {
      
      # Load ini file
      #      cat("\n\nIn ThirdStage_REddyProc:\n")      
      #      cat("   Do we need to reload the ini file here again?\n\n")      
      #      source(pthIniFile)
      
      level_in <- "Clean/SecondStage" # Specify that this is data from the second stage we are using as inputs
      
      if (data_source == "FLUXNET") {
        
        data.now <- read.csv(dir(paste0(db_ini,"/",years_REddyProc[j],"/",site,"/",level_in,"/",sep = ""), full.names=T, pattern="*.csv"))
        data <- dplyr::bind_rows(data,data.now[,c("TIMESTAMP_START",vars)])
        
      } else {
        
        # Create data frame for years & variables of interest 
        data.now <- read_database(db_ini,years_REddyProc[j],site,level_in,vars,tv_input,export)
        data <- dplyr::bind_rows(data,data.now)
      }
    }
    
    if (data_source == "FLUXNET") {
      data$datetime <- ymd_hm(data$TIMESTAMP_START)
      data <- data[,!(names(data) %in% "TIMESTAMP_START")]
    }
    
    # Now load in storage terms if they exist
    if (exists("vars_storage") == TRUE) {
      
      data.storage <- data.frame()
      # Loop through each year and merge all years together
      for (j in 1:length(years_REddyProc)) {
        
        # Load ini file
        #        cat("\n\nIn ThirdStage_REddyProc:\n")      
        #        cat("   Do we need to reload the ini file here again?\n\n")      
        #        source(pthIniFile)
        
        level_in <- "Clean/SecondStage" # Specify that this is data from the second stage we are using as inputs
        
        if (data_source == "FLUXNET") {
          
          data.now.storage <- read.csv(dir(paste0(db_ini,"/",years_REddyProc[j],"/",site,"/",level_in,"/",sep = ""), full.names=T, pattern="*.csv"))
          data.storage <- dplyr::bind_rows(data,data.now.storage[,vars_storage])
          
        } else {
          # Create data frame for years & variables of interest 
          data.now.storage <- read_database(db_ini,years_REddyProc[j],site,level_in,vars_storage,tv_input,export)
          data.storage <- dplyr::bind_rows(data.storage,data.now.storage)
        }
      }
      
      # Add storage terms
      # First rename storage terms to match flux terms
      names.data.storage <- gsub("SC", "FC", colnames(data.storage))
      names.data.storage <- gsub("S", "", names.data.storage)
      
      # Find which columns that corresponds to in data
      names.data <- colnames(data)
      
      for (i in 2:length(names.data.storage)) {
        ind <- grep(paste("^",names.data.storage[i],"$",sep = ''), names.data)
        
        # Add on storage term (if not all NaN)
        if (sum(!is.nan(data.storage[,i])) > 0) {
          data[,ind] <- data[,ind]+data.storage[,i]
        } else {
          data[,ind] <- data[,ind] # This will not include a storage term since all storage terms are NaN
          }
      }
    }
    
    # Create NEE variable if FC exists
    if (length(grep("FC", colnames(data))) > 0){
      data$NEE <- data$FC
    }
    
    # Create time variables
    data <- data %>%
      mutate(year = year(datetime),
             DOY = yday(datetime),
             hour = hour(datetime),
             minute = minute(datetime))
    
    # Create hour as fractional hour (e.g., 13, 13.5, 14)
    min <- data$minute
    min[which(min == 30)] <- 0.5
    data$HHMM <- data$hour+min
    
    # Rearrange data frame and only keep relevant variables for input into REddyProc
    data_REddyProc <- data[ , -which(names(data) %in% c("datetime","hour","minute"))]
    data_REddyProc <- data_REddyProc[ , col_order]
    
    # Rename column names to variable names in REddyProc
    colnames(data_REddyProc)<-var_names  
    
    # Only use existing data up until storage terms are calculated (if not all storage terms are NaN)
    #DT <- data.table(data_REddyProc[,-which(names(data_REddyProc) %in% c("Year","DoY","Hour","NEE","FC","H","LE","FCH4","Ustar"))])
    #last_ind <- max(DT[,lapply(.SD,function(x) which(x == tail(x[!is.na(x)],1)))])
    
    if (exists("data.storage") && sum(!is.nan(data.storage[,i])) > 0) {
      DT <- data.table(data.storage[,-which(names(data.storage) %in% c("datetime"))])
      last_ind <- max(DT[,lapply(.SD,function(x) which(x == tail(x[!is.na(x)],1)))])
      
      data_REddyProc <- data_REddyProc[c(1:last_ind),]
    } 
    
    #Transforming missing values into NA:
    data_REddyProc[is.na(data_REddyProc)]<-NA
    
    # Run REddyProc
    # Following "https://cran.r-project.org/web/packages/REddyProc/vignettes/useCase.html" This is more up to date than the Wutzler et al. paper
    
    # NOTE: skipped loading in txt file since alread have data in data frame
    #+++ Add time stamp in POSIX time format
    EddyDataWithPosix <- fConvertTimeToPosix(
      data_REddyProc, 'YDH',Year = 'Year',Day = 'DoY', Hour = 'Hour') 
    #+++ Initalize R5 reference class sEddyProc for post-processing of eddy data
    #+++ with the variables needed for post-processing later
    EProc <- sEddyProc$new(
      site, EddyDataWithPosix, c('NEE','FC','LE','H','FCH4','Rg','Tair','VPD', 'Ustar')) 
    
    # Here we only use three ustar scenarios - for full uncertainty estimates, use the UNCERTAINTY SCRIPT (or full vs. fast run - as an option in ini)
    if (Ustar_scenario == 'full') { 
      nScen <- 39
      EProc$sEstimateUstarScenarios( 
        nSample = nScen*4, probs = seq(0.025,0.975,length.out = nScen) )
      uStarSuffixes <- colnames(EProc$sGetUstarScenarios())[-1]
      uStarSuffixes
      
    } else if (Ustar_scenario == 'fast') { 
      EProc$sEstimateUstarScenarios(
        nSample = 100L, probs = c(0.05, 0.5, 0.95))
      EProc$sGetEstimatedUstarThresholdDistribution()
    }
    
    # The subsequent post processing steps will be repeated using the four u∗ threshold scenarios (non-resampled and three quantiles of the bootstrapped distribution).
    #EProc$sGetUstarScenarios() -> print output if needed
    #EProc$sPlotNEEVersusUStarForSeason() -> save plot if needed
    
    # Gap-filling
    EProc$sMDSGapFillUStarScens('NEE')
    EProc$sMDSGapFillUStarScens('FC')
    EProc$sMDSGapFillUStarScens('LE')
    EProc$sMDSGapFillUStarScens('H')
    EProc$sMDSGapFillUStarScens('FCH4')
    
    # "_f" denotes the filled value and "_fsd" the estimated standard deviation of its uncertainty.
    # grep("NEE_.*_f$",names(EProc$sExportResults()), value = TRUE) -> print output if needed
    # grep("NEE_.*_fsd$",names(EProc$sExportResults()), value = TRUE) -> print output if needed
    # EProc$sPlotFingerprintY('NEE_U50_f', Year = 2022) -> view plot if needed
    
    # Partitioning
    EProc$sSetLocationInfo(LatDeg = lat, LongDeg = long, TimeZoneHour = TimeZoneHour)
    EProc$sMDSGapFill('Tair', FillAll = FALSE,  minNWarnRunLength = NA)
    EProc$sMDSGapFill('VPD', FillAll = FALSE,  minNWarnRunLength = NA)
    #EProc$sFillVPDFromDew() # fill longer gaps still present in VPD_f
    EProc$sMDSGapFill('Rg', FillAll = FALSE,  minNWarnRunLength = NA)
    
    # Nighttime
    EProc$sMRFluxPartitionUStarScens()
    # EProc$sPlotFingerprintY('GPP_U50_f', Year = 2022)  # -> view plot if needed
    
    # Daytime
    EProc$sGLFluxPartitionUStarScens()
    #EProc$sPlotFingerprintY('GPP_DT_U50', Year = 2022)
    # grep("GPP|Reco",names(EProc$sExportResults()), value = TRUE)
    
    # Create data frame for REddyProc output
    FilledEddyData <- EProc$sExportResults()
    
    if (exists("data.storage") && sum(!is.nan(data.storage[,i])) > 0) {
      # Fill back in the NA values
      FilledEddyData_full <- data.frame(matrix(NA, nrow = nrow(data), ncol = ncol(FilledEddyData)))
      FilledEddyData_full[c(1:last_ind),] <- FilledEddyData 
      colnames(FilledEddyData_full) <-  colnames(FilledEddyData)
      
      # Re-save as FilledEddyData
      FilledEddyData <- FilledEddyData_full
    }
    
    # Delete uStar dulplicate columns since they are output for each gap-filled variables
    vars_remove <- c(colnames(FilledEddyData)[grepl('\\Thres.', names(FilledEddyData))],
                     colnames(FilledEddyData)[grepl('\\_fqc.', names(FilledEddyData))])
    FilledEddyData <- FilledEddyData[, -which(names(FilledEddyData) %in% vars_remove)]
    
    # Save data
    # Loop through each year and save each year individually
    for (j in 1:length(yrs)) {
      
      # indices corresponding to year of interest
      if (data_source == "FLUXNET") {
        ind_s <- which(data$year == yrs[j] & data$DOY == 1 & data$HHMM == 0)
        ind_e <- which(data$year == yrs[j] & data$DOY == last(data$DOY[data$year == yrs[j]]) & data$HHMM == 23.5)
      } else {
        ind_s <- which(data$year == yrs[j] & data$DOY == 1 & data$HHMM == 0.5)
        ind_e <- which(data$year == yrs[j]+1 & data$DOY == 1 & data$HHMM == 0)
      }
      
      ind <- seq(ind_s,ind_e)
      
      # First save all under ThirdStage_REddyProc_RF_Fast or ThirdStage_REddyProc_RF_Full
      if (Ustar_scenario == 'full') { 
        
        out_path <- paste(db_out,"/",as.character(yrs[j]),"/",site,"/",level_REddyProc_Full, sep = "")
        
        if (file.exists(out_path)){
          setwd(out_path)
        } else {
          dir.create(out_path)
          setwd(out_path)
        }
        
        var_names <- colnames(FilledEddyData)
        for (i in 1:length(var_names)) {
          writeBin(as.numeric(FilledEddyData[ind,i]), var_names[i], size = 4)
        }
        
        in_path <- paste(db_ini,"/",as.character(yrs[j]),"/",site,"/clean/SecondStage/", sep = "")
        tv_var_full <- paste(in_path,"clean_tv", sep="")
        
        out_path <- paste(db_ini,"/",as.character(yrs[j]),"/",site,"/",level_REddyProc_Full, sep = "")
        
        if (file.exists(out_path)){
          setwd(out_path)
        } else {
          dir.create(out_path)
          setwd(out_path)
        }
        
        file.copy(tv_var_full,out_path,overwrite = TRUE)
        
      } else if (Ustar_scenario == 'fast') { 
        out_path <- paste(db_out,"/",as.character(yrs[j]),"/",site,"/",level_REddyProc_Fast, sep = "")
        
        if (file.exists(out_path)){
          setwd(out_path)
        } else {
          dir.create(out_path)
          setwd(out_path)
        }
        
        var_names <- colnames(FilledEddyData)
        for (i in 1:length(var_names)) {
          writeBin(as.numeric(FilledEddyData[ind,i]), var_names[i], size = 4)
        }
        
        in_path <- paste(db_ini,"/",as.character(yrs[j]),"/",site,"/clean/SecondStage/", sep = "")
        tv_var_full <- paste(in_path,"clean_tv", sep="")
        
        out_path <- paste(db_ini,"/",as.character(yrs[j]),"/",site,"/",level_REddyProc_Fast, sep = "")
        
        if (file.exists(out_path)){
          setwd(out_path)
        } else {
          dir.create(out_path)
          setwd(out_path)
        }
        
        file.copy(tv_var_full,out_path,overwrite = TRUE)
      }
      
      # Output variables to stage three
      out_path <- paste(db_out,"/",as.character(yrs[j]),"/",site,"/",level_out, sep = "")
      
      if (file.exists(out_path)){
        setwd(out_path)
      } else {
        dir.create(out_path)
        setwd(out_path)
      }
      
      # create new data frame with only variables of interest, and rename columns
      data_third_stage <- FilledEddyData[, which(names(FilledEddyData) %in% vars_third_stage_REddyProc)]
      data_third_stage <- data_third_stage[, vars_third_stage_REddyProc]
      colnames(data_third_stage) <- vars_names_third_stage
      
      if (data_source == "FLUXNET") {
        
        file_name <- list.files(path = paste0(db_ini,"/",yrs[j],"/",site,"/",level_in,sep = ""), pattern = "*.csv")
        
        data.now <- read.csv(dir(paste0(db_ini,"/",yrs[j],"/",site,"/",level_in,sep = ""), full.names=T, pattern="*.csv"))
        var_names_csv <- colnames(data.now)
        
        # Remove variables from data.now that are also in data.all.stagethree
        intersecting_vars <- intersect(vars_names_third_stage, var_names_csv)
        
        data.all.stagethree <- cbind(data.now[,!(names(data.now) %in% intersecting_vars)],data_third_stage[ind,])
        
        write.csv(data.all.stagethree, file_name, row.names=F)
        
      } else {
        
        for (i in 1:length(vars_names_third_stage)) {
          writeBin(as.numeric(data_third_stage[ind,i]), vars_names_third_stage[i], size = 4)
        }
      }
    }
  }
  
  # RF gap-filling for FCH4 (for now - add NEE, LE, H later)
  if (fill_RF_FCH4 == 1) {
    
    # Read function for RF gap-filling data
    p <- sapply(list.files(pattern="RF_gf.R", path=fx_path, full.names=TRUE), source)
    
    data_RF <- data.frame()
    # Loop through each year specified for the RF gap-filling and merge all years together
    for (j in 1:length(years_RF)) {
      # Load stage three data
      if (data_source == "FLUXNET") {
        
        data_RF.now <- read.csv(dir(paste0(db_ini,"/",years_REddyProc[j],"/",site,"/",level_RF_FCH4,"/",sep = ""), full.names=T, pattern="*.csv"))
        data_RF <- dplyr::bind_rows(data_RF,data_RF.now)
        
      } else {
        data_RF.now <- read_database(db_ini,years_RF[j],site,level_RF_FCH4,predictors_FCH4,tv_input,export)
        data_RF <- dplyr::bind_rows(data_RF,data_RF.now)
      }
    }
    
    if (data_source == "FLUXNET") {
      data_RF$datetime <- ymd_hm(data_RF$TIMESTAMP_START)
      data_RF <- data_RF[,!(names(data_RF) %in% "TIMESTAMP_START")]
    }
    
    # Apply gap-filling function
    datetime <- data_RF$datetime
    gap_filled_FCH4 <- RF_gf(data_RF,predictors_FCH4[1],predictors_FCH4,plot_RF_results,datetime)
    
    # Save data for the years of interest (i.e., not years_RF). Note years_RF is used to allow us to years additional years for RF gap-filling
    # Loop through each year and save each year individually
    for (j in 1:length(yrs)) {
      
      # indices corresponding to year of interest
      if (data_source == "FLUXNET") {
        
        ind_s <- which(year(gap_filled_FCH4$DateTime) == yrs[j] & yday(gap_filled_FCH4$DateTime) == 1 & hour(gap_filled_FCH4$DateTime) == 0 & minute(gap_filled_FCH4$DateTime) == 0)
        last_day <- last(yday(gap_filled_FCH4$DateTime)[year(gap_filled_FCH4$DateTime) == yrs[j]])
        ind_e <- which(year(gap_filled_FCH4$DateTime) == yrs[j] & yday(gap_filled_FCH4$DateTime) == last_day & hour(gap_filled_FCH4$DateTime) == 23 & minute(gap_filled_FCH4$DateTime) == 30)
        
      } else {
        
        # indices corresponding to year of interest
        ind_s <- which(year(gap_filled_FCH4$DateTime) == yrs[j] & yday(gap_filled_FCH4$DateTime) == 1 & hour(gap_filled_FCH4$DateTime) == 0 & minute(gap_filled_FCH4$DateTime) == 30)
        ind_e <- which(year(gap_filled_FCH4$DateTime) == yrs[j]+1 & yday(gap_filled_FCH4$DateTime) == 1 & hour(gap_filled_FCH4$DateTime) == 0 & minute(gap_filled_FCH4$DateTime) == 0)
      }
      
      ind <- seq(ind_s,ind_e)
      
      # First save all RF output under REddyProc_RF
      
      if (Ustar_scenario == 'full') { 
        
        out_path <- paste(db_out,"/",as.character(yrs[j]),"/",site,"/",level_REddyProc_Full, sep = "")
        
        if (file.exists(out_path)){
          setwd(out_path)
        } else {
          dir.create(out_path)
          setwd(out_path)
        }
        
        var_names <- colnames(gap_filled_FCH4)
        for (i in 1:length(var_names)) {
          writeBin(as.numeric(gap_filled_FCH4[ind,i]), var_names[i], size = 4)
        }
        
      } else if (Ustar_scenario == 'fast') { 
        
        out_path <- paste(db_out,"/",as.character(yrs[j]),"/",site,"/",level_REddyProc_Fast, sep = "")
        
        if (file.exists(out_path)){
          setwd(out_path)
        } else {
          dir.create(out_path)
          setwd(out_path)
        }
        
        var_names <- colnames(gap_filled_FCH4)
        for (i in 1:length(var_names)) {
          writeBin(as.numeric(gap_filled_FCH4[ind,i]), var_names[i], size = 4)
        }
      }
      
      # Output variables to stage three
      out_path <- paste(db_out,"/",as.character(yrs[j]),"/",site,"/",level_out, sep = "")
      
      if (file.exists(out_path)){
        setwd(out_path)
      } else {
        dir.create(out_path)
        setwd(out_path)
      }
      
      # Save only RF filled FCH4 flux
      
      if (data_source == "FLUXNET") {
        
        file_name <- list.files(path = paste0(db_ini,"/",yrs[j],"/",site,"/",level_RF_FCH4,sep = ""), pattern = "*.csv")
        data.now <- read.csv(dir(paste0(db_ini,"/",yrs[j],"/",site,"/",level_RF_FCH4,sep = ""), full.names=T, pattern="*.csv"))
        
        RF_FCH4 <- as.data.frame(gap_filled_FCH4[ind,1])
        colnames(RF_FCH4) <- vars_third_stage_RF_FCH4
        data.all.RF.stagethree <- cbind(data.now,RF_FCH4)
        
        write.csv(data.all.RF.stagethree, file_name, row.names=F)
        rm(RF_FCH4)
        
      } else {
        writeBin(as.numeric(gap_filled_FCH4[ind,1]), vars_third_stage_RF_FCH4, size = 4)
      }
    }
  }
}



