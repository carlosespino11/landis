

pal <- function(x) {
  n = 7
  quant_list = quantile(x, probs = seq(0, 1, 1/n), na.rm = T)
  if (length(unique(quant_list)) == n+1)
    # colorQuantile(c("black", "#99FFCC"), x, n = n, na.color = "black")
    colorBin(c("black", "#99FFCC"), x, bins = quant_list, na.color = "black")
  
  else
    colorBin(c("black", "#99FFCC"), x, bins = n, na.color = "black")

  
  }

pal2 <- function(x) {
  n = 7
  quant_list = quantile(x, probs = seq(0, 1, 1/n), na.rm = TRUE)
  
  if (length(unique(quant_list)) == n+1) 
    colorBin(c("black", "#EE82EE"), x, bins=quant_list, na.color = "black")
  else
    colorBin(c("black", "#EE82EE"), x, bins = n, na.color = "black")
  
}

classPal <- function(x) {
  #ffff33
  # palette = brewer.pal(name="Set1", n=5)
  palette = c("#E41A1C", "#377EB8", "#4DAF4A", "#ffff33", "#FF7F00")
  colorFactor(palette= palette, domain = x)

}

reverseList = function(hash_list){
  revMap = list()
  for(key in names(hash_list)){ revMap[[hash_list[[key]]]] = key }
  return(revMap)
}
# palette <- rev(brewer.pal(10, "RdYlBu")) #Spectral #RdYlBu
palette <- brewer.pal(10, "YlGnBu") #Spectral #RdYlBu

roadPal = function(x) {colorBin(palette = palette, domain = x, bins=quantile(x, probs = seq(0, 1, 0.1), na.rm=TRUE))}


extent = st_bbox(features_bg)


cityMap = list("Charlotte" = "charlotte")
# cityMap = 'charlotte'            

# mexicoCensusMap = list("deprivation" = "IMU")

choices_map = names(features_bg) 
names(choices_map) = choices_map
choices_map = as.list(choices_map)
# choices_map  = list("total_appraised_value" ="total_appraised_value", 'btwnss' ='btwnss')
