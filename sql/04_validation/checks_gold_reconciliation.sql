-- checks_gold_reconciliation.sql
--
-- Post-build validation of the Gold layer.
--
-- Confirms that:
--   - fct_transactions reconciles to the audited transaction/fraud counts
--   - mart_user_summary reconciles back to the transaction fact
--   - aggregate tables preserve transaction and fraud totals
--   - fraud-label coverage reconciles across Gold models
--   - zero-dollar fraud observations remain consistent
--
-- Anchor values established during source profiling:
--   - 299,381 transactions
--   - 13,332 fraud-labeled transactions
--
-- Queries are intended to be run individually.


-- ============================================================
-- FACT TABLE RECONCILIATION
-- ============================================================

-- Core transaction / fraud counts in the Gold fact.
SELECT
    COUNT(*) AS total_transactions,
    COUNTIF(fraud_status = 'Fraud') AS total_fraud_transactions,
    COUNTIF(fraud_status = 'Legit') AS total_legit_transactions,
    COUNTIF(fraud_status = 'Unlabeled') AS total_unlabeled_transactions,
    COUNTIF(fraud_status != 'Unlabeled') AS total_labeled_transactions

FROM `card_transactions.fct_transactions`;


-- Fraud-status domain check.
SELECT
    fraud_status,
    COUNT(*) AS transaction_count

FROM `card_transactions.fct_transactions`

GROUP BY fraud_status

ORDER BY fraud_status;


-- Unexpected Gold fraud-status values.
SELECT
    COUNT(*) AS unexpected_fraud_status_values

FROM `card_transactions.fct_transactions`

WHERE fraud_status IS NULL
   OR fraud_status NOT IN ('Fraud', 'Legit', 'Unlabeled');


-- ============================================================
-- USER MART RECONCILIATION
-- ============================================================

-- User-level transaction and fraud totals should reconcile
-- back to the transaction fact.
SELECT
    SUM(number_of_transactions) AS user_mart_transactions,
    SUM(total_frauds) AS user_mart_frauds,
    SUM(total_labeled) AS user_mart_labeled_transactions

FROM `card_transactions.mart_user_summary`;


-- Direct fact values for comparison with mart_user_summary.
SELECT
    COUNT(*) AS fact_transactions,
    COUNTIF(fraud_status = 'Fraud') AS fact_frauds,
    COUNTIF(fraud_status != 'Unlabeled') AS fact_labeled_transactions

FROM `card_transactions.fct_transactions`;


-- ============================================================
-- DAILY AGGREGATE RECONCILIATION
-- ============================================================

-- Daily aggregate should reconcile to fact-table transaction,
-- fraud and labeled-transaction totals.
SELECT
    SUM(total_transactions) AS daily_total_transactions,
    SUM(number_of_frauds_this_day) AS daily_total_frauds,
    SUM(total_labeled) AS daily_total_labeled

FROM `card_transactions.agg_txn_daily`;


-- ============================================================
-- MONTHLY AGGREGATE RECONCILIATION
-- ============================================================

SELECT
    SUM(total_transactions) AS monthly_total_transactions,
    SUM(number_of_frauds_this_month) AS monthly_total_frauds,
    SUM(total_labeled) AS monthly_total_labeled

FROM `card_transactions.agg_txn_monthly`;


-- ============================================================
-- YEARLY AGGREGATE RECONCILIATION
-- ============================================================

SELECT
    SUM(total_transactions) AS yearly_total_transactions,
    SUM(number_of_frauds_this_year) AS yearly_total_frauds,
    SUM(total_labeled) AS yearly_total_labeled

FROM `card_transactions.agg_yearly_summary`;


-- ============================================================
-- HOURLY AGGREGATE RECONCILIATION
-- ============================================================

-- Because every transaction belongs to exactly one source-recorded
-- hour, the pooled hourly table should reconcile to fact totals.
SELECT
    SUM(total_transactions) AS hourly_total_transactions,
    SUM(number_of_frauds_this_hour) AS hourly_total_frauds,
    SUM(total_labeled) AS hourly_total_labeled

FROM `card_transactions.agg_hourly_summary`;


-- ============================================================
-- HOUR × YEAR AGGREGATE RECONCILIATION
-- ============================================================

SELECT
    SUM(total_transactions) AS hourly_yearly_total_transactions,
    SUM(number_of_frauds_this_hour_year) AS hourly_yearly_total_frauds,
    SUM(total_labeled) AS hourly_yearly_total_labeled

FROM `card_transactions.agg_hourly_yearly_summary`;


-- ============================================================
-- MCC AGGREGATE RECONCILIATION
-- ============================================================

-- Each transaction has one MCC, so the all-period MCC summary
-- should reconcile to fact totals.
SELECT
    SUM(total_transactions) AS mcc_total_transactions,
    SUM(number_of_frauds_this_mcc) AS mcc_total_frauds,
    SUM(total_labeled) AS mcc_total_labeled

FROM `card_transactions.agg_mcc_summary`;


-- ============================================================
-- MCC × YEAR AGGREGATE RECONCILIATION
-- ============================================================

SELECT
    SUM(total_transactions) AS mcc_yearly_total_transactions,
    SUM(number_of_frauds_this_mcc_year) AS mcc_yearly_total_frauds,
    SUM(total_labeled) AS mcc_yearly_total_labeled

FROM `card_transactions.agg_mcc_yearly_summary`;


-- ============================================================
-- RATE IDENTITY CHECKS
-- ============================================================

-- By construction:
--
-- fraud_rate_all_transactions
-- =
-- fraud_rate_labeled * label_coverage_rate
--
-- Differences should be zero apart from floating-point precision.
SELECT
    year,

    fraud_rate_all_transactions,

    fraud_rate_labeled
        * label_coverage_rate
        AS reconstructed_fraud_rate_all,

    fraud_rate_all_transactions
        - (
            fraud_rate_labeled
            * label_coverage_rate
          )
        AS difference

FROM `card_transactions.agg_yearly_summary`

ORDER BY year;


-- Flag material violations of the rate identity.
SELECT
    COUNT(*) AS yearly_rate_identity_failures

FROM `card_transactions.agg_yearly_summary`

WHERE ABS(
    fraud_rate_all_transactions
    - (
        fraud_rate_labeled
        * label_coverage_rate
      )
) > 0.000000001;


-- ============================================================
-- ZERO-DOLLAR FRAUD RECONCILIATION
-- ============================================================

-- Total zero-dollar fraud transactions from the fact table.
SELECT
    COUNT(*) AS total_zero_dollar_frauds

FROM `card_transactions.fct_transactions`

WHERE amount = 0
  AND fraud_status = 'Fraud';


-- Reconcile the same value through the daily aggregate.
SELECT
    SUM(fraud_zero_dollars) AS daily_zero_dollar_frauds

FROM `card_transactions.agg_txn_daily`;


-- Inspect the individual zero-dollar fraud transactions.
SELECT
    id,
    client_id,
    card_id,
    merchant_id,
    txn_date,
    use_chip,
    merchant_city,
    merchant_state,
    mcc,
    fraud_status

FROM `card_transactions.fct_transactions`

WHERE amount = 0
  AND fraud_status = 'Fraud'

ORDER BY txn_date;