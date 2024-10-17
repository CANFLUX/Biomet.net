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
# args <- c("C:/Database","siteID",startYear,endYear)
# source("C:/Biomet.net/R/database_functions/ThirdStage.R")

# # If current directory is the the root of a database
# setwd(C:/Database)
# args <- c("siteID",startYear,endYear)
# source("C:/Biomet.net/R/database_functions/ThirdStage.R")

# Package names
packages <- c("fs", "yaml", "REddyProc", "rlist", "zoo", "dplyr", "lubridate", "data.table", "reshape2", "stringr", "tidyverse", "ranger", "caret", "ggplot2")

# Install packages not yet installed
installed_packages <- packages %in% rownames(installed.packages())
if (any(installed_packages == FALSE)) {
  install.packages(packages[!installed_packages])
}

# Packages loading
invisible(lapply(packages, library, character.only = TRUE))

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

# Read a the global database configuration
  filename <- file.path(db_root,'Calculation_Procedures/TraceAnalysis_ini/global_config.yml')
  dbase_config = yaml.load_file(filename)
  
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
  if(is.null(config$Processing$ThirdStage$Storage$Apply_Correction)){
    config$Processing$ThirdStage$Storage$Apply_Correction=TRUE
  }
  if(is.null(config$Processing$ThirdStage$REddyProc$Run)){
    config$Processing$ThirdStage$REddyProc$Run=TRUE
  }
  if(is.null(config$Processing$ThirdStage$RF_GapFilling$Run)){
    config$Processing$ThirdStage$RF_GapFilling$Run=TRUE
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

storage_correction <- function(){
  Storage_Terms <- config$Processing$ThirdStage$Storage$Terms
  terms <- names(Storage_Terms)
    for (term in terms){
      flux <- names(Storage_Terms[[term]])
      storage <- unlist(unname(Storage_Terms[[term]]))
      browser()
      # Default behavior is to apply correction 
      if (flux %in% colnames(input_data) && config$Processing$ThirdStage$Storage$Apply_Correction) {
        input_data[[term]] <- input_data[[flux]]+input_data[[storage]]
      # If storage correction is set to false, still create the variable (eg NEE = FC) so it doesn't break anything
      }else if (flux %in% colnames(input_data) && !config$Processing$ThirdStage$Storage$Apply_Correction) {
        input_data[[term]] <- input_data[[flux]]
      # Or notify user if not available
      }else{
        print(sprintf('%s Not present in Second Stage, excluding from storage correction',flux))
      }
  }
  return(input_data)
}

Run_REddyProc <- function() {
  # Subset just the config info relevant to REddyProc
  REddyConfig <- config$Processing$ThirdStage$REddyProc
  
  # Limit to only variables present in input_data (e.g., exclude FCH4 if not present)
  REddyConfig$vars_in <- lapply(REddyConfig$vars_in, function(x) if (x %in% colnames(input_data)){x})
  skip <- names(REddyConfig$vars_in[REddyConfig$vars_in=='NULL']) 
  for (var in skip){
    print(sprintf('%s Not present, REddyProc will not process',var))
  }
  REddyConfig$vars_in <- REddyConfig$vars_in[!REddyConfig$vars_in=='NULL']
  
  # Rearrange data frame and only keep relevant variables for input into REddyProc
  data_REddyProc <- input_data[ , c(unlist(REddyConfig$vars_in),"DateTime","Year","DoY","Hour")]
  # Rename column names to variable names in REddyProc
  colnames(data_REddyProc)<-c(names(REddyConfig$vars_in),"DateTime","Year","DoY","Hour")
  
  if (!('season' %in% colnames(data_REddyProc))){
    # Limit to default REddyProc season-years bounding the site-years requested
    # Create Season Year Variable and filter out any SeasonYear with < 700 obs.
    # Exit if no data remain
    start_time <- paste(as.character(min(config$years)-1),"-12-01 00:00:00",sep='')
    end_time <- paste(as.character(max(config$years)+1),"-03-01 00:00:00",sep='')
    data_REddyProc <- data_REddyProc %>% filter(DateTime > as.POSIXct(start_time, tz = "UTC") & DateTime < as.POSIXct(end_time, tz = "UTC"))
    data_REddyProc$SeasonYear = (year(data_REddyProc$DateTime)+floor(month(data_REddyProc$DateTime)/12))
    bySeasonYear <- data_REddyProc %>%
    group_by(SeasonYear) %>%
    summarise(across(names(REddyConfig$vars_in), ~ sum(!is.na(.)), .names = "countFlag_{col}"))
    # # REddyProc Will Crash if given any season with less than 700 observations
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
  EProc$sMRFluxPartitionUStarScens()
  EProc$sGLFluxPartitionUStarScens()
  
  # Create data frame for REddyProc output
  REddyOutput <- EProc$sExportResults()

  # Delete uStar dulplicate columns since they are output for each gap-filled variables
  vars_remove <- c(colnames(REddyOutput)[grepl('\\Thres.', colnames(REddyOutput))],
                   colnames(REddyOutput)[grepl('\\_fqc.', colnames(REddyOutput))])
  if (length(vars_remove)>0){
    REddyOutput <- REddyOutput[, -which(names(REddyOutput) %in% vars_remove)]
  }
  
  # Revert to original input name (but maintain ReddyProc modifications that follow first underscore)
  # Most are the same so doesn't matter, but some (e.g., Tair aren't standard AmeriFlux names)
  for (i in 1:length(REddyConfig$vars_in)){
    rep <- paste(as.character(names(REddyConfig$vars_in[i])),"_",sep="")
    sub <- paste(as.character(REddyConfig$vars_in[i]),"_",sep="")
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

  # Write all REddyProc outputs to intermediate folder
  # Update names for subset and save to main third stage folder
  update_names <- config$Processing$ThirdStage$AmeriFlux_Names
  input_data <- write_traces(REddyOutput,update_names,unlink = TRUE)

  return(input_data)
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
        vars_in <- c(var_dep,predictors,"DateTime","DoY")
        log_path = file.path(db_root,'Calculation_Procedures/TraceAnalysis_ini',config$Metadata$siteID,'log')
        output <- RandomForestModel(input_data[,vars_in],fill_name,log = log_path,retrain_every_n_months = retrain_interval)
        use_existing_model <- output[2]
        gap_filled = dplyr::bind_cols(input_data[c("DateTime","Year","DoY","Hour")],output[1])
        update_names <- list(fill_name)
        names(update_names) <- c(fill_name)
        input_data <- write_traces(gap_filled,update_names)
      })

    }else{
      print('!!!! Warning !!!!')
      print(sprintf('%s Not present, RandomForest will not process',RFConfig[[fill_name]]$var_dep))
    }
  }
  return(input_data)
}

write_traces <- function(data,update_names,unlink=FALSE){ 
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
    ind_s <- which(data$Year == year & data$DoY == 1 & data$Hour == 0.5)
    ind_e <- which(data$Year == year+1 & data$DoY == 1 & data$Hour == 0)
    ind <- seq(ind_s,ind_e)
    
    # Dumping everything by default into stage 3
    # Can parse down later as desired
    cols_out <- colnames(data)
    cols_out <- cols_out[! cols_out %in% c("Year","DoY","Hour")]
  
    update_names = update_names[names(update_names)!='DateTime']
    # Drop incoming data from input data (simplifies join procedures)
    input_data <- input_data[,!(names(input_data) %in% names(update_names))]

    # add DateTime to use as join key
    update_names <- c('DateTime'='DateTime',update_names)
    # Subset of traces can get appended to the input_data frame for use in subsequent steps if needed
    append_cols <- data[unlist(update_names[update_names %in% cols_out])]
    colnames(append_cols) <- names(update_names[update_names %in% cols_out])
    
    # Join the incoming data to the inputs incase needed for future use (e.g., ReddyPro outputs in RF)
    input_data <- input_data %>% left_join(., append_cols, by = c('DateTime' = 'DateTime'))

    # Dump all data provided to intermediate output location
    setwd(file.path(dpath,intermediate_out))
    for (col in cols_out){
      print(sprintf('Writing %s',col))
      writeBin(as.numeric(data[ind,col]), col, size = 4)
    }
    
    # Copy/rename final outputs
    for (name in names(update_names)){
      if (file.exists(file.path(dpath,intermediate_out,update_names[name]))){
        print(sprintf('Copying %s to %s',update_names[name],name))
        file.copy(
          file.path(dpath,intermediate_out,update_names[name]),
          file.path(dpath,level_out,name),
          overwrite = TRUE)
      }else{
        print(sprintf('%s was not created, cannot copy to final output for %i',update_names[name],year))
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

input_data <- Met_Gap_Filling()

# Apply storage correction (if required)
input_data <- storage_correction()

# Run REddyProc
if (config$Processing$ThirdStage$REddyProc$Run){
  input_data <- Run_REddyProc() 
}

# Run RF model
if (config$Processing$ThirdStage$RF_GapFilling$Run){
  input_data <- RF_GapFilling()
} 

end.time <- Sys.time()
print('Stage 3 Complete, total run time:')
print(end.time - start.time)
