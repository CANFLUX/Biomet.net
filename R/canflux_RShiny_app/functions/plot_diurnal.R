# Mean monthly diurnal cycle (12 panels, one per month)
# 2026 rewrite of the ggplot facet_wrap code from app.R, with a 25-75th
# percentile band added.

plot_diurnal <- function(datetime, y, var_name, units_tbl, lang = "en") {
  lt <- as.POSIXlt(datetime)
  d <- data.table::data.table(month = lt$mon + 1L, hour = lt$hour + lt$min / 60, v = y)
  d <- d[!is.na(v)]
  if (!nrow(d)) return(cq_empty_plot(tr("msg_no_data", lang)))
  agg <- d[, .(mean = mean(v),
               q25 = stats::quantile(v, 0.25, names = FALSE),
               q75 = stats::quantile(v, 0.75, names = FALSE)),
           keyby = .(month, hour)]

  months <- tr("months", lang)
  # one y range for all panels (explicit: plotly's auto range is unreliable
  # across many linked panels)
  yr <- range(c(agg$q25, agg$q75, agg$mean), finite = TRUE)
  pad <- diff(yr) * 0.06; if (pad == 0) pad <- 1
  fac <- cq_facets(12, 4, titles = months,
                   xaxis = list(tickvals = c(0, 6, 12, 18), ticktext = c("0 h", "6 h", "12 h", "18 h"),
                                range = c(-0.5, 24.5)),
                   yaxis = list(range = c(yr[1] - pad, yr[2] + pad)),
                   vgap = 0.09, top_pad = 0.05)
  col <- cq_semantic$measured
  band <- "rgba(42,155,196,0.18)"
  unit <- units_tbl$units[match(var_name, units_tbl$name)]
  unit <- if (is.na(unit)) "" else unit

  fig <- cq_plot()
  for (m in 1:12) {
    a <- agg[month == m]
    if (!nrow(a)) next
    xa <- paste0("x", fac$ids[m]); ya <- paste0("y", fac$ids[m])
    fig <- add_tr(fig, type = "scatter", mode = "lines", x = a$hour, y = signif(a$q75, 4),
                           xaxis = xa, yaxis = ya, line = list(width = 0), hoverinfo = "skip",
                           showlegend = FALSE)
    fig <- add_tr(fig, type = "scatter", mode = "lines", x = a$hour, y = signif(a$q25, 4),
                           xaxis = xa, yaxis = ya, line = list(width = 0), fill = "tonexty",
                           fillcolor = band, hoverinfo = "skip", showlegend = FALSE)
    fig <- add_tr(fig, type = "scatter", mode = "lines", x = a$hour, y = signif(a$mean, 4),
                           xaxis = xa, yaxis = ya, showlegend = FALSE,
                           line = list(color = col, width = 2),
                           customdata = sprintf("%02d:%02d", floor(a$hour), round((a$hour %% 1) * 60)),
                           hovertemplate = paste0(months[m], " %{customdata}<br>%{y:.4g} ", unit,
                                                  "<extra></extra>"))
  }
  fig$layout <- cq_facet_layout(fac, ytitle = unit_label(var_name, units_tbl))
  cq_widget(fig, filename = paste0("diurnal_", var_name))
}
