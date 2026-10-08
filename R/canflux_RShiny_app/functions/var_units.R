# Script to match variables to their AmeriFlux variable, units and description
# By Sara Knox, Created June, 2024; vectorised 2026 (same matching rules)

var_units <- function(Variables, UnitCSVFilePath) {
  # -------------------------------------------------------------------------- #
  # ARGUMENTS:
  # - Variables [chr]: variable names (e.g. "TA_1_1_1")
  # - UnitCSVFilePath [str]: path to the AmeriFlux variable CSV
  # OUTPUT:
  # - data.frame with columns name, variable (AmeriFlux base name), units,
  #   description
  # -------------------------------------------------------------------------- #
  if (is.null(.cq_cache$flux_var)) {
    .cq_cache$flux_var <- utils::read.csv(UnitCSVFilePath, stringsAsFactors = FALSE,
                                          encoding = "UTF-8", check.names = FALSE)
  }
  flux_var <- .cq_cache$flux_var

  # Text before the first "_<digit>" and before "_PI", upper case
  shortnames <- sub("_[0-9].*$", "", Variables)
  shortnames <- toupper(sub("_PI.*$", "", shortnames))

  i <- match(shortnames, flux_var$Variable)
  out <- data.frame(name = Variables,
                    variable = shortnames,
                    units = ifelse(is.na(i), "", flux_var$Units[i]),
                    description = ifelse(is.na(i), "", flux_var$Description[i]),
                    stringsAsFactors = FALSE)
  # Columns created by the app (create_EBC_columns)
  ae <- grepl("^AE_", Variables); hle <- Variables == "H_LE"
  out$units[ae | hle] <- "W m-2"
  out$description[ae] <- "Available energy (NETRAD - G)"
  out$description[hle] <- "Turbulent fluxes (H + LE)"
  out
}

# Axis label "NAME (units)" for a variable, using a var_units() table
unit_label <- function(name, units_tbl) {
  u <- units_tbl$units[match(name, units_tbl$name)]
  if (length(u) == 0 || is.na(u) || !nzchar(u)) name else paste0(name, " (", u, ")")
}
