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

