# This function updates Biomet.net packages
# By Zoran Nesic
# Mar 11, 2025


updateBiometNetPackages <- function() {
  sprintf("start\n")
  # Package names
  packages <- c("REddyProc", "dplyr", "lubridate", "data.table")
  cat("end\n")
  
  # Install packages not yet installed
  installed_packages <- packages %in% rownames(installed.packages())
  if (any(installed_packages == FALSE)) {
    install.packages(packages[!installed_packages])
  }
  
  # Packages loading
  invisible(lapply(packages, library, character.only = TRUE))


}
