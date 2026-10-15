--- GBIF Species Occurrences - bigquery-public-data.gbif ---
-- Record the authorized objects and inspect their definitions.
SELECT column_name, data_type, is_nullable
FROM `bigquery-public-data.gbif.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'occurrences'
ORDER BY ordinal_position;

-- Establish basic scale without exporting row-level data.
SELECT COUNT(*) AS row_count
FROM `bigquery-public-data.gbif.occurrences`;

-- Test the time coverage and candidate identifier relevant to the idea.
SELECT
    MIN(eventdate) AS earliest_date,
    MAX(eventdate) AS latest_date,
    COUNTIF(gbifid IS NULL) AS null_candidate_ids,
    COUNT(DISTINCT gbifid) AS distinct_candidate_ids
FROM `bigquery-public-data.gbif.occurrences`;

--- Census Bureau US Boundaries - bigquery-public-data.geo_us_boundaries ---
-- Record the authorized objects and inspect their definitions.
SELECT column_name, data_type, is_nullable
FROM `bigquery-public-data.gbif.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'occurrences'
ORDER BY ordinal_position;

-- Establish basic scale without exporting row-level data.
SELECT COUNT(*) AS row_count
FROM `bigquery-public-data.gbif.occurrences`;

-- Test the time coverage and candidate identifier relevant to the idea.
SELECT
    MIN(eventdate) AS earliest_date,
    MAX(eventdate) AS latest_date,
    COUNTIF(gbifid IS NULL) AS null_candidate_ids,
    COUNT(DISTINCT gbifid) AS distinct_candidate_ids
FROM `bigquery-public-data.gbif.occurrences`;