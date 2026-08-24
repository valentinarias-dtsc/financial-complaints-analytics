# Data Audit

The data audit assesses whether `raw_complaints` supports the planned metrics and staging transformations before any source values are changed. Selected results are persisted as materialized views and compact CSV evidence.

## 1. Audit Scope

The audit covers identifier integrity, relevant missing values, temporal coverage, categorical domains, product taxonomy, the historical credit-card transition, and expected cleaning impact.

The unit of analysis is one published complaint received from 2023-01-01 through 2025-12-31. The extraction contains four CFPB source categories: `Credit card or prepaid card`, `Credit card`, `Checking or savings account`, and `Money transfer, virtual currency, or money service`. `sql/03_clean_staging.sql` harmonizes them into three analytical families by separating historical credit-card records from prepaid-card records. Mortgage and student-loan complaints are not part of the current MVP extraction.

## 2. Integrity and Validation Checks

The audit reconciled 525,156 raw rows to 525,156 distinct complaint IDs. These checks validate complaint counting, time-series coverage, and the timely-response KPI.

| Check | Observed result | Expected condition | Status |
|---|---:|---|---|
| Duplicate complaint IDs | 0 | `= 0` | PASS |
| Missing complaint IDs | 0 | `= 0` | PASS |
| Invalid `date_received` formats | 0 | `= 0` | PASS |
| Invalid `date_sent_to_company` formats | 0 | `= 0` | PASS |
| Received dates outside the analytical period | 0 | `= 0` | PASS |
| Invalid `timely_response` values | 0 | `= 0` | PASS |
| Cleaning-action reconciliation gap | 0 | `= 0` | PASS |

These results support counting without deduplication and allow `date_received` to define the reporting period. The 1,207 complaints sent to a company after 2025-12-31 remain in scope because they were received within the period. `timely_response` contains only `Yes` and `No`, supporting an explicit binary denominator.

## 3. Missing-Value Profile

The source also represents unavailable values with `None`; the audit treats it as semantic absence alongside SQL `NULL` and empty text where applicable.

| Field | Missing rows | Missing share |
|---|---:|---:|
| `complaint_id` | 0 | 0.00% |
| `date_received` | 0 | 0.00% |
| `product` | 0 | 0.00% |
| `sub_product` | 5 | 0.00% |
| `issue` | 5 | 0.00% |
| `sub_issue` | 115,938 | 22.08% |
| `consumer_complaint_narrative` | 221,491 | 42.18% |
| `company` | 0 | 0.00% |
| `timely_response` | 0 | 0.00% |

The missing `sub_product` and `issue` values occur in the same five complaints. Both fields are required for analysis, so `sql/03_clean_staging.sql` excludes those records rather than imputing them.

Missing `sub_issue` values are not invalid because a subcategory is not applicable to every issue; they do not cause exclusion. Narratives are optional: 42.18% are unavailable and 57.82% are available for the planned KPI. They are not imputed.

## 4. Categorical Normalization

After `LOWER(TRIM())`, product, sub-product, issue, state, and company-response cardinalities did not change. Company cardinality decreased from 1,268 to 1,265, indicating three casing variants.

| Normalized company | Original labels | Affected rows |
|---|---|---:|
| `atm ops inc` | `ATM OPS Inc`; `ATM OPS INC` | 3 |
| `first technology federal credit union` | `First Technology Federal Credit Union`; `FIRST TECHNOLOGY FEDERAL CREDIT UNION` | 421 |
| `global credit union` | `Global Credit Union`; `GLOBAL CREDIT UNION` | 116 |

The variants affect 540 rows and differ only in casing. The staging layer retains the source label while using a `LOWER(TRIM())` key to prevent fragmented company totals. Advanced entity matching is not justified.

## 5. Product Taxonomy and Historical Credit-Card Transition

The historical `Credit card or prepaid card` and later `Credit card` labels overlap in August 2023. Raw labels—and a date cutoff alone—therefore cannot provide longitudinally comparable reporting.

Historical records are classified by `sub_product`. `General-purpose credit card or charge card` and `Store credit card` map to the current credit-card family. Prepaid sub-products are valid source records but outside the analytical MVP.

| Source group and action | Rows | Staging treatment |
|---|---:|---|
| Current `Credit card` | 187,840 | Retain as credit card |
| Historical credit-card sub-products | 32,541 | Map and retain as credit card |
| Historical prepaid sub-products | 2,769 | Exclude from the MVP |
| Other in-scope product families | 302,000 | Retain |

One `Checking or savings account` complaint has the inconsistent sub-product `Credit reporting`. It is excluded from staging while remaining unchanged in raw data.

## 6. Cleaning Decisions Derived from the Audit

| Audit finding | Analytical implication | Implemented staging treatment |
|---|---|---|
| Complaint IDs are complete and unique | Raw rows already represent the intended unit of analysis | Preserve one row per `complaint_id`; no deduplication rule required |
| Received dates are valid and within scope | Time-series filters can use a typed received date | Cast timestamps and define inclusion using `date_received` |
| Five rows lack required classification | Product and issue aggregations would be undefined | Exclude the five rows from analytical staging |
| `sub_issue` is structurally optional | Absence does not invalidate the parent issue | Retain rows and preserve the unavailable value |
| Narratives are unavailable for 42.18% of rows | Narrative coverage must be explicit | Do not impute; derive an availability indicator |
| Company casing creates three duplicate normalized labels | Raw labels would fragment company totals | Create a normalized grouping key and retain the source label |
| Historical credit and prepaid records share one source category | Raw product labels are not longitudinally comparable | Map 32,541 credit records and exclude 2,769 prepaid records |
| One product/sub-product pair is inconsistent | The row cannot be assigned reliably within the selected taxonomy | Exclude the row and document the rule |

Six mutually exclusive actions reconcile all 525,156 raw rows. `sql/03_clean_staging.sql` implements the 2,775 documented exclusions and targets an audit-derived staging population of 522,381 complaints; `sql/04_quality_checks.sql` validates that reconciliation when the workflow is run.

## 7. Audit Artifacts and Reproducibility

`sql/02_data_audit.sql` recreates six audit materialized views on each run. CSV snapshots in `data/audit/` preserve evidence for validation, missingness, normalization, and cleaning impact. This document records their interpretation and the decisions implemented in `sql/03_clean_staging.sql`; `sql/04_quality_checks.sql` provides the corresponding staging validation logic.
