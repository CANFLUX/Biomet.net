# Figure for plotting sonic data
# By Sara Knox
# March 15, 2022

# Input
# data = dataframe with relevant variables
# var_WS = wind speed variables (e.g., from sonic and cup anemometer - make sure sonic data is first)
# var_WD = wind direction variables (e.g., from sonic and cup anemometer)
# var = other sonic variables of interest (e.g., c("u_","pitch") - make sure u* is first)
# unit = units for variables defined in var (e.g., c("m/s","degrees"))
# pitch_ind = index for pitch (e.g., 2)
sonic_plots <- function(data,vars_WS,vars_WD,vars,units,pitch_ind){
  
  plots <- plot.new()
  
  # wind speed plot
  yaxlabel <- "Wind speed (m/s)"
  WS_plot <- plotly_loop(data,vars_WS,yaxlabel)
  
  plots[[1]] <- WS_plot
  
  # wind direction plot
  yaxlabel <- "Wind direction (degrees)"
  WD_plot <- plotly_loop(data,vars_WD,yaxlabel)
  
  plots[[2]] <- WD_plot
  
  # all variables except wind speed and wind direction
  for (i in 1:(length(vars))){
    plots[[i+2]] <- plot_ly(data, x = ~datetime, y = as.formula(paste0("~", vars[i]))) %>%
      add_lines(name = vars[i])%>% 
      layout(yaxis = list(title = units[i]))%>%
      toWebGL()
    }
    
  # For pitch
  # Define upper and lower limits
  max <- rep(10, length(data$datetime))
  min <- rep(-10, length(data$datetime))
  plots[[pitch_ind+2]] <- plots[[pitch_ind+2]] %>%
    add_trace(data, x = ~datetime, y = max, mode = 'lines',line = list(color = 'rgb(150, 150, 150)', width = 1, dash = 'dash'),name = 'upper limit',showlegend = F) %>%
    add_trace(data, x = ~datetime, y = min, mode = 'lines',line = list(color = 'rgb(150, 150, 150)', width = 1, dash = 'dash'),name = 'lower limit',showlegend = F)
  
  p <- subplot(plots, nrows = length(plots), shareX = TRUE, titleX = FALSE,titleY = TRUE)%>% layout(legend = list(orientation = 'h'))
  return(p)
}