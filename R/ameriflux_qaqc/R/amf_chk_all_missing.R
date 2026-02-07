#' Title
#'
#' @param data.in
#'
#' @return
#' @export
#'
#' @examples
amf_chk_all_missing <- function(data.in) {
  name.ls <- colnames(data.in)
  all.na <- function(x) {
    ifelse(sum(is.na(x)) == length(x), T, F)
  }

  all.missing.ls <- name.ls[apply(data.in, 2, all.na)]
  return(all.missing.ls)
}
