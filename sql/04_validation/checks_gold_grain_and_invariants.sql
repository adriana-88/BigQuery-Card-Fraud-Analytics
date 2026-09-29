-- one row per unique aggregated field.

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT id) AS unique_ids
FROM `card_transactions.fct_transactions`;

SELECT  COUNT(*) AS total_rows,
        COUNT(DISTINCT id) AS unique_ids
FROM card_transactions.mart_user_summary;
  
SELECT COUNT(*) as total_rows,
       COUNT(DISTINCT day) as unique_days
FROM card_transactions.agg_txn_daily;

SELECT COUNT(*) as total_rows,
       COUNT(DISTINCT month) as unique_year_months
FROM card_transactions.agg_txn_monthly;

SELECT COUNT(*) as total_rows,
       COUNT(DISTINCT year) as unique_year
FROM card_transactions.agg_yearly_summary;

SELECT COUNT(*) as total_rows,
       COUNT(DISTINCT hour) as unique_hour
FROM card_transactions.agg_hourly_summary;

WITH grain_check AS (
    SELECT
        year,
        hour,
        COUNT(*) AS copies
    FROM `card_transactions.agg_hourly_yearly_summary`
    GROUP BY year, hour
)
SELECT
    SUM(copies) AS total_rows,
    COUNT(*) AS unique_year_hour_combinations,
    COUNTIF(copies > 1) AS duplicate_grain_combinations
FROM grain_check;

SELECT COUNT(*) as total_rows,
       COUNT(DISTINCT mcc) as unique_mcc
FROM card_transactions.agg_mcc_summary;


WITH grain_check AS (
    SELECT
        year,
        mcc,
        COUNT(*) AS copies
    FROM `card_transactions.agg_mcc_yearly_summary`
    GROUP BY year, mcc
)
SELECT
    SUM(copies) AS total_rows,
    COUNT(*) AS unique_mcc_year_combinations,
    COUNTIF(copies > 1) AS duplicate_grain_combinations
FROM grain_check;

--arithmetic invariants

SELECT sum((total_purchases + total_refunds + total_transactions_with_zero)) as calculated_total_transactions,
        sum(total_transactions) as totals
FROM card_transactions.agg_mcc_yearly_summary;

SELECT (total_purchases + total_refunds + total_transactions_with_zero) as calculated_total_transactions,
        total_transactions as totals
FROM card_transactions.agg_mcc_yearly_summary
WHERE (total_purchases + total_refunds + total_transactions_with_zero) != total_transactions;


SELECT sum((total_purchases + total_refunds + total_transactions_with_zero)) as calculated_total_transactions,
        sum(total_transactions) as totals
FROM card_transactions.agg_mcc_summary;

SELECT (total_purchases + total_refunds + total_transactions_with_zero) as calculated_total_transactions,
        total_transactions as totals
FROM card_transactions.agg_mcc_summary
WHERE (total_purchases + total_refunds + total_transactions_with_zero) != total_transactions;

SELECT sum((total_purchases + total_refunds + total_transactions_with_zero)) as calculated_total_transactions,
        sum(total_transactions) as totals
FROM card_transactions.agg_hourly_yearly_summary;

SELECT (total_purchases + total_refunds + total_transactions_with_zero) as calculated_total_transactions,
        total_transactions as totals
FROM card_transactions.agg_hourly_yearly_summary
WHERE (total_purchases + total_refunds + total_transactions_with_zero) != total_transactions;

SELECT sum((total_purchases + total_refunds + total_transactions_with_zero)) as calculated_total_transactions,
        sum(total_transactions) as totals
FROM card_transactions.agg_hourly_summary;

SELECT (total_purchases + total_refunds + total_transactions_with_zero) as calculated_total_transactions,
        total_transactions as totals
FROM card_transactions.agg_hourly_summary
WHERE (total_purchases + total_refunds + total_transactions_with_zero) != total_transactions;

SELECT sum((total_purchases + total_refunds + total_transactions_with_zero)) as calculated_total_transactions,
        sum(total_transactions) as totals
FROM card_transactions.agg_yearly_summary;

SELECT (total_purchases + total_refunds + total_transactions_with_zero) as calculated_total_transactions,
        total_transactions as totals
FROM card_transactions.agg_yearly_summary
WHERE (total_purchases + total_refunds + total_transactions_with_zero) != total_transactions;

SELECT sum((total_purchases + total_refunds + total_transactions_with_zero)) as calculated_total_transactions,
        sum(total_transactions) as totals
FROM card_transactions.agg_txn_monthly;

SELECT (total_purchases + total_refunds + total_transactions_with_zero) as calculated_total_transactions,
        total_transactions as totals
FROM card_transactions.agg_txn_monthly
WHERE (total_purchases + total_refunds + total_transactions_with_zero) != total_transactions;

SELECT sum((total_purchases + total_refunds + total_transactions_with_zero)) as calculated_total_transactions,
        sum(total_transactions) as totals
FROM card_transactions.agg_txn_daily;

SELECT (total_purchases + total_refunds + total_transactions_with_zero) as calculated_total_transactions,
        total_transactions as totals
FROM card_transactions.agg_txn_daily
WHERE (total_purchases + total_refunds + total_transactions_with_zero) != total_transactions;


SELECT
    'agg_txn_daily' AS table_name,
    COUNTIF(
        fraud_rate_all_transactions NOT BETWEEN 0 AND 1
        OR fraud_rate_labeled NOT BETWEEN 0 AND 1
        OR label_coverage_rate NOT BETWEEN 0 AND 1
    ) AS invalid_rate_rows
FROM `card_transactions.agg_txn_daily`

UNION ALL

SELECT
    'agg_txn_monthly',
    COUNTIF(
        fraud_rate_all_transactions NOT BETWEEN 0 AND 1
        OR fraud_rate_labeled NOT BETWEEN 0 AND 1
        OR label_coverage_rate NOT BETWEEN 0 AND 1
    )
FROM `card_transactions.agg_txn_monthly`

UNION ALL

SELECT
    'agg_yearly_summary',
    COUNTIF(
        fraud_rate_all_transactions NOT BETWEEN 0 AND 1
        OR fraud_rate_labeled NOT BETWEEN 0 AND 1
        OR label_coverage_rate NOT BETWEEN 0 AND 1
    )
FROM `card_transactions.agg_yearly_summary`

UNION ALL

SELECT
    'agg_hourly_summary',
    COUNTIF(
        fraud_rate_all_transactions NOT BETWEEN 0 AND 1
        OR fraud_rate_labeled NOT BETWEEN 0 AND 1
        OR label_coverage_rate NOT BETWEEN 0 AND 1
    )
FROM `card_transactions.agg_hourly_summary`

UNION ALL

SELECT
    'agg_hourly_yearly_summary',
    COUNTIF(
        fraud_rate_all_transactions NOT BETWEEN 0 AND 1
        OR fraud_rate_labeled NOT BETWEEN 0 AND 1
        OR label_coverage_rate NOT BETWEEN 0 AND 1
    )
FROM `card_transactions.agg_hourly_yearly_summary`

UNION ALL

SELECT
    'agg_mcc_summary',
    COUNTIF(
        fraud_rate_all_transactions NOT BETWEEN 0 AND 1
        OR fraud_rate_labeled NOT BETWEEN 0 AND 1
        OR label_coverage_rate NOT BETWEEN 0 AND 1
    )
FROM `card_transactions.agg_mcc_summary`

UNION ALL

SELECT
    'agg_mcc_yearly_summary',
    COUNTIF(
        fraud_rate_all_transactions NOT BETWEEN 0 AND 1
        OR fraud_rate_labeled NOT BETWEEN 0 AND 1
        OR label_coverage_rate NOT BETWEEN 0 AND 1
    )
FROM `card_transactions.agg_mcc_yearly_summary`;






