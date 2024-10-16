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
    
    # Create year column if doesn't exist
    if ("year" %in% colnames(data)) {
      df <- (data[, (colnames(data) %in% c(var1, var2, "year"))])
    } else {
      data$year <- as.numeric(format(data$datetime, "%Y"))
      df <- (data[, (colnames(data) %in% c(var1, var2, "year"))])
    }
    
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
        geom_point(aes(x, y)) +
        geom_smooth(aes(x, y), method = lm, color = 'black') +
        scale_x_continuous(limits = c(0, max(df$x))) +  # Set x-axis limits
        scale_y_continuous(limits = c(0, max(df$y))) +  # Set y-axis limits
        labs(x = xlab) +
        labs(y = ylab) +
        theme(plot.title = element_text(color = "grey44")) +
        theme(plot.title = element_text(size = 8)) +
        ggtitle(paste(
          "Slope = ",
          as.character(round(slope, 2)),
          ", R2 = ",
          as.character(round(r2, 2))
        ))
      
    } else {
      lm.simple <- lm(y ~ x, data = df) #Fit linear model with all data
      #lm.withyear <- lm(y ~ x + year, data = df) #Fit linear model with year
      lm.interaction <-
        lm(y ~ x * year, data = df) #Fit linear model with year as interaction
      
      # Find best linear model based on AIC
      aic_values <- AIC(lm.simple, lm.interaction)
      select_best_model <- which.min(aic_values$AIC)
      
      if (select_best_model == 1) {
        best_model <- lm.simple
      } #else if (select_best_model == 2) {
        #best_model <- lm.withyear
      #} 
      else {
        best_model <- lm.interaction
      }
      
      # Get R2 for linear model
      sumtbl <- summary(best_model)
      r2 <- sumtbl$adj.r.squared
      
      if (select_best_model == 2) { # Update number if using more models
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
        geom_point(aes(x, y, color = as.factor(year)), alpha = 0.6) +
        scale_x_continuous(limits = c(0, max(df$x))) +  # Set x-axis limits
        scale_y_continuous(limits = c(0, max(df$y)))    # Set y-axis limits
      
      if (select_best_model == 2) {
        df.model.summary$year <- as.numeric(df.model.summary$year)
        
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
    
    # Identify outliers based
    
    #identify potential outliers - REFINE THIS FURTHER
    
    if (vis_potential_outliers == 1) {
      
      model <- lm(y ~ x, data = df)
      
      # Calculate Cook's Distance
      df$cooksd <- cooks.distance(model)
      
      # Flag influential points (e.g., Cook's Distance > 4/n)
      df$influential <- df$cooksd > (4 / nrow(df))
      
      # Plot with Cook's Distance and influential points
      p2 <- ggplot(df, aes(x = x, y = y)) +
        geom_point(aes(color = influential)) +
        scale_color_manual(values = c("black", "red")) +
        ggtitle("Scatter Plot with Influential Outliers (Cook's Distance)") +
        theme_minimal()

      p2
    }
    return(toWebGL(ggplotly(p)))
  }
