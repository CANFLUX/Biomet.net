# ------------------------------------------------------------------
# Online visualization of CARBONIQUE data

# June, 2024
# Sara Knox
# sara.knox@mcgill.ca

# Adapted from the Ameriflux data visualization app from
# Sophie Ruehr
# sophie_ruehr@berkeley.edu
# ------------------------------------------------------------------

# To do:
# Add phenocam
# For full dataset figure out what to do when we have multiple met sensors (e.g., TA_1_1_1, TA_1_2_1)
# Missing data plots
# if (grepl("badWD", variables[k])) next #Revisit!
# Fix diagnostics including automatically pulling out SYS variables & deal with different sites 
# Fix scatter plots
# Fix G & GPP in G plot
# Fix H label

# 1. SET UP  -----
# Load libraries
library(ggplot2)
library(dplyr)
library(shiny)
library(patchwork)
library(plotly)
library(gapminder)
library(shinycssloaders)
library(readxl)
library(stringi)
library(shinythemes)
library(cowplot)
library(imager) # had to download quartz to be able to run this library properly (https://www.xquartz.org) & may need to use install.packages("igraph", type="binary")
library(naniar)
library(GGally)
library(shinydashboard)
library(tidyr)
library(tibble)
library(epitools)
library(lubridate)
library(hms)
library(tidyr)
library(forecast)
library(reshape2)
library(stringr)
# reactiveConsole(T) # allows the csv file to be used properly
# “install.packages(“igraph”, type=“binary”) - uncomment if receiving a “there is no package called ‘igraph’” error when loading imager

main_dir <- "/Users/saraknox/Code/local_data_cleaning/Projects/uqam-site/Database"
setwd(main_dir)
# List all directories and subdirectories
dir_list <- list.dirs(main_dir,full.names = TRUE,  
                      recursive = TRUE)

# From that list, get site names
dir_length <- lengths(strsplit(dir_list, "/"))
dir_years <- dir_list[grepl("/\\d{4}$", dir_list)] # directories ending with a year.
dir_sites <- list.dirs(dir_years, full.names = TRUE, recursive = FALSE)
sites <- c("UQAM_1") #unique(sapply(strsplit(dir_sites, "/"), '[[', 8)) 

# Path for met/flux variables to display
basepath <- main_dir
level <- "Clean/ThirdStage" #Update to third stage
tv_input <- "clean_tv"

UnitCSVFilePath <- '/Users/saraknox/Code/shiny_test/flux_variables.csv'

# load all necessary functions
arg <- '/Users/saraknox/Code/shiny_test/'
fx_path <- paste0(arg,'functions',sep ="")
p <- sapply(list.files(fx_path,pattern="*.R$", full.names=TRUE), source)

# 2. FUNCTIONS -----
yrs_included <- 
  function(basepath,
           site,
           level) {
    
    # Find which years are available
    dir_yrs_sites <- dir_sites[grepl(site, dir_sites) == TRUE]
    yrs <- unique(str_extract(dir_yrs_sites, "\\d{4}"))
    
    # Check if level folder exists
    yrs_included <- c()
    for (i in 1:length(yrs)) {
      
      inpath <-
        paste(basepath,
              "/",
              as.character(yrs[i]),
              "/",
              site,
              "/",
              level,
              sep = "")
      
      if (dir.exists(inpath) == TRUE) {
        yrs_included <- c(yrs_included,yrs[i])
      }
    }
    return(yrs_included)
  }

read_data_all_years <-
  function(basepath,
           yrs,
           site,
           level,
           tv_input,
           variables,
           export,
           outpath,
           outfilename) {
    
    # Loop through years
    for (i in 1:length(yrs)) {
      
      inpath <-
        paste(basepath,
              "/",
              as.character(yrs[i]),
              "/",
              site,
              "/",
              level[1],
              sep = "")
      
      #setwd()
      #Convert Matlab timevector to POSIXct
      tv <- readBin(paste0(inpath,"/",tv_input,sep=""), double(), n = 18000)
      datetime <-
        as.POSIXct((tv - 719529) * 86400, origin = "1970-01-01", tz = "UTC")
      
      # Round to nearest 30 min
      datetime <- lubridate::round_date(datetime, "30 minutes")
      
      #setup empty dataframe
      frame <- data.frame(matrix(ncol = 1, nrow = length(datetime)))
      
      # Loop through levels
      for (j in 1:length(level)) {
        inpath <-
          paste(basepath,
                "/",
                as.character(yrs[i]),
                "/",
                site,
                "/",
                level[j],
                sep = "")
        
        #Extract data of interest
        ##Use a loop function to read selected binary files and bind to the empty dataframe
        
        # if variables not defined
        if( !is.null("variables") )
        {
          variables <- list.files(paste0(inpath,"/"))
        }
        
        if (length(variables) != 0) { # Remove?
          for (k in 1:length(variables)) {
            if (variables[k] %in% list.files(inpath)) {
              # If the variable is included in the current level
              
              # Skip the data_EP.txt file and other variables/folders
              if (grepl(".txt$", variables[k])) next 
              if (grepl(".csv$", variables[k])) next 
              if (grepl("clean_tv", variables[k])) next 
              if (grepl("Clean_tv", variables[k])) next 
              if (grepl("DateTime", variables[k])) next 
              if (grepl("TimeVector", variables[k])) next 
              if (grepl("ProcessingSettings.yml", variables[k])) next 
              if (grepl("Clean", variables[k])) next 
              if (grepl("clean", variables[k])) next 
              if (grepl("Manual", variables[k])) next 
              if (grepl("NARR", variables[k])) next
              if (grepl("badWD", variables[k])) next #Revisit!
              
              data <-
                data.frame(readBin(paste0(inpath,"/",variables[k],sep=""), numeric(), n = 18000, size = 4))
              colnames(data) <- variables[k]
              frame <- cbind(frame, data)
            }
          }
        }
      }
      
      df <-
        subset(frame, select = -c(1)) #remove the first column that does not contain information
      df <- cbind(datetime, df) #Combine data with datetime
      
      # Make sure all input variables are included in the dataframe
      if (sum(which(variables %in% colnames(df) == FALSE)) > 0) {
        cat("variables: ", variables[which(variables %in% colnames(df) == FALSE)],"are not included in the dataframe", sep="\n")
      }
      
      if (i == 1) {
        empty_df = df[FALSE, ]
        dfmultiyear <- dplyr::bind_rows(empty_df, df)
      } else {
        dfmultiyear <- dplyr::bind_rows(dfmultiyear, df)
      }
    }
    
    if( !is.null("export") ){
      export <- 0
    }
    
    if (export == 1) {
      write.csv(df, paste(outpath, outfilename, ".csv", sep = ""))
    }
    return(dfmultiyear)
  }

var_units <- function(Variables, UnitCSVFilePath) {
  # -------------------------------------------------------------------------- #
  # ARGUMENTS:
  # - Variables [list]: list of variable names 
  # - UnitCSVFilePath [str]: A string that contains the path to an AmeriFlux
  #   CSV
  # PURPOSE:
  # - matches user-inputted variables to their AmeriFlux Variable and Units 
  #   counterparts.
  # OUTPUT:
  # - returns a dataframe containing the AmeriFlux Varaibles and Units data 
  #   adhering to the user-inputted csv's.
  # -------------------------------------------------------------------------- #
  shortnames <- sapply(strsplit(Variables, split = "(_[0-9])"), '[',1)
  shortnames <- sapply(strsplit(shortnames, split = "_PI"),'[',1)
  
  units <- data.frame(name = Variables,
                      variable = shortnames)
  
  flux_var <- read.csv(UnitCSVFilePath)
  flux_var <- flux_var[, c('Variable',
                           'Units',
                           'Type')]
  
  for (i in 1:length(units$variable)) {
    units$variable[i] <- stringr::str_to_upper(units$variable[i])
  }
  
  data_units <- vector(mode='character',length=length(units$variable))
  for (i in 1:length(units$variable)) {
    
    if (length(which(flux_var$Variable %in% units$variable[i])) > 0) {
      ind <- which(flux_var$Variable %in% units$variable[i])
      data_units[i] <- flux_var$Units[ind]
    }
  }
  
  units$units <- data_units
  return(units)
}

# 3. LOAD DATA ----- 
# Load site data from first site when app initializes 
site <- sites[1]
# Find which years are available
yrs <- yrs_included(basepath,site,level)
data <- read_data_all_years(basepath,yrs,site,level,tv_input)
data_units <- var_units(colnames(data),UnitCSVFilePath)

# select subset of radiation variables and get units
var_rad <- c('SW_IN_1_1_1', 'PPFD_IN_1_1_1') # Remove qualifiers to make more general

# CREATE DATASET TO PLOT ALL SITES AT ONCE
# Only a few variables
var_of_interest <- c('datetime',
                     'FC', 'FCH4', # Ecosystem productivity and C fluxes
                     'VPD', 'RH',  'TA', 'PPFD_IN', 'SW_IN', # Meteorological variables
                     'USTAR', # Atmospheric stability / roughness length approximation (proxy for 'good' EC conditions)
                     'LE','H', 'NETRAD', 'G' # Surface energy balance
)

data_all <- data.frame()

# Loop through all sites to create a dataframe with data from all sites

for (i in 1:length(sites)) {
  # Open data at site
  site <- sites[i]
  
  yrs <- yrs_included(basepath,site,level)
  
  # Load data
  data_in <- read_data_all_years(basepath,yrs,site,level,tv_input)
  
  cols <- colnames(data_in) # Get column names
  
  # remove HVR qualifiers
  vars <- gsub("_[[:digit:]]", "", cols) 
  colnames(data_in) <- vars
  
  # Create empty column for missing variables of interest
  data_in[var_of_interest[!(var_of_interest %in% vars)]] = NA
  
  # Get index of each column of variable of interest
  indexvar <- c()
  for (j in 1:length(var_of_interest)) {
    indexvar[j] <- which(names(data_in) %in% var_of_interest[j])
  }
  indexvar <- na.omit(indexvar)
  
  data_subset <- data_in[,indexvar]
  
  # Add 'site' variable to dataframe
  data_subset$site <- site
  
  # Merge with other sites
  if (i == 1){
    data_all <- data_subset
  } else {data_all <- merge(data_all, data_subset, all = T)
  }
  
  print(unique(data_subset$site))
}

# Define units for plot with all sites
data_units_all <- var_units(colnames(data_all),UnitCSVFilePath)

# X variable names (all sites)
xvars <- var_of_interest
# Y variable names (all sites)
yvars <- var_of_interest[-length(var_of_interest)]

# Load site coordinates
coordinatesCSVFilePath <- '/Users/saraknox/Code/shiny_test/site_coordinates.xlsx'
sites_coordinates <- read_excel(coordinatesCSVFilePath,sheet=1,col_names= TRUE)

# 4. USER INTERFACE ----
ui <- dashboardPage(skin = 'black', # Begin UI 
                    
                    dashboardHeader(title = "CARBONIQUE Data Visualization"),
                    
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
                              
                              shinycssloaders::withSpinner(plotlyOutput('scatter_diagnostics', # For cross correlation plot
                                                                        width = '100%', height = '60%'),
                                                           type = getOption("spinner.type", default = 5),
                                                           color = getOption("spinner.color", default = "dodgerblue")),
                              
                              br(),
                              
                              h5(em('Scatter plots and diagnostics of half-hourly data.'),
                                 align = 'center')
                              
                            ), # End scatter plots tab
                            
                            tabPanel('Diurnal Cycle',
                                     
                                     # CREATE VARIABLE INPUTS 
                                     fluidRow(column(6, selectInput('dicol', 'Variable', names(data[-c(1)])))
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
                                                     
                                                     numericInput(inputId = 'std_merid',
                                                                  label = 'Standard Meridian',
                                                                  min = -180,
                                                                  max = 180,
                                                                  step = 15,
                                                                  value = 0)),
                                              
                                              column(3,
                                                     numericInput(inputId = 'lat',
                                                                  label = 'Latitude',
                                                                  min = -90,
                                                                  max = 90,
                                                                  value = 0)),
                                              
                                              column(3,
                                                     
                                                     numericInput(inputId = 'long',
                                                                  label = 'Longitude',
                                                                  min = -180,
                                                                  max = 180,
                                                                  value = 0))
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
                          h4('About the data'),
                          h5(style="text-align: justify;",
                             'Data displayed with this tool are from the ', tags$a(href="https://carboni-que.github.io/", "CARBONIQUE project.", target="_blank")),
                          
                          br(),
                          h4('About this visualization tool'),
                          h5(style="text-align: justify;", 
                             'This app was modified from the ', tags$a(href="https://ameriflux.shinyapps.io/version1/", "Ameriflux data visualization tool", target="_blank")),
                          h5(style="text-align: justify;",
                             'EDIT: If you are interested in learning more, improving this app, or building one yourself, check out the ', tags$a(href = 'https://shiny.rstudio.com/', 'RShiny package in R', target = 'blank'), ' or contact ', tags$a(href="https://sruehr.github.io/", "Sophie Ruehr.", target = 'blank'), 
                             'Code for this app is available on ', tags$a(href = 'https://github.com/sruehr?tab=repositories', 'GitHub.', target = 'blank')), 
                          br(),
                          h4('Citation'),
                          h5('EDIT: If using any of these tools in publication or presentations, please acknowledge as "AmeriFlux Data Visualization Tool, Sophie Ruehr (2022), 10.5281/zenodo.7023749."'),
                          
                          
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
    
    # Update time series limits
    updateSliderInput(inputId = "range",
                      min = min(data$datetime, na.rm = T),
                      max = max(data$datetime, na.rm = T),
                      value = c(min(data$datetime, na.rm = T),
                                max(data$datetime, na.rm = T)))
    
    # Select data for plots based on user inputs
    selectedData <- reactive({ # Time series plots
      if (length(grep(paste0("\\b",input$tscol,"\\b","_*"), names(data), value=TRUE)) == 0) {
        data[, c("datetime",grep(paste0("\\b",input$tscol,"_*"), names(data), value=TRUE))] # For cases with qualifiers
      } else {
        data[, c("datetime",grep(paste0("\\b",input$tscol,"\\b","_*"), names(data), value=TRUE))] # for cases without qualifiers
      }
    })
    
    if (exists("data_diag")) { # Remove?
      selectedDataDiag <- reactive({ # Diagnostics plots
        data_diag_sub[, c("datetime",grep(paste0(input$diagcol,".*"), names(data_diag_sub), value=TRUE))]  
      })
    }
    
    selectedDatascatter<- reactive({ # Scatter plots
      data[, c(input$onecol, input$twocol)] 
    })
    
    selectedDataDiurnal <- reactive({ # Diurnal plots
      data[, c(input$dicol)] 
    })
    
    selectedDataRadiation <- reactive({ # Radiation diagnostic plots
      data[, c("datetime",input$radcol)] 
    })
    
    # OUTPUTS:  ----- 
    
    # a) Time series plots
    output$timeseries_plots <- renderPlotly({ 
      dat_names <- grep(paste0(input$tscol,"_*"), names(data), value=TRUE)[1] # Get name of variable selected
      ylabel <- paste0(dat_names, ' (', data_units$units[which(data_units$name == dat_names)], ')')
      
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
    
    # b) diagnostics plots
    if (exists("data_diag")) { # Remove?
      output$diagnostics_plots <- renderPlotly({ 
        dat_names <- input$diagcol # Get name of variable selected
        ylabel <- dat_names # Could update this
        
        # Rename variables to remove variable prefix
        df <- selectedDataDiag()
        
        names(df) <- sub(paste0('^',dat_names,'.'), '', names(df))
        
        df.long<-gather(df,variable,value,-datetime)
        
        p2 <- ggplot(df.long,aes(datetime,value,color=variable))+geom_line()+
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
        
        p2 <- ggplotly(p2) # create plotly 
        
      }) # End plot render
    }  
    
    # c) Scatter plots
    output$scatter_plots <- renderPlotly({ 
      y_names <- input$twocol # Get name of variable selected
      ylabel <- y_names # Could update this
      
      x_names <- input$onecol # Get name of variable selected
      xlabel <- x_names # Could update this
      
      df <- selectedDatascatter()
      df$year <- year(data$datetime)
      
      scatter_plot_QCQA(df,xlabel,ylabel, xlabel,ylabel,0)
      
    }) # End plot render
    
    output$scatter_diagnostics <- renderPlotly({ 
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
      
      DataDiurnal <- data.frame(data$datetime)
      colnames(DataDiurnal) <- 'datetime'
      DataDiurnal$Month <- as.numeric(substring(data$datetime, 6, 7))
      DataDiurnal$Hour <- format(data$datetime, format = "%H%M")
      
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
      
      names(df) <- sub(paste0('^',rad_name,'.'), '', names(df))
      
      # Calculate potential radiation
      
      if (grepl("DSM", input$sites, fixed = TRUE) == TRUE){
        df$pot_rad <- potential_rad_generalized(-120, -122.8942, 49.0886, df$datetime,yday(df$datetime))
      } else {
        df$pot_rad <- potential_rad_generalized(input$std_merid, input$long, input$lat, df$datetime,yday(df$datetime))
      }
      
      # Calculate diurnal composite
      diurnal.composite <- diurnal_composite_rad_single_var(df,'pot_rad',rad_name,15,48)
      
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
      
      names(df) <- sub(paste0('^',rad_name,'.'), '', names(df))
      
      # Calculate potential radiation
      df$pot_rad <- potential_rad_generalized(input$std_merid, input$long, input$lat, df$datetime,yday(df$datetime))
      
      # Calculate diurnal composite
      diurnal.composite <- diurnal_composite_rad_single_var(df,'pot_rad',rad_name,15,48)
      #diurnal.composite <- diurnal_composite_rad_single_var[is.finite(diurnal.composite$potential_radiation), ]
      
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

# 6. RUN APP -----
shinyApp(ui = ui, server = server)
