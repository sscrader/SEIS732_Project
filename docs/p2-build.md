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
| FACT_GBIF_OCCURRENCES | Eligible U.S. occurrences assigned to urban areas | One unique GBIF occurrence assigned to an applicable urban-area version | gbifid (PK)<br>version_key (FK) | [p2_curate.sql GBIF](../sql/p2_curate.sql#L91) |
| DIM_URBAN_AREA | Urban-area identifiers, names, geometry, and version attributes | One urban area per Census boundary vintage | version_key (PK) <br>compound of geo_id and census_year | [p2_curate.sql Urban Area](../sql/p2_curate.sql#L11) |
| DIM_DATE | Calendar attributes for occurrence dates | One calendar date | date_key (PK) | [p2_curate.sql Dates](../sql/p2_curate.sql#L50) |


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

[GBIF Raw to Curated Row and Key Counts](../sql/p2_acceptance.sql#L93) 
| raw_rows_in_test_window | curated_rows | raw_unique_gbifids | curated_unique_gbifids |
|---|---|---|---|
| 4478374 | 4478374 | 4478374 | 4478374 |

[GBIF Curated Grain and Retention](../sql/p2_acceptance.sql#L58) 
| total_fact_rows | unique_gbifids | assigned_to_urban_area | not_assigned_to_urban_area | missing_coordinates | missing_specieskey |
|---|---|---|---|---|---|
| 4478374 | 4478374 | 1782907 | 2695467 | 3065 | 74110 |

Urban Area data:

[Urban Area Curated Row and Key Counts](../sql/p2_acceptance.sql#L46) 
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

### Repository artifacts and code links

  -------------------------------------------------------------------------------
  Artifact          Responsibility    Repository path / link    Status
  ----------------- ----------------- ------------------------- -----------------
  Build note        Build             `docs/p2-build.md`        \[Complete / in
                    explanation, run                            progress\]
                    order, results,                             
                    field trace                                 

  Ingestion SQL     Source-to-Raw     `sql/02_ingest.sql`       \[Complete / N/A
                    step, if SQL                                / in progress\]
                    performs it                                 

  Curation SQL      Raw-to-Curated    `sql/03_curate.sql`       \[Complete / in
                    transformations                             progress\]

  Acceptance SQL    Executable checks `sql/04_acceptance.sql`   \[Complete / in
                                                                progress\]

  README            Link to P2 build  `README.md`               \[Complete / in
                    note                                        progress\]

  Supporting        Compact results / \[Path(s)\]               \[Complete / N/A
  evidence          screenshots, if                             / in progress\]
                    used                                        
  -------------------------------------------------------------------------------

### Ordered execution instructions

List steps in the order a person with authorized source access would run
them. Identify prerequisites, code links, expected outputs, and
operations that replace or append to objects.

  --------------------------------------------------------------------------------------------------------------
         Step Operation       Prerequisites / Code or procedure            Expected output /   Object behavior
                              inputs                                       result to inspect   
  ----------- --------------- --------------- ---------------------------- ------------------- -----------------
            1 Confirm source  \[Access,       \[Instructions / link\]      \[Sources           \[No change /
              access and      project,                                     accessible; correct other\]
              project /       location\]                                   location\]          
              dataset                                                                          
              configuration                                                                    

            2 Create or       \[Source and    \[`sql/02_ingest.sql` /      \[Raw table, row    \[Create /
              refresh GBIF    destination\]   loading instructions\]       count, key checks\] replace / append
              Raw input                                                                        / merge\]

            3 Create or       \[Source and    \[`sql/02_ingest.sql` /      \[Boundary count    \[Create /
              refresh Census  destination\]   loading instructions\]       and geometry        replace / append
              Raw input                                                    availability\]      / merge\]

            4 Build Curated   \[Required Raw  \[`sql/03_curate.sql`\]      \[Eligible,         \[Create /
              occurrences     objects\]                                    valid-coordinate,   replace / append
                                                                           matched, Curated    / merge\]
                                                                           counts\]            

            5 Build Curated   \[Required Raw  \[`sql/03_curate.sql`\]      \[Dimension counts, \[Create /
              dimensions /    and Curated                                  keys,               replace / append
              related objects objects\]                                    relationships\]     / merge\]

            6 Run acceptance  \[Curated       \[`sql/04_acceptance.sql`,   \[Grain /           \[Read-only /
              check 1         objects\]       query\]                      relationship        other\]
                                                                           result\]            

            7 Run acceptance  \[Curated       \[`sql/04_acceptance.sql`,   \[Audience-result   \[Read-only /
              check 2         objects\]       query\]                      meaning result\]    other\]

            8 Save results    \[Prior steps   \[Instructions / paths\]     \[Results and       \[Documentation
              and verify      complete\]                                   documentation       update\]
              documentation                                                accessible\]        
  --------------------------------------------------------------------------------------------------------------

**Exact run procedure:** \[Include script order, required substitutions
/ variables, interface steps, permissions, and configuration not obvious
from SQL links.\]

**Inputs that must already exist:** \[Source tables, datasets, access
permissions, prerequisite objects. Never include credentials or
secrets.\]

**Objects replaced, appended to, or otherwise changed:** \[Identify each
operation and how to avoid unintended duplicate appends or destructive
replacements.\]

**Results to save before later steps overwrite them:** \[Identify
intermediate results / counts / evidence to retain and where they are
stored.\]

### Reproducibility and verification

-   **Last successful documented build:** \[Date and time, including
    time zone\]
-   **Build input selection:** \[Snapshot, source version, date range,
    filters, selection timestamp\]
-   **What a reviewer can reproduce:** \[Objects and results that can be
    recreated\]
-   **Known later-run differences:** \[Source refreshes, snapshot
    limitations, and likely causes of changed counts\]
-   **Evidence instructions match the build:** \[Explain how you
    verified the documented run order against the successful build;
    include job IDs or result references if useful\]

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


### AI and tool-use note

\[Identify consequential AI or other tool assistance for code, SQL,
debugging, documentation, or analysis. Explain what you reviewed and how
you tested / verified it against actual BigQuery data. Identify the
implementation decisions and claims you personally checked.\]

