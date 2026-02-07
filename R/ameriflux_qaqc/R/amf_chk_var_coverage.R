#' Variable Coverage Check
#'
#' @description
#' The function examines the presence and coverage of all variables at a site.
#' The generated figure provides a quick overview of the available variables
#' and their data coverage for each year of the entire record. The figure can
#' be used to examine whether the data in certain years are entirely missing
#' (e.g., inactive years), certain variables are missing for specific periods
#' (e.g., not measured), or certain variables are entirely missing (e.g., all
#' empty columns). For long-running and heavily-instrumented sites, the figure
#'  can be used to verify the presence and continuity of variables across the
#'  entire record.
#'
#' @param site A string of AmeriFlux Site ID (CC-Sss), only used for output
#' naming/figure title.
#' @param data.in A data frame with all variables, excluding TIMESTAMP_START &
#' TIMESTAMP_END columns.
#' @param TIMESTAMP A POSIXlt (time series format) vector, covering the same
#' time duration as data.in, which is used to parse the time information.
#' @param year.i first year of output table
#' @param year.f last year of output table
#' @param path.out Output directory
#' @param res Temporal resolution in data (character), e.g., "HH" or "HR"
#' @param file.ver Free text (character), only used for output naming
#' @param plot.always Whether plot figures always (True/False).
#'
#' @return A list of the following two objects, and a PNG figure saved to the
#' designated *path.out* directory (if plot.always = T), with a file name of
#' {site}\-{file.ver}\_var_year_available.png
#' \itemize{
#'   \item var.year: A vector of years that the data cover (numeric).
#'   \item var.year2: A data frame of variable coverage
#'     \itemize{
#'     \item site: AmeriFlux Site ID (CC-Sss)
#'     \item year: Year (numeric)
#'     \item data.N: Number of time steps in the data record (numeric)
#'     \item data.N.full: Number of time steps in a full calender year (numeric)
#'     \item full.year: Whether the file contain all time steps in a full
#'     calender year (True/False).
#'     \item VARIABLE 1: Data coverage (ratio) of Variable 1
#'     \item VARIABLE 2: Data coverage (ratio) of Variable 2
#'     \item ...
#'     }
#' }
#'
#' @examples
#'
amf_chk_var_coverage <-
  function(site,
           data.in,
           TIMESTAMP,
           year.i = 1990,
           year.f,
           path.out,
           res,
           #file.ver,
           plot.always = T)

  {

    # Number of data points per day
    d.hr <- ifelse(res == "HH", 48, 24)

    ## A data frame for variable-specific data availability for every year
    var.year <- data.frame(
      site = paste(site),
      year = as.numeric(names(table(TIMESTAMP$year + 1900))),
      data.N = as.numeric(table(TIMESTAMP$year + 1900)),
      data.N.full = NA,
      full.year = NA
    )

    # supposed data points in each year, depending on res & leap/non-leap year
    var.year$data.N.full <-
      ifelse(is.wholenumber((var.year$year - 1900) / 4), 366 * d.hr, 365 * d.hr)

    # logic (TRUE/FALSE), whether actual data number matches the supposed number
    var.year$full.year <-
      ifelse(var.year$data.N == var.year$data.N.full, T, F)

    # a year index, only for working
    yr.full <- TIMESTAMP$year + 1900

    # a list of variable names in the data file
    var.ls <- sort(colnames(data.in))

    ## loop through all variables in data.in, calculate the percentage of
    #  non-missing data for each year (data availability)
    #  add the data availability of all variables back to var.year
    for (i in 1:length(var.ls)) {
      var.year <- cbind(var.year,
                        tmp.in = tapply(data.in[, var.ls[i]],
                                        yr.full,
                                        sum.notna))

      var.year$tmp.in <- var.year$tmp.in / var.year$data.N.full

      colnames(var.year)[ncol(var.year)] <- paste(var.ls[i])
    }

    ## store var.year in a separate format
    var.year2 <-
      data.frame(
        SITE_ID = rep(paste(site), length(var.ls)),
        VARIABLE = colnames(var.year)[c(6:ncol(var.year))],
        matrix(
          0,
          nrow = length(var.ls),
          ncol = (year.f - year.i + 1)
        )
      )
    colnames(var.year2) <- c("SITE_ID", "VARIABLE",
                             paste0("Y", c(year.i:year.f)))

    for (j in 1:nrow(var.year)) {
      var.year2[, which(colnames(var.year2) == paste0("Y", var.year$year[j]))] <-
        t(var.year[j, c(6:ncol(var.year))])
    }

    if(plot.always){
      ### Prepare the output figure
      png(file.path(path.out, paste(site, "-", #file.ver,
                "_var_year_available.png", sep = "")),
          width = 4 + 0.25 * nrow(var.year),
          height = 3 + 0.2 * length(var.ls),
          units = "in",
          res = 200
      )

      par(mar = c(4.5, 10, 2, 0.5))

      # plotting the heat map for per-variable-year data availability
      image(
        var.year$year,
        c(1:length(var.ls)),
        as.matrix(var.year[, which(colnames(var.year) ==
                                     var.ls[1]):ncol(var.year)]),
        col = c("white", rev(colorspace::sequential_hcl(99, h = 255, c = 96))),
        ylab = "",
        xlab = "Year",
        yaxt = "n"
      )

      # add data percentage on top of heatmap, except all-empty variable years
      for (j in 1:length(var.year$year)) {
        non.zero <-
          which(var.year[j, which(colnames(var.year) == var.ls[1]):ncol(var.year)] >
                  0)

        if (length(non.zero) > 0) {
          text(
            var.year$year[j],
            c(1:length(var.ls))[non.zero],
            ceiling(100 * var.year[j, which(colnames(var.year) ==
                                              var.ls[1]):ncol(var.year)])[non.zero],
            cex = 0.5,
            adj = c(0.5, 0.5)
          )
        }
      }

      axis(
        side = 2,
        at = c(1:length(var.ls)),
        labels = var.ls,
        las = 1,
        cex.axis = 0.8
      )
      mtext(
        side = 3,
        paste(site),
        font = 2,
        cex = 1.5,
        adj = 0
      )
      mtext(
        side = 3,
        "data availability (%)",
        font = 2,
        cex = 1,
        adj = 1
      )
      dev.off()
      ### End of the output figure
    }

    return(list(var.year, var.year2))
  }
