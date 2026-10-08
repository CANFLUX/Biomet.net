# Cumulative fluxes from gap-filled (ThirdStage) data
# 2026: moved out of app.R and ported to data.table + plotly (same method).
# The data are read from `cumulative_level` (Clean/ThirdStage by default)
# whatever level the rest of the app uses, so this tab works as soon as a
# site has gap-filled data. Complete years are drawn as before; the current
# (incomplete) year is added as a dashed "year to date" line.

plot_cumulative <- function(site, cumcol, lang = "en") {
  cat3 <- thirdstage_catalog(site)
  if (!length(cat3$raw_vars)) {
    return(cq_empty_plot(tr("msg_no_third_site", lang, site = site, level = cumulative_level)))
  }
  vars <- cumulative_vars(site)
  if (!length(vars)) {
    return(cq_empty_plot(tr("msg_no_cum_vars", lang, site = site, level = cumulative_level)))
  }
  if (is.null(cumcol) || !(cumcol %in% vars)) cumcol <- vars[1]

  # Conversion factors: umol CO2 m-2 s-1 -> gC m-2 d-1 ; nmol CH4 m-2 s-1 -> gC m-2 d-1
  conv <- list(CO2 = 12.01 / (10^6) * (60 * 60 * 24), CH4 = 12.01 / (10^9) * (60 * 60 * 24))
  cf <- if (grepl("^FCH4", cumcol)) conv$CH4 else conv$CO2

  lt <- as.POSIXlt(cat3$datetime)
  df <- data.table::data.table(year = lt$year + 1900L, DOY = lt$yday + 1L, var = site_var(cat3, cumcol))

  # Full years: >= 365 days of half-hours
  count_yr <- df[, .(count = sum(!is.na(var))), by = year]
  count_yr <- count_yr[count > 0]
  if (!nrow(count_yr)) return(cq_empty_plot(tr("msg_no_data", lang)))
  full <- count_yr$year[count_yr$count >= 17520]

  # Daily means (days with a gap are left out), then running sums per year
  daily <- df[year %in% count_yr$year, .(var = mean(var) * cf), keyby = .(year, DOY)]
  daily <- daily[!is.na(var)]
  daily[, var_cum := cumsum(var), by = year]

  yrs <- sort(unique(daily$year))
  pal <- stats::setNames(cq_colors(length(yrs)), yrs)
  fig <- cq_plot()
  for (yy in yrs) {
    d <- daily[year == yy]
    partial <- !(yy %in% full)
    nm <- if (partial) paste0(yy, " (", tr("partial", lang), ")") else as.character(yy)
    fig <- add_tr(fig, type = "scatter", mode = "lines", x = d$DOY, y = signif(d$var_cum, 4),
                  name = nm,
                  line = list(color = pal[[as.character(yy)]], width = 2, dash = if (partial) "dash" else "solid"),
                  hovertemplate = paste0(nm, " \u00b7 ", tr("ax_doy", lang), " %{x}<br>%{y:.1f} gC m-2<extra></extra>"))
  }
  fig$layout <- list(shapes = list(list(type = "line", xref = "paper", x0 = 0, x1 = 1, y0 = 0, y1 = 0,
                                        line = list(color = cq_brand$muted, dash = "dot", width = 1))))
  cq_layout(fig, xlab = tr("ax_doy", lang), ylab = paste0(cumcol, " (gC m-2)"),
            xaxis = list(range = c(0, 367)), filename = paste0("cumulative_", site, "_", cumcol))
}
