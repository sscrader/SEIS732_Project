# P0 - Project Feasibility

## 1. Working title
Trends in Biodiversity Across U.S. Urban Areas

## 2. Audience and need
This product would be valuable for conservationists and urban planners looking to restore natural pockets of biodiversity within urban areas. A problem this audience might face is not being able connected to large-scale and current biodiversity study data. This product could bridge a gap between large biodiversity datasets and the local planners who are deciding conservation strategies. It’s possible a tool like this could lead to better focused choices that promote greater biodiversity.

## 3. Proposed analytical product and questions
I imagine the best consumption artifact for this product would be an interactive map dashboard with key biodiversity metrics and filter options to view historic and species classification shifts. Some questions this product could answer would be:
- Has has the observed biodiversity of plants in Chicago increased over the last five years?
- What other urban areas should we collaborate with to help preserve regional and migratory bird diversity?
- Are there declining species populations that need to be addressed?

## 4. Source identification and access
### GBIF (Global Biodiversity Information Facility) Species Occurrences
[BigQuery public-dataset documentation URL]( https://console.cloud.google.com/marketplace/product/bigquery-public-data/gbif-occurrences?project=seis-732-508203)

Dataset Identifiers:
- BigQuery Dataset ID: bigquery-public-data.gbif
-	Candidate Table: bigquery-public-data.gbif.occurrences
  -	Location: US

Attribution Note:
- Data are made available under the Creative Commons Attribution-NonCommercial 4.0 International, Creative Commons Attribution 4.0 International, or CreativeCommons CC0 1.0 Universal licenses. Filter via the license column.
-	We require users to cite their use of the GBIF derived dataset; see the citation guidelines .
-	For more details, refer to the GBIF Terms of Use .

### Census Bureau US Boundaries
[BigQuery public-dataset documentation URL]( https://console.cloud.google.com/marketplace/product/united-states-census-bureau/us-geographic-boundaries?project=seis-732-508203)
Dataset Identifiers:
- BigQuery Dataset ID: bigquery-public-data.geo_us_boundaries
-	Candidate Table: bigquery-public-data.geo_us_boundaries.urban_areas
  -	Location: US

Attribution Note:
- There are no restrictions on the use of Census Bureau data. The Census Bureau does request that any work using these datasets cite the Census Bureau as the data source.

## 5. Quick source profile
### GBIF Species Occurrences - bigquery-public-data.gbif
-	Meaning of one row
  - One row is one species identification observation - evidence of the occurrence of a species (or other taxon) at a particular place on a specified date.
-	Current row count
  -	3,729,438,201
-	Relevant date or time coverage
  -	Column ‘eventdate’ ranges from 1500-01-01 00:00:00 UTC to 2026-08-28 00:08:00 UTC
-	Possible IDs or keys, what each identifies, and whether values are missing or duplicated
  -	The likely primary key would be the ‘gbifid’ column, which has no null rows and 3,729,438,201 distinct values, matching the row count.
-	Fields likely to support the proposed questions
  -	Taxonomic columns: kingdom, phylum, class, order, family, genus, species, taxonrank, verbatimscientificname, specieskey
  -	Location columns: stateprovince, decimallatitude, decimallongitude
  -	Date Column: eventdate
-	Important null, duplicate, type, or semi-structured characteristics
  -	There five array columns that might exhibit nested behaviors: identifiedby, recordedby, typestatus, mediatype, issue.
-	Known refresh behavior, if available
  -	BigQuery is updated with periodic snapshots. Last update was Oct 1, 2026, 7:01:42 PM UTC-5
-	Any obvious sensitivity, aggregation, or interpretation concern
  -	This table is a combination of many different datasets, from historic museum observations to citizen science apps, so the thoroughness, completion, and accuracy may vary widely within the dataset. Inconsistencies may come up with aggregations that include different origin datasets.

  ### Census Bureau US Boundaries - bigquery-public-data.geo_us_boundaries.urban_areas 
-	Meaning of one row
  -	One row represents one polygon around an urban area in the US
-	Current row count
  -	3,601
-	Relevant date or time coverage
  -	No date/time column
-	Possible IDs or keys, what each identifies, and whether values are missing or duplicated
  -	The likely primary key would be the ‘geo_id’ column, which has no null rows and 3,601 distinct values, matching the row count.
-	Fields likely to support the proposed questions
  -	name, internal_point_geom, urban_area_geom
-	Important null, duplicate, type, or semi-structured characteristics
  -	There doesn’t appear to be obvious null, dupe, type, or structure oddities.
-	Known refresh behavior, if available
  -	Table was last modified Nov 20, 2019, 12:03:21 PM UTC-6
-	Any obvious sensitivity, aggregation, or interpretation concern
  -	I will need to explore the geo capabilities of BigQuery to see if these geo columns can be used with the other dataset’s coordinate points.

## 6. Need-to-source fit
|                                             Proposed question                                             |                                                                                                                                                   Needed fields or concepts                                                                                                                                                  |                                 Candidate source object(s)                                |                                                                                                                                                                                Why the source appears sufficient                                                                                                                                                                                |                                                                                                                                                                                                                                                         Gap or assumption to test in P1                                                                                                                                                                                                                                                         |
|:---------------------------------------------------------------------------------------------------------:|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|:-----------------------------------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|
| Has the observed biodiversity of plants in Chicago increased over the last five years?                    | Observation date (eventdate); plant taxonomic classification (kingdom, phylum, class, order, family, genus, species, specieskey); geographic coordinates (decimallatitude, decimallongitude); unique observation identifier (gbifid). Need annual counts of distinct plant species.                                          | bigquery-public-data.gbif.occurrences; bigquery-public-data.geo_us_boundaries.urban_areas | The GBIF table provides dates, taxonomic classifications, coordinates, and a unique identifier for each occurrence record. The Census urban-area table provides Chicago's urban-area name and polygon geometry, allowing observations to be spatially filtered to the study area. These fields appear sufficient to estimate and compare the number of distinct observed plant species by year. | Confirm how plants can be consistently identified using the taxonomic fields; verify the geometry and coordinate reference system support a spatial join; and determine how duplicate observations, changing reporting effort, and differences in data coverage affect trends. An increase in recorded species does not necessarily mean actual biodiversity increased.                                                                                                              |
| What other urban areas should we collaborate with to help preserve regional and migratory bird diversity? | Bird taxonomic classification (class, order, family, genus, species, specieskey); occurrence dates (eventdate); geographic coordinates; unique observation identifier; urban-area names and boundaries. Seasonal occurrence patterns and a way to compare observed bird species richness across urban areas are also needed. | bigquery-public-data.gbif.occurrences; bigquery-public-data.geo_us_boundaries.urban_areas | GBIF occurrence records can be assigned to urban-area polygons and filtered to birds using their taxonomic classification. This would allow comparison of recorded bird species richness between U.S. urban areas and investigation of when different species are observed. The urban-area table provides geographic context for identifying potential regional collaborators.                  |  Define what constitutes a regional collaborator and how seasonal patterns will be measured. The documented fields do not establish migratory status, migration routes, or conservation priority; additional information or a validated proxy would be needed before making specific migration-related recommendations.                                                                                                    |
| Are there declining species populations that need to be addressed?                                        | Species identifiers and names (specieskey, species, genus); occurrence dates (eventdate); geographic coordinates; unique observation identifier; repeated observations over time.                        | bigquery-public-data.gbif.occurrences; bigquery-public-data.geo_us_boundaries.urban_areas | GBIF's dated occurrence records can support screening for species with decreasing numbers of recorded observations over time, potentially within specific urban areas. The urban-area polygons can provide a consistent geographic scope for this analysis.                          | Test whether records for the same species and areas cover enough years for comparison. Changes in reporting effort, observer participation, geographic coverage, and data sources could create apparent declines. Occurrence records alone cannot establish that a species' population is declining; independent population estimates or standardized monitoring data would be needed to support that conclusion. |

## 7. Feasibility risks and response
Risk 1: Geographic can be tricky to link up between different data sets due to any number of differences in coordinate systems and data types. I want to make sure that I will be able to have the biological observation locations in decimal degrees talk to the city shapes which are provided as multipolygon geometry types. After a quick review of the GoogleCloud resources on geospatial data, there is an SQL conversion for degrees to geographic points, so exploring this will be one of the first checks I make.

Risk 2: The biodiversity data set is very large and, while I plan on limiting the observation date range to the last decade or so, I’m expecting there to still be a lot of variation in the quality and frequency of data, especially considering the explosion of citizen science observation apps (iNaturalist, eBird) in the last couple of years. I would like to take a closer look at the general counts of observations in the last 10 years in the U.S. by taxonomic phyla to get an idea of the distribution of these observation categories.

Realistic Fallback: If there are major issues connecting biodiversity data to urban areas, I would scale this project back to focus on just the provided biodiversity data. I’d explore the question of how biodiversity is changing over time by country – which is a geographic category already provided in the biodiversity set.

## 8. First P1 decision
My first issue I’d like to resolve is determining if the geographic link between the two data tables is dependable enough to incorporate both sets into the model, or if this product should be driven solely by the biodiversity dataset.

## 9. AI/tool accountability
I began my search for a prompt to find public google BigQuery datasets related to industrial water usage usage. By the results of this first enquiry, I found that BigQuery doesn't have environmental related to that niche of environmental data. The results did point me to Google Cloud marketplace interface which is where I performed the rest of my data search, through manually filtering datasets by price (free) and sector until I found a few that sparked project ideas. Through this marketplace interface, I reviewed the dataset description, query examples, and outside sources pages to determine initial project fesability and source credibility.
