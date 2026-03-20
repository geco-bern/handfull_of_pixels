library(dplyr)
library(appeears)

options(keyring_backend="file")
set.seed(42)

dir.create(here::here("data/lulc_competition_2025/"), showWarnings = FALSE)
dir.create(here::here("data/lulc_competition_2025/lst/"), showWarnings = FALSE)
dir.create(here::here("data/lulc_competition_2025/nbar/"), showWarnings = FALSE)
dir.create(here::here("data/lulc_competition_2025/dem/"), showWarnings = FALSE)

#---- download reference_sites site data ----

# From geo-wiki download reference / reference_sites data
# https://zenodo.org/record/6572482/files/Global%20LULC%20reference%20data%20.csv?download=1
# This contains >130K samples, reduce to 1500 stratified random?

reference_sites <- readr::read_csv(
  "https://zenodo.org/record/6572482/files/Global%20LULC%20reference%20data%20.csv?download=1"
)

reference_sites_selection <- reference_sites |>
  filter(
    (competition == 4 | competition == 1)
  ) |>
  group_by(pixelID) |>
  summarize(
    LC1 = as.numeric(names(which.max(table(LC1)))),
    lat = lat[1],
    lon = lon[1]
  )

reference_sites_selection <- reference_sites_selection |>
  group_by(
    LC1
  ) |>
  sample_n(300) |>
  ungroup()

# if (l != rows){
#   break
# }

# split reference_sites selection
# by land cover type
reference_sites_selection <- reference_sites_selection |>
  group_by(LC1) |>
  group_split()

saveRDS(
  reference_sites_selection,
  here::here("data/lulc_competition_2025/competition_selection.rds"),
  compress = "xz"
  )

reference_sites_selection <- readr::read_rds(here::here("data/lulc_competition_2025/competition_selection.rds"))
#---- format appeears download tasks ----

# for every row download the data for this
# location and the specified reflectance
# bands
task_nbar <- lapply(reference_sites_selection, function(x){
  
  product <- "MCD43A4.061"
  layer <- c(
    paste0("Nadir_Reflectance_Band", 1:7),
    paste0("BRDF_Albedo_Band_Mandatory_Quality_Band", 1:7)
  )
  
  base_query <- x |>
    rowwise() |>
    do({
      data.frame(
        task = paste0("nbar_lc_",.$LC1),
        subtask = as.character(.$pixelID),
        latitude = .$lat,
        longitude = .$lon,
        start = "2012-01-01",
        end = "2012-12-31",
        product = product,
        layer = as.character(layer)
      )
    }) |>
    ungroup()
  
  # build a task JSON string 
  task <- rs_build_task(
    df = base_query
  )
  
  # return task
  return(task)
})

task_lst <- lapply(reference_sites_selection, function(x){
  
  product <- "MOD11A2.061"
  layer <- c(
    paste0("LST_Day_1km"),
    paste0("QC_Day")
  )
  
  base_query <- x |>
    rowwise() |>
    do({
      data.frame(
        task = paste0("lst_lc_",.$LC1),
        subtask = as.character(.$pixelID),
        latitude = .$lat,
        longitude = .$lon,
        start = "2012-01-01",
        end = "2012-12-31",
        product = product,
        layer = as.character(layer)
      )
    }) |>
    ungroup()
  
  # build a task JSON string 
  task <- rs_build_task(
    df = base_query
  )
  
  # return task
  return(task)
})

# download dem data
task_dem <- lapply(reference_sites_selection, function(x){

  # construct basic query
  df <- data.frame(
    task = paste0("dem_lc_", x$LC1),
    subtask = as.character(x$pixelID),
    latitude = x$lat,
    longitude = x$lon,
    start = "2012-01-01",
    end = "2012-12-31",
    product = "NASADEM_NC.001",
    layer = c(
      "NASADEM_HGT"
    )
  )

  # build a task JSON string
  task <- rs_build_task(
    df = df
  )

  # return task
  return(task)
})

#--- schedule all downloads in batches of 10 ----

# request the task to be executed
# Note that in November 2025, DEM takes 10x30 minutes, LST takes 10x45minutes 
# and NBAR takes 10x1800minutes [!!] i.e. about 2 weeks. It might be that the
# storage pattern on AppEEARS is not at all optimized for this type of data 
# access pattern. (We are accessing all pixels grouped by the land cover classes
#                  Might it be better to do group them regionally?)
status_elevation <- rs_request_batch(
  request_list = task_dem,
  workers = 10,
  user = "fabern",
  path = here::here("data/lulc_competition_2025/dem"),
  verbose = TRUE,
  time_out = 4
)
# saveRDS(status_elevation,   here::here("data/lulc_competition_2025/dem/status.rds"))


status_reflectance <- rs_request_batch(
  request_list = task_nbar,
  workers = 10,
  user = "fabern",
  path = here::here("data/lulc_competition_2025/nbar"),
  verbose = TRUE,
  time_out = 4
)
# saveRDS(status_reflectance, here::here("data/lulc_competition_2025/nbar/status.rds"))

status_temperature <- rs_request_batch(
  request_list = task_lst,
  workers = 10,
  user = "fabern",
  path = here::here("data/lulc_competition_2025/lst"),
  verbose = TRUE,
  time_out = 4
)
# saveRDS(status_temperature, here::here("data/lulc_competition_2025/lst/status.rds"))

# If above takes time, then: 
# - Let it be performed in the background.
# - Go to https://appeears.earthdatacloud.nasa.gov/explore
# - copy the 30 request IDs (of the 30 tasks)
# - download once tasks are complete with rs_transfer():
dem_request_ids <- c("7661a93f-2f28-4beb-8514-502e145090f1",
                     "53ab76c5-4027-4163-beb5-c61adbf4d047",
                     "e02237fa-ab80-4fcc-8ede-7344ace02230",
                     "3ce78d40-9f66-4c50-ba98-18db3fe8cb5a",
                     "47f1c699-506c-4a0d-8a27-40794748299f",
                     "1a8f929a-2386-47ac-8945-ff3422b3960f",
                     "ff2efa71-d7e8-4ed1-a25f-9e4d2325db7b",
                     "d4b74384-7204-4ff6-971c-83eb5bb1e9ff",
                     "736f60e4-ff8e-4952-8421-175cda78f807",
                     "d759d330-eb58-4792-be58-74f1c4c602fe")
for(task_id in dem_request_ids){
  appeears::rs_transfer(task_id = task_id, 
                        user = "fabern",
                        path = here::here("data/lulc_competition_2025/dem"),
                        verbose = TRUE)
}

lst_request_ids <- c("7affa362-0795-45d1-8531-647da3e885a2",
                     "9f28ea37-72a6-4652-8286-0aaec8d547f4",
                     "1364cc63-d5fd-416a-871c-34d85d0617b4",
                     "c6be122d-91a1-4832-91cd-11565c676216",
                     "331351e4-86a8-499a-8204-b19f3ed65dca",
                     "66747b2e-852f-48bd-a22a-5c3acac982fd",
                     "14fdb8dc-310d-4615-b889-367b1ba4d6ff",
                     "74df1130-8f63-4034-877b-17bd1d5e17ea",
                     "280472da-444b-4676-b1cb-0f81cb693ce4",
                     "9549ce62-a3ea-4a6c-b194-665541392e20")
for(task_id in lst_request_ids){
  appeears::rs_transfer(task_id = task_id, 
                        user = "fabern",
                        path = here::here("data/lulc_competition_2025/lst"),
                        verbose = TRUE)
}

nbar_request_ids <- c("c458252e-b688-4cdb-ac0d-b037f8a1c9f8",
                      "efbdd659-1fce-44ec-adde-fa7796f07cb6",
                      "236ac3a7-04ba-486b-951e-b068047c1517",
                      "f4d4ebd9-4649-4e5b-a514-6f5cee6ae314",
                      "32f67c57-6a7a-400c-9081-4215a50b3721",
                      "8c3966bc-80f2-4554-8f71-ff6c0f8e0e60",
                      "7857b141-cb0b-46d8-814b-285d8ed6db94",
                      "93d97c2c-45b6-4e33-9512-d4fd5caa6bd0",
                      "f0f08cbc-eca6-4f7d-90d2-1bfde23f10f9",
                      "ae648070-ed5f-4ebe-8b30-ed9d3205a328"
                      )
for(task_id in nbar_request_ids){
  appeears::rs_transfer(task_id = task_id, 
                        user = "fabern",
                        path = here::here("data/lulc_competition_2025/nbar"),
                        verbose = TRUE)
}


