-- P2 ACCEPTANCE CHECKS
-- Raw dataset: BIODIVERSITY_PROJECT_RAW
-- Curated dataset: BIODIVERSITY_PROJECT_CURATED

-- ------------------------------------------------------------
-- 1. ACCEPTANCE CHECK 1
-- ------------------------------------------------------------

WITH
  all_country_observations AS (

    -- Retrieve all GBIF observations in the test period.
    -- No country filter is applied.
    -- Retain the latest interpretation per GBIF ID.
    SELECT
      gbifid,
      countrycode,
      eventdate,
      decimallatitude,
      decimallongitude
    FROM
      `bigquery-public-data.gbif.occurrences`
    WHERE
      eventdate >= TIMESTAMP('2026-06-01 00:00:00+00')
      AND gbifid IS NOT NULL
      AND decimallatitude BETWEEN -90 AND 90
      AND decimallongitude BETWEEN -180 AND 180
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY gbifid
          ORDER BY lastinterpreted DESC
        )
      = 1
  ),
  all_country_spatial_matches AS (

    -- Spatially join all eligible observations to urban areas.
    -- Census vintage dates are respected.
    SELECT
      G.gbifid,
      G.countrycode,
      U.version_key
    FROM
      all_country_observations G
    CROSS JOIN
      `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.DIM_URBAN_AREA`
        U
    WHERE
      DATE(G.eventdate) >= U.start_date
      AND (
        U.end_date IS NULL
        OR DATE(G.eventdate) <= U.end_date)
      AND ST_COVEREDBY(
        ST_GEOGPOINT(
          G.decimallongitude,
          G.decimallatitude),
        U.urban_area_geom)
    QUALIFY
      ROW_NUMBER()
        OVER (
          PARTITION BY G.gbifid
          ORDER BY
            ST_AREA(U.urban_area_geom) ASC,
            U.version_key ASC
        )
      = 1
  ),
  comparison AS (
    SELECT

      -- Actual Curated count using US-filtered Raw ingestion
      (
        SELECT COUNT(DISTINCT gbifid)
        FROM
          `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.FACT_GBIF_OCCURRENCE`
        WHERE
          version_key IS NOT NULL
      ) AS curated_us_spatial_matches,

      -- All-country spatial matches
      COUNT(DISTINCT gbifid)
        AS all_country_spatial_matches,

      -- Matches from non-US country codes
      COUNT(
        DISTINCT
          IF(
            countrycode != 'US'
              OR countrycode IS NULL,
            gbifid,
            NULL)) AS non_us_spatial_matches,

      -- Matches from US country codes in the comparison query
      COUNT(
        DISTINCT
          IF(
            countrycode = 'US',
            gbifid,
            NULL)) AS all_query_us_spatial_matches
    FROM
      all_country_spatial_matches
  )
SELECT
  curated_us_spatial_matches,
  all_country_spatial_matches,
  all_query_us_spatial_matches,
  non_us_spatial_matches,
  all_country_spatial_matches
    - curated_us_spatial_matches
    AS difference_in_spatial_matches,
  ROUND(
    100 * SAFE_DIVIDE(non_us_spatial_matches, all_country_spatial_matches), 2)
    AS percent_matches_from_non_us_records
FROM
  comparison;

-- ------------------------------------------------------------
-- 2. ACCEPTANCE CHECK 2
-- ------------------------------------------------------------

SELECT
  DATE_TRUNC(DATE(eventdate), MONTH) AS observation_month,

  -- Observation volume
  COUNT(gbifid) AS occurrence_count,

  -- Species representation
  COUNT(DISTINCT specieskey) AS distinct_species,
  COUNTIF(specieskey IS NULL) AS missing_specieskey,

  -- Reporting activity
  COUNT(DISTINCT datasetkey) AS contributing_datasets,
  COUNT(DISTINCT publishingorgkey) AS contributing_publishers
FROM
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.FACT_GBIF_OCCURRENCE`
WHERE
  eventdate >= TIMESTAMP('2026-06-01 00:00:00+00')
  AND version_key IS NOT NULL
GROUP BY
  observation_month
ORDER BY
  observation_month;

-- ------------------------------------------------------------
-- 3. EXTRA CHECKS
-- ------------------------------------------------------------

-- BASIS OF RECORD COMPOSITION
SELECT
  basisofrecord,
  COUNT(*) AS occurrence_count,
  COUNT(DISTINCT gbifid) AS unique_occurrences,
  COUNT(DISTINCT specieskey) AS distinct_species,
  COUNTIF(specieskey IS NULL) AS missing_specieskey
FROM
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.FACT_GBIF_OCCURRENCE`
WHERE
  eventdate >= TIMESTAMP('2026-06-01 00:00:00+00')
GROUP BY
  basisofrecord
ORDER BY
  occurrence_count DESC;

-- SOURCE INSTITUTION COMPOSITION
SELECT
  institutioncode,
  COUNT(*) AS occurrence_count,
  COUNT(DISTINCT specieskey) AS distinct_species,
  COUNTIF(specieskey IS NULL) AS missing_specieskey,
  ROUND(
    100 * SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()), 2)
    AS percent_of_occurrences
FROM
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.FACT_GBIF_OCCURRENCE`
WHERE
  eventdate >= TIMESTAMP('2026-06-01 00:00:00+00')
GROUP BY
  institutioncode
ORDER BY
  occurrence_count DESC
LIMIT 20;

-- GBIF eventdate scope: on/after 2026-06-01.

DECLARE p_gbif_start_date DATE DEFAULT DATE '2026-06-01';

-- 1. GBIF Raw scope and grain
SELECT
  COUNT(*) AS raw_rows,
  COUNT(DISTINCT gbifid) AS distinct_gbifids,
  COUNTIF(gbifid IS NULL) AS null_gbifids,
  COUNTIF(countrycode != 'US') AS non_us_records,
  COUNTIF(eventdate < TIMESTAMP(p_gbif_start_date)) AS before_test_window,
  MIN(eventdate) AS earliest_eventdate,
  MAX(eventdate) AS latest_eventdate
FROM `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.GBIF_RAW`;

-- 2. Census Raw version grain
SELECT
  COUNT(*) AS raw_urban_rows,
  COUNT(
    DISTINCT CONCAT(CAST(geo_id AS STRING), '_', CAST(census_year AS STRING)))
    AS distinct_urban_area_versions,
  COUNTIF(geo_id IS NULL) AS null_geo_id,
  COUNTIF(urban_area_geom IS NULL) AS null_urban_area_geom
FROM `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.URBAN_RAW`;

-- 3. Dimension primary keys
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT version_key) AS unique_version_keys,
  COUNTIF(version_key IS NULL) AS null_version_keys
FROM `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.DIM_URBAN_AREA`;

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT date_key) AS unique_date_keys,
  COUNTIF(date_key IS NULL) AS null_date_keys
FROM `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.DIM_DATE`;

-- 4. Fact grain and retained unmatched observations
SELECT
  COUNT(*) AS total_fact_rows,
  COUNT(DISTINCT gbifid) AS unique_gbifids,
  COUNTIF(gbifid IS NULL) AS null_gbifids,
  COUNTIF(version_key IS NOT NULL) AS assigned_to_urban_area,
  COUNTIF(version_key IS NULL) AS not_assigned_to_urban_area,
  COUNTIF(decimallatitude IS NULL OR decimallongitude IS NULL)
    AS missing_coordinates,
  COUNTIF(
    decimallatitude IS NOT NULL
    AND decimallongitude IS NOT NULL
    AND (
      decimallatitude NOT BETWEEN -90 AND 90
      OR decimallongitude NOT BETWEEN -180 AND 180)) AS invalid_coordinates,
  COUNTIF(eventdate IS NULL) AS missing_eventdate,
  COUNTIF(specieskey IS NULL) AS missing_specieskey,
  MIN(eventdate) AS earliest_eventdate,
  MAX(eventdate) AS latest_eventdate
FROM
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.FACT_GBIF_OCCURRENCE`;

-- 5. Foreign key check: non-NULL version keys must resolve.
SELECT
  COUNTIF(U.version_key IS NULL) AS unmatched_nonnull_version_keys
FROM
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.FACT_GBIF_OCCURRENCE`
    F
LEFT JOIN
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.DIM_URBAN_AREA` U
  ON F.version_key = U.version_key
WHERE F.version_key IS NOT NULL;

-- Date relationship check.
SELECT
  COUNT(*) AS unmatched_date_keys
FROM
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.FACT_GBIF_OCCURRENCE`
    F
LEFT JOIN `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.DIM_DATE` D
  ON DATE(F.eventdate) = D.date_key
WHERE F.eventdate IS NOT NULL AND D.date_key IS NULL;

-- 6. Raw-to-Curated count reconciliation (same date scope).
SELECT
  (
    SELECT COUNT(*)
    FROM `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.GBIF_RAW`
    WHERE eventdate >= TIMESTAMP(p_gbif_start_date)
  ) AS raw_rows_in_test_window,
  (
    SELECT COUNT(*)
    FROM
      `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.FACT_GBIF_OCCURRENCE`
  ) AS curated_rows,
  (
    SELECT COUNT(DISTINCT gbifid)
    FROM `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.GBIF_RAW`
    WHERE eventdate >= TIMESTAMP(p_gbif_start_date)
  ) AS raw_unique_gbifids,
  (
    SELECT COUNT(DISTINCT gbifid)
    FROM
      `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.FACT_GBIF_OCCURRENCE`
  ) AS curated_unique_gbifids;

-- 7. Trace counts
SELECT
  'Raw' AS layer,
  COUNT(*) AS total_rows,
  COUNT(DISTINCT gbifid) AS distinct_gbifids
FROM
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.GBIF_RAW`
UNION ALL
SELECT
  'Curated' AS layer,
  COUNT(*) AS total_rows,
  COUNT(DISTINCT gbifid) AS distinct_gbifids
FROM
  `seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED.FACT_GBIF_OCCURRENCE`;
