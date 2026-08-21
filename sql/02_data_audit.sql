SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT(complaint_id)) unique_ids
FROM raw_complaints;

WITH missing_counts AS (

    SELECT
        'complaint_id' AS column_name,
        COUNT(*) FILTER (
            WHERE complaint_id IS NULL
        ) AS missing_count
    FROM raw_complaints

    UNION ALL

    SELECT
        'date_received',
        COUNT(*) FILTER (
            WHERE date_received IS NULL
               OR TRIM(date_received) = ''
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'product',
        COUNT(*) FILTER (
            WHERE product IS NULL
               OR TRIM(product) = ''
               OR LOWER(TRIM(product)) = 'none'
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'sub_product',
        COUNT(*) FILTER (
            WHERE sub_product IS NULL
               OR TRIM(sub_product) = ''
               OR LOWER(TRIM(sub_product)) = 'none'
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'issue',
        COUNT(*) FILTER (
            WHERE issue IS NULL
               OR TRIM(issue) = ''
               OR LOWER(TRIM(issue)) = 'none'
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'sub_issue',
        COUNT(*) FILTER (
            WHERE sub_issue IS NULL
               OR TRIM(sub_issue) = ''
               OR LOWER(TRIM(sub_issue)) = ''
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'consumer_complaint_narrative',
        COUNT(*) FILTER (
            WHERE consumer_complaint_narrative IS NULL
               OR TRIM(consumer_complaint_narrative) = ''
               OR LOWER(TRIM(consumer_complaint_narrative)) = 'none'
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'company',
        COUNT(*) FILTER (
            WHERE company IS NULL
               OR TRIM(company) = ''
               OR LOWER(TRIM(company)) = 'none'
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'timely_response',
        COUNT(*) FILTER (
            WHERE timely_response IS NULL
               OR TRIM(timely_response) = ''
               OR LOWER(TRIM(timely_response)) = 'none'
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'submitted_via',
        COUNT(*) FILTER (
            WHERE submitted_via IS NULL
               OR TRIM(submitted_via) = ''
               OR LOWER(TRIM(submitted_via)) = 'none'
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'state',
        COUNT(*) FILTER (
            WHERE state IS NULL
               OR TRIM(state) = ''
               OR LOWER(TRIM(state)) = 'none'
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'company_response_to_consumer',
        COUNT(*) FILTER (
            WHERE company_response_to_consumer IS NULL
               OR TRIM(company_response_to_consumer) = ''
               OR LOWER(TRIM(company_response_to_consumer)) = 'none'
        )
    FROM raw_complaints

    UNION ALL

    SELECT
        'company_public_response',
        COUNT(*) FILTER (
            WHERE company_public_response IS NULL
               OR TRIM(company_public_response) = ''
               OR LOWER(TRIM(company_public_response)) = 'none'
        )
    FROM raw_complaints

),

total_rows AS (
    SELECT COUNT(*) AS total
    FROM raw_complaints
)

SELECT
    mc.column_name,
    mc.missing_count,
    ROUND(
        100.0 * mc.missing_count / tr.total,
        2
    ) AS missing_pct
FROM missing_counts mc
CROSS JOIN total_rows tr
ORDER BY missing_pct DESC, missing_count DESC;


SELECT
    MIN(date_received::date) AS min_received_date,
    MAX(date_received::date) AS max_received_date,
    COUNT(*) FILTER (
        WHERE date_received::date NOT BETWEEN DATE '2023-01-01'
                                         AND DATE '2025-12-31'
    ) AS received_out_of_range
FROM raw_complaints;

SELECT
    MIN(date_sent_to_company::date) AS min_sent_date,
    MAX(date_sent_to_company::date) AS max_sent_date,
    COUNT(*) FILTER (
        WHERE date_sent_to_company::date NOT BETWEEN DATE '2023-01-01'
                                         AND DATE '2025-12-31'
    ) AS sent_out_of_range
FROM raw_complaints;


WITH cardinalities AS (
    SELECT
        'product' AS column_name,
        COUNT(DISTINCT(product)) AS cardinality,
        COUNT(DISTINCT(LOWER(TRIM(product)))) as cardinality_norm
    FROM raw_complaints

    UNION ALL

    SELECT
        'sub_product' AS column_name,
        COUNT(DISTINCT(sub_product)) AS cardinality,
        COUNT(DISTINCT(LOWER(TRIM(sub_product)))) as cardinality_norm
    FROM raw_complaints

    UNION ALL

    SELECT
        'issue' AS column_name,
        COUNT(DISTINCT(issue)) AS cardinality,
        COUNT(DISTINCT(LOWER(TRIM(issue)))) as cardinality_norm
    FROM raw_complaints

    UNION ALL

    SELECT
        'state' AS column_name,
        COUNT(DISTINCT(state)) AS cardinality,
        COUNT(DISTINCT(LOWER(TRIM(state)))) as cardinality_norm
    FROM raw_complaints

    UNION ALL

    SELECT
        'company' AS column_name,
        COUNT(DISTINCT(company)) AS cardinality,
        COUNT(DISTINCT(LOWER(TRIM(company)))) as cardinality_norm
    FROM raw_complaints

    UNION ALL

    SELECT
        'company_response_to_consumer' AS column_name,
        COUNT(DISTINCT(company_response_to_consumer)) AS cardinality,
        COUNT(DISTINCT(LOWER(TRIM(company_response_to_consumer)))) as cardinality_norm
    FROM raw_complaints
)

SELECT 
    column_name,
    cardinality,
    cardinality_norm,
    CASE 
        WHEN cardinality = cardinality_norm THEN 1
        ELSE 0
    END AS equal
FROM cardinalities
ORDER BY equal;


SELECT 
    DISTINCT timely_response
FROM raw_complaints;

SELECT 
    DISTINCT submitted_via
FROM raw_complaints;


SELECT 
    product,
    COUNT(*) AS frequency
FROM raw_complaints
GROUP BY product;

SELECT
    product,
    sub_product,
    COUNT(*) as frequency
FROM raw_complaints
GROUP BY product, sub_product;


SELECT
    DATE_TRUNC('month', date_received::date) AS month,
    product,
    COUNT(*)
FROM raw_complaints
WHERE product IN ('Credit card or prepaid card', 'Credit card')
GROUP BY month, product
ORDER BY month, product;