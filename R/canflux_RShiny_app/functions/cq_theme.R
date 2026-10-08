# CARBONIQUE visual identity for the app and its plots, plus a light plotly
# figure builder.
#
# Brand colours (from the CARBONIQUE logo files)
#   green  #8EC161   yellow #F7C200   teal #54B4CC   brown #77633C
# Font: Roboto (bundled in www/fonts, no internet needed on the server)

cq_brand <- list(
  green  = "#8EC161",
  yellow = "#F7C200",
  teal   = "#54B4CC",
  brown  = "#77633C",
  brown_dark = "#5B4B2C",
  ink    = "#2B2A27",   # body text
  muted  = "#6B675E",   # secondary text
  grid   = "#ECEAE4",
  axis   = "#C9C4B8",
  surface = "#FFFFFF",
  page   = "#F7F6F2"
)

# Chart series colours: deeper steps of the brand hues so thin lines and small
# points stay visible on white. Order checked for colour-blind separation
# (worst adjacent CVD dE 17; the first three stay distinct as any pair).
cq_series <- c("#2A9BC4",  # teal
               "#5A9E2F",  # green
               "#6A55B0",  # violet
               "#C2572B",  # sienna
               "#E0A200",  # gold
               "#C94B7C")  # rose
cq_colors <- function(n) rep_len(cq_series, n)

# Semantic colours for the radiation diagnostics and flags
cq_semantic <- list(potential = "#E0A200", measured = "#2A9BC4",
                    exceeds = "#C2572B", outlier = "#C62F2F", fit = "#5B4B2C")

cq_font <- "Roboto, system-ui, -apple-system, 'Segoe UI', Arial, sans-serif"

# ---------------------------------------------------------------------------
# Figure builder
#
# Figures are assembled as plain plotly.js traces and handed to the plotly
# htmlwidget as-is. This skips plotly R's per-trace processing, which (1) copied
# the hover template once per point and (2) silently dropped missing values,
# shifting regularly spaced half-hourly series in time.
# ---------------------------------------------------------------------------
cq_plot <- function(layout = list()) list(data = list(), layout = layout)

add_tr <- function(fig, ...) {
  tr <- list(...)
  tr <- tr[!vapply(tr, is.null, logical(1))]
  # keep one-value data arrays as JSON arrays (not scalars)
  for (a in intersect(names(tr), c("x", "y", "customdata", "text"))) {
    if (is.atomic(tr[[a]]) && length(tr[[a]]) == 1) tr[[a]] <- I(tr[[a]])
  }
  fig$data[[length(fig$data) + 1]] <- tr
  fig
}

cq_axis <- function(title = NULL, ...) {
  utils::modifyList(list(
    title = list(text = title %||% "", standoff = 8, font = list(size = 13, color = cq_brand$muted)),
    gridcolor = cq_brand$grid, zeroline = FALSE,
    linecolor = cq_brand$axis, showline = TRUE, ticks = "outside",
    tickcolor = cq_brand$axis, ticklen = 4,
    tickfont = list(size = 12, color = cq_brand$muted),
    automargin = TRUE), list(...))
}

cq_base_layout <- function(showlegend = TRUE) {
  list(
    font = list(family = cq_font, size = 13, color = cq_brand$ink),
    paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
    margin = list(l = 10, r = 10, t = 36, b = 10),
    hovermode = "closest",
    hoverlabel = list(font = list(family = cq_font, size = 12, color = cq_brand$ink),
                      bgcolor = "#FFFFFF", bordercolor = cq_brand$axis),
    showlegend = showlegend,
    legend = list(orientation = "h", x = 0, xanchor = "left", y = 1.02, yanchor = "bottom",
                  font = list(size = 12), itemclick = "toggle", itemdoubleclick = "toggleothers",
                  itemsizing = "constant")
  )
}

.cq_base_widget <- function() {
  if (is.null(.cq_cache$base_widget)) {
    .cq_cache$base_widget <- suppressWarnings(suppressMessages(plotly::plotly_build(
      plotly::plot_ly(type = "scatter", mode = "markers", x = numeric(0), y = numeric(0)))))
  }
  .cq_cache$base_widget
}

# Turn a figure into a plotly htmlwidget (what renderPlotly() expects)
cq_widget <- function(fig, filename = "carbonique_plot", modebar = TRUE, source = NULL) {
  w <- .cq_base_widget()
  if (!is.null(source)) w$x$source <- source   # lets the server hear zoom events
  w$x$data <- fig$data
  w$x$layout <- fig$layout
  w$x$config <- list(
    displaylogo = FALSE, responsive = TRUE, showSendToCloud = FALSE,
    displayModeBar = if (modebar) "hover" else FALSE,
    modeBarButtonsToAdd = list(),
    modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d", "toggleSpikelines",
                               "hoverCompareCartesian", "hoverClosestCartesian"),
    toImageButtonOptions = list(format = "png", filename = filename, scale = 2)
  )
  w
}

# One x/y panel with the shared look
cq_layout <- function(fig, xlab = NULL, ylab = NULL, xaxis = list(), yaxis = list(),
                      showlegend = TRUE, filename = "carbonique_plot", source = NULL, ...) {
  lay <- cq_base_layout(showlegend)
  lay$xaxis <- do.call(cq_axis, c(list(title = xlab), xaxis))
  lay$yaxis <- do.call(cq_axis, c(list(title = ylab), yaxis))
  fig$layout <- utils::modifyList(lay, utils::modifyList(fig$layout, list(...)))
  cq_widget(fig, filename, source = source)
}

# A friendly empty state drawn as a plot (keeps the card layout stable)
cq_empty_plot <- function(message) {
  fig <- cq_plot(list(
    xaxis = list(visible = FALSE), yaxis = list(visible = FALSE),
    paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
    font = list(family = cq_font), margin = list(l = 10, r = 10, t = 10, b = 10),
    annotations = list(list(text = gsub("\n", "<br>", message), showarrow = FALSE, x = 0.5, y = 0.5,
                            xref = "paper", yref = "paper",
                            font = list(size = 15, color = cq_brand$muted)))))
  cq_widget(fig, modebar = FALSE)
}

# Small multiples without plotly::subplot(): axis domains for a grid of n
# panels. Returns the axis id suffixes ("", "2", ...) and layout entries.
cq_facets <- function(n, ncol, titles, xaxis = list(), yaxis = list(),
                      hgap = 0.025, vgap = 0.07, top_pad = 0.03,
                      share_x = TRUE, share_y = TRUE) {
  nrow <- ceiling(n / ncol)
  w <- (1 - hgap * (ncol - 1)) / ncol
  h <- (1 - top_pad - vgap * (nrow - 1)) / nrow
  lay <- list(annotations = list())
  ids <- character(n)
  for (i in seq_len(n)) {
    r <- (i - 1) %/% ncol; c <- (i - 1) %% ncol
    x0 <- c * (w + hgap); y1 <- 1 - top_pad - r * (h + vgap)
    suffix <- if (i == 1) "" else as.character(i)
    ids[i] <- suffix
    xa <- do.call(cq_axis, c(list(title = NULL), xaxis))
    ya <- do.call(cq_axis, c(list(title = NULL), yaxis))
    xa$domain <- c(x0, x0 + w); xa$anchor <- paste0("y", suffix)
    ya$domain <- c(y1 - h, y1); ya$anchor <- paste0("x", suffix)
    if (i > 1 && share_x) xa$matches <- "x"
    if (i > 1 && share_y) ya$matches <- "y"
    if (share_x && r < nrow - 1 && i + ncol <= n) xa$showticklabels <- FALSE
    if (share_y && c > 0) ya$showticklabels <- FALSE
    lay[[paste0("xaxis", suffix)]] <- xa
    lay[[paste0("yaxis", suffix)]] <- ya
    lay$annotations[[i]] <- list(text = titles[i], showarrow = FALSE,
                                 x = x0 + w / 2, y = y1, xref = "paper", yref = "paper",
                                 xanchor = "center", yanchor = "bottom",
                                 font = list(size = 12, color = cq_brand$ink))
  }
  list(ids = ids, layout = lay, nrow = nrow)
}

# Layout for a small-multiples figure, with a shared y title on the left
cq_facet_layout <- function(fac, ytitle = NULL, showlegend = FALSE,
                            margin = list(l = 64, r = 10, t = 10, b = 30)) {
  lay <- utils::modifyList(cq_base_layout(showlegend), fac$layout)
  lay$margin <- margin
  if (!is.null(ytitle)) {
    lay$annotations[[length(lay$annotations) + 1]] <- list(
      text = ytitle, textangle = -90, showarrow = FALSE, x = 0, xshift = -54, y = 0.5,
      xref = "paper", yref = "paper", xanchor = "center", yanchor = "middle",
      font = list(size = 13, color = cq_brand$muted))
  }
  lay
}

# Round values before sending them to the browser: float32 sensor data only
# carries ~7 significant digits, and 5 keeps the JSON far smaller.
cq_round <- function(x, digits = 5) signif(x, digits)

# Replace the x/y data of every trace of a plot already on screen (after a
# zoom), without redrawing the widget. `trs` is a list of list(x =, y =).
restyle_xy <- function(session, id, trs, yrange = NULL) {
  if (!length(trs)) return(invisible())
  proxy <- plotly::plotlyProxy(id, session)
  plotly::plotlyProxyInvoke(
    proxy, "restyle",
    list(x = lapply(trs, function(t) I(t$x)), y = lapply(trs, function(t) I(t$y))),
    as.list(seq_along(trs) - 1L))
  if (!is.null(yrange)) {
    pad <- diff(yrange) * 0.06; if (pad == 0) pad <- 1
    plotly::plotlyProxyInvoke(proxy, "relayout", list("yaxis.range" = c(yrange[1] - pad, yrange[2] + pad)))
  }
}
