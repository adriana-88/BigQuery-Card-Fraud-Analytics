CREATE OR REPLACE VIEW `card_transactions.v_cards_clean` AS

SELECT
    id,
    client_id,
    card_brand,
    card_type,

    -- Sensitive source fields retained in Silver only
    card_number,

    -- Source provides expiry as month/year.
    -- Represent the card as valid through the end of that month.
    LAST_DAY(
        SAFE.PARSE_DATE('%m/%Y', expires),
        MONTH
    ) AS expires,

    cvv,

    CASE
        WHEN has_chip = 'YES' THEN TRUE
        WHEN has_chip = 'NO' THEN FALSE
        ELSE NULL
    END AS has_chip,

    SAFE_CAST(
        num_cards_issued AS INT64
    ) AS num_cards_issued,

    SAFE_CAST(
        REPLACE(credit_limit, '$', '')
        AS NUMERIC
    ) AS credit_limit,

    -- Source contains only month/year.
    -- Parsed date therefore represents the first day of that month.
    SAFE.PARSE_DATE(
        '%m/%Y',
        acct_open_date
    ) AS acct_open_date,

    SAFE_CAST(
        year_pin_last_changed AS INT64
    ) AS year_pin_last_changed,

    CASE
        WHEN card_on_dark_web = 'Yes' THEN TRUE
        WHEN card_on_dark_web = 'No' THEN FALSE
        ELSE NULL
    END AS card_on_dark_web

FROM `card_transactions.cards_raw`;