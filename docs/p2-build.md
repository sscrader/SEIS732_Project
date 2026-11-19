# P2 --- Working Ingestion, Curation & Acceptance Checks

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

\[Describe consequential changes to source, scope, grain, fields,
relationships, or transformations. If none, state that explicitly.\]


### Source objects and input subset

| Source | Full identifier / location | Source row meaning | Fields needed | Actual subset / selection criteria |
|---|---|---|---|---|
| GBIF Biodiversity Data | bigquery-public-data.gbif.occurrences | One row is one species identification observation - <br>evidence of the occurrence of a species (or other taxon) at a particular place on a specified date. | gbifid<br>datasetkey<br>occurrenceid<br>taxonkey<br>specieskey<br>kingdom<br>phylum<br>class<br>order<br>family<br>genus<br>species<br>taxonrank<br>scientificname<br>countrycode<br>stateprovince<br>decimallatitude<br>decimallongitude<br>coordinateuncertaintyinmeters<br>eventdate<br>basisofrecord<br>occurrencestatus<br>individualcount<br>publishingorgkey<br>institutioncode<br>collectioncode<br>catalognumber<br>license<br>lastinterpreted | Raw table should update with new data after each refresh as it's added to the source file<br><br>Geographic filter: countrycode = 'US'<br>Temporal filter: inclusive eventdate >= 2021-01-01  |
| Census Urban Areas | bigquery-public-data.geo_us_boundaries.urban_areas | One row represents one polygon around an urban area in the US | geo_id<br>urban_area_code<br>name<br>type<br>area_land_meters<br>area_water_meters<br>internal_point_geom<br>urban_area_geom | Table should contain the most recent census urban area data available through BigQuery -<br>last updated Nov 20, 2019, 12:03:21 PM UTC-6<br><br>Should be able to keep version history of urban areas for changes in future census'  |


### BigQuery build environment

| Item | Value |
|---|---|
| project ID | seis-732-urban-biodiversity |
| dataset ID | seis-732-urban-biodiversity.urban_biodiversity_project |
| Biodiversity Raw dataset table name | GBIF_RAW |
| Urban Area Raw Dataset table name | URBAN_RAW |
| Processing location | US |

### Raw input design and ingestion procedure

**Ingestion approach**

Biodiversity Data
- Retain all source columns.
- Filter:
    - countrycode = 'US'
    - eventdate >= 2021-01-01
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
| seis-732-urban-biodiversity.urban_biodiversity_project.GBIF_RAW | Nov 19, 2026, 12:07:00 AM UTC-6 | 567,942,479 | 567,942,479 | 0 | 2021-01-01 00:00:00 UTC | 2026-09-29 00:00:00 UTC |
| seis-732-urban-biodiversity.urban_biodiversity_project.URBAN_RAW | Nov 19, 2026, 12:09:08 AM UTC-6 | 3,601 | 3,601 | 0 | NA | NA |

**Raw interpretation:** In both raw tables, the row count (COUNT(*)) is equal to the count of distinct keys (COUNT(DISTINCT(key_column))) which indicates that the columns I believed would work as keys for both tables hold up as primary keys. 

This may change for the URBAN_RAW table when new vintages of the same geo_id are introduced, in which case I would need to develop a vintage key that's a composite between the geo_id and census_year.

The eventdate range for the GBIF_RAW table also indicates successful filtering for dates after 2021-01-01.

**Raw input limitations:** This raw ingestion is still limited in the metadata it collects for each snapshot, source version, or selection dates. In P#, I'd like to create a load history table to track time and success of refreshes, new loads, and counts of new rows ingested.

------------------------------------------------------------------------
## 2. Build Curated at the intended grain

### Curated objects and intended grain
| Curated object | Purpose | Grain | Keys | SQL reference |
|:---:|:---:|:---:|:---:|:---:|
| FACT_GBIF_OCCURRENCES | Eligible U.S. occurrences assigned to urban areas | One unique GBIF occurrence assigned to an applicable urban-area version | gbifid (PK)<br>version_key (FK) | [p2_curate.sql GBIF](../sql/p2_curate.sql#L117-L233) |
| DIM_URBAN_AREA | Urban-area identifiers, names, geometry, and version attributes | One urban area per Census boundary vintage | version_key (PK) <br>compound of geo_id and census_year | [p2_curate.sql Urban Area](../sql/p2_curate.sql#L12-L83) |
| DIM_DATE | Calendar attributes for occurrence dates | One calendar date | date_key (PK) | [p2_curate.sql Dates](../sql/p2_curate.sql#L86-L114) |


### Transformations and business rules

**Transformations**
- Generate version_key from geo_id and census_year to create unique vintage identifiers.
- Convert the GBIF eventdate timestamp to a calendar date for the date-dimension relationship, while retaining the original timestamp in the fact table.
- Convert latitude and longitude into a BigQuery GEOGRAPHY point and spatially assign it to the appropriate urban-area polygon.

**Missing and invalid values:** 
- Exclude records without valid coordinates from the spatially assigned fact table.
- Retain the observation, even if specieskey is NULL. This preserves occurrence evidence without incorrectly discarding records.
- Exclude observations that cannot be assigned to an urban area from this particular fact table. Record their count separately for reconciliation.

**Repeated records:** 
- If records with the same gbifid appear in the biodiversity source dataset, we will retain the latest refreshed version of each record per gbifid, as established in your Raw ingestion design.

**Rules retained without transformation:** 
- The data types are generally maintained as they were assigned in the source tables.

### Observed Curated results and count reconciliation

  -----------------------------------------------------------------------------
  Object / stage   Observed row       Distinct  Difference from Explanation
                          count   intended key      prior stage 
                                         count                  
  -------------- -------------- -------------- ---------------- ---------------
  GBIF Raw input      \[Count\]      \[Count\]              --- \[Input
                                                                subset\]

  Eligible GBIF       \[Count\]      \[Count\]   \[Difference\] \[Eligibility
  records                                                       filters\]

  Records with        \[Count\]      \[Count\]   \[Difference\] \[Coordinate
  valid                                                         validation\]
  coordinates                                                   

  Records             \[Count\]      \[Count\]   \[Difference\] \[Spatial
  matched to                                                    join\]
  urban areas                                                   

  Curated             \[Count\]      \[Count\]   \[Difference\] \[Final
  occurrence                                                    result\]
  fact                                                          

  Curated             \[Count\]      \[Count\]   \[Difference\] \[Boundary /
  urban-area                                                    versioning
  dimension                                                     rule\]

  Curated date        \[Count\]      \[Count\]   \[Difference\] \[Date range /
  dimension, if                                                 generation
  implemented                                                   rule\]
  -----------------------------------------------------------------------------

**Count reconciliation and interpretation:** \[Explain material
Raw-to-Curated differences and how many records were excluded for each
major reason. If a join changes row count, explain whether that fits the
intended grain. Discuss unmatched and multiply matched records. A
successful query alone does not establish that the grain was
preserved.\]

**Supporting queries / evidence:** - \[Raw-to-eligible reconciliation
query\] - \[Coordinate validation query\] - \[Spatial match / unmatched
/ multiple-match query\] - \[Curated row count and key uniqueness
query\]

### Field / measure trace

Trace at least one source field through Raw and an implemented Curated
expression or rule. Connect it to the audience-facing measure or output
it supports.

  -------------------------------------------------------------------------------------------------------------
  Trace step        Field /           Object                                    Observed value, count, or
                    expression                                                  example
  ----------------- ----------------- ----------------------------------------- -------------------------------
  Source field      \[e.g., `gbifid`, `bigquery-public-data.gbif.occurrences`   \[Observed source value /
                    `eventdate`,                                                count\]
                    `specieskey`, or                                            
                    coordinate                                                  
                    field\]                                                     

  Raw field         \[Same field or   `raw_gbif_occurrences`                    \[Observed Raw value / count\]
                    renamed field\]                                             

  Curated           \[SQL expression, \[Curated object\]                        \[Observed Curated value /
  expression / rule filter, join, or                                            count\]
                    derived field\]                                             

  Audience measure  \[e.g., count of  \[Serving object, or mark as planned\]    \[Observed result, or
  / output          records or                                                  `Planned — not built in P2`\]
                    distinct recorded                                           
                    species by urban                                            
                    area and year\]                                             
  -------------------------------------------------------------------------------------------------------------

**Explanation of the trace:** \[Explain preservation, transformation,
observed evidence, and how the Curated field supports the primary
question. Do not claim a Serving result if it has not been built.\]

**Field trace evidence:** \[SQL query / result / screenshot reference.\]

------------------------------------------------------------------------

## 3. Run and interpret two acceptance checks

Use the two P1 risks as a starting point. Revise them if implementation
suggests a more meaningful check. Each check must inspect the
implemented path and produce an observed result.

### Acceptance check 1 --- Grain or relationship

**P1 risk:** GBIF coordinates may not agree with country / state fields,
and the spatial join may fail to preserve occurrence grain or may assign
an occurrence to multiple urban areas.

**Specific risk tested:** \[State the precise implementation risk.\]

**Check design** - Curated object(s) inspected: \[Objects\] - Key /
relationship inspected: \[e.g., `gbifid` after spatial join\] - SQL file
and query / section: \[`sql/04_acceptance.sql`, query name\] - Expected
result: \[e.g., zero duplicate occurrence IDs after join; state whether
unmatched records are expected\] - Why the expectation is appropriate:
\[Connect to intended grain / relationship\]

**Observed result**

  Measure                                         Observed result
  --------------------------------------------- -----------------
  Curated occurrence rows                               \[Count\]
  Distinct `gbifid` values                              \[Count\]
  Null `gbifid` values                                  \[Count\]
  Repeated `gbifid` groups                              \[Count\]
  Multiply matched occurrence IDs, if checked           \[Count\]
  Other relevant result                                 \[Value\]

**Interpretation and action:** \[Does the result meet the expectation?
If not, describe correction or justified treatment and record the
post-action result. State unresolved issues.\]

### Acceptance check 2 --- Audience-result meaning

**P1 risk:** Differences in reporting effort or GBIF source-dataset
composition could make changes in occurrence counts look like changes in
biodiversity.

**Specific risk tested:** \[For example, missing species identifiers,
changing `basisofrecord` / `datasetkey` composition, or unexpected
differences between occurrence counts and distinct species counts.\]

**Check design** - Curated object(s) inspected: \[Objects\] - Fields /
measures inspected: \[e.g., `eventdate`, `specieskey`, `basisofrecord`,
`datasetkey`\] - SQL file and query / section:
\[`sql/04_acceptance.sql`, query name\] - Expected result: \[Measurable
expectation, zero-violation condition, threshold, or reconciliation\] -
Why the expectation is appropriate: \[Explain how it protects
audience-result meaning\]

**Observed result**

  Measure                                                    Observed result
  ------------------------------------------------- ------------------------
  Total Curated occurrence records                                 \[Count\]
  Records missing `specieskey`                        \[Count / percentage\]
  Distinct recorded species                                        \[Count\]
  Reporting categories / `basisofrecord` examined       \[Result / summary\]
  Dataset composition examined                          \[Result / summary\]
  Other relevant result                                            \[Value\]

**Interpretation and action:** \[Explain what the results show about
recorded occurrence and species counts. Identify any treatment needed.
Do not interpret occurrence counts as population size or conclusive
biodiversity trends.\]

### Acceptance-check summary

  -----------------------------------------------------------------------------------------------
  Risk and affected   Check code                   Expected       Observed       Interpretation
  result                                           result and why result         or action
  ------------------- ---------------------------- -------------- -------------- ----------------
  \[Grain /           \[`sql/04_acceptance.sql`,   \[Expected     \[Actual       \[Meaning /
  relationship risk\] query / section\]            condition and  result\]       correction /
                                                   rationale\]                   treatment\]

  \[Audience-result   \[`sql/04_acceptance.sql`,   \[Expected     \[Actual       \[Meaning /
  meaning risk\]      query / section\]            condition and  result\]       correction /
                                                   rationale\]                   treatment\]
  -----------------------------------------------------------------------------------------------

**Unresolved acceptance issues:** \[Identify material issues still
unresolved, or explain what evidence supports the conclusion that none
remain.\]

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

**Main limitation of the P2 path:** I haven't tested the history tracking capabilities of the DIM_URBAN_AREA table yet.

load history - build and test
GBIF duplicate row rules - need another layer than just most recent load. if two are in the same load, we need a "tiebreaker" column.

**Concrete P3 next step:** \[Identify next technical task. For example,
build the Serving output aggregating recorded observations by urban
area, time, and species; then plan same-input rerun, changed-input
demonstration, and history verification.\]

**P1 model or explanation updates:** \[State whether implementation
changed the model meaning, grain, relationship, or history plan.
Identify diagrams / documentation to update. If none, explain briefly.\]

### AI and tool-use note

\[Identify consequential AI or other tool assistance for code, SQL,
debugging, documentation, or analysis. Explain what you reviewed and how
you tested / verified it against actual BigQuery data. Identify the
implementation decisions and claims you personally checked.\]

