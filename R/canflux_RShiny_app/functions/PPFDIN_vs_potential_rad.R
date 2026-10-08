# Figure for assessing offset between measured incoming PPFD and potential radiation
# By Sara Knox
# Created Oct 28, 2022
# 2026: now a thin wrapper around radiation_vs_potential_plot() (plot_radiation.R).
# Potential radiation is scaled by 2.5 to be comparable with PPFD, as before.

# Input
# data = diurnal composite from diurnal_composite_rad_single_var()
# rad_var = variable name for radiation variable (e.g. PPFD_IN_1_1_1)

PPFDIN_vs_potential_rad <- function(data, rad_var, lang = "en") {
  radiation_vs_potential_plot(data, rad_var, scale = 2.5, show_exceeds = FALSE, lang = lang)
}
