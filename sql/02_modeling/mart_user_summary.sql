CREATE OR REPLACE TABLE `card_transactions.mart_user_summary` AS

WITH aggr_fct AS (

    SELECT
        client_id,

        -- Transaction activity
        COUNT(*) AS number_of_transactions,

        SUM(amount) AS total_net_spent,

        SUM(
            CASE
                WHEN amount > 0 THEN amount
            END
        ) AS total_amount_spent,

        MAX(
            CASE
                WHEN amount > 0 THEN amount
            END
        ) AS max_amount_spent,

        MIN(
            CASE
                WHEN amount > 0 THEN amount
            END
        ) AS min_amount_spent,

        -- Refund activity
        COUNTIF(amount < 0) AS number_of_refunds,

        MAX(
            CASE
                WHEN amount < 0 THEN ABS(amount)
            END
        ) AS max_refund_amount,

        -- Fraud / label information
        COUNTIF(fraud_status = 'Fraud') AS total_frauds,

        COUNTIF(fraud_status != 'Unlabeled') AS total_labeled,

        SAFE_DIVIDE(
            COUNTIF(fraud_status = 'Fraud'),
            COUNTIF(fraud_status != 'Unlabeled')
        ) AS fraud_rate_labeled,

        SAFE_DIVIDE(
            COUNTIF(fraud_status != 'Unlabeled'),
            COUNT(*)
        ) AS label_coverage_rate,

        COUNTIF(
            amount < 0
            AND fraud_status = 'Fraud'
        ) AS total_refund_frauds,

        -- Customer transaction history
        MIN(txn_date) AS first_transaction,
        MAX(txn_date) AS last_transaction,

        COUNT(DISTINCT merchant_id) AS total_merchants,

        APPROX_TOP_COUNT(
            merchant_id,
            1
        )[OFFSET(0)].value AS favorite_merchant,

        APPROX_TOP_COUNT(
            merchant_id,
            1
        )[OFFSET(0)].count AS favorite_merchant_count

    FROM `card_transactions.fct_transactions`

    GROUP BY client_id
)

SELECT
    -- Customer attributes
    u.id,
    u.current_age,
    u.retirement_age,
    u.birth_year,
    u.birth_month,
    u.gender,
    u.address,
    u.latitude,
    u.longitude,
    u.per_capita_income,
    u.yearly_income,
    u.total_debt,
    u.credit_score,
    u.num_credit_cards,
    u.home_geo,

    -- Customer activity
    COALESCE(a.number_of_transactions, 0)
        AS number_of_transactions,

    COALESCE(a.total_amount_spent, 0)
        AS total_amount_spent,

    COALESCE(a.total_net_spent, 0)
        AS total_net_spent,

    a.max_amount_spent,
    a.min_amount_spent,

    COALESCE(a.number_of_refunds, 0)
        AS number_of_refunds,

    a.max_refund_amount,

    -- Fraud / label information
    COALESCE(a.total_frauds, 0)
        AS total_frauds,

    COALESCE(a.total_labeled, 0)
        AS total_labeled,

    a.fraud_rate_labeled,
    a.label_coverage_rate,

    COALESCE(a.total_refund_frauds, 0)
        AS total_refund_frauds,

    -- Transaction history
    a.first_transaction,
    a.last_transaction,

    COALESCE(a.total_merchants, 0)
        AS total_merchants,

    a.favorite_merchant,
    a.favorite_merchant_count

FROM `card_transactions.v_users_clean` AS u

LEFT JOIN aggr_fct AS a
    ON u.id = a.client_id;