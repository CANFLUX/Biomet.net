#' Title
#'
#' @param data
#' @param name
#' @param l.window
#' @param PAR.coefff
#' @param target.var
#' @param res
#' @param path.out
#' @param plot.always
#' @param night.buffer
#' @param day.threshold
#' @param night.threshold
#'
#' @return
#' @export
#'
#' @examples
amf_chk_timestamp_alignment <-
  function(data,
           name,
           l.window = 15,
           PAR.coefff,
           target.var,
           res = "HH",
           path.out,
           plot.always = T,
           night.buffer = 10,
           day.threshold = 0.04,
           night.threshold = 0.04) {

    d.hr <- ifelse(res == "HH", 48, 24)
    hr <- ifelse(res == "HH", 30, 60)

    TIMESTAMP_START.wrk <-
      strptime(data$TIMESTAMP_START, format = "%Y%m%d%H%M", tz = "UTC")
    TIMESTAMP.wrk <-
      strptime(TIMESTAMP_START.wrk + 0.5 * hr * 60,
               format = "%Y-%m-%d %H:%M:%S",
               tz = "UTC")
    data$HR <-  TIMESTAMP.wrk$hour +  TIMESTAMP.wrk$min / 60
    data$DOY <- (TIMESTAMP.wrk$yday + 1)

    # l.window in days
    l.window.wrk <-
      l.window * d.hr # convert days into half-hourly record
    l <- min(c(24, ceiling(nrow(data) / l.window.wrk)))

    get.ppfd <- grep("PPFD_IN", target.var)
    if (length(get.ppfd) > 0) {
      data[, target.var[get.ppfd]] <-
        data[, target.var[get.ppfd]] * PAR.coefff
    }

    data.t.all <- data.frame()
    ### preparing data
    for (i in 1:l) {
      if (i < l) {
        data.temp <-
          data[c(1:l.window.wrk) + (i - 1) * l.window.wrk, c("TIMESTAMP_START", "DOY", "HR", "SW_IN_POT", target.var)]
      } else{
        data.temp <-
          data[c((1 + (l - 1) * l.window.wrk):nrow(data)), c("TIMESTAMP_START", "DOY", "HR", "SW_IN_POT", target.var)]
      }

      data.t <- data.frame(
        TIMESTAMP_first = tapply(data.temp$TIMESTAMP_START, data.temp$HR, get.first),
        TIMESTAMP_last = tapply(data.temp$TIMESTAMP_START, data.temp$HR, get.last),
        DOY = tapply(data.temp$DOY, data.temp$HR, na.mean),
        HR = tapply(data.temp$HR, data.temp$HR, na.mean),
        SW_IN_POT = tapply(data.temp$SW_IN_POT, data.temp$HR, na.max)
      )

      for (i2 in 1:length(target.var)) {
        data.t$tmp <-
          tapply(data.temp[, target.var[i2]], data.temp$HR, na.max)
        data.t$tmp2 <- NA
        # daytime
        data.t$tmp2[data.t$SW_IN_POT > 0] <-
          (data.t$tmp[data.t$SW_IN_POT > 0] > data.t$SW_IN_POT[data.t$SW_IN_POT > 0])
        # nighttime
        data.t$tmp2[data.t$SW_IN_POT == 0] <-
          (data.t$tmp[data.t$SW_IN_POT == 0] > data.t$SW_IN_POT[data.t$SW_IN_POT == 0]) &
          (data.t$tmp[data.t$SW_IN_POT == 0] > night.buffer)

        colnames(data.t)[which(colnames(data.t) == "tmp")] <-
          target.var[i2]
        colnames(data.t)[which(colnames(data.t) == "tmp2")] <-
          paste0(target.var[i2], "_qc")

      }

      data.t.all <- rbind.data.frame(data.t.all,
                                     data.t)

    }

    ## separate by day/night excluding sunrise/sunset hours
    data.t.all$daynight <-
      ifelse(data.t.all$SW_IN_POT > 0, "day", "night")
    for (i3 in 2:(nrow(data.t.all) - 1)) {
      if ((data.t.all$SW_IN_POT[i3 - 1] == 0 &
           data.t.all$SW_IN_POT[i3] == 0 & data.t.all$SW_IN_POT[i3 + 1] > 0) |
          (data.t.all$SW_IN_POT[i3 - 1] > 0 &
           data.t.all$SW_IN_POT[i3] == 0 &
           data.t.all$SW_IN_POT[i3 + 1] == 0))
        data.t.all$daynight[c((i3 - 1):(i3 + 1))] <- "sunriseset"

    }

    ### Handling error compilation
    all.error.count.d <- list()
    all.error.count.n <- list()
    all.error.ccf <- list()
    all.error <- NULL
    for (i5 in 1:length(target.var)) {
      ## count flagged, divided by supposed length
      all.error.count.d[[i5]] <-
        round(sum(data.t.all[data.t.all$daynight == "day", paste0(target.var[i5], "_qc")], na.rm = TRUE) /
                length(data.t.all[data.t.all$daynight == "day", "SW_IN_POT"]),
              digits = 5)
      #sum(!is.na(data.t.all[data.t.all$daynight == "day", target.var[i5]])), digits = 3)
      all.error.count.n[[i5]] <-
        round(sum(data.t.all[data.t.all$daynight == "night", paste0(target.var[i5], "_qc")], na.rm = TRUE) /
                length(data.t.all[data.t.all$daynight == "night", "SW_IN_POT"]),
              digits = 5)
      #sum(!is.na(data.t.all[data.t.all$daynight == "night", target.var[i5]])), digits = 3)

      if (is.nan(all.error.count.n[[i5]]))
        all.error.count.n[[i5]] <- NA
      if (is.nan(all.error.count.d[[i5]]))
        all.error.count.d[[i5]] <- NA

      all.error <-
        c(
          all.error,
          all.error.count.d[[i5]] > day.threshold,
          all.error.count.n[[i5]] > night.threshold
        )

      if (sum(is.na(data.t.all[, target.var[i5]])) == 0) {
        target.ccf <-
          ccf(data.t.all$SW_IN_POT,
              data.t.all[, target.var[i5]],
              plot = FALSE,
              lag.max = d.hr / 2)
        max.ccf.loc = which.max(target.ccf$acf)
        max.ccf.lag = target.ccf$lag[max.ccf.loc]
        max.ccf = target.ccf$acf[max.ccf.loc]
        if(length(max.ccf.loc) == 1 &
           length(max.ccf.lag) == 1 &
           length(max.ccf) == 1){
          all.error.ccf[[i5]] <- data.frame(
            max.ccf.loc = max.ccf.loc,
            max.ccf.lag = max.ccf.lag,
            max.ccf = max.ccf
          )
          all.error <- c(all.error, max.ccf.lag != 0)
        } else {
          all.error.ccf[[i5]] <- data.frame(
            max.ccf.loc = NA,
            max.ccf.lag = NA,
            max.ccf = NA
          )
        }
      } else{
        all.error.ccf[[i5]] <- data.frame(
          max.ccf.loc = NA,
          max.ccf.lag = NA,
          max.ccf = NA
        )
      }
    }

    any.error <- (sum(all.error, na.rm = T) > 0)

    if (plot.always | any.error) {
      png(file.path(
         path.out,
         paste0(
               name,
               "_timeshift_check.png")),
        width = 9,
        height = 6,
        units = "in",
        res = 300
      )
      par(
        mar = c(0, 0, 0, 0),
        oma = c(4.5, 5.5, 4.5, 2.5),
        mfrow = c(4, 6)
      )

      for (i in 1:l) {
        data.t <- data.t.all[data.t.all$DOY == unique(data.t.all$DOY)[i],]
        plot(
          data.t$HR,
          data.t$SW_IN_POT,
          type = "l",
          xaxt = "n",
          yaxt = "n",
          ylab = "",
          xlim = c(0, 24),
          ylim = c(-50, max(data$SW_IN_POT, na.rm = T) * 1.2),
          col = "black"
        )

        for (i3 in 1:length(target.var)) {
          points(
            data.t$HR,
            data.t[, target.var[i3]],
            type = "b",
            pch = 21,
            cex = 0.8,
            col = "black",
            bg = rainbow(7)[i3]
          )
          points(
            data.t$HR[data.t[, target.var[i3]] > data.t$SW_IN_POT],
            data.t[, target.var[i3]][data.t[, target.var[i3]] > data.t$SW_IN_POT],
            type = "p",
            pch = 1,
            col = rainbow(7)[i3],
            cex = 2
          )
        }

        text(
          12,
          max(data$SW_IN_POT, na.rm = T) * 1.2,
          paste0(
            substr(data.t$TIMESTAMP_first[1], 5, 8),
            "~",
            substr(data.t$TIMESTAMP_last[nrow(data.t)], 5, 8)
          ),
          adj = c(0.5, 1)
        )

        if (i == 1) {
          mtext(
            side = 2,
            expression(Radiation ~ (W ~ m ^ {
              -2
            })),
            outer = T,
            line = 3
          )

          mtext(side = 3,
                name,
                outer = T,
                line = 0.5)
        }

        if (floor((i - 1) / 6) * 6 == i - 1) {
          axis(side = 2,
               at = seq(0, 1200, 200),
               las = 2)
        }

        if (i >= (l - 5) & nrow(data.t) == d.hr) {
          axis(
            side = 1,
            at = data.t$HR[seq(0, d.hr, length.out = 7)],
            labels = c(4, 8, 12, 16, 20, 24),
            cex.axis = 0.9
          )
        }
      }

      mtext(
        side = 1,
        "HOUR",
        line = 2.5,
        outer = T,
        font = 2
      )

      for (i4 in 1:length(target.var)) {
        ## calculate percentage above SW_IN_POT
        mtext(
          side = 3,
          adj = 1,
          line = (i4 - 1) + 0.5,
          paste(
            target.var[i4],
            "has",
            all.error.count.d[[i4]] * 100,
            "/",
            all.error.count.n[[i4]] * 100,
            "% above SW_IN_POT day/nighttime"
          ),
          outer = TRUE,
          cex = 0.7,
          col = ifelse(
            all.error.count.d[[i4]] > day.threshold |
              all.error.count.n[[i4]] > night.threshold,
            "red",
            "black"
          )
        )

        ## calculate cross-correlation
        if (!is.na(all.error.ccf[[i4]]$max.ccf.lag)) {
          if (nrow(all.error.ccf[[i4]]) == 1) {
            mtext(
              side = 3,
              adj = 0,
              line = (i4 - 1) + 0.5,
              paste(
                target.var[i4],
                "has max corr",
                all.error.ccf[[i4]]$max.ccf,
                "at lag",
                all.error.ccf[[i4]]$max.ccf.lag
              ),
              outer = TRUE,
              cex = 0.7,
              col = ifelse(all.error.ccf[[i4]]$max.ccf.lag == 0, "black", "red")
            )

          } else{
            mtext(
              side = 3,
              adj = 0,
              line = (i4 - 1) + 0.5,
              paste(target.var[i4], "can't find max corr"),
              outer = TRUE,
              cex = 0.7
            )
          }
        } else{
          mtext(
            side = 3,
            adj = 0,
            line = (i4 - 1) + 0.5,
            paste(target.var[i4], "can't calculate cross-correlation"),
            outer = TRUE,
            cex = 0.7
          )
        }
      }
      dev.off()
    }

    return(
      list(
        data.t.all = data.t.all,
        any.error = any.error,
        all.error.count.d = all.error.count.d,
        all.error.count.n = all.error.count.n,
        all.error.ccf = all.error.ccf
      )
    )
  }
