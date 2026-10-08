# Fast, cached access to the binary database
# David Trejo Cancino, 2026
#
# Each variable is read from disk only when a plot needs it, then kept in
# memory until the site's files change. Opening a site therefore touches a
# handful of files (time vectors, a few variables) instead of every file in
# the level folder, which matters most on network drives (e.g. W:), where each
# file costs tens of milliseconds whatever its size.
#
# Nothing is written to the app folder.

.cq_cache <- new.env(parent = emptyenv())
.cq_cache$sites <- list()

# Files in a level folder that are not data series (same rules as before)
skip_file_regex <- paste(c("\\.txt$", "\\.csv$", "\\.ya?ml$", "\\.mat$", "\\.json$",
                           "clean_tv", "Clean_tv", "DateTime", "TimeVector",
                           "Clean", "clean", "Manual", "NARR", "badWD"), collapse = "|")

# Every file operation goes through .io(), which counts it. For testing, an
# artificial delay per operation can be set to mimic a slow network drive:
#   Sys.setenv(CARBONIQUE_IO_DELAY = "0.03")
.io <- function(n = 1) {
  .cq_cache$io_ops <- (.cq_cache$io_ops %||% 0) + n
  d <- suppressWarnings(as.numeric(Sys.getenv("CARBONIQUE_IO_DELAY", "0")))
  if (!is.na(d) && d > 0) Sys.sleep(d * n)
}
io_ops <- function() .cq_cache$io_ops %||% 0

# 1. Which sites and years exist --------------------------------------------
discover_sites <- function(main_dir, level, site_pattern) {
  empty <- data.frame(site = character(), year = character(), stringsAsFactors = FALSE)
  .io(); if (!dir.exists(main_dir)) return(empty)
  .io(); years <- list.dirs(main_dir, full.names = FALSE, recursive = FALSE)
  years <- sort(years[grepl("^(19|20)\\d{2}$", years)])
  rows <- lapply(years, function(y) {
    .io(); s <- list.dirs(file.path(main_dir, y), full.names = FALSE, recursive = FALSE)
    # Commented out (P.Moore) -- no need to filter UQAM_0
    #s <- s[grepl(site_pattern, s)]
    if (!length(s)) return(NULL)
    data.frame(site = s, year = y, stringsAsFactors = FALSE)
  })
  db <- do.call(rbind, c(list(empty), rows))
  .io(nrow(db))
  db[dir.exists(file.path(main_dir, db$year, db$site, level[1])), , drop = FALSE]
}

database_index <- function(force = FALSE) {
  stale <- is.null(.cq_cache$index) ||
    difftime(Sys.time(), .cq_cache$index_time, units = "mins") > refresh_minutes
  if (force || stale) {
    .cq_cache$index <- discover_sites(main_dir, level, site_pattern)
    .cq_cache$index_time <- Sys.time()
  }
  .cq_cache$index
}

available_sites <- function() {
  s <- unique(database_index()$site)
  s[order(sub("_\\d+$", "", s), suppressWarnings(as.integer(sub("^.*_", "", s))))]
}

site_years <- function(site) sort(database_index()$year[database_index()$site == site])

# 2. Catalog of one site: time vector and variable files, per year ----------
# Cost: one listing per year and level, plus reading the time vectors.
# The catalog is re-checked at most every `recheck_seconds`, by looking only at
# the time vector files (the cleaning pipeline rewrites them on every run).
list_level_files <- function(p) {
  .io(); f <- list.files(p)
  if (!length(f)) return(character(0))
  .io(); d <- list.dirs(p, full.names = FALSE, recursive = FALSE)
  f <- setdiff(f, d)
  f[!grepl(skip_file_regex, f)]
}

tv_signature <- function(tv_paths) {
  .io(length(tv_paths))
  info <- file.info(tv_paths, extra_cols = FALSE)
  paste(tv_paths, info$size, as.numeric(info$mtime), collapse = "|")
}

# Time vector of a folder: clean_tv, else TimeVector, else a file ending in _tv
find_tv_file <- function(f) {
  lf <- tolower(f)
  for (cand in unique(tolower(c(tv_input, "clean_tv", "timevector")))) {
    i <- match(cand, lf)
    if (!is.na(i)) return(f[i])
  }
  i <- grep("_tv$", lf)
  if (length(i)) f[i[1]] else NA_character_
}

read_tv <- function(p) {
  .io(); readBin(p, "double", n = file.size(p) %/% 8)
}

# Half-hour index of Matlab datenums, for matching two time vectors
tv_slot <- function(tv) round((tv - 719529) * 48)

# Second-logger series that replace the site's own for one year (see
# `logger_overrides` in scripts/UQAM_ini.R). Only variables the site has.
year_overrides <- function(site, base, tv, files) {
  spec <- if (exists("logger_overrides")) logger_overrides[[site]] else NULL
  if (is.null(spec) || !length(spec$vars)) return(NULL)
  p <- file.path(base, spec$folder)
  .io(); if (!dir.exists(p)) return(NULL)
  .io(); f <- list.files(p)
  tvf <- find_tv_file(f)
  if (is.na(tvf)) return(NULL)
  path_of <- function(x) { h <- f[match(tolower(x), tolower(f))]; ifelse(is.na(h), NA, file.path(p, h)) }
  vars <- list()
  for (target in intersect(names(spec$vars), names(files))) {   # only variables the site has
    s <- spec$vars[[target]]
    src <- path_of(s[[1]])
    if (anyNA(src)) next
    when <- NULL
    if (length(s$when)) {
      wp <- path_of(names(s$when)[1])
      if (is.na(wp)) next
      when <- list(file = wp, above = as.numeric(s$when[[1]]))
    }
    vars[[target]] <- list(files = src, limits = s$limits, when = when,
                           from = if (length(s$from)) as.numeric(as.Date(s$from)) + 719529)
  }
  if (!length(vars)) return(NULL)
  btv <- read_tv(file.path(p, tvf))
  idx <- match(tv_slot(btv), tv_slot(tv))
  # never blank the site's own series because the time vectors do not line up
  if (!any(!is.na(idx))) return(NULL)
  list(folder = spec$folder, tv_path = file.path(p, tvf), tv = btv, n = length(btv),
       idx = idx, vars = vars)
}

# One variable from the second logger, on the site's own time steps
read_override <- function(e, var) {
  ov <- e$override; s <- ov$vars[[var]]
  clip <- function(v) {
    v[!is.finite(v)] <- NA
    if (length(s$limits) == 2) v[!is.na(v) & (v < s$limits[1] | v > s$limits[2])] <- NA
    v
  }
  vals <- lapply(s$files, function(p) clip(read_float_file(p, ov$n)))
  b <- if (length(vals) == 1) vals[[1]] else {
    m <- rowMeans(do.call(cbind, vals), na.rm = TRUE); m[is.nan(m)] <- NA; m
  }
  if (!is.null(s$when)) {
    w <- read_float_file(s$when$file, ov$n)
    b[!(is.finite(w) & w > s$when$above)] <- NA
  }
  if (!is.null(s$from)) b[ov$tv <= s$from] <- NA   # time stamps mark the end of each half-hour
  v <- rep(NA_real_, e$n)
  ok <- !is.na(ov$idx)
  v[ov$idx[ok]] <- b[ok]
  v
}

catalog_tv_paths <- function(years) {
  c(vapply(years, `[[`, "", "tv_path"),
    unlist(lapply(years, function(e) e$override$tv_path)))
}

build_catalog <- function(site, levels = level, yrs = site_years(site), overrides = TRUE) {
  years <- lapply(yrs, function(y) {
    base <- file.path(main_dir, y, site)
    tv_path <- file.path(base, levels[1], tv_input)
    .io(); if (!file.exists(tv_path)) return(NULL)
    tv <- read_tv(tv_path)
    files <- character(0)
    for (lv in levels) {
      p <- file.path(base, lv)
      f <- setdiff(list_level_files(p), names(files))   # first level wins on duplicates
      files[f] <- file.path(p, f)
    }
    ov <- if (overrides) year_overrides(site, base, tv, files) else NULL
    list(year = y, tv_path = tv_path, n = length(tv), tv = tv, files = files, override = ov)
  })
  years <- Filter(Negate(is.null), years)
  if (!length(years)) return(NULL)
  tv <- unlist(lapply(years, `[[`, "tv"))
  # Matlab datenum -> POSIXct (UTC), rounded to the nearest 30 minutes
  secs <- round((tv - 719529) * 86400 / 1800) * 1800
  datetime <- as.POSIXct(secs, origin = "1970-01-01", tz = "UTC")
  ord <- order(datetime)
  if (!identical(ord, seq_along(ord))) datetime <- datetime[ord]
  for (i in seq_along(years)) years[[i]]$tv <- NULL
  raw <- unique(unlist(lapply(years, function(e) names(e$files))))
  list(site = site, years = years, datetime = datetime, order = ord,
       sorted = identical(ord, seq_along(ord)), raw_vars = raw,
       signature = tv_signature(catalog_tv_paths(years)),
       checked = Sys.time(), values = new.env(parent = emptyenv()))
}

site_catalog <- function(site) {
  key <- paste0("cat:", site)
  cat <- .cq_cache[[key]]
  if (!is.null(cat) && difftime(Sys.time(), cat$checked, units = "secs") < recheck_seconds) return(cat)
  if (!is.null(cat)) {
    sig <- tv_signature(catalog_tv_paths(cat$years))
    if (identical(sig, cat$signature)) {
      cat$checked <- Sys.time(); .cq_cache[[key]] <- cat
      return(cat)
    }
  }
  cat <- build_catalog(site)
  .cq_cache[[key]] <- cat
  prune_site_cache()
  cat
}

# 3. One variable, all years (cached) ----------------------------------------
read_float_file <- function(p, n) {
  .io()
  v <- tryCatch(readBin(p, "double", n = n, size = 4), error = function(err) numeric(0))
  if (length(v) < n) v <- c(v, rep(NA_real_, n - length(v)))
  v
}

read_raw_var <- function(cat, var) {
  x <- unlist(lapply(cat$years, function(e) {
    if (!is.null(e$override) && var %in% names(e$override$vars)) return(read_override(e, var))
    p <- e$files[var]
    if (is.na(p)) return(rep(NA_real_, e$n))
    read_float_file(p, e$n)
  }), use.names = FALSE)
  if (!cat$sorted) x <- x[cat$order]
  x
}

site_var <- function(cat, var) {
  if (!is.null(cat$values[[var]])) return(cat$values[[var]])
  d <- derived_vars(cat$raw_vars)
  x <- if (var %in% names(d)) {
    src <- d[[var]]
    a <- site_var(cat, src[1])
    if (length(src) > 1) {
      b <- site_var(cat, src[2])
      if (src[3] == "-") a - b else a + b
    } else a
  } else if (var %in% cat$raw_vars) {
    read_raw_var(cat, var)
  } else {
    rep(NA_real_, length(cat$datetime))
  }
  assign(var, x, envir = cat$values)
  x
}

# 4. The object the app works with ---------------------------------------------
# obj$datetime, obj$vars, obj$units ... and obj_cols(obj, cols, rows) for values.
get_site_data <- function(site) {
  if (is.null(site) || !nzchar(site)) return(NULL)
  cat <- site_catalog(site)
  if (is.null(cat)) return(NULL)
  key <- paste0("obj:", site)
  hit <- .cq_cache[[key]]
  if (!is.null(hit) && identical(hit$signature, cat$signature)) return(hit)

  vars <- c(cat$raw_vars, names(derived_vars(cat$raw_vars)))
  vars <- vars[order(tolower(vars))]
  # First and last record: from key flux / met variables (reads 1-2 files per year)
  keyv <- utils::head(intersect(c("FC", "LE", "H", "TA_1_1_1", "SW_IN_1_1_1"), vars), 2)
  if (!length(keyv)) keyv <- vars[1]
  has <- Reduce(`|`, lapply(keyv, function(v) !is.na(site_var(cat, v))), FALSE)
  valid <- which(has)
  step <- diff(as.numeric(cat$datetime))
  obj <- list(
    site = site, cat = cat, datetime = cat$datetime, vars = vars,
    units = var_units(vars, UnitCSVFilePath),
    years = sort(unique(as.integer(format(cat$datetime[valid], "%Y")))),
    first = if (length(valid)) cat$datetime[min(valid)] else cat$datetime[1],
    last  = if (length(valid)) cat$datetime[max(valid)] else utils::tail(cat$datetime, 1),
    regular = length(step) > 0 && all(step == 1800),
    signature = cat$signature
  )
  .cq_cache[[key]] <- obj
  obj
}

obj_col <- function(obj, var) site_var(obj$cat, var)

obj_cols <- function(obj, cols, rows = NULL) {
  d <- data.frame(datetime = if (is.null(rows)) obj$datetime else obj$datetime[rows])
  for (cl in unique(cols)) {
    v <- obj_col(obj, cl)
    d[[cl]] <- if (is.null(rows)) v else v[rows]
  }
  d$year <- as.integer(format(d$datetime, "%Y"))
  d
}

prune_site_cache <- function() {
  keys <- grep("^cat:", ls(.cq_cache), value = TRUE)
  if (length(keys) <= max_cached_sites) return(invisible())
  used <- vapply(keys, function(k) as.numeric(.cq_cache[[k]]$checked), 0)
  drop <- keys[order(used)][seq_len(length(keys) - max_cached_sites)]
  rm(list = c(drop, sub("^cat:", "obj:", drop)), envir = .cq_cache)
}

# 5. All sites: one variable per site (cached through the site catalogs) ------
# Same rule as before: the first file whose name without position qualifiers
# (e.g. TA_1_1_1 -> TA) matches the requested variable.
site_series_for <- function(site, var) {
  cat <- site_catalog(site)
  if (is.null(cat)) return(NULL)
  if (var == "datetime") return(list(name = "datetime", values = as.numeric(cat$datetime)))
  short <- gsub("_[[:digit:]]", "", cat$raw_vars)
  hit <- cat$raw_vars[short == var][1]
  if (is.na(hit)) return(NULL)
  list(name = hit, values = site_var(cat, hit))
}

all_sites_signature <- function() {
  s <- available_sites()
  paste(s, vapply(s, function(x) { c <- site_catalog(x); if (is.null(c)) "" else c$signature }, ""),
        collapse = "|")
}

# Data for the All sites page: one row per site and time step, x and y only
all_sites_xy <- function(xvar, yvar, sites) {
  out <- lapply(sites, function(s) {
    cat <- site_catalog(s)
    ys <- site_series_for(s, yvar)
    if (is.null(cat) || is.null(ys)) return(NULL)
    d <- data.table::data.table(site = s, datetime = cat$datetime, y = ys$values)
    if (xvar != "datetime") {
      xs <- site_series_for(s, xvar)
      if (is.null(xs)) return(NULL)
      d[, x := xs$values]
    }
    d
  })
  data.table::rbindlist(out)
}

# 6. Site coordinates ------------------------------------------------------
site_coordinates <- function(site) {
  if (is.null(.cq_cache$coords)) {
    .cq_cache$coords <- tryCatch(
      as.data.frame(readxl::read_excel(coordinatesXLSXFilePath, sheet = 1, col_names = TRUE)),
      error = function(e) data.frame(Site = character()))
  }
  co <- .cq_cache$coords
  co <- co[toupper(trimws(co$Site)) == toupper(site), , drop = FALSE]
  if (!nrow(co)) return(NULL)
  co <- co[1, ]   # some sites have more than one row: use the first
  list(standard_meridian = as.numeric(co$Standard_Meridian),
       lat = as.numeric(co$Latitude), lon = as.numeric(co$Longitude))
}

# 7. Gap-filled (ThirdStage) data for the cumulative fluxes ------------------
# Read from `cumulative_level` whatever level the rest of the app uses.
thirdstage_catalog <- function(site) {
  key <- paste0("cat3:", site)
  cat <- .cq_cache[[key]]
  if (!is.null(cat) && difftime(Sys.time(), cat$checked, units = "secs") < recheck_seconds) return(cat)
  yrs <- site_years(site)
  .io(length(yrs))
  yrs <- yrs[dir.exists(file.path(main_dir, yrs, site, cumulative_level))]
  cat <- if (length(yrs)) build_catalog(site, cumulative_level, yrs, overrides = FALSE) else NULL
  if (is.null(cat)) {
    cat <- list(site = site, years = list(), raw_vars = character(0), checked = Sys.time())
  }
  .cq_cache[[key]] <- cat
  cat
}

cumulative_vars <- function(site) {
  cat <- thirdstage_catalog(site)
  v <- grep(cumulative_pattern, cat$raw_vars, value = TRUE)
  v[order(tolower(v))]
}
