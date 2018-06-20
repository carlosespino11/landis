library(ggmap)
library(tidyverse)
library(dbplyr)
library(sf)
library(tigris)
library(ggthemes)
library(scales)
library(caret)
##Get Charlotte block polygons
options(tigris_use_cache = TRUE)

meck_bg = block_groups(state = "NC", county = "Mecklenburg") %>%
  sf::st_as_sf()

## Connect to db
con <- DBI::dbConnect(RMySQL::MySQL(), 
                      host = "localhost",
                      user = "root",
                      db = 'landis'
)
houses_db <- tbl(con, "properties")

## Query houses
houses  = houses_db %>%
  filter( built_use_style == 'SINGLE FAMILY RESIDENTIAL' ) %>%
  mutate(total_appraised_value  = 
           ifelse(is.na(building_value), 0, building_value) + 
           ifelse(is.na(features), 0, features)+ 
           ifelse(is.na(land_value), 0, land_value)) %>%
  filter(!is.na(total_appraised_value), !is.na(year_built))%>%
  collect()

## Load parcels to georeference the data
all_parcels = sf::read_sf('./data/raw/Mecklenburg_parcels_2018_05_22/nc_mecklenburg_parcels_pt_2018_05_22.shp')

houses = all_parcels %>%right_join(houses , by= c('PARNO'='parcel_id')) %>% 
  st_transform(st_crs(meck_bg))

houses_bg = meck_bg %>% 
  sf::st_join(houses) %>%
  group_by(GEOID) %>%
  summarise_at(vars(total_appraised_value, year_built,
                    bedrooms, full_baths, half_baths,GISACRES), 
               funs(mean(.,na.rm = TRUE)))
  
  
# Intersect  houses with available polygons
##
street_points = read_sf('data/processed/streets/street_intersection_points_centrality.shp') %>% 
  st_transform(st_crs(meck_bg))

street_central_bg = meck_bg %>% 
  sf::st_join(street_points)%>%
  group_by(GEOID) %>%
  summarise_at(vars(degree:btwnnss), funs(mean))
  


# mapview::mapview(bg_central,  zcol ='btwnnss')
# mapview::mapview(houses_bg,  zcol ='total_appraised_value')
# 
# 

# houses_bg %>% write_rds('./data/processed/houses_bg.rds')
# street_central_bg %>% write_rds('./data/processed/geo_bg.rds')

st_geometry(street_central_bg) = NULL
features_bg = houses_bg  %>% left_join(street_central_bg)
features_bg %>% write_rds('./data/processed/fetures_bg.rds')

# Modeling
library(caret)

# Remove geometry 

st_geometry(features_bg) = NULL

# Remove NA's
model_df = features_bg %>% na.omit()

# Split into train and test
train_df = model_df %>%sample_frac(.8)
test_df  = setdiff(model_df, train_df)
true_y = test_df$total_appraised_value

# Define baseline prediction with the mean value of the target feature
pred_y.base = mean(train_df$total_appraised_value)
rmse.base = RMSE(pred_y.base, true_y)


# Model 1: Linear Regression with ElasticNet Regularization

# 5-fold cross validation
control <- trainControl(method = "cv", number = 5)

fit.glmnet = train(total_appraised_value~., train_df, 
            method = "glmnet", 
            trControl = control,
            preProc = c("center", "scale"))

pred_y.glmnet = predict(fit.glmnet, test_df)
rmse.glmnet = RMSE(pred_y.glmnet, true_y)

ggplot(tibble(pred_y = pred_y.glmnet, true_y =true_y)) + 
  labs(title = 'Linear Regression with ElasticNet Regularization', subtitle = 'True vs Predicted value') + 
  geom_point(aes(y = pred_y, x = true_y)) + 
  geom_abline(aes(slope=1, intercept = 0, colour='45° ref line')) + 
  scale_x_continuous(labels = scales::dollar)+
  scale_y_continuous(labels = scales::dollar)+
  theme_fivethirtyeight()

# Model 2: Random Forest
fit.rf = train(total_appraised_value~., train_df, 
                   method = "rf", 
                   trControl = control,
                   preProc = c("center", "scale"),
               importance = TRUE)

pred_y.rf = predict(fit.rf, test_df)
rmse.rf = RMSE(pred_y.rf, true_y)


ggplot(tibble(pred_y = pred_y.rf, true_y =true_y)) + 
  labs(title = 'Random Forest', subtitle = 'True vs Predicted value') + 
  geom_point(aes(y = pred_y, x = true_y)) + 
  geom_abline(aes(slope=1, intercept = 0, colour='45° ref line')) + 
  scale_x_continuous(labels = scales::dollar)+
  scale_y_continuous(labels = scales::dollar)+
  theme_fivethirtyeight()

# Put results in a table
tibble(model = c('base', 'glmnet', 'rf'),
       RMSE = c(rmse.base, rmse.glmnet, rmse.rf)
) %>% pander::pander()

# Variable importance
varImp(fit.rf)$importance %>% as.data.frame() %>% 
  rownames_to_column('feature') %>% 
  arrange(desc(Overall)) %>%
  ggplot() + 
  geom_bar(aes(y = Overall, x = fct_reorder(feature, Overall)), stat='identity')+
  coord_flip() + 
  labs(title = 'Variable Importance', subtitle = 'Best Model. RF.', x = 'feature') + 
  theme_fivethirtyeight()
  