# Figure for assessing offset between measured incoming radiation and potential radiation
# By Sara Knox
# Created Oct 28, 2022

# Input
# data = data frame
# rad_var = variable name for radiation variable (either SW_IN_1_1_1 or PPFD_IN_1_1_1)

SWIN_vs_potential_rad <-
  function(data,rad_var) {
    
    # Calculate cross correlation for each date
    date <- unique(data$firstdate)
    
    Find_Max_CCF<- function(a,b)
    {
      d <- ccf(a, b, plot = FALSE)
      cor = d$acf[,,1]
      lag = d$lag[,,1]
      res = data.frame(cor,lag)
      res_max = res[which.max(res$cor),]
      return(res_max)
    }
    
    SW <- NA
    for (i in 1:length(date)){
      ind <- which(data$firstdate == date[i])
      data_potential_radiation <- data$potential_radiation[ind]
      data_SW <- data[[rad_var]][ind]
      SW[i] <- Find_Max_CCF(data_potential_radiation[is.finite(data_potential_radiation)], 
                              data_SW[is.finite(data_SW)])[[2]]
    }
    
    p1 <- ggplot() +
      geom_point(data = data, aes(x = time, y = potential_radiation), color = "red",size = 0.5) +
      geom_point(data = data, aes(x = time, y = get(rad_var)), color = "steelblue",linetype="dashed",size = 0.5) +
      geom_point(data = data, aes(x = time, y = exceeds), color = "black",size = 0.75)+
      scale_x_datetime(date_labels = "%H")+ylab("SW_IN & Pot rad (W/m2)")+xlab("")+
      ggtitle("Checking for offsets between SW_IN (blue) and potential radiation (red)")+theme(plot.title = element_text(size=10))+
      facet_wrap(. ~as.factor(firstdate))
    
    dat_text <- data.frame(
      label = paste(as.character(SW)," lag",sep= ""),
      firstdate   = date)
    
    p1 <- p1 + geom_text(
      data    = dat_text,
      mapping = aes(x = as.POSIXct(data$time[8],"%H"), y = 1200, label = label),
      size=2)
    
    return(toWebGL(ggplotly(p1))) 
  }