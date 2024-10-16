# Figure for data QCQA scatter plot for energy balance closure
# By Sara Knox
# Created Jan 22, 2023

# Input
# data = dataframe with relevant variables
# var1 = variables names for available energy (AE, ie. NETRAD, G, etc)
# var2 = variables names for turbulent fluxes (TF, i.e., H+LE)
# xlab = x label
# ylab = y label
scatter_plot_QCQA_EBC <-
  function(data,
           var1,
           var2,
           xlab,
           ylab) {
    
    # Create new dataframe with only var1, var2, and year
    df <- (data[, (colnames(data) %in% c(var1, var2, "year"))]) # Here we need all variable to have a value (ie., , na.rm=FALSE)
    
    # create df with a column ofr available energy (AE, i.e., NETRAD-Storage terms) & one for turbulent fluxes (TF, ie., H+LE)
    df <- df %>%
      mutate(AE = rowSums(across(var1)),
             TF = rowSums(across(var2))) # Turbulent fluxes
    
    # Create linear models
    nyears <- unique(df$year)
    
    lm.interaction <-
      lm(TF ~ AE * year, data = df) #Fit linear model with year
    
    # Get R2 for linear model
    sumtbl <- summary(lm.interaction)
    r2 <- sumtbl$adj.r.squared
    
    # Calculate statistics per year
    df.model.summary <- df %>%
      group_by(year) %>%
      do({
        mod = lm(TF ~ AE, data = .)
        data.frame(Intercept = coef(mod)[1],
                   Slope = coef(mod)[2],
                   R2 = summary(mod)$adj.r.squared)
      })
    
    p <- ggplot(df) +
      geom_point(aes(AE, TF, color = as.factor(year)), alpha = 0.6) +
      geom_smooth(aes(AE, TF, color = as.factor(year)), method = lm) +
      annotate(
        geom = "table",
        x = floor(max(df$AE,na.rm = T))-200,
        y = floor(min(df$TF,na.rm = T))+200,
        label = list(round(setDT(
          df.model.summary
        ), 2)),
        vjust = 1,
        hjust = 0
      ) + ylab(ylab) + xlab(xlab)
    
    return(p)
  }
