# Written by June Skeeter (March 2024)
# Intended to streamline third stage processing
# Input Arguments:

# Required:
# siteID (e.g., BB)
# startYear (first year to run, e.g., 2022)
# Optional: 
# lastYear years run will be: c(startYear:lastYear)

# Note: this currently assumes that "pathTo/yourProject"
# Third stage procedures assumes that pathTo/yourProject contains a matlab file:
#  * pathTo/yourProject/Matlab/biomet_database_default.m
#    * This file defines the path to the version of the biomet database that you are working with

# # Call from command line (assuming R is added to your PATH variable)

# # giving database as an input
# Rscript --vanilla C:/Biomet.net/R/database_functions/ThirdStage.R C:/Database siteID startYear endYear

# # If current directory is the the root of a database
# cd pathTo/yourProject
# Rscript --vanilla C:/Biomet.net/R/database_functions/ThirdStage.R siteID startYear endYear

## Call from R terminal

# # Giving database as an input
# args <- c("F:/EcoFlux lab/Database","AB1",2025,2025)
# source("C:/Biomet.net/R/database_functions/ThirdStage.R")

# # If current directory is the the root of a database
# setwd(C:/Database)
# args <- c("siteID",startYear,endYear)

# Package names
packages <- c("fs", "yaml", "REddyProc", "rlist", "zoo", "dplyr", "lubridate", "data.table", "reshape2", "stringr", "tidyverse", "slider", "ranger", "caret", "ggplot2","lognorm")

# Install packages not yet installed
installed_packages <- packages %in% rownames(installed.packages())
if (any(installed_packages == FALSE)) {
  install.packages(packages[!installed_packages],repos="https://cloud.r-project.org")
}

# Packages loading
invisible(lapply(packages, library, character.only = TRUE))

print(version$version.string)
REddyProc_v <- packageVersion("REddyProc")
sprintf("ReddyProc version: %s",REddyProc_v)

merge_nested_lists = function(...) {
  # Modified from: https://gist.github.com/joshbode/ed70291253a4b4412026
  stack = rev(list(...))
  names(stack) = rep('', length(stack))
  result = list()
  
  while (length(stack)) {
    # pop a value from the stack
    obj = stack[[1]]
    root = names(stack)[[1]]
    stack = stack[-1]
    
    if (is.list(obj) && !is.null(names(obj))) {
      if (any(names(obj) == '')) {
        stop("Mixed named and unnamed elements are not supported.")
      }
      # restack for next-level processing
      if (root != '') {
        names(obj) = paste(root, names(obj), sep='|')
      }
      stack = append(obj, stack)
    } else {
      # clear a path to store result
      path = unlist(strsplit(root, '|', fixed=TRUE))
      for (j in seq_along(path)) {
        sub_path = path[1:j]
        if (is.null(result[[sub_path]])) {
          result[[sub_path]] = list()
        }
      }
      result[[path]] = obj
    }
  }
  
  return(result)
}

configure <- function(siteID){
  # Get path of current script & arguments
  # Procedures differ if called via command line or via source()
  cmdArgs <- commandArgs(trailingOnly = FALSE)
  needle <- "--file="
  match <- grep(needle, cmdArgs)
  if (length(match) > 0) {
    # Rscript
    args <- commandArgs(trailingOnly = TRUE)
    fx_path<- path_dir(normalizePath(sub(needle, "", cmdArgs[match])))
  } else {
    # 'source'd via R console
    fx_path<- path_dir(normalizePath(sys.frames()[[1]]$ofile))
  }
  
  # load summary function (for uncertainty and EBC)
  source(file.path(fx_path,'uncertainty_annual_summary.R'))
  
  # Read a the global database configuration
  filename <- file.path(fx_path,'global_config.yml')
  dbase_config = yaml.load_file(filename)
  
  # Find the database and site-specific config
  db_root <- file.path(args[1])
  db_ini <- file.path(db_root,'Calculation_Procedures/TraceAnalysis_ini/')
  
  if (dir.exists(db_root) && !dir.exists(db_ini)){
    print(sprintf("%s does not exist, cannot proceed",db_ini))
    exit()
  } else if(!dir.exists(db_root)){
    print('database path not provided, checking if current directory is a database')
    db_root = getwd()
    db_ini <- file.path(db_root,'Calculation_Procedures/TraceAnalysis_ini/')
    args <- c(db_root,args)
    if (!dir.exists(db_ini)){
      print(sprintf("%s does not exist, cannot proceed",db_ini))
      print('Input a valid database path or set your working directory to a database to proceed')
      exit()
    }
  }
  print(sprintf('Third stage run initialized for %s data in %s',args[2],db_root))
  
  # Get the siteID argument and read the site-specific configuration
  siteID <- args[2]
  fn <- sprintf('%s_config.yml',siteID)
  filename <- file.path(db_root,'Calculation_Procedures/TraceAnalysis_ini',siteID,fn)
  site_config <- yaml.load_file(filename)
  
  # merge the config files
  config <- merge_nested_lists(site_config,dbase_config)
  
  # Add the relevant paths to the config
  config$Database$db_root <- db_root
  config$fx_path <- fx_path
  
  # Find all site-years in database
  yearsAll = suppressWarnings(as.numeric(list.dirs(db_root, recursive = FALSE,full.names = FALSE)))
  yearsAll = yearsAll[!sapply(yearsAll, is.na)]
  level_in <- config$Database$Paths$SecondStage
  tv <- config$Database$Timestamp$name
  siteYearsAll = file.path(db_root,as.character(yearsAll),siteID,level_in,tv)
  yearsAll = yearsAll[sapply(siteYearsAll,file.exists)]
  siteYearsAll = siteYearsAll[sapply(siteYearsAll,file.exists)]
  siteYearsAll = gsub(tv,'',siteYearsAll)
  siteYearsAll = gsub(config$Database$Paths$SecondStage,'',siteYearsAll)
  siteYearsAll = gsub('//','',siteYearsAll)
  
  # Determine site years to output
  if (length(args)>2){
    years <- c(args[3]:args[length(args)])
    siteYearsOut = file.path(db_root,as.character(years),siteID)
  } else {
    siteYearsOut = siteYearsAll
    years <- yearsAll
  }
  
  config$siteYearsAll <- siteYearsAll
  config$siteYearsOut <- siteYearsOut
  config$years <- years
  
  # Set procedures to run by default unless specified otherwise in site-specific files
  # Can update to have user overrides by command line as well if desired
  # For now, just apply the overrides in site-specific config files
  if(is.null(config$Processing$ThirdStage$Storage_Correction$Run)){
    config$Processing$ThirdStage$Storage_Correction$Run=TRUE
  }
  if(is.null(config$Processing$ThirdStage$JS_Moving_Z$Run)){
    config$Processing$ThirdStage$JS_Moving_Z$Run=TRUE
  }
  if(is.null(config$Processing$ThirdStage$Papale_Spike_Removal$Run)){
    config$Processing$ThirdStage$Papale_Spike_Removal$Run=TRUE
  }
  if(is.null(config$Processing$ThirdStage$REddyProc$Run)){
    config$Processing$ThirdStage$REddyProc$Run=TRUE
  }
  if(is.null(config$Processing$ThirdStage$RF_GapFilling$Run)){
    config$Processing$ThirdStage$RF_GapFilling$Run=TRUE
  }
  if(is.null(config$Processing$ThirdStage$REddyProc$Flux_Partitioning$Run)){
    config$Processing$ThirdStage$REddyProc$Flux_Partitioning$Run=TRUE
  }
  return(config)
}

read_database <- function(input_paths,vars) {
  # remove from memory if 
  if (exists('data_out')) {rm(data_out)}
  # simplified version of database read function
  for (input_path in input_paths){
    # Convert Matlab timevector to POSIXct
    tv <- readBin(paste0(input_path,"/",config$Database$Timestamp$name,sep=""), double(), n = 18000)
    datetime <- as.POSIXct((tv - 719529) * 86400, origin = "1970-01-01", tz = "UTC")
    # Round to nearest 30 min
    datetime <- lubridate::round_date(datetime, "30 minutes")
    df <- data.frame(datetime)
    # Read any variable that exists and is not empty
    for (var in vars) {
      dpath = file.path(input_path,var)
      if (file.exists(dpath)) {
        data <- data.frame(readBin(dpath, numeric(), n = 18000, size = 4))
        colnames(data) <- var
        if (nrow(data) == nrow(df)){
          df <- cbind(df, data)
        } else {
          print(sprintf('Empty file or incorrect number of records, skipping: %s', dpath))
        }
      } else {
        print(sprintf('Does not exist: %s', dpath))
      }
    }
    if (exists('data_out')){data_out <- bind_rows(data_out,df)}
    else {data_out <- df}
  }
  return(data_out)
}

read_and_copy_traces <- function(){
  # Read function for loading data
  # Read all traces from stage 2, copy to stage 3 and also dump to dataframe for stage 3 processing
  # Any modified traces can be overwritten when dumping final stage 3 outputs
  
  # Copy files from second stage to third stage, copies everything by default  
  level_in <- config$Database$Paths$SecondStage
  level_out <- config$Database$Paths$ThirdStage
  
  input_paths <- file.path(config$siteYearsAll,level_in)
  copy_vars <- unique(list.files(input_paths))
  copy_vars <- copy_vars[! copy_vars %in% config$Database$Timestamp$name]
  
  # read all site-years 
  data <- read_database(input_paths,copy_vars)
  
  # Only copy data as specified
  for (siteYearIn in config$siteYearsAll) {
    in_path <- file.path(siteYearIn,level_in)
    out_path <- file.path(siteYearIn,level_out)
    if (siteYearIn %in% config$siteYearsOut){
      dir.create(out_path, showWarnings = FALSE)
      unlink(file.path(out_path,'*'))
      
      # First copy time-vector
      file.copy(file.path(in_path,config$Database$Timestamp$name),
                file.path(out_path,config$Database$Timestamp$name))
      
      # Now copy traces
      for (filename in copy_vars){
        if (file.exists(file.path(in_path,filename))){
          file.copy(file.path(in_path,filename),file.path(out_path,filename))
        }
      }
      
      # Save the config in the output folder (one copy per-year)
      write_yaml(
        config$Processing, 
        file.path(out_path,'ProcessingSettings.yml'),
        fileEncoding = "UTF-8")
    }
    
  }
  
  # Create time variables
  data <- data %>%
    mutate(Year = year(datetime),
           DoY = yday(datetime),
           hour = hour(datetime),
           minute = minute(datetime))
  
  # Create hour as fractional hour (e.g., 13, 13.5, 14)
  data$Hour <- data$hour+data$minute/60
  
  # REddyProc expects a specific naming convention
  names(data)[names(data) == 'datetime'] <- 'DateTime'
  #Transforming missing values into NA:
  data[is.na(data)]<-NA
  return(data)
}

Met_Gap_Filling <- function(){
  interpolation = config$Processing$ThirdStage$Met_Gap_Filling$Linear_Interpolation
  interpolate_vars = unlist(strsplit(interpolation$Fill_Vars, split = ","))
  input_data[interpolate_vars] = na.approx(
    input_data[interpolate_vars],
    maxgap = interpolation$maxgap,
    na.rm = FALSE)
  return(input_data)
}

Standard_Cleaning <- function(){
  suffix_label = ''
  Fluxes <- config$Processing$ThirdStage$Fluxes
  for (flux in names(Fluxes)){
    flux_in <- unlist(Fluxes[[flux]])
    flux_out = paste(flux,suffix_label,sep="")
    Fluxes[[flux]] <- flux_out
    # Declare flux out variables, needed because some (e.g., NEE) are renamed from their stage 2 value
    input_data[[flux_out]] <- input_data[[flux_in]]
    
    if ('northOffset' %in% names(config$Metadata)){
      WD_varname <- 'WD_1_1_1'
      if ('WD' %in% names(config$Processing$ThirdStage$REddyProc$vars_in)){
        WD_varname <- config$Processing$ThirdStage$REddyProc$vars_in$WD
      }
      half_width <- config$Processing$ThirdStage$Standard_Cleaning$wakeFilter
      filter <- config$Metadata$northOffset-180
      # Calculation is robust to user error and does not require adjustments based on wind direction
      na_in <- sum(is.na(input_data[[flux_out]]))
      input_data[[flux_out]][(
        (abs(input_data[WD_varname]-filter)<=half_width)|
          (abs(input_data[WD_varname]-360-filter)<=half_width)|
          (abs(input_data[WD_varname]+360-filter)<=half_width))& !is.na(input_data[WD_varname])
      ] <- NA
      na_out <- sum(is.na(input_data[[flux_out]]))
      print(sprintf('%i values in %s were filtered by the wind sector filter',na_out-na_in,flux))
    } else {
      stop("<P2M> Error: northOffset missing from your configuration file! </P2M>")
    }
    P_varname <- 'P_1_1_1'
    if ('P' %in% names(config$Processing$ThirdStage$REddyProc$vars_in)){
      P_varname <- config$Processing$ThirdStage$REddyProc$vars_in$P
    }
    
    if (P_varname %in% colnames(input_data)){
      # Check whether precipCutoff exists before executing (i.e. was it deactivated by user input of NULL)
      if ('precipCutOff' %in% names(config$Processing$ThirdStage$Standard_Cleaning)){
        p_thresh <- config$Processing$ThirdStage$Standard_Cleaning$precipCutOff
        na_in <- sum(is.na(input_data[[flux_out]]))
        input_data[[flux_out]][input_data[P_varname]>p_thresh & !is.na(input_data[P_varname])] <- NA
        na_out <- sum(is.na(input_data[[flux_out]]))
        print(sprintf('%i values in %s were filtered out by the rain filter',na_out-na_in,flux))
      }
    }
  }
  
  config$Processing$ThirdStage$Fluxes <- Fluxes
  # Delete old outputs, dump new ones
  input_data <- write_traces(input_data[,c('DateTime',unlist(unname(Fluxes)))],Fluxes,unlink=TRUE,suffix_opts=c('',''))    
  return(list(input_data=input_data,config=config))
}

# Removed PI label from being added in Standard_Cleaning. Copy fluxes into new
#   _PI variables prior to 'SC', 'JSZ',' MAD', and 'RP'. Flux_PI is not written 
#   to disk, it is only once a secondary suffix is added.
Add_PI_label <- function(){
  suffix_label = 'PI'
  Fluxes <- config$Processing$ThirdStage$Fluxes
  for (flux in names(Fluxes)){
    flux_in <- unlist(Fluxes[[flux]])
    flux_out = paste(flux,'_',suffix_label,sep="")
    Fluxes[[flux]] <- flux_out
    # Declare flux out variables, needed because some (e.g., NEE) are renamed from their stage 2 value
    input_data[[flux_out]] <- input_data[[flux_in]]
  }
  config$Processing$ThirdStage$Fluxes <- Fluxes
  return(list(input_data=input_data,config=config))
}

Storage_Correction <- function(){
  suffix_label = 'SC'
  Fluxes <- config$Processing$ThirdStage$Fluxes
  Storage_Terms <- config$Processing$ThirdStage$Storage_Correction
  
  missing_storage_term <- FALSE
  for (flux in names(Fluxes)){
    flux_in <- unlist(Fluxes[[flux]])
    storage <- unlist(Storage_Terms[[flux]])
    # Allow script to proceed but ignore all storage correction terms
    if (sum(!is.na(input_data[[storage]]))==0){
      print(sprintf('!!! Warning !!!   No data present in %s.',storage))
      missing_storage_term <- TRUE
    }
  }
  
  # If one or more storage terms are empty, all storage terms are ignored
  if (!missing_storage_term){
    for (flux in names(Fluxes)){
      flux_in <- unlist(Fluxes[[flux]])
      storage <- unlist(Storage_Terms[[flux]])
  
      flux_out = paste(flux_in,'_',suffix_label,sep="")
      Fluxes[[flux]] <- flux_out
      input_data[[flux_out]] <- input_data[[flux_in]]+input_data[[storage]]
    }
  } else {
    print('All storage terms ignored.')
  }
  config$Processing$ThirdStage$Fluxes <- Fluxes
  input_data <- write_traces(input_data[,c('DateTime',unlist(unname(Fluxes)))],Fluxes,unlink=FALSE)    
  return(list(input_data=input_data,config=config,missing_storage_term=missing_storage_term))
}

JS_Moving_Z <- function(){
  suffix_label = 'JSZ'
  Fluxes <- config$Processing$ThirdStage$Fluxes
  # read filtering parameters from config
  window <- config$Processing$ThirdStage$JS_Moving_Z$window
  z <- config$Processing$ThirdStage$JS_Moving_Z$z_thresh
  
  for (flux in names(Fluxes)){
    flux_in <- unlist(Fluxes[[flux]])
    flux_out = paste(flux_in,'_',suffix_label,sep="")
    input_data[[flux_out]] <- input_data[[flux_in]]
    Fluxes[[flux]] <- flux_out
    na_in <- sum(is.na(input_data[[flux_in]]))
    temp <- input_data[,c('DateTime',flux_in)]
    colnames(temp) <- c('DateTime','F')
    temp <- temp %>% mutate(
      U = slide_index_dbl(.x=F,.i=DateTime,
                          .before=as.difftime(window,units="days"),
                          .after=as.difftime(window,units="days"),
                          .f=function(x) mean(x,na.rm=TRUE),
                          .complete=FALSE)
    )
    temp <- temp %>% mutate(
      sigma = slide_index_dbl(.x=F,.i=DateTime,
                              .before=as.difftime(window,units="days"),
                              .after=as.difftime(window,units="days"),
                              .f=function(x) sd(x,na.rm=TRUE),
                              .complete=FALSE)
    )
    temp$sliding_Z_flag <- (temp$F-temp$U)/temp$sigma
    
    temp$drop <- FALSE
    temp$drop[(is.na((temp$sliding_Z_flag)==TRUE)|
                 abs(temp$sliding_Z_flag) >z
    )] <- TRUE
    input_data[input_data$DateTime %in% temp$DateTime[temp$drop == TRUE],flux_out] <- NA
    na_out <- sum(is.na(input_data[[flux_out]]))
    print(sprintf('%i values in %s were filtered out by moving Z score filter',na_out-na_in,flux))
  }
  config$Processing$ThirdStage$Fluxes <- Fluxes
  input_data <- write_traces(input_data[,c('DateTime',unlist(unname(Fluxes)))],Fluxes,unlink=FALSE)     
  return(list(input_data=input_data,config=config))
}

Papale_Spike_Removal <- function(){
  suffix_label = 'MAD'
  Fluxes <- config$Processing$ThirdStage$Fluxes
  SW_varname <- config$Processing$ThirdStage$REddyProc$vars_in$Rg
  # read filtering parameters from config
  window <- config$Processing$ThirdStage$Papale_Spike_Removal$window
  z <- config$Processing$ThirdStage$Papale_Spike_Removal$z_thresh
  
  # Check to make sure SW_varname is in input_data
  if (!SW_varname %in% names(input_data)){
    sprintf('%s not found in input_data dataframe.',SW_varname)
    sprintf('Check the second stage ini file to make sure %s exists.', SW_varname)
    sprintf('If %s is the wrong variable name, update the site specific yml file accordingly.', SW_varname)
    sprintf('The key-value pair is found in Processing: ThirdStage: REddyProc: vars_in: Rg: %s', SW_varname)
    print('Skipping Papale_Spike_Removal due to error!!!')
    
    return()
  }
  
  # Check to make sure SW isn't empty
  NaN_checksum_SW <- sum(!is.na(input_data[SW_varname]))
  if (NaN_checksum_SW==0){
    sprintf('input_data$%s is empty. Cannot do Papale_Spike_Removal',SW_varname)
    sprintf('Check that data is present in %s following Second Stage processing.',SW_varname)
    print('Skipping Papale_Spike_Removal due to error!!!')
    
    return()
  }
  
  for (flux in names(Fluxes)){
    flux_in <- unlist(Fluxes[[flux]])
    flux_out = paste(flux_in,'_',suffix_label,sep="")
    input_data[[flux_out]] <- input_data[[flux_in]]
    Fluxes[[flux]] <- flux_out
    
    # Check to make sure flux isn't empty -- otherwise behaviour na.omit will cause a crash
    NaN_checksum_flux <- sum(!is.na(input_data[flux_in]))
    
    if (NaN_checksum_flux==0){
      sprintf('There is no data in %s',flux_in)
      sprintf('Data has been copied from %s to %s, but it is all NaNs',flux_in,flux_out)
      sprintf('Check %s from second stage to see if all data is missing.',flux_in)
      sprintf('Check log (above) to see if something else has filtered all data from %s.',flux_in)
    } else{
      ## MAD algorithm, Papale et al. 2006
      # D_N <- list()
      df <- na.omit(input_data[,c('DateTime',flux_in,SW_varname)])
      df$DN <- NA
      df[(df[SW_varname] < 20),'DN'] <- 1
      df[(df[SW_varname] >= 20),'DN'] <- 2
      df$di <- c(NA,diff(df[[flux_in]])) - c(diff(df[[flux_in]]),NA)
      dn <- c('Night','Day')
      for(i in 1:2){
        na_in <- sum(is.na(input_data[[flux_in]]))
        temp <- df[df$DN == i,c(flux_in,'di','DateTime')]
        temp <- temp %>% mutate(
          Md = slide_index_dbl(
            .x=di,
            .i=DateTime,
            .before=as.difftime(window,units="days"),
            .after=as.difftime(window,units="days"),
            .f=function(x) median(x,na.rm=TRUE),
            .complete=FALSE)
        )
        
        temp <- temp %>% mutate(
          MAD_score = slide_index_dbl(
            .x=di,
            .i=DateTime,
            .before=as.difftime(window,units="days"),
            .after=as.difftime(window,units="days"),
            .f=function(x) median(abs(x-median(x,na.rm=TRUE)))*z/0.6745,
            .complete=FALSE)
        )
        
        temp$spike_Flag <- FALSE
        temp$spike_Flag[(is.na((temp$di)==TRUE)|
                           temp$di < temp$Md-temp$MAD_score|
                           temp$di > temp$Md+temp$MAD_score
        )] <- TRUE
        input_data[input_data$DateTime %in% temp$DateTime[temp$spike_Flag == TRUE],flux_out] <- NA
        
        na_out <- sum(is.na(input_data[[flux_out]]))
        print(sprintf('%i values in %s were filtered out by %s-time MAD spike filter',na_out-na_in,flux,dn[i]))   
      }
    }
  }
  config$Processing$ThirdStage$Fluxes <- Fluxes
  input_data <- write_traces(input_data[,c('DateTime',unlist(unname(Fluxes)))],Fluxes,unlink=FALSE)      
  return(list(input_data=input_data,config=config))
}

Run_REddyProc <- function() {
  
  suffix_label = 'RP'
  Fluxes_ini <- config$Processing$ThirdStage$Fluxes
  Fluxes <- Fluxes_ini
  # Subset just the config info relevant to REddyProc
  REddyConfig <- config$Processing$ThirdStage$REddyProc
  Time_Vars <- c("DateTime","Year","DoY","Hour")
  
  # Check to make sure there is data in the fluxes to be gap-filled and partitioned
  #--> The call from Matlab is one year at a time
  if (length(config$years)==1){
    start_time <- paste(as.character(config$years),"-01-01 00:00:00",sep='')
    end_time <- paste(as.character(config$years),"-12-31 23:30:00",sep='')
    
    for (v in names(Fluxes_ini)){
      # Get flux data
      flx2chck <- input_data[,c(Time_Vars,unlist(Fluxes_ini[v]))]
      # Filter for current year
      flx2chck2 <- flx2chck %>% filter(DateTime >= as.POSIXct(start_time, tz = "UTC") & DateTime <= as.POSIXct(end_time, tz = "UTC"))
      
      # If all NaN, remove from REdyyProc processing
      #--> Made threshold 48 in case timezone shift comes into play
      if (sum(!is.na(flx2chck2[unlist(Fluxes_ini[v])]))<48){
        Fluxes <- Fluxes[ - which(names(Fluxes)==v)]
        if (v %in% names(REddyConfig$vars_in)){
          REddyConfig$vars_in <- REddyConfig$vars_in[ - which(names(REddyConfig$vars_in)==v)]
        }
        print(sprintf('<P2M> %s is all NaN in %d, REddyProc will ignore the flux </P2M>',v,config$years))
      }
    }
  }
  
  # Update names for ReddyProc
  for (v in names(REddyConfig$vars_in)){
    if (v %in% names(Fluxes)){
      REddyConfig$vars_in[v] = Fluxes[v]
    }
  }
  
  # Limit to only variables present in input_data (e.g., exclude FCH4 if not present)
  REddyConfig$vars_in <- REddyConfig$vars_in[REddyConfig$vars_in %in% colnames(input_data)]
  
  skip <- names(REddyConfig$vars_in[REddyConfig$vars_in=='NULL']) 
  for (var in skip){
    print(sprintf('%s Not present, REddyProc will not process',var))
  }
  REddyConfig$vars_in <- REddyConfig$vars_in[!REddyConfig$vars_in=='NULL']
  
  # Rearrange data frame and only keep relevant variables for input into REddyProc
  Time_Vars <- c("DateTime","Year","DoY","Hour")
  data_REddyProc <- input_data[ , c(unlist(REddyConfig$vars_in),Time_Vars)]
  # Rename column names to variable names in REddyProc
  colnames(data_REddyProc)<-c(names(REddyConfig$vars_in),Time_Vars)
  
  # Modify REddyConfig$vars_in to dump output names
  invert <- as.list(setNames(names(REddyConfig$vars_in), REddyConfig$vars_in))
  for (v in REddyConfig$vars_in){
    if (!(v %in% Time_Vars) & (invert[v] %in% REddyConfig$MDSGapFill$UStarScens | invert[v] %in% REddyConfig$MDSGapFill$basic) ){
      iv = unlist(unname(invert[v]))
      if (grepl('_PI',v)){
        REddyConfig$vars_in[iv] = paste(v,'_',suffix_label,sep="")
      } else if (!(v %in% Time_Vars)) {
        REddyConfig$vars_in[iv] = paste(v,'_PI_',suffix_label,sep="")
      }
    } 
  }
  
  if (!('season' %in% colnames(data_REddyProc))){
    # Limit to default REddyProc season-years bounding the site-years requested
    # Create Season Year Variable and filter out any SeasonYear with < 700 obs.
    # Exit if no data remain
    start_time <- paste(as.character(min(config$years)-1),"-12-01 00:30:00",sep='')
    end_time <- paste(as.character(max(config$years)+1),"-03-01 00:00:00",sep='')
    data_REddyProc <- data_REddyProc %>% filter(DateTime > as.POSIXct(start_time, tz = "UTC") & DateTime < as.POSIXct(end_time, tz = "UTC"))
    data_REddyProc$SeasonYear = (year(data_REddyProc$DateTime)+floor(month(data_REddyProc$DateTime)/12))
    data_REddyProc[month(data_REddyProc$DateTime)==12 & day(data_REddyProc$DateTime)==1 & data_REddyProc$Hour==0,'SeasonYear'] = data_REddyProc[month(data_REddyProc$DateTime)==12 & day(data_REddyProc$DateTime)==1 & data_REddyProc$Hour==0,'SeasonYear'] - 1
    bySeasonYear <- data_REddyProc %>% group_by(SeasonYear) %>%
      summarise(across(names(REddyConfig$vars_in), ~ sum(!is.na(.)), .names = "countFlag_{col}"))
    
    # # REddyProc Will Crash if given any season with less than 700 observations
    
    # if exists, drop countFlag_FCH4 since it's not uncommon for some years not to have any CH4 data (implemented to avoid filtering the full dataset)
    if ("countFlag_FCH4" %in% colnames(bySeasonYear)) {
      bySeasonYear <- bySeasonYear[, !names(bySeasonYear) %in% "countFlag_FCH4"]
      print("dropped column 'countFlag_FCH4' from bySeasonYear")
    }
    
    seasonFilter <- bySeasonYear %>%  filter(if_any(starts_with("countFlag_"), ~ . < 700))
    date_Drop <- data_REddyProc %>%  filter(SeasonYear %in% seasonFilter$SeasonYear)
    date_Drop <- date_Drop %>% select(DateTime)
    data_REddyProc <- data_REddyProc %>%  filter(!(SeasonYear %in% seasonFilter$SeasonYear))
    time_out <- input_data[c("DateTime","Year","DoY","Hour")] %>% filter(!(DateTime %in% data_REddyProc$DateTime))
    if((dim(data_REddyProc)[1]==0)){
      print('Insufficient data available for specified site-years to run REddyProc')
      return(input_data)
    }
  }
  time_cols <- input_data[c("DateTime","Year","DoY","Hour")] %>% filter(DateTime %in% data_REddyProc$DateTime)
  
  # Run REddyProc
  # Following "https://cran.r-project.org/web/packages/REddyProc/vignettes/useCase.html" This is more up to date than the Wutzler et al. paper
  # NOTE: skipped loading in txt file since already have data in data frame
  # Initalize R5 reference class sEddyProc for post-processing of eddy data with the variables needed for post-processing later
  EProc <- sEddyProc$new(
    config$Metadata$siteID,
    data_REddyProc,
    c(names(REddyConfig$vars_in),'Year','DoY','Hour')) 
  EProc$sSetLocationInfo(LatDeg = config$Metadata$lat, 
                         LongDeg = config$Metadata$long,
                         TimeZoneHour = config$Metadata$TimeZoneHour)
  if (REddyConfig$Ustar_filtering$run_defaults){
    EProc$sEstimateUstarScenarios()
  } else {
    UstFull <- REddyConfig$Ustar_filtering$full_uncertainty
    EProc$sEstimateUstarScenarios( 
      nSample = UstFull$samples,
      probs = seq(
        UstFull$min,
        UstFull$max,
        length.out = UstFull$steps)
    )
  }
  
  #browser()
  if ("USTAR_manual_thresh" %in% names(config$Processing$ThirdStage)){
    # Over-ride Ustar thresholds
    EProc$sUSTAR_SCEN$uStar <- rep(config$Processing$ThirdStage$USTAR_manual_thresh$U50,5)
    EProc$sUSTAR_SCEN$U05 <- rep(config$Processing$ThirdStage$USTAR_manual_thresh$U05,5)
    EProc$sUSTAR_SCEN$U50 <- rep(config$Processing$ThirdStage$USTAR_manual_thresh$U50,5)
    EProc$sUSTAR_SCEN$U95 <- rep(config$Processing$ThirdStage$USTAR_manual_thresh$U95,5)
  }
  
  # Simple MDS for non-Ustar dependent variables
  MDS_basic <- unlist(strsplit(REddyConfig$MDSGapFill$basic, ","))
  MDS_basic <- (MDS_basic[MDS_basic %in% names(REddyConfig$vars_in)])
  for (i in 1:length(MDS_basic)){
    EProc$sMDSGapFill(MDS_basic[i])
  }
  
  # MDS for Ustar dependent variables
  MDS_Ustar <- unlist(strsplit(REddyConfig$MDSGapFill$UStarScens, ","))
  MDS_Ustar <- (MDS_Ustar[MDS_Ustar %in% names(REddyConfig$vars_in)])
  for (i in 1:length(MDS_Ustar)){
    EProc$sMDSGapFillUStarScens(MDS_Ustar[i])
  }
  
  # Nighttime (MR) and Daytime (GL)
  if (REddyConfig$Flux_Partitioning$Run){
    EProc$sMRFluxPartitionUStarScens()
    
    # If daytime partitioning fails, try a fixed E0 for debugging. Use caution when interpreting the results.
    tryCatch({
      EProc$sGLFluxPartitionUStarScens()
    }, error = function(err) {
      print('')
      print('<P2M>Daytime flux partitioning failed!!!</P2M>')
      print('<P2M>Skipping daytime flux partitioning!!!</P2M>')
      
      # Tried running with specified E0 -- doesn't fix the issue...
      #E0_fixed <- EProc$sTEMP$E_0_uStar[1]
      #E0_uncert <- 10 #PLACEHOLDER!!!
      #ctrl <- partGLControl(fixedTempSens = data.frame(E0=E0_fixed,sdE0=E0_uncert))
      #EProc$sGLFluxPartitionUStarScens(controlGLPart = ctrl)
    })
    
  } else {
    print('Skipping flux partitioning')
  }
  
  # Create data frame for REddyProc output
  REddyOutput <- EProc$sExportResults()
  
  # Delete uStar dulplicate columns since they are output for each gap-filled variables
  vars_remove <- c(colnames(REddyOutput)[grepl('\\Thres.', colnames(REddyOutput))],
                   colnames(REddyOutput)[grepl('\\_fqc.', colnames(REddyOutput))])
  if (length(vars_remove)>0){
    REddyOutput <- REddyOutput[, -which(names(REddyOutput) %in% vars_remove)]
  }
  
  # *** Examine Reco and GPP naming ***
  # Reco_uStar is how REddyProc outputs the nighttime partitioned values as opposed to GPP_uStar_f
  # It's not clear from the documentation why this is the case -- see: sEddyProc_sMRFluxPartition
  if (sum(colnames(REddyOutput)=="GPP_uStar_f")==1){
    if (sum(colnames(REddyOutput)=="Reco_uStar")==1){
      ustar_suffixes <-colnames(EProc$sGetUstarScenarios())[-1]
      renamed_cols <- colnames(REddyOutput)
      for (i in 1:length(ustar_suffixes)){
        orig_str <- paste0("Reco_",ustar_suffixes[i])
        new_str <- paste0("Reco_",ustar_suffixes[i],"_f")
        renamed_cols[renamed_cols==orig_str] <- new_str
      }
      colnames(REddyOutput) <- renamed_cols
    }
  }
  
  # Revert to original input name (but maintain ReddyProc modifications that follow first underscore)
  # Most are the same so doesn't matter, but some (e.g., Tair aren't standard AmeriFlux names)
  for (n in names(REddyConfig$vars_in)){
    rep <- paste(as.character(n),"_",sep="")
    sub <- paste(as.character(REddyConfig$vars_in[n]),"_",sep="")
    uNames <- lapply(colnames(REddyOutput), function(x) if (startsWith(x,rep)) {sub(rep,sub,x)} else {x})
    colnames(REddyOutput) <- uNames
  }
  
  # Add the time columns back for writing
  REddyOutput = dplyr::bind_cols(
    time_cols,REddyOutput
  )
  if (exists("time_out")){
    REddyOutput <- bind_rows(time_out,REddyOutput)
    REddyOutput <- REddyOutput[order(REddyOutput$DateTime), ]}
  
  toSave <- c()
  # Important variables to transfer to final third stage output
  for (suffix in REddyConfig$saveBySuffix){
    toSave <- c(toSave,names(REddyOutput)[endsWith(names(REddyOutput),suffix)])
  }
  for (flux in names(Fluxes)){
    flux_in <- unlist(Fluxes[[flux]])
    Fluxes[[flux]] <- toSave[(startsWith(toSave,flux_in)) & (endsWith(toSave,REddyConfig$saveBySuffix[1]))]
  }
  config$Processing$ThirdStage$Fluxes <- Fluxes
  input_data <- write_traces(REddyOutput,toSave)
  return(list(input_data=input_data,config=config))
}

RF_GapFilling <- function(){
  db_root <- config$Database$db_root
  RFConfig <- config$Processing$ThirdStage$RF_GapFilling$Models
  retrain_interval <- config$Processing$ThirdStage$RF_GapFilling$retrain_every_n_months
  # Read function for RF gap-filling data
  p <- sapply(list.files(pattern="RandomForestModel.R", path=config$fx_path, full.names=TRUE), source)
  # Check if dependent variable is available and run RF gap filling if it is
  for (fill_name in names(RFConfig)){
    print(fill_name)
    if (RFConfig[[fill_name]]$var_dep %in% colnames(input_data)){
      try({
        var_dep <- unlist(RFConfig[[fill_name]]$var_dep)
        predictors <- unlist(strsplit(RFConfig[[fill_name]]$Predictors, split = ","))
        vars_in <- c(var_dep,predictors,"DateTime","DoY.x")
        log_path = file.path(db_root,'Calculation_Procedures/TraceAnalysis_ini',config$Metadata$siteID,'log')
        output <- RandomForestModel(input_data[,vars_in],fill_name,log = log_path,retrain_every_n_months = retrain_interval)
        use_existing_model <- output[2]
        rf_results = dplyr::bind_cols(input_data[c("DateTime")],output[1])
        update_names <- as.list(names(rf_results))
        names(update_names) <- names(rf_results)
        input_data <- write_traces(rf_results,update_names)
      })
    }else{
      print('!!!! Warning !!!!')
      print(sprintf('%s Not present, RandomForest will not process',RFConfig[[fill_name]]$var_dep))
    }
  }
  return(input_data)
}

write_traces <- function(data,final_outputs=NULL,unlink=FALSE,suffix_opts=c('x','y')){ 
  # Update names for subset and save to main third stage folder
  siteID <- config$Metadata$siteID
  level_in <- config$Database$Paths$SecondStage
  # Set intermediary output depending on ustar scenario
  # Different output path for default vs advanced
  # This could create some ambiguity as to the source of final data
  if (config$Processing$ThirdStage$REddyProc$Ustar_filtering$run_defaults){
    intermediate_out <- config$Database$Paths$ThirdStage_Default
  } else {
    intermediate_out <- config$Database$Paths$ThirdStage_Advanced
  }
  level_out <- config$Database$Paths$ThirdStage
  tv_input <- config$Database$Timestamp$name
  db_root <- config$Database$db_root
  
  # Dumping everything by default into stage 3
  # Can parse down later as desired
  cols_out <- colnames(data)
  cols_out <- cols_out[! cols_out %in% c("Year","DoY","Hour")]
  
  # Join the incoming data to the inputs incase needed for future use (e.g., ReddyPro outputs in RF)
  input_data <- input_data %>% left_join(., data, by = c('DateTime' = 'DateTime'),suffix=suffix_opts)
  
  for (year in config$years){
    print(sprintf('Writing %i',year))
    # Create new directory, or clear existing directory
    dpath <- file.path(db_root,as.character(year),siteID) 
    if (unlink == TRUE || !dir.exists(file.path(dpath,intermediate_out))) {
      dir.create(file.path(dpath,intermediate_out), showWarnings = FALSE)
      unlink(file.path(dpath,intermediate_out,'*'))
    }
    
    # Copy tv from stage 2 to intermediate stage 3
    file.copy(file.path(dpath,level_in,tv_input),
              file.path(dpath,intermediate_out,tv_input))
    ind_s <- which(year(data$DateTime) == year & yday(data$DateTime) == 1 & hour(data$DateTime) == 0 & minute(data$DateTime) == 30)
    ind_e <- which(year(data$DateTime) == year+1 & yday(data$DateTime) == 1 & hour(data$DateTime) == 0 & minute(data$DateTime) == 0)
    ind <- seq(ind_s[1],ind_e[1])
    
    # Dump all data provided to intermediate output location
    setwd(file.path(dpath,intermediate_out))
    for (col in cols_out){
      print(sprintf('Writing %s',col))
      writeBin(as.numeric(data[ind,col]), col, size = 4)
    }
    
    # Copy/rename final outputs
    for (name in final_outputs){
      if (file.exists(file.path(dpath,intermediate_out,name))){
        print(sprintf('Copying %s from %s to %s',name,intermediate_out,level_out))
        file.copy(
          file.path(dpath,intermediate_out,name),
          file.path(dpath,level_out,name),
          overwrite = TRUE)
      }else{
        print(sprintf('%s was not created, cannot copy to final output for %i',name,year))
      }
    }
  } 
  return(input_data)
}

start.time <- Sys.time()

# Load configuration file
config <- configure()

# Read Stage 2 Data
input_data <- read_and_copy_traces() 

# Check input_data for config$Processing$ThirdStage$Fluxes
Fluxes <- config$Processing$ThirdStage$Fluxes
for (flux in names(Fluxes)){
  flux_name <- unlist(Fluxes[[flux]])
  flux_eval <- input_data[[flux_name]]
  # If 'flux_name' isn't found in 'input_data' remove from config$Processing$ThirdStage$Fluxes
  if (is.null(flux_eval)){
    # Extra error checking
    if(flux_name %in% names(Fluxes)){
      config$Processing$ThirdStage$Fluxes <- config$Processing$ThirdStage$Fluxes[ - which(names(config$Processing$ThirdStage$Fluxes) == flux_name)]
    }
  }
}

# Apply standard cleaning
out <- Standard_Cleaning()
input_data <- out$input_data
config <- out$config

input_data <- Met_Gap_Filling()

out <- Add_PI_label()
input_data <- out$input_data
config <- out$config

# Apply storage correction (if required)
missing_storage_term <- FALSE
if (config$Processing$ThirdStage$Storage_Correction$Run){
  out <- Storage_Correction()
  input_data <- out$input_data
  config <- out$config
}

if (config$Processing$ThirdStage$JS_Moving_Z$Run){
  # JS_Moving_Z
  out <- JS_Moving_Z()
  input_data <- out$input_data
  config <- out$config
} else {
  print('Skipping JS_Moving_Z')
}

# MAD algorithm, Papale et al. 2006
if (config$Processing$ThirdStage$Papale_Spike_Removal$Run){
  out <- Papale_Spike_Removal()
  input_data <- out$input_data
  config <- out$config
} else {
  print('Skipping Papale_Spike_Removal')
}

# Run REddyProc
if (config$Processing$ThirdStage$REddyProc$Run){
  tryCatch(
    {
      out <- Run_REddyProc() 
      input_data <- out$input_data
      config <- out$config
    },error = function(err){
      warnings()
      cat('\n<P2M>Error!!! REddyProc crashed!</P2M>\n')
      cat('\n<P2M> Search the log file for "abc123". Error that caused crash printed below </P2M>\n')
      print(err)
      
      if (config$Processing$ThirdStage$RF_GapFilling$Run){
        config$Processing$ThirdStage$RF_GapFilling$Run <- FALSE
        print('Turning RF_GapFilling off')
      }
    }
  )
} else {
  print('Skipping Run_REddyProc')
}

# Run RF model
if (config$Processing$ThirdStage$RF_GapFilling$Run){
  input_data <- RF_GapFilling()
} else {
  print('Skipping RF_GapFilling')
}

# Calculate uncertainty and annual summaries/statistics if running ThirdStage_Advanced
if (!config$Processing$ThirdStage$REddyProc$Ustar_filtering$run_defaults){
  Fluxes <- config$Processing$ThirdStage$Fluxes 
  # Remove final suffix so that uncertainty can calculate different variables
  Fluxes_trimmed <- lapply(Fluxes, function(x) sub("_[^_]+$", "", x))
  
  AE_variables <- config$Processing$ThirdStage$Annual_Summary$Variables_AE
  
  uncertainty_annual_summary(input_data,
                             Fluxes_trimmed$NEE,
                             Fluxes_trimmed$LE,
                             Fluxes_trimmed$H,
                             c(AE_variables$SW_IN,AE_variables$G),
                             c(Fluxes$LE,Fluxes$H))
}

if (missing_storage_term){
  print('<P2M>One or more storage terms was missing. No storage terms were added to fluxes.</P2M>')
  print('Storage terms can be calculated by re-running EddyPro')
}

end.time <- Sys.time()
print('Stage 3 Complete, total run time:')
print(end.time - start.time)
