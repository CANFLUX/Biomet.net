# Script for calculating composite of diurnal patterns over a fixed moving window
# By Sara Knox
# June 27, 2022
# 2026: vectorised with data.table (same windows, same statistics, ~50x faster)

# Input
# data = data frame
# potential_radiation_var = variable name for potential radiation
# rad_var = variable name for radiation variable (either SW_IN_1_1_1 or PPFD_IN_1_1_1)
# width = width of moving windows in days
# ts = timestep (i.e., 48 half hour observations per day)

diurnal_composite_rad_single_var <- function(data, potential_radiation_var, rad_var, width, ts) {

  lt <- as.POSIXlt(data$datetime)
  df <- data.table::data.table(datetime = data$datetime,
                               rad = data[[rad_var]],
                               pot = data[[potential_radiation_var]],
                               hh = lt$hour, mm = lt$min)

  # Start at the first midnight, end at the last 23:30
  istart <- which(df$hh == 0 & df$mm == 0)[1]
  iend <- utils::tail(which(df$hh == 23 & df$mm == 30), 1)
  empty <- data.frame(HHMM = character(), potential_radiation = numeric(), radiation = numeric(),
                      date = as.POSIXct(character()), firstdate = character(), time = as.POSIXct(character()))
  names(empty)[3] <- rad_var
  if (is.na(istart) || !length(iend) || iend <= istart) return(empty)
  df2 <- df[istart:iend]

  # Number of complete windows
  nwindows <- floor(nrow(df2) / width / ts)
  if (nwindows < 1) return(empty)
  df2 <- df2[seq_len(nwindows * width * ts)]
  df2[, window := (seq_len(.N) - 1L) %/% (width * ts) + 1L]
  df2[, HHMM := sprintf("%02d:%02d", hh, mm)]
  df2[, rad := ifelse(is.nan(rad), NA_real_, rad)]

  safe_max <- function(x) if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
  comp <- df2[, .(potential_radiation = safe_max(pot),
                  radiation = safe_max(rad),
                  date = stats::median(as.numeric(datetime))),
              keyby = .(window, HHMM)]
  comp[, date := as.POSIXct(date, origin = "1970-01-01", tz = "UTC")]

  # One label date per window (the middle of the window), as before
  comp[, firstdate := format(date[.N], "%Y-%m-%d"), by = window]

  # Points where SW_IN > potential radiation (strictly greater, so night-time
  # zeros are no longer flagged)
  if (grepl("SW_IN", rad_var, fixed = TRUE)) {
    comp[, exceeds := ifelse(!is.na(radiation) & radiation > potential_radiation, radiation, NA_real_)]
  }

  # Time of day for plotting purposes
  comp[, time := as.POSIXct(HHMM, format = "%R", tz = "UTC")]
  comp[, hour := as.numeric(substr(HHMM, 1, 2)) + as.numeric(substr(HHMM, 4, 5)) / 60]

  data.table::setnames(comp, "radiation", rad_var)
  comp[, window := NULL]
  as.data.frame(comp)
}
