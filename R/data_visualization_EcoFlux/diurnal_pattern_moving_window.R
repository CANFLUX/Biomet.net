# Script for calculating diurnal patterns over a fixed moving window
# By Sara Knox
# June 30, 2022

# Input
# data = data frame
# var_interest = variable of interest
# width = width of moving windows in days
# ts = timestep (i.e., 48 half hour observations per day)

# Loop through data frame to create mean diurnal patter for an n day moving average
diurnal.summary <- function(data, var_interest, width, ts) {
  
  # Create new dataframe with only variables of interest
  df <- (data[, (colnames(data) %in% c("datetime", var_interest))])
  
  # Find index of first midnight time point
  istart <-
    first(which(hour(df$datetime) == 0 & minute(df$datetime) == 0))
  iend <- last(which(hour(df$datetime) == 23 & minute(df$datetime) == 30))
  
  # Create new data frame starting from midnight and ending at 11:30pm
  df2 <- df[istart:iend, ]
  
  # Rename column names
  colnames(df2) <- c("datetime", "var")
  
  # Specify number of windows to loop through
  nwindows <- floor(nrow(df2) / width / ts)
  
  #setup empty dataframe
  diurnal.summary <- data.frame(matrix(ncol = 7, nrow = 0))
  
  for (i in 1:nwindows) {
    if (i == 1) {
      ind <- 1:(width * ts)
      
    } else {
      ind <- ((i - 1) * width*ts + 1):(i * width*ts)
    }
    
    data.diurnal <- df2[ind, ] %>%
      mutate(
        year = year(datetime),
        month = month(datetime),
        day = day(datetime),
        jday = yday(datetime),
        hour = hour(datetime),
        minute = minute(datetime),
        HHMM = format(as.POSIXct(datetime), format = "%H:%M")
      ) %>%  # Create hour and minute variable (HHMM)
      group_by(year, jday, HHMM) %>%
      dplyr::summarize(var = var,
                       date = median(datetime))
    
    # Create a column for the same date for a given window (for plotting purposes)
    data.diurnal$firstdate <-
      last(format(
        as.POSIXct(data.diurnal$date , format = '%Y-%m-%d %H:%M:%S'),
        format = '%Y-%m-%d'
      ))
    
    # Append to dataframe
    diurnal.summary <- rbind(diurnal.summary, data.diurnal)
  }
  
  # Create new time variable for plotting purposes
  diurnal.summary$time <- as.POSIXct(as.character( diurnal.summary$HHMM), format="%R", tz="UTC")
  
  diurnal.summary <- diurnal.summary[is.finite(diurnal.summary$var), ]
  
  return(diurnal.summary)
}
