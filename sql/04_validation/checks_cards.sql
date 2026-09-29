-- checks_cards.sql
--
-- Full exploratory audit of cards_raw and v_cards_clean.
--
-- Includes:
--   - card-ID uniqueness
--   - card/client cardinality
--   - raw completeness and format profiling
--   - client_id='0' and cvv='0' investigation
--   - raw categorical-value profiling
--   - post-clean NULL validation
--   - Boolean normalization checks
--   - numeric/domain validity
--   - card-date consistency
--
-- Investigative script — queries are intended to be run individually.
-- Some exploratory profiling queries are intentionally retained
-- to document the original audit process.


-- ============================================================
-- RAW UNIQUENESS
-- ============================================================

-- Card ID should uniquely identify each source row.
SELECT
    COUNT(*) AS total_cards,
    COUNT(DISTINCT id) AS unique_card_ids

FROM `card_transactions.cards_raw`;


-- ============================================================
-- RAW COMPLETENESS / FORMAT PROFILE
-- ============================================================

-- General profile of all raw card attributes.
--
-- Because cards_raw was imported as strings, UNPIVOT allows the
-- same completeness and formatting checks to be applied across
-- the source fields.
SELECT
    column_name,

    COUNT(*) AS total_rows,

    COUNTIF(value IS NULL)
        AS null_values,

    COUNTIF(TRIM(value) = '')
        AS empty_values,

    COUNTIF(value != TRIM(value))
        AS padded_values,

    COUNTIF(value LIKE '%$%')
        AS has_dollar_sign,

    COUNTIF(value LIKE '%,%')
        AS has_comma,

    COUNTIF(value LIKE '%/%')
        AS contains_slash,

    COUNTIF(value = '0')
        AS zero_string_values,

    MIN(value) AS min_value,
    MAX(value) AS max_value,

    COUNT(DISTINCT value)
        AS distinct_values

FROM `card_transactions.cards_raw`

UNPIVOT INCLUDE NULLS (
    value FOR column_name IN (
        client_id,
        card_brand,
        card_type,
        card_number,
        expires,
        cvv,
        has_chip,
        num_cards_issued,
        credit_limit,
        acct_open_date,
        year_pin_last_changed,
        card_on_dark_web
    )
)

GROUP BY column_name
ORDER BY column_name;


-- ============================================================
-- RAW CARD / CLIENT CARDINALITY
-- ============================================================

-- Number of cards versus number of clients represented
-- in the card table.
SELECT
    COUNT(*) AS total_cards,
    COUNT(DISTINCT client_id) AS clients_with_cards

FROM `card_transactions.cards_raw`;


-- Number of cards per client.
SELECT
    client_id,
    COUNT(*) AS card_count

FROM `card_transactions.cards_raw`

GROUP BY client_id

ORDER BY card_count DESC;


-- ============================================================
-- RAW CATEGORICAL VALUES
-- ============================================================

-- Card-brand distribution.
SELECT
    card_brand,
    COUNT(*) AS card_count

FROM `card_transactions.cards_raw`

GROUP BY card_brand

ORDER BY card_count DESC;


-- Card-type distribution.
SELECT
    card_type,
    COUNT(*) AS card_count

FROM `card_transactions.cards_raw`

GROUP BY card_type

ORDER BY card_count DESC;


-- Raw has_chip values.
--
-- Audited source values:
--   YES
--   NO
SELECT
    has_chip,
    COUNT(*) AS card_count

FROM `card_transactions.cards_raw`

GROUP BY has_chip

ORDER BY card_count DESC;


-- Raw card_on_dark_web values.
--
-- Audited source result:
-- all 6,146 cards contain 'No'.
SELECT
    card_on_dark_web,
    COUNT(*) AS card_count

FROM `card_transactions.cards_raw`

GROUP BY card_on_dark_web

ORDER BY card_count DESC;


-- ============================================================
-- CLIENT_ID='0' / CVV='0' INVESTIGATION
-- ============================================================

-- Investigate raw rows containing client_id='0' or cvv='0'.
--
-- Only fields required for the investigation are selected.
-- card_number is intentionally excluded.
SELECT
    id,
    client_id,
    card_brand,
    card_type,
    expires,
    cvv,
    has_chip,
    num_cards_issued,
    credit_limit,
    acct_open_date,
    year_pin_last_changed,
    card_on_dark_web

FROM `card_transactions.cards_raw`

WHERE client_id = '0'
   OR cvv = '0';


-- Confirm that client ID 0 represents an actual user.
SELECT
    id,
    current_age,
    gender,
    num_credit_cards

FROM `card_transactions.users_raw`

WHERE id = '0';


-- Determine whether the client_id='0' and cvv='0'
-- populations overlap.
SELECT
    COUNTIF(client_id = '0') AS client_zero_rows,
    COUNTIF(cvv = '0') AS cvv_zero_rows,
    COUNTIF(
        client_id = '0'
        AND cvv = '0'
    ) AS overlapping_rows

FROM `card_transactions.cards_raw`;


-- ============================================================
-- RAW DATE FORMAT / PARSE CHECKS
-- ============================================================

-- Source expiry values that cannot be interpreted as MM/YYYY.
SELECT
    COUNT(*) AS invalid_expiry_values

FROM `card_transactions.cards_raw`

WHERE expires IS NOT NULL
  AND SAFE.PARSE_DATE('%m/%Y', expires) IS NULL;


-- Source account-open values that cannot be interpreted as MM/YYYY.
SELECT
    COUNT(*) AS invalid_account_open_values

FROM `card_transactions.cards_raw`

WHERE acct_open_date IS NOT NULL
  AND SAFE.PARSE_DATE('%m/%Y', acct_open_date) IS NULL;


-- ============================================================
-- SILVER NULL-CHECK HELPER
-- ============================================================

-- Development helper retained from the original workflow:
-- generates COUNTIF expressions for the cleaned card view.
SELECT
    STRING_AGG(
        FORMAT(
            'COUNTIF(%s IS NULL) AS null_%s',
            column_name,
            column_name
        ),
        ',\n'
        ORDER BY ordinal_position
    ) AS generated

FROM `card_transactions.INFORMATION_SCHEMA.COLUMNS`

WHERE table_name = 'v_cards_clean';


-- ============================================================
-- SILVER NULL VALIDATION
-- ============================================================

-- Check whether parsing, casting or Boolean normalization
-- introduced unexpected NULL values.
SELECT
    COUNT(*) AS total_cards,

    COUNTIF(id IS NULL)
        AS null_id,

    COUNTIF(client_id IS NULL)
        AS null_client_id,

    COUNTIF(card_brand IS NULL)
        AS null_card_brand,

    COUNTIF(card_type IS NULL)
        AS null_card_type,

    COUNTIF(card_number IS NULL)
        AS null_card_number,

    COUNTIF(expires IS NULL)
        AS null_expires,

    COUNTIF(cvv IS NULL)
        AS null_cvv,

    COUNTIF(has_chip IS NULL)
        AS null_has_chip,

    COUNTIF(num_cards_issued IS NULL)
        AS null_num_cards_issued,

    COUNTIF(credit_limit IS NULL)
        AS null_credit_limit,

    COUNTIF(acct_open_date IS NULL)
        AS null_acct_open_date,

    COUNTIF(year_pin_last_changed IS NULL)
        AS null_year_pin_last_changed,

    COUNTIF(card_on_dark_web IS NULL)
        AS null_card_on_dark_web

FROM `card_transactions.v_cards_clean`;


-- ============================================================
-- BOOLEAN NORMALIZATION
-- ============================================================

-- Verify normalized has_chip distribution.
SELECT
    has_chip,
    COUNT(*) AS card_count

FROM `card_transactions.v_cards_clean`

GROUP BY has_chip

ORDER BY card_count DESC;


-- Verify normalized card_on_dark_web distribution.
--
-- Given the audited raw source, all rows are expected to be FALSE.
SELECT
    card_on_dark_web,
    COUNT(*) AS card_count

FROM `card_transactions.v_cards_clean`

GROUP BY card_on_dark_web

ORDER BY card_count DESC;


-- ============================================================
-- NUMERIC / DOMAIN VALIDITY
-- ============================================================

-- Basic validity checks after conversion to numeric types.
SELECT
    COUNTIF(num_cards_issued <= 0)
        AS non_positive_num_cards_issued,

    COUNTIF(credit_limit < 0)
        AS negative_credit_limits,

    COUNTIF(year_pin_last_changed < 0)
        AS negative_pin_change_year

FROM `card_transactions.v_cards_clean`;


-- Credit-limit range.
SELECT
    MIN(credit_limit) AS min_credit_limit,
    MAX(credit_limit) AS max_credit_limit,
    AVG(credit_limit) AS average_credit_limit

FROM `card_transactions.v_cards_clean`;


-- Number-of-cards-issued distribution.
SELECT
    num_cards_issued,
    COUNT(*) AS card_count

FROM `card_transactions.v_cards_clean`

GROUP BY num_cards_issued

ORDER BY num_cards_issued;


-- ============================================================
-- CARD DATE CONSISTENCY
-- ============================================================

-- v_cards_clean represents:
--
-- expires
--   -> final day of the source-provided expiry month
--
-- acct_open_date
--   -> first day of the source-provided account-opening month
--
-- Therefore a card whose expiry precedes its account-opening
-- month would represent an internal date inconsistency.
SELECT
    id,
    client_id,
    acct_open_date,
    expires

FROM `card_transactions.v_cards_clean`

WHERE expires < acct_open_date

ORDER BY acct_open_date;


-- Count the same date inconsistency.
SELECT
    COUNT(*) AS cards_expiring_before_account_open

FROM `card_transactions.v_cards_clean`

WHERE expires < acct_open_date;


-- ============================================================
-- PIN-CHANGE DATE CONSISTENCY
-- ============================================================

-- Compare PIN-change year with account-opening year.
--
-- A PIN-change year before the account-opening year would
-- represent a potentially inconsistent source relationship.
SELECT
    id,
    client_id,
    acct_open_date,
    year_pin_last_changed

FROM `card_transactions.v_cards_clean`

WHERE year_pin_last_changed
      < EXTRACT(YEAR FROM acct_open_date)

ORDER BY year_pin_last_changed;


-- Count PIN-change years preceding account opening.
SELECT
    COUNT(*) AS pin_change_before_account_open

FROM `card_transactions.v_cards_clean`

WHERE year_pin_last_changed
      < EXTRACT(YEAR FROM acct_open_date);