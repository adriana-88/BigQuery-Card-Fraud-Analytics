
-- Cross-table investigations supplementing core validation.
--
-- Investigations include:
--   - error patterns by transaction channel
--   - negative-amount / refund patterns
--   - ZIP/state consistency
--   - card-date consistency
--   - post-expiry transaction investigation
--   - transaction amount vs. card/client credit limits
--
-- Queries use Silver views directly so parsing and cleaning logic
-- remains consistent with the warehouse models.
--
-- Exploratory only — not required for the core warehouse build.


-- ============================================================
-- ERROR PATTERNS
-- ============================================================

-- Does error frequency differ across transaction channels?
-- Uses all transactions in each channel as the denominator.

SELECT
    use_chip,
    COUNT(*) AS total_transactions,
    COUNTIF(errors IS NOT NULL) AS transactions_with_error,

    SAFE_DIVIDE(
        COUNTIF(errors IS NOT NULL),
        COUNT(*)
    ) AS error_rate

FROM `card_transactions.v_transactions_clean`

GROUP BY use_chip
ORDER BY error_rate DESC;


-- Which recorded error types occur within each transaction channel?
SELECT
    errors,
    use_chip,
    COUNT(*) AS occurrence_count

FROM `card_transactions.v_transactions_clean`

WHERE errors IS NOT NULL

GROUP BY errors, use_chip
ORDER BY errors, occurrence_count DESC;


-- ============================================================
-- REFUND PATTERNS
-- ============================================================

-- How are negative-amount transactions distributed by
-- transaction channel and recorded error?
SELECT
    use_chip,
    errors,
    COUNT(*) AS occurrence_count

FROM `card_transactions.v_transactions_clean`

WHERE amount < 0

GROUP BY use_chip, errors
ORDER BY occurrence_count DESC;


-- ============================================================
-- LOCATION CONSISTENCY
-- ============================================================

-- Does the same ZIP appear with more than one merchant state?
SELECT
    zip,
    COUNT(DISTINCT merchant_state) AS different_states

FROM `card_transactions.v_transactions_clean`

WHERE zip IS NOT NULL

GROUP BY zip

HAVING COUNT(DISTINCT merchant_state) > 1;


-- ============================================================
-- CARD DATE CONSISTENCY
-- ============================================================

-- Transactions occurring after the card's stated expiry month.
--
-- v_cards_clean represents the source-provided expiry month
-- using the final day of that month.
SELECT
    t.id,
    t.card_id,
    t.txn_date,
    c.expires,
    c.acct_open_date,
    t.errors,
    t.amount

FROM `card_transactions.v_transactions_clean` AS t

JOIN `card_transactions.v_cards_clean` AS c
    ON t.card_id = c.id

WHERE DATE(t.txn_date) > c.expires;


-- Positive transactions occurring after card expiry.
SELECT
    t.id,
    t.card_id,
    t.txn_date,
    c.expires,
    c.acct_open_date,
    t.use_chip,
    t.merchant_id,
    t.merchant_city,
    t.merchant_state,
    t.errors,
    t.amount

FROM `card_transactions.v_transactions_clean` AS t

JOIN `card_transactions.v_cards_clean` AS c
    ON t.card_id = c.id

WHERE DATE(t.txn_date) > c.expires
  AND t.amount > 0;


-- Refunds occurring after card expiry.
-- Refunds are investigated separately because a refund may
-- legitimately be processed after the payment card has expired.
SELECT
    t.id,
    t.card_id,
    t.txn_date,
    c.expires,
    t.amount

FROM `card_transactions.v_transactions_clean` AS t

JOIN `card_transactions.v_cards_clean` AS c
    ON t.card_id = c.id

WHERE DATE(t.txn_date) > c.expires
  AND t.amount < 0;


-- Positive post-expiry transactions classified by fraud status.
--
-- Finding:
-- Only one positive post-expiry transaction was identified,
-- and it was fraud-labeled. No legitimate positive transactions
-- occurred after card expiry.
SELECT
    fraud_status,
    COUNT(*) AS post_expiry_positive_transactions

FROM `card_transactions.fct_transactions`

WHERE DATE(txn_date) > expires
  AND amount > 0

GROUP BY fraud_status;


-- ============================================================
-- CASE INVESTIGATION: POST-EXPIRY FRAUD TRANSACTION
-- ============================================================

-- Investigate the single positive post-expiry transaction.
--
-- Finding:
-- Transaction 20608437 occurred on 2018-01-01, one day after
-- card 3858's stated expiry month.
--
-- It was a positive amount (478), Debit Mastercard,
-- Chip Transaction, at a merchant in Rome, Italy.
-- The transaction was fraud-labeled and had no recorded error.
SELECT
    t.id,
    t.client_id,
    t.card_id,
    t.txn_date,
    t.amount,
    t.use_chip,
    t.merchant_id,
    t.merchant_city,
    t.merchant_state,
    t.zip,
    t.mcc,
    t.errors,
    c.card_brand,
    c.card_type,
    c.expires,
    c.acct_open_date

FROM `card_transactions.v_transactions_clean` AS t

JOIN `card_transactions.v_cards_clean` AS c
    ON t.card_id = c.id

WHERE t.id = '20608437';


-- Review the transaction history of the affected card.
--
-- Finding:
-- Card 3858 shows a geographically and temporally concentrated
-- fraud episode: six fraud-labeled Chip Transactions in Rome
-- between 2017-12-17 and 2018-01-01.
--
-- The final transaction in that sequence is the only positive
-- transaction occurring after the card's stated expiry month.
--
-- The row is therefore retained as a fraud anomaly rather than
-- classified as a source-data defect.
SELECT
    id,
    txn_date,
    amount,
    use_chip,
    merchant_city,
    merchant_state,
    errors,
    fraud_status

FROM `card_transactions.fct_transactions`

WHERE card_id = '3858'

ORDER BY txn_date DESC;


-- ============================================================
-- ACCOUNT-OPEN DATE CONSISTENCY
-- ============================================================

-- Transactions occurring before the card account was opened.
--
-- acct_open_date represents the first day of the source-provided
-- opening month because the exact opening day is unavailable.
-- Transactions occurring during that same month are therefore
-- conservatively treated as valid.
SELECT
    t.id,
    t.card_id,
    t.txn_date,
    c.acct_open_date,
    t.amount

FROM `card_transactions.v_transactions_clean` AS t

JOIN `card_transactions.v_cards_clean` AS c
    ON t.card_id = c.id

WHERE DATE(t.txn_date) < c.acct_open_date;


-- ============================================================
-- CREDIT-LIMIT INVESTIGATION
-- ============================================================

-- Credit-card transactions whose positive transaction amount
-- exceeds that individual card's stated credit limit.
SELECT
    t.use_chip,
    COUNT(*) AS transactions_over_card_limit

FROM `card_transactions.v_transactions_clean` AS t

JOIN `card_transactions.v_cards_clean` AS c
    ON t.card_id = c.id

WHERE c.card_type = 'Credit'
  AND t.amount > c.credit_limit

GROUP BY t.use_chip
ORDER BY transactions_over_card_limit DESC;


-- Inspect individual Credit-card transactions whose amount
-- exceeds that card's own stated limit.
SELECT
    t.id,
    t.client_id,
    t.card_id,
    t.txn_date,
    t.amount,
    c.credit_limit,
    t.use_chip,
    t.errors

FROM `card_transactions.v_transactions_clean` AS t

JOIN `card_transactions.v_cards_clean` AS c
    ON t.card_id = c.id

WHERE c.card_type = 'Credit'
  AND t.amount > c.credit_limit

ORDER BY t.amount DESC;


-- Compare each Credit-card transaction amount with the client's
-- combined stated credit limit across Credit cards only.
WITH client_credit_limits AS (

    SELECT
        client_id,
        SUM(credit_limit) AS total_credit_limit

    FROM `card_transactions.v_cards_clean`

    WHERE card_type = 'Credit'

    GROUP BY client_id
)

SELECT
    t.client_id,
    t.id AS transaction_id,
    t.amount,
    cc.total_credit_limit

FROM `card_transactions.v_transactions_clean` AS t

JOIN `card_transactions.v_cards_clean` AS c
    ON t.card_id = c.id

JOIN client_credit_limits AS cc
    ON t.client_id = cc.client_id

WHERE c.card_type = 'Credit'
  AND t.amount > cc.total_credit_limit

ORDER BY t.amount DESC;


-- Do transactions exceeding the client's combined Credit-card
-- limit cluster among a small number of clients?
WITH client_credit_limits AS (

    SELECT
        client_id,
        SUM(credit_limit) AS total_credit_limit

    FROM `card_transactions.v_cards_clean`

    WHERE card_type = 'Credit'

    GROUP BY client_id
),

credit_transactions AS (

    SELECT
        t.id,
        t.client_id,
        t.card_id,
        t.amount,
        t.errors,
        c.credit_limit

    FROM `card_transactions.v_transactions_clean` AS t

    JOIN `card_transactions.v_cards_clean` AS c
        ON t.card_id = c.id

    WHERE c.card_type = 'Credit'
)

SELECT
    ct.client_id,
    COUNT(*) AS number_of_transactions

FROM credit_transactions AS ct

JOIN client_credit_limits AS cc
    ON ct.client_id = cc.client_id

WHERE ct.amount > cc.total_credit_limit

GROUP BY ct.client_id

ORDER BY number_of_transactions DESC;