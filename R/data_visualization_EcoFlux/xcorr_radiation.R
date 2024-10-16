# Figure for plotting the cross-correlation between radiation and potential radiation
# By Sara Knox
# Created Oct 28, 2022

xcorr_rad <- function(data) {
  
  # Calculate statistics
  ccf_obj_SW <- ccf(data$potential_radiation, data$SW_IN,pl = FALSE)
  ccf_obj_PPFD <- ccf(data$potential_radiation, data$PPFD_IN,pl = FALSE)
  
  Find_Max_CCF<- function(a,b)
  {
    d <- ccf(a, b, plot = FALSE)
    cor = d$acf[,,1]
    lag = d$lag[,,1]
    res = data.frame(cor,lag)
    res_max = res[which.max(res$cor),]
    return(res_max)
  }
  
  SW <- Find_Max_CCF(data$potential_radiation[is.finite(data$potential_radiation)], data$SW_IN[is.finite(data$SW_IN)])
  PPDF <- Find_Max_CCF(data$potential_radiation[is.finite(data$potential_radiation)], data$PPFD_IN[is.finite(data$PPFD_IN)])
  
  # Plot data
  p_SW <- ggCcf(data$potential_radiation, data$SW_IN)+
    ggtitle(paste0("SW vs Pot Rad, max lag = ",round(SW[[2]])," corr = ",round(SW[[1]],2)))+
    theme(plot.title = element_text(size = 10))
  p_SW 
  
  p_PPFD <- ggCcf(data$potential_radiation, data$PPFD_IN)+
    ggtitle(paste0("PPFD vs Pot Rad, max lag = ",round(PPDF[[2]])," corr = ",round(PPDF[[1]],2)))+
    theme(plot.title = element_text(size = 10))
  p_PPFD 
  
  p <- list(p_SW,p_PPFD)
  return(p)
}