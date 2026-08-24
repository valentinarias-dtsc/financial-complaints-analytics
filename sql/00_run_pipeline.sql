-- ============================================================================
-- 00_run_pipeline.sql
-- Purpose: run the implemented SQL pipeline in dependency order.
-- Run with: psql -d <database_name> -f sql/00_run_pipeline.sql
-- ============================================================================

\set ON_ERROR_STOP on
\pset pager off

\ir 01_load_raw_data.sql
\ir 02_data_audit.sql
\ir 03_clean_staging.sql
\ir 04_quality_checks.sql
\ir 05_reporting_mart.sql
