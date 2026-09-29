-- =========================================================
-- Gold Mart: mart_transaction_behavior
-- Grain: one row per transaction
-- =========================================================

CREATE OR REPLACE TABLE `card_transactions.mart_transaction_behavior` AS

WITH sequenced_transactions AS (

    SELECT
        id,
        client_id,
        card_id,

        -- -------------------------------------------------
        -- Transaction channel history
        -- -------------------------------------------------
        use_chip,

        LAG(use_chip) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
        ) AS previous_use_chip,

        LAST_VALUE(
            CASE
                WHEN amount > 0 THEN use_chip
                ELSE NULL
            END
            IGNORE NULLS
        ) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS previous_positive_use_chip,

        -- -------------------------------------------------
        -- Merchant history
        -- -------------------------------------------------
        merchant_id,

        LAG(merchant_id) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
        ) AS previous_merchant_id,

        LAST_VALUE(
            CASE
                WHEN amount > 0 THEN merchant_id
                ELSE NULL
            END
            IGNORE NULLS
        ) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS previous_positive_merchant_id,

        -- -------------------------------------------------
        -- Merchant location history
        -- -------------------------------------------------
        merchant_city,

        LAG(merchant_city) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
        ) AS previous_merchant_city,

        (
            LAST_VALUE(
                CASE
                    WHEN amount > 0
                        THEN STRUCT(merchant_city AS value)
                    ELSE NULL
                END
                IGNORE NULLS
            ) OVER (
                PARTITION BY card_id
                ORDER BY txn_date, id
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            )
        ).value AS previous_positive_merchant_city,

        merchant_state,

        LAG(merchant_state) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
        ) AS previous_merchant_state,

        (
            LAST_VALUE(
                CASE
                    WHEN amount > 0
                        THEN STRUCT(merchant_state AS value)
                    ELSE NULL
                END
                IGNORE NULLS
            ) OVER (
                PARTITION BY card_id
                ORDER BY txn_date, id
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            )
        ).value AS previous_positive_merchant_state,

        (
            LAST_VALUE(
                CASE
                    WHEN amount > 0
                         AND merchant_city != 'ONLINE'
                        THEN STRUCT(merchant_state AS value)
                    ELSE NULL
                END
                IGNORE NULLS
            ) OVER (
                PARTITION BY card_id
                ORDER BY txn_date, id
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            )
        ).value AS previous_positive_physical_merchant_state,

        (
            LAST_VALUE(
                CASE
                    WHEN amount > 0
                         AND merchant_city != 'ONLINE'
                        THEN STRUCT(merchant_city AS value)
                    ELSE NULL
                END
                IGNORE NULLS
            ) OVER (
                PARTITION BY card_id
                ORDER BY txn_date, id
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            )
        ).value AS previous_positive_physical_merchant_city,

        -- -------------------------------------------------
        -- Transaction attributes
        -- -------------------------------------------------
        mcc,
        fraud_status,
        is_international,

        LAG(is_international) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
        ) AS previous_is_international,

        LAST_VALUE(
            CASE
                WHEN amount > 0 THEN is_international
                ELSE NULL
            END
            IGNORE NULLS
        ) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS previous_positive_is_international,

        -- -------------------------------------------------
        -- Transaction sequence
        -- -------------------------------------------------
        ROW_NUMBER() OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
        ) AS card_transaction_number,

        txn_date,

        LAG(txn_date) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
        ) AS previous_transaction_date,

        LAST_VALUE(
            CASE
                WHEN amount > 0
                     AND merchant_city != 'ONLINE'
                    THEN txn_date
                ELSE NULL
            END
            IGNORE NULLS
        ) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS previous_positive_physical_transaction_date,

        LAST_VALUE(
            CASE
                WHEN amount > 0 THEN txn_date
                ELSE NULL
            END
            IGNORE NULLS
        ) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS previous_positive_transaction_date,

        -- -------------------------------------------------
        -- Amount history
        -- -------------------------------------------------
        amount,

        LAG(amount) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
        ) AS previous_transaction_amount,

        LAST_VALUE(
            CASE
                WHEN amount > 0 THEN amount
                ELSE NULL
            END
            IGNORE NULLS
        ) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS previous_positive_transaction_amount,

        AVG(
            CASE
                WHEN amount > 0 THEN amount
                ELSE NULL
            END
        ) OVER (
            PARTITION BY card_id
            ORDER BY txn_date, id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS historical_average_positive_amount,

        CASE
            WHEN amount > 0 THEN 'Purchase'
            WHEN amount < 0 THEN 'Refund'
            ELSE 'Zero Amount'
        END AS transaction_type,

        -- -------------------------------------------------
        -- Existing quality and lifecycle attributes
        -- -------------------------------------------------
        is_location_anomaly,
        acct_open_date,
        expires

    FROM `card_transactions.fct_transactions`
),

behavior_features AS (

    SELECT
        *,

        -- -------------------------------------------------
        -- Amount-change features
        -- -------------------------------------------------
        CASE
            WHEN amount > 0
                THEN amount - previous_positive_transaction_amount
            ELSE NULL
        END AS amount_change_from_previous_positive,

        SAFE_DIVIDE(
            CASE
                WHEN amount > 0
                    THEN amount - previous_positive_transaction_amount
                ELSE NULL
            END,
            previous_positive_transaction_amount
        ) AS relative_amount_change_from_previous_positive,

        CASE
            WHEN amount > 0
                THEN amount - historical_average_positive_amount
            ELSE NULL
        END AS amount_change_from_historical_average,

        CASE
            WHEN amount > 0 THEN
                SAFE_DIVIDE(
                    amount - historical_average_positive_amount,
                    historical_average_positive_amount
                )
            ELSE NULL
        END AS relative_amount_change_from_historical_average,

        -- -------------------------------------------------
        -- Time-since features
        -- -------------------------------------------------
        TIMESTAMP_DIFF(
            txn_date,
            previous_transaction_date,
            MINUTE
        ) AS minutes_since_previous_transaction,

        TIMESTAMP_DIFF(
            txn_date,
            previous_positive_transaction_date,
            MINUTE
        ) AS minutes_since_previous_positive_transaction,

        TIMESTAMP_DIFF(
            txn_date,
            previous_positive_physical_transaction_date,
            MINUTE
        ) AS minutes_since_previous_positive_physical_transaction,

        -- -------------------------------------------------
        -- Merchant-change features
        -- -------------------------------------------------
        CASE
            WHEN card_transaction_number = 1
                THEN NULL
            ELSE merchant_id IS DISTINCT FROM previous_merchant_id
        END AS merchant_changed,

        CASE
            WHEN previous_positive_transaction_date IS NULL
                THEN NULL
            ELSE merchant_id IS DISTINCT FROM previous_positive_merchant_id
        END AS merchant_changed_from_previous_positive,

        -- -------------------------------------------------
        -- Location-change features
        -- -------------------------------------------------
        CASE
            WHEN previous_transaction_date IS NULL
                THEN NULL
            WHEN merchant_city = 'ONLINE'
              OR previous_merchant_city = 'ONLINE'
                THEN NULL
            ELSE
                merchant_state IS DISTINCT FROM previous_merchant_state
                OR merchant_city IS DISTINCT FROM previous_merchant_city
        END AS location_changed,

        CASE
            WHEN previous_positive_transaction_date IS NULL
                THEN NULL
            WHEN merchant_city = 'ONLINE'
              OR previous_positive_merchant_city = 'ONLINE'
                THEN NULL
            ELSE
                merchant_state IS DISTINCT FROM previous_positive_merchant_state
                OR merchant_city IS DISTINCT FROM previous_positive_merchant_city
        END AS location_changed_from_previous_positive,

        CASE
            WHEN previous_positive_physical_transaction_date IS NULL
                THEN NULL
            WHEN merchant_city = 'ONLINE'
                THEN NULL
            ELSE
                merchant_state
                    IS DISTINCT FROM previous_positive_physical_merchant_state
                OR merchant_city
                    IS DISTINCT FROM previous_positive_physical_merchant_city
        END AS location_changed_from_previous_positive_physical,

        -- -------------------------------------------------
        -- Channel-change features
        -- -------------------------------------------------
        CASE
            WHEN previous_use_chip IS NULL
                THEN NULL
            ELSE use_chip IS DISTINCT FROM previous_use_chip
        END AS channel_changed_from_previous,

        CASE
            WHEN previous_positive_use_chip IS NULL
                THEN NULL
            ELSE use_chip IS DISTINCT FROM previous_positive_use_chip
        END AS channel_changed_from_previous_positive,

        -- -------------------------------------------------
        -- Card lifecycle features
        -- -------------------------------------------------
        DATE_DIFF(
            DATE(txn_date),
            acct_open_date,
            DAY
        ) AS days_since_account_open,

        DATE_DIFF(
            expires,
            DATE(txn_date),
            DAY
        ) AS days_until_expiry

    FROM sequenced_transactions
)

SELECT *
FROM behavior_features;