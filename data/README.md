# Data Directory

This directory separates reproducible source extracts from the compact evidence that is appropriate to publish with the project.

## Directory Contents

| Path | Versioned | Purpose |
|---|---|---|
| `raw/` | No, except `.gitkeep` | CFPB CSV partitions and the generated extraction manifest |
| `audit/` | Yes | Aggregate SQL audit evidence and the published extraction manifest |

## Raw Data

Run the extractor from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\download_data.ps1
```

It creates eight non-overlapping CSV partitions for 2023–2025 and an `extraction_manifest.csv` in `data/raw/`. The manifest records each partition's date bounds, row count, file size, SHA-256 hash, status, and UTC extraction timestamp.

Raw extracts and the generated manifest are intentionally excluded from Git because they are generated source data, can be recreated from the public CFPB endpoint, and may change if the CFPB republishes records. Do not commit them.

## Published Audit Evidence

After loading `raw_complaints`, run:

```powershell
psql -d <database_name> -f sql/02_data_audit.sql
```

The script recreates the audit materialized views and exports the following compact evidence:

| File | Evidence captured |
|---|---|
| `audit_check_summary.csv` | Integrity, date, response-domain, and cleaning-reconciliation checks |
| `missing_value_profile.csv` | Missing counts and shares for analytically relevant fields |
| `categorical_normalization_impact.csv` | Cardinality before and after basic text normalization |
| `company_normalization_variants.csv` | Audited company labels that differ only by casing |
| `cleaning_impact.csv` | Mutually exclusive keep, map, and exclusion counts |

These files contain aggregate quality evidence rather than complaint-level records. Their interpretation and the resulting staging rules are documented in [`docs/data_audit.md`](../docs/data_audit.md).

## Published Baseline and New Extractions

[`audit/published_extraction_manifest.csv`](audit/published_extraction_manifest.csv) identifies the eight source files used for the published portfolio results. It records row counts, file sizes, extraction timestamps, and SHA-256 hashes, but contains no complaint-level data.

A new run creates `raw/extraction_manifest.csv`. Because the CFPB may republish historical records, its hashes and counts can differ from the published baseline.

The distinction is:

- **Method reproduction:** rerun the extractor and SQL pipeline against the currently available CFPB export;
- **published-result reconciliation:** compare the run with the committed audit evidence and published manifest;
- **byte-for-byte reproduction:** possible only when source files matching the published SHA-256 hashes are available; those large raw files are intentionally not distributed in this repository.

## Reconciliation Baseline

The published run reconciles:

- 525,156 raw rows and distinct complaint IDs;
- 2,775 documented exclusions;
- 522,381 staging and reporting-mart rows;
- 18 passing staging quality checks.

These values are the published baseline enforced by the staging quality checks. If a new CFPB extraction differs, the pipeline stops before creating the reporting mart so the new source population can be audited and the baseline can be updated intentionally.
