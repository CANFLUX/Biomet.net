# Figure for plotting mean diurnal pattern for individual variables
# By Sara Knox
# Created Oct 28, 2022

plot_diurnal_pattern_single_var <- function(data,var_name) {
  
  diurnal.summary.composite <- data %>%
    group_by(firstdate,HHMM) %>%
    dplyr::summarize(var = median(var, na.rm = TRUE),
                     HHMM = first(HHMM))
  diurnal.summary.composite$time <- as.POSIXct(as.character(diurnal.summary.composite$HHMM), format="%R", tz="UTC")
  
  p <- ggplot() +
    geom_point(data = diurnal.summary, aes(x = time, y = var),color = 'Grey',size = 0.1) +
    geom_line(data = diurnal.summary.composite, aes(x = time, y = var),color = 'Black') +
    scale_x_datetime(breaks="6 hours", date_labels = "%R") + ylab(var_name)
  
  p <- ggplotly(p+ facet_wrap(~as.factor(firstdate))) %>% toWebGL()
  p
  
  return(p)
}