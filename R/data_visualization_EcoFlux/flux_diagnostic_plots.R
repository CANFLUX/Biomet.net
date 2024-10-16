# Figure for plotting flux diagnostics
# By Sara Knox
# Jan 22, 2023

# Input
# data = dataframe with relevant variables
# 
flux_diagnostic_plots <- function(data,vars_flux_diag_signal_strength,vars_flux_diag_records,vars_flux_diag_flowrate){
  
  plots <- plot.new()
  
  # signal strengths
  df_SS <- data[,c("datetime",vars_flux_diag_signal_strength)]
  yaxlabel <- "Signal strength"
  SS_plot <- plotly_loop(df_SS,vars_flux_diag_signal_strength,yaxlabel)
  
  plots[[1]] <- SS_plot
  
  # records
  df_recs <- data[,c("datetime",vars_flux_diag_records)]
  yaxlabel <- "number of records"
  Rec_plot <- plotly_loop(df_recs,vars_flux_diag_records,yaxlabel)
  
  plots[[2]] <- Rec_plot
  
  if (grepl("flowrate", vars_flux_diag_flowrate) == TRUE) {
    # flow rate
    df_flowrate <- data[,c("datetime",vars_flux_diag_flowrate)]
    yaxlabel <- "Flow rate (L/m)"
    FR_plot <- plot_ly(df_flowrate, x = ~datetime, y = as.formula(paste0("~", vars_flux_diag_flowrate))) %>%
      add_lines(name = vars_flux_diag_flowrate)%>% 
      layout(yaxis = list(title = vars_flux_diag_flowrate,range = c(-1,20)))%>%
      toWebGL()
    
    plots[[3]] <- FR_plot
  }
  
  p <- subplot(plots, nrows = length(plots), shareX = TRUE, titleX = FALSE,titleY = TRUE)%>% layout(legend = list(orientation = 'h'))
  return(p)
}