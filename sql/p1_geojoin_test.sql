-- P2 pilot: GBIF-to-Census urban area spatial join
-- Selects GBIF data from July 2026 for testing.

DECLARE start_date DATE DEFAULT DATE '2026-07-01';
DECLARE end_date DATE DEFAULT DATE '2026-08-01';

WITH eligible AS (
  SELECT
    gbifid,
    eventdate,
    countrycode,
    decimallatitude,
    decimallongitude
  FROM `bigquery-public-data.gbif.occurrences`
  WHERE countrycode = 'US'
    AND eventdate >= TIMESTAMP(start_date)
    AND eventdate < TIMESTAMP(end_date)
),

coordinate_check AS (
  SELECT
    *,
    (
      decimallatitude BETWEEN -90 AND 90
      AND decimallongitude BETWEEN -180 AND 180
    ) AS valid_coordinates
  FROM eligible
),

valid_occurrences AS (
  SELECT
    gbifid,
    eventdate,
    ST_GEOGPOINT(
      decimallongitude,
      decimallatitude
    ) AS occurrence_point
  FROM coordinate_check
  WHERE valid_coordinates = TRUE
    AND gbifid IS NOT NULL
),

urban_areas AS (
  SELECT
    geo_id,
    name,
    urban_area_geom
  FROM `bigquery-public-data.geo_us_boundaries.urban_areas`
  WHERE urban_area_geom IS NOT NULL
),

-- Inner spatial join identifies all matching urban-area polygons.
spatial_matches AS (
  SELECT
    o.gbifid,
    u.geo_id,
    u.name
  FROM valid_occurrences AS o
  INNER JOIN urban_areas AS u
    ON ST_COVERS(u.urban_area_geom, o.occurrence_point)
),

-- Count how many urban areas each occurrence matches.
matches_per_occurrence AS (
  SELECT
    gbifid,
    COUNT(DISTINCT geo_id) AS urban_area_match_count
  FROM spatial_matches
  GROUP BY gbifid
),

-- Calculate the summary measures.
summary AS (
  SELECT
    COUNT(*) AS eligible_source_rows,
    COUNT(DISTINCT gbifid) AS eligible_distinct_gbifids,
    COUNTIF(gbifid IS NULL) AS missing_gbifid_rows,
    COUNTIF(
      decimallatitude IS NULL
      OR decimallongitude IS NULL
    ) AS missing_coordinate_rows,
    COUNTIF(
      decimallatitude IS NOT NULL
      AND decimallongitude IS NOT NULL
      AND NOT valid_coordinates
    ) AS out_of_range_coordinate_rows,
    COUNTIF(valid_coordinates) AS valid_coordinate_rows
  FROM coordinate_check
),

match_summary AS (
  SELECT
    COUNTIF(m.urban_area_match_count >= 1)
      AS matched_occurrence_ids,

    COUNTIF(m.urban_area_match_count IS NULL)
      AS unmatched_occurrence_ids,

    COUNTIF(m.urban_area_match_count > 1)
      AS multiple_area_match_ids

  FROM valid_occurrences AS o
  LEFT JOIN matches_per_occurrence AS m
    USING (gbifid)
)

SELECT
  start_date AS period_start,
  end_date AS period_end_exclusive,
  s.*,
  ms.*,
  SAFE_DIVIDE(
    ms.matched_occurrence_ids,
    s.eligible_distinct_gbifids
  ) AS matched_share_of_eligible_records,
  SAFE_DIVIDE(
    ms.unmatched_occurrence_ids,
    s.eligible_distinct_gbifids
  ) AS unmatched_share_of_eligible_records
FROM summary AS s
CROSS JOIN match_summary AS ms;
