-- =========================================================
-- Final Fraud Analysis
-- =========================================================
-- Dataset contains Fraud, Legit, and Unlabeled transactions.
-- Fraud rates below use labeled transactions as the denominator.
-- =========================================================


-- =========================================================
-- 1. FRAUD PREVALENCE BY YEAR
-- =========================================================
-- Question:
-- Does fraud prevalence vary over time, and could changes in
-- label coverage explain the pattern?

SELECT
    year,
    total_transactions,
    total_labeled,
    number_of_frauds_this_year,
    fraud_rate_labeled,
    label_coverage_rate

FROM `card_transactions.agg_yearly_summary`

ORDER BY year;



-- =========================================================
-- 2. FRAUD BY TRANSACTION CHANNEL AND YEAR
-- =========================================================
-- Question:
-- Is the higher overall fraud rate for Online transactions
-- consistent across years, or driven by particular periods?

SELECT
    EXTRACT(YEAR FROM txn_date) AS year,
    use_chip,

    COUNT(*) AS total_transactions,

    COUNTIF(
        fraud_status != 'Unlabeled'
    ) AS total_labeled,

    COUNTIF(
        fraud_status = 'Fraud'
    ) AS total_frauds,

    SAFE_DIVIDE(
        COUNTIF(fraud_status = 'Fraud'),
        COUNTIF(fraud_status != 'Unlabeled')
    ) AS fraud_rate_labeled,

    SAFE_DIVIDE(
        COUNTIF(fraud_status != 'Unlabeled'),
        COUNT(*)
    ) AS label_coverage_rate

FROM `card_transactions.fct_transactions`

GROUP BY
    year,
    use_chip

ORDER BY
    year,
    use_chip;



-- =========================================================
-- 3. MCC FRAUD LIFT
-- =========================================================
-- Question:
-- Which merchant categories account for more fraud than
-- expected given their share of labeled purchase activity?
--
-- Positive-value purchases only.
-- Categories require at least 250 labeled purchases to reduce
-- the influence of very small samples.

WITH labels_purchases_mcc AS (

    SELECT
        mcc,
        description,

        COUNT(*) AS total_transactions,

        COUNTIF(
            fraud_status != 'Unlabeled'
        ) AS total_labeled,

        COUNTIF(
            fraud_status = 'Legit'
        ) AS total_legit,

        COUNTIF(
            fraud_status = 'Fraud'
        ) AS total_frauds

    FROM `card_transactions.fct_transactions`

    WHERE amount > 0

    GROUP BY
        mcc,
        description
),

rates AS (

    SELECT
        *,

        SAFE_DIVIDE(
            total_frauds,
            total_labeled
        ) AS fraud_rate_labeled,

        SAFE_DIVIDE(
            total_labeled,
            total_transactions
        ) AS label_coverage_rate,

        SUM(total_labeled) OVER ()
            AS all_labeled_transactions,

        SUM(total_frauds) OVER ()
            AS all_fraud_transactions

    FROM labels_purchases_mcc
)

SELECT
    mcc,
    description,
    total_transactions,
    total_labeled,
    total_frauds,
    fraud_rate_labeled,
    label_coverage_rate,

    SAFE_DIVIDE(
        total_labeled,
        all_labeled_transactions
    ) AS labeled_transaction_share,

    SAFE_DIVIDE(
        total_frauds,
        all_fraud_transactions
    ) AS fraud_share,

    SAFE_DIVIDE(
        SAFE_DIVIDE(
            total_frauds,
            all_fraud_transactions
        ),
        SAFE_DIVIDE(
            total_labeled,
            all_labeled_transactions
        )
    ) AS fraud_lift

FROM rates

WHERE total_labeled >= 250

ORDER BY fraud_lift DESC;



-- =========================================================
-- 4. YEAR-LEVEL CONTEXT FOR SELECTED HIGH-LIFT MCCs
-- =========================================================
-- Aggregate MCC results are interpreted alongside year-level
-- results because fraud prevalence varies substantially over time.

SELECT
    year,
    mcc,
    description,
    total_transactions,
    total_labeled,
    number_of_frauds_this_mcc_year,
    fraud_rate_labeled,
    label_coverage_rate

FROM `card_transactions.agg_mcc_yearly_summary`

WHERE mcc IN (
    '5732', -- Electronics Stores
    '5094', -- Precious Stones and Metals
    '5815', -- Digital Goods
    '5651', -- Family Clothing Stores
    '5311'  -- Department Stores
)

ORDER BY
    mcc,
    year;