-- P2: RAW LAYER INGESTION
-- Google Cloud Project: seis-732-urban-biodiversity
-- Processing Location: US
-- Source 1: bigquery-public-data.gbif.occurrences
-- Source 2: bigquery-public-data.geo_us_boundaries.urban_areas

-- ------------------------------------------------------------
-- 1. GBIF_RAW
-- ------------------------------------------------------------
-- Source: bigquery-public-data.gbif.occurrences
-- Grain: One row per GBIF occurrence record (gbifid)
-- Retain all source columns.
-- Filter:
--   countrycode = 'US'
--   eventdate >= 2021-01-01

CREATE SCHEMA IF NOT EXISTS `seis-732-urban-biodiversity.urban_biodiversity_project`
  OPTIONS (location = 'US');

CREATE OR REPLACE TABLE `seis-732-urban-biodiversity.urban_biodiversity_project.GBIF_RAW`
  OPTIONS (
    description = 'Raw GBIF occurrence records for the United States, with event dates on or after 2021-01-01. All source columns retained.')
AS
SELECT
  *
FROM
  `bigquery-public-data.gbif.occurrences`
WHERE
  countrycode = 'US'
  AND eventdate >= TIMESTAMP('2021-01-01 00:00:00+00');

-- ------------------------------------------------------------
-- 2. URBAN_RAW
-- ------------------------------------------------------------
-- Source: bigquery-public-data.geo_us_boundaries.urban_areas
-- Grain: One row per Census urban area polygon.
-- Retain all source columns.
-- No filtering applied.
-- ------------------------------------------------------------

-- RUN ONCE
-- Initial Census source load into urban area vintage staging table
CREATE OR REPLACE TABLE `seis-732-urban-biodiversity.urban_biodiversity_project.URBAN_VINTAGE_STG`
  OPTIONS (
    description = 'Raw Census Bureau U.S. urban area boundary data. All source columns retained.')
AS
SELECT
  *
FROM
  `bigquery-public-data.geo_us_boundaries.urban_areas`;
-- Create the versioned Raw table if it does not exist.
-- Original source columns are preserved.
-- Additional fields identify the boundary vintage and ingestion.
CREATE TABLE IF NOT EXISTS `seis-732-urban-biodiversity.urban_biodiversity_project.URBAN_RAW`
AS
SELECT
  *,
  CAST(NULL AS INT64) AS census_year,
  CAST(NULL AS TIMESTAMP) AS source_snapshot_at,
  CAST(NULL AS STRING) AS source_file
FROM
  `seis-732-urban-biodiversity.urban_biodiversity_project.URBAN_VINTAGE_STG`
WHERE FALSE;

-- RERUN WITH NEW CENSUS AREAS AS NEEDED
-- Set these values to match the actual Census source.
DECLARE census_year INT64 DEFAULT 2020;

-- Append new urban-area versions.
-- Do not reload an existing geo_id + census_year combination
INSERT INTO `seis-732-urban-biodiversity.urban_biodiversity_project.URBAN_RAW`
SELECT
  S.*,
  census_year,
  CURRENT_TIMESTAMP() AS source_snapshot_at,
  'Census TIGER/Line Urban Areas' AS source_file 
FROM
  `seis-732-urban-biodiversity.urban_biodiversity_project.URBAN_VINTAGE_STG` S
WHERE
  NOT EXISTS(
    SELECT 1
    FROM
      `seis-732-urban-biodiversity.urban_biodiversity_project.URBAN_RAW` R
    WHERE
      R.geo_id = S.geo_id
      AND R.census_year = census_year
  );

-- ------------------------------------------------------------
-- 3. VALIDATION
-- ------------------------------------------------------------

-- GBIF_RAW: Row count, distinct identifiers, date coverage, and geographic filter verification.

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT gbifid) AS distinct_gbifid,
  COUNTIF(gbifid IS NULL) AS null_gbifid,
  COUNTIF(countrycode != 'US') AS non_us_records,
  MIN(eventdate) AS earliest_eventdate,
  MAX(eventdate) AS latest_eventdate
FROM
  `seis-732-urban-biodiversity.urban_biodiversity_project.GBIF_RAW`;

-- URBAN_RAW: Row count, distinct identifiers, and geometry availability.

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT geo_id) AS distinct_geo_id,
  COUNTIF(geo_id IS NULL) AS null_geo_id,
  COUNTIF(urban_area_geom IS NULL) AS null_urban_area_geom
FROM
  `seis-732-urban-biodiversity.urban_biodiversity_project.URBAN_RAW`;

  