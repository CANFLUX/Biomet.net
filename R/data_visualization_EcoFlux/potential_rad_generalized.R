# Script for calculating potential radiation
# By Sara Knox
# June 27, 2022

# Input
# Standard_meridian = standard meridian of site
# long = longitude of site
# Lat = latitude of site

potential_rad_generalized <- function(Standard_meridian,long,Lat,datetime,DOY){
  
  # Solar constant
  Io  <- 1366.5 # units of W m−2
  
  # Define the difference between site's longitude and the standard meridian
  delta_long  <-  long-Standard_meridian
  
  # Standard time
  ST <- as_hms(datetime)
  # Calculate LMST 
  LMST <- ST+hms(0,delta_long*4,0)
  
  # This is needed to output LMST in R's time format
  LMST <- hms(as.numeric(LMST))
  
  # Calculate DOY and gamma
  DOY <- yday(datetime)
  gamma <- ((2*pi/365)*(DOY-1))
  
  # Next the time offset between LMST and LAT (∆TLAT, i.e. deltaT_LAT), in minutes can be calculated using the formula given in Lecture 4, Slide 12
  deltaT_LAT <- 229.18*(0.000075 + 0.001868*cos(gamma) - 0.032077*sin(gamma) - 0.014615*cos(2*gamma) - 0.040849*sin(2*gamma))
  
  # Convert to R time format 
  deltaT_LAT <- hms(seconds = NULL, minutes = deltaT_LAT, hours = NULL, days = NULL)
  
  # Hence, LAT = LMST − ∆TLAT
  LAT <- LMST - hms(as.numeric(deltaT_LAT))
  
  # This is needed to output LAT in R's time format
  LAT <- hms(as.numeric(LAT))
  
  # Note LAT is the local apparent time (see above) in hours of the day (with minutes as a fraction of an hour). This can be calculated using the following:
  # This converts hh:mm:ss to hour of the day
  LAT2 <- sapply(strsplit(as.character(LAT),":"),
                 function(x) {
                   x <- as.numeric(x)
                   x[1]+x[2]/60
                 }
  )
  
  # Now calculate h
  h <- round(15*(12-LAT2)) # Round the hour angle to the nearest degree using round()
  
  # Next, estimate the declination angle using the more precise method. We will call this variable delta2 
  delta2 <- 0.006918 - 0.399912*cos(gamma) + 0.070257*sin(gamma) - 0.006758*cos(2*gamma) + 0.000907*sin(2*gamma) - 0.002697*cos(3*gamma) + 0.00148*sin(3*gamma)
  
  # Note that delta2 is in radians - we need to convert radians to degrees
  delta2deg <- delta2*(180/pi)
  
  # Now we can calculate the solar altitude angle
  # First calculate sin β - note that we have to convert angles in degrees to radians (multiply degrees by (pi/180))
  sinbeta <- sin(Lat*(pi/180))*sin(delta2deg*(pi/180))+cos(Lat*(pi/180))*cos(delta2deg*(pi/180))*cos(h*(pi/180))
  
  # Account for the non-circular orbit (changing distance over course of a year) (note gamma is calculated above)
  ratio2 <- 1.00011 + 0.034221*cos(gamma) + 0.001280*sin(gamma) + 0.000719*cos(2*gamma) + 0.000077*sin(2*gamma)
  
  # Calculate KEx (note that sinbeta is estimated above)
  KEx <- Io*ratio2*sinbeta
  
  # Force nighttime data to 0
  KEx[KEx<0] <- 0
  
  potential_rad <- KEx
}




