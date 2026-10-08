# Radiation diagnostics: measured vs potential radiation in 15-day windows
# Shared by SWIN_vs_potential_rad() and PPFDIN_vs_potential_rad().
# 2026: native plotly small multiples (the ggplot/ggplotly version took ~2 s).

# Lag (in half-hour steps) with the highest cross-correlation between two series
find_max_ccf <- function(a, b) {
  ok <- is.finite(a) & is.finite(b)
  if (sum(ok) < 4 || stats::sd(a[ok]) == 0 || stats::sd(b[ok]) == 0) return(c(cor = NA, lag = NA))
  d <- stats::ccf(a[ok], b[ok], plot = FALSE)
  k <- which.max(d$acf[, , 1])
  c(cor = d$acf[k, , 1], lag = d$lag[k, , 1])
}

# Prepare the composite for one site, one radiation variable and one year
radiation_composite <- function(obj, rad_name, year) {
  yr <- as.integer(format(obj$datetime, "%Y"))
  rows <- which(yr == as.integer(year))
  co <- site_coordinates(obj$site)
  if (is.null(co) || !length(rows)) return(NULL)
  df <- data.frame(datetime = obj$datetime[rows], rad = obj_col(obj, rad_name)[rows])
  names(df)[2] <- rad_name
  df$pot_rad <- potential_rad_generalized(co$standard_meridian, co$lon, co$lat, df$datetime)
  comp <- diurnal_composite_rad_single_var(df, "pot_rad", rad_name, 15, 48)
  if (!nrow(comp)) return(comp)
  # drop windows where the measured radiation is missing throughout
  keep <- tapply(!is.na(comp[[rad_name]]), comp$firstdate, any)
  comp[comp$firstdate %in% names(keep)[keep], , drop = FALSE]
}

radiation_vs_potential_plot <- function(data, rad_var, scale = 1, show_exceeds = TRUE,
                                        lang = "en", ncol = 6) {
  if (is.null(data) || !nrow(data)) return(cq_empty_plot(tr("msg_no_data", lang)))
  dates <- unique(data$firstdate)
  lags <- vapply(dates, function(dd) {
    i <- data$firstdate == dd
    find_max_ccf(data$potential_radiation[i], data[[rad_var]][i])[["lag"]]
  }, numeric(1))
  mon <- tr("months_short", lang)
  dd <- as.Date(dates)
  titles <- paste0(as.integer(format(dd, "%d")), " ", mon[as.integer(format(dd, "%m"))], " \u00b7 ",
                   ifelse(is.na(lags), "", tr("lag_label", lang, k = lags)),
                   ifelse(!is.na(lags) & lags != 0, " \u26a0", ""))
  n <- length(dates)
  ymax <- max(c(data$potential_radiation * scale, data[[rad_var]]), na.rm = TRUE)
  fac <- cq_facets(n, ncol, titles,
                   xaxis = list(tickvals = c(0, 6, 12, 18), ticktext = c("0 h", "6 h", "12 h", "18 h"),
                                range = c(-0.5, 24.5)),
                   yaxis = list(range = c(-0.03 * ymax, 1.06 * ymax)),
                   vgap = 0.35 / max(1, ceiling(n / ncol)), top_pad = 0.04)
  unit <- if (grepl("PPFD", rad_var)) "\u00b5mol m-2 s-1" else "W m-2"
  pot_name <- if (scale != 1) tr("leg_potential_ppfd", lang) else tr("leg_potential", lang)

  fig <- cq_plot()
  exc_shown <- FALSE
  for (i in seq_len(n)) {
    d <- data[data$firstdate == dates[i], , drop = FALSE]
    xa <- paste0("x", fac$ids[i]); ya <- paste0("y", fac$ids[i])
    first <- i == 1
    fig <- add_tr(fig, type = "scatter", mode = "lines", x = d$hour,
                           y = signif(d$potential_radiation * scale, 4), xaxis = xa, yaxis = ya,
                           name = pot_name, legendgroup = "pot", showlegend = first,
                           line = list(color = cq_semantic$potential, width = 2),
                           hovertemplate = paste0("%{x:.1f} h<br>%{y:.0f} ", unit, "<extra>", pot_name, "</extra>"))
    fig <- add_tr(fig, type = "scatter", mode = "markers", x = d$hour,
                           y = signif(d[[rad_var]], 4), xaxis = xa, yaxis = ya,
                           name = tr("leg_measured", lang), legendgroup = "meas", showlegend = first,
                           marker = list(color = cq_semantic$measured, size = 4),
                           hovertemplate = paste0("%{x:.1f} h<br>%{y:.0f} ", unit, "<extra>", rad_var, "</extra>"))
    if (show_exceeds && "exceeds" %in% names(d) && any(!is.na(d$exceeds))) {
      fig <- add_tr(fig, type = "scatter", mode = "markers", x = d$hour,
                             y = signif(d$exceeds, 4), xaxis = xa, yaxis = ya,
                             name = tr("leg_exceeds", lang), legendgroup = "exc",
                             showlegend = !exc_shown,
                             marker = list(color = cq_semantic$exceeds, size = 6, symbol = "diamond"),
                             hovertemplate = paste0("%{x:.1f} h<br>%{y:.0f} ", unit, "<extra></extra>"))
      exc_shown <- TRUE
    }
  }
  fig$layout <- cq_facet_layout(fac, ytitle = paste0(rad_var, " (", unit, ")"), showlegend = TRUE,
                                margin = list(l = 64, r = 10, t = 40, b = 30))
  fig$layout$legend$y <- 1; fig$layout$legend$yanchor <- "bottom"
  fig$layout$legend$x <- 0
  cq_widget(fig, filename = paste0("radiation_", rad_var))
}
