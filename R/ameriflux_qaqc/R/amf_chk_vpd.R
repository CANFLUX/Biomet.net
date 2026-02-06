#' Title
#'
#' @param vpd.data
#' @param ta.data
#' @param rh.data
#' @param out.path
#' @param plot.always
#' @param case
#' @param var.name
#' @param TIMESTAMP
#'
#' @return
#' @export
#'
#' @examples
amf_chk_vpd <- function(vpd.data,
                        ta.data,
                        rh.data,
                        out.path,
                        plot.always = FALSE,
                        case,
                        var.name,
                        TIMESTAMP) {
  e <-
    (0.612 * exp(17.27 * ta.data / (ta.data + 237.3))) * rh.data / 100

  vpd.cal <-
    ((0.612 * exp(17.27 * ta.data / (ta.data + 237.3))) - e) * 10

  lm.vpd <-
    suppressMessages((lmodel2::lmodel2(vpd.data ~ vpd.cal)))

  y.rng <- range(c(vpd.cal, vpd.data), na.rm = T)

  if (plot.always |
      abs(lm.vpd$regression.results$Slope[3] - 1) > 0.2) {
    png(
      file.path(path.out, paste0(case, "_", var.name, "_vpd_check.png")),
      width = 6.5,
      height = 4,
      units = "in",
      res = 200,
      pointsize = 11
    )
    par(
      fig = c(0, 0.6, 0, 1),
      mar = c(4.5, 4.5, 2, 0.5),
      oma = c(0, 0, 0, 0)
    )
    plot(
      TIMESTAMP,
      vpd.data,
      las = 1,
      ylab = "VPD (hPa)",
      xlab = "TIMESTAMP",
      pch = 16,
      col = rgb(0, 0, 0, 0.3),
      ylim = y.rng,
      cex = 0.8
    )
    points(
      TIMESTAMP,
      vpd.cal,
      pch = 3,
      col = rgb(0, 1, 0, 0.3),
      cex = 0.6
    )
    legend(
      "topleft",
      legend = c("observed VPD", "calculated VPD"),
      pch = c(16, 3),
      col = c(rgb(0, 0, 0, 0.3), rgb(0, 1, 0, 0.3)),
      bty = "n"
    )

    par(
      fig = c(0.6, 1, 0, 1),
      mar = c(4.5, 4.5, 2, 0.5),
      oma = c(0, 0, 0, 0),
      new = T
    )
    plot(
      vpd.cal,
      vpd.data,
      las = 1,
      xlim = y.rng,
      ylim = y.rng,
      xlab = "calculated VPD (hPa)",
      ylab = "observed VPD (hPa)",
      pch = 16,
      col = rgb(0, 0, 0, 0.3),
      cex = 0.8
    )
    abline(
      a = 0,
      b = 1,
      col = "black",
      lwd = 2
    )
    abline(
      a = lm.vpd$regression.results$Intercept[3],
      b = lm.vpd$regression.results$Slope[3],
      col = "red",
      lwd = 2
    )
    dev.off()

  }
  return(
    list(
      intercept = lm.vpd$regression.results$Intercept[3],
      slope = lm.vpd$regression.results$Slope[3]
    )
  )
}
