# Figure for data QCQA scatter plot
# By Sara Knox
# March 15, 2022

# Input
# data = dataframe with relevant variables
# x = HMP air temperature
# y1 = sonic temperature
# y2 = 7700 temperature
# xlab = x label
# ylab = y label
scatter_plot_temp_QCQA <- function(data,x,y1,y2,temp_name,xlab,ylab){
  
  p <- ggplot(data) + 
    geom_point(aes(x, y1,color = temp_name[1]),alpha = 0.6)+
    geom_point(aes(x, y2,color = temp_name[2]),alpha = 0.6)+
    scale_color_manual("Sensor",labels = c(temp_name[1], temp_name[2]), values = c("red", "blue")) +
    geom_abline(slope=1, intercept = 0,color = "grey44",linetype = "dashed")+
    labs(x = xlab)+
    labs(y = ylab)
  
  return(toWebGL(ggplotly(p)))
}
