-- =========================================================
-- Validation: card_transactions.mart_transaction_behavior
-- =========================================================


-- 1. Cards with transactions before recorded account opening date
SELECT
    card_id,
    acct_open_date,
    MIN(DATE(txn_date)) AS first_transaction_date,
    COUNT(*) AS total_transactions,
    COUNTIF(DATE(txn_date) < acct_open_date) AS transactions_before_open,
    MIN(
        DATE_DIFF(
            DATE(txn_date),
            acct_open_date,
            DAY
        )
    ) AS earliest_days_relative_to_open
FROM card_transactions.mart_transaction_behavior
GROUP BY
    card_id,
    acct_open_date
HAVING COUNTIF(DATE(txn_date) < acct_open_date) > 0
ORDER BY
    transactions_before_open DESC,
    card_id;


-- 2. Lifecycle exceptions:
--    transactions before account opening or after recorded expiry
SELECT
    id,
    card_id,
    txn_date,
    acct_open_date,
    expires,
    days_since_account_open,
    days_until_expiry,
    amount,
    transaction_type,
    fraud_status
FROM card_transactions.mart_transaction_behavior
WHERE days_since_account_open < 0
   OR days_until_expiry < 0
ORDER BY
    card_id,
    txn_date;


-- 3. First transaction on each card should have no historical values
SELECT *
FROM card_transactions.mart_transaction_behavior
WHERE card_transaction_number = 1
  AND (
         previous_transaction_date IS NOT NULL
      OR previous_transaction_amount IS NOT NULL
      OR previous_use_chip IS NOT NULL
      OR previous_merchant_id IS NOT NULL
      OR previous_merchant_city IS NOT NULL
      OR previous_merchant_state IS NOT NULL
      OR previous_is_international IS NOT NULL

      OR previous_positive_transaction_date IS NOT NULL
      OR previous_positive_transaction_amount IS NOT NULL
      OR previous_positive_use_chip IS NOT NULL
      OR previous_positive_merchant_id IS NOT NULL
      OR previous_positive_merchant_city IS NOT NULL
      OR previous_positive_merchant_state IS NOT NULL
      OR previous_positive_is_international IS NOT NULL

      OR previous_positive_physical_transaction_date IS NOT NULL
      OR previous_positive_physical_merchant_city IS NOT NULL
      OR previous_positive_physical_merchant_state IS NOT NULL

      OR historical_average_positive_amount IS NOT NULL
  );


-- 4. previous_transaction_date should be NULL only for
--    the first transaction on each card
SELECT
    id,
    card_id,
    card_transaction_number,
    txn_date,
    previous_transaction_date
FROM card_transactions.mart_transaction_behavior
WHERE previous_transaction_date IS NULL
  AND card_transaction_number != 1;


-- 5. Number of first transactions should equal number of cards
SELECT
    COUNTIF(card_transaction_number = 1) AS first_transaction_rows,
    COUNT(DISTINCT card_id) AS distinct_cards
FROM card_transactions.mart_transaction_behavior;


-- 6. Historical timestamps must never point into the future
SELECT
    id,
    card_id,
    txn_date,
    previous_transaction_date,
    previous_positive_transaction_date,
    previous_positive_physical_transaction_date
FROM card_transactions.mart_transaction_behavior
WHERE previous_transaction_date > txn_date
   OR previous_positive_transaction_date > txn_date
   OR previous_positive_physical_transaction_date > txn_date;


-- 7. Row count and transaction-ID uniqueness
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT id) AS distinct_transaction_ids
FROM card_transactions.mart_transaction_behavior;


-- 8. Explicit duplicate transaction-ID check
WITH duplicate_ids AS (
    SELECT
        id,
        COUNT(*) AS row_count
    FROM card_transactions.mart_transaction_behavior
    GROUP BY id
)

SELECT
    id,
    row_count
FROM duplicate_ids
WHERE row_count > 1
ORDER BY
    row_count DESC,
    id;