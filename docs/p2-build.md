# P2 --- Working Ingestion, Curation & Acceptance Checks

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

**P2 path being built:** \[Explain which part of the planned product
this implementation supports, including source data, geographic
relationship, and time period.\]

### Changes from the P1 plan

\[Describe consequential changes to source, scope, grain, fields,
relationships, or transformations. If none, state that explicitly.\]

  -----------------------------------------------------------------------
  P1 decision             P2 implementation       Reason for change or
                                                  confirmation
  ----------------------- ----------------------- -----------------------
  GBIF: U.S. records      \[Actual subset and     \[Explain\]
  within selected         date boundaries\]       
  five-year period                                

  Census urban-area       \[Actual source and     \[Explain\]
  boundaries              boundary vintage\]      

  Occurrence grain: one   \[Actual Raw and        \[Explain\]
  row per `gbifid`        Curated grain\]         

  Spatial assignment to   \[Actual predicate and  \[Explain\]
  urban areas             join behavior\]         

  Urban-area versioning   \[What is implemented;  \[Explain\]
                          what is deferred\]      
  -----------------------------------------------------------------------

### Source objects and input subset

  -------------------------------------------------------------------------------------------------------------------------
  Source         Full identifier / location                             Source row     Fields needed         Actual subset
                                                                        meaning                              / selection
                                                                                                             criteria
  -------------- ------------------------------------------------------ -------------- --------------------- --------------
  GBIF           `bigquery-public-data.gbif.occurrences`                One GBIF       \[e.g., `gbifid`,     \[Actual
  occurrences                                                           occurrence     `eventdate`,          filters\]
                                                                        record         `countrycode`,        
                                                                                       `specieskey`,         
                                                                                       `scientificname`,     
                                                                                       `decimallatitude`,    
                                                                                       `decimallongitude`,   
                                                                                       `basisofrecord`,      
                                                                                       `datasetkey`\]        

  Census urban   `bigquery-public-data.geo_us_boundaries.urban_areas`   One polygon    \[e.g., `geo_id`,     \[Actual
  areas                                                                 representing a name,                 geography /
                                                                        U.S. urban     `urban_area_geom`\]   vintage\]
                                                                        area                                 

  Other source,  \[Full identifier\]                                    \[Row          \[Fields\]            \[Subset\]
  if applicable                                                         meaning\]                            
  -------------------------------------------------------------------------------------------------------------------------

**Subset and reproducibility details**

-   GBIF start date (inclusive): \[YYYY-MM-DD\]
-   GBIF end date (exclusive): \[YYYY-MM-DD\]
-   Geographic filter: \[e.g., `countrycode = 'US'`\]
-   Additional eligibility rules: \[Actual filters\]
-   Census boundary source / vintage: \[Describe\]
-   Snapshot, source version, or selection timestamp: \[Record what is
    available\]
-   Remaining reproducibility limitation: \[Explain whether the same
    source rows can be retrieved later\]

### BigQuery build environment

  Item                           Value
  ------------------------------ ------------------------------------
  Google Cloud project ID        \[Project ID\]
  Raw dataset                    \[Full identifier\]
  Curated dataset                \[Full identifier\]
  Processing location            \[Location\]
  Source project / datasets      \[Full identifiers\]
  Other relevant configuration   \[Settings / access requirements\]

### Raw input design and ingestion procedure

Describe how each source is brought into or exposed through your own
BigQuery project.

  --------------------------------------------------------------------------------------------------------------------------------------------
  Raw object                 Source object                                          Fields /         Raw row meaning   Creation / loading code
                                                                                    information                        
                                                                                    preserved and                      
                                                                                    why                                
  -------------------------- ------------------------------------------------------ ---------------- ----------------- -----------------------
  `raw_gbif_occurrences`     `bigquery-public-data.gbif.occurrences`                \[Fields         \[One row         \[`sql/02_ingest.sql`
                                                                                    retained and     represents...\]   or loading procedure\]
                                                                                    purpose\]                          

  `raw_census_urban_areas`   `bigquery-public-data.geo_us_boundaries.urban_areas`   \[Identifiers,   \[One row         \[`sql/02_ingest.sql`
                                                                                    names,           represents...\]   or loading procedure\]
                                                                                    geometries                         
                                                                                    retained\]                         

  \[Additional Raw object\]  \[Source\]                                             \[Information    \[Row meaning\]   \[Code / procedure\]
                                                                                    preserved\]                        
  --------------------------------------------------------------------------------------------------------------------------------------------

**Ingestion approach**

-   Source type: \[BigQuery public table, source view, external table,
    file, etc.\]
-   Destination type: \[Native table, external table, view, etc.\]
-   Operation: \[Create, replace, append, merge, etc.\]
-   Loading procedure: \[Exact steps, including any interface or file
    operation\]
-   Source fields excluded: \[List and explain, if applicable\]
-   Fields / types intentionally preserved: \[Identify\]

**Code and loading instructions:** \[Link runnable SQL or document exact
procedure, prerequisites, and how to execute it.\]

-   [Source-to-Raw ingestion SQL](../sql/02_ingest.sql)

### Observed Raw input results

Record results from the build you actually ran.

  -------------------------------------------------------------------------------------------------
  Raw object                 Run /            Row count  Distinct key    Null key What one row
                             verification                       count       count represents
                             date                                                 
  -------------------------- -------------- ----------- ------------- ----------- -----------------
  `raw_gbif_occurrences`     \[Date\]         \[Count\]   \[`gbifid`:   \[Count\] \[Description\]
                                                              count\]             

  `raw_census_urban_areas`   \[Date\]         \[Count\]   \[`geo_id`:   \[Count\] \[Description\]
                                                              count\]             
  -------------------------------------------------------------------------------------------------

**Raw count interpretation:** \[Compare observed counts with expected /
profiled source counts. Explain differences due to filters, source
changes, snapshot timing, or loading behavior.\]

**Evidence / query references:** - GBIF Raw count and key check: \[SQL
file and query\] - Census Raw count and key check: \[SQL file and
query\] - Other evidence: \[Link / identifier\]

**Raw input limitations:** \[Explain source refresh, snapshot, or subset
limitations.\]

------------------------------------------------------------------------

## 2. Build Curated at the intended grain

### Curated objects and intended grain

State precisely what one row represents in each implemented object and
how it is identified.

  -----------------------------------------------------------------------------------------------
  Curated object            Purpose        Intended grain: Grain identifier / key SQL reference
                                           one row                                
                                           represents...                          
  ------------------------- -------------- --------------- ---------------------- ---------------
  `fact_gbif_occurrences`   Eligible U.S.  \[Actual row    \[`gbifid` and         \[File and
                            occurrences    meaning\]       applicable             section\]
                            assigned to                    relationship/version   
                            urban areas                    key\]                  

  `dim_urban_area`          Urban-area     \[One area or   \[`version_key`,       \[File and
                            identifiers,   one area        `geo_id`, or actual    section\]
                            names,         version?\]      key\]                  
                            geometry, and                                         
                            version                                               
                            attributes                                            

  `dim_date` (if            Calendar       \[Actual row    \[Date key\]           \[File and
  implemented)              attributes for meaning\]                              section\]
                            occurrence                                            
                            dates                                                 

  \[Additional object\]     \[Purpose\]    \[Grain\]       \[Key\]                \[Reference\]
  -----------------------------------------------------------------------------------------------

**Actual Curated grain:** \[Explain whether the occurrence table retains
one row per `gbifid`. Identify the field or field combination
distinguishing Curated rows. Explain any departure from P1.\]

### Transformations and business rules

Document rules actually applied, why they are appropriate, and how they
support the analytical question.

  -----------------------------------------------------------------------------------------
  Field /          Raw input            Curated           Reason            SQL / evidence
  relationship                          transformation or                   reference
                                        rule                                
  ---------------- -------------------- ----------------- ----------------- ---------------
  U.S. eligibility `countrycode`        \[Actual filter   \[Why             \[Reference\]
                                        and null          appropriate\]     
                                        handling\]                          

  Observation date `eventdate`          \[Parsing,        \[Time analysis\] \[Reference\]
                                        valid-date rule,                    
                                        date range,                         
                                        missing dates\]                     

  Occurrence       `gbifid`             \[Null /          \[Protect grain\] \[Reference\]
  identifier                            duplicate                           
                                        handling and key                    
                                        rule\]                              

  Coordinates      `decimallatitude`,   \[Null, range,    \[Spatial         \[Reference\]
                   `decimallongitude`   type,             assignment\]      
                                        point-geometry                      
                                        rules\]                             

  Species          `specieskey`,        \[Eligibility /   \[Species-level   \[Reference\]
  identification   `scientificname`,    missing-value     analysis\]        
                   other taxonomic      rules\]                             
                   fields                                                   

  Urban-area       Occurrence point and \[Spatial         \[Geographic      \[Reference\]
  assignment       `urban_area_geom`    predicate and     relationship\]    
                                        join behavior\]                     

  Urban-area       `geo_id`, boundary   \[Version-key /   \[Preserve        \[Reference\]
  identity /       vintage, geometry    boundary          geographic        
  history                               handling;         meaning\]         
                                        identify deferred                   
                                        work\]                              

  Repeated rows    \[Identifiers\]      \[Deduplication / \[Effect on       \[Reference\]
                                        retention rule\]  grain\]           

  Other            \[Field /            \[Rule\]          \[Reason\]        \[Reference\]
                   relationship\]                                           
  -----------------------------------------------------------------------------------------

**Missing and invalid values:** \[Explain handling of null dates,
missing identifiers, missing species information, missing / out-of-range
coordinates, and other invalid values. Distinguish exclusions from
retained nulls.\]

**Repeated records:** \[State whether repeated `gbifid` values occur and
whether records are removed, retained, or treated another way. Explain
why.\]

**Spatial relationship:** \[Describe point construction and spatial
join. State the actual predicate, unmatched-record treatment, and
multiple-match handling.\]

**Rules retained without transformation:** \[Identify source fields or
relationships retained as-is and provide observed evidence that they are
suitable.\]

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

**Main limitation of the P2 path:** \[Most consequential limitation in
the implemented path: source completeness / reporting effort, spatial
matching, boundary vintage / versioning, bounded subset, etc.\]

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

------------------------------------------------------------------------

## P2 completion review

Mark complete only when the repository contains the evidence.

-   [ ] Build note saved at `docs/p2-build.md` or clearly identified
    alternative.
-   [ ] README links to the P2 build note.
-   [ ] Source objects, full identifiers, subset, Google Cloud project,
    datasets, and processing location documented.
-   [ ] Runnable ingestion SQL or exact loading instructions saved.
-   [ ] Raw row counts, key checks, row meaning, and verification date
    recorded.
-   [ ] Curated objects, intended grain, and grain identifiers
    documented.
-   [ ] Actual rules for fields, types, missing / invalid values,
    repeated rows, and relationships explained.
-   [ ] Curated counts and material differences from Raw explained.
-   [ ] At least one source → Raw → Curated field trace includes
    observed evidence and audience measure / output.
-   [ ] Two executable acceptance checks saved.
-   [ ] Both checks include expected results, observed results, and
    interpretations / actions.
-   [ ] Run order, prerequisites, object behavior, and results to
    preserve documented.
-   [ ] Documented procedure matches one successful build.
-   [ ] Main P2 limitation and concrete P3 next step recorded.
-   [ ] Consequential AI / tool assistance and verification documented.
-   [ ] P2 work committed to the repository.

## Canvas submission

-   **Repository URL:** \[Paste URL\]
-   **P2 commit link or short identifier:** \[Paste commit hash / URL\]
-   **Build note path:** `docs/p2-build.md` \[or alternative path\]
-   **Submission note, if needed:** \[Brief clarification for
    instructor\]

------------------------------------------------------------------------

## P2 evidence standard --- self-review

  --------------------------------------------------------------------------
  Evaluation level        Evidence to look for       Self-assessment / notes
  ----------------------- -------------------------- -----------------------
  Insufficient Evidence   Missing / inaccessible     \[What is missing?\]
                          code, inputs, or results   
                          prevent checking the build 
                          and main claims.           

  Developing              Useful parts run, but a    \[What remains
                          consequential input,       incorrect /
                          grain, transformation,     unverifiable?\]
                          check, or run-order issue  
                          makes the Curated result   
                          incorrect or unverifiable. 

  Proficient              Documented                 \[What evidence
                          source-to-Raw-to-Curated   demonstrates each
                          path works at declared     element?\]
                          grain; rules fit the       
                          question; two relevant     
                          checks have observed and   
                          interpreted results;       
                          counts and field trace     
                          support the explanation;   
                          code and instructions      
                          support reproduction.      

  Advanced                Meets Proficient and       \[What case did you
                          investigates an additional investigate, what
                          consequential source or    changed, and why is the
                          transformation case.       treatment justified?\]
                          Evidence shows its effect  
                          on Curated and supports    
                          the chosen treatment.      
  --------------------------------------------------------------------------

> More SQL, objects, or documentation alone do not establish Advanced
> evidence. The additional case should investigate consequential source
> or transformation behavior and show its effect on the Curated result.
