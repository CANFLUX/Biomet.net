# Figure for plotting sonic data
# By Sara Knox
# March 15, 2022

# Input
# data = dataframe with relevant variables
# var = concatenated list of list of variables (e.g.,list(as.list(vars_G),as.list(vars_TS)))
#yaxislabel = y axis labels (e.g., c("G (W/m2)","Temperature (°C)") for example above)

multiple_plotly_plots <- function(data,var,yaxlabel){
  
  # Specify number of variables (e.g., G, soil/water temperature)
  nvariables <- length(lengths(var)) # number of variables included 
  
  # Specify number of individual measurements per variables (e.g., 3 SHFPs, 15 temperature measurements)
  nmeasurements <- lengths(var)
  
  # Create empty plot
  plots <- plot.new()
  
  # Loop through each variables
  for (i in 1:nvariables){
    
    # Plot first measurement for each variable    
    p <- plot_ly(data, x = ~datetime, y = as.formula(paste0("~", var[[i]][1])),name = as.character(var[[i]][1]), type = 'scatter', mode = 'lines') 
    
    if (length(var[[i]]) > 1){
      # Plot subsequent measurements for each variable
      for (j in 1:(nmeasurements[i]-1)){
        p <- p %>% add_trace(y = as.formula(paste0("~", var[[i]][j+1])), name = as.character(var[[i]][j+1]), mode = 'lines')
        # print(var[[i]][j+1])
      }
    }
    
    plots[[i]] <- p%>% 
      layout(yaxis = list(title =yaxlabel[i]))%>%
      toWebGL()
  }
  
   
  p <- subplot(plots, nrows = nvariables, shareX = TRUE, titleX = FALSE,titleY = TRUE)%>% layout(legend = list(orientation = 'h'))
   
  return(p)
  
}