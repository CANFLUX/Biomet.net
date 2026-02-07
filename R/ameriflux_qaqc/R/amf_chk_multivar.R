#' Title
#'
#' @param site
#' @param year
#' @param full.time
#' @param target.name1
#' @param target.unit1
#' @param target.name2
#' @param target.unit2
#' @param target.data1
#' @param target.data2
#' @param rsquare.threshold
#' @param outlier.threshold
#' @param outlier.dev.threshold
#' @param path.out
#' @param plot.all
#'
#' @return
#' @export
#'
#' @examples
amf_chk_multivar <- function(site,
                             year,
                             full.time,
                             target.name1,
                             target.unit1,
                             target.name2,
                             target.unit2,
                             target.data1,
                             target.data2,
                             rsquare.threshold,
                             outlier.threshold,
                             outlier.dev.threshold,
                             path.out,
                             plot.all = F) {
  #### Convert the data into numeric
  if (!is.numeric(target.data1)) {
    target.data1 <- as.numeric(target.data1)
    warning(paste(target.name1, "isn't numeric..."))
  }
  if (!is.numeric(target.data2)) {
    target.data2 <- as.numeric(target.data2)
    warning(paste(target.name2, "isn't numeric..."))
  }

  if (sum.notna(target.data1) == 0 | sum.notna(target.data2) == 0) {
    if (sum.notna(target.data1) == 0)
      warning(paste(target.name1, "all missing..."))
    stat.out <- NULL

    if (sum.notna(target.data2) == 0)
      warning(paste(target.name2, "all missing..."))
    stat.out <- NULL

  } else if (sum.both.notna(target.data1, target.data2) == 0) {
    warning(paste(target.name1, target.name2, "pairs all missing..."))
    stat.out <- NULL

  } else {
    #### run comparison for each pair of variables (designed for checking data after 1-to-1 mapping)
    ##   generate plots and stats
    missing.loc1 <- which(is.na(target.data1))
    missing.loc2 <- which(is.na(target.data2))

    target.data <- data.frame(var1 = target.data1,
                              var2 = target.data2)

    ## core model for regression
    ln.r2.tmp <- summary(lm(var2 ~ var1,
                            data = na.omit(target.data)))
    #ln.tmp <- suppressMessages(lmodel2::lmodel2(var2 ~ var1,
    #                                            data = na.omit(target.data)))
    target.data.na <- na.omit(target.data)
    ln.tmp <- pracma::odregress(x = target.data.na$var1,
                                y = target.data.na$var2)

    stat.out <- data.frame(
      year = year,
      var1 = target.name1,
      var2 = target.name2,
      var1_missing = length(missing.loc1),
      var2_missing = length(missing.loc2),
      var_pair_n = nrow(na.omit(target.data)),
      rsqure = ln.r2.tmp$r.squared,
      slope = ln.tmp$coeff[1],
      intercept = ln.tmp$coeff[2],
      dev_std = NA,
      outlier = NA
    )

    ### obtain outliers via distance from regression line
    target.data$predict1 <-
      stat.out$intercept + target.data$var1 * stat.out$slope
    target.data$predict2 <-
      (target.data$var2 - stat.out$intercept) / stat.out$slope
    target.data$dev <-
      abs(target.data$var1 - target.data$predict2) *
      abs(target.data$var2 - target.data$predict1) /
      sqrt((target.data$var1 - target.data$predict2) ^ 2 +
             (target.data$var2 - target.data$predict1) ^ 2
      )
    target.data$dev[!is.na(target.data$predict1) &
                      !is.na(target.data$var2) &
                      target.data$predict1 < target.data$var2] <-
      -(target.data$dev[!is.na(target.data$predict1) &
                          !is.na(target.data$var2) &
                          target.data$predict1 < target.data$var2])

    stat.out$dev_std <- sd(target.data$dev, na.rm = T)
    target.data$flag_outlier <- !is.nan(target.data$dev) &
      !is.na(target.data$dev) &
      ((
        target.data$dev > 0 &
          target.data$dev > outlier.dev.threshold * stat.out$dev_std
      ) |
        (
          target.data$dev < 0 &
            target.data$dev < (-outlier.dev.threshold * stat.out$dev_std)
        )
      )
    stat.out$outlier <-
      sum(target.data$flag_outlier, na.rm = T) / nrow(target.data)

    if (stat.out$rsqure < rsquare.threshold |
        stat.out$outlier > outlier.threshold |
        stat.out$rsqure == 1) {
      should.plot <- TRUE
      any.error <- TRUE

    } else{
      should.plot <- FALSE
      any.error <- FALSE

    }

    if (plot.all | should.plot) {
      png(file.path(path.out,
        paste0(
          site,
          "-",
          year,
          "-",
          target.name1,
          "-",
          target.name2,
          ".png",
          sep = ""
        )),
        width = 7,
        height = 9,
        units = "in",
        res = 250
      )

      rng.all1 <- range(target.data1, na.rm = T)
      rng.all2 <- range(target.data2, na.rm = T)
      rng.all1[1] <-
        rng.all1[1] - 0.05 * (rng.all1[2] - rng.all1[1])
      rng.all2[1] <-
        rng.all2[1] - 0.05 * (rng.all2[2] - rng.all2[1])

      par(
        fig = c(0, 1, 0.7, 1),
        mar = c(0.5, 4, 1.5, 0.5),
        oma = c(1, 1, 0, 0.5)
      )
      plot(
        full.time,
        target.data$var1,
        ylab = "",
        xlab = "",
        xaxt = "n",
        type = "p",
        col = rgb(0, 0, 0, 0.3),
        las = 1,
        pch = 16,
        cex = 0.5,
        ylim = rng.all1
      )
      points(
        full.time[target.data$flag_outlier],
        target.data$var1[target.data$flag_outlier],
        pch = 1,
        col = "red",
        cex = 1
      )
      mtext(side = 2,
            text = target.name1,
            line = 4)
      mtext(
        side = 2,
        text = target.unit1,
        line = 2.8,
        cex = 0.8
      )
      mtext(
        side = 3,
        paste(
          "flagged:",
          sum(target.data$flag_outlier, na.rm = T),
          "/",
          nrow(target.data),
          "(",
          round(
            sum(target.data$flag_outlier, na.rm = T) / nrow(target.data),
            digits = 3
          ) * 100,
          "% )"
        ),
        line = 0.5,
        adj = 0,
        col = ifelse(any.error, "red", "black"),
        cex = 0.8
      )

      par(
        fig = c(0, 1, 0.35, 0.7),
        mar = c(3.5, 4, 0.5, 0.5),
        oma = c(1, 1, 0, 0.5),
        new = T
      )
      plot(
        full.time,
        target.data2,
        ylab = "",
        xlab = "",
        type = "p",
        col = rgb(0, 0, 0, 0.3),
        las = 1,
        pch = 16,
        cex = 0.5,
        ylim = rng.all2
      )
      points(
        full.time[target.data$flag_outlier],
        target.data$var2[target.data$flag_outlier],
        pch = 1,
        col = "red",
        cex = 1
      )
      mtext(side = 2,
            text = target.name2,
            line = 4)
      mtext(
        side = 2,
        text = target.unit2,
        line = 2.8,
        cex = 0.8
      )
      mtext(side = 1,
            text = "TIMESTAMP",
            line = 2.2)

      par(
        fig = c(0, 0.5, 0, 0.35),
        mar = c(4, 4, 0.5, 0.5),
        oma = c(1, 1, 0, 0.5),
        new = T
      )
      plot(
        target.data1,
        target.data2,
        xlab = "",
        ylab = "",
        xlim = rng.all1,
        ylim = rng.all2,
        col = rgb(0, 0, 0, 0.2),
        cex = 0.65,
        pch = 16,
        las = 1
      )
      points(
        target.data$var1[target.data$flag_outlier],
        target.data$var2[target.data$flag_outlier],
        col = "red",
        cex = 1,
        pch = 1
      )
      abline(
        a = stat.out$intercept,
        b = stat.out$slope,
        col = "orange",
        lty = 1,
        lwd = 1.5
      )
      #abline(v = 0, col = "black", lty = 4)
      #abline(h = 0, col = "black", lty = 4)
      mtext(
        side = 3,
        paste(
          "slope:",
          round(stat.out$slope, digits = 2),
          "itcpt:",
          round(stat.out$intercept, digits = 2),
          "R2:",
          round(stat.out$rsqure, digits = 2),
          sep = " "
        ),
        line = 0.2,
        adj = 0,
        cex = 0.8,
        col = ifelse(any.error, "red", "orange")
      )
      mtext(side = 2,
            text = paste(target.name2),
            line = 4)
      mtext(
        side = 2,
        text = target.unit2,
        line = 2.8,
        cex = 0.8
      )
      mtext(side = 1,
            text = paste(target.name1),
            line = 3.4)
      mtext(
        side = 1,
        text = target.unit1,
        line = 2.5,
        cex = 0.8
      )

      par(
        fig = c(0.5, 1, 0, 0.35),
        mar = c(4, 4, 0.5, 0.5),
        oma = c(1, 1, 0, 0.5),
        new = T
      )
      hist(
        target.data$dev,
        xlab = "",
        nclass = 100,
        border = "white",
        col = "grey",
        main = "",
        las = 1,
        xlim = c(min(
          c(
            min(target.data$dev, na.rm = T),
            -stat.out$dev_std * outlier.dev.threshold
          ),
          na.rm = T
        ),
        max(
          c(
            max(target.data$dev, na.rm = T),
            stat.out$dev_std * outlier.dev.threshold
          ),
          na.rm = T
        ))
      )
      mtext(
        side = 3,
        paste(
          "mean:",
          round(mean(target.data$dev, na.rm = T), digits = 2),
          "median:",
          round(median(target.data$dev, na.rm = T), digits = 2),
          "std:",
          round(sd(target.data$dev, na.rm = T), digits = 2),
          sep = " "
        ),
        line = 0,
        adj = 1,
        cex = 0.8,
        col = "black"
      )
      abline(
        v = c(
          stat.out$dev_std * outlier.dev.threshold,
          -stat.out$dev_std * outlier.dev.threshold
        ),
        col = "red",
        lty = 4
      )
      mtext(side = 1,
            text = "Deviation from regression line",
            line = 3.4)
      dev.off()
    }
  }
  return(stat.out)

}
