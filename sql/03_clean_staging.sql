-- ============================================================================
-- 03_clean_staging.sql
-- Purpose: create a clean complaint-level staging table from raw_complaints
--          using only transformations justified by the data audit.
-- Scope:   harmonize the MVP product taxonomy, apply documented exclusions,
--          cast analytical fields, and preserve source values for traceability.
-- Output:  stg_complaints with one row per in-scope complaint.
-- ============================================================================

\set ON_ERROR_STOP on

-- Source timestamps use UTC ISO-8601 text. Keeping the session in UTC makes
-- date casts deterministic and consistent with the data-audit assumptions.
SET TIME ZONE 'UTC';

-- Recreate the staging table so the script can be rerun safely.
DROP TABLE IF EXISTS stg_complaints;


-- ============================================================================
-- 1. CLEAN AND CLASSIFY COMPLAINTS
-- ============================================================================
-- The prepared CTE applies type conversions required for downstream analysis.
-- Source categorical labels are otherwise preserved without unnecessary
-- normalization or imputation.

CREATE TABLE stg_complaints AS
WITH prepared AS (
    SELECT
        complaint_id,
        date_received::DATE AS date_received,
        product,
        sub_product,
        issue,
        sub_issue,
        company,
        submitted_via,
        date_sent_to_company::DATE AS date_sent_to_company,
        company_response_to_consumer,
        company_public_response,
        CASE
            WHEN timely_response = 'Yes' THEN TRUE
            WHEN timely_response = 'No' THEN FALSE
        END AS timely_response,
        consumer_complaint_narrative,
        state,
        zip_code,
        tags
    FROM raw_complaints
),
classified AS (
    SELECT
        *,

        -- Harmonize the historical credit-card taxonomy using product and
        -- sub-product rather than date because both source categories overlap
        -- during the transition period.
        CASE
            WHEN product = 'Credit card or prepaid card'
                 AND sub_product IN (
                     'General-purpose credit card or charge card',
                     'Store credit card'
                 )
                THEN 'Credit card'

            WHEN product = 'Credit card or prepaid card'
                THEN 'Prepaid card'

            WHEN product IN (
                'Credit card',
                'Checking or savings account',
                'Money transfer, virtual currency, or money service'
            )
                THEN product

            ELSE NULL
        END AS analytical_product,

        -- Narrative text is optional and is not imputed. This flag supports
        -- reporting on narrative availability without altering source content.
        CASE
            WHEN NULLIF(TRIM(consumer_complaint_narrative), '') IS NOT NULL
                THEN TRUE
            ELSE FALSE
        END AS has_narrative,

        -- Preserve the source company label while providing a conservative key
        -- for grouping casing variants identified during the data audit.
        LOWER(TRIM(company)) AS company_key

    FROM prepared
)

SELECT
    complaint_id,
    date_received,
    product AS source_product,
    analytical_product,
    sub_product,
    issue,
    sub_issue,
    company,
    company_key,
    submitted_via,
    date_sent_to_company,
    company_response_to_consumer,
    company_public_response,
    timely_response,
    consumer_complaint_narrative,
    has_narrative,
    state,
    zip_code,
    tags
FROM classified
WHERE analytical_product IS NOT NULL

    -- Historical prepaid-card complaints fall outside the MVP scope.
    AND analytical_product <> 'Prepaid card'

    -- Product/sub-product and issue are required for the planned analytical
    -- slices. The source uses "none" as a textual missing-value marker.
    AND NULLIF(LOWER(TRIM(sub_product)), 'none') IS NOT NULL
    AND NULLIF(LOWER(TRIM(issue)), 'none') IS NOT NULL

    -- One audited source row contains an unexpected product/sub-product pair.
    -- It remains unchanged in raw_complaints but is excluded from MVP staging.
    AND NOT (
        product = 'Checking or savings account'
        AND sub_product = 'Credit reporting'
    );


-- ============================================================================
-- 2. STAGING RECONCILIATION
-- ============================================================================
-- The data audit established an expected staging population of 522,381 rows
-- after 2,775 documented exclusions. Complaint IDs should remain unique.

SELECT
    COUNT(*) AS staging_rows,
    COUNT(DISTINCT complaint_id) AS distinct_complaint_ids
FROM stg_complaints;