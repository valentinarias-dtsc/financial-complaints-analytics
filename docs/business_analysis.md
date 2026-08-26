# Business Analysis

This report summarizes the business-analysis results produced from `mart_complaints` and `dim_calendar` after the full SQL pipeline was rerun. The analysis is descriptive: it identifies volume, concentration, growth, and response patterns without attributing causes or treating complaint counts as exposure-adjusted performance measures.

## 1. Executive Summary

The reporting mart contains 522,381 unique complaints received from 2023-01-01 through 2025-12-31. Complaint volume increased from 118,035 in 2023 to 145,554 in 2024 and 258,792 in 2025. The 2025 increase is heavily influenced by an exceptional January, which recorded 77,183 complaints and accounted for 29.82% of the year's volume.

Three findings define the current portfolio:

- `Credit card` is the largest product overall, with 220,381 complaints and a 42.19% share.
- `Managing an account` is the largest issue, with 103,749 complaints and a 19.86% share.
- `Money transfer, virtual currency, or money service` combined with `Other transaction problem` rose from 3,007 complaints in 2024 to 53,893 in 2025. This combination requires a dedicated anomaly investigation before the increase is interpreted.

Response performance is consistently high: 518,681 complaints received a timely response, equivalent to 99.29% of the mart. Narratives are available for 302,021 complaints, or 57.82%, with the highest availability in money-transfer complaints.

## 2. Dataset Overview

The mart preserves one row per validated complaint and uses `date_received` to define the analytical period.

| Metric | Result |
|---|---:|
| Total complaints | 522,381 |
| First date received | 2023-01-01 |
| Last date received | 2025-12-31 |
| Analytical products | 3 |
| Sub-products | 17 |
| Issues | 38 |
| Companies | 1,261 |

The product scope is intentionally limited to credit cards, checking or savings accounts, and money-transfer or virtual-currency services. It should not be generalized to the complete CFPB complaint universe.

## 3. Complaint Volume Over Time

### Annual volume

| Year | Complaints | Annual change |
|---:|---:|---:|
| 2023 | 118,035 | — |
| 2024 | 145,554 | +23.31% |
| 2025 | 258,792 | +77.80% |

Volume increased in both annual comparisons. In 2024, January was the only month below its 2023 counterpart; the remaining months recorded positive year-over-year growth. Every month of 2025 exceeded the corresponding month of 2024.

The annual result nevertheless hides an exceptional monthly pattern:

| Month | Complaints | MoM change | MoM growth | YoY change | YoY growth |
|---|---:|---:|---:|---:|---:|
| 2024-12 | 13,226 | +540 | +4.26% | +3,397 | +34.56% |
| 2025-01 | 77,183 | +63,957 | +483.57% | +66,618 | +630.55% |
| 2025-02 | 17,793 | -59,390 | -76.95% | +7,472 | +72.40% |
| 2025-12 | 18,701 | +3,161 | +20.34% | +5,475 | +41.40% |

January 2025 alone represents 29.82% of all complaints received in 2025. February fell sharply from that peak but remained well above February 2024. The rest of 2025 generally returned to a range of approximately 14,000 to 19,000 complaints per month.

The January observation should not be treated as ordinary trend growth until its source, classification, and timing are investigated.

## 4. Product Analysis

| Analytical product | Complaints | Share |
|---|---:|---:|
| Credit card | 220,381 | 42.19% |
| Checking or savings account | 186,881 | 35.77% |
| Money transfer, virtual currency, or money service | 115,119 | 22.04% |

`Credit card` is the largest product across the complete period. The yearly composition, however, changed materially in 2025:

| Product | 2024 complaints | 2024 share | 2025 complaints | 2025 share |
|---|---:|---:|---:|---:|
| Credit card | 75,989 | 52.21% | 89,979 | 34.77% |
| Checking or savings account | 52,814 | 36.28% | 84,194 | 32.53% |
| Money transfer, virtual currency, or money service | 16,751 | 11.51% | 84,619 | 32.70% |

All three products increased in absolute volume. Credit-card complaints grew by 18.41%, despite losing share because other products grew faster. Checking or savings complaints grew by 59.42%. Money-transfer complaints grew by 405.15% and nearly matched the other two product families in 2025; the January anomaly is an important contributor to this change.

## 5. Issue Analysis

| Issue | Complaints | Share |
|---|---:|---:|
| Managing an account | 103,749 | 19.86% |
| Other transaction problem | 59,059 | 11.31% |
| Problem with a purchase shown on your statement | 47,088 | 9.01% |
| Incorrect information on your report | 29,620 | 5.67% |
| Getting a credit card | 28,396 | 5.44% |
| Problem with a company's investigation into an existing problem | 24,430 | 4.68% |
| Closing an account | 24,375 | 4.67% |
| Fraud or scam | 22,747 | 4.35% |
| Problem with a lender or other company charging your account | 22,081 | 4.23% |
| Other features, terms, or problems | 21,484 | 4.11% |

The five leading issues account for 51.29% of the mart, showing that a relatively small group explains more than half of all complaints. `Managing an account` is the clear global leader, while `Other transaction problem` is strongly associated with the money-transfer product and its 2025 increase.

## 6. Product-Issue Concentration

### Checking or savings account

| Issue | Complaints | Share within product |
|---|---:|---:|
| Managing an account | 103,749 | 55.52% |
| Closing an account | 24,375 | 13.04% |
| Problem with a lender or other company charging your account | 22,081 | 11.82% |
| Problem caused by your funds being low | 18,776 | 10.05% |
| Opening an account | 16,692 | 8.93% |

`Managing an account` accounts for more than half of the product. The five displayed issues cover the complete issue mix for this analytical product after rounding.

### Credit card

| Issue | Complaints | Share within product |
|---|---:|---:|
| Problem with a purchase shown on your statement | 47,088 | 21.37% |
| Incorrect information on your report | 29,139 | 13.22% |
| Getting a credit card | 28,396 | 12.88% |
| Problem with a company's investigation into an existing problem | 24,118 | 10.94% |
| Other features, terms, or problems | 21,484 | 9.75% |

Credit-card complaints are more dispersed: no issue exceeds 22%, and the five leading issues account for 68.16% of the product.

### Money transfer, virtual currency, or money service

| Issue | Complaints | Share within product |
|---|---:|---:|
| Other transaction problem | 59,059 | 51.30% |
| Fraud or scam | 22,747 | 19.76% |
| Unauthorized transactions or other transaction problem | 8,850 | 7.69% |
| Money was not available when promised | 5,126 | 4.45% |
| Trouble accessing funds in a mobile or digital wallet | 4,844 | 4.21% |

The first two issues account for 71.06% of this product. `Other transaction problem` alone represents more than half, making it the most important category for follow-up.

## 7. Growth Analysis: 2025 Versus 2024

The growth query requires at least 100 complaints in 2024. This rule reduces rankings driven by negligible bases while retaining categories with meaningful prior-period activity.

### Largest absolute increases

| Product and issue | 2024 | 2025 | Change | Growth |
|---|---:|---:|---:|---:|
| Money transfer — Other transaction problem | 3,007 | 53,893 | +50,886 | +1,692.25% |
| Checking — Managing an account | 30,197 | 44,959 | +14,762 | +48.89% |
| Checking — Problem caused by funds being low | 3,530 | 11,939 | +8,409 | +238.22% |
| Credit card — Purchase shown on statement | 14,595 | 19,810 | +5,215 | +35.73% |
| Money transfer — Fraud or scam | 6,173 | 11,179 | +5,006 | +81.10% |
| Money transfer — Unauthorized transactions | 1,660 | 5,758 | +4,098 | +246.87% |

The leading combination contributed approximately 44.94% of the total 113,238-complaint increase between 2024 and 2025. It dominates both absolute and percentage rankings.

### Other large percentage increases

| Product and issue | 2024 | 2025 | Growth |
|---|---:|---:|---:|
| Money transfer — Confusing or missing disclosures | 360 | 1,970 | +447.22% |
| Money transfer — Other service problem | 545 | 2,064 | +278.72% |
| Money transfer — Unauthorized transactions | 1,660 | 5,758 | +246.87% |
| Checking — Problem caused by funds being low | 3,530 | 11,939 | +238.22% |
| Money transfer — Wrong amount charged or received | 182 | 459 | +152.20% |
| Money transfer — Mobile-wallet account management | 758 | 1,773 | +133.91% |

These results identify where activity grew; they do not establish why it grew. In particular, the comparison should be interpreted alongside the January 2025 concentration.

## 8. Timely Response Analysis

| Metric | Result |
|---|---:|
| Total complaints | 522,381 |
| Timely responses | 518,681 |
| Non-timely responses | 3,700 |
| Timely response rate | 99.29% |

| Product | Complaints | Timely responses | Timely response rate |
|---|---:|---:|---:|
| Credit card | 220,381 | 219,720 | 99.70% |
| Checking or savings account | 186,881 | 185,508 | 99.27% |
| Money transfer, virtual currency, or money service | 115,119 | 113,453 | 98.55% |

Response performance is high across every product. Money-transfer complaints have the lowest rate and the largest number of non-timely responses, at 1,666, compared with 1,373 for checking or savings and 661 for credit cards.

## 9. Company Analysis

### Highest complaint volume

| Company | Complaints | Share of mart | Timely response rate |
|---|---:|---:|---:|
| Block, Inc. | 52,403 | 10.03% | 98.53% |
| JPMORGAN CHASE & CO. | 42,397 | 8.12% | 100.00% |
| CAPITAL ONE FINANCIAL CORPORATION | 35,690 | 6.83% | 99.99% |
| WELLS FARGO & COMPANY | 35,513 | 6.80% | 99.99% |
| BANK OF AMERICA, NATIONAL ASSOCIATION | 31,980 | 6.12% | 98.13% |
| CITIBANK, N.A. | 29,697 | 5.68% | 100.00% |
| Early Warning Services, LLC | 22,027 | 4.22% | 99.99% |
| EQUIFAX, INC. | 19,040 | 3.64% | 100.00% |
| NAVY FEDERAL CREDIT UNION | 18,185 | 3.48% | 100.00% |
| TRANSUNION INTERMEDIATE HOLDINGS, INC. | 17,794 | 3.41% | 100.00% |

The ten largest companies account for 58.33% of complaint volume. This concentration can guide operational investigation but cannot establish comparative company quality.

Only 140 of the 1,261 companies meet the 100-complaint threshold used for timely-response comparisons. Among those companies, selected low observed rates include:

| Company | Complaints | Timely response rate |
|---|---:|---:|
| Novo Platform Inc. | 117 | 27.35% |
| Sigue Corp. | 229 | 58.08% |
| Relay Financial (US), Corp. | 174 | 67.82% |
| Conduent Incorporated | 102 | 75.49% |
| Chime Inc. | 216 | 81.48% |
| Ria Envia, LLC | 163 | 82.21% |
| Google Compare Credit Cards Inc. | 372 | 84.41% |
| ROBINHOOD MARKETS INC. | 3,067 | 88.82% |

The CFPB dataset does not provide customer, account, or transaction denominators. Higher complaint volume does not necessarily mean worse performance, and timely-response rates do not measure resolution quality or consumer satisfaction. Company results are descriptive signals for prioritization, not a general quality ranking.

## 10. Company Response Categories

| Company response to consumer | Complaints | Share |
|---|---:|---:|
| Closed with explanation | 400,574 | 76.68% |
| Closed with non-monetary relief | 63,053 | 12.07% |
| Closed with monetary relief | 58,344 | 11.17% |
| Untimely response | 406 | 0.08% |
| In progress | 4 | 0.00% |

`Closed with explanation` is the dominant response category. Monetary and non-monetary relief together represent 23.24% of complaints. These labels describe the company response recorded by the CFPB; they are not direct measures of consumer satisfaction.

## 11. Submission Channel Analysis

| Channel | Complaints | Share | Timely responses | Timely response rate |
|---|---:|---:|---:|---:|
| Web | 476,031 | 91.13% | 472,620 | 99.28% |
| Phone | 22,778 | 4.36% | 22,599 | 99.21% |
| Referral | 19,673 | 3.77% | 19,582 | 99.54% |
| Postal mail | 3,899 | 0.75% | 3,880 | 99.51% |

Web is the dominant intake channel. Timely-response rates vary by only 0.33 percentage points between the lowest and highest channels, so the available results do not indicate a large operational response gap by submission method.

## 12. Narrative Availability

| Metric | Result |
|---|---:|
| Total complaints | 522,381 |
| Complaints with narrative | 302,021 |
| Narrative availability rate | 57.82% |

| Product | Complaints with narrative | Availability rate |
|---|---:|---:|
| Money transfer, virtual currency, or money service | 83,560 | 72.59% |
| Checking or savings account | 108,949 | 58.30% |
| Credit card | 109,512 | 49.69% |

Money-transfer complaints provide the strongest narrative coverage and would offer the broadest basis for a future text-analysis project. Availability measures only whether text exists; it does not assess content quality, representativeness, or sentiment. NLP remains outside the current MVP.

## 13. Pending Product-Issue Anomaly Investigation

The most important unresolved signal is:

`Money transfer, virtual currency, or money service` → `Other transaction problem`

This combination recorded 42,521 complaints in January 2025, equal to 55.09% of that month's total and 78.90% of the combination's 53,893 complaints during 2025. Before 2025, its monthly share was generally between approximately 1.5% and 2.4%.

The observation supports further investigation but not a final anomaly conclusion. The next phase must define:

- the historical reference period and baseline;
- expected and excess complaint calculations;
- absolute volume change versus relative share change;
- minimum-volume requirements;
- whether company or submission-channel concentration explains part of the signal;
- whether source timing, backlog, classification, or another data-process factor may be involved.

No causal explanation is assigned in this report, and the anomaly section in `sql/06_business_analysis.sql` remains deliberately pending.

## 14. Limitations

- The extraction covers selected product families and is not the complete CFPB complaint population.
- Complaint counts are not adjusted for customers, accounts, transactions, or market share.
- A complaint is an observed report, not a confirmed service failure or causal outcome.
- Timely response measures response timing, not resolution quality or consumer satisfaction.
- Company labels use the audited reporting label but do not implement advanced entity resolution.
- Narrative availability is not equivalent to representative or analysis-ready text.
- The exceptional January 2025 volume materially affects annual and growth comparisons.

## 15. Reproducibility and Result Artifacts

The findings were generated after running the complete SQL pipeline and then executing `sql/06_business_analysis.sql` against PostgreSQL. The pipeline reconciled 525,156 raw rows to 522,381 validated mart rows after 2,775 documented exclusions; all 18 staging quality checks passed.

Complete query outputs are stored locally as 15 CSV files under `private/business_analysis_results/`. The directory is excluded by `.gitignore` because the exports are provisional analytical artifacts. Section 12 has no final result table because its methodology remains intentionally unresolved.
