#' Title
#'
#' @param case
#' @param path.out
#' @param var.name
#' @param base.name
#' @param TIMESTAMP
#' @param data1.tmp
#' @param outlier.loc2.1
#' @param outlier.loc3.1
#' @param limit.ls
#' @param iqr.min
#' @param iqr.max
#'
#' @return
#' @export
#'
#' @examples
amf_chk_physical_range <- function(case,
                                   path.out,
                                   var.name,
                                   base.name,
                                   TIMESTAMP,
                                   data1.tmp,
                                   outlier.loc2.1,
                                   outlier.loc3.1,
                                   limit.ls,
                                   iqr.min = NULL,
                                   iqr.max = NULL) {
  png(
    file.path(path.out, paste0(case, "_", var.name, "_range-check.png")),
    width = 6.5,
    height = 6.5,
    res = 200,
    units = "in"
  )
  ## legend
  par(
    fig = c(0, 0.9, 0.9, 1),
    mar = c(0, 3, 0.5, 0.5),
    oma = c(1.5, 1, 0.5, 1.2)
  )
  plot(
    NA,
    xaxt = "n",
    yaxt = "n",
    bty = "n",
    xlim = c(0, 1),
    ylim = c(0, 1)
  )
  legend(
    "topleft",
    legend = c(
      "Plausible range (+/-5%)",
      "Plausible range",
      "Points beyond Plausible range (+/-5%)",
      "Points beyond Plausible range",
      "Interquantile Range (network max)",
      "Interquantile Range (network min)"
    ),
    lty = c(2, 2, NA, NA, 1, 1),
    col = c("red", "orange", "red", "orange", "forestgreen", "green"),
    pch = c(NA, NA, 1, 1, NA, NA),
    pt.cex = c(NA, NA, 1.5, 1.5, NA, NA),
    ncol = 2,
    bty = "n",
    cex = 0.6
  )

  ## plot using data range
  par(
    fig = c(0, 0.9, 0.45, 0.9),
    mar = c(0, 3, 2, 0.5),
    new = T
  )
  plot(
    TIMESTAMP,
    data1.tmp,
    ylab = NA,
    xlab = NA,
    xaxt = "n",
    cex = 0.5,
    pch = 21,
    bg = "grey",
    col = "darkgrey",
    las = 1
  )
  points(
    TIMESTAMP[outlier.loc2.1],
    data1.tmp[outlier.loc2.1],
    pch = 1,
    col = "orange",
    cex = 1.5,
    lwd = 1.5
  )
  points(
    TIMESTAMP[outlier.loc3.1],
    data1.tmp[outlier.loc3.1],
    pch = 1,
    col = "red",
    cex = 1.5,
    lwd = 1.5
  )
  abline(
    h = limit.ls[which(limit.ls$Name == base.name),
                 c("Max_buff", "Min_buff")],
    col = "red",
    lty = 2,
    lwd = 1.5
  )
  abline(
    h = limit.ls[which(limit.ls$Name == base.name),
                 c("Max", "Min")],
    col = "orange",
    lty = 2,
    lwd = 1.5
  )
  mtext(
    side = 3,
    line = 0,
    outer = F,
    paste(
      round(length(outlier.loc3.1) / length(na.omit(data1.tmp)) * 100, digits = 3),
      "% beyond plausible range +/- 5%"
    ),
    cex = 0.8,
    adj = 0
  )
  mtext(
    side = 3,
    line = 0.8,
    outer = F,
    paste(
      round(length(outlier.loc2.1) / length(na.omit(data1.tmp)) * 100, digits = 3),
      "% beyond plausible range"
    ),
    cex = 0.8,
    adj = 0
  )

  par(
    fig = c(0.9, 1, 0.45, 0.9),
    mar = c(0, 0, 2, 0.5),
    new = T
  )
  #vioplot(na.omit(data1.tmp), yaxt = "n")
  boxplot(
    na.omit(data1.tmp),
    yaxt = "n",
    cex = 0.5,
    pch = 16,
    col = "grey"
  )
  abline(
    h = limit.ls[which(limit.ls$Name == base.name),
                 c("Max_buff", "Min_buff")],
    col = "red",
    lty = 2,
    lwd = 1.5
  )
  abline(
    h = limit.ls[which(limit.ls$Name == base.name),
                 c("Max", "Min")],
    col = "orange",
    lty = 2,
    lwd = 1.5
  )
  lines(
    c(0.7, 0.7),
    c(
      median(data1.tmp, na.rm = T) +
        (
          quantile(data1.tmp, na.rm = T, 0.75) - median(data1.tmp, na.rm = T)
        ) /
        IQR(data1.tmp, na.rm = T) * iqr.max,
      median(data1.tmp, na.rm = T) +
        (
          quantile(data1.tmp, na.rm = T, 0.25) - median(data1.tmp, na.rm = T)
        ) /
        IQR(data1.tmp, na.rm = T) * iqr.max
    ),
    lwd = 2,
    col = "forestgreen"
  )
  lines(
    c(1.3, 1.3),
    c(
      median(data1.tmp, na.rm = T) +
        (
          quantile(data1.tmp, na.rm = T, 0.75) - median(data1.tmp, na.rm = T)
        ) /
        IQR(data1.tmp, na.rm = T) * iqr.min,
      median(data1.tmp, na.rm = T) +
        (
          quantile(data1.tmp, na.rm = T, 0.25) - median(data1.tmp, na.rm = T)
        ) /
        IQR(data1.tmp, na.rm = T) * iqr.min
    ),
    lwd = 2,
    col = "green"
  )

  ## plot using plausible range
  par(
    fig = c(0, 0.9, 0, 0.45),
    mar = c(3, 3, 0.5, 0.5),
    new = T
  )
  plot(
    TIMESTAMP,
    data1.tmp,
    ylab = NA,
    xlab = NA,
    cex = 0.5,
    pch = 21,
    bg = "grey",
    col = "darkgrey",
    las = 1,
    ylim = as.numeric(limit.ls[which(limit.ls$Name == base.name),
                               c("Min_buff", "Max_buff")])
  )
  points(
    TIMESTAMP[outlier.loc2.1],
    data1.tmp[outlier.loc2.1],
    pch = 1,
    col = "orange",
    cex = 1.5,
    lwd = 1.5
  )
  points(
    TIMESTAMP[outlier.loc3.1],
    data1.tmp[outlier.loc3.1],
    pch = 1,
    col = "red",
    cex = 1.5,
    lwd = 1.5
  )
  abline(
    h = limit.ls[which(limit.ls$Name == base.name),
                 c("Max_buff", "Min_buff")],
    col = "red",
    lty = 2,
    lwd = 1.5
  )
  abline(
    h = limit.ls[which(limit.ls$Name == base.name),
                 c("Max", "Min")],
    col = "orange",
    lty = 2,
    lwd = 1.5
  )

  par(
    fig = c(0.9, 1, 0, 0.45),
    mar = c(3, 0, 0.5, 0.5),
    new = T
  )
  boxplot(
    na.omit(data1.tmp),
    yaxt = "n",
    cex = 0.5,
    pch = 16,
    col = "grey",
    ylim = as.numeric(limit.ls[which(limit.ls$Name == base.name),
                               c("Min_buff", "Max_buff")])
  )
  abline(
    h = limit.ls[which(limit.ls$Name == base.name),
                 c("Max_buff", "Min_buff")],
    col = "red",
    lty = 2,
    lwd = 1.5
  )
  abline(
    h = limit.ls[which(limit.ls$Name == base.name),
                 c("Max", "Min")],
    col = "orange",
    lty = 2,
    lwd = 1.5
  )
  lines(
    c(0.7, 0.7),
    c(
      median(data1.tmp, na.rm = T) +
        (
          quantile(data1.tmp, na.rm = T, 0.75) - median(data1.tmp, na.rm = T)
        ) /
        IQR(data1.tmp, na.rm = T) * iqr.max,
      median(data1.tmp, na.rm = T) +
        (
          quantile(data1.tmp, na.rm = T, 0.25) - median(data1.tmp, na.rm = T)
        ) /
        IQR(data1.tmp, na.rm = T) * iqr.max
    ),
    lwd = 2,
    col = "forestgreen"
  )
  lines(
    c(1.3, 1.3),
    c(
      median(data1.tmp, na.rm = T) +
        (
          quantile(data1.tmp, na.rm = T, 0.75) - median(data1.tmp, na.rm = T)
        ) /
        IQR(data1.tmp, na.rm = T) * iqr.min,
      median(data1.tmp, na.rm = T) +
        (
          quantile(data1.tmp, na.rm = T, 0.25) - median(data1.tmp, na.rm = T)
        ) /
        IQR(data1.tmp, na.rm = T) * iqr.min
    ),
    lwd = 2,
    col = "green"
  )

  mtext(side = 1,
        "TIMESTAMP",
        line = 0,
        outer = T)
  mtext(side = 2,
        var.name,
        line = 0,
        outer = T)

  dev.off()
}
