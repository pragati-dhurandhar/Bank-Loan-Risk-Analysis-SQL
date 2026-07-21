--PHASE 3: Customer Risk Segmentation

--A.List customers with their basic loan counts and total disbursed amounts.
SELECT 
    cust.customer_id,
    cust.full_name,
    COUNT(l.loan_id) AS total_loan_count,
    ROUND(SUM(l.loan_amount)/ 100000.0, 2) AS total_disbursed_amount_lakhs,
    ROUND(AVG(l.loan_amount)/100000.0, 2) AS average_loan_size_lakhs
FROM customers cust
JOIN loans l ON cust.customer_id = l.customer_id
WHERE l.disbursement_date IS NOT NULL
GROUP BY cust.customer_id, cust.full_name
ORDER BY total_disbursed_amount_lakhs DESC;

--B.Identify customers with at least one defaulted loan.
SELECT 
    cust.customer_id,
    cust.full_name,
    COUNT(l.loan_id) AS total_loans_held,
    -- Count only the loans that are in 'Defaulted' status
    SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) AS defaulted_loan_count,
    -- Total unpaid amount in Lakhs
    CAST(
        SUM(CASE WHEN l.loan_status = 'Defaulted' THEN l.loan_amount ELSE 0 END) / 100000.0 AS DECIMAL(10, 2)) AS total_defaulted_amount_lakhs
FROM customers cust
JOIN loans l ON cust.customer_id = l.customer_id
GROUP BY cust.customer_id, cust.full_name
HAVING SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) >= 1
ORDER BY total_defaulted_amount_lakhs DESC;

--C.Total defaulted amount per customer, Filter: Focus on customers with total default exposure > ₹5 Lakhs
SELECT 
    cust.customer_id,
    cust.full_name,
    -- Count of failed loans
    SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) AS defaulted_loan_count,
    -- Total money at risk in Lakhs
    CAST(
        SUM(CASE WHEN l.loan_status = 'Defaulted' THEN l.loan_amount ELSE 0 END) / 100000.0 AS DECIMAL(10, 2)) AS total_defaulted_amount_lakhs
FROM customers cust
JOIN loans l ON cust.customer_id = l.customer_id
GROUP BY cust.customer_id, cust.full_name
-- FILTER: Only show exposure greater than ₹5 Lakhs
HAVING (SUM(CASE WHEN l.loan_status = 'Defaulted' THEN l.loan_amount ELSE 0 END) / 100000.0) > 5.0
ORDER BY total_defaulted_amount_lakhs DESC;

--D.Calculate: Analyze if certain income brackets or employment types have higher default rates.
SELECT cust.employemnet_type,
    -- Grouping income into brackets for better analysis
    CASE 
        WHEN cust.annual_income < 500000 THEN 'Low Income (<5L)'
        WHEN cust.annual_income BETWEEN 500000 AND 1500000 THEN 'Mid Income (5L-15L)'
        ELSE 'High Income (>15L)'
    END AS income_bracket,
    COUNT(l.loan_id) AS total_loans,
    CAST(SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(l.loan_id) AS DECIMAL(10, 2)) AS default_rate_pct
FROM customers cust
JOIN loans l ON cust.customer_id = l.customer_id
WHERE l.disbursement_date IS NOT NULL
GROUP BY cust.employemnet_type,annual_income
ORDER BY default_rate_pct DESC;

--E.Final ranked list of customers for immediate action, Assign 'Priority Score' based on Default Amount + CIBIL Score.
SELECT cust.customer_id, cust.full_name, cust.cibil_score,
    -- Defaulted amount in Lakhs
    CAST(SUM(CASE WHEN l.loan_status = 'Defaulted' THEN l.loan_amount ELSE 0 END) / 100000.0 AS DECIMAL(10, 2)) AS total_defaulted_lakhs,
    -- PRIORITY SCORE CALCULATION
    -- Higher score = Higher priority. 
    -- We penalize low CIBIL scores and reward high defaulted amounts.
    ROUND((SUM(CASE WHEN l.loan_status = 'Defaulted' THEN l.loan_amount ELSE 0 END) / 100000.0) * (1000 - cust.cibil_score), 0) AS collection_priority_score
FROM customers cust
JOIN loans l ON cust.customer_id = l.customer_id
GROUP BY cust.customer_id, cust.full_name, cust.cibil_score
HAVING SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) >= 1
ORDER BY collection_priority_score DESC;