-- =========================================================
-- Gold Mart: mart_merchant_behavior
-- Grain: one row per card with purchase activity
-- Purpose: identify each card's most frequently used merchant
-- =========================================================

CREATE OR REPLACE TABLE `card_transactions.mart_merchant_behavior` AS

WITH merchant_counts AS (

    SELECT
        card_id,
        merchant_id,
        COUNT(*) AS purchase_count,
        MAX(txn_date) AS last_purchase_date

    FROM `card_transactions.mart_transaction_behavior`

    WHERE amount > 0

    GROUP BY
        card_id,
        merchant_id
),

ranked_merchants AS (

    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY card_id
            ORDER BY
                purchase_count DESC,
                last_purchase_date DESC,
                merchant_id
        ) AS merchant_rank,

        SUM(purchase_count) OVER (
            PARTITION BY card_id
        ) AS total_card_purchases

    FROM merchant_counts
)

SELECT
    card_id,
    merchant_id AS favorite_merchant_id,
    purchase_count AS favorite_merchant_purchases,
    total_card_purchases,

    SAFE_DIVIDE(
        purchase_count,
        total_card_purchases
    ) AS favorite_merchant_purchase_share,

    last_purchase_date AS favorite_merchant_last_purchase_date

FROM ranked_merchants

WHERE merchant_rank = 1;