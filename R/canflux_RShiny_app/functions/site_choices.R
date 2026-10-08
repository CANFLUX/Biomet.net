# Choices and default selections for every selector of the site explorer
# 2026 (moved out of app.R so tests/smoke_test.R can use it)
#
# Current selections are kept when the new site has the same variable, so
# switching sites keeps you on the same variable when possible.

site_choices <- function(obj, current = list()) {
  vars <- obj$vars
  pick <- function(choices, cur, prefs) {
    if (!length(choices)) return(character(0))
    if (!is.null(cur) && cur %in% choices) return(cur)
    hit <- intersect(prefs, choices)
    if (length(hit)) hit[1] else choices[1]
  }
  groups <- unique(gsub("_[[:digit:]]", "", vars))
  desc <- obj$units$description[match(groups, gsub("_[[:digit:]]", "", obj$units$name))]
  desc <- ifelse(is.na(desc) | !nzchar(desc), "", paste0(" \u00b7 ", substr(desc, 1, 42)))
  grp_desc <- paste0(groups,desc)
  grp_desc <- strtrim(grp_desc,width=40)
  grp_desc_len <- nchar(grp_desc)
  grp_desc_idx <- grp_desc_len==40
  grp_desc[grp_desc_idx] <- paste0(grp_desc[grp_desc_idx],"...")
  desc <- unlist(Map(gsub, groups, "", grp_desc))
  ts_choices <- stats::setNames(groups, paste0(groups, desc))
  rad <- intersect(var_rad, vars)
  ae <- grep("^AE_", vars, value = TRUE)
  hle <- grep("H_LE", vars, value = TRUE)
  years <- as.character(obj$years)
  list(
    ts_var  = list(choices = ts_choices, selected = pick(groups, current$ts_var, c("TA", "FC", "LE"))),
    sc_x    = list(choices = vars, selected = pick(vars, current$sc_x, c("SW_IN_1_1_1", vars[1]))),
    sc_y    = list(choices = vars, selected = pick(vars, current$sc_y, c("PPFD_IN_1_1_1", vars[2]))),
    di_var  = list(choices = vars, selected = pick(vars, current$di_var, c("FC", "TA_1_1_1", "LE"))),
    rad_var = list(choices = rad, selected = pick(rad, current$rad_var, var_rad)),
    rad_year = list(choices = years, selected = pick(years, current$rad_year, rev(years))),
    ebc_x   = list(choices = ae, selected = pick(ae, current$ebc_x, ae)),
    ebc_y   = list(choices = hle, selected = pick(hle, current$ebc_y, "H_LE"))
  )
}
