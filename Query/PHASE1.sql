SELECT @@VERSION

--1A. Count and percentage of loans in each status category (Active, Defaulted, Overdue, Closed)
SELECT 
    loan_status, 
    COUNT(*) AS loan_count,
    ROUND((COUNT(*) * 100.0) / (SELECT COUNT(*) FROM loans WHERE disbursement_date IS NOT NULL), 2) AS percentage_of_portfolio
FROM 
    loans
WHERE 
    disbursement_date IS NOT NULL
GROUP BY 
    loan_status
ORDER BY 
    loan_count DESC;

SELECT 
    loan_status, 
    COUNT(*) AS loan_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage_of_portfolio
FROM 
    loans
WHERE 
    disbursement_date IS NOT NULL
GROUP BY 
    loan_status
ORDER BY 
    loan_count DESC;

--1B. Total unique customers, total loans, total portfolio value, and average loan size.
SELECT 
    COUNT(DISTINCT customer_id) AS total_unique_customers,
    COUNT(loan_id) AS total_loans,
    SUM(loan_amount) AS total_portfolio_value,
    AVG(loan_amount) AS average_loan_size
FROM 
    loans
WHERE 
    disbursement_date IS NOT NULL;

 --1C. Counts for each risk category using conditional aggregation.
SELECT 
    SUM(CASE WHEN loan_status = 'Active' THEN 1 ELSE 0 END) AS active_count,
    SUM(CASE WHEN loan_status = 'Closed' THEN 1 ELSE 0 END) AS closed_count,
    SUM(CASE WHEN loan_status = 'Defaulted' THEN 1 ELSE 0 END) AS defaulted_count,
    SUM(CASE WHEN loan_status = 'Overdue' THEN 1 ELSE 0 END) AS overdue_count,
    
    -- Calculate Default Rate %
    ROUND(
        SUM(CASE WHEN loan_status = 'Defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS default_rate_pct,
    
    -- Calculate Portfolio At Risk (PAR) % (Defaulted + Overdue)
    ROUND(
        SUM(CASE WHEN loan_status IN ('Defaulted', 'Overdue') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS portfolio_at_risk_pct
FROM 
    loans
WHERE 
    disbursement_date IS NOT NULL;

--1D. Total monetary value at risk for each status category.
SELECT 
    loan_status, 
    SUM(loan_amount) AS total_monetary_value,
    ROUND(SUM(loan_amount) * 100.0 / SUM(SUM(loan_amount)) OVER(), 2) AS percentage_of_total_value
FROM 
    loans
WHERE 
    disbursement_date IS NOT NULL
GROUP BY 
    loan_status
ORDER BY 
    total_monetary_value DESC;

--1E. A single comprehensive view combining all above metrics
SELECT 
    loan_status,
    COUNT(loan_id) AS loan_count,
    ROUND(COUNT(loan_id) * 100.0 / SUM(COUNT(loan_id)) OVER(), 2) AS pct_of_count,
    ROUND(SUM(loan_amount) / 10000000.0, 2) AS value_in_crores,
    ROUND(SUM(loan_amount) * 100.0 / SUM(SUM(loan_amount)) OVER(), 2) AS pct_of_value,
    CASE 
        WHEN loan_status = 'Active' THEN 'Healthy'
        WHEN loan_status = 'Closed' THEN 'Completed'
        WHEN loan_status = 'Defaulted' THEN 'Loss Category'
        WHEN loan_status = 'Overdue' THEN 'High Risk'
    END AS health_classification,
    CASE 
        WHEN loan_status = 'Active' THEN 'Maintain & Monitor'
        WHEN loan_status = 'Closed' THEN 'Incentivize Renewal'
        WHEN loan_status = 'Defaulted' THEN 'Immediate Legal Action'
        WHEN loan_status = 'Overdue' THEN 'Aggressive Collection'
    END AS board_action
FROM 
    loans
WHERE 
    disbursement_date IS NOT NULL
GROUP BY 
    loan_status
ORDER BY 
    loan_count DESC;