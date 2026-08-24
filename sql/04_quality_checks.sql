-- ============================================================================
-- 04_quality_checks.sql
-- Purpose: validate that stg_complaints satisfies the integrity, scope, and
--          transformation rules established by the data audit.
-- Scope:   verify staging outputs without modifying or repairing data.
-- Output:  a compact PASS/FAIL summary for the staging quality checks.
-- ============================================================================

\set ON_ERROR_STOP on


-- ============================================================================
-- 1. STAGING QUALITY CHECKS
-- ============================================================================
-- Each check compares an observed value with its expected value. A FAIL should
-- be investigated in staging before building downstream reporting objects.

WITH quality_checks AS (

    -- The data audit established an expected staging population of 522,381
    -- complaints after 2,775 documented exclusions.
    SELECT
        'staging_row_count' AS check_name,
        COUNT(*)::BIGINT AS observed_value,
        522381::BIGINT AS expected_value,
        CASE
            WHEN COUNT(*) = 522381 THEN 'PASS'
            ELSE 'FAIL'
        END AS status
    FROM stg_complaints

    UNION ALL

    SELECT
        'raw_to_staging_exclusions',
        (
            (SELECT COUNT(*) FROM raw_complaints)
            -
            (SELECT COUNT(*) FROM stg_complaints)
        )::BIGINT,
        2775::BIGINT,
        CASE
            WHEN (
                (SELECT COUNT(*) FROM raw_complaints)
                -
                (SELECT COUNT(*) FROM stg_complaints)
            ) = 2775
                THEN 'PASS'
            ELSE 'FAIL'
        END
        

    -- Complaint ID defines the staging grain and must remain complete and
    -- unique after the documented exclusions.
    UNION ALL

    SELECT
        'missing_complaint_id',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE complaint_id IS NULL
       OR LOWER(TRIM(complaint_id)) IN ('', 'none')

    UNION ALL

    SELECT
        'duplicate_id_excess_rows',
        (COUNT(*) - COUNT(DISTINCT complaint_id))::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = COUNT(DISTINCT complaint_id) THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints


    -- Required analytical fields should remain populated according to the same
    -- missing-value definition used during the data audit.
    UNION ALL

    SELECT
        'missing_date_received',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE date_received IS NULL

    UNION ALL

    SELECT
        'missing_analytical_product',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE analytical_product IS NULL
       OR LOWER(TRIM(analytical_product)) IN ('', 'none')

    UNION ALL

    SELECT
        'missing_sub_product',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE sub_product IS NULL
       OR LOWER(TRIM(sub_product)) IN ('', 'none')

    UNION ALL

    SELECT
        'missing_issue',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE issue IS NULL
       OR LOWER(TRIM(issue)) IN ('', 'none')

    UNION ALL

    SELECT
        'missing_company',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE company IS NULL
       OR LOWER(TRIM(company)) IN ('', 'none')

    UNION ALL

    SELECT
        'missing_company_key',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE company_key IS NULL
       OR company_key IN ('', 'none')

    UNION ALL

    SELECT
        'missing_timely_response',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE timely_response IS NULL


    -- Staging should contain only the three product families defined for the
    -- MVP and should preserve the documented historical taxonomy decisions.
    UNION ALL

    SELECT
        'unexpected_analytical_product',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE analytical_product NOT IN (
        'Credit card',
        'Checking or savings account',
        'Money transfer, virtual currency, or money service'
    )

    UNION ALL

    SELECT
        'historical_prepaid_rows',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE source_product = 'Credit card or prepaid card'
      AND sub_product IN (
          'General-purpose prepaid card',
          'Gift card',
          'Government benefit card',
          'Payroll card',
          'Student prepaid card'
    )

    UNION ALL

    SELECT
        'unexpected_historical_card_sub_product' AS check_name,
        COUNT(*)::BIGINT AS observed_value,
        0::BIGINT AS expected_value,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END AS status
    FROM raw_complaints
    WHERE product = 'Credit card or prepaid card'
      AND (
          sub_product IS NULL
          OR LOWER(TRIM(sub_product)) = 'none'
          OR sub_product NOT IN (
              'General-purpose credit card or charge card',
              'General-purpose prepaid card',
              'Gift card',
              'Government benefit card',
              'Payroll card',
              'Store credit card',
              'Student prepaid card'
          )
      )

    UNION ALL

    SELECT
        'historical_credit_card_mapping',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE source_product = 'Credit card or prepaid card'
      AND sub_product IN (
          'General-purpose credit card or charge card',
          'Store credit card'
      )
      AND analytical_product IS DISTINCT FROM 'Credit card'

    UNION ALL

    SELECT
        'unexpected_product_sub_product_pair',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE source_product = 'Checking or savings account'
      AND sub_product = 'Credit reporting'


    -- Derived staging fields should remain consistent with the transformation
    -- rules implemented in 03_clean_staging.sql.
    UNION ALL

    SELECT
        'inconsistent_company_key',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE company_key <> LOWER(TRIM(company))

    UNION ALL

    SELECT
        'inconsistent_has_narrative',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE has_narrative IS NULL
       OR (
            has_narrative = TRUE
            AND NULLIF(TRIM(consumer_complaint_narrative), '') IS NULL
       )
       OR (
            has_narrative = FALSE
            AND NULLIF(TRIM(consumer_complaint_narrative), '') IS NOT NULL
       )


    -- Analytical scope is defined by date_received. date_sent_to_company is
    -- intentionally not constrained because later processing dates are valid.
    UNION ALL

    SELECT
        'date_received_outside_period',
        COUNT(*)::BIGINT,
        0::BIGINT,
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM stg_complaints
    WHERE date_received < DATE '2023-01-01'
       OR date_received >= DATE '2026-01-01'
)

SELECT *
FROM quality_checks
ORDER BY check_name;