# KPI Dictionary

This dictionary defines the measures and recurring breakdowns used in the Power BI report. Unless noted otherwise, all metrics respond to the active report filters, including Year, Product, and visual cross-filtering.

## Total Complaints

| Attribute | Definition |
|---|---|
| Business definition | Number of validated, in-scope published complaints in the current filter context |
| Numerator | Rows in `mart_complaints` |
| Denominator | Not applicable |
| DAX | `Total Complaints = COUNTROWS(mart_complaints)` |
| SQL reconciliation | `SELECT COUNT(*) FROM mart_complaints;` plus equivalent `WHERE` predicates for the selected context |
| Interpretation | Measures complaint volume, not complaint rate or company quality |
| Published global value | 522,381 |

`complaint_id` is unique in the validated mart, so row count and distinct complaint count reconcile in the published run.

## Monthly Complaint Volume

| Attribute | Definition |
|---|---|
| Business definition | Total complaints grouped by calendar month of `date_received` |
| Numerator | `[Total Complaints]` evaluated for each `dim_calendar[year_month]` |
| Denominator | Not applicable |
| DAX | Uses `[Total Complaints]`; no separate measure is required |
| SQL reconciliation | `SELECT DATE_TRUNC('month', date_received), COUNT(*) FROM mart_complaints GROUP BY 1 ORDER BY 1;` |
| Interpretation | Shows timing and concentration of received complaints |
| Caveat | January 2025 contains an unresolved concentration and should not be treated as ordinary trend growth |

In Power BI, `year_month` is sorted by `year_month_sort`.

## Complaints Previous Year

| Attribute | Definition |
|---|---|
| Business definition | Complaint volume for the same calendar period one year earlier |
| Numerator | `[Total Complaints]` shifted back one year through `dim_calendar` |
| Denominator | Not applicable |
| DAX | `Complaints Previous Year = CALCULATE([Total Complaints], SAMEPERIODLASTYEAR(dim_calendar[date]))` |
| SQL reconciliation | Compare the selected year's count with `COUNT(*)` for the equivalent prior-year date interval |
| Interpretation | Supporting measure for YoY growth; not displayed as a headline KPI |

## YoY Complaint Growth

| Attribute | Definition |
|---|---|
| Business definition | Percentage change in complaint volume from the equivalent prior-year period |
| Numerator | `[Total Complaints] - [Complaints Previous Year]` |
| Denominator | `[Complaints Previous Year]` |
| Filter context | Returned only when exactly one calendar year is selected |
| SQL reconciliation | `(current_year_count - prior_year_count) / prior_year_count`, using the same product and categorical filters |
| Interpretation | Positive values indicate higher observed complaint volume than the prior year |
| Caveat | Descriptive, not causal; sensitive to taxonomy, reporting behavior, and the January 2025 concentration |

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

Published annual checks: 2024 = 23.31%; 2025 = 77.80%.

## Timely Complaints

| Attribute | Definition |
|---|---|
| Business definition | Complaints recorded by the CFPB as having received a timely company response |
| Numerator | Mart rows where `timely_response = TRUE` |
| Denominator | Not applicable |
| DAX | `Timely Complaints = CALCULATE([Total Complaints], mart_complaints[timely_response] = TRUE())` |
| SQL reconciliation | `SELECT COUNT(*) FROM mart_complaints WHERE timely_response IS TRUE;` |
| Published global value | 518,681 |

## Timely Response Rate

| Attribute | Definition |
|---|---|
| Business definition | Share of complaints recorded as having received a timely company response |
| Numerator | `[Timely Complaints]` |
| Denominator | `[Total Complaints]` |
| Filter context | All active filters; returns blank when the context contains no complaints |
| SQL reconciliation | `(COUNT(*) FILTER (WHERE timely_response IS TRUE))::numeric / NULLIF(COUNT(*), 0)` in the same context |
| Interpretation | Measures response timing, not resolution quality or consumer satisfaction |
| Published global value | 99.29% |

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

## Complaints with Narrative

| Attribute | Definition |
|---|---|
| Business definition | Complaints for which a non-empty consumer narrative is available |
| Numerator | Mart rows where `has_narrative = TRUE` |
| Denominator | Not applicable |
| DAX | `Complaints with Narrative = CALCULATE([Total Complaints], mart_complaints[has_narrative] = TRUE())` |
| SQL reconciliation | `SELECT COUNT(*) FROM mart_complaints WHERE has_narrative IS TRUE;` |
| Published global value | 302,021 |

## Narrative Rate

| Attribute | Definition |
|---|---|
| Business definition | Share of complaints with an available consumer narrative |
| Numerator | `[Complaints with Narrative]` |
| Denominator | `[Total Complaints]` |
| Filter context | All active filters |
| SQL reconciliation | `(COUNT(*) FILTER (WHERE has_narrative IS TRUE))::numeric / NULLIF(COUNT(*), 0)` in the same context |
| Interpretation | Measures text availability only; it does not establish content quality or representativeness |
| Published global value | 57.82% |

```DAX
Narrative Rate =
DIVIDE(
    [Complaints with Narrative],
    [Total Complaints],
    0
)
```

## Complaint Distribution Breakdowns

Product, issue, sub-product, company, and company-response visuals reuse `[Total Complaints]` under a categorical filter context rather than defining separate count measures.

| Breakdown | Category | Ranking rule | Interpretation caveat |
|---|---|---|---|
| Product volume | `analytical_product` | All three families | Mix within the selected scope, not the complete CFPB universe |
| Leading issues | `issue` | Top 5 by `[Total Complaints]` | Top N recalculates under slicers and intended cross-filters |
| Company volume | `company_name` | Top 10 by `[Total Complaints]` | Volume is not exposure-adjusted and must not be read as a quality ranking |
| High-volume sub-products | `sub_product` | Top categories by `[Total Complaints]` | Taxonomy is source-defined and may evolve |
| Company response distribution | `company_response_to_consumer` | All response categories | Categories do not measure consumer satisfaction |

For a share-of-context reconciliation in SQL, divide each grouped count by the window total calculated under the same non-category filters. The dashboard displays counts for these breakdowns; shares reported in the narrative analysis are supporting descriptive results.

## Formatting and Validation

- Counts use whole numbers with thousands separators and no automatic `K` or `M` abbreviation.
- Rates use percentage format with two decimal places.
- The hidden QA page reconciles global totals, annual totals, product totals, calendar behavior, and single-year YoY results.
- Reference annual totals are 118,035 for 2023, 145,554 for 2024, and 258,792 for 2025.
