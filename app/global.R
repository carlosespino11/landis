library(shiny)
library(leaflet)
library(maptools)
library(dplyr)
library(ggthemes)
library(ggplot2)
library(ggthemes)
library(shinyBS)
library(shinyjs)
library(tidyr)
library(RColorBrewer)
library(magrittr)
library(tidyverse)
library(sf)

#' Read datasets
features_bg = read_rds('./data/fetures_bg.rds') %>%dplyr::select(-GEOID)%>%
  st_transform(st_crs('+proj=longlat +datum=WGS84'))


source("app-utils.R")