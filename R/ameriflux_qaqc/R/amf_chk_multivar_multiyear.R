#' Title
#'
#' @param site
#' @param multi.var.stat
#' @param mslope.dev.threshold
#' @param rsquare.threshold
#' @param path.out
#' @param plot.all
#'
#' @return
#' @export
#'
#' @examples
amf_chk_multivar_multiyear <- function(site,
                                       multi.var.stat,
                                       mslope.dev.threshold,
                                       rsquare.threshold,
                                       path.out,
                                       plot.all = F){

  ## min 3 years valid regression results
  multi.slope <- NA
  if(sum(!is.na(multi.var.stat$rsqure) &
         multi.var.stat$rsqure > rsquare.threshold) >= 3 ){
    multi.slope <-
      mean(multi.var.stat$slope[!is.na(multi.var.stat$rsqure) &
                                  multi.var.stat$rsqure > rsquare.threshold], na.rm = T)
  }

  multi.var.stat$slope.dev <-
    (multi.var.stat$slope - multi.slope) / multi.slope

  multi.var.stat$flag_rsquare <- FALSE
  multi.var.stat$flag_rsquare[!is.na(multi.var.stat$rsqure) &
                                (multi.var.stat$rsqure < rsquare.threshold |
                                   multi.var.stat$rsqure == 1)] <- TRUE

  multi.var.stat$flag_slope <- FALSE
  multi.var.stat$flag_slope[!is.na(multi.var.stat$slope.dev) &
                              abs(multi.var.stat$slope.dev) > mslope.dev.threshold] <- TRUE

  if (any(multi.var.stat$flag_rsquare | multi.var.stat$flag_slope)) {
    should.plot <- TRUE
    any.error <- TRUE
  } else{
    should.plot <- FALSE
    any.error <- FALSE
  }

  if (plot.all | should.plot) {
    png(file.path(
        path.out,
        paste0(site,
        "-allyear-",
        multi.var.stat$var1[1],
        "-",
        multi.var.stat$var2[1],
        ".png",
        sep = ""
      )),
      width = 6,
      height = 4,
      units = "in",
      res = 250
    )
    par(fig = c(0, 1, 0, 1), mar = c(3.5, 4, 2.5, 3.5), oma = c(0.5, 0.5, 0, 1))
    plot(multi.var.stat$year,
         multi.var.stat$rsqure,
         ylab = "",
         xlab = "",
         type = "b",
         col = rgb(0.2, 1, 0.2, 0.7),
         las = 1,
         pch = 16,
         cex = 1,
         ylim = c(0, 1))
    points(multi.var.stat$year[multi.var.stat$flag_rsquare],
           multi.var.stat$rsqure[multi.var.stat$flag_rsquare],
           pch = 1,
           cex = 3,
           col = "red")
    par(new = T)
    plot(multi.var.stat$year,
         multi.var.stat$slope,
         ylab = "",
         xlab = "",
         xaxt = "n",
         yaxt = "n",
         type = "b",
         col = rgb(0.2, 0.2, 1, 0.7),
         las = 1,
         pch = 16,
         cex = 1,
         ylim = range(multi.var.stat$slope, na.rm = T))
    points(multi.var.stat$year[multi.var.stat$flag_slope],
           multi.var.stat$slope[multi.var.stat$flag_slope],
           pch = 1,
           cex = 3,
           col = "red")
    axis(side = 4,
         at = seq(range(multi.var.stat$slope, na.rm = T)[1],
                  range(multi.var.stat$slope, na.rm = T)[2],
                  length.out = 5),
         labels = round(seq(range(multi.var.stat$slope, na.rm = T)[1],
                            range(multi.var.stat$slope, na.rm = T)[2],
                            length.out = 5),
                        digits = 2),
         las = 1)
    mtext(side = 2,
          expression(Regression~R^{2}),
          line = 3)
    mtext(side = 4,
          expression(Regreesion~slope),
          line = 3)
    mtext(side = 1,
          "Year",
          line = 2.5)
    mtext(
      side = 3,
      paste("Years deviated:",
            paste(multi.var.stat$year[which(abs(multi.var.stat$slope.dev) > mslope.dev.threshold)],
                  collapse = "/")),
      adj = 0,
      cex = 0.7,
      line = 0.8,
      col = ifelse(any.error, "red", "grey")
    )
    mtext(
      side = 3,
      paste("Diff (%):",
            paste(
              round(multi.var.stat$slope.dev[which(abs(multi.var.stat$slope.dev) > mslope.dev.threshold)], digits = 3) * 100,
              collapse = "/"
            )),
      adj = 0,
      cex = 0.7,
      line = 0,
      col = ifelse(any.error, "red", "grey")
    )
    legend("topleft",
           legend = c("slope", "R2"),
           pch = 16,
           col = c(rgb(0.2, 0.2, 1, 0.7),
                   rgb(0.2, 1, 0.2, 0.7)),
           bty = "n")
    dev.off()

  }
  return(multi.var.stat)
}
