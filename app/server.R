shinyServer(function(input, output, session) {
  # Reactive expression for selected city
  selectedCityFeature <- reactive({
    selected = input$city_feature
    return(selected)
  })
  
  # Reactive expression for selected census feature
  selectedCensusFeature <- reactive({
    city = isolate({input$city_feature})
    selected = if(is.null(input$census_feature))
      "total_appraised_value"
    else
      input$census_feature
    
    map = features_bg
    data = map %>% pull(selected)
    
    legend = selected
    
    return(list(data = data, selected = selected, legend = legend, census_map = map))
  })
  
  # Reactive expression for selected OSM feature
  selectedOSMFeature <- reactive({
    city = isolate({input$city_feature})
    selected = if(is.null(input$osm_feature))
      "btwnnss"
    else
      input$osm_feature
    
    map = features_bg
    data = map %>% pull(selected)
    
    legend =selected
    
    return(list(data = data, selected = selected, legend = legend, census_map = map))
  })
  
  observe({
    selected = selectedCityFeature()
    choiceMap = choices_map
    updateSelectInput(session, "census_feature", choices = choiceMap)
  })
  
  
  observe({
    selected = selectedCityFeature()
    
    choiceMap =choices_map
    updateSelectInput(session,"osm_feature", choices = choiceMap)
  })
  
  # Census map 
  output$deprivation_map <- renderLeaflet({
    # Aaspects of the map that  won't need to change dynamically
    leaflet() %>%
      addProviderTiles("CartoDB.DarkMatter") 
    
  })
  
  # OSM map
  output$variable_map <- renderLeaflet({
    # Aaspects of the map that  won't need to change dynamically
    leaflet() %>%
      addProviderTiles("CartoDB.DarkMatter")
    
  })
  
  # Detail map
  output$modal_map <- renderLeaflet({
    # Aaspects of the map that  won't need to change dynamically
    leaflet() %>%
      addProviderTiles("CartoDB.DarkMatter")
    
  })
  
  observe({
    selectedMap = selectedCensusFeature()
    selected =  selectedMap[["selected"]]
    feature = selectedMap[["data"]]
    legend = selectedMap[["legend"]]
    # featureName = selectedFeature()[["name"]]
    map = selectedMap[["census_map"]]
    extent = map %>% st_bbox
    
    
    city = isolate({input$city_feature})

    weight = .2
    zoom = 10    
    
    
    # # ids = map$GEOID
    # print(pal2(feature)(feature))
    # print(dim(map))
    # print(extent)
    delay(700, {
      leafletProxy("deprivation_map") %>%
        # syncWith("variable_map") %>%
        clearControls() %>%
        clearShapes() %>%
        # addPolygons(fillColor = pal2(feature)(feature),fillOpacity = 0.8, weight = weight, color="white",
        #             # layerId = ids,
        #             data = map)
        addPolygons(fillColor = pal2(feature)(feature),fillOpacity = 0.8, weight = weight, color="white",
                    # layerId = ids,
                    data = map)%>%
        addLegend(pal = pal2(feature),
                  values = feature,
                  position = "bottomleft",
                  title = legend,
                  # labels = c("Low",NA,NA,NA, "Medium",NA , NA ,NA ,NA,  "High"),
                  opacity=.9,
                  labFormat = labelFormat(digits = 2)
        )%>%
        setView(lng= mean(extent[c(1,3)]), lat = mean(extent[c(2,4)]),zoom =zoom)
    })
  })
  
  observe({
    selectedMap = selectedOSMFeature()
    selected =  selectedMap[["selected"]]
    feature = selectedMap[["data"]]
    legend = selectedMap[["legend"]]
    map = selectedMap[["census_map"]]
    
    
    extent = map %>% st_bbox
    
    city = isolate({input$city_feature})
    if(city == "milan"){
      weight = .4
      zoom = 12
    } else {
      weight = .2
      zoom = 10    
    }
    
    # ids = map$GEOID
    # featureName = selectedFeature()[["name"]]
    delay(700, {
      leafletProxy("variable_map") %>%
        # syncWith("deprivation_map") %>%
        clearControls() %>%
        clearShapes() %>%
        addPolygons(fillColor = pal(feature)(feature), fillOpacity = 0.8, weight = weight, color="white",
                    # layerId = ids,
                    data = map) %>%
        addLegend(pal = pal(feature),
                  values = feature,
                  position = "bottomright",
                  title = legend,
                  opacity=.9
        )%>%
        setView(lng= mean(extent[c(1,3)]), lat = mean(extent[c(2,4)]),zoom =zoom)
    })
  })
  # input$MAPID_click
  observeEvent(input$variable_map_shape_click, {
    event = input$variable_map_shape_click
    map_click_event_handler(event)
    toggleModal(session, "detail-modal", "open")
    
  })
  
  
  
  observeEvent(input$deprivation_map_shape_click, {
    event = input$deprivation_map_shape_click
    map_click_event_handler(event)
    toggleModal(session, "detail-modal", "open")
    
  })  
  
  
  map_click_event_handler_update_map = function(event){
    init_vars_map_click(event)
    
    delay(700, {
      leafletProxy("modal_map") %>%
        clearControls() %>%
        clearShapes() %>%
        setView(lng= mean(extent[1,]), lat = mean(extent[2,]), zoom = 14)%>%
        addPolygons(fillColor = pal2(feature)(filtered_feature), 
                    fillOpacity = 0.8, 
                    weight = weight, 
                    color="white",
                    data = filtered_map)  %>%
        addPolylines(weight = 2, 
                     color= roadPal(street_map$closeness)(filtered_streets$closeness), 
                     data=filtered_streets)%>%
        addCircles(lng= ~lon, lat= ~lat, weight = 1,radius = 20,color="white",
                   fillColor = classPal(amenity_map$amenity)(filtered_amenities$amenity),
                   fillOpacity =1, data= filtered_amenities) %>%
        addLegend(pal = classPal(amenity_map$amenity),
                  values = amenity_map$amenity,
                  position = "bottomleft",
                  title = "amenity",
                  opacity=.9
        ) %>%
        addLegend(pal = roadPal(street_map$closeness),
                  values = street_map$closeness,
                  position = "bottomright",
                  title = "betwenness <br> centrality",
                  opacity=.9
        ) 
    })
  }
  map_click_event_handler_plot = function(event) {
    init_vars_map_click(event)
    
    df = map@data %>% dplyr::select(ends_with("osm")) %>%
      gather(key, value) %>% 
      mutate(key = {key %>% gsub("idw_", "",.)  %>% gsub("_osm", "",.) %>% gsub("_", " ",.)})
    
    # plot_names = unique(df$key) %>% gsub("idw_", "",.)  %>% gsub("_osm", "",.) %>% gsub("_", " ",.) 
    # print(plot_names)
    # subset(street_map, unlist(street_map@data[poly_ids[[city]]]) == poly_id)
    df_selected = filtered_map@data %>% dplyr::select(ends_with("osm")) %>%
      gather(key, value) %>% 
      mutate(key = {key %>% gsub("idw_", "",.)  %>% gsub("_osm", "",.) %>% gsub("_", " ",.)})
    
    ggplot(df) + geom_boxplot(aes(1, value), fill = "#303030",size=.5,color = "darkgrey") +
      geom_hline(aes(yintercept=value), color="#EE82EE", size=1.2, data= df_selected)+
      facet_grid(key~., scales="free_y") + 
      coord_flip() +
      theme_fivethirtyeight()+
      theme(strip.text.y = element_text(angle=0), axis.text = element_blank(),
            axis.title = element_blank(), axis.ticks.y = element_blank(),
            panel.background = element_rect(fill = "#303030"),
            plot.background = element_rect(fill = "#303030"),
            # axis.title = element_text(colour = "white"),
            # axis.text = element_text(colour = "white"),
            panel.grid = element_blank(),
            strip.background = element_rect(fill = "black"),
            strip.text = element_text(colour = "white")
      )
  }
  
  output$scatter_plot <- renderPlot({
    selectedCensus = selectedCensusFeature()
    
    selected_census =  selectedCensus[["selected"]]
    feature_census  = selectedCensus[["data"]]
    featureName_census = selectedCensus[["legend"]]
    
    selectedOSM = selectedOSMFeature()
    
    selected_osm =  selectedOSM[["selected"]]
    feature_osm  = selectedOSM[["data"]]
    featureName_osm = selectedOSM[["legend"]]
    
    if(length(feature_osm) != length(feature_census)){
      plot = ggplot()
    } else {
      plot_df = data.frame(selected_osm  = feature_osm, selected_census = feature_census)
      names(plot_df) = c(selected_osm, selected_census)
      
      plot = ggplot(data = plot_df) +
        geom_point(aes_string(x = selected_osm, y = selected_census), size =.8, color="white") +
        geom_smooth(aes_string(x = selected_osm, y = selected_census),method = "lm", fill="lightgrey", color = "#6FDCF1") +
        theme_fivethirtyeight() +
        # theme(plot.title = element_text(hjust = 1)) +
        labs(x = featureName_osm, y=featureName_census) +
        theme(panel.background = element_rect(fill = "black"),
              plot.background = element_rect(fill = "black"),
              axis.title = element_text(colour = "white"),
              axis.text = element_text(colour = "white"))
    }
    plot
    # layout(plot_bgcolor='rgb(254, 247, 234, .5)') %>%
    # layout(paper_bgcolor='rgb(254, 247, 234, .5)')
    # labs(title = paste(selected_osm," vs ",selected_census, sep=""), x = featureName_osm, y=featureName_census)
  })
  map_click_event_handler <- function(event) {
    map_click_event_handler_update_map(event)
    output$selected_distribution <- renderPlot({
      map_click_event_handler_plot(event)
    })
    output$selected_rank <- renderTable({
      map_click_event_handler_table(event)
    },include.rownames=FALSE)
    output$modal_title <- renderText({
      paste("Detail", event$id)
    })
  }
  
  output$census_map_title <- renderText({
    selectedMap = selectedCensusFeature()
    selectedMap[["legend"]]
  })
  output$variable_map_title <- renderText({
    selectedMap = selectedOSMFeature()
    selectedMap[["legend"]]
  })
  
  output$census_statistics <- renderTable({
    
    selectedMap = selectedCensusFeature()
    
    selected =  selectedMap[["selected"]]
    feature = selectedMap[["data"]]
    legend = selectedMap[["legend"]]
    
    
    summary(feature) %>% broom::tidy() %>% 
      dplyr::select(minimum, median, mean, maximum)%>% 
      setNames(c("min", "median", "mean", "max")) 
  }, 
  include.rownames=FALSE)
  
  output$census_density <- renderPlot({
    
    selectedMap = selectedCensusFeature()
    
    selected =  selectedMap[["selected"]]
    feature = selectedMap[["data"]]
    legend = selectedMap[["legend"]]
    
    
    p = ggplot() + geom_density(aes(x = feature), fill = "#EE82EE", alpha=.7) + 
      labs(x = legend) + theme_fivethirtyeight() + 
      theme(axis.title=element_blank(),
            panel.background = element_rect(fill = "black"),
            plot.background = element_rect(fill = "black"),
            # axis.title = element_text(colour = "white"),
            axis.text = element_text(colour = "white"))
    p
    
  })
  
  
  # output$selected_rank <- renderTable({
  map_click_event_handler_table = function(event){
    init_vars_map_click(event)
    
    ranked = map@data %>% arrange_(defaults[[city]])
    ranked$percentile = percent_rank(ranked[defaults[[city]]])
    ranked$rank = 1:dim(ranked)[1]
    
    index = which(ranked[poly_ids[[city]]] == poly_id)
    
    surroundings = (index - 2):(index + 2)
    while( sum(surroundings <=0) > 0 ){surroundings = surroundings + 1}
    while( sum(surroundings > dim(map@data)[1]) > 0 ){surroundings = surroundings - 1}
    
    table = ranked %>% slice(surroundings) %>% dplyr::select_("rank", "percentile", poly_ids[[city]],  defaults[[city]]) 
    names(table) = c("rank", "percentile", "id",  reverseList(censusMap[[city]])[[defaults[[city]]]])
    
    table
  }
  
  init_vars_map_click = function(event){
    poly_id <<- event$id
    
    city <<- isolate({input$city_feature})
    
    map <<- census[[city]]
    street_map <<- streets[[city]]
    amenity_map <<- amenities[[city]]
    
    filtered_map <<- subset(map, unlist(map@data[poly_ids[[city]]]) == poly_id)
    
    selected <<- isolate({input$census_feature})
    feature <<- unlist(map@data[selected])
    
    filtered_feature <<- unlist(filtered_map@data[selected])
    
    filtered_streets <<- subset(street_map, unlist(street_map@data[poly_ids[[city]]]) == poly_id)
    
    filtered_amenities <<- amenity_map[amenity_map[poly_ids[[city]]] == poly_id,]
    
    extent <<- filtered_map@bbox
    # 
    # city = isolate({input$city_feature})
    if(city == "milan"){
      weight <<- .4
      zoom <<- 14
    } else {
      weight <<- .2
      zoom <<- 17
    }
    # 
  }
})