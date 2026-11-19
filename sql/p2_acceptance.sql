-- P2: Acceptance Checks
-- Google Cloud Project: seis-732-urban-biodiversity
-- Source:
--   urban_biodiversity_project.DIM_URBAN_AREA
--   urban_biodiversity_project.DIM_DATE
--   urban_biodiversity_project.FACT_GBIF_OCCURRENCE

-- ------------------------------------------------------------
-- 1. ACCEPTANCE CHECK 1
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- 2. ACCEPTANCE CHECK 2
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 3. EXTRA CHECKS
-- ------------------------------------------------------------
-- DIM_URBAN_AREA primary key check
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT version_key) AS unique_version_keys,
  COUNTIF(version_key IS NULL) AS null_version_keys
FROM
  `seis-732-urban-biodiversity.urban_biodiversity_project.DIM_URBAN_AREA`;

-- DIM_DATE primary key check
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT date_key) AS unique_date_keys,
  COUNTIF(date_key IS NULL) AS null_date_keys
FROM
  `seis-732-urban-biodiversity.urban_biodiversity_project.DIM_DATE`;

-- verify fact grain
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT gbifid) AS unique_gbifids,
  COUNTIF(gbifid IS NULL) AS null_gbifids,
  COUNTIF(version_key IS NULL) AS null_version_keys,
  COUNTIF(eventdate IS NULL) AS null_eventdates
FROM
  `seis-732-urban-biodiversity.urban_biodiversity_project.FACT_GBIF_OCCURRENCE`;

-- verify foreign key relationships
SELECT
  COUNT(*) AS unmatched_urban_area_keys
FROM
  `seis-732-urban-biodiversity.urban_biodiversity_project.FACT_GBIF_OCCURRENCE` F
LEFT JOIN
  `seis-732-urban-biodiversity.urban_biodiversity_project.DIM_URBAN_AREA` U
  ON
    F.version_key = U.version_key
WHERE
  U.version_key IS NULL;

SELECT
  COUNT(*) AS unmatched_date_keys
FROM
  `seis-732-urban-biodiversity.urban_biodiversity_project.FACT_GBIF_OCCURRENCE` F
LEFT JOIN
  `seis-732-urban-biodiversity.urban_biodiversity_project.DIM_DATE` D
  ON
    DATE(F.eventdate) = D.date_key
WHERE
  D.date_key IS NULL;

-- check spatial joins
SELECT
  COUNT(*) AS raw_gbif_rows,
  COUNTIF(
    decimallatitude IS NULL
    OR decimallongitude IS NULL) AS missing_coordinates,
  COUNTIF(
    decimallatitude NOT BETWEEN -90 AND 90
    OR decimallongitude NOT BETWEEN -180 AND 180) AS invalid_coordinates,
  COUNTIF(
    specieskey IS NULL) AS missing_species_key,
  COUNTIF(
    eventdate IS NULL) AS missing_eventdate
FROM
  `seis-732-urban-biodiversity.urban_biodiversity_project.GBIF_RAW`;

SELECT
  G.gbifid,
  COUNT(*) AS spatial_matches
FROM
  `seis-732-urban-biodiversity.urban_biodiversity_project.GBIF_RAW` G
JOIN
  `seis-732-urban-biodiversity.urban_biodiversity_project.DIM_URBAN_AREA` U
  ON
    DATE(G.eventdate) >= U.start_date
    AND (
      U.end_date IS NULL
      OR DATE(G.eventdate) <= U.end_date)
    AND ST_COVERS(
      U.urban_area_geom,
      ST_GEOGPOINT(
        G.decimallongitude,
        G.decimallatitude))
GROUP BY
  G.gbifid
HAVING
  COUNT(*) > 1;

-- compare raw and curated counts
SELECT
  (SELECT COUNT(*) FROM `seis-732-urban-biodiversity.urban_biodiversity_project.GBIF_RAW`)
    AS raw_rows,
  (
    SELECT COUNT(*)
    FROM `seis-732-urban-biodiversity.urban_biodiversity_project.FACT_GBIF_OCCURRENCE`
  ) AS curated_rows,
  (
    SELECT COUNT(DISTINCT gbifid)
    FROM `seis-732-urban-biodiversity.urban_biodiversity_project.GBIF_RAW`
  ) AS raw_unique_gbifids,
  (
    SELECT COUNT(DISTINCT gbifid)
    FROM `seis-732-urban-biodiversity.urban_biodiversity_project.FACT_GBIF_OCCURRENCE`
  ) AS curated_unique_gbifids;