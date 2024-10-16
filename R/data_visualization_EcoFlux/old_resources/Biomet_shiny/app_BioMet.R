# ----
# UBC BioMet.net Shiny Visualization App
# A Shiny app to visualize User-Inputted Flux Data
#  * Following Ameriflux Template provided by Sophie Ruehr (sophie_ruehr@berkeley.edu)

# June 30, 2023
# Author: Kelsey McGuire (Supervised by Dr. Sara Knox)
# kmcgu@mail.ubc.ca; sknox01@mail.ubc.ca
# ----

# 1. SET UP  -----
# Load libraries
library(dplyr)
library(ggplot2)
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
# reactiveConsole(T) # allows the csv file to be used properly
# “install.packages(“igraph”, type=“binary”) - uncomment if receiving a “there is no package called ‘igraph’” error when loading imager

# Uncomment when running locally:
setwd('/Users/sara/Code/Biomet.net/R/data_visualization/BioMet_shiny/')

# 2. FUNCTIONS -----
clean_data <- function(file) {
  # -------------------------------------------------------------------------- #
  # ARGUMENTS:
  # - file [str]: string containing the path to the desired file to be processed 
  # PURPOSE:
  # - to read in a raw data file (from any stage), and clean it up a little bit
  #   through replacing missing values and converting the dates to more usable
  #   POSIX date-time formatting
  # OUTPUT:
  # - returns a list of 12 variables relating to flux analyses (see 
  #   https://ameriflux.lbl.gov/data/aboutdata/data-variables/ for detailed 
  #   descriptions of all variables.)
  # -------------------------------------------------------------------------- #
  
  raw_data <- read.csv(file) # READ IN RAW DATA .CSV
  
  raw_data[raw_data == -9999] <- NA # REPLACE MISSING VALUES WITH NA
  
  if ('TIMESTAMP_START' %in% colnames(raw_data)) {
    raw_data <- raw_data[, !(colnames(raw_data) %in% c('TIMESTAMP', 
                                                       'TIMESTAMP_END'))]
    
    raw_data$TIMESTAMP_START <- as.POSIXct(as.character(raw_data$TIMESTAMP_START), # CHANGE DATE INTO POSIX FORMAT
                                           format = '%Y%m%d%H%M')
    
    colnames(raw_data)[colnames(raw_data) == 'TIMESTAMP_START'] <- 'DATETIME'
    
  } else {
    if ('TIMESTAMP' %in% colnames(raw_data)) {
      raw_data <- raw_data[, !(colnames(raw_data) %in% c('TIMESTAMP_START', 
                                                         'TIMESTAMP_END'))]
    }
    
    raw_data$TIMESTAMP <- as.POSIXct(as.character(raw_data$TIMESTAMP), # CHANGE DATE INTO POSIX FORMAT
                                     format = '%Y%m%d%H%M')
    
    colnames(raw_data)[colnames(raw_data) == 'TIMESTAMP'] <- 'DATETIME'
  }
  
  clean_data <- raw_data
  
  return(clean_data)
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
  
  unitsout <- data.frame(name = Variables,
                         variable = shortnames)
  
  flux_var <- read.csv(UnitCSVFilePath)
  flux_var <- flux_var[, c('Variable',
                           'Units',
                           'Type')]
  
  for (i in 1:length(unitsout$variable)) {
    unitsout$variable[i] <- stringr::str_to_upper(unitsout$variable[i])
  }
  
  filtered_var <- flux_var %>% 
    filter(Variable %in% unitsout$variable)
  
  return(filtered_var)
}

data_processing <- function(CleanDataFile, UnitCSVPath, Stage) {
  # -------------------------------------------------------------------------- #
  # ARGUMENTS:
  # - CleanDataFile [list]: list that's outputted from the clean_data() fxn
  # - UnitCSVPath [str]: A string that contains the path to an AmeriFlux CSV
  # - Stage [str]: A string that contains what stage of file is being cleaned up
  #   (for naming purposes)
  # PURPOSE:
  # - finds the summary statistics for all variables at the raw time intervals 
  #   (typically every half-hour), as well as sums the data by day to make 
  #   analysis and visualization for achievable for larger datasets. Alongside
  #   these analyses is a dataframe with units pertaining to the variables 
  #   found in the user's csv.
  # OUTPUT:
  # - a list containing three elements: summary [character], daily_data [list],
  #   and units [dataframe]. 
  #   These can then be called upon outside the fxn when they are respectively 
  #   needed.
  # -------------------------------------------------------------------------- #
  output_list <- list() # Empty list for output
  
  # 2.1.1 Get summary statistics
  stage <- Stage
  summary_stats <- c()
  summary_stats_out <- data.frame()
  
  # Loop through each variable in dataset
  for (k in 3:dim(CleanDataFile)[2]) { # Ignore datetime variables 
    var <- as.numeric(CleanDataFile[,k])
    summary_k <- round(summary(var),3)  # Take summary 
    if (length(summary_k) < 7) { # Ensure there are no NA-only values
      summary_k <- c(summary_k, 0)
    }
    
    percent_NA <- round(summary_k[7] / length(CleanDataFile[,k]) * 100,2) # Get percent of NAs in variable
    summary_k <- c(colnames(CleanDataFile)[k], summary_k, percent_NA) # Create new object with variable name and %NA
    names(summary_k)[c(1,8,9)] <- c('Variable','NAs', '% NA') # Rename columns
    summary_stats <- rbind(summary_stats, summary_k) # Add to growing list of variables 
  }
  
  rownames(summary_stats) <- rep('', dim(summary_stats)[1]) # Get rid of row names
  
  # Save summary statistics   
  summary_stats_out <- summary_stats # Add site to list of summary statistics
  names(summary_stats_out) <- paste0(stage) # Name list with site name
  
  output_list$summary <- summary_stats_out
  
  # 2.1.2 Get averaged daily data 
  # Average by day (to diminish data size)
  CleanDataFile$Date <- as.Date(CleanDataFile$DATETIME) # Create date variable
  dat_daily <- CleanDataFile %>% group_by(Date) %>% summarise_all(.funs = mean, na.rm = T) # Take average of each variable for each unique date
  
  dat_daily <- dat_daily %>% subset(select = -c(DATETIME)) # Get rid of timestamp variables
  
  output_list$daily_data <- dat_daily
  output_list$var_units <- var_units(names(dat_daily), UnitCSVPath)
  
  return(output_list)
}

potential_rad_generalized <- function(Standard_meridian,long,Lat, datetime) {
  # -------------------------------------------------------------------------- #
  # NOTE: Function originally written by Dr. Sara Knox (06/27/22)
  # ARGUMENTS:
  # - Standard_meridian [int]: An integer of the SOI's closest standard meridian
  # - long [int]: An integer value of the SOI's longitude
  # - lat [int]: An integer value of the SOI's latitude
  # - datetime [DateTime]: A list of datetimes
  # PURPOSE:
  # - calculates the SOI's potential radiation to be used as a comparison value
  # OUTPUT:
  # - an integer value of the potential radiation at that site.
  # -------------------------------------------------------------------------- #
  
  # Solar constant
  Io  <- 1366.5 # units of W m−2
  
  # Define the difference between site's longitude and the standard meridian
  delta_long  <-  long-Standard_meridian
  
  # Standard time
  ST <- as_hms(datetime)
  # Calculate LMST 
  LMST <- ST+hms(0,delta_long*4,0)
  
  # This is needed to output LMST in R's time format
  LMST <- hms(as.numeric(LMST))
  
  # Calculate DOY and gamma
  DOY <- yday(datetime)
  gamma <- ((2*pi/365)*(DOY-1))
  
  # Next the time offset between LMST and LAT (∆TLAT, i.e. deltaT_LAT), in minutes can be calculated using the formula given in Lecture 4, Slide 12
  deltaT_LAT <- 229.18*(0.000075 + 0.001868*cos(gamma) - 0.032077*sin(gamma) - 0.014615*cos(2*gamma) - 0.040849*sin(2*gamma))
  
  # Convert to R time format 
  deltaT_LAT <- hms(seconds = NULL, minutes = deltaT_LAT, hours = NULL, days = NULL)
  
  # Hence, LAT = LMST − ∆TLAT
  LAT <- LMST - hms(as.numeric(deltaT_LAT))
  
  # This is needed to output LAT in R's time format
  LAT <- hms(as.numeric(LAT))
  
  # Note LAT is the local apparent time (see above) in hours of the day (with minutes as a fraction of an hour). This can be calculated using the following:
  # This converts hh:mm:ss to hour of the day
  LAT2 <- sapply(strsplit(as.character(LAT),":"),
                 function(x) {
                   x <- as.numeric(x)
                   x[1]+x[2]/60
                 }
  )
  
  # Now calculate h
  h <- round(15*(12-LAT2)) # Round the hour angle to the nearest degree using round()
  
  # Next, estimate the declination angle using the more precise method. We will call this variable delta2 
  delta2 <- 0.006918 - 0.399912*cos(gamma) + 0.070257*sin(gamma) - 0.006758*cos(2*gamma) + 0.000907*sin(2*gamma) - 0.002697*cos(3*gamma) + 0.00148*sin(3*gamma)
  
  # Note that delta2 is in radians - we need to convert radians to degrees
  delta2deg <- delta2*(180/pi)
  
  # Now we can calculate the solar altitude angle
  # First calculate sin β - note that we have to convert angles in degrees to radians (multiply degrees by (pi/180))
  sinbeta <- sin(Lat*(pi/180))*sin(delta2deg*(pi/180))+cos(Lat*(pi/180))*cos(delta2deg*(pi/180))*cos(h*(pi/180))
  
  # Account for the non-circular orbit (changing distance over course of a year) (note gamma is calculated above)
  ratio2 <- 1.00011 + 0.034221*cos(gamma) + 0.001280*sin(gamma) + 0.000719*cos(2*gamma) + 0.000077*sin(2*gamma)
  
  # Calculate KEx (note that sinbeta is estimated above)
  KEx <- Io*ratio2*sinbeta
  
  # Force nighttime data to 0
  KEx[KEx<0] <- 0
  
  potential_rad <- KEx
}

# 3. USER INTERFACE ----
ui <- fluidPage(
  
  # DESIGN OPTIONS
  titlePanel(em('UBC Biometeorology Flux Visualization')),
  theme = shinytheme('cerulean'),
  
  # SET PAGE LAYOUT
  sidebarLayout(
    
    # SET SIDEBAR LAYOUT
    position = 'left',
    
    sidebarPanel = sidebarPanel(
      width = 3,
      
      # ADD SHORT DESCRIPTION
      h4(em('App Description'),
         align = 'center'),
      p(em("Upload your Site of Interest's Second and Third Stage Data below."),
        align = 'center'),
      
      # FILE INPUT OPTIONS FOR SECOND AND THIRD STAGE DATA
      fileInput(inputId = 'secfile',
                label = "Upload Second Stage CSV Below",
                multiple = TRUE,
                accept = '.csv'),
      
      fileInput(inputId = 'thrfile',
                label = 'Upload Third Stage CSV Below',
                multiple = TRUE,
                accept = '.csv')
      
    ), # END SIDERBAR LAYOUT
    
    mainPanel = mainPanel(
      width = 9,
      
      # MAIN TITLE 
      h3('Data Visualization'),
      
      tabsetPanel(
        # BEGIN ALL TAB SUBSETS
        
        tabPanel('Time Series',         # BEGIN TIME SERIES PANEL
                 
                 h4(strong('Time Series Plots')),
                 p(em('Optional to compare variables from single stage or have a 
                      stage-to-stage comparison between select variables')),
                 
                 br(),
                 
                 # SELECT SECOND AND THIRD STAGE VARIABLES
                 ## BEGINS W/ NULL CHOICES DUE TO NO FILE BEING UPLOADES
                 fluidRow( column(6,
                                  
                                  selectInput(inputId = 'secvar',
                                              label = 'Second Stage Variables',
                                              choices = NULL),
                                  
                                  checkboxInput(inputId = 'plot_third',
                                                label = em('Plot Third Stage Variable'),
                                                value = F)),
                           
                           column(6,
                                  
                                  selectInput(inputId = 'thrvar',
                                              label = 'Third Stage Variables',
                                              choices = NULL))
                           
                 ), # END OF FLUID ROW
                 
                 uiOutput('sliderrange'),
                 
                 # OUTPUT TIME SERIES WITH A SPINNER 
                 shinycssloaders::withSpinner(plotlyOutput('timeseries'),
                                              type = getOption("spinner.type", default = 5),
                                              color = getOption("spinner.color", default = "dodgerblue")),
                 
                 h5(em('Plot shows daily average of half-hourly data.'), 
                    align = 'center')
                 
        ), # END TIME SERIES PANEL
        
        tabPanel('Diurnal Cycle',
                 
                 h4(strong('Diurnal Cycle')),
                 p(em('See how a variables average hourly value changes over the course of a month.')),
                 
                 # CREATE VARIABLE INPUTS 
                 fluidRow( column(6,
                                 
                                  selectInput(inputId = 'di_stage',
                                             label = 'Select Stage',
                                             choices = NULL)),
                           column(6,
                                 
                                  selectInput(inputId = 'di_var',
                                             label = 'Diurnal Variable',
                                             choices = NULL))
                 ), # END FLUID ROW 
                 
                 # OUTPUT DIURNAL PLOTS (W/ SPINNER)
                 shinycssloaders::withSpinner(plotlyOutput('diurnal', 
                                                           width = '100%', height = '60%'),
                                              type = getOption("spinner.type", default = 5),
                                              color = getOption("spinner.color", default = "dodgerblue")),
                 
                 br(),
                 
                 h5(em('Plots shows half-hourly averages over the course of the month.'), 
                    align = 'center')
                 
        ), # END DIURNAL CYCLE TAB
        
        tabPanel('Density & Scatter Plots',      # BEGIN SCATTER PLOTS TAB
                 
                 h4(strong('Density and Scatter Plots')),
                 p(em('Compare variables from Second Stage (2s) and/or Third Stage (3s) Data')),
                 
                 # CREATE INPUT FOR TYPE OF PLOT COMPARISON
                 selectInput(inputId = 'comp_type',                 
                             label = 'Plot Comparison Options',
                             choices = c('Variable',
                                         'Stage')),
                 
                 # SELECT X- AND Y-AXIS VARIABLES
                 fluidRow( column(6,
                                  
                                  uiOutput('xaxis')),
                                  
                           column(6,
                                  
                                  uiOutput('yaxis'))),
                 br(),
                 
                 # OUTPUT SCATTER AND DENSITY PLOTS (W/ SPINNER)
                 # OUTPUT TIME SERIES WITH A SPINNER 
                 shinycssloaders::withSpinner(plotlyOutput('scatter',
                                                           width = '100%', height = '200%'),
                                              type = getOption("spinner.type", default = 5),
                                              color = getOption("spinner.color", default = "dodgerblue")),
                 
                 h5(em('Plots shows daily averages of half-hourly data.'), 
                    align = 'center')
                 
        ), # END SCATTER PANEL
        
        tabPanel('Radiation Plots',
                 
                 h4(strong('Radiation Plots')),
                 p(em('Compare various radiation values.')),
                 
                 # CREATE INPUTS FOR SITE LOCATION (STANDARD MERIDIAN, LONGITUDE, LATITUDE)
                 h5(em("Site Location Information")),
                 fluidRow( column(3,
                                  
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
                                               value = 0)),
                           column(3,
                                  
                                  uiOutput(outputId = 'timescale'))),
                 
                 # INPUTS FOR RADIATION VARIABLE AND THE COMPARITIVE VARIABLE
                 h5(em('Radiation Parameters')),
                 fluidRow( column(4, 
                                  
                                  selectInput(inputId = 'rad_stage',
                                              label = 'Stage',
                                              choices = 'Second Stage')),
                           
                           column(4, 
                                  
                                  selectInput(inputId = 'rad_var',                 
                                              label = 'Radiation Variable',
                                              choices = NULL)),
                           
                           column(4,
                                  
                                  selectInput(inputId = 'rad_comp_var',                 
                                              label = 'Comparison Variable',
                                              choices = NULL))),
                 
                 # RADIATION PLOT
                 shinycssloaders::withSpinner(plotlyOutput('rad_plot',
                                                           width = '100%', height = '300%'),
                                              type = getOption("spinner.type", default = 5),
                                              color = getOption("spinner.color", default = "dodgerblue")),
                 
        ),
        
        tabPanel('Missing Data',
          
                 # MISSING DATA PLOT
                 shinycssloaders::withSpinner(plotlyOutput('miss_plot',
                                                           width = '100%', height = '400%'),
                                              type = getOption("spinner.type", default = 5),
                                              color = getOption("spinner.color", default = "dodgerblue")),
          
                 h5(em('Colours represent the percentage of missing data - see Summary Statistics page for exact counts.'), 
                    align = 'center')
          
        ), # END MISSING DATA
        
        tabPanel('Summary Statistics',
                 
                 br(),
                 
                 # SECSTAG SUMMARY STATISTICS
                 h4('Second Stage Summary'),
                                  
                 # OUPUT SECSTAG SUMMARY TABLE (W/ SPINNER)
                 shinycssloaders::withSpinner(tableOutput("summary_secstag"),
                                              type = getOption("spinner.type", default = 5),
                                              color = getOption("spinner.color", default = "dodgerblue")),
                 tags$head(tags$style("#dummy table {background-color: red; }", media="screen", type="text/css")),
                           
                 # THRSTAG SUMMARY STATISTICS
                 h4('Third Stage Summary'),
                                  
                 # OUPUT THRSTAG SUMMARY TABLE (W/ SPINNER)
                 shinycssloaders::withSpinner(tableOutput("summary_thrstag"),
                                              type = getOption("spinner.type", default = 5),
                                              color = getOption("spinner.color", default = "dodgerblue")),
                 tags$head(tags$style("#dummy table {background-color: red; }", media="screen", type="text/css")),
                 
                 h5(em("Minima, maxima, IQRs, means, medians and missing data for each variable within the provided dataset's time."),
                    align = 'center')
                 
        ) # END SUMMARY STATISTICS PANEL
        
      ) # END ALL TAB SUBSETS
      
    ) # END MAIN LAYOUT (CONTAINS ALL TAB SUBSETS (E.G., SCATTER, TIME SERIES))
    
  ) # END PAGE LAYOUT 
  
) # END USER INTERFACE

# 4. SERVER ----
server <- function(input, output, session) {
  # SET UP AND CLEAN INPUTTED DATA
  options(shiny.maxRequestSize=50*1024^2) # csv max file size of 50MB
  
  # REACTIVE VARIABLES
  SelectedData <- reactiveValues()
  
  inputs <- reactive({
    list(input$secfile, input$thrfile)  # WHEN REACTIVITY RELIES ON BOTH FILES
  })
  
  observeEvent(inputs(), {
    # SECOND STAGE PROCESSING
    if (is.null(input$secfile) == F) { # IF STATEMENT FOR WHEN THRSTAG FILE IS MISSING
      if (length(input$secfile$name) == 1) {
        
        # READ IN SECOND STAGE DATA FILE
        InSecFile <- input$secfile
        
        # CLEAN UP AND PROCESS FILE 
        SelectedData$sec_clean <- clean_data(InSecFile$datapath)
        
        ProSecFile <- data_processing(SelectedData$sec_clean, '/Users/sara/Code/Biomet.net/R/data_visualization/BioMet_shiny/flux_variables.csv', 'Second')
        
        SelectedData$sec_daily <- ProSecFile$daily_data
        SelectedData$sec_summary <- ProSecFile$summary
        SelectedData$sec_units <- ProSecFile$var_units
        
      } else {
        # SECOND STAGE DATA
        SecCleanedData <- data.frame()
        
        for (i in 1:length(input$secfile$name)) {
          
          # READ IN SECOND STAGE DATA FILE
          SecPathFile <- input$secfile$datapath[i]
          
          # CLEAN UP FILE
          SecCleanFile <- clean_data(SecPathFile)
          
          SecCleanedData <- rbind(SecCleanedData, SecCleanFile)
        }
        
        # PROCESS FILE 
        SelectedData$sec_clean <- CleanedData
        
        ProSecFile <- data_processing(CleanedData, '/Users/sara/Code/Biomet.net/R/data_visualization/BioMet_shiny/flux_variables.csv', 'Second')
        
        SelectedData$sec_daily <- ProSecFile$daily_data
        SelectedData$sec_summary <- ProSecFile$summary
        SelectedData$sec_units <- ProSecFile$var_units
        
      } # END IF/ELSE REVOLVING AROUND MULTIPLE FILES
    } # END SECOND STAGE PROCESSING
    
    # THIRD STAGE DATA PROCESSING
    if (is.null(input$thrfile) == F) { # IF STATEMENT FOR WHEN THRSTAG FILE IS MISSING
      if (length(input$thrfile$name) == 1) {
        req(input$thrfile)
        
        # READ IN THIRD STAGE DATA FILE
        InThrFile <- input$thrfile
        
        # CLEAN UP AND PROCESS FILE 
        SelectedData$thr_clean <- clean_data(InThrFile$datapath)
        
        ProThrFile <- data_processing(SelectedData$thr_clean, '/Users/sara/Code/Biomet.net/R/data_visualization/BioMet_shiny/flux_variables.csv', 'Third')
        
        SelectedData$thr_daily <- ProThrFile$daily_data
        SelectedData$thr_summary <- ProThrFile$summary
        SelectedData$thr_units <- ProThrFile$var_units
        
      } else {
        req(input$thrfile)
        ThrCleanedData <- data.frame()
        
        for (i in 1:length(input$thrfile$name)) {
          
          # READ IN SECOND STAGE DATA FILE
          ThrPathFile <- input$thrfile$datapath[i]
          
          # CLEAN UP FILE
          ThrCleanFile <- clean_data(ThrPathFile)
          
          ThrCleanedData <- rbind(ThrCleanedData, ThrCleanFile)
        }
        
        # PROCESS FILE
        SelectedData$thr_clean <- ThrCleanedData
        
        ProThrFile <- data_processing(ThrCleanedData, '/Users/sara/Code/Biomet.net/R/data_visualization/BioMet_shiny/flux_variables.csv', 'Third')
        
        SelectedData$thr_daily <- ProThrFile$daily_data
        SelectedData$thr_summary <- ProThrFile$summary
        SelectedData$thr_units <- ProThrFile$var_units
        
      } # END IF/ELSE REVOLVING AROUND MULTIPLE FILES
    } # END THIRD STAGE PROCESSING
    
    # TIME SERIES ----
    # ---------- #
    # DESCRIPTION
    # - this section concentrates on the time series plots, that displays second
    #   (and third stage if selected) over the dates provided by the user's data
    
    # INPUTS
    # - Second Stage Variable [Str]:
    #     - Flux variables pulled from the user-inputted data
    # - Third Stage Variable [Str] * Will only render after third stage data is uploaded *
    #     - " ^ " 
    # ---------- #
    
    req(input$secfile)
    
    # PULL OUT SECOND STAGE VARIABLES
    sec_variables <- colnames(SelectedData$sec_daily)
    sec_variables <- sec_variables[-1]
    
    updateSelectInput(session = session,
                      inputId = 'secvar',
                      label = 'Second Stage Variable',
                      choices = sec_variables)
    
    # RENDER DATE INPUT
    output$sliderrange <- renderUI({
      mindate <- head(SelectedData$sec_daily$Date, n = 1)
      maxdate <- tail(SelectedData$sec_daily$Date, n = 2)[1]
      
      sliderInput(inputId = 'sliderrange',
                  label = 'Date Range',
                  value = c(mindate, maxdate),
                  min = mindate, max = maxdate,
                  width = '85%')
    })
    
    # UPDATE SELECTIONS TO USER SPECIFICATIONS
    thr_variables <- colnames(SelectedData$thr_daily)
    thr_variables <- thr_variables[-1]
    
    updateSelectInput(session = session, 
                      inputId = 'thrvar', 
                      label = 'Third Stage Variable', 
                      choices = thr_variables)
    
    observeEvent(input$plot_third, {
      updateSliderInput(session = session,
                        inputId = 'sliderrange',
                        value = c(head(SelectedData$sec_daily$Date, n = 1),
                                  tail(SelectedData$sec_daily$Date, n = 2)[1]),
                        min = head(SelectedData$sec_daily$Date, n = 1),
                        max = tail(SelectedData$sec_daily$Date, n = 2)[1])
    })
    
    UserSelectedData <- reactive({       # GET USER-SPECIFIED VARIABLES
      if (input$plot_third == F) {
        req(input$secfile)
        
        SelectedData$sec_daily[, c('Date', input$secvar)]
        
      } else {
        req(input$secfile, input$thrfile)
        
        c(SelectedData$sec_daily[, 'Date'],
          SelectedData$sec_daily[, input$secvar],
          SelectedData$thr_daily[, input$thrvar])
        
      }
    })
    
    # FIND UNITS FOR USER-SELECTED VARIABLES
    Units <- reactive({
      if (input$plot_third == F) {
        req(input$secfile)
        variables <- SelectedData$sec_units[[1]]
        
        for (i in 1:length(variables)) {
          if (grepl(variables[i], input$secvar, ignore.case = TRUE)) {
            units <- SelectedData$sec_units[[2]][i]
          }
        }
      } else {
        req(input$secfile, input$thrfile)
        variables <- SelectedData$thr_units[[1]]
        
        units <- list()
        for (i in 1:length(variables)) {
          if (grepl(variables[i], input$secvar, ignore.case = TRUE)) {
            units$sec <- SelectedData$sec_units[[2]][i]
          }
          
          if (grepl(variables[i], input$thrvar, ignore.case = TRUE)) {
            units$thr <- SelectedData$thr_units[[2]][i]
          }
        }
      }
      units
    })
    
    # START TIME SERIES PLOT RENDER
    output$timeseries <- renderPlotly({
      req(input$secvar)
      
      var_names <- list()
      var_names$svar <- names(UserSelectedData())[2] # sec. stag.
      ylabel <- paste0(var_names$svar, ' [', Units()[1], ']')
      Date <- UserSelectedData()[1][[1]]
      
      if (input$plot_third == F) {
        p1 <- plot_ly(data = UserSelectedData(), 
                      x = ~Date, y = ~UserSelectedData()[2][[1]], 
                      type = 'scatter', mode = 'lines', line = list(color = 'orangered3'), name = var_names$svar)
        
        p1 <- p1 %>% layout(
          yaxis = list(
            title = ylabel
          ),
          xaxis = list(range = c(input$sliderrange[1], 
                                 input$sliderrange[2])))
        
      } else {
        req(input$secvar, input$thrvar)
        
        var_names$tvar <- names(UserSelectedData())[3] # thr. stag.
        ylabel2 <- paste0(var_names$tvar, ' [', Units()[2], ']')
        
        p1 <- plot_ly() %>%
          add_trace(data = UserSelectedData(), 
                    x = ~Date, y = ~UserSelectedData()[2][[1]], 
                    type = 'scatter', mode = 'lines', line = list(color = 'orangered3'), name = var_names$svar) %>%
          add_trace(data = UserSelectedData(), 
                    x = ~Date, y = ~UserSelectedData()[3][[1]], 
                    type = 'scatter', mode = 'lines', line = list(color = 'dodgerblue3'), name = var_names$tvar, 
                    yaxis = "y2")
        
        p1 <- p1 %>% layout(
          yaxis2 = list(
            title = ylabel2,
            overlaying = "y",
            side = "right"
          ),
          yaxis = list(
            title = ylabel
          ),
          xaxis = list(range = c(input$sliderrange[1], 
                                 input$sliderrange[2])), 
          margin = list(
            l = 80,
            r = 80,  
            t = 50,   
            b = 100   
          ),
          legend = list(
            x = 0,  # Horizontal position (0-1) with 0.5 as the center
            y = -0.2, # Vertical position with negative value to move to the bottom
            orientation = 'h' 
          )
        )
      }
      
      p1
      
    }) # END TIME SERIES PLOT
    
    # DIURNAL ----
    # ---------- #
    # DESCRIPTION
    # - this section concentrates on the diurnal plots, which display the hourly 
    #   averages, and the upper and lower standard deviations across each month 
    #   found in the user's .csv
    
    # INPUTS
    # - Select Stage [Str]:
    #     - Stage of interest (plot will not render if third stage is selected
    #       but file is missing)
    # - Diurnal Variable [Str]:
    #     - Variables featured within the user-inputted .csv, dependent on the 
    #       stage selection
    # ---------- #
    updateSelectInput(session = session,
                      inputId = 'di_stage',
                      label = 'Select Stage',
                      choices = c('Second Stage',
                                  'Third Stage'))
    
    di_variables <- reactive({
      if (input$di_stage == 'Second Stage') {
        req(input$secfile)
        return(colnames(SelectedData$sec_daily)[-1])
        
      } else {
        req(input$thrfile)
        return(colnames(SelectedData$thr_daily)[-1])
      }
    })
    
    observe({
      updateSelectInput(session = session,
                        inputId = 'di_var',
                        label = 'Diurnal Variable',
                        choices = di_variables())
    })
    
    # PULL OUT USER-SPECIFIED DATA
    di_data <- reactive({
      req(input$secfile)
      
      if (input$di_stage == 'Second Stage') {
        DiurnalData <- SelectedData$sec_clean[, c('DATETIME', 
                                                  input$di_var)]
        DiurnalData$Month <- as.numeric(substring(DiurnalData$DATETIME, 6, 7))
      } else {
        DiurnalData <- SelectedData$thr_clean[, c('DATETIME',
                                                  input$di_var)]
        
        DiurnalData$Month <- as.numeric(substring(DiurnalData$DATETIME, 6, 7))
      }
      
      # Calculate mean and standard deviation of the selected variable
      var_sd <- sd(DiurnalData[[2]], na.rm = TRUE)
      
      # Calculate +1 SD and -1 SD values and fill the corresponding columns
      DiurnalData$upper_sd <- DiurnalData[[2]] + var_sd
      DiurnalData$lower_sd <- DiurnalData[[2]] - var_sd
      
      colnames(DiurnalData) <- c('Date', 'Variable', 'Month', 'UppSD', 'LowSD')
      return(na.omit(DiurnalData))
    })
    
    # FIND UNITS FOR USER-SELECTED VARIABLES
    DiUnits <- reactive({
      if (input$di_stage == 'Second Stage') {
        req(input$secfile)
        variables <- SelectedData$sec_units[[1]]
        
        for (i in 1:length(variables)) {
          if (grepl(variables[i], input$di_var, ignore.case = TRUE)) {
            units <- SelectedData$sec_units[[2]][i]
          }
        }
        
      } else {
        req(input$thrfile)
        variables <- SelectedData$thr_units[[1]]
        
        for (i in 1:length(variables)) {
          if (grepl(variables[i], input$di_var, ignore.case = TRUE)) {
            units <- SelectedData$thr_units[[2]][i]
          }
        }
      }
      units
    })
    
    observe({ # BEGIN DIURNAL PLOT 
      req(input$di_var)
      didat <- di_data()
      
      didat$Hour <- format(didat$Date, format = "%H%M")
      
      hourly_di <- didat %>% group_by(Month, Hour) %>% summarise(Average = mean(Variable))
      hourly_di$Hour <- as.numeric(hourly_di$Hour)
      
      var_sd <- sd(hourly_di$Average, na.rm = TRUE)
      hourly_di$UppSD <- hourly_di$Average + var_sd
      hourly_di$LowSD <- hourly_di$Average - var_sd
      
      month_labs <- c('1' = 'January', '2' = 'February', '3' = 'March',
                      '4' = 'April', '5' = 'May', '6' = 'June',
                      '7' = 'July', '8' = 'August', '9' = 'September',
                      '10' = 'October', '11' = 'November', '12' = 'December')
      
      month_labeller <- labeller(Month = function(levels) month_labs[as.character(levels)])
      
      # BEGIN DIURNAL PLOT RENDER
      output$diurnal <- renderPlotly({ 
        di_plot <- ggplot(data = hourly_di, 
                          aes(x = Hour, y = Average)) +
          geom_line() +
          geom_ribbon(aes(ymax = UppSD, ymin = LowSD), 
                      col = 'dodgerblue4', fill = 'dodgerblue4', alpha = 0.3) +
          facet_wrap(~ Month, ncol = 4, scales = "free", strip.position = "bottom",
                     labeller = month_labeller) +
          scale_x_continuous(breaks = c(0, 600, 1200, 1800, 2330), 
                             labels = c("MDNT", "6 AM", "Noon", "6 PM", "MDNT")) +
          scale_y_continuous(limits = c(min(hourly_di$LowSD),
                                        max(hourly_di$UppSD))) +
          theme_minimal() +
          labs(title = paste(input$di_var, "Averaged Over a Month"),
               x = "Hour of the Day",
               y = paste(input$di_var, " [", DiUnits()[1], "]")) +
          theme(panel.spacing.x = unit(3, "mm"),
                panel.spacing.y = unit(6, "mm"),
                strip.placement = "outside",
                strip.background = element_blank())
        
        ggplotly(di_plot)  # Set tooltip to display the custom text
        
      }) # END PLOT RENDER
    }) # END PLOT
    
    # SCATTER PLOT ----
    # ---------- #
    # DESCRIPTION
    # - this section concentrates on comparisons between variables within/across
    #   stages. Various plot colours distinguish between stages, and basic correlation
    #   values will be calculated.
    
    # INPUTS
    # - Plot Comparison Type [Str]:
    #     - Choice between Variable or Stage Comparison - Plots will depend on 
    #       this choice (Variable is defaulted since Stage selection only 
    #       works when third stage is inputted)
    #     - If "Variable" is selected, inputs:
    #         - X-Variable [Str]: List of variables from the user .csv's, distinguishes
    #                             same variables across stages by the number notation 
    #                             that follows its name, will appear along the x-axis
    #         - Y-Variable [Str]: " ^ ", but along the y-axis
    #     - If "Stage" is selected, inputs:
    #         - Second Stage [Str]: Second stage variables, and this selection will 
    #                               appear along the x-axis
    #         - Third Stage [Str]: Third stage variables, will appear along the y
    # ---------- #
    
    updateSelectInput(session = session,
                      inputId = 'comp_type',
                      label = 'Plot Comparison Type',
                      choices = c('Variable',
                                  'Stage'))
    
    # GET NAMES OF VARIABLES FROM THE USER-SELECTED DATA
    var_names <- reactive({
        
        # SEC. STAG VARIABLES
        secvar <- paste0(colnames(SelectedData$sec_daily[-1]), "_2s", sep = '')
        
        output <- secvar
        
        if (!is.null(input$thrfile)) { # ADDS THIRD STAGE VARIABLES ONLY WHEN UPLOADED
          # THR. STAG VARIABLES
          thrvar <- paste0(colnames(SelectedData$thr_daily[-1]), "_3s", sep = '')
          
          output <- c(secvar, thrvar)
        } 
        
        return(output)
        
    })
    
    stage_comp_var <- reactive({
      sec_variables <- colnames(SelectedData$sec_daily)[-1]
      thr_variables <- colnames(SelectedData$thr_daily)[-1]
      
      common_variables <- intersect(sec_variables, thr_variables)
      
      return(common_variables)
    })
    
    # RENDER VARIABLE OPTIONS
    observeEvent(input$comp_type, {
      # RENDER X VARIABLES
      output$xaxis <- renderUI({
        if (input$comp_type == 'Variable') {
          selectInput(inputId = 'xaxis', 
                      label = 'X-Axis Variable', 
                      choices = var_names())
        } else if (input$comp_type == "Stage") {
          selectInput(inputId = 'xaxis', 
                      label = 'Second Stage Variable', 
                      choices = stage_comp_var())
        }
      })
      
      # RENDER Y VARIABLES
      output$yaxis <- renderUI({
        if (input$comp_type == 'Variable') {
          selectInput(inputId = 'yaxis', 
                      label = 'Y-Axis Variable', 
                      choices = var_names())
        } else if (input$comp_type == "Stage") {
          selectInput(inputId = 'yaxis', 
                      label = 'Third Stage Variable', 
                      choices = stage_comp_var())
        }
      })
    })
    
    # GET SCATTER DATA
    ScatterData <- reactive({
      req(input$secfile)
      
      if (input$comp_type == 'Variable') {
        # FIND X
        req(input$xaxis)
        
        if (stringr::str_detect(input$xaxis, '_2s')) {
          xvar <- (stringr::str_remove(input$xaxis, '_2s'))
          x <- SelectedData$sec_daily[, xvar]
        } else {
          req(input$thrfile)
          xvar <- (stringr::str_remove(input$xaxis, '_3s'))
          x <- SelectedData$thr_daily[, xvar]
        }
        
        # FIND Y
        req(input$yaxis)
        
        if (stringr::str_detect(input$yaxis, '_2s')) {
          yvar <- (stringr::str_remove(input$yaxis, '_2s'))
          y <- SelectedData$sec_daily[, yvar]
        } else {
          req(input$thrfile)
          yvar <- (stringr::str_remove(input$yaxis, '_3s'))
          y <- SelectedData$thr_daily[, yvar]
        }
        
        data <- cbind(x, y)
        
        if (stringr::str_detect(input$xaxis, '_2s') & stringr::str_detect(input$yaxis, '_2s')) {
          data$stage <- 'sec'
        } else if (stringr::str_detect(input$xaxis, '_3s') & stringr::str_detect(input$yaxis, '_3s')) {
          data$stage <- 'thr'
        } else {
          data$stage <- 'combo'
        }
        
        return(data)
        
      } else if (input$comp_type == 'Stage') {
        
        # GET VARIABLE DATA
        ## SECOND STAGE
        
        secstag <- as.data.frame(cbind(SelectedData$sec_daily[, input$xaxis], 
                                       SelectedData$sec_daily[, input$yaxis]))
        secstag$stage <- 'sec'
        
        ## THIRD STAGE
        thrstag <- as.data.frame(cbind(SelectedData$thr_daily[, input$xaxis], 
                                       SelectedData$thr_daily[, input$yaxis]))
        thrstag$stage <- 'thr'
        
        data <- rbind(secstag, thrstag)
        
        return(data)
      }
    })
    
    # FIND UNITS FOR USER-SELECTED VARIABLES
    ScatterUnits <- reactive({
      req(input$secfile)
      units <- list()
      
      if (stringr::str_detect(input$xaxis, '_2s') & stringr::str_detect(input$yaxis, '_2s')) {
        variables <- SelectedData$sec_units[[1]]
        
        for (i in 1:length(variables)) {
          if (grepl(variables[i], input$xaxis, ignore.case = TRUE)) {
            units$x <- SelectedData$sec_units[[2]][i]
          } 
          if (grepl(variables[i], input$yaxis, ignore.case = TRUE)) {
            units$y <- SelectedData$sec_units[[2]][i]
          } 
        }
      } else {
        req(input$thrfile)
        variables <- SelectedData$thr_units[[1]]
        
        for (i in 1:length(variables)) {
          if (grepl(variables[i], input$xaxis, ignore.case = TRUE)) {
            units$x <- SelectedData$thr_units[[2]][i]
          } 
          if (grepl(variables[i], input$yaxis, ignore.case = TRUE)) {
            units$y <- SelectedData$thr_units[[2]][i]
          } 
        }
      }
      units
    })
    
    # SCATTER PLOT RENDER
    output$scatter <- renderPlotly({
      req(input$comp_type, input$secfile)
      
      varnames <- names(ScatterData())
      units <- ScatterUnits()
      
      title <- paste(varnames[1], " [", units['x'], "]", 'vs.', varnames[2], " [", units['y'], "]")
      axes_labels <- c(varnames[1], varnames[2])
      
      clean_dat <- na.omit(ScatterData())
      
      if (input$comp_type == 'Variable') {
        colnames(clean_dat) <- c("x_var", "y_var", "stage")  # Rename columns
        
        corr_plots <- ggpairs(data = clean_dat,
                              columns = 1:2,
                              aes(x = x_var, y = y_var,
                                  colour = clean_dat$stage, fill = clean_dat$stage, alpha = 0.1),
                              lower = list(continuos = 'smooth'),
                              columnLabels = axes_labels[1:2]) +  
          theme_bw() +
          scale_colour_manual(values = c('sec' = 'dodgerblue3',
                                         'thr' = 'orangered3',
                                         'combo' = 'darkorchid4')) +
          scale_fill_manual(values = c('sec' = 'dodgerblue3',
                                       'thr' = 'orangered3',
                                       'combo' = 'darkorchid4')) +
          theme(axis.text = element_text(color = "black", size = 7),
                strip.text = element_text(size = 9),
                plot.title = element_text(size = 11, face = "bold"),
                plot.margin = margin(t = 35, r = 20, b = 20, l = 30)) +
          ggtitle(title)
        
        corr_plots <- ggplotly(corr_plots)
        
        } else if (input$comp_type == 'Stage') {
          colnames(clean_dat) <- c("x_var", "y_var", "stage")  # Rename columns
          
          corr_plots <- ggpairs(data = clean_dat,
                                columns = 1:2,
                                aes(x = x_var, y = y_var,
                                    colour = clean_dat$stage, fill = clean_dat$stage, alpha = 0.1),
                                columnLabels = axes_labels[1:2]) +
            theme_bw() +
            scale_colour_manual(values = c('sec' = 'dodgerblue3',
                                           'thr' = 'orangered')) +
            scale_fill_manual(values = c('sec' = 'dodgerblue3',
                                         'thr' = 'orangered')) +
            theme(axis.text = element_text(color = "black", size = 9),
                  strip.text = element_text(size = 9),
                  plot.title = element_text(size = 11, face = "bold"),
                  plot.margin = margin(t = 35, r = 20, b = 20, l = 30)) +
            ggtitle(title) +
            labs(x = varnames[1], y = varnames[2]) +
            theme(legend.position = "bottom")
          
          corr_plots <- ggplotly(corr_plots)
        }
      
      corr_plots
        
    }) # END SCATTER PLOT RENDER
    
    # RADIATION PLOTS ----
    # ---------- #
    # DESCRIPTION
    # - this section concentrates on the radiation plots tab, where it will filter 
    #   user inputted variables to show only radiation tagged variables (as 
    #   described by ameriflux - e.g., SW, LW, NETRAD, PPFD, NDVI, etc.) and will then
    #   plot them against a comparative variable, which is either potential radiation
    #   (default), or Net Radiation if the .csv provides that variable.
    # - various plots can be created, with the starting plot showing the daily averages
    #   over the entire timescale that the csv provides. The user is able to then
    #   select between individual or composite monthly plots displaying their selected
    #   rad. var of interest against the comparative variable they would like.
    
    # INPUTS
    # - Site Location Data [flt]:
    #     - Standard Meridian (input$std_merid), Latitude (input$lat), Longitude (input$long)
    # * NOTE: As of 08/25/23, when changing the location data, the error, 
    #         " Warning: Error in UseMethod: no applicable method for 'group_by' applied to an object of class "list" "
    #         will pop up, but only for a short time, before the app is updated 
    #         to include the final input from the numeric location inputs (std_merid, lat, long)
    # - Time Scale [Str] * Will only render after .csv is inputted and data can be processed *
    #     - Options include "All Time" (default; uses the entire dataset, and 
    #       displays daily averages), "All Months" (monthly subplots so that you 
    #       can see the hourly average per month, over the entire year), after 
    #       these the inputs depend on the inputted .csv, where it will include 
    #      the months of the years provided (e.g.,2022-12, 2023-01, 2023-02, etc.)
    # - Stage [Str] 
    #     - Similar to other tabs, will display the stage options depending on 
    #       if multiple stages are uploaded or not.
    # - Radiation Variable [Str]
    #     - The variables that a user can select depending on which ameriflux-defined
    #       radiation variables are featured within the .csv (filters automatically)
    # - Comparison Variable [Str]
    #     - The options for what to compare the radiation variable against, the 
    #       default is "Potential Radiation" which is calculated using the 
    #       potential_rad_generalized previously defined, or it can be "Net 
    #       Radiation" if a NETRAD variable is found within the csv.
    # ---------- #
    
    # FIND UNITS FOR USER-SELECTED VARIABLES
    observe({
      # UPDATE STAGE CHOICES IF THIRD STAGE PRESENT
      if (is.null(input$thrfile) == FALSE) {
        updateSelectInput(session = session,
                          inputId = 'rad_stage',
                          label = 'Stage',
                          choices = c('Second Stage',
                                      'Third Stage'))
      }
    })

    RadVariables <- reactive({
      variables <- list()
      variables$comprad <- 'Potential Radiation'
      
      if (input$rad_stage == 'Second Stage') {
        req(input$secfile)
        
        variables$rad <- SelectedData$sec_units %>%
          filter(Type == 'MET_RAD')
        
        compvar <- SelectedData$sec_units[[1]]
        
        for (i in 1:length(compvar)) {
          if (compvar[i] == 'NETRAD') {
            variables$comprad <- c('Potential Radiation', 'Net Radiation')
          }
        }
        
      } else {
        req(input$secfile, input$thrfile)
        
        radvar1 <- SelectedData$sec_units %>%
          filter(Type == 'MET_RAD')
        
        radvar2 <- SelectedData$thr_units %>%
          filter(Type == 'MET_RAD')
        
        variables$rad <- c(radvar1, radvar2)
        
        compvar <- c(SelectedData$sec_units[[1]],
                     SelectedData$thr_units[[1]])
        
        for (i in 1:length(compvar)) {
          if (compvar[i] == 'NETRAD') {
            variables$comprad <- c('Potential Radiation', 'Net Radiation')
          }
        }
      }
      variables
    })
    
    # RENDER TIME SCALE OPTIONS
    output$timescale <- renderUI({
      req(input$secfile)
      raddat <- RadData()
      date <- as.Date(raddat$datetime)
      
      raddat$YearMonth <- format(date, format = "%Y-%m")
      yearmonth <- unique(raddat$YearMonth)
      
      selectInput(inputId = 'timescale', 
                  label = 'Time Scale', 
                  choices = c('All Time',
                              'All Months',
                              yearmonth))
    })
    
    observe({
      # UPDATE VARIABLE CHOICES
      updateSelectInput(session = session,
                        inputId = 'rad_var',
                        label = 'Radiation Variable',
                        choices = RadVariables()[['rad']][[1]])
      
      updateSelectInput(session = session,
                        inputId = 'rad_comp_var',                 
                        label = 'Comparison Variable',
                        choices = RadVariables()[['comprad']])
    })
    
    RadData <- reactive({
      req(input$secfile, input$rad_var)
      
      # ENSURE ONLY CALCULATED WHEN ACTUAL NUMBERS ARE INPUTTED
      if ((is.na(input$std_merid) || is.na(input$long) || is.na(input$lat)) == F) {
        if (input$rad_stage == 'Second Stage') {
          raw_names <- names(SelectedData$sec_clean)
          
          for (i in 1:length(raw_names)) {
            if (grepl(input$rad_var, raw_names[i])) {
              var <- raw_names[i]
            }
          }
          
          raw_data <- SelectedData$sec_clean[, c('DATETIME',
                                                 var)]
          
          if (input$rad_comp_var == 'Potential Radiation') {
            date <- raw_data['DATETIME'][[1]]
            
            for (i in 1:length(date)) {
              raw_data$pot_rad[i] <- potential_rad_generalized(input$std_merid, input$long, input$lat, date[i])
            }
          } else {
            
            for (i in 1:length(raw_names)) {
              if (grepl('NETRAD', raw_names[i])) {
                netrad <- raw_names[i]
              }
            }
            
            raw_data <- SelectedData$sec_clean[, c('DATETIME',
                                                   var,
                                                   netrad)]
          }
          
        } else {
          raw_names <- names(SelectedData$thr_clean)
          
          for (i in 1:length(raw_names)) {
            if (grepl(input$rad_var, raw_names[i])) {
              var <- raw_names[i]
            }
          }
          
          raw_data <- SelectedData$thr_clean[, c('DATETIME',
                                                 var)]
          
          if (input$rad_comp_var == 'Potential Radiation') {
            date <- raw_data['DATETIME'][[1]]
            
            for (i in 1:length(date)) {
              raw_data$pot_rad[i] <- potential_rad_generalized(input$std_merid, input$long, input$lat, date[i])
            }
          } else {
            
            for (i in 1:length(raw_names)) {
              if (grepl('NETRAD', raw_names[i])) {
                netrad <- raw_names[i]
              }
            }
            
            raw_data <- SelectedData$thr_clean[, c('DATETIME',
                                                   var,
                                                   netrad)]
          }
        }
        colnames(raw_data) <- c('datetime', 'var', 'comp_var')
        
        return(na.omit(raw_data))
      }
    })
    
    RadUnits <- reactive({
      if (input$rad_stage == 'Second Stage') {
        req(input$secfile)
        variables <- SelectedData$sec_units[[1]]
        
        for (i in 1:length(variables)) {
          if (grepl(variables[i], input$rad_var, ignore.case = TRUE)) {
            units <- SelectedData$sec_units[[2]][i]
          }
        }
        
      } else {
        req(input$thrfile)
        variables <- SelectedData$thr_units[[1]]
        
        for (i in 1:length(variables)) {
          if (grepl(variables[i], input$rad_var, ignore.case = TRUE)) {
            units <- SelectedData$thr_units[[2]][i]
          }
        }
      }
      units
    })
    
    observe({ # BEGIN RADIATION PLOTS
      req(c(input$secfile, input$timescale))
      raddat <- RadData()
      units <- RadUnits()
      
      if (!is.null(input$timescale)) {
        if (input$timescale == 'All Time') {
          output$rad_plot <- renderPlotly({ 
            
            raddat$date <- as.Date(raddat$datetime)
            
            daily_rad <- raddat %>% group_by(date) %>% summarise(across(c(var, comp_var), mean))
            
            ylabel <- paste0(input$rad_var, ' [', units, ']')
            ylabel2 <- paste0(input$rad_comp_var, ' [ W m-2 ]')
            
            rad_plot <- plot_ly(data = daily_rad) %>%
              add_trace(x = ~date, y = ~var, 
                        type = 'scatter', mode = 'lines', name = input$rad_var) %>%
              add_trace(x = ~date, y = ~comp_var, 
                        type = 'scatter', mode = 'lines', name = input$rad_comp_var, 
                        yaxis = "y2") %>%
              layout(
                yaxis2 = list(
                  title = ylabel2,
                  overlaying = "y",
                  side = "right"
                ),
                yaxis = list(
                  title = ylabel
                ),
                xaxis = list(range = c(min(daily_rad$date), 
                                       max(daily_rad$date))), 
                margin = list(
                  l = 80,
                  r = 80,  
                  t = 50,   
                  b = 100   
                ),
                legend = list(
                  x = 0,  
                  y = -0.2, 
                  orientation = 'h' 
                ),
                title = paste('Daily averaged', input$rad_var, 'compared to', input$rad_comp_var)
              )
          }) # END PLOT RENDER
        } else if (input$timescale == 'All Months') {
          req(input$rad_var)
          
          raddat$YearMonth <- format(as.Date(raddat$datetime), format = "%Y-%m")
          raddat$Hour <- format(raddat$datetime, format = "%H%M")
          raddat$Month <- format(raddat$datetime, format = "%m")
          
          month_labs <- c('01' = 'January', '02' = 'February', '03' = 'March',
                          '04' = 'April', '05' = 'May', '06' = 'June',
                          '07' = 'July', '08' = 'August', '09' = 'September',
                          '10' = 'October', '11' = 'November', '12' = 'December')
          
          month_labeller <- labeller(YearMonth = function(levels) month_labs[as.character(levels)])
          
          # CREATE LIST OF INDIVIDUAL MONTH PLOTS
          rad_plots <- list()
          yearmonths <- unique(raddat$YearMonth)
          
          for (month in yearmonths) {
            month_data <- raddat %>% filter(grepl(month, datetime))
            hourly_rad <- month_data %>% group_by(Hour) %>% summarise(across(c(var, comp_var), mean))
            hourly_rad$Hour <- as.numeric(hourly_rad$Hour)
            
            if (nrow(hourly_rad) > 2) {
              ylabel <- paste0(input$rad_var, ' [', units, ']')
              ylabel2 <- paste0(input$rad_comp_var, ' [ W m-2 ]')
              
              rad_plot <- ggplot(data = hourly_rad, aes(x = Hour)) +
                geom_line(aes(y = var), linetype = "solid", color = "dodgerblue3") +
                geom_line(aes(y = comp_var), linetype = "solid", color = "orangered3") +
                facet_wrap(month, nrow = 3, scales = "free_y") +
                labs(title = paste("Monthly Plots of", input$rad_var),
                     x = "Date",
                     y = ylabel) +
                scale_y_continuous(sec.axis = sec_axis(~ .,
                                                       name = ylabel2)) +
                theme_minimal()
              
              rad_plots[[as.character(month)]] <- rad_plot
            }
          }
          
          # ARRANGE ALL MONTHLY PLOTS IN GRID
          output$rad_plot <- renderPlotly({
            subplot(ggplots = rad_plots, nrows = 3, margin = 0.04) %>%
              layout(legend = list(orientation = "h"))
          })
          
        } else {
          yearmonth <- input$timescale
          monthly_rad <- raddat %>% filter(grepl(yearmonth, datetime))
          
          output$rad_plot <- renderPlotly({ 
            ylabel <- paste0(input$rad_var, ' [', units, ']')
            ylabel2 <- paste0(input$rad_comp_var, ' [ W m-2 ]')
            
            rad_plot <- plot_ly(data = monthly_rad) %>%
              add_trace(x = ~datetime, y = ~var, 
                        type = 'scatter', mode = 'lines', name = input$rad_var) %>%
              add_trace(x = ~datetime, y = ~comp_var, 
                        type = 'scatter', mode = 'lines', name = input$rad_comp_var, 
                        yaxis = "y2") %>%
              layout(
                yaxis2 = list(
                  title = ylabel2,
                  overlaying = "y",
                  side = "right"
                ),
                yaxis = list(
                  title = ylabel
                ),
                xaxis = list(range = c(min(monthly_rad$datetime), 
                                       max(monthly_rad$datetime))), 
                margin = list(
                  l = 80,
                  r = 80,  
                  t = 50,   
                  b = 100   
                ),
                legend = list(
                  x = 0,  
                  y = -0.2, 
                  orientation = 'h' 
                ),
                title = paste(input$rad_var, 'compared to', input$rad_comp_var, 'for', yearmonth)
              )
          }) # END PLOT RENDER
        }
      }
    })
    
    # MISSING DATA ----
    # ---------- #
    # DESCRIPTION
    # - this section shows a plot displaying the percentages of missing data (NAs)
    #   for each variable from the data provided. If both stage data's are given 
    #   two separate plots will be shown.
    # ---------- #
    
    missing_data <- reactive({
      req(input$secfile)
      
      sec_data <- SelectedData$sec_summary[, c('Variable',
                                               '% NA')]
      sec_df <- as.data.frame(sec_data)
      sec_df$stage <- 'Second'
      sec_df$year <- '2020'
      
      missing_data <- sec_df
      
      if (is.null(input$thrfile) == F) {
        req(input$thrfile)
        thr_data <- SelectedData$thr_summary[, c('Variable',
                                                 '% NA')]
        thr_df <- as.data.frame(thr_data)
        thr_df$stage <- 'Third'
        thr_df$year <- '2020'
        
        missing_data <- (rbind(sec_df, thr_df))
      }
      
      colnames(missing_data) <- c('Variable', 'NAs', 'Stage', 'Year')
      return(missing_data)
      
    })
    
    output$miss_plot <- renderPlotly({ # BEGIN MISSING PLOT RENDER
      missing_data <- missing_data() # Retrieve the reactive value once
      
      # Convert %NA to numeric
      missing_data$NAs <- as.numeric(missing_data$NAs)
      
      if (is.null(input$thrfile)) {
        # Only plot second stage data
        miss_plot <- ggplot(data = missing_data,
                            aes(x = Stage, 
                                y = Variable,
                                fill = missing_data$NAs)) +
          geom_raster() +
          xlab('') + ylab('') + labs(fill = "NAs") +
          scale_fill_gradient(high = 'orangered', low = 'dodgerblue',
                              limits = c(0, 100)) +
          theme_minimal() +
          theme(axis.text.x = element_text(angle = 40))
      } else {
        # Plot both second and third stage data side by side
        miss_plot <- ggplot(data = missing_data,
                            aes(x = Variable, 
                                y = missing_data$NAs,
                                fill = missing_data$NAs,
                                text = paste("Variable: ", Variable, "<br>% NA: ", NAs))) +
          geom_tile() +
          xlab('') + ylab('') + labs(fill = "NAs") +
          scale_fill_gradient(high = 'orangered', low = 'dodgerblue',
                              limits = c(0, 100)) +
          theme_minimal() +
          theme(axis.text.x = element_text(angle = 40)) +
          facet_wrap(~ Stage, ncol = 2)  # Split by Stage with 2 columns
      }
      
      ggplotly(miss_plot)
      
    })
    
    output$miss_sec <- renderTable({
      if (is.null(input$thrfile)) {
        t(missing_data()[, c('Variable', 'NAs')])
      } else {
        t(missing_data()[, c('Variable', 'NAs', 'Stage')]) %>%
          filter(Stage == 'Second')
      }
    })
    
    output$miss_thr <- renderTable({
      if (!is.null(input$thrfile)) {
        t(missing_data()[, c('Variable', 'NAs', 'Stage')]) %>%
          filter(Stage == 'Third')
      }
    })
    
    # SUMMARY STATISTICS ----
    # ---------- #
    # DESCRIPTION
    # - this section shows tables of the statistics for each variable from each
    #   stage's .csv
    # ---------- #
    
    # SECSTAG TABLE
    observeEvent(input$secfile, {
      secstagsum <- SelectedData$sec_summary
      
      output$summary_secstag <- renderTable({
        secstagsum
      }) # END SECSTAG TABLE RENDER
      
      # THRSTAG TABLE
      observeEvent(input$thrfile, {
        thrstagsum <- SelectedData$thr_summary
        
        output$summary_thrstag <- renderTable({
          thrstagsum
        }) # END SECSTAG TABLE RENDER
      }) # END THRSTAG SUMMARY 
    })
    
    
  }) # END REACTIVITY 
} # END SERVER

# 5. RUN SHINY APP ----
shinyApp(ui = ui, server = server)