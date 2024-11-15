# ------------------------------------------------------------------
# June, 2024
# Sara Knox
# sara.knox@mcgill.ca

# Adapted from the Ameriflux data visualization app from
# Sophie Ruehr
# sophie_ruehr@berkeley.edu
# ------------------------------------------------------------------

# To do:
# Add year to radiation plots
# Add Ameriflux limits to plots
# For full dataset figure out what to do when we have multiple met sensors (e.g., TA_1_1_1, TA_1_2_1)
# Could update scatter plot labels
# Add phenocam
# Revisit WD

# 1. SET UP  -----
# Load data from tmp folder
load("data_tmp/all_data.RData")

# 3. USER INTERFACE ----
ui <- dashboardPage(skin = 'black', # Begin UI 
                    
                    dashboardHeader(title = "Data Visualization Tool"),
                    
                    dashboardSidebar(sidebarMenu(
                      menuItem("Individual sites", tabName = "indiv"),
                      menuItem("All sites", tabName = "all"),
                      menuItem("About", tabName = "about")
                    )), # End dashboard sidebar
                    
                    
                    dashboardBody( # Begin dashboard body
                      
                      # Suppress warnings
                      tags$style(type="text/css",
                                 ".shiny-output-error { visibility: hidden; }",
                                 ".shiny-output-error:before { visibility: hidden; }"),
                      
                      tabItems(
                        tabItem( # Begin 'Individual Sites' page
                          h1('Individual sites'),
                          
                          tabName = "indiv",
                          # Select site from dropdown list
                          selectInput('sites', 'Select site', sites,
                                      multiple = F),
                          
                          # 1. Site information (main panel)
                          
                          br(), br(),
                          
                          tabsetPanel( # Begin tab panels section
                            
                            tabPanel( # Begin time series tab
                              "Time series",
                              
                              br(),
                              
                              # Select main variable
                              fluidRow( column(6, selectInput('tscol', 'Variable', names(data[-c(1)]))),
                                        
                                        # Select date range for time series
                                        column(12,  sliderInput(inputId = "range", width = '80%',
                                                                label = "Date range",
                                                                min = min(data$datetime, na.rm = T),
                                                                max = max(data$datetime, na.rm = T),
                                                                value = c(min(data$datetime, na.rm = T),
                                                                          max(data$datetime, na.rm = T))))),
                              br(),
                              
                              # Ouput time series plot with a spinner
                              shinycssloaders::withSpinner(plotlyOutput('timeseries_plots'),
                                                           type = getOption("spinner.type", default = 5),
                                                           color = getOption("spinner.color", default = "#4D90FE")),
                              h5(em('Plot shows 30-min data'), align = 'center')
                              
                            ), # End time series tab 
                            
                            tabPanel( # Begin scatter plots and diagnostics
                              "Scatter plots",
                              
                              br(),
                              
                              fluidRow(column(6, # Make both inputs on same row
                                              # Input first (one) variable for scatter plot                               
                                              selectInput('onecol', 'First variable', names(data[-c(1)]))),
                                       column(6, 
                                              # Input second (two) variable for scatter plot 
                                              selectInput('twocol', 'Second variable', names(data[-c(1:2)])))),
                              br(),
                              
                              # Output scatter and density plots
                              shinycssloaders::withSpinner(plotlyOutput('scatter_plots', # For diurnal plot
                                                                        width = '100%', height = '60%'),
                                                           type = getOption("spinner.type", default = 5),
                                                           color = getOption("spinner.color", default = "dodgerblue")),
                              
                              shinycssloaders::withSpinner(plotOutput('scatter_diagnostics', # For cross correlation plot
                                                                      width = '100%', height = "400px")),
                              # type = getOption("spinner.type", default = 5),
                              # color = getOption("spinner.color", default = "dodgerblue")),
                              
                              br(),
                              
                              h5(em('Scatter plots and diagnostics of half-hourly data.'),
                                 align = 'center')
                              
                            ), # End scatter plots tab
                            
                            tabPanel('Diurnal Cycle',
                                     
                                     # CREATE VARIABLE INPUTS 
                                     fluidRow(column(6, selectInput('dicol', 'Variable', names(data[-c(1)]))),
                                              # Select date range for time series
                                              column(12,  sliderInput(inputId = "range", width = '80%',
                                                                      label = "Date range",
                                                                      min = min(data$datetime, na.rm = T),
                                                                      max = max(data$datetime, na.rm = T),
                                                                      value = c(min(data$datetime, na.rm = T),
                                                                                max(data$datetime, na.rm = T))))        
                                     ), # END FLUID ROW 
                                     
                                     # OUTPUT DIURNAL PLOTS (W/ SPINNER)
                                     shinycssloaders::withSpinner(plotlyOutput('diurnal', 
                                                                               width = '100%', height = '60%'),
                                                                  type = getOption("spinner.type", default = 5),
                                                                  color = getOption("spinner.color", default = "dodgerblue")),
                                     
                                     br(),
                                     
                                     h5(em('Plot shows mean (black line) and +- one standard deviation (shading) of half-hourly data by month.'), 
                                        align = 'center')
                                     
                            ), # End diurnal cycle tab
                            
                            tabPanel('Radiation Diagnostics',
                                     
                                     # CREATE VARIABLE INPUTS 
                                     fluidRow(column(3, selectInput('radcol', 'Variable', var_rad)),
                                              column(3, 
                                                     # Input second (two) variable for scatter plot 
                                                     selectInput('site_yr', 'Year', yrs))
                                     ), # END FLUID ROW 
                                     
                                     # OUTPUT RADIATION PLOTS
                                     shinycssloaders::withSpinner(plotlyOutput('radiation1', # For diurnal plot
                                                                               width = '100%', height = '60%'),
                                                                  type = getOption("spinner.type", default = 5),
                                                                  color = getOption("spinner.color", default = "dodgerblue")),
                                     
                                     shinycssloaders::withSpinner(plotlyOutput('radiation2', # For cross correlation plot
                                                                               width = '100%', height = '60%'),
                                                                  type = getOption("spinner.type", default = 5),
                                                                  color = getOption("spinner.color", default = "dodgerblue")),
                                     
                                     br(),
                                     
                                     h5(em('Plot shows mean diurnal radiation pattern and cross correlation between measured radiation and potential radiation'), 
                                        align = 'center')
                                     
                            ) # End radiation diagnostics tab
                          ) # End tab panels section
                        ), # End 'Individual Sites' page
                        
                        tabItem( # Begin 'All Sites' page
                          tabName = "all",
                          h1('All sites'),
                          
                          # Select inputs for plot
                          fluidRow( column(4, selectInput('xcol_all', 'X-axis variable', xvars)), 
                                    column(4, selectInput('ycol_all', 'Y-axis variable', yvars)),
                                    
                                    br(),  br(),  br(), br(),  br(),
                                    
                                    # Output plot
                                    shinycssloaders::withSpinner(plotlyOutput('all_plots', 
                                                                              width = '100%',  height = '100%'),
                                                                 type = getOption("spinner.type", default = 5)),
                                    inline = TRUE,
                                    
                                    br()
                          ), # End 'All Sites' page
                        ), # End tab panels section
                        
                        tabItem( # Begin 'About' page
                          tabName = 'about',
                          
                          # Informational text 
                          #h4('About the data'),
                          #h5(style="text-align: justify;",
                          #   'Data displayed with this tool are from the ', tags$a(href="https://carboni-que.github.io/", "CARBONIQUE project.", target="_blank")),
                          
                          br(),
                          h4('About this visualization tool'),
                          h5(style="text-align: justify;", 
                             'This app was modified from the ', tags$a(href="https://ameriflux.shinyapps.io/version1/", "Ameriflux data visualization tool", target="_blank")),
                          h5(style="text-align: justify;",
                             'EDIT: If you are interested in learning more, improving this app, or building one yourself, check out the ', tags$a(href = 'https://shiny.rstudio.com/', 'RShiny package in R', target = 'blank'), ' or contact ', tags$a(href="https://sruehr.github.io/", "Sophie Ruehr.", target = 'blank'), 
                             'Code for this app is available on ', tags$a(href = 'https://github.com/sruehr?tab=repositories', 'GitHub.', target = 'blank')), 
                          #br(),
                          #h4('Citation'),
                          #h5('TBD'),
                          
                          
                          br(),
                          h4('Acknowledgements'),
                          h5(style="text-align: justify;",
                             'This application was developed by Sara Knox based on the original code by Sophie Ruehr, which is available is available on ', tags$a(href = 'https://github.com/sruehr?tab=repositories', 'GitHub.', target = 'blank')), 
                          
                        ) # End 'About' page
                      ), # End all pages         
                      hr(),
                      h5('App designed and developed by Sara Knox, 2024.')
                    ) # End dashbard body
) # End UI

# 4. Server
server <- function(input, output, session) { # Begin server
  
  observeEvent(input$sites, { # Change output based on site selection
    
    # Update data 
    yrs <- yrs_included(basepath,input$sites,level)
    data <- read_data_all_years(basepath,yrs,input$sites,level,tv_input)
    data_units <- var_units(colnames(data),UnitCSVFilePath)
    
    # Update Y variable (time series) - find unique variable names
    names_data <- names(data)
    names_data_unique <- unique(gsub("_[[:digit:]]", "",names_data))  
    
    updateSelectInput(session, 'tscol', choices = names_data_unique[-1])
    
    # Update X variable (scatter plot)
    updateSelectInput(session, 'onecol', choices = names(data[-c(1)]))
    
    # Update Y variable (scatter plot)
    updateSelectInput(session, 'twocol',choices = names(data[,-c(1,2)]))
    
    # Update Y variable (diurnal)
    updateSelectInput(session, 'dicol', choices = names(data[-c(1)]))
    
    # Update Y variable (radiation diagnostics)
    updateSelectInput(session, 'radcol', choices = var_rad)
    
    # Update year (radiation diagnostics)
    updateSelectInput(session, 'site_yr',choices = yrs)
    
    # Update time series limits
    updateSliderInput(inputId = "range",
                      min = min(data$datetime, na.rm = T),
                      max = max(data$datetime, na.rm = T),
                      value = c(min(data$datetime, na.rm = T),
                                max(data$datetime, na.rm = T)))
    
    # Select data for plots based on user inputs
    selectedData <- reactive({ # Time series plots
      if (length(grep(paste0("\\b",input$tscol,"\\b","_*"), names(data), value=TRUE)) == 0) {
        data[, c("datetime",grep(paste0("^",input$tscol,"_"), names(data), value=TRUE))] # For cases with qualifiers
      } else {
        data[, c("datetime",grep(paste0("\\b",input$tscol,"\\b","_*"), names(data), value=TRUE))] # for cases without qualifiers
      }
    })
    
    selectedDatascatter<- reactive({ # Scatter plots
      data[, c(input$onecol, input$twocol)] 
    })
    
    selectedDataDiurnal <- reactive({ # Diurnal plots
      data[(data$datetime >= input$range[1]) & (data$datetime <= input$range[2]), c(input$dicol)] 
    })
    
    selectedDataRadiation <- reactive({ # Radiation diagnostic plots
      data[, c("datetime",input$radcol)] 
    })
    
    # OUTPUTS:  ----- 
    
    # a) Time series plots
    output$timeseries_plots <- renderPlotly({ 
      
      if (length(grep(paste0("\\b", input$tscol, "\\b", "_*"), names(data), value = TRUE)) == 0) {
        dat_names <- grep(paste0("^", input$tscol, "_"), names(data), value = TRUE)[1] # Get name of variable selected
        ylabel <- paste0(dat_names, ' (', data_units$units[which(data_units$name == dat_names)], ')')
      } else {
        dat_names <- grep(paste0("\\b", input$tscol, "\\b", "_*"), names(data), value = TRUE)[1] # Get name of variable selected
        ylabel <- paste0(dat_names, ' (', data_units$units[which(data_units$name == dat_names)], ')')
      }
      
      df.long<-gather(selectedData(),variable,value,-datetime)
      
      p1 <- ggplot(df.long,aes(datetime,value,color=variable))+geom_point(alpha = 0.3, size = 0.5)+
        theme_bw() + # plot theme
        theme(text=element_text(size=20), #change font size of all text
              axis.text=element_text(size=15), #change font size of axis text
              axis.title=element_text(size=12), #change font size of axis titles
              plot.title=element_text(size=20), #change font size of plot title
              legend.text=element_text(size=8), #change font size of legend text
              legend.title=element_text(size=8),
              plot.margin = margin(t = 20,  # Top margin
                                   r = 30,  # Right margin
                                   b = 30,  # Bottom margin
                                   l = 30)) + # Left margin +
        ylab(ylabel) +
        xlab('Date')  + # relabl X axis
        xlim(input$range[1], input$range[2]) # change date limits to user input 
      
      # Remove legend if there aren't multiple variables
      if (length(selectedData())<=2){
        p1 <- p1 + theme(legend.position="none")
      }
      p1 <- ggplotly(p1) %>% toWebGL()  # create plotly 
    }) # End plot render
    
    # b) diagnostics plots - Could add later
    
    # c) Scatter plots
    output$scatter_plots <- renderPlotly({ 
      y_names <- input$twocol # Get name of variable selected
      ylabel <- y_names # Could update this
      
      x_names <- input$onecol # Get name of variable selected
      xlabel <- x_names # Could update this
      
      df <- selectedDatascatter()
      df$year <- year(data$datetime) 
      
      scatter_plot_QCQA(df,xlabel,ylabel, xlabel,ylabel,1)
      
    }) # End plot render
    
    output$scatter_diagnostics <- renderPlot({ 
      y_names <- input$twocol # Get name of variable selected
      ylabel <- y_names # Could update this
      
      x_names <- input$onecol # Get name of variable selected
      xlabel <- x_names # Could update this
      
      df <- selectedDatascatter()
      df$year <- year(data$datetime) 
      
      R2_slope_QCQA(df,xlabel,ylabel)
      
    }) # End plot render
    
    # d) Diurnal plot
    output$diurnal <- renderPlotly({ 
      
      dat_names <- input$dicol # Get name of variable selected
      ylabel <- paste0(dat_names, ' (', data_units$units[which(data_units$name == dat_names)], ')')
      
      dt <- data$datetime[(data$datetime >= input$range[1]) & (data$datetime <= input$range[2])]
      DataDiurnal <- data.frame(dt)
      colnames(DataDiurnal) <- 'datetime'
      DataDiurnal$Month <- as.numeric(substring(dt, 6, 7))
      DataDiurnal$Hour <- format(dt, format = "%H%M")
      
      DataDiurnal$Var <- selectedDataDiurnal()
      
      data_diurnal <- DataDiurnal %>% group_by(Month, Hour) %>% summarise(Average = mean(Var, na.rm=TRUE))
      data_diurnal$Hour <- as.numeric(data_diurnal$Hour)
      
      var_sd <- sd(data_diurnal$Average, na.rm = TRUE)
      data_diurnal$UppSD <- data_diurnal$Average + var_sd
      data_diurnal$LowSD <- data_diurnal$Average - var_sd
      
      month_labs <- c('1' = 'January', '2' = 'February', '3' = 'March',
                      '4' = 'April', '5' = 'May', '6' = 'June',
                      '7' = 'July', '8' = 'August', '9' = 'September',
                      '10' = 'October', '11' = 'November', '12' = 'December')
      
      month_labeller <- labeller(Month = function(levels) month_labs[as.character(levels)])
      
      diurnal_plot <- ggplot(data = data_diurnal,
                             aes(x = Hour, y = Average)) +
        geom_line() +
        geom_ribbon(aes(ymax = UppSD, ymin = LowSD),colour = NA,
                    col = 'dodgerblue4', fill = 'dodgerblue4', alpha = 0.3) +
        facet_wrap(~ Month, ncol = 4, 
                   labeller = month_labeller) +
        scale_x_continuous(breaks = c(0, 600, 1200, 1800, 2330),
                           labels = c("00:00", "06:00", "12:00", "18:00","24:00")) +
        scale_y_continuous(limits = c(min(data_diurnal$LowSD),
                                      max(data_diurnal$UppSD))) +
        theme_minimal()+
        theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))+
        xlab("Hour:Minute")+
        ylab(ylabel)+
        theme(panel.spacing.x = unit(3, "mm"),
              panel.spacing.y = unit(6, "mm"),
              strip.placement = "outside",
              strip.background = element_blank())
      
      ggplotly(diurnal_plot)  # Set tooltip to display the custom text
      
    }) # End plot render
    
    # e) radiation plots
    output$radiation1 <- renderPlotly({ 
      rad_name <- input$radcol # Get name of variable selected
      #ylabel <- rad_names # Could update this
      
      # Rename variables to remove variable prefix
      df <- selectedDataRadiation()
      
      df <- df[year(df$datetime) == as.numeric(input$site_yr), ]
      
      names(df) <- sub(paste0('^',rad_name,'.'), '', names(df))
      
      # Calculate potential radiation
      sites_coordinates_filtered <-  sites_coordinates[sites_coordinates['Site'] == input$sites, ] # extra standard meridian/lat/long from excel file
      df$pot_rad <- potential_rad_generalized(as.numeric(sites_coordinates_filtered$Standard_Meridian), as.numeric(sites_coordinates_filtered$Longitude), as.numeric(sites_coordinates_filtered$Latitude), df$datetime,yday(df$datetime))
      
      # Calculate diurnal composite
      diurnal.composite <- diurnal_composite_rad_single_var(df,'pot_rad',rad_name,15,48)
      
      # Summarize data to filter out dates where diurnal composite has all -Inf values
      df_summary <- diurnal.composite %>%
        group_by(firstdate) %>%
        summarize(rad_na_count = sum(is.na(!!sym(rad_name))), # find number of -Inf values for rad var
                  count = n())                                 # Count number of observations per date
      
      # Remove dates with only -Inf points
      keep <- df_summary %>%
        filter(rad_na_count != count) 
      
      diurnal.composite <- diurnal.composite[diurnal.composite$firstdate %in% keep$firstdate, ]
      
      if (grepl("SW_IN", rad_name, fixed = TRUE) == TRUE) {
        p_rad_dirnal <- SWIN_vs_potential_rad(diurnal.composite,rad_name)} else {
          p_rad_dirnal <- PPFDIN_vs_potential_rad(diurnal.composite,rad_name)
        }
    }) # End plot render
    
    output$radiation2 <- renderPlotly({ 
      rad_name <- input$radcol # Get name of variable selected
      #ylabel <- rad_names # Could update this
      
      # Rename variables to remove variable prefix
      df <- selectedDataRadiation()
      
      df <- df[year(df$datetime) == as.numeric(input$site_yr), ]
      
      names(df) <- sub(paste0('^',rad_name,'.'), '', names(df))
      
      # Calculate potential radiation
      sites_coordinates_filtered <-  sites_coordinates[sites_coordinates['Site'] == input$sites, ] # extra standard meridian/lat/long from excel file
      df$pot_rad <- potential_rad_generalized(as.numeric(sites_coordinates_filtered$Standard_Meridian), as.numeric(sites_coordinates_filtered$Longitude), as.numeric(sites_coordinates_filtered$Latitude), df$datetime,yday(df$datetime))
      
      # Calculate diurnal composite
      diurnal.composite <- diurnal_composite_rad_single_var(df,'pot_rad',rad_name,15,48)
      #diurnal.composite <- diurnal_composite_rad_single_var[is.finite(diurnal.composite$potential_radiation), ]
      
      # Summarize data to filter out dates where diurnal composite has all -Inf values
      df_summary <- diurnal.composite %>%
        group_by(firstdate) %>%
        summarize(rad_na_count = sum(is.na(!!sym(rad_name))), # find number of -Inf values for rad var
                  count = n())                                 # Count number of observations per date
      
      # Remove dates with only -Inf points
      keep <- df_summary %>%
        filter(rad_na_count != count) 
      
      diurnal.composite <- diurnal.composite[diurnal.composite$firstdate %in% keep$firstdate, ]
      
      xcorr_rad(diurnal.composite,rad_name)
    }) # End plot render
    
  }) 
  
  # e) All sites plot
  output$all_plots <- renderPlotly({ 
    xlab <- paste(input$xcol_all)
    ylab <- paste(input$ycol_all)
    
    if(xlab != 'datetime') {
      dat_names <- xlab # Get name of variable selected
      xlab <- paste0(dat_names, ' (', data_units_all$units[which(data_units_all$name == dat_names)], ')')
    }
    
    dat_names2 <- ylab
    ylab <- paste0(dat_names2, ' (', data_units_all$units[which(data_units_all$name == dat_names2)], ')')
    
    p3 <- ggplot(data_all) +
      geom_point(aes(x = .data[[input$xcol_all]],
                     y = .data[[input$ycol_all]],
                     color = .data[['site']],
                     group = .data[['site']]),
                 na.rm = T, alpha = 0.3, size = 0.5) + # color of line
      theme_bw() + # plot theme
      theme(text=element_text(size=20), #change font size of all text
            axis.text=element_text(size=15), #change font size of axis text
            axis.title=element_text(size=15), #change font size of axis titles
            plot.title=element_text(size=20), #change font size of plot title
            legend.text=element_text(size=8), #change font size of legend text
            legend.title=element_text(size=10)) +
      xlab(xlab) +
      ylab(ylab)
    
    p3 <- ggplotly(p3) %>% toWebGL() 
  }) # End all sites plot
  
}# End server

# 5. RUN APP -----
shinyApp(ui = ui, server = server)
