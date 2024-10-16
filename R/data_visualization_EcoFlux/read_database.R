# Function written to load database variables and export to csv file (exporting is optional)
# By Sara Knox
# March 13, 2022

# Inputs

# basepath <- "specify/your/path/here"
# yrs <- select years (e.g., c(2016:2020)) or just  a single year (e.g., 2016)
#site <- select site (e.g., "BB1")
#levels <- select levels (e.g., c("Met","Flux")) or just a single level (e.g., "Met"). Can also include subfolders (e.g., "Met/clean")
#vars <- select years (e.g., c("AIR_TEMP_2M","TKE"))
#tv_input <- either "clean_tv" or "Clean_tv" depending on the level
#export <- 1 to save csv file, else 0
#outpath <- "specify/your/path/here/"
#outfilename <- specify file name (e.g., "BB1_subset_2020")

# Revisions:
#  Nov 2, 2022 (Zoran)
#    - renamed the function from read.export.data to read_database


# to output R dataframe, use df <- read_database(basepath,yrs,site,level,vars,outpath,outfilename,export)

read_database <-
  function(basepath,
           yrs,
           site,
           level,
           vars,
           tv_input,
           export,
           outpath,
           outfilename) {
    
    # Load libraries
    library(reshape2)
    library(stringr)
    library(lubridate)
    
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
        for (k in 1:length(vars)) {
          if (vars[k] %in% list.files(inpath)) {
            # If the variable is included in the current level
            
            # Skip the data_EP.txt file
            if (grepl(".txt$", vars[k])) next 
            if (grepl("clean_tv", vars[k])) next 
            
            data <-
              data.frame(readBin(paste0(inpath,"/",vars[k],sep=""), numeric(), n = 18000, size = 4))
            colnames(data) <- vars[k]
            frame <- cbind(frame, data)
          }
        }
      }
      df <-
        subset(frame, select = -c(1)) #remove the first column that does not contain information
      df <- cbind(datetime, df) #Combine data with datetime
      
      # Make sure all input vars are included in the dataframe
      if (sum(which(vars %in% colnames(df) == FALSE)) > 0) {
        cat("variables: ", vars[which(vars %in% colnames(df) == FALSE)],"are not included in the dataframe", sep="\n")
      }
      
      if (i == 1) {
        empty_df = df[FALSE, ]
        dfmultiyear <- bind_rows(empty_df, df)
      } else {
        dfmultiyear <- bind_rows(dfmultiyear, df)
      }
    }
    
    if (export == 1) {
      write.csv(df, paste(outpath, outfilename, ".csv", sep = ""))
    }
    return(dfmultiyear)
  }
