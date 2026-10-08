# ------------------------------------------------------------------
# Smoke test: run the app's server logic against the real database,
# for every site and every tab, without a browser.
#
# Run from the app folder (the same folder as app.R):
#   Rscript tests/smoke_test.R
# Optional: test another database copy first
#   CARBONIQUE_DB=/path/to/database Rscript tests/smoke_test.R
#
# Prints how long each site takes to read and render, then a summary.
# Exit status is 1 if anything failed, so it can gate a deployment.
# ------------------------------------------------------------------
suppressPackageStartupMessages(library(shiny))
if (!file.exists("app.R")) stop("Run this from the app folder (where app.R is).")

outputs_site <- c("site_stats", "site_meta", "ts_plot", "sc_plot", "sc_fit", "di_plot",
                  "rad_plot", "rad_ccf", "ebc_plot", "ebc_fit", "cum_controls", "cum_plot")
failures <- character(0)
timing <- data.frame(site = character(), step = character(), seconds = numeric())

t_start <- Sys.time()
testServer(shinyAppDir("."), {
  sites <- available_sites()
  if (!length(sites)) stop("No sites found under ", main_dir)
  cat(sprintf("Database: %s\nSites: %s\n\n", main_dir, paste(sites, collapse = ", ")))

  for (s in sites) {
    t0 <- Sys.time()
    obj <- get_site_data(s)
    cat(sprintf("%-10s %d time steps, %d variables, opened in %.2f s (last record %s)\n",
                s, length(obj$datetime), length(obj$vars),
                as.numeric(difftime(Sys.time(), t0, units = "secs")), format(obj$last)))
    for (e in obj$cat$years) if (length(e$override$vars)) {
      cat(sprintf("%-10s %s, from %s: %s\n", "", e$year, e$override$folder,
                  paste(names(e$override$vars), collapse = ", ")))
    }
    ch <- site_choices(obj)
    for (lang in c("en", "fr")) {
      t1 <- Sys.time()
      session$setInputs(lang = lang, site = s, nav = "site", site_tab = "rad", period = "all",
                        ts_res = "30min", sc_outliers = TRUE, ebc_outliers = FALSE,
                        ts_var = ch$ts_var$selected, sc_x = ch$sc_x$selected, sc_y = ch$sc_y$selected,
                        di_var = ch$di_var$selected, rad_var = ch$rad_var$selected,
                        rad_year = ch$rad_year$selected, ebc_x = ch$ebc_x$selected,
                        ebc_y = ch$ebc_y$selected, cum_var = cumulative_vars(s)[1])
      for (o in outputs_site) {
        res <- tryCatch({ force(output[[o]]); "ok" }, error = function(e) conditionMessage(e))
        if (!identical(res, "ok") && nzchar(res)) {
          failures <<- c(failures, sprintf("%s / %s / %s: %s", s, lang, o, res))
        }
      }
      timing[nrow(timing) + 1, ] <<- list(s, paste("all tabs,", lang),
                                          as.numeric(difftime(Sys.time(), t1, units = "secs")))
    }
    # zoom in and back out on the time series (server sends the detail)
    zoom <- tryCatch({
      session$setInputs(ts_plot_xrange = list(from = format(obj$last - 20 * 86400, "%Y-%m-%d %H:%M:%S"),
                                              to = format(obj$last, "%Y-%m-%d %H:%M:%S")))
      session$setInputs(ts_plot_xrange = list(reset = TRUE)); "ok"
    }, error = function(e) conditionMessage(e))
    if (!identical(zoom, "ok")) failures <<- c(failures, sprintf("%s / zoom: %s", s, zoom))
    # a shorter period and daily means
    session$setInputs(period = "30d", ts_res = "daily")
    for (o in c("ts_plot", "di_plot", "sc_plot")) {
      res <- tryCatch({ force(output[[o]]); "ok" }, error = function(e) conditionMessage(e))
      if (!identical(res, "ok") && nzchar(res)) failures <<- c(failures, sprintf("%s / 30 days / %s: %s", s, o, res))
    }
    session$setInputs(period = "all", ts_res = "30min")
  }

  # All sites page: every resolution and layout, time view and x-y view
  for (xv in c("datetime", "NETRAD")) for (lay in c("panels", "overlay")) for (res_ in c("daily", "monthly", "30min")) {
    t1 <- Sys.time()
    session$setInputs(nav = "all", xcol_all = xv, ycol_all = if (xv == "datetime") "TA" else "LE",
                      all_res = res_, all_layout = lay, all_sites = sites)
    res <- tryCatch({ force(output$all_plot); "ok" }, error = function(e) conditionMessage(e))
    timing[nrow(timing) + 1, ] <<- list("all sites", paste(xv, lay, res_),
                                        as.numeric(difftime(Sys.time(), t1, units = "secs")))
    if (!identical(res, "ok") && nzchar(res)) failures <<- c(failures, sprintf("all sites / %s %s %s: %s", xv, lay, res_, res))
  }
  session$setInputs(xcol_all = "datetime", ycol_all = "TA", all_res = "30min", all_layout = "panels")
  zoom <- tryCatch({
    session$setInputs(all_plot_xrange = list(from = "2025-06-01 00:00:00", to = "2025-06-20 00:00:00"))
    session$setInputs(all_plot_xrange = list(reset = TRUE)); "ok"
  }, error = function(e) conditionMessage(e))
  if (!identical(zoom, "ok")) failures <<- c(failures, sprintf("all sites / zoom: %s", zoom))
})

cat("\nRender time (server side, all outputs of each step):\n")
print(timing, row.names = FALSE, digits = 2)
cat(sprintf("\nTotal time: %.1f s\n", as.numeric(difftime(Sys.time(), t_start, units = "secs"))))
if (length(failures)) {
  cat("\nFAILED:\n", paste0("  ", failures, collapse = "\n"), "\n", sep = "")
  quit(status = 1)
} else {
  cat("\nAll outputs rendered without errors.\n")
}
