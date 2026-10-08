# Figure for comparing the R2 and slope of two variables, year by year
# By Sara Knox
# Created January 5, 2023
# 2026: native plotly. R2 and slope are drawn as two side-by-side panels
# instead of one chart with two y axes, so each keeps its own honest scale.
# Uses the per-year fits computed by scatter_fit() (lm(y ~ x) for each year).

# Input
# data = dataframe with relevant variables (and "year" or "datetime")
# var1 = x variable name
# var2 = y variable name

R2_slope_QCQA <- function(data, var1, var2, lang = "en", fit = NULL) {
  if (is.null(fit) && !is.null(data)) fit <- scatter_fit(data, var1, var2)
  if (is.null(fit) || is.null(fit$per_year) || !nrow(fit$per_year)) {
    return(cq_empty_plot(tr("msg_few_points", lang)))
  }
  py <- fit$per_year
  yrs <- as.character(py$year)
  fac <- cq_facets(2, 2, titles = c(tr("fit_r2", lang), tr("fit_slope", lang)),
                   xaxis = list(type = "category"), share_x = FALSE, share_y = FALSE,
                   hgap = 0.12, top_pad = 0.1)
  fig <- cq_plot()
  for (k in 1:2) {
    val <- if (k == 1) py$r2 else py$slope
    lab <- if (k == 1) "R\u00b2" else tr("fit_slope", lang)
    fig <- add_tr(fig, type = "scatter", mode = "lines+markers", x = yrs, y = signif(val, 4),
                           xaxis = paste0("x", fac$ids[k]), yaxis = paste0("y", fac$ids[k]),
                           showlegend = FALSE,
                           line = list(color = cq_brand$axis, width = 1.5),
                           marker = list(color = cq_colors(length(yrs)), size = 11,
                                         line = list(color = "#FFFFFF", width = 2)),
                           hovertemplate = paste0("%{x}<br>", lab, " %{y:.3f}<extra></extra>"))
  }
  fig$layout <- cq_facet_layout(fac, margin = list(l = 10, r = 10, t = 10, b = 10))
  cq_widget(fig, filename = "fit_per_year")
}
