# Figure for assessing offset between measured incoming radiation and potential radiation
# By Sara Knox
# Created Oct 28, 2022

# Input
# data = data frame
# rad_var = variable name for radiation variable (either SW_IN_1_1_1 or PPFD_IN_1_1_1)

PPFDIN_vs_potential_rad <-
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
    
    PPFD <- NA
    for (i in 1:length(date)){
      ind <- which(data$firstdate == date[i])
      data_potential_radiation <- data$potential_radiation[ind]
      data_PPFD <- data[[rad_var]][ind]
      PPFD[i] <- Find_Max_CCF(data_potential_radiation[is.finite(data_potential_radiation)], 
                              data_PPFD[is.finite(data_PPFD)])[[2]]
    }
    
    p2 <- ggplot() +
      geom_point(data = data, aes(x = time, y = potential_radiation*2.5), color = "red",size = 0.5) +
      geom_point(data = data, aes(x = time, y = get(rad_var)), color = "darkcyan",linetype="dashed",size = 0.5) +
      scale_x_datetime(date_labels = "%H")+ylab("PPDF_IN & scaled pot rad (umol m-2 s-1)")+xlab("")+
      ggtitle("Checking for offsets between PPFD_IN (green) and potential radiation (red)")+theme(plot.title = element_text(size=10))+
      facet_wrap(. ~as.factor(firstdate))
    
    dat_text <- data.frame(
      label = paste(as.character(PPFD)," lag",sep= ""),
      firstdate   = date)
    
    p2 <- p2 + geom_text(
      data    = dat_text,
      mapping = aes(x = as.POSIXct(data$time[8],"%H"), y = 2300, label = label),
      size=2)
    
    return(toWebGL(ggplotly(p2))) 
  }
