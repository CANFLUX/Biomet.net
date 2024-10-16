# Create plot_ly figure for multivariate comparison of long-term trend or step change
# By Sara Knox
# Created July 3, 2022

# Input
# df = dataframe with the variables year, R2, and slope

multivariate_comparison_trend <- function(df) {
  fig <- plot_ly()
  
  # Add traces
  fig <-
    fig %>% add_trace(
      data = df,
      x = ~ year,
      y = ~ R2,
      name = "R2",
      mode = "lines+markers",
      type = "scatter"
    )
  
  ay <- list(
    tickfont = list(color = "black"),
    overlaying = "y",
    side = "right",
    title = "Slope"
  )
  
  fig <-
    fig %>% add_trace(
      x = ~ year,
      y = ~ slope,
      name = "slope",
      yaxis = "y2",
      mode = "lines+markers",
      type = "scatter"
    )
  
  # Set figure title, x and y-axes titles
  fig <- fig %>% layout(
    yaxis2 = ay,
    xaxis = list(title = "year"),
    yaxis = list(title = "R2")
  ) %>%
    layout(
      plot_bgcolor = '#e5ecf6',
      xaxis = list(
        zerolinecolor = '#ffff',
        zerolinewidth = 2,
        gridcolor = 'ffff',
        dtick = 1,
        tickmode = "linear"
      ),
      yaxis = list(
        zerolinecolor = '#ffff',
        zerolinewidth = 2,
        gridcolor = 'ffff'
      )
    )
    
  fig
  return(fig)
}
