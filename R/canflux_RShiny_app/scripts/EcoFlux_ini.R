# ------------------------------------------------------------------
# EcoFlux data explorer: configuration
#
# This file only holds settings. It is read once when the app starts.
# Edit the values below to point the app at another database or level.
# ------------------------------------------------------------------

# Root of the database, organised as <main_dir>/<year>/<site>/<level>/<variable files>
# It can be overridden without editing this file by setting the BIOMET_DB
# environment variable (handy for testing on a laptop or a staging copy).
main_dir <- Sys.getenv("BIOMET_DB", unset = "/home/uqam-site")
#main_dir <- '/Users/saraknox/Code/local_data_cleaning/Projects/uqam-site/Database'
basepath <- main_dir

# Level(s) to read. The first level also provides the time vector (tv_input).
level <- c("Clean/SecondStage")
#level <- c("Clean/ThirdStage", "Met") # NEED TO UPDATE FOR THIRD STAGE WHEN ALL SITES HAVE DATA

tv_input <- "clean_tv" # MAKE SURE tv is in folder

# Series taken from a second logger instead of the site's own files.
# For each site: the folder (inside <year>/<site>, only years that have it) and
#   <variable in the app> = list(<file(s)>, limits =, from =, when =)
# * one file, or several files whose mean is used (e.g. G_1, the mean of the plates)
# * limits = c(min, max): values outside are dropped (the logger files are raw)
# * from = "YYYY-MM-DD": values before that day are dropped
# * when = c(<file> = x): values are kept only where <file> is above x
# A variable is replaced only if the site already has it; the second logger's
# values then replace the whole series for that year. File names are matched
# without regard to case.
logger_overrides <- list(
  UQAM_4 = list(
    folder = "Met/B",   # UQAM_4b logger
    vars = list(
      # Radiation (CNR4, PQS): empty on the main logger. The 4b logger clock was
      # 30 min off in January and February (fixed on a site visit); not corrected here.
      SW_IN_1_1_1    = list("SYS_SW_IN_Avg",    limits = c(-20, 1500)),
      SW_OUT_1_1_1   = list("SYS_SW_OUT_Avg",   limits = c(-20, 1200)),
      LW_IN_1_1_1    = list("SYS_LW_IN_Avg",    limits = c(100, 600)),
      LW_OUT_1_1_1   = list("SYS_LW_OUT_Avg",   limits = c(100, 750)),
      NETRAD_1_1_1   = list("SYS_NETRAD_Avg",   limits = c(-250, 1100)),
      PPFD_IN_1_1_1  = list("SYS_PPFD_IN_Avg",  limits = c(-20, 3000)),
      PPFD_OUT_1_1_1 = list("SYS_PPFD_OUT_Avg", limits = c(-20, 2500)),
      ALB_1_1_1      = list("SYS_ALB_Avg",      limits = c(0, 1), when = c(SYS_SW_IN_Avg = 20)),
      # Soil heat flux plates. The main-logger G files read 1,000 to 3,000 W m-2
      # (no plate connected). The 4b plates went into the soil on Apr 8 (before
      # that they read +100 to +2,000 W m-2 day and night).
      G_1_1_1 = list("SYS_HFP_1_1_1_Avg", limits = c(-250, 500), from = "2026-04-08"),
      G_2_1_1 = list("SYS_HFP_2_1_1_Avg", limits = c(-250, 500), from = "2026-04-08"),
      G_3_1_1 = list("SYS_HFP_3_1_1_Avg", limits = c(-250, 500), from = "2026-04-08"),
      G_4_1_1 = list("SYS_HFP_4_1_1_Avg", limits = c(-250, 500), from = "2026-04-08"),
      G_1     = list(c("SYS_HFP_1_1_1_Avg", "SYS_HFP_2_1_1_Avg",
                       "SYS_HFP_3_1_1_Avg", "SYS_HFP_4_1_1_Avg"),
                     limits = c(-250, 500), from = "2026-04-08"),
      # Soil temperature profile (empty on the main logger): TS_1 to TS_4 are
      # SoilVue depths 1 to 4
      TS_1 = list("SYS_TS_1_1_1_Avg", limits = c(-30, 50)),
      TS_2 = list("SYS_TS_1_2_1_Avg", limits = c(-30, 50)),
      TS_3 = list("SYS_TS_1_3_1_Avg", limits = c(-30, 50)),
      TS_4 = list("SYS_TS_1_4_1_Avg", limits = c(-30, 50))
    )
  )
)

# Only site folders ending in _1 ... _99 are listed (UQAM_0 is excluded)
site_pattern <- "_[1-9][0-9]?$"

# Site shown when the app opens (falls back to the first site if absent)
default_site <- "BB"

# Units and variable descriptions (AmeriFlux names)
UnitCSVFilePath <- "data/flux_variables.csv"

# Site coordinates used by the radiation diagnostics
coordinatesXLSXFilePath <- "data/site_coordinates_UQAM.xlsx"

# Names of incoming shortwave radiation and incoming PPFD
var_rad <- c("SW_IN_1_1_1", "PPFD_IN_1_1_1")

# Variables compared on the "All sites" page
var_of_interest <- c("datetime",
                     "FC", "FCH4",                          # Ecosystem productivity and C fluxes
                     "VPD", "RH", "TA", "PPFD_IN", "SW_IN", # Meteorological variables
                     "USTAR",                               # Turbulence (proxy for 'good' EC conditions)
                     "LE", "H", "NETRAD", "G")              # Surface energy balance

# How often (minutes) the app re-scans the database folders for new sites/years
refresh_minutes <- 10

# How often (seconds) the app checks whether a site's files were updated
# (it looks at the time vector files only, so this is cheap)
recheck_seconds <- 60

# Cumulative fluxes use gap-filled data, read from this level whatever `level` is
cumulative_level <- "Clean/ThirdStage"
cumulative_pattern <- "^(NEE|FCH4).*_uStar_f$"

# Maximum number of sites kept in memory at once
max_cached_sites <- 8

# Points drawn per series before long periods are simplified for display
# (the highest and lowest value of each time step are kept; zooming in shows
# every half-hour again)
max_points_per_series <- 3000
