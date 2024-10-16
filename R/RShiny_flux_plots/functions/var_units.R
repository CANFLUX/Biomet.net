# Script to matche user-input variables to their AmeriFlux Variable and Units ounterparts
# By Sara Knox
# Created June, 2024

var_units <- function(Variables, UnitCSVFilePath) {
  # -------------------------------------------------------------------------- #
  # ARGUMENTS:
  # - Variables [list]: list of variable names 
  # - UnitCSVFilePath [str]: A string that contains the path to an AmeriFlux
  #   CSV
  # PURPOSE:
  # - matches user-inputted variables to their AmeriFlux Variable and Units 
  #   counterparts.
  # OUTPUT:
  # - returns a dataframe containing the AmeriFlux Varaibles and Units data 
  #   adhering to the user-inputted csv's.
  # -------------------------------------------------------------------------- #
  shortnames <- sapply(strsplit(Variables, split = "(_[0-9])"), '[',1)
  shortnames <- sapply(strsplit(shortnames, split = "_PI"),'[',1)
  
  units <- data.frame(name = Variables,
                      variable = shortnames)
  
  flux_var <- read.csv(UnitCSVFilePath)
  flux_var <- flux_var[, c('Variable',
                           'Units',
                           'Type')]
  
  for (i in 1:length(units$variable)) {
    units$variable[i] <- stringr::str_to_upper(units$variable[i])
  }
  
  data_units <- vector(mode='character',length=length(units$variable))
  for (i in 1:length(units$variable)) {
    
    if (length(which(flux_var$Variable %in% units$variable[i])) > 0) {
      ind <- which(flux_var$Variable %in% units$variable[i])
      data_units[i] <- flux_var$Units[ind]
    }
  }
  
  units$units <- data_units
  return(units)
}
