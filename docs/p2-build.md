# P2 - Working Ingestion, Curation & Acceptance Checks

------------------------------------------------------------------------
## 1. Establish the input and run ingestion

### Audience, need, and analytical question

**Audience:** Conservationists and urban planners looking to restore
natural pockets of biodiversity within urban areas.

**Audience need:** Connect local jurisdictions to large-scale
biodiversity observation data to inform conservation planning.

**Primary analytical question:** What species observations have been
made within urban areas over time?

**Supporting question:** What are the 50 least observed species in
Chicago, IL?

**P2 path being built:** The pathway for data from source to raw and then curated layers, including establishment of the relationship between species observations and urban area data.

### Changes from the P1 plan

One major change from P1 is that I will be limiting the biodiversity observation data to just that from June 01, 2026 and on. In P1 I had proposed using the last five years, but with hundreds of millions of observations, that time period would make the building and testing of this pipeline expensive.


### Source objects and input subset

| Source | Full identifier / location | Source row meaning | Fields needed | Actual subset / selection criteria |
|---|---|---|---|---|
| GBIF Biodiversity Data | bigquery-public-data.gbif.occurrences | One row is one species identification observation - <br>evidence of the occurrence of a species (or other taxon) at a particular place on a specified date. | gbifid<br>datasetkey<br>occurrenceid<br>taxonkey<br>specieskey<br>kingdom<br>phylum<br>class<br>order<br>family<br>genus<br>species<br>taxonrank<br>scientificname<br>countrycode<br>stateprovince<br>decimallatitude<br>decimallongitude<br>coordinateuncertaintyinmeters<br>eventdate<br>basisofrecord<br>occurrencestatus<br>individualcount<br>publishingorgkey<br>institutioncode<br>collectioncode<br>catalognumber<br>license<br>lastinterpreted | Raw table should update with new data after each refresh as it's added to the source file<br><br>Geographic filter: countrycode = 'US'<br>Temporal filter: inclusive eventdate >= 2026-06-01  |
| Census Urban Areas | bigquery-public-data.geo_us_boundaries.urban_areas | One row represents one polygon around an urban area in the US | geo_id<br>urban_area_code<br>name<br>type<br>area_land_meters<br>area_water_meters<br>internal_point_geom<br>urban_area_geom | Table should contain the most recent census urban area data available through BigQuery -<br>last updated Nov 20, 2019, 12:03:21 PM UTC-6<br><br>Should be able to keep version history of urban areas for changes in future census'  |


### BigQuery build environment

| Item | Value |
|---|---|
| project ID | seis-732-urban-biodiversity |
| dataset ID | seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW |
| Biodiversity Raw dataset table name | GBIF_RAW |
| Urban Area Raw Dataset table name | URBAN_RAW |
| Processing location | US |

### Raw input design and ingestion procedure

**Ingestion approach**

Biodiversity Data
- Retain all source columns.
- Filter:
    - countrycode = 'US'
    - eventdate >= 2026-06-01
- history maintenance: keep only the last retrieved gbif_id

Urban Areas
- Retain all source columns.
- No filtering or other transformations applied.
- history maintenance: preserve census boundary history by the census year

**Ingestion SQL:** 

[p2_ingestion.sql](../sql/p2_ingest.sql)

### Observed Raw input results

Results from raw ingestion verification queries:

| Raw Object | Run Date | Row Count | Distinct Key Count | Null Key Count | Earliest eventdate | Latest eventdate |
|---|---|---|---|---|---|---|
| seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_RAW.GBIF_RAW | Nov 19, 2026, 12:07:00 AM UTC-6 | 4,478,374 | 4,478,374 | 0 | 2026-06-01 00:00:00 UTC | 2026-09-29 00:00:00 UTC |
| seis-732-urban-biodiversity.urban_biodiversity_project.URBAN_RAW | Nov 19, 2026, 12:09:08 AM UTC-6 | 3,601 | 3,601 | 0 | NA | NA |

**Raw interpretation:** In both raw tables, the row count (COUNT(*)) is equal to the count of distinct keys (COUNT(DISTINCT(key_column))) which indicates that the columns I believed would work as keys for both tables hold up as primary keys. 

This may change for the URBAN_RAW table when new vintages of the same geo_id are introduced, in which case I would need to develop a vintage key that's a composite between the geo_id and census_year.

The eventdate range for the GBIF_RAW table also indicates successful filtering for dates after 2026-06-01.

**Raw input limitations:** This raw ingestion is still limited in the metadata it collects for each snapshot, source version, or selection dates. In P3, I'd like to create a load history table to track time and success of refreshes, new loads, and counts of new rows ingested.

------------------------------------------------------------------------
## 2. Build Curated at the intended grain

### Curated objects and intended grain
| Curated object | Purpose | Grain | Keys | SQL reference |
|:---:|:---:|:---:|:---:|:---:|
| FACT_GBIF_OCCURRENCES | Eligible U.S. occurrences assigned to urban areas | One unique GBIF occurrence assigned to an applicable urban-area version | gbifid (PK)<br>version_key (FK) | [p2_curate.sql GBIF](../sql/p2_curate.sql#L98) |
| DIM_URBAN_AREA | Urban-area identifiers, names, geometry, and version attributes | One urban area per Census boundary vintage | version_key (PK) <br>compound of geo_id and census_year | [p2_curate.sql Urban Area](../sql/p2_curate.sql#L11) |
| DIM_DATE | Calendar attributes for occurrence dates | One calendar date | date_key (PK) | [p2_curate.sql Dates](../sql/p2_curate.sql#L69) |


### Transformations and business rules

**Transformations**
- Generate version_key from geo_id and census_year to create unique vintage identifiers.
- Convert the GBIF eventdate timestamp to a calendar date for the date-dimension relationship, while retaining the original timestamp in the fact table.
- Convert latitude and longitude into a BigQuery GEOGRAPHY point and spatially assign it to the appropriate urban-area polygon.

**Missing and invalid values:** 
- Include records without valid coordinates in the spatially assigned fact table.
- Retain the observation, even if specieskey is NULL. This preserves occurrence evidence without incorrectly discarding records.
- Include observations that cannot be assigned to an urban area from this particular fact table. 

**Repeated records:** 
- If records with the same gbifid appear in the biodiversity source dataset, we will retain the latest refreshed version of each record per gbifid, as established in your Raw ingestion design.

**Rules retained without transformation:** 
- The data types are generally maintained as they were assigned in the source tables.

### BigQuery build environment

| Item | Value |
|---|---|
| project ID | seis-732-urban-biodiversity |
| dataset ID | seis-732-urban-biodiversity.BIODIVERSITY_PROJECT_CURATED |
| Biodiversity Curated dataset table name | FACT_GBIF_OCCURRENCE |
| Urban Area Curated Dataset table name | DIM_URBAN_AREA |
| Date Curated Dataset table name | DIM_DATE |
| Processing location | US |

### Observed Curated results and count reconciliation

Biodiversity data:

[GBIF Raw to Curated Row and Key Counts](../sql/p2_acceptance.sql#L265) 
| raw_rows_in_test_window | curated_rows | raw_unique_gbifids | curated_unique_gbifids |
|---|---|---|---|
| 4478374 | 4478374 | 4478374 | 4478374 |

[GBIF Curated Grain and Retention](../sql/p2_acceptance.sql#L222) 
| total_fact_rows | unique_gbifids | assigned_to_urban_area | not_assigned_to_urban_area | missing_coordinates | missing_specieskey |
|---|---|---|---|---|---|
| 4478374 | 4478374 | 1782907 | 2695467 | 3065 | 74110 |

Urban Area data:

[Urban Area Curated Row and Key Counts](../sql/p2_acceptance.sql#L199) 
| total_rows | unique_version_keys | null_version_keys |
|---|---|---|
| 7202 | 3601 | 0 |

**Count reconciliation and interpretation:** The biodiversity data (FACT_GBIF_OCCURRENCE) does maintain the same row count, count of unique ID's and therefore grain from the Raw to the Curation stage. Preliminary queries show that there are some rows that are missing coordinates and species keys. I would consider removing these null fields from the data in the curation stage to prevent misinterpretation of the occurrence data. For example, an observation that has a null urban area version key because it's designated rural is very different (and more useful information) than an observation with a null urban area version key due to missing coordinates.

The urban area curated table has the same count of keys as the Raw table, but appears to have doubled the row count. I will need to re-evaluate the urban area curation SQL to resolve this duplication.

### Field / measure trace

**Explanation of the trace:** The field trace follows the GBIF gbifid identifier from the public GBIF occurrence source into BIODIVERSITY_PROJECT_RAW.GBIF_RAW, where it is retained without changing its meaning. During the ingestion step, observations are filtered to the U.S. and with event dates on or after June 1, 2026. The Curated FACT_GBIF_OCCURRENCE table retains gbifid as its occurrence identifier and uses it to maintain the intended one-row-per-occurrence grain. The gbifid will support the planned Serving measure occurrence_count = COUNT(gbifid), which will then be grouped by urban area, year, and species. The Serving object and audience output have not yet been implemented.

| Trace step | Field | BigQuery Object | Observed Count | Transformation / rule |
|:---:|:---:|:---:|:---:|:---:|
| Source | gbifid | bigquery-public-data.gbif.occurrences | 3,729,438,201 | Original GBIF occurrence identifier |
| Raw | gbifid | BIODIVERSITY_PROJECT_RAW.GBIF_RAW | 4,478,374 | Preserved as STRING; source filtered to U.S. records with eventdate >= 2026-06-01; latest lastinterpreted selected per ID during ingestion |
| Curated | gbifid | BIODIVERSITY_PROJECT_CURATED.FACT_GBIF_OCCURRENCE | 4,478,374 | Selected unchanged from gbif_base; one fact row per GBIF ID, with spatial assignment stored separately in nullable version_key |
| Serving | occurrence_count = COUNT(gbifid) | URBAN_OCCURRENCES_SERVING | Not yet implemented |  |


------------------------------------------------------------------------
## 3. Run and interpret two acceptance checks

### Acceptance check 1 --- Grain or relationship

**P1 risk:** 
The coordinates provided for GBIF occurrences might not match the location information provided in fields like country and state code, meaning the observation counts my be different if the dataset is filtered down to just U.S observations and then joined to the urban areas table versus if all raw rows are joined to the geographic table.

**Specific risk tested:** The count of gbifid with a non-null urban area version_key in the curated table are based on the raw ingestion that first filters the source data by date and location country U.S. and then merges the occurrences to the urban area geographic table. This check compares the curated count to the count of gbifid with a non-null urban area version_key to a new query that filters the source data by date, joins all of these observations onto the urban area geographic table, without filtering by the US.

**Observed result**

| curated_us_spatial_matches | all_country_spatial_matches | all_query_us_spatial_matches | non_us_spatial_matches | difference_in_spatial_matches | percent_matches_from_non_us_records |
|---|---|---|---|---|---|
| 1782907 | 1789024 | 1782907 | 6117 | 6117 | 0.34 |

**Interpretation and action:** These check results show that there are some discrepancies between the count of urban observations when the GBIF source data is filtered for countrycode = 'US' before joining to the urban area table - there are 6,117 more observations that have coordinates in urban areas but don't have a 'US' country code. These records is relatively small compared to the spatially matched observations that have a US country code. It would be reasonable to continue filtering for both date and country code while ingesting data into raw in order to reduce the bytes used.

### Acceptance check 2 --- Audience-result meaning

**P1 risk:** 
Differences in reporting effort or GBIF source dataset composition could make changes in occurrence counts look like changes in biodiversity.

**Specific risk tested:** The observation counts were assessed on a monthly basis for trends that might indicate trends in reporting effort. These may look like increased contributions from individual datasets, changes in observation types, or missing species identifiers.

**Observed result**

| observation_month | occurrence_count | distinct_species | missing_specieskey | contributing_datasets | contributing_publishers |
|---|---|---|---|---|---|
| 2026-06-01 | 506249 | 16967 | 8870 | 42 | 39 |
| 2026-07-01 | 516009 | 15950 | 9135 | 38 | 32 |
| 2026-08-01 | 467663 | 14835 | 7178 | 31 | 27 |
| 2026-09-01 | 292986 | 12012 | 4296 | 11 | 11 |

**Interpretation and action:** These results indicate that there has been a decline in GBIF reporting activity from June to September. based on the occurrence count, distinct species, contributing datasets and publishers. Instead of evidence that species populations are declining, these results could indicate reduced reporting activity, fewer data contributions, seasonal changes in observation activity, or incomplete availability of records for that month.

### Acceptance-check summary

| Risk and affected result | Check code | Expected result and why | Observed result | Interpretation or action |
|:---:|:---:|:---:|:---:|:---:|
| Grain / relationship risk: Filtering GBIF to countrycode = 'US' before spatial matching could exclude observations whose coordinates fall within U.S. urban-area boundaries but whose country code is non-US or missing. This could affect the completeness of urban occurrence counts. | [Acceptance Check 1](../sql/p2_acceptance.sql#L6) | The U.S. filtered Curated spatial match count should equal the all-country (non-filtered) matches from the spatial join. The all-country total may be higher if records with non-US or missing country codes have coordinates inside U.S. urban areas. | Curated U.S. matches: 1,782,907. All-country matches: 1,789,024. U.S.-coded matches in the all-country query: 1,782,907. Additional non-US or missing-country-code matches: 6,117 (0.34%). | The additional 6,117 records represent a small but measurable completeness tradeoff from filtering by country code. Retain the U.S. filter because the project focuses on U.S. observations, but document that some geographically relevant records may be excluded. |
| Audience-result meaning risk: Changes in occurrence counts or distinct species could be interpreted as changes in biodiversity when they may instead reflect changes in reporting effort, source participation, or data availability. | [Acceptance Check 2](../sql/p2_acceptance.sql#L119)  | Monthly occurrence and distinct-species counts should be examined alongside contributing datasets and publishers. If these measures change together, it may indicate that source participation or reporting coverage is influencing the results. These measures are diagnostic indicators, not direct measures of population size or biodiversity trends. | Occurrences declined from 506,249 in June to 292,986 in September (about 42%). Distinct species declined from 16,967 to 12,012 (about 29%). Contributing datasets declined from 42 to 11, and publishers from 39 to 11. The percentage of records missing specieskey remained relatively low, declining from approximately 1.75% to 1.47%. | The decline in occurrence and species counts coincides with a substantial reduction in contributing datasets and publishers. This suggests that reporting coverage and data-source participation may be influencing the monthly results. Do not interpret these changes as evidence of declining species populations. Further investigation of dataset-level contributions and publication schedules would help distinguish reporting changes from ecological patterns. |


------------------------------------------------------------------------
## 4. Make the run reproducible and record the next step

1.  **Confirm access and configuration**
    -   Verify access to the GBIF and Census source tables, the `seis-732-urban-biodiversity` project, and the BigQuery `US` processing location.
2.  **Create the Raw and Curated datasets**
    -   Run the CREATE SCHEMA statements. Both datasets are created only if they do not already exist.
    -   Code: [Dataset setup](../sql/p2_ingest.sql#L11).
3.  **Ingest GBIF observations**
    -   Input: `bigquery-public-data.gbif.occurrences`.
    -   Create `GBIF_RAW` if absent, then `MERGE` U.S. records with `eventdate >= 2026-06-01`.
    -   `GBIF_RAW` is append-only by `gbifid`: new IDs are inserted; existing IDs are not refreshed.
    -   Code: [GBIF table setup](../sql/p2_ingest.sql#L19) · [GBIF MERGE](../sql/p2_ingest.sql#L33).
4.  **Ingest Census urban-area boundaries**
    -   Input: `bigquery-public-data.geo_us_boundaries.urban_areas`.
    -   Replace `URBAN_VINTAGE_STG` from the source; append new `geo_id` + `census_year` combinations to `URBAN_RAW`.
    -   Confirm that `p_census_year` on line 71 matches the source vintage before inserting.
    -   Code: [Census staging and Raw setup](../sql/p2_ingest.sql#L50) · [Vintage assignment and insert](../sql/p2_ingest.sql#L70).
5.  **Build the Curated tables**
    -   Inputs: `GBIF_RAW` and `URBAN_RAW`.
    -   Run the Curated script to rebuild `DIM_URBAN_AREA`, `DIM_DATE`, and `FACT_GBIF_OCCURRENCE`. 
        -   The `FACT_GBIF_OCCURRENCE` build also creates temporary base and spatial-match tables
        -   Unmatched observations are retained with a null `version_key`
    -   These three Curated tables are replaced on each run.
    -   Code: [Urban-area dimension](../sql/p2_curate.sql#L11) · [Date dimension](../sql/p2_curate.sql#L69) · [Fact table and spatial matching](../sql/p2_curate.sql#L98).
6.  **Run acceptance checks and validation**
    -   Prerequisite: the Raw and Curated tables must have been built.
    -   Run the country-filter/spatial-match comparison: [Acceptance Check 1](../sql/p2_acceptance.sql#L6).
    -   Run the monthly reporting-activity check: [Acceptance Check 2](../sql/p2_acceptance.sql#L119).
    -   Run supporting grain, relationship, and reconciliation checks if needed:
        [Raw and dimension checks](../sql/p2_acceptance.sql#L186) ·
        [Fact and relationship checks](../sql/p2_acceptance.sql#L222) ·
        [Raw-to-Curated reconciliation](../sql/p2_acceptance.sql#L265).
7.  **Save results and update the build record**
    -   Save Raw and Curated row/key counts, both acceptance-check outputs, and supporting validation results before rebuilding the Curated tables.
    -   Record the run date, source selection, and Census vintage in the P2 documentation.


### Main limitation and P3 next step

**Main limitation of the P2 path:** 

- Testing of the history tracking capabilities of the DIM_URBAN_AREA table hasn't happened in this phase.
    - Need to introduce a new urban area file with revisions or changes in boundaries to test the versioning
- Need to implement a load or refresh history table to track load success metadata
- GBIF duplicate row rules - need another layer than just most recent load. if two are in the same load, we need a "tiebreaker" column.
- By limiting observations in the curated layer to those that are within urban boundaries at the time of refresh/loading, would I be limiting the possibilities for historical analysis.
    - For example, if urban boundaries were revised (type 1 change) a few years later and some historical observations that should now get classified as "urban" would get missed?
- The query that creates the FACT_GBIF_OCCURRENCE curated table takes substantial amount of time to run and processes nearly 200 GB of data, so I'd like to optimize this more.

**Concrete P3 next step:** 
- Develop the version history for urban area boundaries more.
- Create a load and refresh history table.
- Review raw and curation SQL logic to prevent duplicate rows.
- Explore possible serving level tools for geographic visualizations.

### AI and tool-use note

AI assistance was used to help develop and revise BigQuery SQL, troubleshoot query logic, and organize the Raw and Curated data pipeline. AI suggestions were reviewed against the project requirements and the actual BigQuery source tables and query results. AI-generated code and interpretations were not accepted without review; I personally ran the ingestion, curation, and acceptance SQL in BigQuery and reviewed the resulting row counts, distinct keys, spatial matches, relationships, and monthly reporting metrics.

