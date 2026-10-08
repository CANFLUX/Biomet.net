# Function to create columns to assess energy balance closure
# By Sara Knox; updated 2026 to work on data.table/data.frame and to skip
# gracefully when a site has no net radiation, ground heat flux, H or LE.
#
# Adds:
#   AE[_G][_NETRAD] = available energy = NETRAD - G (or NETRAD when G is missing)
#   H_LE            = turbulent fluxes = H + LE

# Derived energy balance variables available from a set of column names:
# a named list, name -> c(source1, source2, operator) (or just source1)
derived_vars <- function(cols) {
  out <- list()
  g_col <- grep("^G_1(_1_1)?$", cols, value = TRUE)
  if ("G_1" %in% g_col) g_col <- "G_1"
  g_col <- g_col[1]
  netrad_col <- grep("^NETRAD(_1_1_1)?$", cols, value = TRUE)[1]
  if (!is.na(netrad_col)) {
    ae_name <- paste0("AE", if (!is.na(g_col)) "_G", "_NETRAD")
    out[[ae_name]] <- if (!is.na(g_col)) c(netrad_col, g_col, "-") else netrad_col
  }
  h_col  <- grep("^H(_.*_uStar_orig)?$", cols, value = TRUE)[1]
  le_col <- grep("^LE(_.*_uStar_orig)?$", cols, value = TRUE)[1]
  if (!is.na(h_col) && !is.na(le_col)) out[["H_LE"]] <- c(h_col, le_col, "+")
  out
}

create_EBC_columns <- function(data) {
  cols <- colnames(data)

  # Ground heat flux: "G_1" or "G_1_1_1" (prefer "G_1" when both exist)
  g_col <- grep("^G_1(_1_1)?$", cols, value = TRUE)
  if ("G_1" %in% g_col) g_col <- "G_1"
  g_col <- g_col[1]

  # Net radiation: "NETRAD" or "NETRAD_1_1_1"
  netrad_col <- grep("^NETRAD(_1_1_1)?$", cols, value = TRUE)[1]

  if (!is.na(netrad_col)) {
    ae <- data[[netrad_col]]
    if (!is.na(g_col)) ae <- ae - data[[g_col]]
    ae_name <- paste0("AE", if (!is.na(g_col)) "_G", "_NETRAD")
    data[[ae_name]] <- ae
  }

  # Turbulent fluxes: H and LE (or their *_uStar_orig versions in ThirdStage)
  h_col  <- grep("^H(_.*_uStar_orig)?$", cols, value = TRUE)[1]
  le_col <- grep("^LE(_.*_uStar_orig)?$", cols, value = TRUE)[1]
  if (!is.na(h_col) && !is.na(le_col)) {
    data[["H_LE"]] <- data[[h_col]] + data[[le_col]]
  }

  data
}
