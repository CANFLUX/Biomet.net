#' Configuration for QA/QC checks
#'
#' @description
#' This function define the configuration parameters to control the QA/QC runs
#' and checks. The default values are used for common AmeriFlux QA/QC.
#'
#' @param hr_sites AmeriFlux sites known with hourly resolution (CC-Sss).
#' @param min.data.to.check Minimum acceptable data ratio to perform checks
#' for a year (numeric).
#' @param threshold.ver Version of the diurnal-seasonal historical ranges.
#' Currently, it reflects the last creation date (YYYYMMDD).
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
#' @param hard.flag.threshold Fail threshold for physical range check (numeric).
#' Fail if more than this ratio of data points outside the expected physical
#' range plus buffer range.
#' @param soft.flag.threshold Warning threshold for physical range check
#' (numeric). Warning if more than this ratio of data points outside the
#' expected physical range but within the buffer range, except for those listed
#' in *loosen.var*.
#' @param buffer.precentage A buffer ratio for physical range check (numeric).
#'  A ±5% (default) buffer is applied to account for possible edge values near
#'  the lower and upper bounds, commonly observed for radiation variables,
#'  relative humidity, and snow depth.
#' @param wslope.dev.threshold Warning threshold for wind sigma check (numeric).
#' Warning if the W_SIGMA-USTAR regression slope deviates more than this ratio
#' from the reported model, i.e., 1.25 (Kaimal et al., 1994).
#' @param ustar.low.threshold1 Warning threshold for the USTAR filtering check
#' (numeric). Warning if annual minimum USTAR is larger than this ratio.
#' @param ustar.diff.threshold1 Warning threshold for the USTAR filtering check
#' (numeric). Warning if annual minimum USTAR when FC is not missing is larger
#' than this ratio.
#' @param ustar.low.threshold2 Fail threshold for the USTAR filtering check
#' (numeric). Fail if annual minimum USTAR is larger than this ratio.
#' @param ustar.diff.threshold2 Fail threshold for the USTAR filtering check
#' (numeric). Fail if the difference between the annual minimum USTAR when FC
#' is not missing and annual minimum USTAR is larger than this ratio.
#' @param night.buffer A buffer radiation threshold (W m-2) to flag nighttime
#' radiation for the timestamp alignment check (numeric).
#' @param day.threshold Warning/Fail threshold for the timestamp alignment check
#' (numeric). Warning if there are flagged points in the daytime below this
#' ratio. Fail if flagged points in the daytime exceed this ratio.
#' @param night.threshold Warning/Fail threshold for the timestamp alignment
#' check (numeric). Warning if there are flagged points in the nighttime below
#' this ratio. Fail if flagged points in the nighttime exceed this ratio.
#' @param multi.var.pair A list of two vectors (character), containing the
#' target variable pairs for the multivariate check.
#' @param multi.var.pair.unit A list of two vectors (character), containing the
#' units of the target variable pairs for the multivariate check.
#' @param rsquare.threshold A vector of Warning thresholds for the multivariate
#' check (numeric). The length/order of this vector matches the ones in
#' *multi.var.pair*. Warning if the regression R2 of a multivariate check falls
#' below this threshold.
#' @param outlier.threshold Warning threshold for the multivariate check
#' (numeric). Warning if the ratio of data points flagged based on the distance
#' to the regression line exceeds this threshold. Also see *outlier.dev.threshold*
#' @param outlier.dev.threshold Threshold to flag points for multivariate check
#' (numeric). Flagged if a point deviates more than this threshold \* standard
#' deviation of all points orthogonal distances to the regression line.
#' @param mslope.dev.threshold Warning threshold for the multivariate check
#' (numeric). Warning if a year regression slope deviates more than this ratio
#' to the multi-year mean, but below *mslope.dev.threshold2*.
#' @param mslope.dev.threshold2 Fail threshold for the multivariate check
#' (numeric). Fail if a year regression slope deviates more than this ratio
#' to the multi-year mean.
#' @param min.year.multivarite Minimum years of data records to run slope
#' deviation check for the multivariate check (numeric).
#' @param mad.var Mandatory variable list (character).
#' @param mad.opt.var Alternative variable pair for the mandatory variables
#' (character).
#' @param opt.var Optional variable (character).
#' @param l.wd Number of days to aggregate for the diurnal-seasonal check
#' (numeric), i.e., default = 30 days.
#' @param n.wd Number of aggregated windows for the diurnal-seasonal check
#' (numeric), i.e., default = floor(365 / l.wd).
#' @param loosen.var A vector of variables to ignore soft-flag warning for the
#' physical range check (character). These variables are known for
#' commonly-observed values near or slightly beyond the lower and upper bounds,
#' so the Warning for these variables is turned off.
#' @param sign.var.ls A vector of variables to run sign convention check
#' (character).
#' @param unit.var.ls A vector of variables to run unit check (character).
#' @param unit.var.scale.ls A vector of scaling ratios to run unit check
#' (numeric).
#' @param na.alias A list of commonly-seen alias for the missing values
#' (character).
#'
#' @return A list of config
#' @export
#'
#' @examples
amf_qaqc_config <- function(hr_sites = c("BR-Sa1", "US-MMS", "US-Ha1",
                                         "US-Cop", "US-Ne1", "US-Ne2",
                                         "US-Ne3", "US-PFa", "US-Cwt"),
                            min.data.to.check = 0.1,
                            threshold.ver = 20240109,
                            Q1Q3.threshold = 15,
                            Q95.threshold = 70,
                            Q1Q3.threshold2 = 30,
                            Q95.threshold2 = 85,
                            hard.flag.threshold = 0.001,
                            soft.flag.threshold = 0.01,
                            buffer.precentage = 0.05,
                            wslope.dev.threshold = 0.2,
                            ustar.low.threshold1 = 0.02,
                            ustar.diff.threshold1 = 0.02,
                            ustar.low.threshold2 = 0.1,
                            ustar.diff.threshold2 = 0.1,
                            night.buffer = 10,
                            day.threshold = c(0.048, 0.111),
                            night.threshold = c(0.048, 0.111),
                            multi.var.pair = list(
                              c("PPFD_IN", "WS", "TA"),
                              c("SW_IN", "USTAR", "T_SONIC")
                              ),
                            multi.var.pair.unit = list(
                              c(expression(mu * mol ~ m ^ { -2 } ~ s ^ { -1 }),
                                expression(m ~ s ^ { -1 }),
                                expression(degree * C)
                              ),
                              c(expression(W ~ m ^ { -2 }),
                                expression(m ~ s ^ { -1 }),
                                expression(degree * C))
                            ),
                            rsquare.threshold = c(0.7, 0.5, 0.7),
                            outlier.threshold = 0.01,
                            outlier.dev.threshold = 4.5,
                            mslope.dev.threshold = 0.1,
                            mslope.dev.threshold2 = 0.2,
                            min.year.multivarite = 3,
                            mad.var = c(
                              "FC",
                              "H",
                              "LE",
                              "WS",
                              "USTAR",
                              "TA",
                              "PA"
                              ),
                            mad.opt.var = list(
                              c("CO2", "SC"),
                              c("SW_IN", "PPFD_IN"),
                              c("RH", "H2O", "VPD")
                              ),
                            opt.var = c("G", "NETRAD", "LW_IN", "P", "SWC", "TS"),
                            l.wd = 30,
                            n.wd = floor(365 / l.wd),
                            loosen.var = c(
                              "SW_IN",
                              "SW_OUT",
                              "SW_BC_IN",
                              "SW_BC_OUT",
                              "PPFD_IN",
                              "PPFD_OUT",
                              "PPFD_BC_IN",
                              "PPFD_BC_OUT",
                              "SW_DIF",
                              "SW_DIR",
                              "PPFD_DIF",
                              "PPFD_DIR",
                              "D_SNOW",
                              "PPFD_UW_IN"
                            ),
                            sign.var.ls = list(
                              var = c("TAU", "G", "GPP", "RECO", "NETRAD",
                                      "SC", "SLE", "SH", "SG"),
                              sign = c("neg", NA, "pos", "pos", "pos",
                                       NA, NA, NA, NA),
                              prototype = c(F, T, F, F, T,
                                            T, T, T, T)
                            ),
                            unit.var.ls = c("VPD", "CH4", "FCH4", "D_SNOW"),
                            unit.var.scale.ls = c(10, 1000, 1000, 100),
                            na.alias = c("-9999", "-9999.0", "-9999.00",
                                         "-9999.000", "-9999.0000")) {


  # loosen soft flag thresholds for radiation & percentage variable
  FP_ls <- amerifluxr::amf_variables()
  FP_per_ls <- FP_ls[FP_ls$Units == "%", "Name"]
  loosen.var <- c(loosen.var,
                  FP_per_ls)

  amf_cfg <- list(hr_sites = hr_sites,
                  min.data.to.check = min.data.to.check,
                  threshold.ver = threshold.ver,
                  Q1Q3.threshold = Q1Q3.threshold,
                  Q95.threshold = Q95.threshold,
                  Q1Q3.threshold2 = Q1Q3.threshold2,
                  Q95.threshold2 = Q95.threshold2,
                  hard.flag.threshold = hard.flag.threshold,
                  soft.flag.threshold = soft.flag.threshold,
                  buffer.precentage = buffer.precentage,
                  wslope.dev.threshold = wslope.dev.threshold,
                  ustar.low.threshold1 = ustar.low.threshold1,
                  ustar.diff.threshold1 = ustar.diff.threshold1,
                  ustar.low.threshold2 = ustar.low.threshold2,
                  ustar.diff.threshold2 = ustar.diff.threshold2,
                  night.buffer = night.buffer,
                  day.threshold = day.threshold,
                  night.threshold = night.threshold,
                  multi.var.pair = multi.var.pair,
                  multi.var.pair.unit = multi.var.pair.unit,
                  rsquare.threshold = rsquare.threshold,
                  outlier.threshold = outlier.threshold,
                  outlier.dev.threshold = outlier.dev.threshold,
                  mslope.dev.threshold = mslope.dev.threshold,
                  mslope.dev.threshold2 = mslope.dev.threshold2,
                  min.year.multivarite = min.year.multivarite,
                  mad.var = mad.var,
                  mad.opt.var = mad.opt.var,
                  opt.var = opt.var,
                  l.wd = l.wd,
                  n.wd = n.wd,
                  loosen.var = loosen.var,
                  sign.var.ls = sign.var.ls,
                  unit.var.ls = unit.var.ls,
                  unit.var.scale.ls = unit.var.scale.ls,
                  loosen.var = loosen.var,
                  FP_per_ls = FP_per_ls,
                  na.alias = na.alias)

  return(amf_cfg)
}


#' Obtain AmeriFlux site UTC offset
#'
#' @param site_id AmeriFlux 6 digit ID
#'
#' @return UTC offset in hours
#' @export
#'
#' @examples
amf_get_utc <- function(site_id){

  base_url <- "https://amfcdn.lbl.gov/"
  api_url <- file.path(base_url, "api/v1")
  url <- file.path(api_url, "BADM/data/")
  utc <-
    as.numeric(jsonlite::fromJSON(paste0(url, "/", site_id, "/Site_General_Info"),
                                  flatten = TRUE)[["UTC_OFFSET"]][[1]]$UTC_OFFSET)

  return(utc)
}
