# Figure for data QCQA scatter plot
# By Sara Knox
# Created March 15, 2022
# 2026: plotly (SVG, thinned points), fit computed once and shared with R2_slope_QCQA.
#   Changes to note:
#   * The fit is Y on X (lm(y ~ x)), i.e. the line that is drawn. The old plot
#     title reported the slope of X on Y, which did not match the drawn line.
#   * Axes are no longer forced to start at 0, so negative values (night-time
#     H, LE, NETRAD...) are no longer dropped from the plot and the fit.
#   * The year interaction uses year as a factor (one line per year).
#   * "vis_potential_outliers" now highlights points with Cook's D > 4/n.

# Input
# data = dataframe with relevant variables and a "year" column (or "datetime")
# var1 = x variable name, var2 = y variable name

scatter_fit <- function(data, var1, var2) {
  if (!("year" %in% names(data))) data$year <- as.integer(format(data$datetime, "%Y"))
  df <- data.frame(x = data[[var1]], y = data[[var2]], year = data$year)
  df <- df[stats::complete.cases(df), , drop = FALSE]
  if (nrow(df) < 3 || stats::sd(df$x) == 0) return(NULL)

  simple <- stats::lm(y ~ x, data = df)
  s <- summary(simple)

  per_year <- do.call(rbind, lapply(sort(unique(df$year)), function(yy) {
    d <- df[df$year == yy, , drop = FALSE]
    if (nrow(d) < 3 || stats::sd(d$x) == 0) return(NULL)
    m <- stats::lm(y ~ x, data = d)
    data.frame(year = yy, n = nrow(d), intercept = unname(stats::coef(m)[1]),
               slope = unname(stats::coef(m)[2]), r2 = summary(m)$adj.r.squared)
  }))

  # Best model (AIC): one line for all years, or one line per year
  by_year <- FALSE; r2 <- s$adj.r.squared
  if (!is.null(per_year) && nrow(per_year) > 1) {
    di <- df[df$year %in% per_year$year, , drop = FALSE]
    inter <- stats::lm(y ~ x * factor(year), data = di)
    simple_i <- stats::lm(y ~ x, data = di)
    if (stats::AIC(inter) < stats::AIC(simple_i)) {
      by_year <- TRUE
      r2 <- summary(inter)$adj.r.squared
    }
  }

  list(df = df, n = nrow(df), model = simple,
       slope = unname(stats::coef(simple)[2]), intercept = unname(stats::coef(simple)[1]),
       r2 = r2, by_year = by_year, per_year = per_year, var1 = var1, var2 = var2)
}

scatter_fit_text <- function(fit, lang = "en") {
  if (is.null(fit)) return(tr("msg_few_points", lang))
  if (fit$by_year) {
    tr("fit_by_year", lang, r2 = fmt_num(fit$r2, 3, lang), n = fmt_int(fit$n, lang))
  } else {
    tr("fit_simple", lang, slope = fmt_num(fit$slope, 3, lang),
       intercept = fmt_num(fit$intercept, 3, lang),
       r2 = fmt_num(fit$r2, 3, lang), n = fmt_int(fit$n, lang))
  }
}

scatter_plot_QCQA <- function(data, var1, var2, xlab, ylab, vis_potential_outliers = 0,
                              one_to_one = FALSE, lang = "en", fit = NULL) {
  if (is.null(fit) && !is.null(data)) fit <- scatter_fit(data, var1, var2)
  if (is.null(fit)) return(cq_empty_plot(tr("msg_few_points", lang)))
  df <- fit$df
  years <- sort(unique(df$year))
  pal <- stats::setNames(cq_colors(length(years)), years)

  # Points: one per small cell of the plot for each year (outliers stay
  # visible); the fit above uses every point
  keep <- thin_xy(df$x, df$y, group = df$year)
  dk <- df[keep, , drop = FALSE]
  fig <- cq_plot()
  for (yy in years) {
    d <- dk[dk$year == yy, , drop = FALSE]
    fig <- add_tr(fig, type = "scatter", mode = "markers",
                  x = cq_round(d$x), y = cq_round(d$y), name = as.character(yy),
                  legendgroup = as.character(yy),
                  marker = list(color = pal[[as.character(yy)]], size = 4, opacity = 0.5),
                  hovertemplate = paste0(var1, " %{x:.4g}<br>", var2, " %{y:.4g}<extra>", yy, "</extra>"))
  }

  if (isTRUE(as.logical(vis_potential_outliers))) {
    cd <- stats::cooks.distance(fit$model)
    flag <- which(cd > 4 / nrow(df))
    if (length(flag)) {
      fl <- flag[thin_xy(df$x[flag], df$y[flag])]
      fig <- add_tr(fig, type = "scatter", mode = "markers",
                    x = cq_round(df$x[fl]), y = cq_round(df$y[fl]),
                    name = tr("leg_outliers", lang),
                    marker = list(color = "rgba(0,0,0,0)", size = 8,
                                  line = list(color = cq_semantic$outlier, width = 1.4)),
                    hovertemplate = paste0(var1, " %{x:.4g}<br>", var2, " %{y:.4g}<extra>Cook's D</extra>"))
    }
  }

  xr <- range(df$x)
  xs <- signif(seq(xr[1], xr[2], length.out = 50), 6)
  if (one_to_one) {
    lim <- range(c(df$x, df$y))
    fig <- add_tr(fig, type = "scatter", mode = "lines", x = lim, y = lim,
                           name = tr("leg_11", lang), hoverinfo = "skip",
                           line = list(color = cq_brand$muted, width = 1.2, dash = "dot"))
  }
  if (fit$by_year) {
    for (i in seq_len(nrow(fit$per_year))) {
      r <- fit$per_year[i, ]
      xr_y <- range(df$x[df$year == r$year])
      xs_y <- signif(seq(xr_y[1], xr_y[2], length.out = 50), 6)
      fig <- add_tr(fig, type = "scatter", mode = "lines", x = xs_y, y = signif(r$intercept + r$slope * xs_y, 6),
                             name = as.character(r$year), legendgroup = as.character(r$year), showlegend = FALSE,
                             line = list(color = pal[[as.character(r$year)]], width = 2.5),
                             hovertemplate = paste0(r$year, ": ", tr("fit_slope", lang), " ", fmt_num(r$slope, 3, lang),
                                                    ", R\u00b2 ", fmt_num(r$r2, 3, lang), "<extra></extra>"))
    }
  } else {
    fig <- add_tr(fig, type = "scatter", mode = "lines", x = xs, y = signif(fit$intercept + fit$slope * xs, 6),
                           name = tr("leg_fit", lang),
                           line = list(color = cq_semantic$fit, width = 2.5),
                           hovertemplate = paste0(tr("fit_slope", lang), " ", fmt_num(fit$slope, 3, lang),
                                                  ", R\u00b2 ", fmt_num(fit$r2, 3, lang), "<extra></extra>"))
  }
  cq_layout(fig, xlab = xlab, ylab = ylab, filename = paste(var1, "vs", var2, sep = "_"))
}
