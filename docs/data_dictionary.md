# Data Dictionary

This dictionary documents the two PostgreSQL reporting tables consumed by Power BI. It focuses on the public analytical interface of the project; source preservation, audit fields, and excluded staging-only columns are described in the SQL scripts and the [data audit](data_audit.md).

## `mart_complaints`

**Grain:** one validated, in-scope published complaint.

**Population:** 522,381 complaints received from 2023-01-01 through 2025-12-31 after the 2,775 exclusions documented in the audit.

| Column | PostgreSQL type | Description | Source or derivation | Caveat |
|---|---|---|---|---|
| `complaint_id` | `text` | CFPB complaint identifier and mart row key | Preserved from source | Unique and complete in the published run; kept as text because it is an identifier, not a quantity |
| `date_received` | `date` | Date the CFPB received the complaint | Cast from source timestamp in staging | Defines inclusion in the analytical period and relates to `dim_calendar[date]` |
| `source_product` | `text` | Original CFPB product label | Preserved from `raw_complaints.product` | Historical `Credit card or prepaid card` remains visible here and is not longitudinally comparable by itself |
| `analytical_product` | `text` | Harmonized product family used for reporting | Derived from source product and sub-product in staging | Limited to the three MVP families; historical prepaid complaints are excluded |
| `sub_product` | `text` | CFPB product subcategory | Preserved after required-value validation | Labels depend on the CFPB taxonomy and may change over time |
| `issue` | `text` | CFPB issue category | Preserved after required-value validation | Descriptive category, not a verified cause |
| `sub_issue` | `text` | More detailed CFPB issue category | Preserved from source | Optional and unavailable for some issue categories; absence does not cause exclusion |
| `company_name` | `text` | Company label used in analysis | Source company with three audited casing variants consolidated | No general entity resolution; subsidiaries or related legal entities may remain separate |
| `submitted_via` | `text` | Channel through which the complaint was submitted | Preserved from source | Web dominates the selected population, limiting channel comparisons |
| `date_sent_to_company` | `date` | Date the CFPB sent the complaint to the company | Cast from source timestamp in staging | May fall after 2025-12-31 because scope is based on `date_received` |
| `company_response_to_consumer` | `text` | CFPB company-response category | Preserved from source | Response category does not measure satisfaction or resolution quality |
| `timely_response` | `boolean` | Whether the response was recorded as timely | Maps source `Yes` to `TRUE` and `No` to `FALSE` | Measures response timing only |
| `has_narrative` | `boolean` | Whether a non-empty consumer narrative is available | Derived from `consumer_complaint_narrative` in staging | Indicates availability, not text quality or representativeness |
| `state` | `text` | U.S. state or territory code associated with the complaint | Preserved from source | Not enriched or adjusted for population or customer exposure |

### Analytical product rules

| Source condition | `analytical_product` | Treatment |
|---|---|---|
| Current `Credit card` | `Credit card` | Retained |
| Historical `Credit card or prepaid card` with general-purpose, charge, or store credit-card sub-product | `Credit card` | Harmonized and retained |
| Historical prepaid-card sub-product | — | Excluded from the MVP |
| `Checking or savings account` | Same as source | Retained, except one audited inconsistent product/sub-product record |
| `Money transfer, virtual currency, or money service` | Same as source | Retained |

## `dim_calendar`

**Grain:** one calendar date.

**Population:** every date from 2023-01-01 through 2025-12-31, including dates without complaints.

| Column | PostgreSQL type | Description | Derivation | Reporting use |
|---|---|---|---|---|
| `date` | `date` | Calendar date and dimension key | `GENERATE_SERIES` over the MVP period | One-side key related to `mart_complaints[date_received]` |
| `year` | `integer` | Four-digit calendar year | Extracted from `date` | Year slicer and single-year YoY context |
| `month` | `integer` | Calendar month number, 1–12 | Extracted from `date` | Numeric month logic |
| `month_name` | `text` | Full English month name | Formatted from `date` | Display label when month is used without year |
| `quarter_number` | `integer` | Calendar quarter number, 1–4 | Extracted from `date` | Quarter ordering and filtering |
| `quarter_name` | `text` | Quarter label `Q1`–`Q4` | Derived from `quarter_number` | Display label |
| `year_month` | `text` | Month label in `YYYY-MM` format | Formatted from `date` | Monthly trend axis |
| `year_month_sort` | `integer` | Chronological sort key in `YYYYMM` form | `year * 100 + month` | Power BI sort-by column for `year_month` |

## Model Relationship

Power BI uses one active, single-direction relationship:

```text
dim_calendar[date]  1 ───── *  mart_complaints[date_received]
```

`dim_calendar` is marked as the Date Table. Calendar filters propagate to the complaint mart; automatic date/time hierarchies are not used.
