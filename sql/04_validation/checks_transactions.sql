-- checks_transactions.sql
--
-- Full exploratory audit of v_transactions_clean.
--
-- Includes:
--   - transaction-ID uniqueness
--   - duplicate transaction-content investigation
--   - categorical distributions
--   - fraud-label coverage
--   - online / physical transaction location consistency
--   - merchant location and ZIP profiling
--   - derived geographic flag investigation
--   - timestamp parsing and date-range validation
--   - dataset temporal coverage
--   - hourly, minute and second distributions
--   - 06:00 transaction-concentration investigation
--   - amount distribution and quantiles
--   - negative and zero-value transaction investigation
--   - common transaction-amount clustering
--   - refund/fraud relationship
--
-- Investigative script — queries are intended to be run individually.
-- Some repetitive exploratory queries are intentionally retained because
-- they document the profiling process.


-- ============================================================
-- UNIQUENESS
-- ============================================================

-- Transaction ID should uniquely identify every transaction.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT id) AS distinct_ids

FROM `card_transactions.v_transactions_clean`;


-- ============================================================
-- DUPLICATE TRANSACTION-CONTENT INVESTIGATION
-- ============================================================

-- Look for transactions with identical business attributes,
-- regardless of transaction ID.
--
-- Duplicate-looking transactions are not automatically treated
-- as data-quality errors because multiple genuine transactions
-- may share the same attributes.
SELECT
    txn_date,
    client_id,
    card_id,
    amount,
    use_chip,
    merchant_id,
    merchant_city,
    merchant_state,
    zip,
    mcc,
    errors,
    COUNT(*) AS copies

FROM `card_transactions.v_transactions_clean`

GROUP BY
    txn_date,
    client_id,
    card_id,
    amount,
    use_chip,
    merchant_id,
    merchant_city,
    merchant_state,
    zip,
    mcc,
    errors

HAVING COUNT(*) > 1

ORDER BY copies DESC;


-- ============================================================
-- CATEGORY / VALUE DISTRIBUTIONS
-- ============================================================

-- Transaction-channel distribution.
SELECT
    use_chip,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

GROUP BY use_chip

ORDER BY transaction_count DESC;


-- Merchant-ID distribution.
SELECT
    merchant_id,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

GROUP BY merchant_id

ORDER BY transaction_count DESC;


-- Merchant-state distribution.
SELECT
    merchant_state,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

GROUP BY merchant_state

ORDER BY transaction_count DESC;


-- Merchant-city distribution.
SELECT
    merchant_city,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

GROUP BY merchant_city

ORDER BY transaction_count DESC;


-- Merchant ZIP distribution.
SELECT
    zip,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

GROUP BY zip

ORDER BY transaction_count DESC;


-- MCC distribution.
SELECT
    mcc,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

GROUP BY mcc

ORDER BY transaction_count DESC;


-- Error-value distribution.
SELECT
    errors,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

GROUP BY errors

ORDER BY transaction_count DESC;


-- ============================================================
-- FRAUD-LABEL COVERAGE
-- ============================================================

-- Profile the fraud labels available for transactions.
--
-- NULL represents transactions for which no fraud-label row exists.
SELECT
    f.is_fraud,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean` AS t

LEFT JOIN `card_transactions.v_fraud_labels_clean` AS f
    ON t.id = f.transaction_id

GROUP BY f.is_fraud;


-- ============================================================
-- SILVER NULL / FLAG PROFILE
-- ============================================================

-- Basic post-clean completeness check for key fields and
-- derived Boolean flags.
SELECT
    COUNT(*) AS total_transactions,

    COUNTIF(id IS NULL)
        AS null_id,

    COUNTIF(txn_date IS NULL)
        AS null_txn_date,

    COUNTIF(client_id IS NULL)
        AS null_client_id,

    COUNTIF(card_id IS NULL)
        AS null_card_id,

    COUNTIF(amount IS NULL)
        AS null_amount,

    COUNTIF(use_chip IS NULL)
        AS null_use_chip,

    COUNTIF(merchant_id IS NULL)
        AS null_merchant_id,

    COUNTIF(mcc IS NULL)
        AS null_mcc,

    COUNTIF(is_online IS NULL)
        AS null_is_online,

    COUNTIF(has_error IS NULL)
        AS null_has_error,

    COUNTIF(is_location_anomaly IS NULL)
        AS null_is_location_anomaly,

    COUNTIF(is_international IS NULL)
        AS null_is_international

FROM `card_transactions.v_transactions_clean`;


-- Distribution of derived quality / semantic flags.
SELECT
    COUNTIF(is_online IS TRUE)
        AS online_transactions,

    COUNTIF(has_error IS TRUE)
        AS transactions_with_error,

    COUNTIF(is_location_anomaly IS TRUE)
        AS location_anomalies,

    COUNTIF(is_international IS TRUE)
        AS inferred_international_transactions

FROM `card_transactions.v_transactions_clean`;


-- ============================================================
-- ONLINE-TRANSACTION LOCATION CONSISTENCY
-- ============================================================

-- Online transactions that unexpectedly contain merchant state.
SELECT *
FROM `card_transactions.v_transactions_clean`
WHERE use_chip = 'Online Transaction'
  AND merchant_state IS NOT NULL;


-- Online transactions whose merchant_city is not the expected
-- source value 'ONLINE', including NULL city values.
SELECT *
FROM `card_transactions.v_transactions_clean`
WHERE use_chip = 'Online Transaction'
  AND (
      merchant_city IS NULL
      OR merchant_city != 'ONLINE'
  );


-- Online transactions that contain a ZIP.
SELECT *
FROM `card_transactions.v_transactions_clean`
WHERE use_chip = 'Online Transaction'
  AND zip IS NOT NULL;


-- ============================================================
-- PHYSICAL-TRANSACTION LOCATION INVESTIGATION
-- ============================================================

-- Non-online transactions without merchant state.
SELECT *
FROM `card_transactions.v_transactions_clean`
WHERE use_chip != 'Online Transaction'
  AND merchant_state IS NULL;


-- Non-online transactions whose merchant city is recorded as ONLINE.
-- These form the source pattern used for is_location_anomaly.
SELECT *
FROM `card_transactions.v_transactions_clean`
WHERE use_chip != 'Online Transaction'
  AND merchant_city = 'ONLINE';


-- Non-online transactions without ZIP.
SELECT *
FROM `card_transactions.v_transactions_clean`
WHERE use_chip != 'Online Transaction'
  AND zip IS NULL;


-- Non-online transactions with neither ZIP nor state, excluding
-- rows whose merchant city is recorded as ONLINE.
SELECT *
FROM `card_transactions.v_transactions_clean`
WHERE use_chip != 'Online Transaction'
  AND zip IS NULL
  AND merchant_state IS NULL
  AND (
      merchant_city IS NULL
      OR merchant_city != 'ONLINE'
  );


-- All non-online transactions missing both ZIP and state.
SELECT *
FROM `card_transactions.v_transactions_clean`
WHERE use_chip != 'Online Transaction'
  AND zip IS NULL
  AND merchant_state IS NULL;


-- Missing ZIP/state by transaction channel.
SELECT
    use_chip,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

WHERE use_chip != 'Online Transaction'
  AND zip IS NULL
  AND merchant_state IS NULL

GROUP BY use_chip;


-- Non-online transactions missing either ZIP or state,
-- excluding merchant_city='ONLINE'.
SELECT
    use_chip,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

WHERE use_chip != 'Online Transaction'
  AND (
      zip IS NULL
      OR merchant_state IS NULL
  )
  AND (
      merchant_city IS NULL
      OR merchant_city != 'ONLINE'
  )

GROUP BY use_chip;


-- Which merchant cities occur among non-online transactions
-- missing both ZIP and state?
SELECT
    merchant_city,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

WHERE use_chip != 'Online Transaction'
  AND zip IS NULL
  AND merchant_state IS NULL

GROUP BY merchant_city

ORDER BY transaction_count DESC;


-- ============================================================
-- MERCHANT LOCATION FORMAT INVESTIGATION
-- ============================================================

-- Length distribution of merchant_state.
SELECT
    LENGTH(merchant_state) AS state_length,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

GROUP BY state_length

ORDER BY state_length;


-- Values longer than the two-character US-state pattern.
SELECT
    merchant_state,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

WHERE LENGTH(merchant_state) > 2

GROUP BY merchant_state

ORDER BY transaction_count DESC;


-- Merchant-city blank/whitespace checks.
SELECT
    COUNTIF(merchant_city = '')
        AS empty_city,

    COUNTIF(TRIM(merchant_city) = '')
        AS blank_city,

    COUNTIF(merchant_city != TRIM(merchant_city))
        AS padded_city

FROM `card_transactions.v_transactions_clean`;


-- Merchant-state values that do not match the expected
-- two-uppercase-letter pattern.
--
-- These values underpin the inferred is_international flag.
SELECT
    COUNTIF(
        NOT REGEXP_CONTAINS(
            merchant_state,
            r'^[A-Z]{2}$'
        )
    ) AS non_standard_state_values

FROM `card_transactions.v_transactions_clean`

WHERE merchant_state IS NOT NULL;


-- Case-insensitive merchant-city duplicates.
SELECT
    LOWER(merchant_city) AS city_lower,
    COUNT(DISTINCT merchant_city) AS variants

FROM `card_transactions.v_transactions_clean`

GROUP BY city_lower

HAVING COUNT(DISTINCT merchant_city) > 1;


-- Relationship between the inferred international flag
-- and missing ZIP among physical transactions.
SELECT
    is_international,
    COUNTIF(zip IS NULL) AS no_zip,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

WHERE is_online IS FALSE

GROUP BY is_international;


-- ZIP values should contain five digits after Silver cleaning.
SELECT
    COUNTIF(
        zip IS NOT NULL
        AND NOT REGEXP_CONTAINS(zip, r'^[0-9]{5}$')
    ) AS invalid_clean_zip_format

FROM `card_transactions.v_transactions_clean`;


-- ============================================================
-- TIMESTAMP VALIDATION
-- ============================================================

-- Source datetime contains no timezone metadata.
-- txn_date is stored as TIMESTAMP for analytical convenience.
-- Hour-based findings therefore refer to the source-recorded
-- clock hour and should not be interpreted as verified local time.


-- Did timestamp parsing create NULL values?
SELECT
    COUNTIF(txn_date IS NULL) AS null_txn_dates

FROM `card_transactions.v_transactions_clean`;


-- Transactions outside the expected dataset period.
SELECT
    txn_date,
    COUNT(*) AS transaction_count

FROM `card_transactions.v_transactions_clean`

WHERE txn_date >= TIMESTAMP '2020-01-01 00:00:00+00'
   OR txn_date < TIMESTAMP '2010-01-01 00:00:00+00'

GROUP BY txn_date

ORDER BY txn_date;


-- ============================================================
-- TEMPORAL COVERAGE
-- ============================================================

-- Identify years containing fewer than 12 active months.
WITH transactions_by_month_year AS (

    SELECT
        EXTRACT(MONTH FROM txn_date) AS month,
        EXTRACT(YEAR FROM txn_date) AS year,
        COUNT(*) AS transactions

    FROM `card_transactions.v_transactions_clean`

    GROUP BY year, month
),

months_active_per_year AS (

    SELECT
        *,
        COUNT(*) OVER (
            PARTITION BY year
        ) AS number_of_active_months

    FROM transactions_by_month_year
)

SELECT
    month,
    year,
    number_of_active_months

FROM months_active_per_year

WHERE number_of_active_months < 12

ORDER BY year, month;


-- ============================================================
-- HOURLY COVERAGE
-- ============================================================

-- Number of transactions for each hour within each calendar day.
WITH hours_extracted AS (

    SELECT
        EXTRACT(HOUR FROM txn_date) AS hour,
        EXTRACT(DAY FROM txn_date) AS day,
        EXTRACT(MONTH FROM txn_date) AS month,
        EXTRACT(YEAR FROM txn_date) AS year,
        COUNT(*) AS transactions

    FROM `card_transactions.v_transactions_clean`

    GROUP BY year, month, day, hour
)

SELECT
    MAX(day) AS latest_day_in_october_2019

FROM hours_extracted

WHERE month = 10
  AND year = 2019;


-- Overall transaction distribution by source-recorded hour.
WITH hours_only_extracted AS (

    SELECT
        EXTRACT(HOUR FROM txn_date) AS hour,
        COUNT(*) AS transactions

    FROM `card_transactions.v_transactions_clean`

    GROUP BY hour
)

SELECT *
FROM hours_only_extracted
ORDER BY hour;


-- Same hourly distribution written directly.
-- Retained as part of the exploratory workflow.
SELECT
    EXTRACT(HOUR FROM txn_date) AS hour,
    COUNT(*) AS transactions_per_hour

FROM `card_transactions.v_transactions_clean`

GROUP BY hour

ORDER BY hour;


-- ============================================================
-- SECOND / MINUTE DISTRIBUTION
-- ============================================================

-- Profile transaction timestamps by recorded second and minute.
WITH seconds_minutes_extracted AS (

    SELECT
        EXTRACT(SECOND FROM txn_date) AS seconds,
        EXTRACT(MINUTE FROM txn_date) AS minute,
        COUNT(*) AS transactions

    FROM `card_transactions.v_transactions_clean`

    GROUP BY seconds, minute
)

-- IMPORTANT:
-- SUM(transactions), rather than COUNT(*), is required here.
-- COUNT(*) would count minute/second buckets rather than transactions.
SELECT
    seconds,
    SUM(transactions) AS transactions_at_second

FROM seconds_minutes_extracted

WHERE seconds != 0

GROUP BY seconds

ORDER BY seconds;


-- Minute distribution.
WITH seconds_minutes_extracted AS (

    SELECT
        EXTRACT(SECOND FROM txn_date) AS seconds,
        EXTRACT(MINUTE FROM txn_date) AS minute,
        COUNT(*) AS transactions

    FROM `card_transactions.v_transactions_clean`

    GROUP BY seconds, minute
)

SELECT
    minute,
    SUM(transactions) AS transactions_at_minute

FROM seconds_minutes_extracted

GROUP BY minute

ORDER BY minute;


-- ============================================================
-- HOURLY TRANSACTION CHANNEL INVESTIGATION
-- ============================================================

-- Transaction counts by channel and hour.
--
-- difference_from_largest_channel shows how far each channel is
-- below the most frequent channel during that same hour.
WITH hours_extract_clean AS (

    SELECT
        use_chip,
        EXTRACT(HOUR FROM txn_date) AS hour,
        COUNT(*) AS transactions

    FROM `card_transactions.v_transactions_clean`

    GROUP BY hour, use_chip
)

SELECT
    *,
    MAX(transactions) OVER (
        PARTITION BY hour
    ) - transactions AS difference_from_largest_channel,

    CASE
        WHEN use_chip = 'Online Transaction' THEN 'ONLINE'
        ELSE 'Not Online'
    END AS online_or_not

FROM hours_extract_clean

WHERE hour BETWEEN 6 AND 17

ORDER BY hour, transactions DESC;


-- ============================================================
-- 06:00 CONCENTRATION INVESTIGATION
-- ============================================================

-- Original exploratory comparison:
-- transaction count at 06:00 versus the combined 07:00–17:00 period.
--
-- The 07:00–17:00 period contains 11 hours, so raw totals alone
-- are not directly comparable to the single 06:00 hour.
WITH hours_extract_cleaned AS (

    SELECT
        use_chip,
        EXTRACT(HOUR FROM txn_date) AS hour,
        COUNT(*) AS transactions

    FROM `card_transactions.v_transactions_clean`

    GROUP BY hour, use_chip
),

only_6 AS (

    SELECT
        use_chip,
        SUM(transactions) AS totals_at_6

    FROM hours_extract_cleaned

    WHERE hour = 6

    GROUP BY use_chip
),

only_7_17 AS (

    SELECT
        use_chip,
        SUM(transactions) AS totals_7_to_17

    FROM hours_extract_cleaned

    WHERE hour BETWEEN 7 AND 17

    GROUP BY use_chip
)

SELECT
    use_chip,
    totals_at_6,
    NULL AS totals_7_to_17

FROM only_6

UNION ALL

SELECT
    use_chip,
    NULL AS totals_at_6,
    totals_7_to_17

FROM only_7_17;


-- Normalized comparison:
-- compare transaction count at 06:00 against the average
-- transaction count PER HOUR during 07:00–17:00.
--
-- A ratio above 1 means 06:00 has more transactions than the
-- average hour in the 07:00–17:00 comparison period.
SELECT
    use_chip,

    COUNTIF(
        EXTRACT(HOUR FROM txn_date) = 6
    ) AS transactions_at_6,

    COUNTIF(
        EXTRACT(HOUR FROM txn_date) BETWEEN 7 AND 17
    ) AS transactions_7_to_17,

    SAFE_DIVIDE(
        COUNTIF(
            EXTRACT(HOUR FROM txn_date) BETWEEN 7 AND 17
        ),
        11
    ) AS average_transactions_per_hour_7_to_17,

    SAFE_DIVIDE(
        COUNTIF(
            EXTRACT(HOUR FROM txn_date) = 6
        ),
        SAFE_DIVIDE(
            COUNTIF(
                EXTRACT(HOUR FROM txn_date) BETWEEN 7 AND 17
            ),
            11
        )
    ) AS hour_6_vs_average_7_to_17_ratio

FROM `card_transactions.v_transactions_clean`

GROUP BY use_chip

ORDER BY hour_6_vs_average_7_to_17_ratio DESC;


-- ============================================================
-- MINUTE DISTRIBUTION: 06:00 VS 12:00
-- ============================================================

-- Investigate whether transactions within selected hours are
-- evenly distributed across minutes or concentrated at
-- particular minute values.
WITH only_6 AS (

    SELECT
        mcc,
        use_chip,
        client_id,
        amount,
        merchant_id,
        EXTRACT(MONTH FROM txn_date) AS month,
        EXTRACT(MINUTE FROM txn_date) AS minute,
        EXTRACT(HOUR FROM txn_date) AS hour,
        COUNT(*) AS transactions

    FROM `card_transactions.v_transactions_clean`

    WHERE EXTRACT(HOUR FROM txn_date) = 6

    GROUP BY
        mcc,
        use_chip,
        client_id,
        amount,
        merchant_id,
        month,
        hour,
        minute
),

joined_6 AS (

    SELECT
        o.*,
        m.description

    FROM only_6 AS o

    LEFT JOIN `card_transactions.v_mcc_codes_clean` AS m
        ON o.mcc = m.mcc_code
),

only_12 AS (

    SELECT
        mcc,
        use_chip,
        client_id,
        amount,
        merchant_id,
        EXTRACT(MONTH FROM txn_date) AS month,
        EXTRACT(MINUTE FROM txn_date) AS minute,
        EXTRACT(HOUR FROM txn_date) AS hour,
        COUNT(*) AS transactions

    FROM `card_transactions.v_transactions_clean`

    WHERE EXTRACT(HOUR FROM txn_date) = 12

    GROUP BY
        mcc,
        use_chip,
        client_id,
        amount,
        merchant_id,
        month,
        hour,
        minute
),

joined_12 AS (

    SELECT
        o.*,
        m.description

    FROM only_12 AS o

    LEFT JOIN `card_transactions.v_mcc_codes_clean` AS m
        ON o.mcc = m.mcc_code
),

unioned_table AS (

    SELECT
        minute,
        hour,
        transactions

    FROM joined_6

    UNION ALL

    SELECT
        minute,
        hour,
        transactions

    FROM joined_12
),

minute_summary AS (

    SELECT
        minute,
        hour,
        SUM(transactions) AS total_transactions

    FROM unioned_table

    GROUP BY minute, hour
)

SELECT
    minute,
    hour,
    total_transactions,

    ROUND(
        AVG(total_transactions) OVER (
            PARTITION BY hour
        ),
        2
    ) AS average_transactions_per_minute,

    ROUND(
        total_transactions
        - AVG(total_transactions) OVER (
            PARTITION BY hour
        ),
        2
    ) AS difference_from_average,

    ROUND(
        STDDEV(total_transactions) OVER (
            PARTITION BY hour
        ),
        2
    ) AS standard_deviation,

    ROUND(
        SAFE_DIVIDE(
            total_transactions
            - AVG(total_transactions) OVER (
                PARTITION BY hour
            ),
            STDDEV(total_transactions) OVER (
                PARTITION BY hour
            )
        ),
        1
    ) AS standard_deviations_from_average

FROM minute_summary

ORDER BY hour, minute;


-- ============================================================
-- AMOUNT DISTRIBUTION
-- ============================================================

-- Initial quartile inspection.
SELECT
    APPROX_QUANTILES(amount, 4) AS amount_quartiles

FROM `card_transactions.v_transactions_clean`;


-- Quartiles plus mean.
WITH qrt AS (

    SELECT
        APPROX_QUANTILES(amount, 4) AS quartiles,
        AVG(amount) AS mean

    FROM `card_transactions.v_transactions_clean`
)

SELECT
    quartiles[OFFSET(0)] AS min_amount,
    quartiles[OFFSET(1)] AS q1,
    quartiles[OFFSET(2)] AS median,
    quartiles[OFFSET(3)] AS q3,
    quartiles[OFFSET(4)] AS max_amount,
    mean

FROM qrt;


-- ============================================================
-- NEGATIVE / ZERO TRANSACTIONS
-- ============================================================

SELECT
    COUNTIF(amount < 0) AS number_of_negative_transactions,
    COUNTIF(amount = 0) AS number_of_zero_transactions

FROM `card_transactions.v_transactions_clean`;


-- MCC distribution among zero-value transactions.
SELECT
    m.description,
    COUNT(*) AS number_of_transactions

FROM `card_transactions.v_transactions_clean` AS t

LEFT JOIN `card_transactions.v_mcc_codes_clean` AS m
    ON t.mcc = m.mcc_code

WHERE t.amount = 0

GROUP BY m.description

ORDER BY number_of_transactions DESC;


-- ============================================================
-- MOST COMMON TRANSACTION AMOUNTS
-- ============================================================

-- Top 20 most frequently occurring transaction amounts.
SELECT
    amount,
    COUNT(*) AS frequency

FROM `card_transactions.v_transactions_clean`

GROUP BY amount

ORDER BY frequency DESC

LIMIT 20;


-- ============================================================
-- REFUND / FRAUD CROSS-CHECK
-- ============================================================

-- Compare purchase/refund/zero-value composition across
-- Fraud, Legit and Unlabeled transactions.
--
-- This uses the Gold fraud_status field because missing fraud
-- labels have already been explicitly represented as Unlabeled.
SELECT
    fraud_status,

    COUNT(*) AS total_transactions,

    COUNTIF(amount > 0)
        AS positive_transactions,

    COUNTIF(amount < 0)
        AS refund_transactions,

    COUNTIF(amount = 0)
        AS zero_amount_transactions,

    SAFE_DIVIDE(
        COUNTIF(amount < 0),
        COUNT(*)
    ) AS refund_share

FROM `card_transactions.fct_transactions`

GROUP BY fraud_status

ORDER BY fraud_status;