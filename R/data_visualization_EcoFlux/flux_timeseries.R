# Figure for plotting radiation data
# By Sara Knox
# March 15, 2022

# Input
# data = dataframe with relevant variables
# var_radiometer = variables from net radiometer (e.g., c("SW_IN_1_1_1","SW_OUT_1_1_1","LW_IN_1_1_1","LW_OUT_1_1_1")).
#                  note that SW_IN and SW_OUT should always be listed as variables 1 and 2, respectively
# var_NETRAD = Net radiation variable
# var_PPFD = incoming and reflected PAR (e.g., c("PPFD_IN","PPFD_OUT")). Note incoming PAR should always be listed first.
# var_potential_radiation = potential radiation calculated using the function potential_rad

radiation_plots <- function(data,var_radiometer,var_NETRAD,var_PPFD, var_potential_radiation){
  
  yaxlabel <- c("Radiation (W/m2)","Net radiation (W/m2)","SW_IN & PPFD_IN","SW_OUT & PPFD_OUT")
  
  # Radiation components
  p_components <- plotly_loop(data,c(var_potential_radiation,var_radiometer),yaxlabel[1])
  
  # NETRAD
  p_net <- plot_ly(data = data, x = ~datetime, y = as.formula(paste0("~",var_NETRAD)), type = 'scatter', mode = 'lines',name = var_NETRAD)%>%
    layout(yaxis = list(title = yaxlabel[2])) %>%
    toWebGL() 
  
  # SW_IN vs PPFD
  # Incoming
  p_sw_ppfd_in <- plot_ly(data = data, x = ~datetime, y = as.formula(paste0("~",var_PPFD[1])), type = 'scatter', mode = 'lines',name = var_PPFD[1]) %>% 
    add_trace(y = as.formula(paste0("~", var_radiometer[1])), type = 'scatter',mode = 'lines',name = var_radiometer[1]) %>%
    layout(yaxis = list(title = yaxlabel[3])) %>%
    toWebGL() 
  
  # Outgoing
  p_sw_ppfd_out <- plot_ly(data = data, x = ~datetime, y = as.formula(paste0("~",var_PPFD[2])), type = 'scatter', mode = 'lines',name = var_PPFD[2]) %>% 
    add_trace(y = as.formula(paste0("~", var_radiometer[2])), mode = 'lines',name = var_radiometer[2]) %>%
    layout(yaxis = list(title = yaxlabel[4])) %>%
    toWebGL() 
  
  p <- subplot(p_components,p_net, p_sw_ppfd_in, p_sw_ppfd_out, nrows = 4, shareX = TRUE, titleX = FALSE,titleY = TRUE)%>% layout(legend = list(orientation = 'h'))
  
  return(p)
}