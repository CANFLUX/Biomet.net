# Figure for plotting the cross-correlation between radiation and potential radiation
# By Sara Knox
# Created Oct 28, 2022

# Input
# data = data frame
# rad_var = variable name for radiation variable (either SW_IN_1_1_1 or PPFD_IN_1_1_1)

xcorr_rad <- function(data,rad_var) {
  
  # Calculate statistics
  ccf_obj_rad <- ccf(data$potential_radiation, data[[rad_var]],pl = FALSE)
  
  Find_Max_CCF<- function(a,b)
  {
    d <- ccf(a, b, plot = FALSE)
    cor = d$acf[,,1]
    lag = d$lag[,,1]
    res = data.frame(cor,lag)
    res_max = res[which.max(res$cor),]
    return(res_max)
  }
  
  RAD_CCF <- Find_Max_CCF(data$potential_radiation[is.finite(data$potential_radiation)], data[[rad_var]][is.finite(data[[rad_var]])])
  
  # Plot data
  p_RAD_CCF <- ggCcf(data$potential_radiation, data[[rad_var]])+
    ggtitle(paste0(rad_var," vs Pot Rad, max lag = ",round(RAD_CCF[[2]])," corr = ",round(RAD_CCF[[1]],2)))+
    theme(plot.title = element_text(size = 10))
  p_RAD_CCF 
  
  return(p_RAD_CCF )
}