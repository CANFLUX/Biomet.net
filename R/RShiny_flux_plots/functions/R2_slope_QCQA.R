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
    
    # Replace any NA values with NaN
    data <- data %>%
      mutate(across(everything(), ~ replace(., is.na(.), NaN)))
    
    # Create year column if doesn't exist
    if ("year" %in% colnames(data)) {
      df <- (data[, (colnames(data) %in% c(var1, var2, "year"))])
    } else {
      data$year <- as.numeric(format(data$datetime, "%Y"))
      df <- (data[, (colnames(data) %in% c(var1, var2, "year"))])
    }
    
    if (var1 == var2) {
      df <- data.frame(df[, 1],df)
    }
    
    colnames(df) <- c("y", "x", "year")
    
    # calculate slope and R2 per year 
    if (length(unique(df$year)) == 1 | length(df$year[df$year == unique(df$year)[2]]) == 1) {
      
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
      
      # Summarize data
      df_summary <- df %>%
        group_by(year) %>%
        summarize(nan_x = sum(is.nan(x)),  # find number of NaN values for x
                  nan_y = sum(is.nan(y)),  # find number of NaN values for x
            count = n()                    # Count number of observations per date
          )
        
      # Remove any years with only one data point
      years_to_keep <- df_summary %>%
        filter(count > 1 & (nan_y != count) & (nan_x != count)) 
      
      df <- df %>%
        filter(year %in% years_to_keep$year) 
      
      # Now calculate R2 and slope for each year
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
        geom_point(aes(color = "R2"), size = 3) +
        geom_line(aes(color = "R2"))+
        geom_point(aes(y = Slope/scale, color = "Slope"),size = 3) +
        geom_line(aes(y = Slope/scale, color = "Slope")) +
        scale_x_continuous(breaks = seq(df.model.summary$year[1], df.model.summary$year[length(df.model.summary$year)], 1)) +
        scale_y_continuous(
          name = "R2",  # Label for the primary y-axis
          sec.axis = sec_axis(~ . * scale, name = "Slope")  # Adjust the range and label for the secondary y-axis
        ) +
        labs(x = "Year", color = "") +
        scale_color_manual(values = c(R2Color, slopeColor))+ 
        theme(
          axis.title.y = element_text(color = R2Color, size=14),
          axis.title.y.right = element_text(color = slopeColor, size=14),
          axis.title.x = element_text(size = 14),
          axis.text.x = element_text(size = 14),
          axis.text.y = element_text(size = 14),
          axis.text.y.right = element_text(size = 14),
          legend.position = "bottom",
          legend.direction = "horizontal")
      
      return(p)
  }
