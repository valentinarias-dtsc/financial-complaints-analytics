# Power BI Report

The Power BI report is the presentation layer of the Financial Complaints Analytics MVP. It consumes the validated PostgreSQL reporting layer and provides a compact view of complaint volume, response performance, product and issue concentration, and company-level patterns.

The report is intentionally simple. Data cleaning, taxonomy harmonization, exclusions, and quality validation remain in SQL; Power BI is used for the semantic model, reusable measures, filtering, and interactive reporting.

## Data Connection

The report connects directly to PostgreSQL in **Import** mode.

Imported tables:

- `mart_complaints`
- `dim_calendar`

No raw, staging, or audit tables are loaded into the semantic model.

Power Query is limited to connection, column selection, type verification, and minor presentation adjustments. Transformation logic is not duplicated from SQL.

## Semantic Model

The model uses a single active relationship:

```text
dim_calendar[date]  1 ───── *  mart_complaints[date_received]
```

Filtering flows from `dim_calendar` to `mart_complaints`.

`dim_calendar` is marked as the Date Table and provides the reporting attributes used for year and month filtering. `year_month` is sorted by `year_month_sort` to preserve chronological order.

Reusable measures are stored in the `_Measures` table.

## Measures

The final report uses the following measures:

```DAX
Total Complaints =
COUNTROWS(mart_complaints)
```

```DAX
Timely Complaints =
CALCULATE(
    [Total Complaints],
    mart_complaints[timely_response] = TRUE()
)
```

```DAX
Timely Response Rate =
IF(
    [Total Complaints] = 0,
    BLANK(),
    DIVIDE(
        [Timely Complaints],
        [Total Complaints],
        0
    )
)
```

```DAX
Complaints with Narrative =
CALCULATE(
    [Total Complaints],
    mart_complaints[has_narrative] = TRUE()
)
```

```DAX
Narrative Rate =
DIVIDE(
    [Complaints with Narrative],
    [Total Complaints],
    0
)
```

```DAX
Complaints Previous Year =
CALCULATE(
    [Total Complaints],
    SAMEPERIODLASTYEAR(dim_calendar[date])
)
```

```DAX
YoY Complaint Growth =
IF(
    HASONEVALUE(dim_calendar[year]),
    DIVIDE(
        [Total Complaints] - [Complaints Previous Year],
        [Complaints Previous Year]
    ),
    BLANK()
)
```

The YoY KPI is only returned when one year is selected. This avoids presenting an ambiguous comparison when multiple years are active.

## Page 1 — Executive Overview

The first page provides the headline view of the complaint portfolio.

It includes:

- `Year` slicer;
- `Product` slicer;
- Total Complaints;
- YoY Complaint Growth;
- Timely Response Rate;
- Narrative Rate;
- Monthly Complaint Volume;
- Complaint Volume by Product;
- Top 5 Leading Issues.

The page is intended for high-level monitoring of volume, trend, product mix, and issue concentration.

Year and Product slicers define the main filter context. Visual selections support additional exploration within the page.

## Page 2 — Company & Issue Analysis

The second page provides a more operational view of company, issue, sub-product, and response-category concentration.

It includes:

- `Year` slicer;
- `Product` slicer;
- Top 10 Companies by Complaint Volume;
- High-Volume Issues;
- High-Volume Sub Products;
- Volume by Company Response to Consumer.

The company visual is implemented as a table with:

- Company;
- Total Complaints;
- Timely Response Rate.

The Top 10 ranking is based on complaint volume. Timely response is shown as a contextual metric rather than as the ranking criterion.

The company table is treated as the main exploratory anchor for the page. It can interact with the other visuals, but the issue, sub-product, and response-category visuals do not filter the company table. This keeps the company ranking stable while still allowing broad exploration of the selected context.

The `Submitted Via` slicer was intentionally excluded from the final page because the source is strongly concentrated in Web submissions and the channel breakdown adds limited discrimination for this MVP.

## QA and Reconciliation

The `.pbix` includes a separate QA page used during development to reconcile Power BI measures with SQL results.

Checks include:

- total complaint counts;
- timely complaint counts and response rate;
- narrative counts and rate;
- annual totals;
- product totals;
- calendar filtering;
- YoY values under a single-year context.

The QA page is retained in the file but hidden from the final report.

Validated reference values include:

- Total Complaints: `522,381`;
- Timely Complaints: `518,681`;
- Timely Response Rate: `99.29%`;
- Complaints with Narrative: `302,021`;
- Narrative Rate: `57.82%`;
- 2023 complaints: `118,035`;
- 2024 complaints: `145,554`;
- 2025 complaints: `258,792`.

## Formatting Conventions

The report uses a **16:9** canvas.

Counts are displayed as whole numbers with thousands separators. Percentages use two decimal places.

Display units are set to `None` so Power BI does not automatically abbreviate values as thousands.

## Deferred Analysis

The report does not include a finalized `Fastest-Growing Issues` visual.

A sharp January 2025 concentration in:

`Money transfer, virtual currency, or money service` → `Other transaction problem`

materially affects 2025 growth comparisons. The signal is documented in `docs/business_analysis.md`, but a dedicated anomaly method is intentionally deferred beyond the MVP.

A future extension may add a third page focused on January 2025, product–issue growth, and potential concentration drivers.
