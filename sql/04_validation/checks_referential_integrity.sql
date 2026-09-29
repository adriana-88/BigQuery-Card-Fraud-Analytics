-- checks_referential_integrity.sql
--
-- Referential-integrity and cross-table consistency checks across
-- the source schema.
--
-- Includes:
--   - key completeness
--   - transaction -> user references
--   - transaction -> card references
--   - transaction -> MCC references
--   - fraud label -> transaction references
--   - card -> user references
--   - user/card coverage
--   - fraud-label uniqueness and accepted values
--   - MCC-code uniqueness / description completeness
--   - transaction/card ownership consistency
--
-- Findings from the audited dataset:
--   - no orphan foreign-key references were identified
--   - 94,361 transactions have no fraud-label row; this is treated
--     as a label-coverage gap rather than a referential-integrity defect
--   - transaction client_id and card ownership are consistent
--
-- Queries are intended to be run individually.


-- ============================================================
-- KEY COMPLETENESS
-- ============================================================

-- Missing identifiers / foreign keys in the transaction source.
SELECT
    COUNT(*) AS total_transactions,

    COUNTIF(id IS NULL)
        AS null_transaction_id,

    COUNTIF(client_id IS NULL)
        AS null_client_id,

    COUNTIF(card_id IS NULL)
        AS null_card_id,

    COUNTIF(mcc IS NULL)
        AS null_mcc

FROM `card_transactions.transactions_raw`;


-- Missing key fields in cards.
SELECT
    COUNT(*) AS total_cards,

    COUNTIF(id IS NULL)
        AS null_card_id,

    COUNTIF(client_id IS NULL)
        AS null_card_client_id

FROM `card_transactions.cards_raw`;


-- Missing transaction IDs in fraud labels.
SELECT
    COUNT(*) AS total_fraud_label_rows,

    COUNTIF(transaction_id IS NULL)
        AS null_transaction_id

FROM `card_transactions.fraud_labels_raw`;


-- ============================================================
-- TRANSACTION -> USER
-- ============================================================

-- Transactions whose client_id does not exist in users_raw.
SELECT
    COUNT(*) AS transactions_with_missing_user_reference

FROM `card_transactions.transactions_raw` AS t

LEFT JOIN `card_transactions.users_raw` AS u
    ON t.client_id = u.id

WHERE t.client_id IS NOT NULL
  AND u.id IS NULL;


-- ============================================================
-- TRANSACTION -> CARD
-- ============================================================

-- Transactions whose card_id does not exist in cards_raw.
SELECT
    COUNT(*) AS transactions_with_missing_card_reference

FROM `card_transactions.transactions_raw` AS t

LEFT JOIN `card_transactions.cards_raw` AS c
    ON t.card_id = c.id

WHERE t.card_id IS NOT NULL
  AND c.id IS NULL;


-- ============================================================
-- TRANSACTION -> MCC
-- ============================================================

-- Transactions whose MCC does not exist in the MCC lookup.
SELECT
    COUNT(*) AS transactions_with_missing_mcc_reference

FROM `card_transactions.transactions_raw` AS t

LEFT JOIN `card_transactions.mcc_codes_raw` AS m
    ON t.mcc = m.mcc_code

WHERE t.mcc IS NOT NULL
  AND m.mcc_code IS NULL;


-- ============================================================
-- FRAUD-LABEL COVERAGE
-- ============================================================

-- Transactions without a matching fraud-label row.
--
-- This is a coverage check, not an orphan-reference defect:
-- the transaction exists, but no corresponding label is available.
SELECT
    COUNT(*) AS transactions_without_fraud_label

FROM `card_transactions.transactions_raw` AS t

LEFT JOIN `card_transactions.fraud_labels_raw` AS f
    ON t.id = f.transaction_id

WHERE t.id IS NOT NULL
  AND f.transaction_id IS NULL;


-- Fraud-label rows whose transaction_id does not exist
-- in the transaction source.
--
-- Unlike the previous query, these would represent true orphan
-- references if any were found.
SELECT
    COUNT(*) AS fraud_labels_without_transaction

FROM `card_transactions.fraud_labels_raw` AS f

LEFT JOIN `card_transactions.transactions_raw` AS t
    ON f.transaction_id = t.id

WHERE f.transaction_id IS NOT NULL
  AND t.id IS NULL;


-- ============================================================
-- CARD -> USER
-- ============================================================

-- Cards whose client_id does not exist in users_raw.
SELECT
    COUNT(*) AS cards_without_valid_user

FROM `card_transactions.cards_raw` AS c

LEFT JOIN `card_transactions.users_raw` AS u
    ON c.client_id = u.id

WHERE c.client_id IS NOT NULL
  AND u.id IS NULL;


-- ============================================================
-- USER / CARD COVERAGE
-- ============================================================

-- Users who have no cards in cards_raw.
--
-- This is a relationship-coverage check, not referential-integrity
-- failure: users are the parent entity and are not required to
-- have a matching child row unless the business rules say so.
SELECT
    COUNT(*) AS users_without_cards

FROM `card_transactions.users_raw` AS u

LEFT JOIN `card_transactions.cards_raw` AS c
    ON u.id = c.client_id

WHERE u.id IS NOT NULL
  AND c.client_id IS NULL;


-- ============================================================
-- FRAUD-LABEL UNIQUENESS / DOMAIN
-- ============================================================

-- transaction_id should occur at most once in the fraud-label table.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT transaction_id) AS unique_transaction_ids

FROM `card_transactions.fraud_labels_raw`;


-- Distribution of raw fraud-label values.
-- Expected source values: Yes / No.
SELECT
    is_fraud,
    COUNT(*) AS row_count

FROM `card_transactions.fraud_labels_raw`

GROUP BY is_fraud

ORDER BY row_count DESC;


-- Explicitly identify unexpected fraud-label values.
SELECT
    COUNT(*) AS unexpected_fraud_label_values

FROM `card_transactions.fraud_labels_raw`

WHERE is_fraud IS NULL
   OR is_fraud NOT IN ('Yes', 'No');


-- ============================================================
-- MCC LOOKUP UNIQUENESS / COMPLETENESS
-- ============================================================

-- MCC code should uniquely identify a lookup row.
SELECT
    COUNT(*) AS total_mcc_rows,
    COUNT(DISTINCT mcc_code) AS unique_mcc_codes

FROM `card_transactions.mcc_codes_raw`;


-- Missing / blank MCC descriptions.
SELECT
    COUNTIF(description IS NULL)
        AS null_descriptions,

    COUNTIF(TRIM(description) = '')
        AS empty_descriptions

FROM `card_transactions.mcc_codes_raw`;


-- ============================================================
-- CROSS-TABLE BUSINESS CONSISTENCY
-- ============================================================

-- Every card used in a transaction should belong to the same
-- client recorded on that transaction.
--
-- A dataset can pass ordinary foreign-key checks while still
-- failing this relationship-consistency test. For example:
--
-- transaction.client_id -> valid user A
-- transaction.card_id   -> valid card belonging to user B
--
-- Both foreign keys would exist, but the row would be logically
-- inconsistent.
SELECT
    COUNT(*) AS mismatched_card_owners

FROM `card_transactions.v_transactions_clean` AS t

JOIN `card_transactions.v_cards_clean` AS c
    ON t.card_id = c.id

WHERE t.client_id != c.client_id;

-- Audited result: 0