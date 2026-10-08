# Deploying the 2026 version of the CARBONIQUE data explorer

This version is a drop-in replacement for the current app at
`https://288-gic-rshiny.geog.mcgill.ca/knox/carbonique/`. Same data, same database
path (`/home/uqam-site`), same analyses; it is faster, follows the CARBONIQUE visual
identity and has a French/English switch.

## 1. Check the R packages on the server

```r
for (p in c("shiny", "bslib", "plotly", "htmlwidgets", "data.table", "readxl", "jsonlite"))
  cat(p, format(packageVersion(p)), "\n")
```

Minimum versions: shiny 1.6, bslib 0.5, plotly 4.10, htmlwidgets 1.5.3, data.table 1.12.
Tested with R 4.3.3, shiny 1.8.0, bslib 0.6.1, plotly 4.10.4, data.table 1.14.10.

No new packages are needed. The app no longer uses tidyverse, shinydashboard,
shinycssloaders, gridExtra, ggrepel, hms, readr, lubridate or forecast (they can stay
installed).

## 2. Install it next to the current app first

Copy the folder to a new app directory so both versions run side by side, for example
(user directory layout):

```sh
cp -r carbonique_RShiny_app ~/ShinyApps/carbonique-beta
```

It is then available at `.../knox/carbonique-beta/`. Nothing in the current app changes.

## 3. Test it on the server, with the real database

```sh
cd ~/ShinyApps/carbonique-beta
Rscript tests/smoke_test.R
```

This reads every site and renders every tab in English and French. It must end with
`All outputs rendered without errors.` Then open the beta URL and click through the tabs.

## 4. Switch

When the beta looks right, replace the current app folder with this one (or, if the
server folder is a git clone of the repository, run `git pull` once this version is merged
into `main`). To roll back, put the previous folder back or `git checkout 6f1f0fa` (the
last commit before this version).

## What changed for the server

* **Reads only what is shown.** The old app re-read every site on the first visit of each
  day and saved `data/all_data.RData` and `data/updated.txt`. The new app opens a site by
  reading its time vectors and the few variables on screen, then keeps each variable in
  memory until the site's files change (it checks the `clean_tv` files, at most once a
  minute). Opening a site touches about 15 files instead of 400 to 600, which is what
  made it slow on network drives (about 12 s per site on `W:`). It writes nothing to its
  folder. The two old files and `scripts/load_save_data.R` were removed.
* **No WebGL needed.** Plots are drawn as SVG, so they also work in browsers where WebGL
  is off (the old plots stayed empty there). Long periods are simplified for display
  (lowest and highest value of each time step, at most 3,000 points per series); zooming
  in makes the server send every half-hour of the new range. Scatter clouds are thinned
  to one point per small screen cell; fits and statistics always use all the data.
* **Rendered plots are cached** (`bindCache`), so the next visitor asking for the same
  view gets it immediately.
* **No external downloads.** The Roboto font and the logos are served from `www/`.
* **Optional, recommended:** keep the R process alive between visits so the in-memory
  cache survives. In `/etc/shiny-server/shiny-server.conf`, inside the relevant
  `location` block:

  ```
  app_idle_timeout 1800;
  ```

## Things to review (analysis changes)

These are corrections of issues found while testing. Please check that they match the
intent:

1. **Regression direction** (scatter and energy balance tabs). The line drawn is Y on X,
   but the old title reported the slope of X on Y. Title, line and per-year chart now
   all use `lm(y ~ x)`.
2. **Negative values were dropped** from scatter plots and fits because both axes were
   forced to start at 0. Night-time H, LE and NETRAD are now included.
3. **Year effect** is tested with `year` as a factor (one line per year), which matches
   the per-year lines that are drawn.
4. **Cross-correlation plot** (radiation tab) never displayed on the server: it called
   `forecast::ggCcf()` but the forecast package was not loaded. It now uses base R `ccf()`.
5. **Radiation "exceeds" points** are now measured > potential (strictly), so night-time
   zeros are not flagged. Window lags use paired finite values.
6. **H_LE** uses the first H and the first LE column found (the old code summed every
   match, which could double count if both `H` and `H_*_uStar_orig` exist).
7. **Time series variable groups**: choosing `TA` shows `TA_1_1_1`, `TA_1_2_1`...;
   `TA_F` is its own entry (before, `TA` also pulled in the `TA_F_*` series).
8. **One period selector** in the sidebar now applies to the time series, scatter,
   diurnal and energy balance tabs. The old app had two date sliders with the same id
   (only one worked) and the time series ignored it.
9. **Cumulative fluxes** now read `Clean/ThirdStage` directly (the old tab only worked if
   the whole app was switched to ThirdStage, which it never was). Complete years are
   drawn as before; incomplete years (such as the current one) are added as dashed
   lines. Days with a gap are left out of the running sum.
10. **"Last record"** on the overview tiles is the last time step with FC or LE data
   (or the first flux/met variable available), rather than any variable.

The site data, potential radiation and 15-day composites were checked against the old
functions on the same database copy: identical values.

## Configuration

Everything is in `scripts/UQAM_ini.R`:

* `main_dir` (or the `CARBONIQUE_DB` environment variable) and `level` (the data level
  the site tabs read),
* `cumulative_level` and `cumulative_pattern`: where the cumulative fluxes tab finds
  gap-filled series (`Clean/ThirdStage`, names like `NEE_..._uStar_f`). It reads them for
  any site that has that folder, whatever `level` is set to,
* `logger_overrides`: series taken from a second logger instead of the site's own files.
  At UQAM_4, radiation (CNR4, PQS), soil heat flux (`G_1` = mean of the four plates,
  from 2026-04-08) and soil temperature `TS_1` to `TS_4` (SoilVue depths 1 to 4) come
  from `Met/B` (UQAM_4b logger), because they are empty or wrong on the main logger.
  These files are raw, so values outside plausible limits are dropped (set per variable
  in the same place). Only variables the site already has are replaced; the smoke test
  lists them per site,
* `default_site`, the radiation variable names, the variables of the All sites page,
* `max_points_per_series` (display simplification), `recheck_seconds` (how often a site's
  files are checked for updates).

The radiation diagnostics need each site's coordinates in
`data/site_coordinates_UQAM.xlsx` (columns Site, Standard_Meridian, Latitude,
Longitude; one row per site, site names as in the database folders). All six sites
(MCGILL_1, UQAM_1 to UQAM_5) are in it. A new site only needs a new row; until then its
radiation tab shows a message.
