## CDSI Workshop
## Creating a Shiny Dashboard in R
## Dr. Tim Elrick, McGill
## Fri, 25 November 2022
## CC-BY-SA 4.0


# Last stage: We add a tab panel to show two different tables on the 
#             graph and table page


# load packages and data --------------------------------------------------


library(shiny)
library(shinydashboard)
library(tidyverse)
library(lubridate)

ds <- 
  read_csv("../en_climate_daily_QC_7025251_2022_P1D_June.csv") %>% 
  select(-c(1:4, `Data Quality`, Year:Day), -ends_with("Flag")) %>% 
  rename(Date = `Date/Time`)


# Define user interface UI ------------------------------------------------

ui <- 
  dashboardPage(
    
    dashboardHeader(title = "Montreal Climate Data 2022"),
    
    dashboardSidebar(
      
      selectInput(inputId = "input_variable",
                  label = "Choose variable",
                  choices = names(ds)[-(1:4)]),
      
      sliderInput(inputId = "input_daterange",
                  label = "Choose date range",
                  min = ymd("2022-01-01"),
                  max = ymd("2022-06-01"),
                  value = c(ymd("2022-01-01"), ymd("2022-06-01")),
                  timeFormat = "%b %d"),
      
      checkboxInput(inputId = "input_trendline",
                    label = "Show trendline"),
      
      sidebarMenu(
        
        menuItem(text = "Graph & Table",
                 tabName = "graphtable",
                 icon = icon("dashboard")),
        
        menuItem(text = "Some numbers",
                 tabName = "somenumbers",
                 icon = icon("list"))
      )
      ),
    
    dashboardBody(
      
      tabItems(
        
        tabItem(
          tabName = "graphtable",
          
          fluidRow(
            tabBox(
              title = "Tables",
              tabPanel(
                title = "Single variable",
                div(
                  tableOutput(outputId = "output_table"),
                  style = "height:250px; overflow-y:scroll"
                )
              ),
              
              tabPanel(
                title = "Full table",
                div(
                  tableOutput(outputId = "output_table2"),
                  style = "height:250px; overflow:scroll;
                           background-color: #fff5c4"
                  )
                )
              )
            ),
          
          fluidRow(
            plotOutput(outputId = "output_graph")
          )
        ),
        
        tabItem(
          tabName = "somenumbers",
          
          fluidRow(
            infoBoxOutput(outputId = "output_maxvalue")
            )
          
          )
      )
    )
  )


# Define server logic ----------------------------------------------------

server <- function(input, output) {
  
  ds2 <- 
    reactive(ds %>% 
               select(Date, .data[[input$input_variable]]) %>% 
               filter(between(Date, input$input_daterange[1],
                              input$input_daterange[2]))
             )
  
  output$output_table <- 
    renderTable(ds2() %>% 
                  mutate(Date = as.character(Date)))
  
  output$output_graph <- 
    renderPlot(
      {
        g <- 
          ggplot(data = ds2(),
                 mapping = aes(x = Date,
                               y = .data[[input$input_variable]])) +
            geom_line() +
            labs(x = "", 
                 y = "",
                 title = input$input_variable) +
            theme_minimal()
      
        if (input$input_trendline) g + geom_smooth(se = F) else g
      }
    )
  
  output$output_maxvalue <- 
    renderInfoBox(
      infoBox(title = paste("Maximum of", input$input_variable),
              value = max(ds[[input$input_variable]], na.rm = TRUE)
      )
    )
  
  output$output_table2 <- 
    renderTable(ds %>% gt::gt())
}


# Run the application ---------------------------------------------------

shinyApp(ui, server)