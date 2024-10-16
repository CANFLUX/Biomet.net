# Figure for plotting plotly figures using a loop
# By Sara Knox
# Created March 19, 2022

# Input
# data = dataframe with relevant variables
# var = variables of interest 
plotly_loop <- function(data,var,yaxislabel){
  
  p <- plot_ly(data, x = ~datetime, y = as.formula(paste0("~", var[1])),name = var[1], type = 'scatter', mode = 'lines') 
  for (i in 1:length(var)){
    p <- p %>% add_trace(data, x = ~datetime,y = as.formula(paste0("~", var[i+1])), name = var[i+1], mode = 'lines')
  }
  
  p <- p%>%
    layout(yaxis = list(title = yaxislabel))%>%
    layout(legend = list(orientation = 'h'))%>% 
    toWebGL()
  
  return(p)
}
