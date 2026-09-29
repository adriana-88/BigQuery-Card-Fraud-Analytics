# Card Transaction Fraud Analytics in BigQuery

A hands-on SQL and data-modeling project built in Google BigQuery using a subset of the
[Transactions Fraud Dataset](https://www.kaggle.com/datasets/computingvictor/transactions-fraud-datasets)
created by CaixaBank Tech for the 2024 AI Hackathon.

The project was developed as a practical way to learn and refresh BigQuery SQL, data quality,
analytical data modeling, validation, and fraud-oriented exploratory analysis.

It is not intended to represent a production fraud-detection system or a machine-learning model.

---

## Key findings

These findings describe the **fraud-enriched working sample**, not population fraud rates from the full Kaggle dataset.

- Fraud prevalence varies substantially over time in the working sample: the labeled fraud rate ranges from about **0.2% in 2011** to **12.5% in 2010**.
- Transaction-channel effects are not stable over time. Online transactions appear much more fraud-heavy in several years, but that pattern weakens or reverses in later periods.
- Several merchant categories are overrepresented among fraud-labeled purchases. **Electronics Stores** and **Precious Stones and Metals** show the highest aggregate fraud lift in the final comparison, although year-level results show that the strength and stability of these associations varies.

---

## Project overview

The original Kaggle dataset is large, so this project uses a deliberately reduced and fraud-enriched
working sample rather than the full transaction table.

The source contains **13,305,915 transactions** and **8,914,963 fraud labels**, including
**13,332 fraud-labeled transactions**. The preparation script keeps **all fraud-labeled rows** and
uniformly samples the remaining labeled-legitimate and unlabeled transactions at approximately
**2.16%**, using seed `42`, to target roughly 300,000 rows.

The realized working sample contains **299,381 transactions**.

The resulting BigQuery project contains approximately:

- **299,381 transactions**
- **2,000 users**
- **6,146 cards**
- **109 merchant category codes (MCCs)**
- **205,020 transactions with fraud labels**

The transaction data covers **January 2010 through October 2019**.

Because fraud labels are available for only part of the transaction population, unlabeled
transactions are kept explicitly as a separate state rather than being treated as legitimate.

Final transaction status therefore has three values:

- `Fraud`
- `Legit`
- `Unlabeled`

This distinction is used throughout the analysis.

---

## Data source

**Dataset:** Transactions Fraud Dataset  
**Creator:** CaixaBank Tech — 2024 AI Hackathon  
**License:** Apache 2.0

Source:

https://www.kaggle.com/datasets/computingvictor/transactions-fraud-datasets

The dataset combines:

- transaction records
- user/customer information
- payment-card information
- merchant category codes
- fraud labels

The source data is synthetic and is used here for learning and analytical exploration.

Only a subset of the original Kaggle data is used in this repository.

---

## Sampling design

The working transaction table is **not a simple random sample**.

The preprocessing script:

- keeps all **13,332 fraud-labeled transactions**
- samples every other transaction using the same random keep probability
- uses a fixed random seed of `42`
- targets approximately **300,000 transaction rows**
- writes fraud labels only for transactions retained in the working sample

This design intentionally enriches fraud cases so there are enough positive examples for SQL-based
exploration in BigQuery.

That enrichment changes the meaning of absolute rates:

- in the full source labels, fraud represents about **0.15% of labeled transactions**
- in the working sample, fraud represents about **6.5% of labeled transactions**
- across all working-sample rows, fraud represents about **4.45%**

Therefore, percentages and fraud-lift magnitudes in this repository should be interpreted as
**properties of the enriched working sample**, not as estimates of fraud prevalence in the full
dataset or in real banking data.

Because the same non-fraud sampling rule is applied across the transaction file, comparisons across
years, channels and merchant categories remain useful for exploratory relative analysis, but they are
not presented as population estimates.

The sampling logic is preserved in:

```text
prep/prepare_bigquery_data.py
```

---

## Project structure

The project follows a simplified Raw (Bronze) / Silver / Gold-style workflow inside one BigQuery dataset.

```text
Raw Kaggle data
      │
      ▼
 Raw (Bronze) tables
      │
      ▼
 Silver cleaning views
      │
      ▼
 Gold fact table and marts
      │
      ├── Aggregate tables
      │
      ├── Validation checks
      │
      └── Fraud analysis
```

Repository structure:

```text
prep/
└── prepare_bigquery_data.py

sql/
│
├── 01_cleaning/
│   ├── v_transactions_clean.sql
│   ├── v_users_clean.sql
│   ├── v_cards_clean.sql
│   ├── v_fraud_labels_clean.sql
│   └── v_mcc_codes_clean.sql
│
├── 02_modeling/
│   ├── fct_transactions.sql
│   ├── mart_user_summary.sql
│   ├── mart_transaction_behaviour.sql
│   └── mart_merchant_behavior.sql
│
├── 03_aggregates/
│   ├── agg_txn_daily.sql
│   ├── agg_txn_monthly.sql
│   ├── agg_txn_yearly.sql
│   ├── agg_txn_hourly.sql
│   ├── agg_txn_hour_year.sql
│   ├── agg_mcc_summary.sql
│   └── agg_mcc_yearly.sql
│
├── 04_validation/
│   ├── checks_transactions.sql
│   ├── checks_users.sql
│   ├── checks_cards.sql
│   ├── checks_referential_integrity.sql
│   ├── checks_gold_reconciliation.sql
│   ├── checks_gold_grain_and_invariants.sql
│   ├── checks_mart_transaction_behavior.sql
│   ├── checks_mart_merchant_behavior.sql
│   └── extra_validation.sql
│
└── 05_analysis/
    ├── exploratory_analysis.sql
    └── final_analysis.sql
```

---

# 1. Data cleaning

The raw Kaggle tables were loaded into BigQuery largely as string-based source fields.

The Silver views convert them into more useful analytical types while keeping the source-level
grain unchanged.

Examples include:

- transaction amounts converted from currency strings to `NUMERIC`
- transaction dates converted to timestamps
- user income, debt and credit attributes converted to numeric types
- card expiration and account-opening month/year fields converted to dates
- fraud labels converted to boolean values
- latitude and longitude converted to numeric coordinates
- customer coordinates converted into BigQuery `GEOGRAPHY` points

Defensive BigQuery functions such as `SAFE_CAST`, `SAFE.PARSE_DATE`, and `SAFE_DIVIDE`
are used where conversion or division could otherwise fail.

---

## ZIP-code repair

ZIP values had passed through a numeric representation before reaching the source table and
appeared in forms such as:

```text
10458.0
```

The cleaning layer converts the values back to integers and pads them to five digits where possible.

This prevents Northeast US ZIP codes with leading zeros from remaining incorrectly formatted.

---

## Transaction flags

The transaction cleaning view also derives several flags used later in analysis:

- `is_online`
- `has_error`
- `is_location_anomaly`
- `is_international`

Rather than automatically deleting unusual observations, anomalies are generally retained and
flagged so they can be investigated separately.

---

# 2. Gold analytical models

## `fct_transactions`

The central fact table has a grain of:

> **one row per transaction**

It joins transaction records with selected user, card, merchant-category, geography and fraud-label
attributes.

Sensitive card fields such as the full card number and CVV are not carried into the fact table.

Fraud status is represented as:

```text
Fraud
Legit
Unlabeled
```

rather than interpreting a missing fraud label as evidence that the transaction was legitimate.

---

## `mart_user_summary`

Grain:

> **one row per user**

The user mart combines customer attributes with behavioral summaries including:

- transaction counts
- positive purchase totals
- net transaction value
- refund counts
- fraud counts
- labeled-transaction counts
- labeled fraud rate
- label coverage
- first and last observed transaction
- number of merchants used
- most frequently used merchant

Users with no transaction activity are retained through a `LEFT JOIN`, with appropriate zero-filled
activity metrics.

---

## `mart_transaction_behavior`

Grain:

> **one row per transaction**

This mart was created while learning and applying BigQuery window functions to transaction history.

It adds historical card-level context such as:

- previous transaction
- previous positive-value transaction
- previous merchant
- previous physical merchant location
- previous transaction channel
- historical average positive transaction amount
- time since prior transaction
- merchant/channel/location change indicators
- days since account opening
- days until recorded card expiry

The associated validation script checks that historical timestamps do not point into future
transactions at the recorded timestamp resolution, and that first transactions on each card have
no prior-state values.

Because the source was sampled at the **transaction-row level**, these historical features describe
the sequence visible in the working sample, not each card's complete source history. They are useful
for practicing window-function and behavioral-feature logic, but should not be interpreted as
production-ready fraud-detector inputs.

---

## `mart_merchant_behavior`

Grain:

> **one row per card with purchase activity**

The mart identifies each card's most frequently used merchant and records:

- favorite merchant
- number of purchases at that merchant
- total purchases made by the card
- favorite-merchant share of purchases
- date of the most recent purchase at that merchant

Ties are resolved using the most recently used merchant and then merchant ID for deterministic
ordering.

Validation confirmed:

- **4,037 rows**
- **4,037 distinct cards**
- no merchant-share values outside `0–1`
- no favorite-merchant purchase count greater than total card purchases

---

# 3. Aggregate tables

Reusable aggregate tables were created at several analytical grains:

- day
- month
- year
- hour
- hour × year
- MCC
- MCC × year

The aggregate tables include metrics such as:

- total transactions
- labeled transactions
- fraud transactions
- fraud rate across all transactions
- fraud rate across labeled transactions
- label coverage
- purchase totals
- refund totals
- zero-dollar transactions

Two fraud-rate definitions are intentionally retained:

```text
fraud / all transactions
```

and

```text
fraud / labeled transactions
```

This avoids silently treating unlabeled transactions as legitimate.

---

# 4. Data quality and validation

Validation was performed throughout the project rather than only after the final tables were built.

Checks include:

### Source and structural checks

- source row counts
- primary-key duplication
- missing-value profiling
- numeric and date conversion failures
- transaction date ranges
- allowed categorical values

### Referential integrity

Relationships checked include:

- transactions → users
- transactions → cards
- transactions → MCC
- cards → users
- fraud labels → transactions

The audited subset contained no orphaned records in these relationships.

### Gold reconciliation

Gold tables are reconciled back to the transaction fact table.

Core anchor values are:

- **299,381 transactions**
- **13,332 fraud-labeled transactions**
- **191,688 legitimate-labeled transactions**
- **94,361 unlabeled transactions**
- **205,020 labeled transactions**
- approximately **68.5% label coverage**

Aggregate transaction, fraud and labeled counts were checked against these anchor values.

### Grain and arithmetic invariants

Additional checks verify that:

- fact-table transaction IDs remain unique
- user marts remain one row per user
- aggregate tables preserve their intended grain
- composite grains such as MCC × year and hour × year contain no duplicate combinations
- purchases + refunds + zero-dollar transactions reconcile to total transactions
- calculated rates remain between `0` and `1`

---

# 5. Cross-table investigations

Several anomalies found during validation were investigated rather than automatically removed.

These included:

- error patterns by transaction channel
- negative-value/refund behavior
- ZIP and state consistency
- transactions outside recorded card lifecycle dates
- transaction amounts exceeding stated credit limits

One example involved a positive transaction occurring one day after the card's recorded expiry month.

Reviewing the card history visible in the working sample showed a concentrated sequence of
fraud-labeled transactions in Rome around the same period. The row was therefore retained as an
anomalous fraud observation rather than automatically classified as a source-data error.

This investigation is exploratory and does not establish whether the scenario would be valid in a
real banking system.

---

# 6. Fraud analysis

The final analysis focuses on three questions.

All rates below are calculated on the **fraud-enriched working sample**. They are used for exploratory
comparison inside that sample and are not population fraud-rate estimates.

## 6.1 Does fraud prevalence change over time?

Yes — substantially within this synthetic dataset.

The labeled fraud rate varies considerably across years, while label coverage remains comparatively
stable at roughly 67–70%.

Examples include approximately:

- **2010: 12.5%**
- **2011: 0.2%**
- **2015: 9.9%**
- **2016: 11.0%**
- **2017: 0.8%**

The sampling procedure retains all fraud-labeled transactions while uniformly sampling the remaining
rows, so these percentages are intentionally enriched and should not be read as source-level annual
fraud rates.

The dataset is also synthetic, so the figures should not be interpreted as real-world historical fraud
rates. Instead, they show that **time is an important analytical dimension in the working sample**.

---

## 6.2 Is one transaction channel consistently more fraud-prone?

At the aggregate level, Online transactions appear to have a much higher labeled fraud rate than
Chip or Swipe transactions.

However, the year-level analysis shows that this relationship is highly unstable.

Online fraud prevalence is very high in several years but falls to zero or near zero in others.
Chip transactions only appear in this working subset from 2015 onward, and in 2018–2019 the
Chip fraud rate is higher than the Online rate.

The main conclusion is therefore not that one channel is universally more dangerous.

Instead:

> **Aggregate channel fraud rates can hide substantial temporal variation.**

Channel comparisons in this dataset should therefore be interpreted together with year.

---

## 6.3 Which merchant categories are overrepresented among fraud transactions?

For positive-value purchases, an MCC-level **fraud lift** was calculated as:

```text
share of fraud transactions
────────────────────────────
share of labeled transactions
```

A lift greater than `1` means that a merchant category represents a larger share of fraud than its
share of labeled purchase activity.

To reduce the influence of very small samples, the final comparison requires at least **250 labeled
purchase transactions** per MCC.

**Electronics Stores** and **Precious Stones and Metals** show the highest aggregate fraud lift
among categories meeting the minimum labeled-sample threshold. **Department Stores** and
**Family Clothing Stores** also show elevated fraud representation with larger supporting samples.

However, examining the same categories by year shows that the size of the effect varies
substantially over time. Some categories with extreme aggregate rates also have relatively small
annual samples.

The result is therefore treated as an exploratory association rather than evidence that a merchant
category is inherently fraudulent.

---

# Key analytical lesson

A recurring theme in this project was that a plausible headline metric often required another level
of investigation.

Examples include:

```text
High overall Online fraud rate
        ↓
Check Online fraud by year
        ↓
Relationship is not stable over time
```

and:

```text
Very high MCC fraud rate
        ↓
Check number of labeled observations
        ↓
Check MCC × year
        ↓
Effect varies substantially by period
```

The project therefore emphasizes denominator choice, sample size, temporal context, and validation
before interpreting aggregate results.

---

# Limitations

This project has several important limitations.

1. **The working table is a designed, fraud-enriched sample.**  
   All 13,332 fraud-labeled source transactions were retained, while labeled-legitimate and unlabeled
   transactions were uniformly sampled at approximately 2.16% using seed 42. Absolute fraud rates,
   fraud-lift magnitudes and card-history features are therefore properties of the working sample and
   should not be treated as full-source estimates.

2. **The source data is synthetic.**  
   Patterns should not be interpreted as real banking fraud behavior or historical fraud prevalence.

3. **Fraud labels are incomplete.**  
   The source labels file does not cover every transaction. In the working sample, approximately
   68.5% of transactions have a fraud label. Unlabeled transactions are retained separately rather
   than classified as legitimate.

4. **2019 is incomplete.**  
   The observed transaction data ends in October 2019.

5. **The project is analytical, not predictive.**  
   No machine-learning fraud classifier was built, and no claim is made that the SQL-derived
   patterns would predict fraud in new transactions.

6. **Historical customer attributes are limited by the source data.**  
   Some user information represents a snapshot rather than a complete time-varying customer history.

7. **This is a learning project.**  
   The repository documents practical work completed while learning and refreshing SQL,
   BigQuery, data modeling, validation, and analytical reasoning. It should not be interpreted
   as production banking infrastructure.

---

# How to run

1. Download the Kaggle source files.
2. Run `prep/prepare_bigquery_data.py` to create:
   - `transactions_sample.csv`
   - `fraud_labels_sample.csv`
   - `mcc_codes.csv`
3. Upload those files plus `users_data.csv` and `cards_data.csv` to BigQuery as raw tables in the
   `card_transactions` dataset. The project deliberately loads source fields as strings and performs
   type conversion in the cleaning layer.
4. Run `01_cleaning`.
5. Run `02_modeling`, with `fct_transactions.sql` first and
   `mart_transaction_behavior.sql` before `mart_merchant_behavior.sql`.
6. Run `03_aggregates`.
7. Run the checks in `04_validation`.
8. Run `05_analysis`.
9. Compare the Gold-layer totals with the documented anchor values.

---

# Tools and SQL concepts used

- Python / pandas for source preparation and sampling
- Google BigQuery
- Standard SQL
- CTEs
- joins
- conditional aggregation
- window functions
- `LAG`
- `LAST_VALUE ... IGNORE NULLS`
- `ROW_NUMBER`
- `SAFE_CAST`
- `SAFE.PARSE_DATE`
- `SAFE_DIVIDE`
- `COUNTIF`
- `DATE_DIFF`
- `TIMESTAMP_DIFF`
- regular expressions
- BigQuery `GEOGRAPHY`
- data-quality checks
- referential-integrity checks
- reconciliation tests
- analytical marts
- temporal and categorical fraud analysis

---

# Project status

The source-preparation, SQL warehouse, validation, and exploratory fraud-analysis phases are
**complete for the current project scope**.

Possible future extensions could include visualization or statistical modeling, but they are not
required for the current project scope.
