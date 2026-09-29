CREATE OR REPLACE VIEW `card_transactions.v_transactions_clean` AS

SELECT
    id,

    -- Source datetime contains no timezone information.
    -- Parsed as TIMESTAMP for analytical convenience;
    -- hour-based analysis uses the source-recorded clock time.
    SAFE_CAST(date AS TIMESTAMP) AS txn_date,

    client_id,
    card_id,

    SAFE_CAST(
        REPLACE(amount, '$', '')
        AS NUMERIC
    ) AS amount,

    use_chip,
    merchant_id,
    merchant_city,
    merchant_state,

    FORMAT(
        '%05d',
        SAFE_CAST(
            SAFE_CAST(zip AS FLOAT64)
            AS INT64
        )
    ) AS zip,

    mcc,

    NULLIF(TRIM(errors), '') AS errors,

    -- Flags derived from source semantics / EDA findings
    use_chip = 'Online Transaction'
        AS is_online,

    NULLIF(TRIM(errors), '') IS NOT NULL
        AS has_error,

    (
        use_chip != 'Online Transaction'
        AND merchant_city = 'ONLINE'
    ) AS is_location_anomaly,

    (
        merchant_state IS NOT NULL
        AND NOT REGEXP_CONTAINS(
            merchant_state,
            r'^[A-Z]{2}$'
        )
    ) AS is_international

FROM `card_transactions.transactions_raw`;


