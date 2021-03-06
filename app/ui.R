shinyUI(
  bootstrapPage(
    tags$head(
      #' App custom styles
      includeCSS("www/css/styles.css"),
      #' Scripts to sync maps
      includeScript("www/js/L.Map.Sync.js"),
      includeScript("www/js/sync_maps.js")
    ),
    #' Main container
    fluidRow(class="map-container",
             #' Left map panel
             column(6, class="left-side",
                    leafletOutput("deprivation_map", width = "100%", height = "100%"),
                    absolutePanel(top = 50, left = 45,h3(textOutput("census_map_title")))),
             #' Right map panel
             column(6, class="right-side",
                    leafletOutput("variable_map", width = "100%", height = "100%"),
                    absolutePanel(top = 50, left = 45,h3(textOutput("variable_map_title"))))

    ),
    #' Controls panel
    absolutePanel(top = 130, id = "controls", class = "panel panel-default middle",
                  fixed = TRUE, draggable = TRUE,height = "auto", width =  "350px",
                  h4("city"),
                  selectInput("city_feature", NA, choices = cityMap, selected="charlotte"),
                  h4("Property value (left map)"),
                  selectInput("census_feature", NA, choices = choices_map, selected="total_appraised_value"),
                  h5("density of chosen feature"),
                  plotOutput('census_density', height = 125),
                  h4("Compare to (right map)"),
                  selectInput("osm_feature", NA, choices = choices_map, selected="btwnnss"),
                  h5("scatterplot"),
                  plotOutput("scatter_plot", height = 175)
                  
                  
    ),
    #' Modal panel. It opens after a polygon click
    absolutePanel(top = 0, left = 35, headerPanel("Charlotte property prices")),
    bsModal("detail-modal", textOutput("modal_title"), "tabBut", size = "large",
            useShinyjs(),
            leafletOutput("modal_map", width = "100%", height = "300px"),
            fluidRow(class="some-class",
                     column(6, class="left-side",
                            h4("OSM Distribution"),
                            plotOutput("selected_distribution", width = "100%", height = "250px")),
                     column(6, class="right-side",
                            h4("Deprivation rank"),
                            tableOutput("selected_rank"))
            )
    )
  )
)