library(readr)
library(dplyr)
library(maptools)
library(sp)
library(rgdal)
library(leaflet)
library(rgeos)
library(shp2graph)
library(magrittr)
library(RColorBrewer)
library(webshot)
library(htmlwidgets)
library(sf)


#' Read Street network shapefile
# streets = read_sf('data/streets/Streets.shp')
streets = readOGR("data/raw/streets/Streets.shp" ) %>%
  spTransform(CRS("+proj=utm +zone=32 +datum=WGS84 +units=m"))
streets %<>% subset(RCOUNTY =='MECK' & LCOUNTY == 'MECK')

# Plot street shapefile
# streets%>% spTransform(CRS("+init=epsg:4326")) %>% leaflet() %>%
# addProviderTiles("CartoDB.Positron") %>%
# addPolylines(weight = .4, color="black")

#' Create graph object from shapefile
street_graph_list = readshpnw(streets, ELComputed=TRUE, longlat=FALSE) 
street_graph = nel2igraph(street_graph_list[[2]],street_graph_list[[3]],
                          weight=street_graph_list[[4]])


#' Remove self loops
# street_graph %<>% simplify()

#' Plot results
# street_graph %>%
# simplify() %>% 
# plot(vertex.label=NA, vertex.size=.1,vertex.size2=.1, edge.curved = FALSE)
 

#' Compute some centrality measures
eig = eigen_centrality(street_graph, weight=E(street_graph)$weight)$vector
deg = degree(street_graph)
bet = betweenness(street_graph,normalized = TRUE)
close = closeness(street_graph,normalized = TRUE)
# bet = betweenness.estimate(street_graph, cutoff=20000, directed=FALSE)
# close = closeness.estimate(street_graph, cutoff=20000)

V(street_graph)$degree = deg
V(street_graph)$closeness = close
V(street_graph)$betweenness = bet
V(street_graph)$eigen = eig


#' Create SpatialPoints from nodes. This will be useful to aggreagte later by a certain geography
#' 
intersections_data_frame = get.data.frame(street_graph, what="vertices")

coordinates(intersections_data_frame)= ~ x +y
proj4string(intersections_data_frame ) = CRS("+proj=utm +zone=32 +datum=WGS84 +units=m")
intersections_data_frame %<>% spTransform(CRS("+init=epsg:4326"))

#' Save SpatialPointsDataFrame
writePointsShape(intersections_data_frame, "./data/processed/streets/street_intersection_points_centrality.shp")
intersections_data_frame%>%sf::st_as_sf() %>%
  write_sf( "./data/processed/streets/street_intersection_points_centrality.shp")


##' Convert back the graph object to a shapefile
#' Create data frame with the information for all edges
street_data_frame = as_data_frame(street_graph)
street_data_frame %<>% 
  mutate(closeness = (vertex_attr(street_graph, "closeness", to)+
                        vertex_attr(street_graph, "closeness", from))/2,
         betweenness = (vertex_attr(street_graph, "betweenness", to)+
                          vertex_attr(street_graph, "betweenness", from))/2,
         degree = (vertex_attr(street_graph, "degree", to)+
                     vertex_attr(street_graph, "degree", from))/2,
         eigen = (vertex_attr(street_graph, "eigen", to)+
                    vertex_attr(street_graph, "eigen", from))/2,
         from.lon =vertex_attr(street_graph, "x", from),
         from.lat =vertex_attr(street_graph, "y", from),
         to.lon =vertex_attr(street_graph, "x", to),
         to.lat =vertex_attr(street_graph, "y", to)
  )%>% 
  tibble::rownames_to_column("id")

#' Create SpatialLinesDataFrame
lines_list = apply(street_data_frame, 1,function(row){
  Lines(
    Line(
      rbind(as.numeric(c(row["from.lon"], row["from.lat"])),
            as.numeric(c(row["to.lon"], row["to.lat"])))
    ),
    ID= row["id"])
})

spatial_lines = SpatialLines(lines_list)
lines_df = SpatialLinesDataFrame(SpatialLines(lines_list), data=as.data.frame(street_data_frame))
proj4string(lines_df) = CRS("+proj=utm +zone=32 +datum=WGS84 +units=m")

lines_df %<>% spTransform(CRS("+init=epsg:4326"))



#' Plot result into a map
palette <- rev(brewer.pal(10, "RdYlBu")) #Spectral #RdYlBu
# palette <- rev(brewer.pal(10, "Spectral")) #Spectral #RdYlBu

roadPal = function(x) {colorQuantile(palette = palette, domain = x, n=10)}

close_points_map = leaflet(intersections_data_frame) %>%
  addProviderTiles("CartoDB.Positron") %>%
  addCircles(weight = 1, color=~roadPal(closeness)(closeness))
close_points_map

close_map = leaflet(lines_df) %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolylines(weight = 1, color=~roadPal(closeness)(closeness))
close_map

bet_points_map = leaflet(intersections_data_frame) %>%
  addProviderTiles("CartoDB.Positron") %>%
  addCircles(weight = 1, color=~roadPal(betweenness)(betweenness)) 
bet_points_map

bet_map = leaflet(lines_df) %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolylines(weight = 1, color=~roadPal(betweenness)(betweenness)) 
bet_map

saveWidget(close_map, paste(getwd(),"/figures/street_closeness.html", sep=""), selfcontained = TRUE)
saveWidget(bet_map, paste(getwd(),"/figures/street_betweeness.html", sep=""), selfcontained = TRUE)


#' Save SpatialLinesDataFrame
writeLinesShape(lines_df, "data/processed/streets/streets_lines_centrality.shp")
