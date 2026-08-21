\set ON_ERROR_STOP on

-- Creates the raw table only on the first run. All columns are loaded as TEXT
-- to preserve the original values before cleaning or type conversion.
CREATE TABLE IF NOT EXISTS raw_complaints (
    date_received TEXT,
    product TEXT,
    sub_product TEXT,
    issue TEXT,
    sub_issue TEXT,
    consumer_complaint_narrative TEXT,
    company_public_response TEXT,
    company TEXT,
    state TEXT,
    zip_code TEXT,
    tags TEXT,
    submitted_via TEXT,
    date_sent_to_company TEXT,
    company_response_to_consumer TEXT,
    timely_response TEXT,
    complaint_id TEXT
);

-- The reload is atomic: if any \copy fails, ON_ERROR_STOP stops the script and
-- the transaction prevents the table from being left partially loaded.
BEGIN;

-- Removes existing rows without dropping the table or its dependencies.
TRUNCATE TABLE raw_complaints;

-- Each file represents a time partition validated by the download script.
-- UTF8 is used because it is the encoding of the generated CSV files.
\copy raw_complaints FROM 'data/raw/complaints_2023_h1.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy raw_complaints FROM 'data/raw/complaints_2023_h2.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy raw_complaints FROM 'data/raw/complaints_2024_h1.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy raw_complaints FROM 'data/raw/complaints_2024_h2.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy raw_complaints FROM 'data/raw/complaints_2025_01.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy raw_complaints FROM 'data/raw/complaints_2025_h1_feb_jun.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy raw_complaints FROM 'data/raw/complaints_2025_q3.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
\copy raw_complaints FROM 'data/raw/complaints_2025_q4.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COMMIT;

-- Final reconciliation check: both counts must match when each complaint_id
-- appears only once in the loaded data.
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT complaint_id) AS distinct_complaint_ids
FROM raw_complaints;
