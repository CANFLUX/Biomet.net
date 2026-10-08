# Interface text in English and French
#
# Static text in the UI is wrapped with i18n("key"): it is rendered in English
# and swapped in the browser when the language toggle changes (www/carbonique.js),
# so switching language never reloads the page or resets the user's choices.
# Text built on the server (plot labels, messages) uses tr("key", lang).
# Placeholders like {site} are filled by tr(..., site = "UQAM_1").

cq_i18n <- list(
  en = list(
    app_title = "Data explorer",
    nav_site = "Site explorer", nav_all = "All sites", nav_about = "About",
    lang_label = "Language",
    lbl_site = "Site", lbl_period = "Period",
    period_all = "All data", period_30d = "Last 30 days", period_90d = "Last 90 days",
    period_1y = "Last 12 months", period_custom = "Custom range",
    lbl_dates = "Dates",
    period_help = "The period applies to the time series, scatter plots, diurnal cycle and energy balance tabs.",
    lbl_level = "Data level", lbl_location = "Location",
    no_coords_short = "Not in the coordinates file",
    stat_last = "Last record", stat_record = "Record", stat_vars = "Variables",
    stat_cov = "{var} coverage", stat_cov_sub = "Last 30 days of record",
    stat_today = "Today", stat_days_ago = "{n} days ago", stat_day_ago = "1 day ago",
    stat_since = "Since {date}", stat_vars_sub = "Half-hourly series",
    tab_ts = "Time series", tab_scatter = "Scatter plots", tab_diurnal = "Diurnal cycle",
    tab_rad = "Radiation diagnostics", tab_ebc = "Energy balance closure", tab_cum = "Cumulative fluxes",
    lbl_variable = "Variable", lbl_resolution = "Resolution",
    res_30 = "30 min", res_daily = "Daily mean", res_monthly = "Monthly mean",
    lbl_layout = "Layout", layout_panels = "One panel per site", layout_overlay = "All sites together",
    partial = "partial year",
    btn_csv = "Download CSV",
    lbl_x = "X variable", lbl_y = "Y variable",
    lbl_outliers = "Highlight potential outliers",
    lbl_rad_var = "Radiation variable", lbl_year = "Year",
    lbl_ae = "Available energy", lbl_turb = "Turbulent fluxes", lbl_flux = "Flux",
    lbl_xall = "X axis", lbl_yall = "Y axis", lbl_sites = "Sites",
    card_fit = "Fit per year",
    cap_ts = "Drag to zoom, double-click to reset. Long periods are simplified for display (highest and lowest value of each time step); zoom in to see every half-hour. Daily means use days with at least half of the half-hours.",
    cap_scatter = "Half-hourly data, one colour per year. Lines are least-squares fits of Y on X; one line per year is drawn when year improves the fit (AIC). Overlapping points are thinned for display; the fits use all the data.",
    cap_fit = "Adjusted R\u00b2 and slope of the Y-on-X fit for each year.",
    cap_diurnal = "Mean diurnal cycle for each month of the selected period. Shaded band: 25th to 75th percentile.",
    cap_rad = "Highest value of each half-hour over 15-day windows. Measured radiation should line up with potential radiation: a lag other than 0 (in half-hour steps) points to a time stamp offset.",
    cap_ccf = "Cross-correlation between potential and measured radiation for the whole year. Dashed lines: 95% confidence bounds.",
    cap_ebc = "Half-hourly turbulent fluxes (H + LE) against available energy (NETRAD \u2212 G). Dotted line: perfect closure (1:1).",
    cap_cum = "Running sums of daily gap-filled fluxes (Clean/ThirdStage). Complete years as solid lines, incomplete years (such as the current one) dashed.",
    cap_all = "One colour per site, the same on every page. Panels share their axes so sites compare directly. Drag to zoom (all panels follow), double-click to reset.",
    msg_no_data = "No data for this selection.",
    msg_no_coords = "No coordinates for {site} in data/site_coordinates_UQAM.xlsx.\nAdd a row for this site to enable the radiation diagnostics.",
    msg_no_rad = "This site has no incoming radiation series (SW_IN or PPFD_IN).",
    msg_no_third = "Cumulative fluxes need gap-filled (ThirdStage) data.\nThe app currently reads {level}.",
    msg_no_third_site = "No gap-filled data ({level}) for {site} yet.\nCumulative fluxes appear here once the ThirdStage processing has run for this site.",
    msg_no_cum_vars = "{site} has a {level} folder, but no NEE or FCH4 gap-filled series (names ending in _uStar_f).",
    msg_no_ebc = "Energy balance closure needs NETRAD, H and LE at this site.",
    msg_no_full_year = "No complete year of gap-filled data yet.",
    msg_db_missing = "Database folder not found: {path}. Check main_dir in scripts/UQAM_ini.R.",
    msg_few_points = "Not enough overlapping data to fit a line.",
    ax_date = "Date", ax_hour = "Hour of day", ax_year = "Year",
    ax_lag = "Lag (half-hour steps)", ax_corr = "Correlation", ax_doy = "Day of year",
    fit_simple = "Slope {slope} \u00b7 intercept {intercept} \u00b7 R\u00b2 {r2} \u00b7 n = {n}",
    fit_by_year = "Year changes the relationship, so each year gets its own line \u00b7 R\u00b2 {r2} \u00b7 n = {n}",
    fit_r2 = "Adjusted R\u00b2", fit_slope = "Slope",
    leg_potential = "Potential radiation", leg_potential_ppfd = "Potential radiation \u00d7 2.5",
    leg_measured = "Measured", leg_exceeds = "Measured above potential",
    leg_outliers = "Potential outliers (Cook's D > 4/n)", leg_fit = "Fit, all years", leg_11 = "1:1",
    lag_label = "lag {k}", max_lag = "Highest correlation {r} at lag {k}",
    months = c("January", "February", "March", "April", "May", "June", "July",
               "August", "September", "October", "November", "December"),
    months_short = c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"),
    footer = "EcoFlux \u00b7 Where land, atmosphere, and climate connect.",
    loading = "Loading\u2026"
  ),
  fr = list(
    app_title = "Explorateur de donn\u00e9es",
    nav_site = "Exploration par site", nav_all = "Tous les sites", nav_about = "\u00c0 propos",
    lang_label = "Langue",
    lbl_site = "Site", lbl_period = "P\u00e9riode",
    period_all = "Toutes les donn\u00e9es", period_30d = "30 derniers jours", period_90d = "90 derniers jours",
    period_1y = "12 derniers mois", period_custom = "P\u00e9riode personnalis\u00e9e",
    lbl_dates = "Dates",
    period_help = "La p\u00e9riode s'applique aux onglets s\u00e9ries temporelles, nuages de points, cycle journalier et bilan d'\u00e9nergie.",
    lbl_level = "Niveau de donn\u00e9es", lbl_location = "Emplacement",
    no_coords_short = "Absent du fichier de coordonn\u00e9es",
    stat_last = "Derni\u00e8re donn\u00e9e", stat_record = "P\u00e9riode couverte", stat_vars = "Variables",
    stat_cov = "Couverture {var}", stat_cov_sub = "30 derniers jours de donn\u00e9es",
    stat_today = "Aujourd'hui", stat_days_ago = "Il y a {n} jours", stat_day_ago = "Il y a 1 jour",
    stat_since = "Depuis le {date}", stat_vars_sub = "S\u00e9ries semi-horaires",
    tab_ts = "S\u00e9ries temporelles", tab_scatter = "Nuages de points", tab_diurnal = "Cycle journalier",
    tab_rad = "Diagnostics du rayonnement", tab_ebc = "Fermeture du bilan d'\u00e9nergie", tab_cum = "Flux cumul\u00e9s",
    lbl_variable = "Variable", lbl_resolution = "R\u00e9solution",
    res_30 = "30 min", res_daily = "Moyenne journali\u00e8re", res_monthly = "Moyenne mensuelle",
    lbl_layout = "Affichage", layout_panels = "Un panneau par site", layout_overlay = "Tous les sites ensemble",
    partial = "ann\u00e9e partielle",
    btn_csv = "T\u00e9l\u00e9charger CSV",
    lbl_x = "Variable X", lbl_y = "Variable Y",
    lbl_outliers = "Surligner les valeurs aberrantes potentielles",
    lbl_rad_var = "Variable de rayonnement", lbl_year = "Ann\u00e9e",
    lbl_ae = "\u00c9nergie disponible", lbl_turb = "Flux turbulents", lbl_flux = "Flux",
    lbl_xall = "Axe X", lbl_yall = "Axe Y", lbl_sites = "Sites",
    card_fit = "Ajustement par ann\u00e9e",
    cap_ts = "Glisser pour zoomer, double-cliquer pour r\u00e9initialiser. Les longues p\u00e9riodes sont simplifi\u00e9es \u00e0 l'affichage (valeurs minimale et maximale de chaque pas de temps) ; zoomer pour voir chaque demi-heure. Les moyennes journali\u00e8res utilisent les jours ayant au moins la moiti\u00e9 des demi-heures.",
    cap_scatter = "Donn\u00e9es semi-horaires, une couleur par ann\u00e9e. Les droites sont des ajustements par moindres carr\u00e9s de Y en fonction de X ; une droite par ann\u00e9e est trac\u00e9e quand l'ann\u00e9e am\u00e9liore l'ajustement (AIC). Les points superpos\u00e9s sont all\u00e9g\u00e9s \u00e0 l'affichage ; les ajustements utilisent toutes les donn\u00e9es.",
    cap_fit = "R\u00b2 ajust\u00e9 et pente de l'ajustement de Y en fonction de X pour chaque ann\u00e9e.",
    cap_diurnal = "Cycle journalier moyen pour chaque mois de la p\u00e9riode choisie. Bande ombr\u00e9e : 25e au 75e centile.",
    cap_rad = "Valeur maximale de chaque demi-heure sur des fen\u00eatres de 15 jours. Le rayonnement mesur\u00e9 devrait co\u00efncider avec le rayonnement potentiel : un d\u00e9calage diff\u00e9rent de 0 (en pas de 30 min) indique un d\u00e9calage d'horodatage.",
    cap_ccf = "Corr\u00e9lation crois\u00e9e entre le rayonnement potentiel et mesur\u00e9 pour toute l'ann\u00e9e. Lignes pointill\u00e9es : bornes de confiance \u00e0 95 %.",
    cap_ebc = "Flux turbulents semi-horaires (H + LE) en fonction de l'\u00e9nergie disponible (NETRAD \u2212 G). Ligne pointill\u00e9e : fermeture parfaite (1:1).",
    cap_cum = "Sommes cumul\u00e9es des flux journaliers combl\u00e9s (Clean/ThirdStage). Ann\u00e9es compl\u00e8tes en trait plein, ann\u00e9es incompl\u00e8tes (comme l'ann\u00e9e en cours) en tirets.",
    cap_all = "Une couleur par site, la m\u00eame sur toutes les pages. Les panneaux partagent leurs axes pour comparer les sites directement. Glisser pour zoomer (tous les panneaux suivent), double-cliquer pour r\u00e9initialiser.",
    msg_no_data = "Aucune donn\u00e9e pour cette s\u00e9lection.",
    msg_no_coords = "Aucune coordonn\u00e9e pour {site} dans data/site_coordinates_UQAM.xlsx.\nAjoutez une ligne pour ce site pour activer les diagnostics du rayonnement.",
    msg_no_rad = "Ce site n'a pas de s\u00e9rie de rayonnement incident (SW_IN ou PPFD_IN).",
    msg_no_third = "Les flux cumul\u00e9s n\u00e9cessitent des donn\u00e9es combl\u00e9es (ThirdStage).\nL'application lit actuellement {level}.",
    msg_no_third_site = "Pas encore de donn\u00e9es combl\u00e9es ({level}) pour {site}.\nLes flux cumul\u00e9s appara\u00eetront ici d\u00e8s que le traitement ThirdStage aura \u00e9t\u00e9 fait pour ce site.",
    msg_no_cum_vars = "{site} a un dossier {level}, mais aucune s\u00e9rie NEE ou FCH4 combl\u00e9e (noms finissant par _uStar_f).",
    msg_no_ebc = "La fermeture du bilan d'\u00e9nergie n\u00e9cessite NETRAD, H et LE \u00e0 ce site.",
    msg_no_full_year = "Aucune ann\u00e9e compl\u00e8te de donn\u00e9es combl\u00e9es pour l'instant.",
    msg_db_missing = "Dossier de la base de donn\u00e9es introuvable : {path}. V\u00e9rifiez main_dir dans scripts/UQAM_ini.R.",
    msg_few_points = "Pas assez de donn\u00e9es communes pour ajuster une droite.",
    ax_date = "Date", ax_hour = "Heure", ax_year = "Ann\u00e9e",
    ax_lag = "D\u00e9calage (pas de 30 min)", ax_corr = "Corr\u00e9lation", ax_doy = "Jour de l'ann\u00e9e",
    fit_simple = "Pente {slope} \u00b7 ordonn\u00e9e \u00e0 l'origine {intercept} \u00b7 R\u00b2 {r2} \u00b7 n = {n}",
    fit_by_year = "L'ann\u00e9e modifie la relation : une droite par ann\u00e9e \u00b7 R\u00b2 {r2} \u00b7 n = {n}",
    fit_r2 = "R\u00b2 ajust\u00e9", fit_slope = "Pente",
    leg_potential = "Rayonnement potentiel", leg_potential_ppfd = "Rayonnement potentiel \u00d7 2,5",
    leg_measured = "Mesur\u00e9", leg_exceeds = "Mesur\u00e9 sup\u00e9rieur au potentiel",
    leg_outliers = "Valeurs aberrantes potentielles (D de Cook > 4/n)", leg_fit = "Ajustement, toutes les ann\u00e9es", leg_11 = "1:1",
    lag_label = "d\u00e9calage {k}", max_lag = "Corr\u00e9lation maximale {r} au d\u00e9calage {k}",
    months = c("Janvier", "F\u00e9vrier", "Mars", "Avril", "Mai", "Juin", "Juillet",
               "Ao\u00fbt", "Septembre", "Octobre", "Novembre", "D\u00e9cembre"),
    months_short = c("janv.", "f\u00e9vr.", "mars", "avr.", "mai", "juin", "juil.", "ao\u00fbt", "sept.", "oct.", "nov.", "d\u00e9c."),
    footer = "EcoFlux \u00b7 Là où la terre, l'atmosphère, et le climat se rejoignent.",
    loading = "Chargement\u2026"
  )
)

`%||%` <- function(a, b) if (is.null(a)) b else a

tr <- function(.key, .lang = "en", ...) {
  # (argument names start with a dot so placeholders such as {k} are never
  #  partially matched to them). Placeholder values may be vectors.
  s <- cq_i18n[[.lang]][[.key]] %||% cq_i18n$en[[.key]] %||% .key
  args <- list(...)
  if (!length(args)) return(s)
  n <- max(lengths(args))
  out <- rep_len(s, n)
  for (nm in names(args)) {
    v <- rep_len(as.character(args[[nm]]), n)
    out <- vapply(seq_len(n), function(i) gsub(paste0("{", nm, "}"), v[i], out[i], fixed = TRUE), "")
  }
  out
}

# Translatable static text for the UI
i18n <- function(key, tag = "span") {
  htmltools::tag(tag, list(`data-i18n` = key, cq_i18n$en[[key]]))
}

# Number formatting that follows the language (decimal comma in French)
fmt_num <- function(x, digits = 3, lang = "en") {
  s <- formatC(signif(x, digits), digits = digits, format = "fg", flag = "#")
  s <- sub("\\.$", "", trimws(s))
  if (lang == "fr") s <- chartr(".", ",", s)
  s
}
fmt_int <- function(x, lang = "en") {
  formatC(x, format = "d", big.mark = if (lang == "fr") "\u202f" else ",")
}
