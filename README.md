# Financial Complaints Analytics

> A reproducible SQL and Power BI analytics project for monitoring consumer complaints in U.S. banking and payments.

**Project status:** Active development — reproducible extraction, raw PostgreSQL loading, and an initial SQL data audit are implemented. Staging transformations, the analytical mart, Power BI report, and published findings remain planned.

## Project overview

Financial institutions receive complaints across products, service channels, and operational processes. Turning those records into reliable management information can help customer operations and compliance teams identify where complaint volume is concentrated, which issues are growing, and where response performance may require attention.

This project uses public records from the [Consumer Financial Protection Bureau (CFPB) Consumer Complaint Database](https://www.consumerfinance.gov/data-research/consumer-complaints/) to build a focused analytics workflow in PostgreSQL and a planned two-page Power BI report. The objective is monitoring and prioritization—not complaint prediction, causal evaluation, or a production data platform.

The MVP is deliberately limited to practical SQL, transparent data-quality decisions, basic Power Query and DAX, and concise analytical communication. Python, notebooks, cloud services, and advanced BI features are outside the initial scope.

## Business objective

The project frames an analytics request from a Customer Operations or Compliance Manager who needs to understand:

- how complaint volume and composition change over time;
- which products and issues account for most complaints;
- which product–issue combinations are growing most rapidly;
- how timely response rates vary across relevant segments; and
- which high-volume areas warrant further investigation.

Complaint counts are not used to rank the overall quality of financial institutions. The CFPB data does not include customer or transaction exposure, so complaint volume alone cannot establish a complaint rate or service-quality difference.

## MVP scope

- **Period:** 2023-01-01 through 2025-12-31, using three complete calendar years.
- **Geography:** United States.
- **Source:** CFPB Consumer Complaint Database.
- **Unit of analysis:** one published consumer complaint.
- **Domain:** consumer banking and payments.
- **Reporting target:** two Power BI pages with a limited set of business KPIs.

The extractor retains four CFPB source categories:

1. `Credit card or prepaid card`
2. `Credit card`
3. `Checking or savings account`
4. `Money transfer, virtual currency, or money service`

The planned analytical layer will report three product families: credit cards, checking or savings accounts, and money transfer, virtual currency, or money services. Historical records from `Credit card or prepaid card` will be assigned to the credit-card family only when the sub-product identifies a general-purpose, charge, or store credit card. Historical prepaid sub-products will be excluded from the three-family MVP. This harmonization is planned for staging and is not yet implemented.

## Implementation status

| Component | Status | Repository evidence |
|---|---|---|
| Scope and source-category selection | Implemented | Fixed dates, product filters, and extraction partitions in `scripts/download_data.ps1` |
| Reproducible CFPB extraction | Implemented | PowerShell orchestration with `curl.exe`, temporary files, response checks, date-boundary validation, duplicate-ID checks, SHA-256 hashes, and an extraction manifest |
| Raw PostgreSQL schema and reload | Implemented | `sql/01_load_raw_data.sql` creates `raw_complaints`, atomically reloads eight CSV partitions, and reconciles row and distinct-ID counts |
| Initial raw-data audit | Implemented | `sql/02_data_audit.sql` profiles identifiers, missing values, dates, categorical normalization, taxonomy, and potentially affected rows |
| Staging and taxonomy harmonization | Planned | Cleaning rules will be finalized from the audit evidence |
| Quality checks and reporting mart | Planned | Record reconciliation, reusable analytical fields, and a calendar table |
| Power BI report and DAX measures | Planned | Two report pages and approximately six reusable measures |
| Findings and recommendations | Planned | Results will be published only after the analytical layer and metrics are validated |

## Data workflow

```mermaid
flowchart TD
    A[CFPB CSV export] --> B[PowerShell and curl extraction]
    B --> C[Raw CSV partitions and manifest]
    C --> D[PostgreSQL raw table]
    D --> E[SQL data audit]
    E --> F[Planned staging and validation]
    F --> G[Planned reporting mart]
    G --> H[Planned Power BI report]
```

Implemented steps preserve the source values in a text-based raw table so that type conversion, normalization, and exclusions remain explicit downstream decisions.

## Reproduce the implemented workflow

### Requirements

- Windows PowerShell or PowerShell with access to `curl.exe`.
- PostgreSQL with the `psql` command-line client.
- Network access to the CFPB complaint search API.

Run commands from the repository root so the relative `data/raw/` paths used by `psql` resolve correctly.

### 1. Download and validate the source partitions

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\download_data.ps1
```

The script uses eight fixed, non-overlapping date windows to remain below the CFPB CSV export limit. It writes validated files to `data/raw/` and creates `extraction_manifest.csv` with partition dates, row counts, file sizes, SHA-256 hashes, and extraction timestamps. Existing CSV files are validated and retained by default; pass `-Force` to rebuild them.

### 2. Create and reload the raw table

```powershell
psql -d <database_name> -f sql/01_load_raw_data.sql
```

All source columns are initially stored as `TEXT`. The load runs inside a transaction, truncates the existing raw table, imports all eight partitions with `\copy`, and finishes with a row-count and distinct-identifier reconciliation query.

### 3. Run the initial audit

```powershell
psql -d <database_name> -f sql/02_data_audit.sql
```

The audit script is read-only. It evaluates complaint-ID integrity, missing-value patterns, received and sent date coverage, the impact of text normalization, low-cardinality domains, product and issue relationships, the 2023 credit-card taxonomy transition, and records potentially affected by future cleaning rules.

Source CSVs and generated manifests are intentionally excluded from version control. Results depend on the CFPB export returned when the extractor is run, even though the filters and date windows are fixed.

## Technology responsibilities

| Area | Technology | Responsibility |
|---|---|---|
| Extraction | PowerShell and `curl.exe` | Build reproducible CFPB requests, partition downloads, validate files, and generate the manifest |
| Raw loading | PostgreSQL `psql` and `\copy` | Load validated CSV partitions without transforming source values |
| Audit and transformation | SQL | Profile quality, define cleaning decisions, harmonize taxonomy, validate records, and build the reporting mart |
| Power Query | Power BI PostgreSQL connector | Connect to the mart, select columns, verify types, and apply minor presentation adjustments |
| Reporting | Power BI and basic DAX | Define reusable measures and present executive and operational views |
| Version control and documentation | Git, GitHub, and Markdown | Track code, decisions, methodology, metric definitions, findings, and limitations |

Important transformation logic will remain in PostgreSQL rather than being duplicated in Power Query.

## Planned analytical outputs

### Core metrics

- Total complaints.
- Monthly complaint volume.
- Year-over-year complaint growth.
- Timely response rate.
- Complaint distribution by product and issue.
- Narrative availability rate.

Metric definitions, denominators, filters, and caveats will be documented before results are presented.

### Power BI report

**Page 1 — Executive Overview**

- headline KPIs;
- monthly complaint trend;
- product mix;
- leading issues; and
- year and product filters.

**Page 2 — Company & Issue Analysis**

- company complaint volume;
- timely response rate;
- response category distribution;
- high-volume and fast-growing issues; and
- company, product, and channel filters.

The report is planned around one analytical mart and a calendar table. Power Query will be limited to connection and presentation-level adjustments, while DAX will be limited to approximately six reusable measures.

## Repository structure

```text
financial-complaints-analytics/
├── data/
│   └── raw/                         # Generated CSV partitions; ignored by Git
├── scripts/
│   └── download_data.ps1            # Implemented CFPB extraction and validation
├── sql/
│   ├── 01_load_raw_data.sql         # Implemented raw schema and reload
│   └── 02_data_audit.sql            # Implemented read-only audit
├── .gitignore
├── LICENSE
└── README.md
```

Additional SQL, documentation, Power BI, and image artifacts will be added as their corresponding project stages are implemented.

## Delivery roadmap

| Stage | Status | Intended result |
|---|---|---|
| Scope, extraction, raw loading, and initial audit | In progress | Reproducible raw layer and evidence-based cleaning decisions |
| SQL cleaning, validation, and business analysis | Planned | Validated staging layer and reporting mart |
| KPI definitions and Power BI | Planned | Functional two-page report with reconciled measures |
| Findings, limitations, and presentation | Planned | Concise analytical narrative supported by validated outputs |

The roadmap communicates sequence rather than a delivery guarantee. Scope may be adjusted when the data audit identifies a material quality or interpretation constraint.

## Quality and interpretation safeguards

The completed workflow is intended to validate:

- uniqueness of complaint identifiers;
- valid date ranges;
- required values and category consistency;
- record counts across extraction, raw, staging, and mart layers;
- metric reconciliation between SQL and Power BI; and
- minimum-volume thresholds for company comparisons.

The source has important interpretation limits. Complaints are published records rather than a representative sample of all customer experiences. Company comparisons lack exposure denominators such as customer or transaction counts. Taxonomy changes, optional narratives, submission behavior, and publication rules may also affect observed patterns. Findings will therefore be presented as descriptive signals for monitoring and investigation, not causal evidence.

## Out of scope for the MVP

- Cloud data warehouses.
- dbt, Airflow, or orchestration platforms.
- Python analysis and Jupyter notebooks.
- Machine learning or complaint prediction.
- Advanced natural language processing.
- Census or external demographic enrichment.
- Excel-based analysis.
- Advanced Power Query or DAX.
- Real-time dashboards.

## Data source

Consumer Financial Protection Bureau. [Consumer Complaint Database](https://www.consumerfinance.gov/data-research/consumer-complaints/).

This repository is an independent portfolio project and is not affiliated with or endorsed by the CFPB.
