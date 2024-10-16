# Figure for plotting temp/RH data
# By Sara Knox
# March 15, 2022

# Input
# data = dataframe with relevant variables
# var_temp = temperature variables of interest (e.g., c("AIR_TEMP_2M","sonic_temperature_C","air_t_mean_C")) -
#            note variable order should be HMP, sonic temperature, 7700, 7200/7550
# var_RH = relative humidity variables of interest (e.g., c("RH_2M","RH"))
temp_RH_data_plotting <- function(data,var_temp,var_RH){
  
  yaxlabel <- c("Air Temperature (°C)","Relative Humidity (%)")
  
  # Temperature plots
  temp_plot <- plotly_loop(data,var_temp,yaxlabel[1])
  
  # RH plots
  RH_plot <-  plotly_loop(data,var_RH,yaxlabel[2])
  
  p <- subplot(temp_plot,RH_plot, nrows = 2, shareX = TRUE, titleX = FALSE,titleY = TRUE)%>% layout(legend = list(orientation = 'h'))
  return(p)
}
