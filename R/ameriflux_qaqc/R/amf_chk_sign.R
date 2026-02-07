#' Sign Convention Check
#'
#' @description
#' The function checks the sign convention (+/-) of a target variable, based on
#' mean diurnal patterns in the summer months using the following logic: 1) A
#' variable is mostly positive, e.g., GPP, RECO; 2) A variable is mostly
#' negative, e.g., TAU; 3) A variable has known positive/negative pattern over
#' the hours of the day, e.g., G, SC. A student t test is used for first two
#' scenarios. A correlation test is used for the last scenario.
#'
#' @param data.in A vector of target data (numeric).
#' @param var.name A string of the target variable name (character).
#' @param var.sign A string defining the variable sign convention (character).
#' "pos" for variables mostly positive, e.g., GPP, RECO; "neg" for variables
#' mostly negative, e.g., TAU; NA for others, e.g., G, SC.
#' @param TIMESTAMP.sub A POSIXlt (time series format) vector, covering the same
#' time duration as data.in, which is used to parse the time information.
#' @param var.prototype (Default = NULL) A vector of mean diurnal time series
#' of the target variable (numeric). This is a prototype prescribed based on
#' known knowledge or network composite data. The vector length = 48 for
#' half-hourly and 24 for hourly. This is used only when *var.sign* is not
#' missing (NA).
#' @param case A string (character) used for output naming/figure title.
#' @param path.out Output directory
#' @param summer.mon A vector of summer months (numeric). For example, c(6:8)
#' for June-August in the North Hemisphere.
#' @param plot.always Whether plot figures always (True/False). If False, it
#' outputs figures only when there are errors or warnings in a check.
#'
#' @return A list of the following three objects, and a PNG figure saved to the
#' designated *path.out* directory (if plot.always = T), with a file name of
#' {case}_{var.name}_sign_convention_check.png
#' \itemize{
#'   \item Logic (True/False) Whether target variable differs from the expected
#'    in the first two scenarios based on student t test. Return NA for in
#'    scenario 3.
#'   \item The value of the t-statistic (numeric).
#'   \item The value of correlation (numeric).
#'   }
#' @examples
amf_chk_sign <- function(data.in,
                         var.name,
                         var.sign,
                         TIMESTAMP.sub,
                         var.prototype = NULL,
                         case,
                         path.out,
                         summer.mon,
                         plot.always = T) {
  HR.id <- TIMESTAMP.sub$hour + TIMESTAMP.sub$min / 60

  ## check if significantly negative/positive
  if (!is.na(var.sign)) {
    ttest <- stats::t.test(
      data.in,
      alternative = ifelse(var.sign == "pos", "less", "greater"),
      na.action = na.omit
    )
    ttest.result1 <- ttest$p.value < 0.05
    ttest.result2 <- round(ttest$statistic, digits = 3)
  } else{
    ttest <- stats::t.test(data.in,
                           alternative = "two.sided",
                           na.action = na.omit)
    ttest.result1 <- NA
    ttest.result2 <- round(ttest$statistic, digits = 3)
  }

  data.summer <-
    data.in[which((TIMESTAMP.sub$mon + 1) %in% summer.mon)]
  HR.summer <-
    HR.id[which((TIMESTAMP.sub$mon + 1)  %in% summer.mon)]
  data.prototype.summer <- tapply(data.summer, HR.summer, na.mean)
  data.HR.summer <- tapply(HR.summer, HR.summer, na.mean)

  ## check against prototype
  if (!is.null(var.prototype) &
      sum.notna(data.prototype.summer) > 0.5 * length(data.prototype.summer)) {
    cor.result <-
      round(
        stats::cor(var.prototype, data.prototype.summer, use = "complete.obs"),
        digits = 3
      )

  } else{
    cor.result <- NA

  }

  if (plot.always |
      (!is.na(ttest.result1) & ttest.result1) |
      (!is.na(cor.result) & cor.result < 0)) {
    rng.y <-
      range(c(
        data.summer,
        data.prototype.summer,
        var.prototype
      ),
      na.rm = T)
    png(file.path(path.out, paste0(case, "_", var.name,
        "_sign_convention_check.png"
      )),
      width = 6.5,
      height = 4,
      units = "in",
      res = 200,
      pointsize = 11
    )
    par(
      fig = c(0, 0.7, 0, 1),
      mar = c(4.5, 2, 2, 0.5),
      oma = c(0, 3, 0, 0)
    )
    plot(
      HR.summer,
      data.summer,
      ylim = rng.y,
      ylab = "",
      xlab = "HOUR",
      las = 1,
      pch = 16,
      col = rgb(0, 0, 0, 0.2),
      cex = 0.6
    )
    points(
      data.HR.summer,
      data.prototype.summer,
      pch = 21,
      col = "black",
      bg = "white",
      type = "b"
    )
    abline(h = 0)
    if (!is.null(var.prototype))
      points(
        data.HR.summer,
        var.prototype,
        pch = 16,
        type = "b",
        col = "orange"
      )
    mtext(
      side = 3,
      text = paste("corr =", cor.result),
      adj = 0,
      col = ifelse(!is.na(cor.result) &
                     cor.result < 0, "red", "black"),
      cex = 1
    )
    mtext(side = 2, var.name, line = 3.5)
    legend(
      "topleft",
      c(
        "Expected diurnal pattern",
        "Data mean (summer)",
        "Data (summer)"
      ),
      pch = c(16, 21, 16),
      col = c("orange", "black", rgb(0, 0, 0, 0.3)),
      pt.bg = c(NA, "white", NA),
      cex = 0.8,
      box.lwd = NA,
      bg = rgb(1, 1, 1, 0.5)
    )

    par(
      fig = c(0.7, 1, 0, 1),
      mar = c(4.5, 4, 2, 0.5),
      oma = c(0, 3, 0, 0),
      new = T
    )
    boxplot(data.in,
            las = 1)
    abline(h = 0)
    mtext(
      side = 3,
      text = paste("t =", ttest.result2),
      adj = 0,
      col = ifelse(!is.na(ttest.result1) &
                     ttest.result1, "red", "black"),
      cex = 0.8
    )
    mtext(
      side = 3,
      text = paste("mean =", round(na.mean(data.in), digits = 3)),
      line = 0.8,
      adj = 0,
      col = ifelse(!is.na(ttest.result1) &
                     ttest.result1, "red", "black"),
      cex = 0.8
    )
    dev.off()
  }

  return(list(c(ttest.result1),
              c(ttest.result2),
              c(cor.result)))
}
