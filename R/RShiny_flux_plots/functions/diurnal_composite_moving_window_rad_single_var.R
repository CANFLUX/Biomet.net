# Script for calculating composite of diurnal patterns over a fixed moving window
# By Sara Knox
# June 27, 2022

# Input
# data = data frame
# potential_radiation_var = variable name for potential radiation
# rad_var = variable name for radiation variable (either SW_IN_1_1_1 or PPFD_IN_1_1_1)
# width = width of moving windows in days
# ts = timestep (i.e., 48 half hour observations per day)

# Loop through data frame to create mean diurnal patter for a 15 day moving average
diurnal_composite_rad_single_var <- function(data,potential_radiation_var,rad_var,width,ts){
  
  # Create new dataframe with only variables of interest
  df <- (data[, (colnames(data) %in% c("datetime", potential_radiation_var,rad_var))])
  
  # Find index of first midnight time point
  istart <- first(which(hour(df$datetime) == 0 & minute(df$datetime) == 0))
  iend <- last(which(hour(df$datetime) == 23 & minute(df$datetime) == 30))
  
  # Create new data frame starting from midnight and ending at 11:30pm
  df2 <- df[istart:iend, ]
  
  # Rename column names
  colnames(df2) <- c("datetime", rad_var, "potential_radiation")
  
  # Convert NaN to NA if present
  df2[sapply(df2, is.numeric)] <- lapply(df2[sapply(df2, is.numeric)], function(x) { x[is.nan(x)] <- NA; x })
  
  # Specify number of windows to loop through
  nwindows <- floor(nrow(df2)/width/ts)
  
  #setup empty dataframe
  diurnal.composite <- data.frame(matrix(ncol=5, nrow=0)) 
  colnames(diurnal.composite)<- c("HHMM","potential_radiation",rad_var, "date")
  
  for (i in 1:nwindows){
    
    if (i == 1) {
      data.diurnal <- df2[1:(width*ts), ] %>%
        mutate(year = year(datetime),
               month = month(datetime),
               day = day(datetime),
               jday = yday(datetime),
               hour = hour(datetime),
               minute = minute(datetime),
               HHMM = format(as.POSIXct(datetime), format = "%H:%M")) %>%  # Create hour and minute variable (HHMM)
        group_by(HHMM) %>%
        dplyr::summarize(potential_radiation = max(potential_radiation, na.rm = TRUE),
                         radiation = max(get(rad_var), na.rm = TRUE),
                         date = median(datetime))
      
      # Create a column for the same date for a given window (for plotting purposes)
      data.diurnal$firstdate <- last(format(as.POSIXct(data.diurnal$date ,format='%Y-%m-%d %H:%M:%S'),format='%Y-%m-%d'))
      
      # Append to dataframe
      diurnal.composite <- rbind(diurnal.composite,data.diurnal)
      
      # Replace -Inf with NA
      diurnal.composite$radiation[is.infinite(diurnal.composite$radiation)] <- NA
      
    } else {
      data.diurnal <- df2[((i-1)*width*ts+1):(i*width*ts), ] %>%
        mutate(year = year(datetime),
               month = month(datetime),
               day = day(datetime),
               jday = yday(datetime),
               hour = hour(datetime),
               minute = minute(datetime),
               HHMM = format(as.POSIXct(datetime), format = "%H:%M")) %>%  # Create hour and minute variable (HHMM)
        group_by(HHMM) %>%
        dplyr::summarize(potential_radiation = max(potential_radiation, na.rm = TRUE),
                         radiation = max(get(rad_var), na.rm = TRUE),
                         date = median(datetime))
      
      # Create a column for the same date for a given window (for plotting purposes)
      data.diurnal$firstdate <- last(format(as.POSIXct(data.diurnal$date ,format='%Y-%m-%d %H:%M:%S'),format='%Y-%m-%d'))
      
      # Append to dataframe
      diurnal.composite <- rbind(diurnal.composite,data.diurnal)
      
      # Replace -Inf with NA
      diurnal.composite$radiation[is.infinite(diurnal.composite$radiation)] <- NA
    }
  }
  
  # Find points where SW_IN > potential radiation
  if (grepl("SW_IN", rad_var, fixed = TRUE) == TRUE) {
    
    diurnal.composite$exceeds <- diurnal.composite$radiation
    diurnal.composite$exceeds[which(diurnal.composite$radiation < diurnal.composite$potential_radiation)] <- NA
  }
  
  # Create new time variable for plotting purposes
  diurnal.composite$time <- as.POSIXct(as.character(diurnal.composite$HHMM), format="%R", tz="UTC")
  
  # Rename column name
  diurnal.composite <- diurnal.composite %>% rename_with(~rad_var,radiation)
  
  return(diurnal.composite)
}

