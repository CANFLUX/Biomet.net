# ------------------------------------------------------------------
# EcoFlux data explorer
#
# June, 2024: Sara Knox (sara.knox@mcgill.ca), adapted from the AmeriFlux
#   data visualization app by Sophie Ruehr (sophie_ruehr@berkeley.edu)
# December 2024: Tim Elrick, server setup and load-time improvements
# 2026: David Trejo Cancino, performance rewrite, CARBONIQUE visual identity,
#   French/English interface
#
# Files:
#   scripts/EcoFLux_ini.R     settings (database path, level, variables)
#   functions/             data access, analyses and plots
#   www/                   logo, Roboto font, stylesheet and small script
# ------------------------------------------------------------------

# 1. SET UP ---------------------------------------------------------
library(shiny)
library(bslib)
library(plotly)
library(data.table)

print(getwd())
print(Sys.getenv('BIOMET_DB'))

source("scripts/EcoFlux_ini.R")
for (f in list.files("functions", pattern = "\\.R$", full.names = TRUE)) source(f)

asset_version <- "2026.09.2"   # bump when www/ files change, so browsers reload them

cq_theme <- bs_theme(
  version = 5, preset = "bootstrap",   # plain Bootstrap 5 (no extra Open Sans download)
  bg = "#FFFFFF", fg = cq_brand$ink,
  primary = cq_brand$brown, secondary = cq_brand$muted,
  success = "#5A9E2F", info = "#2A9BC4", warning = "#E0A200", danger = "#C2572B",
  base_font = font_collection("Roboto", "system-ui", "-apple-system", "Segoe UI", "Arial", "sans-serif"),
  heading_font = font_collection("Roboto", "system-ui", "-apple-system", "Segoe UI", "Arial", "sans-serif"),
  "font-size-base" = "0.94rem",
  "border-radius" = "0.6rem",
  "headings-font-weight" = "500",
  "navbar-bg" = "#FFFFFF",
  "link-color" = cq_brand$brown_dark
)

# 2. USER INTERFACE ---------------------------------------------------
controls <- function(...) div(class = "cq-controls", ...)
caption <- function(key) p(class = "cq-caption", i18n(key))
plot_box <- function(id, height) div(class = "cq-plot-wrap", plotlyOutput(id, height = height))
sel <- function(id, key, ch, width = NULL) {
  selectInput(id, i18n(key), choices = ch$choices, selected = ch$selected, width = width)
}

icon_download <- HTML('<svg class="cq-icon" viewBox="0 0 16 16" width="14" height="14" aria-hidden="true"><path fill="currentColor" d="M8 1a.75.75 0 0 1 .75.75v6.69l2.22-2.22a.75.75 0 1 1 1.06 1.06l-3.5 3.5a.75.75 0 0 1-1.06 0l-3.5-3.5a.75.75 0 0 1 1.06-1.06l2.22 2.22V1.75A.75.75 0 0 1 8 1ZM2.75 11a.75.75 0 0 1 .75.75v1.5h9v-1.5a.75.75 0 0 1 1.5 0v2.25a.75.75 0 0 1-.75.75H2.75a.75.75 0 0 1-.75-.75v-2.25a.75.75 0 0 1 .75-.75Z"/></svg>')

# plotly.js is requested with the page (not after the first plot arrives)
plotly_page_deps <- htmltools::findDependencies(htmltools::as.tags(cq_empty_plot("")))

brand <- tags$span(
  class = "cq-brand",
  tags$img(src = "img/EcoFLux logo long.png", alt = "EcoFlux", class = "cq-logo"),
  tags$span(class = "cq-brand-sub", i18n("app_title"))
)

lang_toggle <- div(
  id = "lang", class = "cq-lang-toggle", role = "group", `aria-label` = "Language / Langue",
  tags$button(type = "button", `data-lang` = "fr", "FR"),
  tags$button(type = "button", `data-lang` = "en", "EN")
)

about_page <- function() {
  div(
    class = "cq-about",
    card(
      card_body(
        tags$img(src = "img/EcoFLux logo.png", alt = "EcoFlux", class = "cq-about-logo"),
        div(class = "lang-en",
            h3("About the data"),
            p("CARBONIQUE studies the carbon cycle in Quebec wetlands. The five-year research program ",
              "measures the net ecosystem carbon balance of open peatlands, wooded peatlands, forested swamps ",
              "and coastal marshes, under natural and disturbed conditions."),
            p("This tool shows the half-hourly data collected at the project's flux sites. It reads the ",
              "cleaned database directly, so new data appear as soon as they are processed."),
            p("Learn more at ", tags$a(href = "https://carbonique.ca", target = "_blank", "carbonique.ca"), "."),
            h3("How to use it"),
            tags$ul(
              tags$li(tags$b("Site explorer: "), "pick a site and a period, then move between the tabs. ",
                      "Every plot zooms (drag), resets (double-click) and can be saved as a PNG from its toolbar."),
              tags$li(tags$b("All sites: "), "compare one variable across sites, over time or against another variable."),
              tags$li(tags$b("Time series: "), "download the selected series as a CSV file.")
            ),
            h3("Acknowledgements"),
            p("This application was developed by Sara Knox (2024), based on the ",
              tags$a(href = "https://ameriflux.shinyapps.io/version1/", target = "_blank", "AmeriFlux data visualization tool"),
              " by Sophie Ruehr. Server setup by Tim Elrick. Performance update, visual identity and French ",
              "interface by David Trejo Cancino (2026)."),
            p("Code: ", tags$a(href = "https://github.com/CANFLUX/carbonique_RShiny_app", target = "_blank",
                               "github.com/CANFLUX/carbonique_RShiny_app"))
        ),
        div(class = "lang-fr",
            h3("\u00c0 propos des donn\u00e9es"),
            p("CARBONIQUE \u00e9tudie le cycle du carbone dans les milieux humides du Qu\u00e9bec. Ce programme de ",
              "recherche de cinq ans mesure le bilan net de carbone des \u00e9cosyst\u00e8mes de tourbi\u00e8res ouvertes, ",
              "tourbi\u00e8res bois\u00e9es, mar\u00e9cages arbor\u00e9s et marais c\u00f4tiers, en conditions naturelles et perturb\u00e9es."),
            p("Cet outil affiche les donn\u00e9es semi-horaires recueillies aux sites de flux du projet. Il lit directement ",
              "la base de donn\u00e9es nettoy\u00e9e : les nouvelles donn\u00e9es apparaissent d\u00e8s qu'elles sont trait\u00e9es."),
            p("Pour en savoir plus : ", tags$a(href = "https://carbonique.ca", target = "_blank", "carbonique.ca"), "."),
            h3("Mode d'emploi"),
            tags$ul(
              tags$li(tags$b("Exploration par site : "), "choisissez un site et une p\u00e9riode, puis parcourez les onglets. ",
                      "Chaque graphique permet de zoomer (glisser), de r\u00e9initialiser (double-clic) et de s'enregistrer en PNG depuis sa barre d'outils."),
              tags$li(tags$b("Tous les sites : "), "comparez une variable entre les sites, dans le temps ou en fonction d'une autre variable."),
              tags$li(tags$b("S\u00e9ries temporelles : "), "t\u00e9l\u00e9chargez les s\u00e9ries choisies en CSV.")
            ),
            h3("Remerciements"),
            p("Cette application a \u00e9t\u00e9 d\u00e9velopp\u00e9e par Sara Knox (2024) \u00e0 partir de ",
              tags$a(href = "https://ameriflux.shinyapps.io/version1/", target = "_blank", "l'outil de visualisation d'AmeriFlux"),
              " de Sophie Ruehr. Configuration du serveur : Tim Elrick. Mise \u00e0 jour des performances, identit\u00e9 visuelle ",
              "et interface fran\u00e7aise : David Trejo Cancino (2026)."),
            p("Code : ", tags$a(href = "https://github.com/CANFLUX/carbonique_RShiny_app", target = "_blank",
                                "github.com/CANFLUX/carbonique_RShiny_app"))
        )
      )
    )
  )
}

ui <- function(request) {
  sites <- available_sites()
  head_assets <- tags$head(
    tags$link(rel = "icon", type = "image/png", href = "img/favicon.png"),
    tags$link(rel = "apple-touch-icon", href = "img/apple-touch-icon.png"),
    tags$meta(name = "description", content = "EcoFlux tower data explorer"),
    tags$link(rel = "stylesheet", href = paste0("carbonique.css?v=", asset_version)),
    tags$script(HTML(paste0("window.CQ_I18N = ", jsonlite::toJSON(cq_i18n, auto_unbox = TRUE), ";"))),
    tags$script(src = paste0("carbonique.js?v=", asset_version)),
    htmltools::attachDependencies(tags$span(), plotly_page_deps)
  )

  if (!length(sites)) {
    return(page_fluid(theme = cq_theme, head_assets,
                      div(class = "cq-fatal", brand,
                          p(tr("msg_db_missing", "en", path = main_dir)),
                          p(tr("msg_db_missing", "fr", path = main_dir)))))
  }

  site0 <- if (default_site %in% sites) default_site else sites[1]
  obj <- get_site_data(site0)
  ch <- site_choices(obj)
  all_vars <- var_of_interest

  site_page <- layout_sidebar(
    sidebar = sidebar(
      width = 285, class = "cq-sidebar",
      selectInput("site", i18n("lbl_site"), choices = sites, selected = site0),
      radioButtons("period", i18n("lbl_period"),
                   choiceNames = list(i18n("period_all"), i18n("period_30d"), i18n("period_90d"),
                                      i18n("period_1y"), i18n("period_custom")),
                   choiceValues = c("all", "30d", "90d", "1y", "custom"), selected = "all"),
      conditionalPanel(
        "input.period == 'custom'",
        dateRangeInput("dates", i18n("lbl_dates"),
                       start = as.Date(obj$first), end = as.Date(obj$last),
                       separator = " \u2192 ", weekstart = 1)
      ),
      p(class = "cq-help", i18n("period_help")),
      uiOutput("site_meta")
    ),
    uiOutput("site_stats"),
    navset_card_underline(
      id = "site_tab",
      nav_panel(
        i18n("tab_ts"), value = "ts",
        controls(
          sel("ts_var", "lbl_variable", ch$ts_var, width = "320px"),
          radioButtons("ts_res", i18n("lbl_resolution"), inline = TRUE,
                       choiceNames = list(i18n("res_30"), i18n("res_daily")),
                       choiceValues = c("30min", "daily")),
          div(class = "cq-control-end",
              downloadButton("ts_csv", tagList(icon_download, i18n("btn_csv")),
                             class = "btn-outline-primary btn-sm", icon = NULL))
        ),
        uiOutput("ts_desc"),
        plot_box("ts_plot", "440px"),
        caption("cap_ts")
      ),
      nav_panel(
        i18n("tab_scatter"), value = "scatter",
        controls(
          sel("sc_x", "lbl_x", ch$sc_x, width = "240px"),
          sel("sc_y", "lbl_y", ch$sc_y, width = "240px"),
          div(class = "cq-control-check", checkboxInput("sc_outliers", i18n("lbl_outliers"), FALSE))
        ),
        uiOutput("sc_text"),
        plot_box("sc_plot", "480px"),
        caption("cap_scatter"),
        h6(class = "cq-subhead", i18n("card_fit")),
        plot_box("sc_fit", "230px"),
        caption("cap_fit")
      ),
      nav_panel(
        i18n("tab_diurnal"), value = "diurnal",
        controls(sel("di_var", "lbl_variable", ch$di_var, width = "260px")),
        plot_box("di_plot", "640px"),
        caption("cap_diurnal")
      ),
      nav_panel(
        i18n("tab_rad"), value = "rad",
        controls(
          sel("rad_var", "lbl_rad_var", ch$rad_var, width = "220px"),
          sel("rad_year", "lbl_year", ch$rad_year, width = "140px")
        ),
        uiOutput("rad_plot_ui"),
        uiOutput("rad_ccf_ui")
      ),
      nav_panel(
        i18n("tab_ebc"), value = "ebc",
        controls(
          sel("ebc_x", "lbl_ae", ch$ebc_x, width = "240px"),
          sel("ebc_y", "lbl_turb", ch$ebc_y, width = "240px"),
          div(class = "cq-control-check", checkboxInput("ebc_outliers", i18n("lbl_outliers"), FALSE))
        ),
        uiOutput("ebc_text"),
        plot_box("ebc_plot", "480px"),
        caption("cap_ebc"),
        h6(class = "cq-subhead", i18n("card_fit")),
        plot_box("ebc_fit", "230px"),
        caption("cap_fit")
      ),
      nav_panel(
        i18n("tab_cum"), value = "cum",
        uiOutput("cum_controls"),
        plot_box("cum_plot", "460px"),
        caption("cap_cum")
      )
    )
  )

  all_page <- layout_sidebar(
    sidebar = sidebar(
      width = 285, class = "cq-sidebar",
      selectInput("xcol_all", i18n("lbl_xall"), choices = all_vars, selected = "datetime"),
      selectInput("ycol_all", i18n("lbl_yall"), choices = all_vars[-1], selected = "TA"),
      radioButtons("all_res", i18n("lbl_resolution"),
                   choiceNames = list(i18n("res_30"), i18n("res_daily"), i18n("res_monthly")),
                   choiceValues = c("30min", "daily", "monthly"), selected = "daily"),
      radioButtons("all_layout", i18n("lbl_layout"),
                   choiceNames = list(i18n("layout_panels"), i18n("layout_overlay")),
                   choiceValues = c("panels", "overlay"), selected = "panels"),
      checkboxGroupInput("all_sites", i18n("lbl_sites"), choices = sites, selected = sites)
    ),
    card(
      class = "cq-card",
      card_body(uiOutput("all_plot_ui"), caption("cap_all"))
    )
  )

  # Light navbar. bslib 0.9+ takes this through navbar_options(); older versions
  # take `inverse` directly.
  navbar_args <- if (exists("navbar_options", envir = asNamespace("bslib"))) {
    list(navbar_options = bslib::navbar_options(inverse = FALSE))
  } else {
    list(inverse = FALSE)
  }

  do.call(page_navbar, c(list(
    nav_panel(i18n("nav_site"), value = "site", site_page),
    nav_panel(i18n("nav_all"), value = "all", all_page),
    nav_panel(i18n("nav_about"), value = "about", about_page()),
    nav_spacer(),
    nav_item(lang_toggle),
    id = "nav",
    title = brand,
    window_title = "EcoFlux \u00b7 Data explorer",
    theme = cq_theme,
    fillable = FALSE,
    header = head_assets,
    footer = div(class = "cq-footer", i18n("footer"),
                 tags$a(href = "https://ecoflux-lab.github.io/", target = "_blank", "ecoflux-lab.github.io"))
  ), navbar_args))
}

# 3. SERVER -------------------------------------------------------------
server <- function(input, output, session) {

  lang <- reactive(if (identical(input$lang, "fr")) "fr" else "en")

  # The selected site's data (read from disk only when its files change)
  site_obj <- reactive({
    req(input$site)
    obj <- get_site_data(input$site)
    validate(need(!is.null(obj), tr("msg_no_data", lang())))
    obj
  })
  site_key <- reactive(paste(site_obj()$site, site_obj()$signature))

  # Keep every selector in sync with the site. Current choices are kept when the
  # new site has them. Inputs that change are frozen until the browser confirms
  # the update, so no plot is drawn twice or with a stale selection.
  observeEvent(site_obj(), {
    ids <- c("ts_var", "sc_x", "sc_y", "di_var", "rad_var", "rad_year", "ebc_x", "ebc_y")
    cur <- lapply(stats::setNames(ids, ids), function(id) input[[id]])
    ch <- site_choices(site_obj(), cur)
    prev <- session$userData$choices
    session$userData$choices <- ch
    if (is.null(prev)) return()          # first site: the page was built with these choices
    for (id in ids) {
      same_choices <- identical(ch[[id]]$choices, prev[[id]]$choices)
      same_sel <- identical(unname(ch[[id]]$selected), cur[[id]] %||% character(0))
      if (!same_choices || !same_sel) {
        freezeReactiveValue(input, id)
        updateSelectInput(session, id, choices = ch[[id]]$choices, selected = ch[[id]]$selected)
      }
    }
  })

  # Rows of the selected period
  period_key <- reactive({
    if (identical(input$period, "custom")) paste("custom", paste(input$dates, collapse = "_")) else input$period
  })
  period_rows <- reactive({
    obj <- site_obj()
    end <- obj$last; start <- obj$first
    r <- switch(input$period %||% "all",
                "30d" = c(end - 30 * 86400, end),
                "90d" = c(end - 90 * 86400, end),
                "1y"  = c(end - 365 * 86400, end),
                "custom" = {
                  req(length(input$dates) == 2, !anyNA(input$dates))
                  c(as.POSIXct(as.character(input$dates[1]), tz = "UTC"),
                    as.POSIXct(as.character(input$dates[2]), tz = "UTC") + 86400)
                },
                NULL)
    if (is.null(r)) seq_along(obj$datetime) else which(obj$datetime >= r[1] & obj$datetime <= r[2])
  })
  period_data <- function(cols) obj_cols(site_obj(), cols, period_rows())

  # Sidebar: data level and location
  output$site_meta <- renderUI({
    obj <- site_obj(); co <- site_coordinates(obj$site); l <- lang()
    loc <- if (is.null(co)) tr("no_coords_short", l) else
      sprintf("%.4f\u00b0 N, %.4f\u00b0 W", co$lat, abs(co$lon))
    div(class = "cq-meta",
        div(class = "cq-meta-row", span(class = "cq-meta-label", tr("lbl_level", l)),
            span(paste(level, collapse = ", "))),
        div(class = "cq-meta-row", span(class = "cq-meta-label", tr("lbl_location", l)), span(loc)))
  })

  # Overview tiles
  output$site_stats <- renderUI({
    obj <- site_obj(); l <- lang()
    days <- floor(as.numeric(difftime(Sys.time(), obj$last, units = "days")))
    ago <- if (days <= 0) tr("stat_today", l) else if (days == 1) tr("stat_day_ago", l) else tr("stat_days_ago", l, n = days)
    stale <- days > 3
    flux <- intersect(c("FC", "NEE", "LE", "H"), obj$vars)[1]
    if (is.na(flux)) flux <- obj$vars[1]
    win <- obj$datetime > obj$last - 30 * 86400 & obj$datetime <= obj$last
    cov <- mean(!is.na(obj_col(obj, flux)[win]))
    yrs <- range(obj$years)
    tile <- function(cls, label, value, sub, extra = NULL) {
      div(class = paste("cq-stat", cls),
          div(class = "cq-stat-label", label),
          div(class = "cq-stat-value", value),
          div(class = "cq-stat-sub", sub), extra)
    }
    div(class = "cq-stats",
        tile("t1", tr("stat_last", l),
             tagList(format(obj$last, "%Y-%m-%d"), span(class = "cq-stat-time", format(obj$last, "%H:%M"))),
             if (stale) span(class = "cq-warn", "\u26a0 ", ago) else ago),
        tile("t2", tr("stat_record", l), if (yrs[1] == yrs[2]) yrs[1] else paste(yrs[1], yrs[2], sep = "-"),
             tr("stat_since", l, date = format(obj$first, "%Y-%m-%d"))),
        tile("t3", tr("stat_vars", l), length(obj$vars), tr("stat_vars_sub", l)),
        tile("t4", tr("stat_cov", l, var = flux), paste0(round(100 * cov), if (l == "fr") "\u00a0%" else "%"),
             tr("stat_cov_sub", l),
             div(class = "cq-bar", div(class = "cq-bar-fill", style = sprintf("width:%.0f%%", 100 * cov)))))
  })

  # a) Time series ------------------------------------------------------
  ts_cols <- reactive({
    obj <- site_obj(); req(input$ts_var)
    cols <- obj$vars[gsub("_[[:digit:]]", "", obj$vars) == input$ts_var]
    req(length(cols) > 0)
    cols
  })
  output$ts_desc <- renderUI({
    obj <- site_obj(); cols <- ts_cols()
    u <- obj$units[match(cols[1], obj$units$name), ]
    if (is.na(u$description) || !nzchar(u$description)) return(NULL)
    p(class = "cq-var-desc", tags$b(input$ts_var), " \u00b7 ", u$description,
      if (nzchar(u$units)) paste0(" (", u$units, ")"))
  })
  output$ts_plot <- bindCache(
    renderPlotly(plot_timeseries(site_obj(), ts_cols(), period_rows(), input$ts_res, lang())),
    site_key(), ts_cols(), period_key(), input$ts_res, lang()
  )
  # Zooming in or out asks for the half-hourly values of the new range
  # (long ranges are simplified; see plot_timeseries.R)
  observeEvent(input$ts_plot_xrange, {
    if (!identical(input$ts_res, "30min")) return()
    obj <- site_obj(); cols <- ts_cols(); rows <- period_rows()
    z <- input$ts_plot_xrange
    trs <- if (isTRUE(z$reset)) {
      ab <- trim_to_data(lapply(cols, function(cl) obj_col(obj, cl)[rows]))
      req(!is.null(ab))
      timeseries_traces(obj, cols, rows[ab[1]:ab[2]])
    } else {
      rng <- c(parse_plotly_time(z$from), parse_plotly_time(z$to))
      req(!anyNA(rng))
      timeseries_traces(obj, cols, rows, rng[1], rng[2])
    }
    restyle_xy(session, "ts_plot", trs)
  })

  output$ts_csv <- downloadHandler(
    filename = function() paste0(input$site, "_", input$ts_var, "_", format(Sys.Date(), "%Y%m%d"), ".csv"),
    content = function(file) {
      d <- period_data(ts_cols()); d$year <- NULL
      d$datetime <- format(d$datetime, "%Y-%m-%d %H:%M")
      data.table::fwrite(d, file, na = "NA")
    }
  )

  # b) Scatter plots ------------------------------------------------------
  sc_fit <- reactive({
    obj <- site_obj(); req(input$sc_x %in% obj$vars, input$sc_y %in% obj$vars)
    scatter_fit(period_data(c(input$sc_x, input$sc_y)), input$sc_x, input$sc_y)
  })
  output$sc_text <- renderUI(p(class = "cq-fit", scatter_fit_text(sc_fit(), lang())))
  output$sc_plot <- bindCache(
    renderPlotly({
      obj <- site_obj()
      scatter_plot_QCQA(NULL, input$sc_x, input$sc_y, unit_label(input$sc_x, obj$units),
                        unit_label(input$sc_y, obj$units), input$sc_outliers, lang = lang(), fit = sc_fit())
    }),
    site_key(), input$sc_x, input$sc_y, period_key(), input$sc_outliers, lang()
  )
  output$sc_fit <- bindCache(
    renderPlotly(R2_slope_QCQA(NULL, input$sc_x, input$sc_y, lang = lang(), fit = sc_fit())),
    site_key(), input$sc_x, input$sc_y, period_key(), lang()
  )

  # c) Diurnal cycle ------------------------------------------------------
  output$di_plot <- bindCache(
    renderPlotly({
      obj <- site_obj(); req(input$di_var %in% obj$vars)
      d <- period_data(input$di_var)
      plot_diurnal(d$datetime, d[[input$di_var]], input$di_var, obj$units, lang())
    }),
    site_key(), input$di_var, period_key(), lang()
  )

  # d) Radiation diagnostics ----------------------------------------------
  rad_comp <- reactive({
    obj <- site_obj()
    req(input$rad_var %in% obj$vars, input$rad_year)
    radiation_composite(obj, input$rad_var, input$rad_year)
  })
  rad_message <- reactive({
    obj <- site_obj()
    if (!length(intersect(var_rad, obj$vars))) return(tr("msg_no_rad", lang()))
    if (is.null(site_coordinates(obj$site))) return(tr("msg_no_coords", lang(), site = obj$site))
    NULL
  })
  # The radiation panel grows with the number of 15-day windows (6 per row).
  # Its height only changes when the row count changes, to avoid redrawing.
  rad_height <- reactiveVal(840)
  observe({
    req(identical(input$site_tab, "rad"), identical(input$nav, "site"))
    n <- if (is.null(rad_message())) length(unique(rad_comp()$firstdate)) else 0
    h <- if (n == 0) 220 else 90 + max(1, ceiling(n / 6)) * 150
    if (!identical(h, isolate(rad_height()))) rad_height(h)
  })
  output$rad_plot_ui <- renderUI(tagList(plot_box("rad_plot", paste0(rad_height(), "px")),
                                          if (is.null(rad_message())) caption("cap_rad")))
  output$rad_ccf_ui <- renderUI({
    if (!is.null(rad_message())) return(NULL)
    tagList(plot_box("rad_ccf", "300px"), caption("cap_ccf"))
  })
  output$rad_plot <- bindCache(
    renderPlotly({
      if (!is.null(rad_message())) return(cq_empty_plot(rad_message()))
      if (grepl("SW_IN", input$rad_var, fixed = TRUE)) {
        SWIN_vs_potential_rad(rad_comp(), input$rad_var, lang())
      } else {
        PPFDIN_vs_potential_rad(rad_comp(), input$rad_var, lang())
      }
    }),
    site_key(), input$rad_var, input$rad_year, lang()
  )
  output$rad_ccf <- bindCache(
    renderPlotly({
      if (!is.null(rad_message())) return(cq_empty_plot(rad_message()))
      xcorr_rad(rad_comp(), input$rad_var, lang())
    }),
    site_key(), input$rad_var, input$rad_year, lang()
  )

  # e) Energy balance closure ---------------------------------------------
  ebc_fit <- reactive({
    obj <- site_obj(); req(input$ebc_x %in% obj$vars, input$ebc_y %in% obj$vars)
    scatter_fit(period_data(c(input$ebc_x, input$ebc_y)), input$ebc_x, input$ebc_y)
  })
  ebc_ok <- reactive(length(grep("^AE_", site_obj()$vars)) > 0 && "H_LE" %in% site_obj()$vars)
  output$ebc_text <- renderUI({
    if (!ebc_ok()) return(NULL)
    p(class = "cq-fit", scatter_fit_text(ebc_fit(), lang()))
  })
  output$ebc_plot <- bindCache(
    renderPlotly({
      if (!ebc_ok()) return(cq_empty_plot(tr("msg_no_ebc", lang())))
      obj <- site_obj()
      scatter_plot_QCQA(NULL, input$ebc_x, input$ebc_y, unit_label(input$ebc_x, obj$units),
                        unit_label(input$ebc_y, obj$units), input$ebc_outliers,
                        one_to_one = TRUE, lang = lang(), fit = ebc_fit())
    }),
    site_key(), input$ebc_x, input$ebc_y, period_key(), input$ebc_outliers, lang()
  )
  output$ebc_fit <- bindCache(
    renderPlotly({
      if (!ebc_ok()) return(cq_empty_plot(tr("msg_no_ebc", lang())))
      R2_slope_QCQA(NULL, input$ebc_x, input$ebc_y, lang = lang(), fit = ebc_fit())
    }),
    site_key(), input$ebc_x, input$ebc_y, period_key(), lang()
  )

  # f) Cumulative fluxes (gap-filled ThirdStage data, read on demand) ----------
  output$cum_controls <- renderUI({
    vars <- cumulative_vars(input$site)
    if (!length(vars)) return(NULL)
    cur <- isolate(input$cum_var)
    controls(selectInput("cum_var", i18n("lbl_flux"), choices = vars,
                         selected = if (!is.null(cur) && cur %in% vars) cur else vars[1], width = "300px"))
  })
  output$cum_plot <- bindCache(
    renderPlotly(plot_cumulative(input$site, input$cum_var, lang())),
    input$site, thirdstage_catalog(input$site)$signature %||% "none", input$cum_var, lang()
  )

  # g) All sites ------------------------------------------------------------
  all_sites_now <- reactive(available_sites())
  all_data <- reactive({
    req(input$xcol_all, input$ycol_all)
    all_sites_xy(input$xcol_all, input$ycol_all, intersect(all_sites_now(), input$all_sites))
  })
  all_units <- var_units(var_of_interest, UnitCSVFilePath)

  # Height grows with the number of panels; only changes when the layout does
  all_height <- reactiveVal(620)
  observe({
    req(identical(input$nav, "all"))
    n <- length(input$all_sites)
    h <- if (!identical(input$all_layout, "panels") || n <= 1) 600 else
      if (identical(input$xcol_all, "datetime")) 70 + n * 165 else 90 + ceiling(n / (if (n <= 4) 2 else 3)) * 300
    if (!identical(h, isolate(all_height()))) all_height(h)
  })
  output$all_plot_ui <- renderUI(plot_box("all_plot", paste0(all_height(), "px")))

  output$all_plot <- bindCache(
    renderPlotly(plot_all_sites(all_data(), all_sites_now(), input$all_sites, input$xcol_all,
                                input$ycol_all, all_units, input$all_res, input$all_layout, lang())),
    all_sites_signature(), input$xcol_all, input$ycol_all, sort(input$all_sites),
    input$all_res, input$all_layout, lang()
  )

  observeEvent(input$all_plot_xrange, {
    if (!identical(input$all_res, "30min") || !identical(input$xcol_all, "datetime")) return()
    d <- all_data()
    sites <- intersect(all_sites_now(), input$all_sites)
    sites <- sites[sites %in% unique(d$site[!is.na(d$y)])]
    z <- input$all_plot_xrange
    panels <- identical(input$all_layout, "panels") && length(sites) > 1
    mp <- if (panels) max_points_per_series else 1500
    trs <- if (isTRUE(z$reset)) all_sites_time_traces(d, sites, "30min", max_points = mp) else {
      rng <- c(parse_plotly_time(z$from), parse_plotly_time(z$to))
      req(!anyNA(rng))
      all_sites_time_traces(d, sites, "30min", rng[1], rng[2], max_points = mp)
    }
    # panels share one y range: fit it to what is now in view
    yv <- unlist(lapply(trs, `[[`, "y")); yv <- yv[is.finite(yv)]
    yr <- if (length(yv)) range(yv) else NULL
    restyle_xy(session, "all_plot", trs, yrange = if (panels) yr)
  })
}

# 4. RUN APP -----
shinyApp(ui = ui, server = server)
