# Figure for data QCQA scatter plot
# By Sara Knox
# Created March 15, 2022

# Input
# data = dataframe with relevant variables
# x = x variable name
# y = y variable name
# year = "year"
# xlab = x label
# ylab = y label
#vis_potential_outliers = 1 for yes, and 0 for no
scatter_plot_QCQA <-
  function(data,
           var1,
           var2,
           xlab,
           ylab,
           vis_potential_outliers) {
    # Create new dataframe with only var1, var2, and year
    df <- (data[, (colnames(data) %in% c(var1, var2, "year"))])
    
    col_order <- c(var1, var2, "year")
    df <- df[, col_order]
    
    df <- na.omit(df)
    colnames(df) <- c("x", "y", "year")
    
    # Create linear models
    nyears <- unique(df$year)
    
    if (length(nyears) == 1) {
      lm.simple <- lm(y ~ x , data = df) #Fit linear model
      best_model <- lm.simple
      
      # Get R2 and slope for linear model
      sumtbl <- summary(lm.simple)
      slope <- sumtbl$coefficients[2]
      r2 <- sumtbl$adj.r.squared
      
      p <- ggplot(df) +
        geom_point(aes(x, y, color = as.factor(year)), alpha = 0.6) +
        geom_smooth(aes(x, y), method = lm, color = 'black') +
        ggtitle(paste(
          "Slope = ",
          as.character(round(slope, 2)),
          ", R2 = ",
          as.character(round(r2, 2))
        )) +
        labs(x = xlab) +
        labs(y = ylab) +
        labs(color = "Year") +
        theme(plot.title = element_text(color = "grey44")) +
        theme(plot.title = element_text(size = 8))
      
    } else {
      lm.interaction <-
        lm(y ~ x * year, data = df) #Fit linear model with year
      lm.simple <- lm(y ~ x , data = df) #Fit linear model
      
      # Find best linear model
      model.comparison <- anova(lm.simple, lm.interaction)
      if (model.comparison[2, "Pr(>F)"] < 0.05) {
        best_model <- lm.interaction
      } else {
        best_model <- lm.simple
      }
      
      # Get R2 for linear model
      sumtbl <- summary(best_model)
      r2 <- sumtbl$adj.r.squared
      
      if (model.comparison[2, "Pr(>F)"] < 0.05) {
        df.model.summary <- df %>%
          group_by(year) %>%
          do({
            mod = lm(y ~ x, data = .)
            data.frame(Intercept = coef(mod)[1],
                       Slope = coef(mod)[2])
          })
      } else {
        slope <- sumtbl$coefficients[2]
      }
      
      p <- ggplot(df) +
        geom_point(aes(x, y, color = as.factor(year)), alpha = 0.6)
      
      if (model.comparison[2, "Pr(>F)"] < 0.05) {
        p <-
          p + geom_smooth(aes(x, y, color = as.factor(year)), method = lm) +
          ggtitle(paste(
            "R2 = ",
            as.character(round(r2, 2)),
            ", year is a significant interaction term"
          )) +
          annotate(
            geom = "table",
            x = floor(max(df$x)),
            y = ceiling(max(df$y)),
            label = list(round(setDT(
              df.model.summary
            ), 2)),
            vjust = 1,
            hjust = 0
          )
        
      } else {
        p <- p + geom_smooth(aes(x, y), method = lm, color = 'black') +
          ggtitle(paste(
            "Slope = ",
            as.character(round(slope, 2)),
            ", R2 = ",
            as.character(round(r2, 2))
          ))
      }
      p <- p + theme(plot.title = element_text(color = "grey44")) +
        theme(plot.title = element_text(size = 8)) +
        labs(x = xlab) +
        labs(y = ylab) +
        labs(color = "Year")
    }
    
    # Identify outliers based on standardized residuals
    # The good thing about standardized residuals is that they quantify how large
    #the residuals are in standard deviation units, and therefore can be easily used to identify outliers (https://online.stat.psu.edu/stat462/node/172/)
    standard_res <- rstandard(lm.simple)
    
    df <- cbind(df, standard_res)
    
    #identify potential outliers - REFINE THIS FURTHER
    
    if (vis_potential_outliers == 1) {
      ind.potential.outliers <-  which(abs(df$standard_res) > 3)
      
      p <- p +
        geom_point(data = df[ind.potential.outliers,],
                   aes(x, y),
                   color = 'black',
                   alpha = 0.6)
      p
    }
    return(toWebGL(ggplotly(p)))
  }
