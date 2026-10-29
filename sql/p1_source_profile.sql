-- SEIS732 Project
-- P1: Grain, Model, History & Pipeline Plan

--- GBIF Species Occurrences - bigquery-public-data.gbif ---
-- test gbifid as candidate key
SELECT
    COUNTIF(gbifid IS NULL) AS null_candidate_ids,
    COUNT(DISTINCT gbifid) AS distinct_candidate_ids
FROM `bigquery-public-data.gbif.occurrences`;

-- test the columns that determine the grain

-- Test the combination of columns that may determine the grain

WITH grain_groups AS (
  SELECT
    taxonkey,
    decimallatitude,
    decimallongitude,
    eventdate,
    collectioncode,
    catalognumber,
    COUNT(*) AS rows_per_id
  FROM `bigquery-public-data.gbif.occurrences`
  GROUP BY
    taxonkey,
    decimallatitude,
    decimallongitude,
    eventdate,
    collectioncode,
    catalognumber
)

SELECT
  COALESCE(SUM(rows_per_id), 0) AS source_rows,

  COALESCE(
    SUM(
      IF(
        taxonkey IS NULL
        OR decimallatitude IS NULL
        OR decimallongitude IS NULL
        OR eventdate IS NULL
        OR collectioncode IS NULL
        OR catalognumber IS NULL,
        rows_per_id,
        0
      )
    ),
    0
  ) AS rows_with_null_key_component,

  COUNTIF(
    taxonkey IS NOT NULL
    AND decimallatitude IS NOT NULL
    AND decimallongitude IS NOT NULL
    AND eventdate IS NOT NULL
    AND collectioncode IS NOT NULL
    AND catalognumber IS NOT NULL
    AND rows_per_id > 1
  ) AS repeated_key_groups

FROM grain_groups;

--- Census Bureau US Boundaries - bigquery-public-data.geo_us_boundaries ---
-- test geo_id as candidate key
SELECT
    COUNTIF(geo_id IS NULL) AS null_candidate_ids,
    COUNT(DISTINCT geo_id) AS distinct_candidate_ids
FROM `bigquery-public-data.geo_us_boundaries.urban_areas`;

-- test the column (urban_area_code) that determines the grain
WITH grain_groups AS (
  SELECT urban_area_code, COUNT(*) AS rows_per_id
  FROM `bigquery-public-data.geo_us_boundaries.urban_areas`
  GROUP BY urban_area_code
)
SELECT
  COALESCE(SUM(rows_per_id), 0) AS source_rows,
  COALESCE(SUM(IF(urban_area_code IS NULL, rows_per_id, 0)), 0) AS rows_with_null_id,
  COUNTIF(urban_area_code IS NOT NULL AND rows_per_id > 1) AS repeated_id_groups
FROM grain_groups;