CREATE OR REPLACE VIEW `card_transactions.v_users_clean` AS

SELECT
    id,

    -- Demographics
    SAFE_CAST(current_age AS INT64) AS current_age,
    SAFE_CAST(retirement_age AS INT64) AS retirement_age,
    SAFE_CAST(birth_year AS INT64) AS birth_year,
    SAFE_CAST(birth_month AS INT64) AS birth_month,
    gender,

    -- Location
    address,
    SAFE_CAST(latitude AS FLOAT64) AS latitude,
    SAFE_CAST(longitude AS FLOAT64) AS longitude,

    SAFE.ST_GEOGPOINT(
        SAFE_CAST(longitude AS FLOAT64),
        SAFE_CAST(latitude AS FLOAT64)
    ) AS home_geo,

    -- Financial attributes
    SAFE_CAST(
        REPLACE(per_capita_income, '$', '')
        AS NUMERIC
    ) AS per_capita_income,

    SAFE_CAST(
        REPLACE(yearly_income, '$', '')
        AS NUMERIC
    ) AS yearly_income,

    SAFE_CAST(
        REPLACE(total_debt, '$', '')
        AS NUMERIC
    ) AS total_debt,

    SAFE_CAST(credit_score AS INT64) AS credit_score,
    SAFE_CAST(num_credit_cards AS INT64) AS num_credit_cards

FROM `card_transactions.users_raw`;