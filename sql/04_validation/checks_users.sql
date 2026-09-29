-- checks_users.sql
--
-- Full exploratory audit of users_raw and v_users_clean.
--
-- Includes:
--   - uniqueness checks
--   - raw demographic and financial distributions
--   - completeness / whitespace / formatting checks
--   - numeric-format validation
--   - post-clean NULL validation
--   - geographic validity
--   - credit-score profiling
--   - age/reference-date investigation
--   - income/debt consistency investigation
--   - distribution and outlier profiling
--
-- Investigative script — queries are intended to be run individually.
-- Some apparently repetitive profiling queries are intentionally retained
-- because they document the exploratory process.


-- ============================================================
-- RAW UNIQUENESS
-- ============================================================

-- User ID should uniquely identify each source row.
SELECT
    COUNT(DISTINCT id) AS unique_ids,
    COUNT(*) AS total_ids
FROM `card_transactions.users_raw`;


-- ============================================================
-- RAW DEMOGRAPHIC DISTRIBUTIONS
-- ============================================================

-- Current-age distribution.
SELECT
    current_age,
    COUNT(*) AS user_count
FROM `card_transactions.users_raw`
GROUP BY current_age
ORDER BY SAFE_CAST(current_age AS INT64);


-- Number of distinct current-age values.
SELECT
    COUNT(DISTINCT current_age) AS distinct_ages,
    COUNT(*) AS total_users
FROM `card_transactions.users_raw`;


-- Birth-month distribution.
SELECT
    birth_month,
    COUNT(*) AS user_count
FROM `card_transactions.users_raw`
GROUP BY birth_month
ORDER BY SAFE_CAST(birth_month AS INT64);


-- Number of distinct birth years.
SELECT
    COUNT(DISTINCT birth_year) AS distinct_birth_years,
    COUNT(*) AS total_users
FROM `card_transactions.users_raw`;


-- Gender cardinality.
SELECT
    COUNT(DISTINCT gender) AS distinct_gender_values,
    COUNT(*) AS total_users
FROM `card_transactions.users_raw`;


-- Gender distribution.
SELECT
    gender,
    COUNT(*) AS user_count
FROM `card_transactions.users_raw`
GROUP BY gender
ORDER BY user_count DESC;


-- Retirement-age distribution.
SELECT
    retirement_age,
    COUNT(*) AS user_count
FROM `card_transactions.users_raw`
GROUP BY retirement_age
ORDER BY SAFE_CAST(retirement_age AS INT64);


-- ============================================================
-- RAW FINANCIAL DISTRIBUTIONS
-- ============================================================

-- Per-capita-income distribution.
SELECT
    per_capita_income,
    COUNT(*) AS user_count
FROM `card_transactions.users_raw`
GROUP BY per_capita_income;


-- Number of distinct per-capita-income values.
SELECT
    COUNT(DISTINCT per_capita_income) AS distinct_per_capita_income_values,
    COUNT(*) AS total_users
FROM `card_transactions.users_raw`;


-- Credit-score distribution.
SELECT
    credit_score,
    COUNT(*) AS user_count
FROM `card_transactions.users_raw`
GROUP BY credit_score
ORDER BY SAFE_CAST(credit_score AS INT64);


-- Total-debt distribution.
SELECT
    total_debt,
    COUNT(*) AS user_count
FROM `card_transactions.users_raw`
GROUP BY total_debt;


-- Number-of-credit-cards distribution.
SELECT
    num_credit_cards,
    COUNT(*) AS user_count
FROM `card_transactions.users_raw`
GROUP BY num_credit_cards
ORDER BY SAFE_CAST(num_credit_cards AS INT64);


-- Yearly-income distribution.
SELECT
    yearly_income,
    COUNT(*) AS user_count
FROM `card_transactions.users_raw`
GROUP BY yearly_income
ORDER BY user_count DESC;


-- ============================================================
-- RAW GEOGRAPHIC DISTRIBUTIONS
-- ============================================================

-- Latitude distribution.
SELECT
    latitude,
    COUNT(*) AS user_count
FROM `card_transactions.users_raw`
GROUP BY latitude;


-- Longitude distribution.
SELECT
    longitude,
    COUNT(*) AS user_count
FROM `card_transactions.users_raw`
GROUP BY longitude;


-- Check for leading/trailing whitespace in longitude.
SELECT
    longitude
FROM `card_transactions.users_raw`
WHERE LENGTH(longitude) != LENGTH(TRIM(longitude));


-- ============================================================
-- RAW COMPLETENESS / GENERAL FORMAT PROFILE
-- ============================================================

-- General source-string audit.
--
-- This section intentionally includes categorical fields such as
-- gender and address because NULL, blank, and whitespace checks
-- are meaningful for every source column.
SELECT
    column_name,
    COUNT(*) AS total_rows,
    COUNTIF(value IS NULL) AS null_values,
    COUNTIF(TRIM(value) = '') AS empty_values,
    COUNTIF(value != TRIM(value)) AS padded_values

FROM `card_transactions.users_raw`

UNPIVOT INCLUDE NULLS (
    value FOR column_name IN (
        current_age,
        retirement_age,
        birth_year,
        birth_month,
        gender,
        address,
        latitude,
        longitude,
        per_capita_income,
        yearly_income,
        total_debt,
        credit_score,
        num_credit_cards
    )
)

GROUP BY column_name
ORDER BY column_name;


-- ============================================================
-- RAW NUMERIC FORMAT PROFILE
-- ============================================================

-- Numeric-like source fields only.
--
-- Separating this from the general UNPIVOT audit prevents
-- categorical values such as gender/address from being
-- incorrectly classified as malformed numeric values.
SELECT
    column_name,
    COUNT(*) AS total_rows,
    COUNTIF(value IS NULL) AS null_values,
    COUNTIF(TRIM(value) = '') AS empty_values,
    COUNTIF(value LIKE '%$%') AS has_dollar,
    COUNTIF(value LIKE '%,%') AS has_comma,

    COUNTIF(
        value IS NOT NULL
        AND TRIM(value) != ''
        AND NOT REGEXP_CONTAINS(
            TRIM(value),
            r'^-?\$?[0-9,]*\.?[0-9]*$'
        )
    ) AS unexpected_numeric_format

FROM `card_transactions.users_raw`

UNPIVOT INCLUDE NULLS (
    value FOR column_name IN (
        current_age,
        retirement_age,
        birth_year,
        birth_month,
        latitude,
        longitude,
        per_capita_income,
        yearly_income,
        total_debt,
        credit_score,
        num_credit_cards
    )
)

GROUP BY column_name
ORDER BY column_name;


-- ============================================================
-- SILVER VIEW INSPECTION
-- ============================================================

-- Manual inspection of the cleaned user view.
-- Retained as part of the original investigative workflow.
SELECT *
FROM `card_transactions.v_users_clean`;


-- ============================================================
-- SILVER NULL-CHECK HELPER
-- ============================================================

-- Development helper used to generate COUNTIF statements for
-- all columns in v_users_clean.
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

WHERE table_name = 'v_users_clean';


-- ============================================================
-- SILVER NULL VALIDATION
-- ============================================================

-- Check whether SAFE_CAST / SAFE geography construction created
-- unexpected NULL values.
SELECT
    COUNT(*) AS total,

    COUNTIF(id IS NULL)
        AS null_id,

    COUNTIF(current_age IS NULL)
        AS null_current_age,

    COUNTIF(retirement_age IS NULL)
        AS null_retirement_age,

    COUNTIF(birth_year IS NULL)
        AS null_birth_year,

    COUNTIF(birth_month IS NULL)
        AS null_birth_month,

    COUNTIF(gender IS NULL)
        AS null_gender,

    COUNTIF(address IS NULL)
        AS null_address,

    COUNTIF(latitude IS NULL)
        AS null_latitude,

    COUNTIF(longitude IS NULL)
        AS null_longitude,

    COUNTIF(per_capita_income IS NULL)
        AS null_per_capita_income,

    COUNTIF(yearly_income IS NULL)
        AS null_yearly_income,

    COUNTIF(total_debt IS NULL)
        AS null_total_debt,

    COUNTIF(credit_score IS NULL)
        AS null_credit_score,

    COUNTIF(num_credit_cards IS NULL)
        AS null_num_credit_cards,

    COUNTIF(home_geo IS NULL)
        AS null_home_geo

FROM `card_transactions.v_users_clean`;


-- ============================================================
-- SILVER DOMAIN VALIDITY
-- ============================================================

-- Geographic coordinate validity.
SELECT
    COUNTIF(latitude NOT BETWEEN -90 AND 90)
        AS invalid_latitude,

    COUNTIF(longitude NOT BETWEEN -180 AND 180)
        AS invalid_longitude,

    COUNTIF(home_geo IS NULL)
        AS null_home_geo

FROM `card_transactions.v_users_clean`;


-- Birth-month and credit-card-count validity.
SELECT
    COUNTIF(birth_month NOT BETWEEN 1 AND 12)
        AS invalid_birth_month,

    COUNTIF(num_credit_cards < 0)
        AS negative_credit_card_counts

FROM `card_transactions.v_users_clean`;


-- ============================================================
-- CREDIT SCORE
-- ============================================================

-- Basic credit-score range and zero-value check.
SELECT
    MIN(credit_score) AS min_score,
    MAX(credit_score) AS max_score,
    COUNTIF(credit_score = 0) AS total_zero

FROM `card_transactions.v_users_clean`;


-- ============================================================
-- AGE / REFERENCE-DATE INVESTIGATION
-- ============================================================

-- Check for impossible / unexpected birth years relative to
-- the apparent user-age reference period.
SELECT
    COUNTIF(birth_year >= 2020) AS birth_year_2020_or_later

FROM `card_transactions.v_users_clean`;


-- Initial investigation:
-- compare current_age with age implied by 2020 - birth_year.
WITH testing_age AS (

    SELECT
        id,
        birth_year,
        current_age,
        birth_month,
        2020 - birth_year AS test_year

    FROM `card_transactions.v_users_clean`
),

tested_ages AS (

    SELECT
        *,

        CASE
            WHEN test_year <= 17 THEN NULL
            ELSE test_year
        END AS flag

    FROM testing_age
)

SELECT
    birth_month

FROM tested_ages

WHERE current_age - flag != 0

GROUP BY
    current_age - flag,
    birth_month;


-- Investigate which calendar year is implied by:
--
-- birth_year + current_age
--
-- Values clustering around 2019/2020 indicate that current_age
-- behaves as a historical snapshot rather than age calculated
-- dynamically at query time.
SELECT
    birth_year + current_age AS implied_year,
    COUNT(*) AS user_count

FROM `card_transactions.v_users_clean`

GROUP BY implied_year
ORDER BY implied_year;


-- Examine birth-month patterns among users whose age implies
-- 2019 versus 2020.
--
-- The pattern suggests an age reference date around early 2020.
SELECT
    birth_month,

    COUNTIF(
        birth_year + current_age = 2020
    ) AS had_birthday,

    COUNTIF(
        birth_year + current_age = 2019
    ) AS not_yet

FROM `card_transactions.v_users_clean`

GROUP BY birth_month
ORDER BY birth_month;


-- Age and retirement-age range checks.
--
-- at_or_past_retirement_age indicates that current_age is
-- greater than or equal to the recorded retirement_age.
-- It should not be interpreted as proof of actual retirement status.
SELECT
    MIN(current_age) AS min_age,
    MAX(current_age) AS max_age,

    COUNTIF(current_age = 0)
        AS total_zero,

    COUNTIF(current_age <= 17)
        AS total_minors,

    COUNTIF(current_age >= retirement_age)
        AS at_or_past_retirement_age,

    MIN(retirement_age)
        AS min_retirement_age,

    MAX(retirement_age)
        AS max_retirement_age

FROM `card_transactions.v_users_clean`;


-- ============================================================
-- INCOME / DEBT INVESTIGATION
-- ============================================================

-- Basic value-range checks.
--
-- yearly_income < per_capita_income is treated as an exploratory
-- relationship rather than a data-quality failure because
-- per_capita_income appears to behave as a contextual/statistical
-- attribute rather than necessarily an individual's income.
SELECT
    COUNTIF(yearly_income < per_capita_income)
        AS yearly_income_below_per_capita_income,

    COUNTIF(yearly_income = 0)
        AS zero_yearly_income,

    COUNTIF(yearly_income < 0)
        AS negative_yearly_income,

    COUNTIF(per_capita_income = 0)
        AS zero_per_capita_income,

    COUNTIF(per_capita_income < 0)
        AS negative_per_capita_income,

    COUNTIF(total_debt = 0)
        AS zero_total_debt,

    COUNTIF(total_debt < 0)
        AS negative_total_debt

FROM `card_transactions.v_users_clean`;


-- Inspect users whose yearly income falls below the recorded
-- per-capita-income value.
SELECT
    id,
    yearly_income,
    per_capita_income,
    address,
    per_capita_income - yearly_income AS difference

FROM `card_transactions.v_users_clean`

WHERE yearly_income < per_capita_income

ORDER BY difference DESC;


-- Do many users share the same per-capita-income value?
-- Useful for investigating whether this behaves like a
-- geographic/contextual statistic.
SELECT
    per_capita_income,
    COUNT(DISTINCT id) AS n_users

FROM `card_transactions.v_users_clean`

GROUP BY per_capita_income

ORDER BY n_users DESC

LIMIT 10;


-- ============================================================
-- CREDIT-CARD COUNT DISTRIBUTION
-- ============================================================

SELECT
    num_credit_cards,
    COUNT(*) AS total_users

FROM `card_transactions.v_users_clean`

GROUP BY num_credit_cards

ORDER BY num_credit_cards;


-- ============================================================
-- FINANCIAL DISTRIBUTION / QUANTILES
-- ============================================================

-- Quartiles and means for yearly income and total debt.
WITH q AS (

    SELECT
        APPROX_QUANTILES(yearly_income, 4) AS yi_q,
        AVG(yearly_income) AS yi_mean,

        APPROX_QUANTILES(total_debt, 4) AS debt_q,
        AVG(total_debt) AS debt_mean

    FROM `card_transactions.v_users_clean`
)

SELECT
    yi_q[OFFSET(0)] AS yi_min,
    yi_q[OFFSET(1)] AS yi_q1,
    yi_q[OFFSET(2)] AS yi_median,
    yi_q[OFFSET(3)] AS yi_q3,
    yi_q[OFFSET(4)] AS yi_max,
    yi_mean,

    debt_q[OFFSET(0)] AS debt_min,
    debt_q[OFFSET(1)] AS debt_q1,
    debt_q[OFFSET(2)] AS debt_median,
    debt_q[OFFSET(3)] AS debt_q3,
    debt_q[OFFSET(4)] AS debt_max,
    debt_mean

FROM q;


-- ============================================================
-- LOW-INCOME / OUTLIER INSPECTION
-- ============================================================

-- Inspect users at the bottom of the yearly-income distribution.
SELECT
    id,
    current_age,
    yearly_income,
    per_capita_income,
    total_debt,
    credit_score

FROM `card_transactions.v_users_clean`

ORDER BY yearly_income ASC

LIMIT 5;


-- Count extremely low yearly-income records.
SELECT
    COUNT(*) AS users_with_yearly_income_below_100

FROM `card_transactions.v_users_clean`

WHERE yearly_income < 100;