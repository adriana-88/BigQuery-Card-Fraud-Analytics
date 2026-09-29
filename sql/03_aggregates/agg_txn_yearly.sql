
CREATE OR REPLACE TABLE card_transactions.agg_yearly_summary AS

SELECT
    DATE_TRUNC(DATE(txn_date), YEAR) AS year,
    COUNT(*) AS total_transactions,
    COUNTIF(fraud_status = 'Fraud') AS number_of_frauds_this_year,
    COUNTIF(fraud_status != 'Unlabeled') AS total_labeled,

    SAFE_DIVIDE(
        COUNTIF(fraud_status = 'Fraud'),
        COUNT(*)
    ) AS fraud_rate_all_transactions,

    SAFE_DIVIDE(
        COUNTIF(fraud_status = 'Fraud'),
        COUNTIF(fraud_status != 'Unlabeled')
    ) AS fraud_rate_labeled,

    SAFE_DIVIDE(
        COUNTIF(fraud_status != 'Unlabeled'),
        COUNT(*)
    ) AS label_coverage_rate,

    SUM(amount) AS total_amount_net,
    SUM(CASE WHEN amount > 0 THEN amount END) AS positive_amount,
    SUM(CASE WHEN amount < 0 THEN amount END) AS negative_amount,

    COUNTIF(amount < 0) AS total_refunds,
    COUNTIF(amount > 0) AS total_purchases,

    COUNTIF(
        fraud_status = 'Fraud'
        AND amount < 0
    ) AS total_refund_frauds,

    SAFE_DIVIDE(
        COUNTIF(fraud_status = 'Fraud' AND amount < 0),
        COUNTIF(fraud_status = 'Fraud')
    ) AS refund_rate_fraud,

    COUNTIF(
        amount = 0
        AND fraud_status = 'Fraud'
    ) AS fraud_zero_dollars,

    COUNTIF(amount = 0) AS total_transactions_with_zero

FROM `card_transactions.fct_transactions`

GROUP BY year;