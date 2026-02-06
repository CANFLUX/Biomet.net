#' Diurnal-Seasonal Check
#'
#' @description
#' The module examines the diurnal-seasonal pattern of a target variable
#' against the historical records at a site and determines if the data are
#' within the expected ranges. In particular, the module relies on the
#' pronounced temporal variations at the diurnal and seasonal scales of most
#' micrometeorological variables.
#'
#' @param data.sel A data frame of target data from a calender year to check,
#' containing the following variables.
#' \itemize{
#'   \item TIMESTAMP: An object of class "POSIXlt" in the UTC time zone,
#'   based on the middle time of the interval
#'   \item DOY2: Sequential day window ID for each data row. This should match
#'   *DOY2* in *thres.in*.
#'   \item HR2: Sequential hour ID for each data row. This should match *HR2*
#'   in *thres.in*.
#'   \item var: Target variable data
#'   }
#' @param thres.in A data frame of historical ranges, containing the following
#' variables:
#' \itemize{
#'  \item DOY2: Sequential day window ID for each data row. Default =
#'   floor(DOY / 30); DOY2 = 12 if DOY > 360.
#'  \item HR2: Sequential hour ID for each data row. Default = hour + minute
#'   / 30, e.g., 0.25 for an interval with middle time of 00:15
#'  \item upp.bd2: Historical 97.5% percentile range of a target variable from
#'  a target site
#'  \item upp.bd1: Historical 75% percentile range of a target variable from a
#'  target site
#'  \item med.bd: Historical 50% percentile range of a target variable from a
#'  target site
#'  \item low.bd1: Historical 25% percentile range of a target variable from a
#'  target site
#'  \item low.bd2: Historical 2.5% percentile range of a target variable from a
#'  target site
#' }
#' @param var.name A target variable (character).
#' @param site A target site ID (CC-Sss).
#' @param year Year of the target data (numeric).
#' @param d.hr Data points per day (numeric), i.e., 48 for half-hourly.
#' @param n.wd Number of day windows per year (numeric), i.e., 12
#' @param path.out Output directory
#' @param Q1Q3.threshold Fail threshold for diurnal-seasonal check (numeric).
#' Fail if fewer than this ratio of data fall within the historical
#' interquartile range.
#' @param Q95.threshold Fail threshold for diurnal-seasonal check (numeric).
#' Fail if more than this ratio of data fall outside the historical
#'  2.5%-97.5% range.
#' @param Q1Q3.threshold2 Warning threshold for diurnal-seasonal check (numeric).
#' Warning if fewer than this ratio of data fall within the historical
#' interquartile range.
#' @param Q95.threshold2 Warning threshold for diurnal-seasonal check (numeric).
#' Warning if more than this ratio of data fall outside the historical
#'  2.5%-97.5% range.
#' @param plot_always Whether plot figures always (True/False). If set False,
#' only plot when fail/warning.
#'
#' @return A data frame contains the summary statistics of the check.
#' \itemize{
#'  \item var_name: Variable name (character)
#'  \item lag: the time step shift at which the maximal absolute cross
#'  correlation between the historical and new data (numeric).
#'  \item max_ccor: The maximal absolute cross correlation between the
#'  historical and new data (numeric).
#'  \item wihtin_95per_range: The ratio of occasions that the new data are within
#'   the 2.5%-97.5% ranges of historical records (numeric).
#'  \item wihtin_Q1Q3_range: The ratio of occasions that the new data are within
#'   the 25%-75% ranges of historical records (numeric).
#'  \item all_constant: Whether a target variable is all constant (True/False).
#' }
#'
#' @examples
amf_chk_diurnal_seasonal <- function(data.sel,
                                     thres.in,
                                     var.name,
                                     site,
                                     year,
                                     d.hr,
                                     n.wd,
                                     path.out,
                                     Q1Q3.threshold = 15,
                                     Q95.threshold = 70,
                                     Q1Q3.threshold2 = 30,
                                     Q95.threshold2 = 85,
                                     plot_always = FALSE) {
  hr <- ifelse(d.hr == 48, 30, 60)

  new.median <- data.frame(
    DOY2 = rep(c(1:(n.wd)), each = d.hr),
    HR2 = rep(c(1:d.hr) / (60 / hr) - (hr / 60) / 2, times =
                n.wd),
    median = NA
  )

  for (ii in 1:n.wd) {
    new.median$median[c(1:d.hr) + (ii - 1) * d.hr] <-
      as.vector(c(tapply(
        data.sel$var[data.sel$DOY2 == ii],
        data.sel$HR2[data.sel$DOY2 == ii],
        na.median
      )))
  }

  if (sum.na(new.median$median) == 0 &
      length(new.median$median) == length(thres.in$med.bd)) {
    cor.out <- cor(new.median$median,
                   thres.in$med.bd)
    ccf.out <- ccf(new.median$median,
                   thres.in$med.bd,
                   plot = FALSE,
                   lag.max = d.hr / 2)

  } else{
    cor.out <- NA
    ccf.out <- NULL
  }

  ### revise the flow using merge instead of looping
  data.sel$DOY2_HR2 <- paste(data.sel$DOY2, data.sel$HR2, sep = "_")
  thres.in$DOY2_HR2 <- paste(thres.in$DOY2, thres.in$HR2, sep = "_")

  data.sel <- merge.data.frame(data.sel,
                               thres.in[,-which(colnames(thres.in) %in% c("DOY2", "HR2"))],
                               by = "DOY2_HR2",
                               all.x = TRUE,
                               sort = FALSE)

  # within 95% range
  logger1 <- sum(
    !is.na(data.sel$var) &
      data.sel$var >= data.sel$low.bd2 &
      data.sel$var <= data.sel$upp.bd2,
    na.rm = T
  )
  # within inter-quantile
  logger2 <- sum(
    !is.na(data.sel$var) &
      data.sel$var >= data.sel$low.bd1 &
      data.sel$var <= data.sel$upp.bd1,
    na.rm = T
  )

  logger1 <- logger1 / sum.notna(data.sel$var) * 100
  logger2 <- logger2 / sum.notna(data.sel$var) * 100

  ## all constant
  all.constant <- amf_chk_constant(data.sel$var)

  ## combine error
  # if(!is.null(ccf.out) & sum.notna(ccf.out$acf) > 0){
  #   any_error <- (logger1 < Q95.threshold) |
  #     (logger2 < Q1Q3.threshold) |
  #     ccf.out$lag[which(abs(ccf.out$acf) == max(abs(ccf.out$acf)))] != 0 |
  #     all.constant
  # }else{
  any_error <- (logger1 < Q95.threshold) |
    (logger2 < Q1Q3.threshold) |
    all.constant
  #}

  ########################################################################################
  # only plot if plot_always == TRUE or any error
  if (plot_always | any_error) {
    rng <- c(min(
      c(data.sel$var, thres.in$low.bd1, thres.in$low.bd2),
      na.rm = T
    ),
    max(
      c(data.sel$var, thres.in$upp.bd1, thres.in$upp.bd2),
      na.rm = T
    ))

    png(
      file.path(
        path.out,
        paste0(site,
        "_",
        year,
        "_",
        var.name,
        "_seasonal-diurnal-check.png"
      )),
      width = 6,
      height = 4.5,
      units = "in",
      res = 200,
      points = 10
    )

    par(
      mfrow = c(3, 4),
      mar = c(0, 0, 1.2, 0),
      oma = c(3.5, 5, 3, 1)
    )

    for (m in 1:max(data.sel$DOY2, na.rm = T)) {
      plot(
        data.sel$HR2[data.sel$DOY2 == m],
        data.sel$var[data.sel$DOY2 == m],
        xlab = "",
        ylab = "",
        pch = 16,
        cex = 0.8,
        col = "darkgrey",
        yaxt = "n",
        xaxt = "n",
        ylim = rng,
        xaxs = "i"
      )
      polygon(
        c(thres.in$HR2[thres.in$DOY2 == m],
          rev(thres.in$HR2[thres.in$DOY2 == m])),
        c(thres.in$upp.bd2[thres.in$DOY2 == m],
          rev(thres.in$low.bd2[thres.in$DOY2 == m])),
        col = "wheat1",
        border = NA
      )
      polygon(
        c(thres.in$HR2[thres.in$DOY2 == m],
          rev(thres.in$HR2[thres.in$DOY2 == m])),
        c(thres.in$upp.bd1[thres.in$DOY2 == m],
          rev(thres.in$low.bd1[thres.in$DOY2 == m])),
        col = "salmon",
        border = NA
      )
      points(
        data.sel$HR2[data.sel$DOY2 == m],
        data.sel$var[data.sel$DOY2 == m],
        pch = 16,
        cex = 0.8,
        col = "darkgrey"
      )

      lines(
        thres.in$HR2[thres.in$DOY2 == m],
        thres.in$med.bd[thres.in$DOY2 == m],
        type = "l",
        lty = 1,
        lwd = 2,
        col = "red4"
      )
      lines(
        new.median$HR2[new.median$DOY2 == m],
        new.median$median[new.median$DOY2 == m],
        type = "l",
        lty = 1,
        lwd = 2,
        col = "black"
      )
      mtext(
        side = 3,
        paste(
          substr(
            min(data.sel$TIMESTAMP[data.sel$DOY2 == m], na.rm = T),
            start = 6,
            stop = 10
          ),
          "~",
          substr(
            max(data.sel$TIMESTAMP[data.sel$DOY2 == m], na.rm = T),
            start = 6,
            stop = 10
          )
        ),
        line = 0,
        cex = 0.8
      )

      if (m == 1) {
        legend(
          "topleft",
          legend = c("data", "data median"),
          pch = c(16, NA),
          lty = c(NA, 1),
          lwd = c(1, 2),
          col = c("darkgrey", "black"),
          border = NA,
          bty = "n",
          cex = 0.8
        )
      }
      if (m == 2) {
        legend(
          "topleft",
          legend = c(
            "previous median",
            "previous 25-75% range",
            "previous 2.5-97.5% range"
          ),
          lty = c(1, NA, NA),
          lwd = c(2, 1, 1),
          fill = c(NA, "salmon", "wheat1"),
          col = c("red4", NA, NA),
          border = NA,
          bty = "n",
          cex = 0.8
        )
      }

      if (round((m - 1) / 4) == (m - 1) / 4) {
        axis(
          side = 2,
          at = seq(rng[1], rng[2], length.out = 5),
          labels = round(seq(rng[1], rng[2], length.out =
                               5), digits = 1),
          cex.axis = 0.9,
          las = 2
        )
      }

      if (m >= (max(data.sel$DOY2, na.rm = T) - 3)) {
        axis(
          side = 1,
          at = thres.in$HR2[thres.in$DOY2 == m][seq(0, d.hr, length.out = 7)],
          labels = c(4, 8, 12, 16, 20, 24),
          cex.axis = 0.9
        )
      }
    }

    if (!is.null(ccf.out) & sum.notna(ccf.out$acf) > 0) {
      mtext(
        side = 3,
        paste(
          "max ccor =",
          round(ccf.out$acf[which(abs(ccf.out$acf) == max(abs(ccf.out$acf)))], digits =
                  3),
          "at lag",
          ccf.out$lag[which(abs(ccf.out$acf) == max(abs(ccf.out$acf)))]
        ),
        adj = 0,
        font = 3,
        line = 1.5,
        outer = T,
        cex = 0.8,
        col = ifelse(ccf.out$lag[which(abs(ccf.out$acf) == max(abs(ccf.out$acf)))] ==
                       0, "black", "red")
      )
    } else{
      mtext(
        side = 3,
        paste("max ccor = NA at lag NA"),
        adj = 0,
        font = 3,
        line = 1.5,
        outer = T,
        cex = 0.8
      )
    }

    mtext(
      side = 3,
      paste("cor =", round(cor.out, digits = 3)),
      adj = 0,
      font = 3,
      line = 0.5,
      outer = T,
      cex = 0.8,
      ifelse(cor.out < 0.5, "red", "black")
    )
    mtext(
      side = 3,
      paste("wihtin 95% range:", round(logger1, digits = 1), "%"),
      adj = 1,
      font = 3,
      line = 1.5,
      outer = T,
      cex = 0.8,
      col = ifelse(
        logger1 < Q95.threshold,
        "red",
        ifelse(logger1 < Q95.threshold2, "orange", "black")
      )
    )
    mtext(
      side = 3,
      paste("wihtin Q1-Q3 range:", round(logger2, digits = 1), "%"),
      adj = 1,
      font = 3,
      line = 0.5,
      outer = T,
      cex = 0.8,
      col = ifelse(
        logger2 < Q1Q3.threshold,
        "red",
        ifelse(logger2 < Q1Q3.threshold2, "orange", "black")
      )
    )

    mtext(
      side = 3,
      "DATE",
      line = 0,
      outer = T,
      font = 2
    )
    #abline(v=c(0:max(floor(thres.in$HR2))),col="black",lty=4)
    mtext(
      side = 1,
      "HOUR",
      line = 2.5,
      outer = T,
      font = 2
    )
    mtext(
      side = 2,
      var.name,
      line = 3.5,
      outer = T,
      font = 2
    )
    dev.off()

  }

  # statistics output
  stat.out <- data.frame(
    #site = site,
    year = year,
    var_name = var.name,
    lag = ifelse(!is.null(ccf.out),
                 ccf.out$lag[which(abs(ccf.out$acf) == max(abs(ccf.out$acf)))],
                 NA),
    max_ccor = ifelse(!is.null(ccf.out),
                      ccf.out$acf[which(abs(ccf.out$acf) == max(abs(ccf.out$acf)))],
                      NA),
    wihtin_95per_range = logger1,
    wihtin_Q1Q3_range = logger2,
    all_constant = all.constant,
    stringsAsFactors = FALSE
  )

  return(stat.out)
}
