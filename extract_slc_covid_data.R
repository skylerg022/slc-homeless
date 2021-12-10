## Skyler Gray
## Code to extract Salt Lake county's COVID case count data from Johns Hopkins
##  University Center for Systems Science and Engineering's Github page
##  (https://github.com/CSSEGISandData/COVID-19/blob/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_US.csv)

library(tidyverse)
library(lubridate)
library(pdftools)
library(rgdal)
library(rgeos) # For tidy() function
library(broom) #contains tidy() function which converts polygons to data.frame


# set working directory if necessary
if (rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
}

pic_width <- 7
pic_height <- 4
pic_unit <- 'in'

# Clean/extract Salt Lake county COVID data -------------------------------

covid <- read_csv('data/time_series_covid19_confirmed_US.txt') %>%
  filter(Admin2 == 'Salt Lake') %>%
  pivot_longer(cols = c(`1/22/20`:`11/8/21`),
               names_to = 'date',
               values_to = 'total_cases') %>%
  mutate(date = mdy(date)) %>%
  select(date, total_cases)

n <- nrow(covid)
new_cases <- c(0, covid$total_cases[-1] - covid$total_cases[-n])
covid <- covid %>%
  mutate(cases = new_cases,
         cases_avg7 = zoo::rollapply(cases, 7, mean, 
                                     align='right', fill=0))

# plot(covid$cases_avg7, type = 'l')
# looks good to me!

# Write out cleaned data file
write_csv(covid, 'data/covid19_cases_saltlakecounty.csv')


# Add census tract population dataset ----------------------------------------

# Pull pdf table data from SLC Data Book 2020
slc_book <- pdf_text("data/sources/SLC-Data-Book-2020forWeb.pdf")

temp <- str_split(slc_book[9], '\n')[[1]] %>% # Extract table
  .[-c(1:15, 46:55)] %>% # Keep only table info
  str_split_fixed(' {2,}', 12)
pop_2019 <- rbind(temp[,1:6],
                  temp[,7:12]) %>%
  data.frame(stringsAsFactors = FALSE) %>%
  rename(map_code = X1, 
         tract = X2,
         population = X4) %>%
  select(map_code, tract, population) %>%
  mutate(population = str_remove(population, ',') %>%
           as.numeric(), # Convert counts to numeric
         map_code = str_extract(map_code, '[A-Z][0-9]+'), # Remove note markers
         tract = case_when(nchar(tract) == 4 ~ paste0(tract, '00'),
                           TRUE       ~ str_remove(tract, '\\.'))) %>%
  filter(!is.na(map_code))


# Add median income
idx <- grep('Table 32: Median Household Income', slc_book)

temp <- str_split(slc_book[idx], '\n')[[1]] %>% # Extract table
  .[-c(1:16, 47:55)] %>% # Keep only table info
  str_split_fixed(' {2,}', 8)
inc_2019 <- rbind(temp[,1:4],
                  temp[,5:8]) %>%
  data.frame(stringsAsFactors = FALSE) %>%
  rename(map_code = X1, 
         tract = X2,
         income = X3) %>%
  select(map_code, tract, income) %>%
  mutate(income = str_remove_all(income, '\\$|,') %>%
           str_replace('-', '-1') %>%
           as.numeric(), # Convert counts to numeric
         map_code = str_extract(map_code, '[A-Z][0-9]+'), # Remove note markers
         tract = case_when(nchar(tract) == 4 ~ paste0(tract, '00'),
                           TRUE              ~ str_remove(tract, '\\.'))) %>%
  filter(!is.na(map_code))

write_csv(inc_2019, 'data/slc_income_2019_est_tracts.csv')


# Shapefile dataset for census tracts 2010 --------------------------------

path <- 'data/Utah_Census_Tracts_2010'
myShp <- readOGR(dsn = path, layer = 'CensusTracts2010')
slcShp <- myShp[myShp$COUNTYFP10 == '035' & myShp$TRACTCE10 %in% pop_2019$tract,]
writeOGR(slcShp, 
         dsn = 'data/SLC_Census_Tracts_2010',
         layer = 'CensusTracts2010',
         driver = 'ESRI Shapefile',
         overwrite_layer = TRUE)

pop_2019 <- pop_2019 %>%
  left_join(slcShp@data %>%
              rename(tract = TRACTCE10) %>%
              mutate(across(c(AREALAND, AREAWATR), as.numeric),
                     sqMiles = (AREALAND + AREAWATR)/2589988) %>%
              select(tract, sqMiles),
            by = 'tract') %>%
  mutate(density = population / sqMiles)

write_csv(pop_2019, 'data/slc_population_2019_est_tracts.csv')

# Clean homelessness report data ------------------------------------------

dt_str <- '%m/%d/%Y  %H:%M:%S %p'
homeless <- read_csv('data/Service_Request_SLCMobile_Homeless.csv',
                     col_types = cols(DateCreated = col_datetime(dt_str),
                                      DateClosed = col_datetime(dt_str))) %>%
  janitor::clean_names() %>%
  arrange(date_closed) %>%
  filter(!is.na(date_closed),
         date_created > min(covid$date),
         date_created <= '2021-10-31') %>%
  mutate(min_from_last_close = as.double(date_closed - lag(date_closed))/60) %>%
  mutate(days_open = round( as.double(date_closed - date_created)/(60*24) ),
         across(c(date_created, date_closed), as_date), # datetime to date
         district = str_extract(initial_boundary_name,
                                'Council District [1-9]') %>%
           str_extract('[1-9]'),
         neighborhood = str_extract(initial_boundary_name,
                                    '[^;]+$'),
         lat = str_extract(new_georeferenced_column,
                           '[\\-0-9\\.]+') %>%
           as.double(),
         long = str_extract(new_georeferenced_column,
                           '[\\-0-9\\.]+\\)$') %>%
           str_remove('\\)') %>%
           as.double(),
         # Adding district for one observation missing it
         district = ifelse(neighborhood == 'Sugar House' & is.na(district),
                           '7', district)) %>%
  select(-c(date_updated, request_type:device_type))

# Save ggplot of unfiltered data
p1 <- homeless %>%
  ggplot(aes(date_created, date_closed)) +
  geom_point(alpha = 0.3) +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, vjust = 0.5, hjust=0.5)) +
  labs(x = 'Date Created', y = 'Date Closed')

# Write only location report data
homeless %>%
  select(id, district, lat, long) %>%
  write_csv('data/slc_homeless_only_locations.csv')

# CLEANING OUT DATA THAT MAY NOT PROVIDE INSIGHT
# Filter out days with 5 or more requests closed within 3 min. intervals
quick_close_days <- homeless %>%
  filter(min_from_last_close < 3/60) %>%
  pull(date_closed) %>%
  table() %>% sort(TRUE) %>%
  .[. > 3] %>%
  names()

# Filter out days with a crazy number of closed requests
# cases <- table(homeless$date_closed) %>%
#   table()
# cdf <- cumsum(cases) / sum(cases)
# Filter out the top 10% of cases: Dates with 50 or more cases closed
crazy_close_days <- table(homeless$date_closed) %>%
  sort(TRUE) %>%
  .[. > 50] %>%
  names()

# # Observations of dates that will be filtered out
# homeless %>%
#   filter( (date_closed %in% date(quick_close_days)) |
#           (date_closed %in% date(crazy_close_days)) ) %>%
#   ggplot(aes(date_created, date_closed)) +
#   geom_point()

homeless2 <- homeless %>%
  filter( !(date_closed %in% date(quick_close_days)),
          !(date_closed %in% date(crazy_close_days)) ) %>%
  filter(date_closed != '2020-12-29') %>%
  select(-min_from_last_close)

# Save filtered data visualization
p2 <- homeless2 %>%
  ggplot(aes(date_created, date_closed)) +
  geom_point(alpha = 0.3) +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, vjust = 0.5, hjust=0.5)) +
  labs(x = 'Date Created', y = 'Date Closed')

cowplot::plot_grid(p1, p2, nrow = 1) %>%
  ggsave(filename = 'plots/data_openclose.png',
         plot = .,
         device = 'png',
         dpi = 300,
         width = pic_width, 
         height = pic_height,
         units = pic_unit)


# Add tract of report
report_loc <- SpatialPoints(homeless2 %>%
                              select(long, lat),
                            proj4string = CRS(proj4string(myShp)))
report_tract <- over(report_loc, myShp)$TRACTCE10
homeless2$tract <- report_tract

write_csv(homeless2, 'data/homeless_requests.csv')


# Add district population dataset -----------------------------------------

# Salt Lake City district population 2019 estimate
#  OBTAINED FROM 2020 SALT LAKE CITY DATA BOOK
#  URL: https://www.slc.gov/hand/wp-content/uploads/sites/12/2020/10/SLC-Data-Book-2020forWeb.pdf

pop <- read.table(header = TRUE, text = '
                  district, population
                  1, 28734
                  2, 26915
                  3, 28603
                  4, 32294
                  5, 26773
                  6, 27627
                  7, 28730',
                  sep = ',') %>%
  mutate(district = as.character(district))

write_csv(pop, 'data/slc_population_2019_est.csv')

