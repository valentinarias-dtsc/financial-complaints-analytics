-- ============================================================================
-- 05_reporting_mart.sql
-- Purpose: create a simple reporting layer from validated staging data for
--          downstream business analysis and Power BI.
-- Scope:   retain reporting-relevant complaint fields and create a continuous
--          calendar dimension for the defined MVP analytical period.
-- Output:  mart_complaints and dim_calendar.
-- ============================================================================

\set ON_ERROR_STOP on


-- Recreate reporting tables so the script can be rerun safely.
DROP TABLE IF EXISTS mart_complaints;
DROP TABLE IF EXISTS dim_calendar;


-- ============================================================================
-- 1. COMPLAINT REPORTING MART
-- ============================================================================
-- Preserve the complaint-level grain while exposing only fields required for
-- planned KPIs, filters, and analytical breakdowns. Cleaning and taxonomy logic
-- remain centralized in stg_complaints and are not duplicated here.

CREATE TABLE mart_complaints AS
SELECT
    complaint_id,
    date_received,
    source_product,
    analytical_product,
    sub_product,
    issue,
    sub_issue,
    company_name,
    submitted_via,
    date_sent_to_company,
    company_response_to_consumer,
    timely_response,
    has_narrative,
    state
FROM stg_complaints;


-- ============================================================================
-- 2. CALENDAR DIMENSION
-- ============================================================================
-- Generate one row for every calendar date in the MVP analytical period,
-- including dates with no complaints, to support continuous time-series
-- analysis and reusable date attributes in Power BI.

CREATE TABLE dim_calendar AS
SELECT
    calendar_date::DATE AS date,
    EXTRACT(YEAR FROM calendar_date)::INT AS year,
    EXTRACT(MONTH FROM calendar_date)::INT AS month,
    TO_CHAR(calendar_date, 'FMMonth') AS month_name,
    EXTRACT(QUARTER FROM calendar_date)::INT AS quarter_number,
    'Q' || EXTRACT(QUARTER FROM calendar_date)::INT AS quarter_name,
    TO_CHAR(calendar_date, 'YYYY-MM') AS year_month,
    (
        EXTRACT(YEAR FROM calendar_date)::INT * 100
        + EXTRACT(MONTH FROM calendar_date)::INT
    ) AS year_month_sort
FROM GENERATE_SERIES(
    DATE '2023-01-01',
    DATE '2025-12-31',
    INTERVAL '1 day'
) AS dates(calendar_date);


-- ============================================================================
-- 3. REPORTING MART RECONCILIATION
-- ============================================================================
-- The complaint mart should preserve the validated staging population and its
-- one-row-per-complaint grain. The calendar should contain one unique row per
-- day across the complete three-year analytical period.

SELECT
    COUNT(*) AS mart_rows,
    COUNT(DISTINCT complaint_id) AS distinct_complaint_ids
FROM mart_complaints;

SELECT
    COUNT(*) AS calendar_rows,
    MIN(date) AS min_date,
    MAX(date) AS max_date
FROM dim_calendar;

SELECT
    date,
    COUNT(*) AS date_rows
FROM dim_calendar
GROUP BY date
HAVING COUNT(*) > 1;