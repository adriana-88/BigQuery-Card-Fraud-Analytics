##Project anchor numbers

SELECT
    COUNT(*) AS total_transactions,
    COUNTIF(fraud_status = 'Fraud') AS fraud_transactions,
    COUNTIF(fraud_status = 'Legit') AS legit_transactions,
    COUNTIF(fraud_status = 'Unlabeled') AS unlabeled_transactions,
    COUNTIF(fraud_status != 'Unlabeled') AS labeled_transactions,
    SAFE_DIVIDE(
        COUNTIF(fraud_status != 'Unlabeled'),
        COUNT(*)
    ) AS label_coverage,
    MIN(txn_date) AS first_transaction,
    MAX(txn_date) AS last_transaction
FROM `card_transactions.fct_transactions`;

##Fraud by year
SELECT
    year,
    total_transactions,
    total_labeled,
    number_of_frauds_this_year,
    fraud_rate_labeled,
    label_coverage_rate
FROM `card_transactions.agg_yearly_summary`
ORDER BY year;

##Fraud by channel × year
SELECT
    EXTRACT(YEAR FROM txn_date) AS year,
    use_chip,
    COUNT(*) AS total_transactions,
    COUNTIF(fraud_status != 'Unlabeled') AS total_labeled,
    COUNTIF(fraud_status = 'Fraud') AS total_frauds,

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


##Your MCC fraud-lift result
with labels_purchases_mcc as(

    select mcc,
           description,
           count(*) as total_transactions,
           countif(fraud_status!='Unlabeled') as total_labeled,
           countif(fraud_status='Legit') as total_legit,
           countif(fraud_status='Fraud') as total_frauds
    from card_transactions.fct_transactions
    where amount >0
    group by mcc, description
),

rates as(

select*, safe_divide(total_frauds, total_labeled) as fraud_rate_labeled,
      safe_divide(total_labeled, total_transactions) as label_coverage_rate,
      sum(total_labeled) over () as all_labeled_transactions,
      sum(total_frauds) over () as all_fraud_transactions
from labels_purchases_mcc

)
select *,
       safe_divide(total_labeled,all_labeled_transactions) as labeled_transaction_share,
       safe_divide(total_frauds,all_fraud_transactions) as fraud_share,
       SAFE_DIVIDE(
         SAFE_DIVIDE(total_frauds, all_fraud_transactions),
         SAFE_DIVIDE(total_labeled, all_labeled_transactions)
        ) AS fraud_lift
from rates
where total_labeled >=250
order by fraud_lift desc;
    