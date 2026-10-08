# Figure for assessing offset between measured incoming radiation and potential radiation
# By Sara Knox
# Created Oct 28, 2022
# 2026: now a thin wrapper around radiation_vs_potential_plot() (plot_radiation.R)

# Input
# data = diurnal composite from diurnal_composite_rad_single_var()
# rad_var = variable name for radiation variable (e.g. SW_IN_1_1_1)

SWIN_vs_potential_rad <- function(data, rad_var, lang = "en") {
  radiation_vs_potential_plot(data, rad_var, scale = 1, show_exceeds = TRUE, lang = lang)
}
