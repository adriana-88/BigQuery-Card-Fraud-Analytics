CREATE OR REPLACE TABLE `card_transactions.fct_transactions` AS

SELECT
    -- Transaction identifiers and measures
    t.id,
    t.txn_date,
    t.amount,

    -- Customer attributes
    t.client_id,
    u.credit_score,
    u.num_credit_cards,
    u.current_age,
    u.gender,
    u.address,
    u.per_capita_income,
    u.yearly_income,
    u.birth_month,
    u.birth_year,
    u.total_debt,
    u.retirement_age,

    -- Card attributes
    t.card_id,
    c.acct_open_date,
    c.card_brand,
    c.card_type,
    c.credit_limit,
    c.expires,
    c.has_chip,
    c.num_cards_issued,
    c.card_on_dark_web,

    -- Merchant category
    t.mcc,
    m.description,

    -- Transaction characteristics
    t.errors,
    t.has_error,
    t.is_online,
    t.use_chip,
    t.merchant_id,
    t.merchant_city,
    t.merchant_state,
    t.zip,
    t.is_international,
    t.is_location_anomaly,

    -- Customer geography
    u.home_geo,
    u.latitude,
    u.longitude,

    -- Fraud label
    CASE
        WHEN f.is_fraud IS TRUE THEN 'Fraud'
        WHEN f.is_fraud IS FALSE THEN 'Legit'
        ELSE 'Unlabeled'
    END AS fraud_status

FROM `card_transactions.v_transactions_clean` AS t

LEFT JOIN `card_transactions.v_users_clean` AS u
    ON t.client_id = u.id

LEFT JOIN `card_transactions.v_cards_clean` AS c
    ON t.card_id = c.id

LEFT JOIN `card_transactions.v_mcc_codes_clean` AS m
    ON t.mcc = m.mcc_code

LEFT JOIN `card_transactions.v_fraud_labels_clean` AS f
    ON t.id = f.transaction_id;