-- P2 CURATED LAYER
-- Inputs: BIODIVERSITY_PROJECT_RAW.GBIF_RAW and URBAN_RAW
-- Outputs: BIODIVERSITY_PROJECT_CURATED.DIM_URBAN_AREA,
--          DIM_DATE, FACT_GBIF_OCCURRENCE
-- GBIF scope: eventdate >= 2026-06-01.
-- Re-runnable: curated tables use CREATE OR REPLACE; temp tables use
-- CREATE OR REPLACE TEMP TABLE (safe in BigQuery session mode).

DECLARE p_gbif_start_date DATE DEFAULT DATE '2026-06-01';

-- 1. DIM_URBAN_AREA
-- Grain: one row per geo_id per Census boundary vintage.
-- PK: version_key. Effective dates use the project convention:
-- January 1 of a vintage through the day before the next vintage.
CREATE OR REPLACE TABLE `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.DIM_URBAN_AREA`
AS
WITH
  source_versions AS (
    SELECT
      CAST(geo_id AS STRING) AS geo_id,
      CAST(census_year AS STRING) AS census_year,
      SAFE_CAST(census_year AS INT64) AS census_year_int,
      CAST(urban_area_code AS STRING) AS urban_area_code,
      CAST(name AS STRING) AS name,
      CAST(type AS STRING) AS type,
      SAFE_CAST(area_land_meters AS FLOAT64) AS area_land_meters,
      SAFE_CAST(area_water_meters AS FLOAT64) AS area_water_meters,
      internal_point_geom,
      urban_area_geom
    FROM `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.URBAN_RAW`
    WHERE
      geo_id IS NOT NULL
      AND SAFE_CAST(census_year AS INT64) IS NOT NULL
      AND urban_area_geom IS NOT NULL
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY geo_id, census_year
          ORDER BY source_snapshot_at DESC
        )
      = 1
  ),
  vintages AS (
    SELECT DISTINCT
      census_year_int,
      LEAD(census_year_int) OVER (ORDER BY census_year_int) AS next_census_year
    FROM source_versions
  )
SELECT
  S.geo_id,
  CONCAT(S.geo_id, '_', S.census_year) AS version_key,
  S.census_year,
  DATE(S.census_year_int, 1, 1) AS start_date,
  CASE
    WHEN V.next_census_year IS NULL THEN NULL
    ELSE DATE_SUB(DATE(V.next_census_year, 1, 1), INTERVAL 1 DAY)
    END AS end_date,
  S.urban_area_code,
  S.name,
  S.type,
  S.area_land_meters,
  S.area_water_meters,
  S.internal_point_geom,
  S.urban_area_geom
FROM source_versions S
JOIN vintages V
  USING (census_year_int);

-- 2. DIM_DATE
-- Grain: one row per calendar date represented in the test window.
-- PK: date_key.
CREATE OR REPLACE TABLE `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.DIM_DATE`
AS
WITH
  date_limits AS (
    SELECT
      MIN(DATE(eventdate)) AS min_date,
      MAX(DATE(eventdate)) AS max_date
    FROM `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.GBIF_RAW`
    WHERE eventdate >= TIMESTAMP(p_gbif_start_date)
  )
SELECT
  calendar_date AS date_key,
  EXTRACT(YEAR FROM calendar_date) AS year,
  EXTRACT(QUARTER FROM calendar_date) AS quarter,
  EXTRACT(MONTH FROM calendar_date) AS month,
  FORMAT_DATE('%B', calendar_date) AS month_name,
  EXTRACT(DAY FROM calendar_date) AS day,
  EXTRACT(DAYOFWEEK FROM calendar_date) AS day_of_week
FROM
  date_limits,
  UNNEST(
    IF(
      min_date IS NULL,
      ARRAY<DATE>[],
      GENERATE_DATE_ARRAY(min_date, max_date))) AS calendar_date;

-- 3. FACT_GBIF_OCCURRENCE
-- Grain: one row per GBIF ID in the test window.
-- version_key is NULL when no applicable urban-area polygon matches.
CREATE OR REPLACE TEMP TABLE gbif_base
AS
SELECT
  gbifid,
  datasetkey,
  occurrenceid,
  taxonkey,
  specieskey,
  kingdom,
  phylum,
  class,
  `order`,
  family,
  genus,
  species,
  taxonrank,
  scientificname,
  countrycode,
  stateprovince,
  decimallatitude,
  decimallongitude,
  coordinateuncertaintyinmeters,
  eventdate,
  basisofrecord,
  occurrencestatus,
  individualcount,
  publishingorgkey,
  institutioncode,
  collectioncode,
  catalognumber,
  license,
  lastinterpreted,
  CASE
    WHEN
      decimallatitude BETWEEN -90 AND 90
      AND decimallongitude BETWEEN -180 AND 180
      THEN ST_GEOGPOINT(decimallongitude, decimallatitude)
    ELSE NULL
    END AS occurrence_geom
FROM `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.GBIF_RAW`
WHERE eventdate >= TIMESTAMP(p_gbif_start_date);

-- Spatial match only valid points. CROSS JOIN + spatial predicate
-- permits BigQuery's optimized spatial join execution.
CREATE OR REPLACE TEMP TABLE urban_matches
AS
SELECT
  G.gbifid,
  U.version_key,
  ST_AREA(U.urban_area_geom) AS polygon_area
FROM gbif_base G
CROSS JOIN
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.DIM_URBAN_AREA` U
WHERE
  G.occurrence_geom IS NOT NULL
  AND DATE(G.eventdate) >= U.start_date
  AND (U.end_date IS NULL OR DATE(G.eventdate) <= U.end_date)
  AND ST_COVEREDBY(G.occurrence_geom, U.urban_area_geom)
QUALIFY
  ROW_NUMBER()
    OVER (
      PARTITION BY G.gbifid
      ORDER BY polygon_area, U.version_key
    )
  = 1;

-- LEFT JOIN retains all GBIF rows; unmatched version_key is NULL.
-- Partitioning/clustering are established on first creation and retained
-- on subsequent CREATE OR REPLACE runs.
CREATE OR REPLACE TABLE `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.FACT_GBIF_OCCURRENCE`
  PARTITION BY DATE(eventdate)
  CLUSTER BY version_key, specieskey
AS
SELECT
  G.gbifid,
  M.version_key,
  G.datasetkey,
  G.occurrenceid,
  G.taxonkey,
  G.specieskey,
  G.kingdom,
  G.phylum,
  G.class,
  G.`order`,
  G.family,
  G.genus,
  G.species,
  G.taxonrank,
  G.scientificname,
  G.countrycode,
  G.stateprovince,
  G.decimallatitude,
  G.decimallongitude,
  G.coordinateuncertaintyinmeters,
  G.eventdate,
  G.basisofrecord,
  G.occurrencestatus,
  G.individualcount,
  G.publishingorgkey,
  G.institutioncode,
  G.collectioncode,
  G.catalognumber,
  G.license,
  G.lastinterpreted
FROM gbif_base G
LEFT JOIN urban_matches M
  USING (gbifid);
