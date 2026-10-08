# Figure for plotting the cross-correlation between radiation and potential radiation
# By Sara Knox
# Created Oct 28, 2022
# 2026: base R ccf() + plotly. The previous version called forecast::ggCcf(),
# but the forecast package was never loaded by the app, so this plot failed
# silently on the server.

# Input
# data = diurnal composite from diurnal_composite_rad_single_var()
# rad_var = variable name for radiation variable (either SW_IN_1_1_1 or PPFD_IN_1_1_1)

xcorr_rad <- function(data, rad_var, lang = "en") {
  if (is.null(data) || !nrow(data)) return(cq_empty_plot(tr("msg_no_data", lang)))
  a <- data$potential_radiation; b <- data[[rad_var]]
  ok <- is.finite(a) & is.finite(b)
  if (sum(ok) < 10) return(cq_empty_plot(tr("msg_no_data", lang)))
  cc <- stats::ccf(a[ok], b[ok], plot = FALSE)
  lag <- cc$lag[, , 1]; r <- cc$acf[, , 1]
  k <- which.max(r)
  ci <- stats::qnorm(0.975) / sqrt(sum(ok))
  cols <- ifelse(seq_along(r) == k, cq_semantic$exceeds, cq_semantic$measured)

  fig <- cq_plot()
  fig <- add_tr(fig, type = "bar", x = lag, y = signif(r, 4), marker = list(color = cols),
                         showlegend = FALSE,
                         hovertemplate = paste0(tr("ax_lag", lang), " %{x}<br>", tr("ax_corr", lang),
                                                " %{y:.3f}<extra></extra>"))
  fig$layout <- list(bargap = 0.35,
                      shapes = list(
                        list(type = "line", xref = "paper", x0 = 0, x1 = 1, y0 = ci, y1 = ci,
                             line = list(color = cq_brand$muted, dash = "dash", width = 1)),
                        list(type = "line", xref = "paper", x0 = 0, x1 = 1, y0 = -ci, y1 = -ci,
                             line = list(color = cq_brand$muted, dash = "dash", width = 1))),
                      annotations = list(list(
                        text = tr("max_lag", lang, r = fmt_num(r[k], 2, lang), k = lag[k]),
                        x = 0, y = 1.02, xref = "paper", yref = "paper", xanchor = "left", yanchor = "bottom",
                        showarrow = FALSE, font = list(size = 13, color = cq_brand$ink))))
  cq_layout(fig, xlab = tr("ax_lag", lang), ylab = tr("ax_corr", lang), showlegend = FALSE,
            filename = paste0("ccf_", rad_var))
}
