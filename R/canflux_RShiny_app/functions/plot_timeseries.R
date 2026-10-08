# Time series and All sites plots
# 2026 rewrite of the ggplot + ggplotly code that lived in app.R.
#
# Speed and robustness choices:
# * Plots are drawn as SVG (no WebGL), so they work in every browser, including
#   computers where WebGL is switched off.
# * Long periods are simplified for display: when a series has more than
#   `max_points_per_series` values in view, the lowest and highest value of each
#   time step are kept (spikes and gaps stay visible). Zooming in asks the
#   server for the full half-hourly data of the new range (see app.R).
# * Scatter clouds are thinned to one point per small screen cell; fits and
#   statistics always use all the data.

# Parse a time sent back by plotly ("2025-03-01 12:34:56.789", "2025-03-01")
parse_plotly_time <- function(s) {
  s <- sub("\\.\\d+$", "", as.character(s))
  for (f in c("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d")) {
    t <- as.POSIXct(s, format = f, tz = "UTC")
    if (!is.na(t)) return(t)
  }
  NA
}

# x range from a plotly relayout event:
#   c(from, to) (POSIXct) after a zoom or pan, NULL after a reset,
#   "ignore" for events that do not change the x axis
relayout_xrange <- function(ev) {
  if (is.null(ev) || !length(ev)) return("ignore")
  nm <- names(ev)
  if (any(grepl("^xaxis[0-9]*\\.autorange$", nm))) return(NULL)
  r0 <- grep("^xaxis[0-9]*\\.range\\[0\\]$", nm, value = TRUE)[1]
  if (!is.na(r0)) {
    r1 <- sub("\\[0\\]$", "[1]", r0)
    return(c(parse_plotly_time(ev[[r0]]), parse_plotly_time(ev[[r1]])))
  }
  r <- grep("^xaxis[0-9]*\\.range$", nm, value = TRUE)[1]
  if (!is.na(r) && length(ev[[r]]) == 2) {
    return(c(parse_plotly_time(ev[[r]][[1]]), parse_plotly_time(ev[[r]][[2]])))
  }
  "ignore"
}

# Indices to draw for one series within [from, to]
decimate_idx <- function(tnum, y, from = -Inf, to = Inf, max_points = max_points_per_series) {
  idx <- which(!is.na(y) & tnum >= from & tnum <= to)
  if (length(idx) <= max_points) return(idx)
  nb <- max_points %/% 2 # Half the number of points since keeping min and max
  tt <- tnum[idx]
  b <- floor((tt - tt[1]) / (tt[length(tt)] - tt[1] + 1) * nb)
  d <- data.table::data.table(b = b, v = y[idx], i = idx)
  keep <- d[, .(i = c(i[which.min(v)], i[which.max(v)])), by = b]$i
  # Example if you wanted more than just the min/max -- nb would need to be modified as well
  # keep <- d[, .(i = c(i[which.min(v)], i[which.median(v)], i[which.max(v)])), by = b]$i
  sort(unique(keep))
}

# which.median <- function(x) {
#   med <- median(x, na.rm = TRUE)
#   # Returns the indices that match the median value
#   # which(x == med)
#   which.min(abs(x - med))
# }

# One point per small cell of the x-y plane (and per group); keeps outliers
thin_xy <- function(x, y, group = NULL, cells = 260, keep_all_below = 2 * max_points_per_series) {
  ok <- which(!is.na(x) & !is.na(y))
  if (length(ok) <= keep_all_below) return(ok)
  xr <- range(x[ok]); yr <- range(y[ok])
  cx <- floor((x[ok] - xr[1]) / (diff(xr) + 1e-12) * cells)
  cy <- floor((y[ok] - yr[1]) / (diff(yr) + 1e-12) * cells)
  g <- if (is.null(group)) 0 else as.integer(factor(group[ok])) - 1
  key <- (g * (cells + 1) + cx) * (cells + 1) + cy
  ok[!duplicated(key)]
}

# Daily means from half-hourly values; a day needs at least `min_frac` of its
# half-hours to get a value. Time stamps mark the end of each half-hour.
daily_mean <- function(datetime, y, min_frac = 0.5) {
  day <- as.Date(datetime - 900, tz = "UTC")
  d <- data.table::data.table(day = day, y = y)
  d[, .(y = if (sum(!is.na(y)) >= 48 * min_frac) mean(y, na.rm = TRUE) else NA_real_), keyby = day]
}

# Monthly means of daily means (a month needs at least half of its days)
monthly_mean <- function(datetime, y) {
  d <- daily_mean(datetime, y)
  d[, month := as.Date(format(day, "%Y-%m-01"))]
  d[, .(y = if (sum(!is.na(y)) >= 14) mean(y, na.rm = TRUE) else NA_real_), keyby = month]
}

fmt_time <- function(t) format(t, "%Y-%m-%d %H:%M")

units_of <- function(name, units_tbl) {
  u <- units_tbl$units[match(name, units_tbl$name)]
  if (length(u) == 0 || is.na(u)) "" else u
}

# Rows [a, b] of a set of series, trimmed to where at least one has data
trim_to_data <- function(series) {
  has <- Reduce(`|`, lapply(series, function(y) !is.na(y)), FALSE)
  if (!any(has)) return(NULL)
  c(min(which(has)), max(which(has)))
}

# ----------------------------------------------------------------------------
# a) Time series of one variable (all its replicates, e.g. TA_1_1_1, TA_1_2_1)
# ----------------------------------------------------------------------------

# x/y arrays of each half-hourly series for a time window (used for the first
# drawing and again after every zoom)
timeseries_traces <- function(obj, cols, rows, from = -Inf, to = Inf) {
  t <- obj$datetime[rows]; tn <- as.numeric(t)
  f <- if (inherits(from, "POSIXct")) as.numeric(from) else from
  e <- if (inherits(to, "POSIXct")) as.numeric(to) else to
  lapply(cols, function(cl) {
    y <- obj_col(obj, cl)[rows]
    i <- decimate_idx(tn, y, f, e)
    list(x = fmt_time(t[i]), y = cq_round(y[i]), n_all = sum(!is.na(y) & tn >= f & tn <= e))
  })
}

plot_timeseries <- function(obj, cols, rows, resolution = "30min", lang = "en") {
  ys <- lapply(cols, function(cl) obj_col(obj, cl)[rows])
  ab <- trim_to_data(ys)
  if (is.null(ab)) return(cq_empty_plot(tr("msg_no_data", lang)))
  rows <- rows[ab[1]:ab[2]]
  units <- units_of(cols[1], obj$units)
  pal <- cq_colors(length(cols))
  fig <- cq_plot()
  if (resolution == "daily") {
    for (i in seq_along(cols)) {
      d <- daily_mean(obj$datetime[rows], obj_col(obj, cols[i])[rows])
      fig <- add_tr(fig, type = "scatter", mode = "lines", x = format(d$day), y = cq_round(d$y),
                    name = cols[i], connectgaps = FALSE, line = list(color = pal[i], width = 1.6),
                    hovertemplate = paste0("%{x|%Y-%m-%d}<br>%{y:.4g} ", units, "<extra>", cols[i], "</extra>"))
    }
  } else {
    trs <- timeseries_traces(obj, cols, rows)
    for (i in seq_along(cols)) {
      fig <- add_tr(fig, type = "scatter", mode = "markers", x = trs[[i]]$x, y = trs[[i]]$y,
                    name = cols[i], marker = list(color = pal[i], size = 3.5, opacity = 0.6),
                    hovertemplate = paste0("%{x|%Y-%m-%d %H:%M}<br>%{y:.4g} ", units,
                                           "<extra>", cols[i], "</extra>"))
    }
  }
  cq_layout(fig, xlab = NULL, ylab = unit_label(cols[1], obj$units),
            xaxis = list(type = "date"), showlegend = length(cols) > 1,
            filename = paste(obj$site, cols[1], sep = "_"), source = "ts_plot")
}

# ----------------------------------------------------------------------------
# b) All sites
# ----------------------------------------------------------------------------

# Per-site x/y arrays for the time view; resolution "30min" is decimated
all_sites_time_traces <- function(d, sites, resolution, from = -Inf, to = Inf, max_points = max_points_per_series) {
  f <- if (inherits(from, "POSIXct")) as.numeric(from) else from
  e <- if (inherits(to, "POSIXct")) as.numeric(to) else to
  lapply(sites, function(s) {
    ds <- d[d$site == s]
    if (!nrow(ds)) return(list(x = character(0), y = numeric(0)))
    if (resolution == "daily") {
      a <- daily_mean(ds$datetime, ds$y); return(list(x = format(a$day), y = cq_round(a$y)))
    }
    if (resolution == "monthly") {
      a <- monthly_mean(ds$datetime, ds$y); return(list(x = format(a$month), y = cq_round(a$y)))
    }
    i <- decimate_idx(as.numeric(ds$datetime), ds$y, f, e, max_points)
    list(x = fmt_time(ds$datetime[i]), y = cq_round(ds$y[i]))
  })
}

site_label <- function(s, color) {
  paste0("<span style='color:", color, "'>\u25cf</span> ", s)
}

plot_all_sites <- function(d, all_sites, sites, xvar, yvar, units_tbl, resolution = "daily",
                           layout = "panels", lang = "en") {
  pal <- stats::setNames(cq_colors(length(all_sites)), all_sites)   # colour follows the site
  sites <- intersect(all_sites, sites)
  if (!nrow(d) || !length(sites)) return(cq_empty_plot(tr("msg_no_data", lang)))
  d <- d[d$site %in% sites]
  sites <- sites[sites %in% unique(d$site[!is.na(d$y)])]
  if (!length(sites)) return(cq_empty_plot(tr("msg_no_data", lang)))
  yunits <- units_of(yvar, units_tbl)
  time_view <- xvar == "datetime"
  panels <- layout == "panels" && length(sites) > 1

  # data per site
  if (time_view) {
    trs <- all_sites_time_traces(d, sites, resolution,
                                 max_points = if (panels) max_points_per_series else 1500)
  } else {
    trs <- lapply(sites, function(s) {
      ds <- d[d$site == s]
      xv <- ds$x; yv <- ds$y
      if (resolution == "daily") {
        xv <- daily_mean(ds$datetime, xv)$y; yv <- daily_mean(ds$datetime, yv)$y
      } else if (resolution == "monthly") {
        xv <- monthly_mean(ds$datetime, xv)$y; yv <- monthly_mean(ds$datetime, yv)$y
      }
      i <- thin_xy(xv, yv, cells = if (panels) 160 else 220)
      list(x = cq_round(xv[i]), y = cq_round(yv[i]))
    })
  }
  names(trs) <- sites
  mode <- if (time_view && resolution != "30min") "lines" else "markers"
  mk <- function(col) list(color = col, size = if (time_view) 3 else 3.5, opacity = if (panels) 0.6 else 0.45)
  hover <- if (time_view) {
    paste0(if (resolution == "30min") "%{x|%Y-%m-%d %H:%M}" else if (resolution == "daily") "%{x|%Y-%m-%d}" else "%{x|%Y-%m}",
           "<br>%{y:.4g} ", yunits)
  } else {
    paste0(xvar, " %{x:.4g}<br>", yvar, " %{y:.4g}")
  }

  fig <- cq_plot()
  if (panels) {
    n <- length(sites)
    ncol <- if (time_view) 1 else if (n <= 4) 2 else 3
    yr <- range(unlist(lapply(trs, `[[`, "y")), finite = TRUE)
    pad <- diff(yr) * 0.06; if (!is.finite(pad) || pad == 0) pad <- 1
    xa <- if (time_view) list(type = "date") else {
      xr <- range(unlist(lapply(trs, `[[`, "x")), finite = TRUE)
      xp <- diff(xr) * 0.04; if (!is.finite(xp) || xp == 0) xp <- 1
      list(range = c(xr[1] - xp, xr[2] + xp))
    }
    fac <- cq_facets(n, ncol, titles = vapply(sites, function(s) site_label(s, pal[[s]]), ""),
                     xaxis = xa, yaxis = list(range = c(yr[1] - pad, yr[2] + pad)),
                     hgap = 0.05, vgap = if (time_view) 0.35 / n else 0.3 / ceiling(n / ncol),
                     top_pad = 0.02)
    for (i in seq_len(n)) {
      s <- sites[i]
      fig <- add_tr(fig, type = "scatter", mode = mode, x = trs[[s]]$x, y = trs[[s]]$y, name = s,
                    xaxis = paste0("x", fac$ids[i]), yaxis = paste0("y", fac$ids[i]),
                    marker = if (mode == "markers") mk(pal[[s]]),
                    line = if (mode == "lines") list(color = pal[[s]], width = 1.5),
                    connectgaps = FALSE, showlegend = FALSE,
                    hovertemplate = paste0(hover, "<extra>", s, "</extra>"))
    }
    ytitle <- unit_label(yvar, units_tbl)
    fig$layout <- cq_facet_layout(fac, ytitle = ytitle,
                                  margin = list(l = 64, r = 10, t = 10, b = if (time_view) 30 else 64))
    if (!time_view) {
      fig$layout$annotations[[length(fig$layout$annotations) + 1]] <- list(
        text = unit_label(xvar, units_tbl), showarrow = FALSE, x = 0.5, y = 0, yshift = -36,
        xref = "paper", yref = "paper", xanchor = "center", yanchor = "top",
        font = list(size = 13, color = cq_brand$muted))
    }
    return(cq_widget(fig, filename = paste("all_sites", yvar, sep = "_"), source = "all_plot"))
  }

  for (s in sites) {
    fig <- add_tr(fig, type = "scatter", mode = mode, x = trs[[s]]$x, y = trs[[s]]$y, name = s,
                  marker = if (mode == "markers") mk(pal[[s]]),
                  line = if (mode == "lines") list(color = pal[[s]], width = 1.6),
                  connectgaps = FALSE,
                  hovertemplate = paste0(hover, "<extra>", s, "</extra>"))
  }
  cq_layout(fig, xlab = if (time_view) NULL else unit_label(xvar, units_tbl),
            ylab = unit_label(yvar, units_tbl),
            xaxis = if (time_view) list(type = "date") else list(),
            filename = paste("all_sites", yvar, sep = "_"), source = "all_plot")
}
