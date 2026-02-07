#' Title
#'
#' @param x
#'
#' @return
#' @export
#'
#' @examples
amf_chk_constant <- function(x) {
  ls.summary <- summary(as.numeric(x))
  all.constant <-
    ifelse(
      ls.summary[1] == ls.summary[2] &
        ls.summary[2] == ls.summary[3] &
        ls.summary[3] == ls.summary[4] &
        ls.summary[4] == ls.summary[5],
      TRUE,
      FALSE
    )
  return(all.constant)
}
