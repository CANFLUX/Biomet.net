#' Title
#'
#' @param ustar
#' @param ustar.name
#' @param sigmaw
#' @param sigmaw.name
#' @param zL
#' @param case
#' @param year
#' @param path.out
#' @param plot_always
#' @param extention
#' @param slope.dev.threshold
#'
#' @return
#' @export
#'
#' @examples
amf_chk_sigma <- function(ustar,
                          ustar.name,
                          sigmaw,
                          sigmaw.name,
                          zL = NULL,
                          case,
                          year,
                          path.out,
                          plot_always = FALSE,
                          extention = NULL,
                          slope.dev.threshold = 0.2) {
  # ustar = data4.tmp
  # ustar.name = get.ustar
  # sigmaw = data3.tmp
  # sigmaw.name = get.sigma.var
  # zL = data5.tmp

  lm2.1 <- suppressMessages((lmodel2::lmodel2(sigmaw ~ ustar)))
  if (!is.null(zL)) {
    if (sum(!is.na(zL) & abs(zL) < 0.1) > 30) {
      data2.2 <- data.frame(sigmaw = sigmaw,
                            ustar = ustar,
                            zL = zL)
      data2.2 <- na.omit(data2.2)
      if (nrow(data2.2) > 30) {
        lm2.2 <-
          suppressMessages((lmodel2::lmodel2(sigmaw[!is.na(zL) &
                                                      abs(zL) < 0.1] ~
                                               ustar[!is.na(zL) &
                                                       abs(zL) < 0.1])))
      }
    }
  }

  stat.out <- data.frame(
    data = c("all", "neutral"),
    slope = c(lm2.1$regression.results$Slope[3],
              NA)
  )
  if (!is.null(zL)) {
    if (sum(!is.na(zL) & abs(zL) < 0.1) > 30) {
      if (nrow(data2.2) > 30) {
        stat.out$slope[2] <- lm2.2$regression.results$Slope[3]
      }
    }
  }

  if (plot_always |
      abs(stat.out$slope[1] - 1.25) > slope.dev.threshold * 1.25 |
      (
        !is.null(zL) &
        !is.na(stat.out$slope[2]) &
        abs(stat.out$slope[2] - 1.25) > slope.dev.threshold * 1.25
      )) {
    rng.ustar <- c(0, quantile(ustar, 0.999, na.rm = T))
    rng.sigmaw <- c(0, quantile(sigmaw, 0.999, na.rm = T))

    png(
      file.path(
        path.out,
        paste0(case,
        "_",
        year,
        "_sigmaw_check",
        extention,
        ".png"
      )),
      width = 5,
      height = 5,
      res = 200,
      units = "in"
    )
    par(mar = c(4.5, 4.5, 2.5, 0.5),
        oma = c(0, 0, 0, 0))
    plot(
      ustar,
      sigmaw,
      ylab = sigmaw.name,
      xlab = ustar.name,
      cex = 0.8,
      pch = 16,
      col = rgb(0, 0, 0, 0.1),
      las = 1,
      ylim = rng.sigmaw,
      xlim = rng.ustar
    )
    if (!is.null(zL)) {
      points(
        ustar[!is.na(zL) & abs(zL) < 0.1],
        sigmaw[!is.na(zL) & abs(zL) < 0.1],
        cex = 0.8,
        pch = 16,
        col = rgb(1, 0, 0, 0.1)
      )
    }

    # Kaimal & finnigan 1994
    abline(
      a = 0,
      b = 1.25,
      lwd = 2,
      col = "green",
      lty = 1
    )
    ## Sorbjan 1986
    #abline(a = 0, b = 1.6, lwd = 2, col = "blue", lty = 2)

    abline(
      a = lm2.1$regression.results$Intercept[3],
      b = lm2.1$regression.results$Slope[3],
      lwd = 2,
      col = "black"
    )
    legend(
      0,
      rng.sigmaw[2],
      legend = c("all data", "regression (all data)", "Kaimal 94 model"),
      pch = c(16, NA, NA),
      lty = c(NA, 1, 1),
      lwd = c(1, 2, 2),
      col = c(rgb(0, 0, 0, 0.1), "black", "green"),
      bty = "n",
      cex = 0.8
    )

    mtext(
      side = 3,
      adj = 1,
      line = 0,
      paste(
        "SIGMA_W =",
        round(lm2.1$regression.results$Intercept[3], digits = 2),
        "+",
        round(lm2.1$regression.results$Slope[3], digits = 2),
        "* USTAR"
      ),
      cex = 0.6
    )

    if (!is.null(zL)) {
      abline(
        a = lm2.2$regression.results$Intercept[3],
        b = lm2.2$regression.results$Slope[3],
        lwd = 2,
        col = "red"
      )
      legend(
        "bottomright",
        legend = c("neutral data", "regression (neutral data)"),
        pch = c(16, NA),
        lty = c(NA, 1),
        lwd = c(1, 2),
        col = c(rgb(1, 0, 0, 0.1), "red"),
        bty = "n",
        cex = 0.8
      )
      mtext(
        side = 3,
        adj = 1,
        line = 0.6,
        paste(
          "SIGMA_W =",
          round(lm2.2$regression.results$Intercept[3], digits = 2),
          "+",
          round(lm2.2$regression.results$Slope[3], digits = 2),
          "* USTAR"
        ),
        col = "red",
        cex = 0.6
      )
    }

    dev.off()
  }

  return(stat.out)

}
