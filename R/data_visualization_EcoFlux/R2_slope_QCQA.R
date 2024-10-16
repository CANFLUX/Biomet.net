# Figure for comparing the R2 and slope of PPDF_IN vs. SW_IN
# By Sara Knox
# CreatedJanuary 5, 2023

# Input
# data = dataframe with relevant variables
# var1 = variable 1 name
# var2 = variable 2 name

# year = "year"

R2_slope_QCQA <-
  function(data,
           var1,
           var2) {
    
    # Create new dataframe with only var1, var2, and year
    df <- (data[, (colnames(data) %in% c(var1, var2, "year"))])
    
    colnames(df) <- c("y", "x", "year")
    
    # calculate slope and R2 per year 
    if (length(unique(df$year)) == 1) {
      
      # If there's only one year of data
      df.model.summary <- df %>%
        do({
          mod = lm(y ~ x, data = .)
          data.frame(year = df$year[1],
                     Intercept = coef(mod)[1],
                     Slope = coef(mod)[2],
                     R2 = summary(mod)$adj.r.squared)
        })
      
    } else {
      
      # If there's multiple years of data
      df.model.summary <- df %>%
        group_by(year) %>%
        do({
          mod = lm(y ~ x, data = .)
          data.frame(Intercept = coef(mod)[1],
                     Slope = coef(mod)[2],
                     R2 = summary(mod)$adj.r.squared)
        })
    }
    
    # Create plot
    
    scale = 0.5
    
    R2Color = "#69b3a2"
      slopeColor = rgb(0.2, 0.6, 0.9, 1)
      
      p <-   ggplot(df.model.summary, aes(x = year, y = R2)) +
        geom_point(aes(color = "R2")) +
        geom_line(aes(color = "R2"))+
        geom_point(aes(y = Slope/scale, color = "Slope")) +
        geom_line(aes(y = Slope/scale, color = "Slope")) +
        scale_x_continuous(breaks = seq(df.model.summary$year[1], df.model.summary$year[length(df.model.summary$year)], 1)) +
        scale_y_continuous(sec.axis = sec_axis(~.*scale, name="Slope")) +
        labs(x = "Year", y = "R2", color = "") +
        scale_color_manual(values = c(R2Color, slopeColor))+ 
        theme(
          axis.title.y = element_text(color = R2Color, size=13),
          axis.title.y.right = element_text(color = slopeColor, size=13))
      
      return(toWebGL(ggplotly(p)))
  }
