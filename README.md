# SEIS732 Project: Urban Biodiversity Data Product

A data warehousing project examining recorded biodiversity observations
in relation to urban geography.

## Project overview

This repository contains project documentation, SQL, and supporting
evidence for the SEIS732 data warehousing project.

The analytical focus is recorded observations. Observation counts
should be interpreted in the context of observer effort, geographic
coverage, and limitations in the underlying source data.

## Project stages

| Stage | Focus | Documentation |
|---|---|---|
| P0 | Need, audience, dataset, and feasibility | [P0 Feasibility](docs/p0-feasibility.md) |
| P1 | Grain, model, history, and pipeline plan | [P1 Plan](docs/p1-plan.md) |
| P2 | Ingestion, curation, and acceptance checks | Planned |
| P3 | Serving, reliability, quality, and lineage | Planned |
| P4 | Access, data product, documentation, and defense | Planned |

## Repository organization

- `docs/` — project plans and model documentation
- `sql/` — source profiling and analytical SQL
- `evidence/` — compact, permitted supporting evidence
- `.gitignore` — exclusions for local files and sensitive material

## Data and reproducibility

SQL scripts should identify their source objects and document
important assumptions. Record compact results and methodology,
not full source extracts.

Do not commit credentials, secrets, restricted data, or source
extracts prohibited by course or source-provider requirements.

## Current status

P1 preparation: organizing project documentation, confirming the
analytical grain, and preparing the source-profile check.