# Script for calculating potential radiation
# By Sara Knox
# June 27, 2022
# 2026: vectorised (no hms/string parsing), same equations and results.

# Input
# Standard_meridian = standard meridian of site
# long = longitude of site
# Lat = latitude of site
# datetime = POSIXct time stamps
# DOY = day of year (recomputed from datetime, kept for compatibility)

potential_rad_generalized <- function(Standard_meridian, long, Lat, datetime, DOY = NULL) {

  # Solar constant
  Io <- 1366.5 # units of W m-2

  # Define the difference between site's longitude and the standard meridian
  delta_long <- long - Standard_meridian

  # Standard time, in seconds after midnight (clock time of the time stamps)
  lt <- as.POSIXlt(datetime)
  ST <- lt$hour * 3600 + lt$min * 60 + lt$sec

  # Local mean solar time: 4 minutes per degree of longitude
  LMST <- ST + delta_long * 4 * 60

  # Day of year and gamma
  DOY <- lt$yday + 1
  gamma <- ((2 * pi / 365) * (DOY - 1))

  # Time offset between LMST and local apparent time (minutes)
  deltaT_LAT <- 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma) -
                            0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))

  # LAT = LMST - deltaT_LAT (seconds)
  LAT <- LMST - deltaT_LAT * 60

  # Hour of the day, keeping whole minutes only (as the original hh:mm parsing did)
  LAT2 <- (LAT %/% 3600) + ((LAT %% 3600) %/% 60) / 60

  # Hour angle, rounded to the nearest degree
  h <- round(15 * (12 - LAT2))

  # Declination angle (radians -> degrees)
  delta2 <- 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) - 0.006758 * cos(2 * gamma) +
    0.000907 * sin(2 * gamma) - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
  delta2deg <- delta2 * (180 / pi)

  # Solar altitude angle
  sinbeta <- sin(Lat * (pi / 180)) * sin(delta2deg * (pi / 180)) +
    cos(Lat * (pi / 180)) * cos(delta2deg * (pi / 180)) * cos(h * (pi / 180))

  # Account for the non-circular orbit
  ratio2 <- 1.00011 + 0.034221 * cos(gamma) + 0.001280 * sin(gamma) +
    0.000719 * cos(2 * gamma) + 0.000077 * sin(2 * gamma)

  KEx <- Io * ratio2 * sinbeta

  # Force nighttime data to 0
  KEx[KEx < 0] <- 0

  KEx
}
