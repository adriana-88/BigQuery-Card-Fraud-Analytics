CREATE OR REPLACE VIEW `card_transactions.v_mcc_codes_clean` AS

SELECT
    mcc_code,
    description

FROM `card_transactions.mcc_codes_raw`;

