# Script to read data available in the database
# By Sara Knox
# Created June, 2024

# Inputs

# basepath <- "specify/your/path/here"
# yrs <- select years (e.g., c(2016:2020)) or just  a single year (e.g., 2016)
#site <- select site (e.g., "BB1")
#level <- select levels (e.g., c("Met","Flux")) or just a single level (e.g., "Met"). Can also include subfolders (e.g., "Met/clean")
#variables <- select variables (e.g., c("AIR_TEMP_2M","TKE"))
#tv_input <- either "clean_tv" or "Clean_tv" depending on the level
#export <- 1 to save csv file, else 0
#outpath <- "specify/your/path/here/"
#outfilename <- specify file name (e.g., "BB1_subset_2020")

read_data_all_years <-
  function(basepath,
           yrs,
           site,
           level,
           tv_input,
           variables,
           export,
           outpath,
           outfilename) {
    
    # Loop through years
    for (i in 1:length(yrs)) {
      
      inpath <-
        paste(basepath,
              "/",
              as.character(yrs[i]),
              "/",
              site,
              "/",
              level[1],
              sep = "")
      
      #setwd()
      #Convert Matlab timevector to POSIXct
      tv <- readBin(paste0(inpath,"/",tv_input,sep=""), double(), n = 18000)
      datetime <-
        as.POSIXct((tv - 719529) * 86400, origin = "1970-01-01", tz = "UTC")
      
      # Round to nearest 30 min
      datetime <- lubridate::round_date(datetime, "30 minutes")
      
      #setup empty dataframe
      frame <- data.frame(matrix(ncol = 1, nrow = length(datetime)))
      
      # Loop through levels
      for (j in 1:length(level)) {
        inpath <-
          paste(basepath,
                "/",
                as.character(yrs[i]),
                "/",
                site,
                "/",
                level[j],
                sep = "")
        
        #Extract data of interest
        ##Use a loop function to read selected binary files and bind to the empty dataframe
        
        # if variables not defined
        if( !is.null("variables") )
        {
          all_files_folders <- list.files(paste0(inpath,"/"), recursive = FALSE, full.names = FALSE)
          variables <- all_files_folders[!file.info(file.path(paste0(inpath,"/"), all_files_folders))$isdir] # Get file information and filter out directories
        }
        
        if (length(variables) != 0) { # Remove?
          for (k in 1:length(variables)) {
            if (variables[k] %in% list.files(inpath, recursive = FALSE)) {
              # If the variable is included in the current level
              
              # Skip the data_EP.txt file and other variables/folders
              if (grepl(".txt$", variables[k])) next 
              if (grepl(".csv$", variables[k])) next 
              if (grepl("clean_tv", variables[k])) next 
              if (grepl("Clean_tv", variables[k])) next 
              if (grepl("DateTime", variables[k])) next 
              if (grepl("TimeVector", variables[k])) next 
              if (grepl("ProcessingSettings.yml", variables[k])) next 
              if (grepl("Clean", variables[k])) next 
              if (grepl("clean", variables[k])) next 
              if (grepl("Manual", variables[k])) next 
              if (grepl("NARR", variables[k])) next
              if (grepl("badWD", variables[k])) next #Revisit!
              
              data <-
                data.frame(readBin(paste0(inpath,"/",variables[k],sep=""), numeric(), n = 18000, size = 4))
              colnames(data) <- variables[k]
              frame <- cbind(frame, data)
            }
          }
        }
      }
      
      df <-
        subset(frame, select = -c(1)) #remove the first column that does not contain information
      df <- cbind(datetime, df) #Combine data with datetime
      
      # Make sure all input variables are included in the dataframe
      if (sum(which(variables %in% colnames(df) == FALSE)) > 0) {
        cat("variables: ", variables[which(variables %in% colnames(df) == FALSE)],"are not included in the dataframe", sep="\n")
      }
      
      if (i == 1) {
        empty_df = df[FALSE, ]
        dfmultiyear <- dplyr::bind_rows(empty_df, df)
      } else {
        dfmultiyear <- dplyr::bind_rows(dfmultiyear, df)
      }
    }
    
    if( !is.null("export") ){
      export <- 0
    }
    
    if (export == 1) {
      write.csv(df, paste(outpath, outfilename, ".csv", sep = ""))
    }
    return(dfmultiyear)
  }
