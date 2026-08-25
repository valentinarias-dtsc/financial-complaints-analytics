-- 1. Dataset overview
SELECT 
    'Total complaints' AS inspection_name,
    COUNT(*)::text AS value
FROM mart_complaints

UNION ALL

SELECT
    'Temporal range',
    (
        TO_CHAR(MIN(date_received), 'YYYY/MM/DD')
        || ' - ' ||
        TO_CHAR(MAX(date_received), 'YYYY/MM/DD')
    )::text
FROM mart_complaints

UNION ALL

SELECT
    'Distinct products count',
    COUNT(DISTINCT analytical_product)::text
FROM mart_complaints

UNION ALL

SELECT
    'Distinct sub-products count',
    COUNT(DISTINCT(sub_product))::text
FROM mart_complaints

UNION ALL

SELECT
    'Distinct issues count',
    COUNT(DISTINCT(issue))::text
FROM mart_complaints

UNION ALL

SELECT
    'Distinct companies count',
    COUNT(DISTINCT(company_name))::text
FROM mart_complaints
ORDER BY 1
;


-- 2 Complaint volume over time
WITH monthly_complaints AS(
    SELECT
        dm.year_month,
        dm.year_month_sort,
        COUNT(*) AS complaints

    FROM mart_complaints mc
      LEFT JOIN dim_calendar dm
      ON mc.date_received = dm.date
    GROUP BY dm.year_month, dm.year_month_sort
)
SELECT
    year_month,
    complaints,
    LAG(complaints) OVER (ORDER BY year_month_sort) AS last_month_complaints,
    complaints - 
        LAG(complaints) OVER (ORDER BY year_month_sort) AS mom_change,
    ROUND((
        complaints::numeric
        / NULLIF(
            LAG(complaints) OVER (ORDER BY year_month_sort), 0
            ) - 1
        ) * 100, 
        2
    ) AS mom_growth_pct,
    LAG(complaints, 12) OVER (ORDER BY year_month_sort) AS last_year_complaints,
    complaints - 
        LAG(complaints, 12) OVER (ORDER BY year_month_sort) AS yoy_change,
    ROUND((
        complaints::numeric
        / NULLIF(
            LAG(complaints, 12) OVER (ORDER BY year_month_sort), 0
            ) - 1
        ) * 100, 
        2
    ) AS yoy_growth_pct 
FROM monthly_complaints
ORDER BY year_month_sort;


-- 3. Product analysis
WITH product_frequency AS (
    SELECT
        analytical_product,
        COUNT(*)::numeric AS frequency_abs
    FROM mart_complaints
    GROUP BY analytical_product
),
row_count AS (
    SELECT COUNT(*) AS total_rows
    FROM mart_complaints
)
SELECT
    analytical_product,
    frequency_abs,
    ROUND(100 * frequency_abs / rc.total_rows, 2) AS frequency_pct
FROM product_frequency
  CROSS JOIN row_count rc
ORDER BY frequency_pct DESC;

WITH monthly_product_frequency AS(
    SELECT
        dm.year_month,
        dm.year_month_sort,
        COUNT(*) AS total_complaints,
        COUNT(*) FILTER (
            WHERE analytical_product = 'Credit card'
        )::numeric AS credit_complaints,
        COUNT(*) FILTER (
            WHERE analytical_product = 'Checking or savings account'
        )::numeric AS bank_account_complaints,
        COUNT(*) FILTER (
            WHERE analytical_product = 'Money transfer, virtual currency, or money service'
        )::numeric AS virtual_account_complaints
    FROM mart_complaints mc
      LEFT JOIN dim_calendar dm
      ON mc.date_received = dm.date
    GROUP BY dm.year_month, dm.year_month_sort
)
SELECT
    year_month,
    total_complaints,
    credit_complaints,
    bank_account_complaints,
    virtual_account_complaints,
    ROUND(100 * credit_complaints / total_complaints, 2) AS credit_pct,
    ROUND(100 * bank_account_complaints / total_complaints, 2) AS bank_account_pct,
    ROUND(100 * virtual_account_complaints / total_complaints, 2) AS virtual_account_pct
FROM monthly_product_frequency
ORDER BY year_month_sort;

-- 4. Issue analysis
WITH row_count AS (
    SELECT
        COUNT(*) AS total_rows
    FROM mart_complaints
),
issues_complaints AS (
    SELECT
        issue,
        COUNT(*)::numeric AS frequency_abs
    FROM mart_complaints
    GROUP BY issue
)
SELECT
    issue,
    frequency_abs,
    ROUND((100 * frequency_abs / rc.total_rows), 2) AS frequency_pct,
    ROUND(SUM(100 * frequency_abs / rc.total_rows) OVER (ORDER BY frequency_abs DESC), 2) AS cummulative_pct
FROM issues_complaints
  CROSS JOIN row_count rc
ORDER BY frequency_pct DESC;

SELECT
    analytical_product,
    issue,
    COUNT(*) AS frequency_abs
FROM mart_complaints
GROUP BY analytical_product, issue
ORDER BY analytical_product DESC, frequency_abs DESC;