-- P2 RAW LAYER INGESTION
-- Project: seis-732-urban-biodiversity
-- GBIF scope: U.S. occurrences with eventdate >= 2026-06-01.
-- "Created on" is interpreted as eventdate (observation date), consistent
-- with the existing P2 files; it is not lastinterpreted.
-- Re-runnable: GBIF inserts new gbifid values only; Census inserts each
-- geo_id + census_year once. Existing GBIF IDs are not refreshed.

DECLARE p_gbif_start_date DATE DEFAULT DATE '2026-06-01';

CREATE SCHEMA IF NOT EXISTS
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW`
OPTIONS (location = 'US');

CREATE SCHEMA IF NOT EXISTS
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED`
OPTIONS (location = 'US');

-- 1. GBIF_RAW: all source columns; one row per gbifid.
-- Create an empty target with the source schema on first run.
CREATE TABLE IF NOT EXISTS
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.GBIF_RAW`
PARTITION BY DATE(eventdate)
CLUSTER BY gbifid
OPTIONS (
  description = 'U.S. GBIF occurrence records with eventdate on or after 2026-06-01; one row per gbifid.'
)
AS
SELECT *
FROM `bigquery-public-data.gbif.occurrences`
WHERE FALSE;

-- Deduplicate each source extract to its latest interpretation, then
-- insert only GBIF IDs not already captured in GBIF_RAW.
MERGE
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.GBIF_RAW` T
USING (
  SELECT *
  FROM `bigquery-public-data.gbif.occurrences`
  WHERE countrycode = 'US'
    AND eventdate >= TIMESTAMP(p_gbif_start_date)
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY gbifid
    ORDER BY lastinterpreted DESC
  ) = 1
) S
ON T.gbifid = S.gbifid
WHEN NOT MATCHED THEN INSERT ROW;

-- 2. URBAN_RAW: one row per geo_id + census_year.
-- Staging table is replaceable; URBAN_RAW is persistent history.
CREATE OR REPLACE TABLE
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.URBAN_VINTAGE_STG`
AS
SELECT *
FROM `bigquery-public-data.geo_us_boundaries.urban_areas`;

CREATE TABLE IF NOT EXISTS
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.URBAN_RAW`
AS
SELECT
  S.*,
  CAST(NULL AS INT64) AS census_year,
  CAST(NULL AS TIMESTAMP) AS source_snapshot_at,
  CAST(NULL AS STRING) AS source_file
FROM
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.URBAN_VINTAGE_STG` S
WHERE FALSE;

-- Set to the actual Census geography vintage represented by the staged data.
DECLARE p_census_year INT64 DEFAULT 2020;

INSERT INTO
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.URBAN_RAW`
SELECT
  S.*,
  p_census_year,
  CURRENT_TIMESTAMP(),
  'bigquery-public-data.geo_us_boundaries.urban_areas'
FROM
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.URBAN_VINTAGE_STG` S
WHERE NOT EXISTS (
  SELECT 1
  FROM `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.URBAN_RAW` T
  WHERE T.geo_id = S.geo_id
    AND T.census_year = p_census_year
);

-- 3. Raw validation
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT gbifid) AS distinct_gbifid,
  COUNTIF(gbifid IS NULL) AS null_gbifid,
  COUNTIF(countrycode != 'US') AS non_us_records,
  MIN(eventdate) AS earliest_eventdate,
  MAX(eventdate) AS latest_eventdate
FROM `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.GBIF_RAW`;

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT CONCAT(CAST(geo_id AS STRING), '_', CAST(census_year AS STRING)))
    AS distinct_urban_area_versions,
  COUNTIF(geo_id IS NULL) AS null_geo_id,
  COUNTIF(urban_area_geom IS NULL) AS null_urban_area_geom
FROM `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.URBAN_RAW`;
