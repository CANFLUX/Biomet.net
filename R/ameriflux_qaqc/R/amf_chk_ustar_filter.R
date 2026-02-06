#' Title
#'
#' @param ustar_data
#' @param ustar_name
#' @param fc_data
#' @param fc_name
#' @param radiation_data
#' @param radiation_threshold
#' @param year
#' @param ustar.low.threshold1
#' @param ustar.low.threshold2
#' @param ustar.diff.threshold1
#' @param ustar.diff.threshold2
#'
#' @return
#' @export
#'
#' @examples
amf_chk_ustar_filter <- function(ustar_data,
                                 ustar_name,
                                 fc_data,
                                 fc_name,
                                 radiation_data,
                                 radiation_threshold,
                                 year,
                                 ustar.low.threshold1,
                                 ustar.low.threshold2,
                                 ustar.diff.threshold1,
                                 ustar.diff.threshold2) {
  get.ustar.low.d <-
    round(min(ustar_data[which(radiation_data > radiation_threshold)],
              na.rm = T), digits = 3)
  get.ustar.low.n <-
    round(min(ustar_data[which(radiation_data <= radiation_threshold)],
              na.rm = T), digits = 3)
  get.ustar.fc.low.d <-
    round(min(ustar_data[which(radiation_data > radiation_threshold &
                                 !is.na(fc_data))], na.rm = T), digits = 3)
  get.ustar.fc.low.n <-
    round(min(ustar_data[which(radiation_data <= radiation_threshold &
                                 !is.na(fc_data))], na.rm = T), digits = 3)

  ustar.stat <- data.frame(
    year = year,
    fc_var = fc_name,
    ustar_var = ustar_name,
    day_min_ustar = get.ustar.low.d,
    day_min_ustar_fc = get.ustar.fc.low.d,
    night_min_ustar = get.ustar.low.n,
    night_min_ustar_fc = get.ustar.fc.low.n,
    status = "ok"
  )

  if (get.ustar.low.d > ustar.low.threshold1 |
      get.ustar.fc.low.d > ustar.low.threshold1 |
      get.ustar.fc.low.d - get.ustar.low.d > ustar.diff.threshold1) {
    print(
      paste(
        "[warning] Daytime",
        fc_name,
        "potenially filtered by",
        ustar_name,
        get.ustar.low.d,
        "/",
        get.ustar.fc.low.d,
        year
      )
    )
    ustar.stat$status <- "warning"
  }

  if (get.ustar.low.n > ustar.low.threshold1 |
      get.ustar.fc.low.n > ustar.low.threshold1 |
      get.ustar.fc.low.n - get.ustar.low.n > ustar.diff.threshold1) {
    print(
      paste(
        "[warning] Nighttime",
        fc_name,
        "potenially filtered by",
        fc_name,
        get.ustar.low.n,
        "/",
        get.ustar.fc.low.n,
        year
      )
    )
    ustar.stat$status <- "warning"
  }

  if (get.ustar.low.d > ustar.low.threshold2 |
      get.ustar.fc.low.d > ustar.low.threshold2 |
      get.ustar.fc.low.d - get.ustar.low.d > ustar.diff.threshold2) {
    print(
      paste(
        "[error] Daytime",
        fc_name,
        "filtered by",
        fc_name,
        get.ustar.low.d,
        "/",
        get.ustar.fc.low.d,
        year
      )
    )
    ustar.stat$status <- "error"
  }

  if (get.ustar.low.n > ustar.low.threshold2 |
      get.ustar.fc.low.n > ustar.low.threshold2 |
      get.ustar.fc.low.n - get.ustar.low.n > ustar.diff.threshold2) {
    print(
      paste(
        "[error] Nighttime",
        fc_name,
        "filtered by",
        fc_name,
        get.ustar.low.n,
        "/",
        get.ustar.fc.low.n,
        year
      )
    )
    ustar.stat$status <- "error"
  }

  return(ustar.stat)
}
