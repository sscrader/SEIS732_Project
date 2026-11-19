-- P2: CURATED LAYER
-- Google Cloud Project: seis-732-urban-biodiversity
-- Source:
--   urban_biodiversity_project.GBIF_RAW
--   urban_biodiversity_project.URBAN_RAW
-- Output:
--   urban_biodiversity_project.DIM_URBAN_AREA
--   urban_biodiversity_project.DIM_DATE
--   urban_biodiversity_project.FACT_GBIF_OCCURRENCE

-- ------------------------------------------------------------
-- 1. DIM_URBAN_AREA
-- ------------------------------------------------------------
-- Grain: One row per urban area per Census boundary vintage.
-- Primary key: version_key

CREATE OR REPLACE TABLE `seis-732-urban-biodiversity.urban_biodiversity_project.DIM_URBAN_AREA`
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
      CAST(area_land_meters AS FLOAT64) AS area_land_meters,
      CAST(area_water_meters AS FLOAT64) AS area_water_meters,
      internal_point_geom,
      urban_area_geom
    FROM
      `seis-732-urban-biodiversity.urban_biodiversity_project.URBAN_RAW`
    WHERE
      geo_id IS NOT NULL
      AND SAFE_CAST(census_year AS INT64) IS NOT NULL
  ),
  vintage_dates AS (
    SELECT DISTINCT
      census_year_int,
      LEAD(census_year_int)
        OVER (
          ORDER BY census_year_int
        ) AS next_census_year
    FROM
      source_versions
  )
SELECT
  U.geo_id,
  CONCAT(
    U.geo_id,
    '_',
    U.census_year) AS version_key,
  U.census_year,
  DATE(U.census_year_int, 1, 1) AS start_date,
  CASE
    WHEN V.next_census_year IS NULL THEN NULL
    ELSE
      DATE_SUB(
        DATE(V.next_census_year, 1, 1),
        INTERVAL 1 DAY)
    END AS end_date,
  U.urban_area_code,
  U.name,
  U.type,
  U.area_land_meters,
  U.area_water_meters,
  U.internal_point_geom,
  U.urban_area_geom
FROM
  source_versions U
JOIN
  vintage_dates V
  ON U.census_year_int = V.census_year_int
WHERE
  U.urban_area_geom IS NOT NULL
QUALIFY
  ROW_NUMBER()
    OVER (
      PARTITION BY U.geo_id, U.census_year
      ORDER BY U.geo_id
    )
  = 1;

-- ------------------------------------------------------------
-- 2. DIM_DATE
-- ------------------------------------------------------------
-- Grain: One row per calendar date.
-- Primary key: date_key

CREATE OR REPLACE TABLE `seis-732-urban-biodiversity.urban_biodiversity_project.DIM_DATE`
AS
WITH
  date_range AS (
    SELECT
      MIN(DATE(eventdate)) AS min_date,
      MAX(DATE(eventdate)) AS max_date
    FROM
      `seis-732-urban-biodiversity.urban_biodiversity_project.GBIF_RAW`
    WHERE
      eventdate IS NOT NULL
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
  date_range,
  UNNEST(
    GENERATE_DATE_ARRAY(min_date, max_date)) AS calendar_date;

-- ------------------------------------------------------------
-- 3. FACT_GBIF_OCCURRENCE
-- ------------------------------------------------------------
-- Grain: One GBIF occurrence assigned to one urban-area
-- boundary version.
-- Primary key: gbifid
-- Foreign keys:
--   version_key -> DIM_URBAN_AREA.version_key
--   DATE(eventdate) -> DIM_DATE.date_key

CREATE OR REPLACE TABLE `seis-732-urban-biodiversity.urban_biodiversity_project.FACT_GBIF_OCCURRENCE`
AS
WITH
  valid_occurrences AS (
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
      ST_GEOGPOINT(
        decimallongitude,
        decimallatitude) AS occurrence_geom
    FROM
      `seis-732-urban-biodiversity.urban_biodiversity_project.GBIF_RAW`
    WHERE
      gbifid IS NOT NULL
      AND eventdate IS NOT NULL
      AND decimallatitude BETWEEN -90 AND 90
      AND decimallongitude BETWEEN -180 AND 180
  ),
  spatial_matches AS (
    SELECT
      G.*,
      U.version_key,

      -- Calculate polygon area for deterministic
      -- handling of multiple spatial matches.
      ST_AREA(U.urban_area_geom) AS polygon_area
    FROM
      valid_occurrences G
    JOIN
      `seis-732-urban-biodiversity.urban_biodiversity_project.DIM_URBAN_AREA` U
      ON
        DATE(G.eventdate) >= U.start_date
        AND (
          U.end_date IS NULL
          OR DATE(G.eventdate) <= U.end_date)
        AND ST_COVERS(
          U.urban_area_geom,
          G.occurrence_geom)
  )
SELECT
  gbifid,
  version_key,
  datasetkey,
  occurrenceid,
  taxonkey,
  specieskey,
  kingdom,
  phylum,
  `class`,
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
  lastinterpreted
FROM
  spatial_matches
QUALIFY
  ROW_NUMBER()
    OVER (
      PARTITION BY gbifid
      ORDER BY
        polygon_area ASC,
        version_key ASC
    )
  = 1;