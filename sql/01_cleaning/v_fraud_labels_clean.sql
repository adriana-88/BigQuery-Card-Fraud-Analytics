CREATE OR REPLACE VIEW `card_transactions.v_fraud_labels_clean` AS

SELECT
    transaction_id,

    CASE
        WHEN is_fraud = 'Yes' THEN TRUE
        WHEN is_fraud = 'No' THEN FALSE
        ELSE NULL
    END AS is_fraud

FROM `card_transactions.fraud_labels_raw`;