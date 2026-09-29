-- One row per card represented in purchase activity
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT card_id) AS distinct_cards
FROM `card_transactions.mart_merchant_behavior`;


-- Favorite merchant share should be within 0–1
SELECT
    COUNT(*) AS invalid_share_rows
FROM `card_transactions.mart_merchant_behavior`
WHERE favorite_merchant_purchase_share < 0
   OR favorite_merchant_purchase_share > 1;


-- Purchase counts must be internally consistent
SELECT
    COUNT(*) AS invalid_count_rows
FROM `card_transactions.mart_merchant_behavior`
WHERE favorite_merchant_purchases > total_card_purchases;