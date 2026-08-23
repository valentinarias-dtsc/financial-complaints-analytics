-- ============================================================================
-- 02_data_audit.sql
-- Purpose: inspect the raw complaints table, document data-quality decisions,
--          and persist a small set of reusable audit results.
-- Scope:   this script never updates or deletes rows from raw_complaints.
-- Output:  idempotent materialized views plus documentary CSV snapshots in
--          data/audit/.
-- ============================================================================

\set ON_ERROR_STOP on

-- Source timestamps use UTC ISO-8601 text. Keeping the session in UTC makes
-- later casts deterministic and prevents a date from shifting by time zone.
SET TIME ZONE 'UTC';

-- Drop dependent objects first so the script can be rerun safely.
DROP MATERIALIZED VIEW IF EXISTS audit_check_summary_mv;
DROP MATERIALIZED VIEW IF EXISTS audit_cleaning_impact_mv;
DROP MATERIALIZED VIEW IF EXISTS audit_company_variants_mv;
DROP MATERIALIZED VIEW IF EXISTS audit_categorical_cardinality_mv;
DROP MATERIALIZED VIEW IF EXISTS audit_missing_profile_mv;
DROP MATERIALIZED VIEW IF EXISTS audit_integrity_mv;


-- ============================================================================
-- 1. ROW AND IDENTIFIER INTEGRITY
-- ============================================================================
-- These are the minimum blocking checks for a complaint-level dataset. The
-- additional classification checks anticipate rows that require an explicit
-- staging decision later in this audit.

CREATE MATERIALIZED VIEW audit_integrity_mv AS
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT complaint_id) AS unique_complaint_ids,
    COUNT(*) - COUNT(DISTINCT complaint_id) AS duplicate_complaint_ids,
    COUNT(*) FILTER (WHERE complaint_id IS NULL) AS missing_complaint_ids,
    COUNT(*) FILTER (
        WHERE date_received IS NULL
           OR date_received !~
              '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
    ) AS invalid_date_received_format,
    COUNT(*) FILTER (
        WHERE date_sent_to_company IS NULL
           OR date_sent_to_company !~
              '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
    ) AS invalid_date_sent_format,
    COUNT(*) FILTER (
        WHERE CASE
                  WHEN date_received ~
                       '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
                      THEN date_received::TIMESTAMPTZ
              END < TIMESTAMPTZ '2023-01-01 00:00:00+00'
           OR CASE
                  WHEN date_received ~
                       '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
                      THEN date_received::TIMESTAMPTZ
              END >= TIMESTAMPTZ '2026-01-01 00:00:00+00'
    ) AS received_dates_outside_period,
    COUNT(*) FILTER (
        WHERE timely_response IS NULL
           OR LOWER(TRIM(timely_response)) NOT IN ('yes', 'no')
    ) AS invalid_timely_response,
    COUNT(*) FILTER (
        WHERE product IS NULL
           OR sub_product IS NULL
           OR issue IS NULL
           OR LOWER(TRIM(product)) IN ('', 'none')
           OR LOWER(TRIM(sub_product)) IN ('', 'none')
           OR LOWER(TRIM(issue)) IN ('', 'none')
    ) AS missing_required_classification,
    COUNT(*) FILTER (
        WHERE product = 'Checking or savings account'
          AND sub_product = 'Credit reporting'
    ) AS invalid_product_sub_product_pairs
FROM raw_complaints;

SELECT *
FROM audit_integrity_mv;


-- ============================================================================
-- 2. MISSING-VALUE PROFILE
-- ============================================================================
-- "None" is treated as unavailable because the source uses it as a textual
-- missing-value marker. sub_issue is profiled but is not a required field:
-- its absence can be structurally valid for some issues.

CREATE MATERIALIZED VIEW audit_missing_profile_mv AS
WITH missing_counts AS (
    SELECT
        'complaint_id'::TEXT AS column_name,
        COUNT(*) FILTER (WHERE complaint_id IS NULL) AS missing_rows
    FROM raw_complaints

    UNION ALL

    SELECT
        'date_received',
        COUNT(*) FILTER (
            WHERE date_received IS NULL
               OR LOWER(TRIM(date_received)) IN ('', 'none')
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'product',
        COUNT(*) FILTER (
            WHERE product IS NULL OR LOWER(TRIM(product)) IN ('', 'none')
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'sub_product',
        COUNT(*) FILTER (
            WHERE sub_product IS NULL OR LOWER(TRIM(sub_product)) IN ('', 'none')
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'issue',
        COUNT(*) FILTER (
            WHERE issue IS NULL OR LOWER(TRIM(issue)) IN ('', 'none')
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'sub_issue',
        COUNT(*) FILTER (
            WHERE sub_issue IS NULL OR LOWER(TRIM(sub_issue)) IN ('', 'none')
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'consumer_complaint_narrative',
        COUNT(*) FILTER (
            WHERE consumer_complaint_narrative IS NULL
               OR LOWER(TRIM(consumer_complaint_narrative)) IN ('', 'none')
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'company',
        COUNT(*) FILTER (
            WHERE company IS NULL OR LOWER(TRIM(company)) IN ('', 'none')
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'timely_response',
        COUNT(*) FILTER (
            WHERE timely_response IS NULL
               OR LOWER(TRIM(timely_response)) IN ('', 'none')
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'submitted_via',
        COUNT(*) FILTER (
            WHERE submitted_via IS NULL
               OR LOWER(TRIM(submitted_via)) IN ('', 'none')
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'state',
        COUNT(*) FILTER (
            WHERE state IS NULL OR LOWER(TRIM(state)) IN ('', 'none')
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'company_response_to_consumer',
        COUNT(*) FILTER (
            WHERE company_response_to_consumer IS NULL
               OR LOWER(TRIM(company_response_to_consumer)) IN ('', 'none')
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'company_public_response',
        COUNT(*) FILTER (
            WHERE company_public_response IS NULL
               OR LOWER(TRIM(company_public_response)) IN ('', 'none')
        )
    FROM raw_complaints
),
row_count AS (
    SELECT COUNT(*) AS total_rows
    FROM raw_complaints
)
SELECT
    column_name,
    missing_rows,
    ROUND(100.0 * missing_rows / NULLIF(total_rows, 0), 2) AS missing_pct
FROM missing_counts
CROSS JOIN row_count;

SELECT *
FROM audit_missing_profile_mv
ORDER BY missing_pct DESC, column_name;

-- Inspect the rows that lack fields required for product/issue analysis.
-- sub_issue is intentionally excluded from this flag.
SELECT
    complaint_id,
    date_received,
    company,
    product,
    sub_product,
    issue,
    sub_issue,
    timely_response,
    submitted_via
FROM raw_complaints
WHERE product IS NULL
   OR sub_product IS NULL
   OR issue IS NULL
   OR LOWER(TRIM(product)) IN ('', 'none')
   OR LOWER(TRIM(sub_product)) IN ('', 'none')
   OR LOWER(TRIM(issue)) IN ('', 'none')
ORDER BY date_received, complaint_id;


-- ============================================================================
-- 3. DATE QUALITY
-- ============================================================================
-- Inclusion is defined only by date_received. date_sent_to_company may extend
-- beyond 2025 because it represents later processing of an in-scope complaint.

SELECT
    MIN(
        CASE
            WHEN date_received ~
                 '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
                THEN date_received::TIMESTAMPTZ
        END
    ) AS min_date_received,
    MAX(
        CASE
            WHEN date_received ~
                 '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
                THEN date_received::TIMESTAMPTZ
        END
    ) AS max_date_received,
    MIN(
        CASE
            WHEN date_sent_to_company ~
                 '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
                THEN date_sent_to_company::TIMESTAMPTZ
        END
    ) AS min_date_sent_to_company,
    MAX(
        CASE
            WHEN date_sent_to_company ~
                 '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
                THEN date_sent_to_company::TIMESTAMPTZ
        END
    ) AS max_date_sent_to_company,
    COUNT(*) FILTER (
        WHERE CASE
                  WHEN date_sent_to_company ~
                       '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
                      THEN date_sent_to_company::TIMESTAMPTZ
              END
              < CASE
                    WHEN date_received ~
                         '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
                        THEN date_received::TIMESTAMPTZ
                END
    ) AS sent_before_received,
    COUNT(*) FILTER (
        WHERE CASE
                  WHEN date_sent_to_company ~
                       '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z$'
                      THEN date_sent_to_company::TIMESTAMPTZ
              END >= TIMESTAMPTZ '2026-01-01 00:00:00+00'
    ) AS sent_after_analysis_period
FROM raw_complaints;

SELECT received_dates_outside_period
FROM audit_integrity_mv;


-- ============================================================================
-- 4. CATEGORICAL NORMALIZATION IMPACT
-- ============================================================================
-- Compare source labels with a conservative LOWER(TRIM()) key. The normalized
-- value supports grouping; source labels remain available for traceability.

CREATE MATERIALIZED VIEW audit_categorical_cardinality_mv AS
SELECT
    field_name,
    raw_distinct_values,
    normalized_distinct_values,
    raw_distinct_values - normalized_distinct_values AS merged_categories
FROM (
    SELECT
        'product'::TEXT AS field_name,
        COUNT(DISTINCT product) AS raw_distinct_values,
        COUNT(DISTINCT LOWER(TRIM(product))) AS normalized_distinct_values
    FROM raw_complaints

    UNION ALL

    SELECT
        'sub_product',
        COUNT(DISTINCT sub_product),
        COUNT(DISTINCT LOWER(TRIM(sub_product)))
    FROM raw_complaints

    UNION ALL

    SELECT
        'issue',
        COUNT(DISTINCT issue),
        COUNT(DISTINCT LOWER(TRIM(issue)))
    FROM raw_complaints

    UNION ALL

    SELECT
        'state',
        COUNT(DISTINCT state),
        COUNT(DISTINCT LOWER(TRIM(state)))
    FROM raw_complaints

    UNION ALL

    SELECT
        'company',
        COUNT(DISTINCT company),
        COUNT(DISTINCT LOWER(TRIM(company)))
    FROM raw_complaints

    UNION ALL

    SELECT
        'company_response_to_consumer',
        COUNT(DISTINCT company_response_to_consumer),
        COUNT(DISTINCT LOWER(TRIM(company_response_to_consumer)))
    FROM raw_complaints
) AS cardinality;

SELECT *
FROM audit_categorical_cardinality_mv
ORDER BY field_name;


-- ============================================================================
-- 5. COMPANY NORMALIZATION: SOURCE-LABEL VARIANTS
-- ============================================================================
-- These groups show exactly which original labels collapse under the proposed
-- normalized key and how many complaints are affected.

CREATE MATERIALIZED VIEW audit_company_variants_mv AS
WITH company_variants AS (
    SELECT
        LOWER(TRIM(company)) AS company_norm,
        company,
        COUNT(*) AS row_count
    FROM raw_complaints
    WHERE company IS NOT NULL
    GROUP BY LOWER(TRIM(company)), company
),
duplicated_normalized_names AS (
    SELECT company_norm
    FROM company_variants
    GROUP BY company_norm
    HAVING COUNT(*) > 1
)
SELECT
    company_norm,
    company AS original_company,
    row_count
FROM company_variants
WHERE company_norm IN (
    SELECT company_norm
    FROM duplicated_normalized_names
);

SELECT *
FROM audit_company_variants_mv
ORDER BY company_norm, original_company;


-- ============================================================================
-- 6. SMALL CATEGORICAL DOMAINS
-- ============================================================================
-- These values feed headline response and channel KPIs, so the complete domain
-- is inspected before downstream cleaning.

SELECT
    timely_response,
    COUNT(*) AS complaint_count
FROM raw_complaints
GROUP BY timely_response
ORDER BY complaint_count DESC, timely_response;

SELECT
    submitted_via,
    COUNT(*) AS complaint_count
FROM raw_complaints
GROUP BY submitted_via
ORDER BY complaint_count DESC, submitted_via;

SELECT
    company_response_to_consumer,
    COUNT(*) AS complaint_count
FROM raw_complaints
GROUP BY company_response_to_consumer
ORDER BY complaint_count DESC, company_response_to_consumer;


-- ============================================================================
-- 7. PRODUCT AND ISSUE TAXONOMY
-- ============================================================================
-- Product/sub-product pairs define valid dashboard slices. Issue-to-product
-- cardinality is also inspected because issue labels are not globally 1:1 with
-- products and should not be modeled as if they were.

SELECT
    product,
    COUNT(*) AS complaint_count
FROM raw_complaints
GROUP BY product
ORDER BY complaint_count DESC, product;

SELECT
    product,
    sub_product,
    COUNT(*) AS complaint_count
FROM raw_complaints
GROUP BY product, sub_product
ORDER BY product, complaint_count DESC, sub_product;

-- One source row uses a credit-reporting sub-product under checking/savings.
-- It is kept in raw_complaints but marked for exclusion from the MVP staging set.
SELECT
    complaint_id,
    date_received,
    company,
    product,
    sub_product,
    issue,
    sub_issue
FROM raw_complaints
WHERE product = 'Checking or savings account'
  AND sub_product = 'Credit reporting'
ORDER BY complaint_id;

SELECT
    issue,
    COUNT(*) AS complaint_count
FROM raw_complaints
GROUP BY issue
ORDER BY complaint_count DESC, issue;

SELECT
    issue,
    sub_issue,
    COUNT(*) AS complaint_count
FROM raw_complaints
GROUP BY issue, sub_issue
ORDER BY issue, complaint_count DESC, sub_issue;

WITH issue_product_cardinality AS (
    SELECT
        issue,
        COUNT(DISTINCT product) AS product_count,
        STRING_AGG(DISTINCT product, ' | ' ORDER BY product) AS products
    FROM raw_complaints
    WHERE issue IS NOT NULL
      AND LOWER(TRIM(issue)) NOT IN ('', 'none')
    GROUP BY issue
)
SELECT
    issue,
    product_count,
    CASE
        WHEN product_count = 1 THEN '1:1'
        ELSE '1:N'
    END AS issue_to_product_cardinality,
    products
FROM issue_product_cardinality
ORDER BY product_count DESC, issue;


-- ============================================================================
-- 8. CREDIT-CARD TAXONOMY TRANSITION
-- ============================================================================
-- CFPB source labels overlap in August 2023, so date alone is not a safe rule.
-- Historical "Credit card" sub-products determine whether a row maps to the
-- current credit-card scope or is excluded as prepaid-card history.

SELECT
    product,
    MIN(date_received::TIMESTAMPTZ) AS first_date_received,
    MAX(date_received::TIMESTAMPTZ) AS last_date_received,
    COUNT(*) AS complaint_count
FROM raw_complaints
WHERE product IN ('Credit card', 'Credit card or prepaid card')
GROUP BY product
ORDER BY product;

SELECT
    DATE_TRUNC('month', date_received::TIMESTAMPTZ)::DATE AS month_received,
    product,
    COUNT(*) AS complaint_count
FROM raw_complaints
WHERE product IN ('Credit card', 'Credit card or prepaid card')
GROUP BY DATE_TRUNC('month', date_received::TIMESTAMPTZ)::DATE, product
ORDER BY month_received, product;


-- ============================================================================
-- 9. ROWS AFFECTED BY FUTURE CLEANING
-- ============================================================================
-- Actions are mutually exclusive and exhaustive, which makes the expected
-- staging row count auditable. The materialized result is evidence only: this
-- script does not apply the cleaning rules to raw_complaints.

CREATE MATERIALIZED VIEW audit_cleaning_impact_mv AS
WITH classified_rows AS (
    SELECT
        CASE
            WHEN product IS NULL
              OR sub_product IS NULL
              OR issue IS NULL
              OR LOWER(TRIM(product)) IN ('', 'none')
              OR LOWER(TRIM(sub_product)) IN ('', 'none')
              OR LOWER(TRIM(issue)) IN ('', 'none')
                THEN 'exclude_missing_required_classification'
            WHEN product = 'Checking or savings account'
             AND sub_product = 'Credit reporting'
                THEN 'exclude_invalid_product_sub_product_pair'
            WHEN product = 'Credit card or prepaid card'
             AND sub_product IN (
                 'General-purpose credit card or charge card',
                 'Store credit card'
             )
                THEN 'map_historical_credit_to_credit_card'
            WHEN product = 'Credit card or prepaid card'
                THEN 'exclude_historical_prepaid'
            WHEN product = 'Credit card'
                THEN 'keep_current_credit_card'
            ELSE 'keep_other_in_scope_product'
        END AS cleaning_action
    FROM raw_complaints
),
grouped_actions AS (
    SELECT
        cleaning_action,
        CASE
            WHEN cleaning_action LIKE 'exclude_%' THEN 'exclude'
            WHEN cleaning_action LIKE 'map_%' THEN 'map_and_keep'
            ELSE 'keep'
        END AS action_group,
        COUNT(*) AS affected_rows
    FROM classified_rows
    GROUP BY cleaning_action
)
SELECT
    cleaning_action,
    action_group,
    affected_rows
FROM grouped_actions;

SELECT *
FROM audit_cleaning_impact_mv
ORDER BY action_group, cleaning_action;


-- ============================================================================
-- 10. COMPACT AUDIT SUMMARY AND DOCUMENTARY EXPORTS
-- ============================================================================
-- The summary reuses previously materialized results. PASS means the observed
-- value meets the stated expectation; REVIEW means a documented staging rule
-- is required rather than that the raw source should be changed.

CREATE MATERIALIZED VIEW audit_check_summary_mv AS
SELECT
    'duplicate_complaint_ids'::TEXT AS check_name,
    duplicate_complaint_ids::BIGINT AS observed_value,
    '= 0'::TEXT AS expected_condition,
    CASE WHEN duplicate_complaint_ids = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM audit_integrity_mv

UNION ALL

SELECT
    'missing_complaint_ids',
    missing_complaint_ids,
    '= 0',
    CASE WHEN missing_complaint_ids = 0 THEN 'PASS' ELSE 'FAIL' END
FROM audit_integrity_mv

UNION ALL

SELECT
    'received_dates_outside_period',
    received_dates_outside_period,
    '= 0',
    CASE WHEN received_dates_outside_period = 0 THEN 'PASS' ELSE 'FAIL' END
FROM audit_integrity_mv

UNION ALL

SELECT
    'invalid_date_received_format',
    invalid_date_received_format,
    '= 0',
    CASE WHEN invalid_date_received_format = 0 THEN 'PASS' ELSE 'FAIL' END
FROM audit_integrity_mv

UNION ALL

SELECT
    'invalid_date_sent_format',
    invalid_date_sent_format,
    '= 0',
    CASE WHEN invalid_date_sent_format = 0 THEN 'PASS' ELSE 'FAIL' END
FROM audit_integrity_mv

UNION ALL

SELECT
    'invalid_timely_response',
    invalid_timely_response,
    '= 0',
    CASE WHEN invalid_timely_response = 0 THEN 'PASS' ELSE 'FAIL' END
FROM audit_integrity_mv

UNION ALL

SELECT
    'missing_required_classification',
    missing_required_classification,
    '= 0; otherwise exclude from analytical staging',
    CASE WHEN missing_required_classification = 0 THEN 'PASS' ELSE 'REVIEW' END
FROM audit_integrity_mv

UNION ALL

SELECT
    'invalid_product_sub_product_pairs',
    invalid_product_sub_product_pairs,
    '= 0; otherwise exclude from analytical staging',
    CASE WHEN invalid_product_sub_product_pairs = 0 THEN 'PASS' ELSE 'REVIEW' END
FROM audit_integrity_mv

UNION ALL

SELECT
    'cleaning_action_reconciliation_gap',
    (SELECT total_rows FROM audit_integrity_mv) - SUM(affected_rows),
    '= 0',
    CASE
        WHEN (SELECT total_rows FROM audit_integrity_mv) = SUM(affected_rows)
            THEN 'PASS'
        ELSE 'FAIL'
    END
FROM audit_cleaning_impact_mv

UNION ALL

SELECT
    'historical_credit_rows_to_map',
    COALESCE(SUM(affected_rows), 0),
    '> 0; quantified for staging',
    CASE WHEN COALESCE(SUM(affected_rows), 0) > 0 THEN 'PASS' ELSE 'REVIEW' END
FROM audit_cleaning_impact_mv
WHERE cleaning_action = 'map_historical_credit_to_credit_card'

UNION ALL

SELECT
    'historical_prepaid_rows_to_exclude',
    COALESCE(SUM(affected_rows), 0),
    '> 0; quantified for staging',
    CASE WHEN COALESCE(SUM(affected_rows), 0) > 0 THEN 'PASS' ELSE 'REVIEW' END
FROM audit_cleaning_impact_mv
WHERE cleaning_action = 'exclude_historical_prepaid'

UNION ALL

SELECT
    'company_categories_merged_by_normalization',
    merged_categories,
    'review source-label variants before using normalized company keys',
    CASE WHEN merged_categories = 0 THEN 'PASS' ELSE 'REVIEW' END
FROM audit_categorical_cardinality_mv
WHERE field_name = 'company';

SELECT *
FROM audit_check_summary_mv
ORDER BY check_name;

-- Only stable, documentary results are exported. Large exploratory taxonomies
-- remain query output because they are more useful interactively than as files.
\copy (SELECT * FROM audit_check_summary_mv ORDER BY check_name) TO 'data/audit/audit_check_summary.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')
\copy (SELECT * FROM audit_missing_profile_mv ORDER BY missing_pct DESC, column_name) TO 'data/audit/missing_value_profile.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')
\copy (SELECT * FROM audit_categorical_cardinality_mv ORDER BY field_name) TO 'data/audit/categorical_normalization_impact.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')
\copy (SELECT * FROM audit_company_variants_mv ORDER BY company_norm, original_company) TO 'data/audit/company_normalization_variants.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')
\copy (SELECT * FROM audit_cleaning_impact_mv ORDER BY action_group, cleaning_action) TO 'data/audit/cleaning_impact.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')

-- End of audit.
