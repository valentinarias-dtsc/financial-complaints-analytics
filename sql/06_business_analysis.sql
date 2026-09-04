-- ============================================================================
-- 06_business_analysis.sql
-- Purpose: answer the main business questions using the reporting layer.
-- Scope:   descriptive analysis only; cleaning and staging logic remain upstream.
-- Sources: mart_complaints and dim_calendar.
-- ============================================================================

\set ON_ERROR_STOP on


-- 1. Dataset overview
SELECT
    COUNT(*) AS total_complaints,
    MIN(date_received) AS first_date_received,
    MAX(date_received) AS last_date_received,
    COUNT(DISTINCT analytical_product) AS products,
    COUNT(DISTINCT sub_product) AS sub_products,
    COUNT(DISTINCT issue) AS issues,
    COUNT(DISTINCT company_name) AS companies
FROM mart_complaints;


-- 2. Complaint volume over time
-- Calendar months preserve the complete reporting timeline, including months
-- with no complaints.
WITH monthly_complaints AS (
    SELECT
        dc.year_month,
        dc.year_month_sort,
        COUNT(mc.complaint_id) AS complaints
    FROM dim_calendar AS dc
    LEFT JOIN mart_complaints AS mc
        ON dc.date = mc.date_received
    GROUP BY
        dc.year_month,
        dc.year_month_sort
),
monthly_comparisons AS (
    SELECT
        year_month,
        year_month_sort,
        complaints,
        LAG(complaints) OVER (
            ORDER BY year_month_sort
        ) AS previous_month_complaints,
        LAG(complaints, 12) OVER (
            ORDER BY year_month_sort
        ) AS previous_year_complaints
    FROM monthly_complaints
)
SELECT
    year_month,
    complaints,
    previous_month_complaints,
    complaints - previous_month_complaints AS mom_change,
    ROUND(
        100.0 * (complaints - previous_month_complaints)
        / NULLIF(previous_month_complaints, 0),
        2
    ) AS mom_growth_pct,
    previous_year_complaints,
    complaints - previous_year_complaints AS yoy_change,
    ROUND(
        100.0 * (complaints - previous_year_complaints)
        / NULLIF(previous_year_complaints, 0),
        2
    ) AS yoy_growth_pct
FROM monthly_comparisons
ORDER BY year_month_sort;


-- 3. Product analysis
WITH product_complaints AS (
    SELECT
        analytical_product,
        COUNT(*) AS complaints
    FROM mart_complaints
    GROUP BY analytical_product
)
SELECT
    analytical_product,
    complaints,
    ROUND(
        100.0 * complaints / SUM(complaints) OVER (),
        2
    ) AS complaint_share_pct
FROM product_complaints
ORDER BY
    complaints DESC,
    analytical_product;

WITH monthly_product_complaints AS (
    SELECT
        dc.year_month,
        dc.year_month_sort,
        mc.analytical_product,
        COUNT(*) AS complaints
    FROM mart_complaints AS mc
    INNER JOIN dim_calendar AS dc
        ON mc.date_received = dc.date
    GROUP BY
        dc.year_month,
        dc.year_month_sort,
        mc.analytical_product
)
SELECT
    year_month,
    analytical_product,
    complaints,
    ROUND(
        100.0 * complaints
        / SUM(complaints) OVER (PARTITION BY year_month_sort),
        2
    ) AS monthly_product_share_pct
FROM monthly_product_complaints
ORDER BY
    year_month_sort,
    complaints DESC,
    analytical_product;


-- 4. Issue analysis
WITH issue_complaints AS (
    SELECT
        issue,
        COUNT(*) AS complaints
    FROM mart_complaints
    GROUP BY issue
)
SELECT
    issue,
    complaints,
    ROUND(
        100.0 * complaints / SUM(complaints) OVER (),
        2
    ) AS complaint_share_pct
FROM issue_complaints
ORDER BY
    complaints DESC,
    issue;


-- 5. Product-issue concentration
-- The percentage denominator is all complaints within the same product.
WITH product_issue_complaints AS (
    SELECT
        analytical_product,
        issue,
        COUNT(*) AS complaints
    FROM mart_complaints
    GROUP BY
        analytical_product,
        issue
)
SELECT
    analytical_product,
    issue,
    complaints,
    ROUND(
        100.0 * complaints
        / SUM(complaints) OVER (PARTITION BY analytical_product),
        2
    ) AS issue_share_within_product_pct
FROM product_issue_complaints
ORDER BY
    analytical_product,
    complaints DESC,
    issue;


-- 6. Growth analysis
-- Compare the two complete and consecutive years available in the mart.
-- A minimum of 100 complaints in 2024 avoids percentage-growth rankings driven
-- by insignificant bases while keeping the rule simple to explain.
WITH product_issue_yearly_complaints AS (
    SELECT
        mc.analytical_product,
        mc.issue,
        dc.year,
        COUNT(*) AS complaints
    FROM mart_complaints AS mc
    INNER JOIN dim_calendar AS dc
        ON mc.date_received = dc.date
    WHERE dc.year IN (2024, 2025)
    GROUP BY
        mc.analytical_product,
        mc.issue,
        dc.year
),
product_issue_growth AS (
    SELECT
        analytical_product,
        issue,
        COALESCE(
            SUM(complaints) FILTER (WHERE year = 2024),
            0
        ) AS complaints_2024,
        COALESCE(
            SUM(complaints) FILTER (WHERE year = 2025),
            0
        ) AS complaints_2025
    FROM product_issue_yearly_complaints
    GROUP BY
        analytical_product,
        issue
)
SELECT
    analytical_product,
    issue,
    complaints_2024,
    complaints_2025,
    complaints_2025 - complaints_2024 AS complaint_change,
    ROUND(
        100.0 * (complaints_2025 - complaints_2024)
        / NULLIF(complaints_2024, 0),
        2
    ) AS growth_pct
FROM product_issue_growth
WHERE complaints_2024 >= 100
ORDER BY
    complaint_change DESC,
    growth_pct DESC,
    analytical_product,
    issue;


-- 7. Timely response analysis
-- The denominator is all complaints in each result group. The validated mart
-- has no null timely_response values.
SELECT
    COUNT(*) AS total_complaints,
    COUNT(*) FILTER (WHERE timely_response) AS timely_responses,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE timely_response) / COUNT(*),
        2
    ) AS timely_response_rate_pct
FROM mart_complaints;

SELECT
    analytical_product,
    COUNT(*) AS complaints,
    COUNT(*) FILTER (WHERE timely_response) AS timely_responses,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE timely_response) / COUNT(*),
        2
    ) AS timely_response_rate_pct
FROM mart_complaints
GROUP BY analytical_product
ORDER BY
    timely_response_rate_pct DESC,
    analytical_product;

-- The submission-channel timely response breakdown is combined with channel
-- volume and share in section 10 to avoid a duplicate query.


-- 8. Company analysis
-- Complaint volume is descriptive only. Without customer, account, or
-- transaction denominators, it is not a general ranking of company quality.
SELECT
    company_name,
    COUNT(*) AS complaints
FROM mart_complaints
GROUP BY company_name
ORDER BY
    complaints DESC,
    company_name;

-- Use at least 100 complaints for a more stable comparison of response rates.
SELECT
    company_name,
    COUNT(*) AS complaints,
    COUNT(*) FILTER (WHERE timely_response) AS timely_responses,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE timely_response) / COUNT(*),
        2
    ) AS timely_response_rate_pct
FROM mart_complaints
GROUP BY company_name
HAVING COUNT(*) >= 100
ORDER BY
    timely_response_rate_pct DESC,
    complaints DESC,
    company_name;


-- 9. Company response category analysis
WITH response_category_complaints AS (
    SELECT
        company_response_to_consumer,
        COUNT(*) AS complaints
    FROM mart_complaints
    GROUP BY company_response_to_consumer
)
SELECT
    company_response_to_consumer,
    complaints,
    ROUND(
        100.0 * complaints / SUM(complaints) OVER (),
        2
    ) AS complaint_share_pct
FROM response_category_complaints
ORDER BY
    complaints DESC,
    company_response_to_consumer;


-- 10. Submission channel analysis
WITH channel_complaints AS (
    SELECT
        submitted_via,
        COUNT(*) AS complaints,
        COUNT(*) FILTER (WHERE timely_response) AS timely_responses
    FROM mart_complaints
    GROUP BY submitted_via
)
SELECT
    submitted_via,
    complaints,
    ROUND(
        100.0 * complaints / SUM(complaints) OVER (),
        2
    ) AS complaint_share_pct,
    timely_responses,
    ROUND(
        100.0 * timely_responses / NULLIF(complaints, 0),
        2
    ) AS timely_response_rate_pct
FROM channel_complaints
ORDER BY
    complaints DESC,
    submitted_via;


-- 11. Narrative availability
-- This measures whether a narrative is available, not its content or quality.
SELECT
    COUNT(*) AS total_complaints,
    COUNT(*) FILTER (WHERE has_narrative) AS complaints_with_narrative,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE has_narrative) / COUNT(*),
        2
    ) AS narrative_availability_rate_pct
FROM mart_complaints;

SELECT
    analytical_product,
    COUNT(*) AS complaints,
    COUNT(*) FILTER (WHERE has_narrative) AS complaints_with_narrative,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE has_narrative) / COUNT(*),
        2
    ) AS narrative_availability_rate_pct
FROM mart_complaints
GROUP BY analytical_product
ORDER BY
    narrative_availability_rate_pct DESC,
    analytical_product;


-- 12. DEFERRED JANUARY 2025 CONCENTRATION ANALYSIS
-- January 2025 contains an extraordinary concentration for:
--
--   Money transfer, virtual currency, or money service
--   Other transaction problem
--
-- This signal is documented as a post-MVP research direction. No executable
-- query is included because the project does not yet define or validate a
-- method for classifying the observation as an anomaly or assigning a cause.
