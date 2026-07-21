--Phase 2

--A.number of customers and loans per city

SELECT city_name, COUNT(DISTINCT cust.customer_id) AS number_of_customers, COUNT(DISTINCT l.loan_id) AS number_of_loans
FROM loans l
JOIN customers cust ON l.customer_id = cust.customer_id
JOIN dim_city c ON cust.city_id = c.city_id
WHERE l.disbursement_date IS NOT NULL
GROUP BY city_name;

--B.default rates by city, Exclude cities with low volume (<100 loans) to avoid statistical noise.

SELECT  city_name, 
		COUNT(l.loan_id) AS total_loan,
		SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) AS defaulted_loans,
		CAST(ROUND(SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END)*100.0/COUNT(l.loan_id),2) AS DECIMAL (10,2)) AS default_rate_percentage
FROM loans l
JOIN customers cust ON l.customer_id = cust.customer_id
JOIN dim_city c ON cust.city_id = c.city_id
WHERE l.disbursement_date IS NOT NULL
GROUP BY city_name
HAVING COUNT(l.loan_id) >= 100
ORDER BY default_rate_percentage DESC;

--C.Total portfolio value and total defaulted value per city, Convert huge sums to Crores/Lakhs.

SELECT c.city_name,
-- Total Portfolio Value in Crores
    ROUND(SUM(l.loan_amount) / 10000000.0, 2) AS total_portfolio_crores,
    
-- Total Money Lost (Defaulted) in Crores
    ROUND(SUM(CASE WHEN l.loan_status = 'Defaulted' THEN l.loan_amount ELSE 0 END) / 10000000.0, 2) AS total_defaulted_crores
FROM loans l
JOIN customers cust ON l.customer_id = cust.customer_id
JOIN dim_city c ON cust.city_id = c.city_id
WHERE l.disbursement_date IS NOT NULL
GROUP BY c.city_name
ORDER BY total_defaulted_crores DESC;

--D. Classify cities as 'Critical', 'High Risk', 'Monitor', or 'Safe' based on default rates, Rules: defaults > 15% = Critical, > 10% = High Risk.

SELECT 
    c.city_name,
    ROUND(
        SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(l.loan_id), 2
    ) AS default_rate_pct,
    
    CASE 
        WHEN (SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(l.loan_id)) > 15 THEN 'CRITICAL'
        WHEN (SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(l.loan_id)) > 10 THEN 'HIGH RISK'
        WHEN (SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(l.loan_id)) > 5 THEN 'MONITOR'
        ELSE 'SAFE'
    END AS risk_tier
FROM loans l
JOIN customers cust ON l.customer_id = cust.customer_id
JOIN dim_city c ON cust.city_id = c.city_id
WHERE l.disbursement_date IS NOT NULL
GROUP BY c.city_name
ORDER BY default_rate_pct DESC;

--E. Comprehensive city-level dashboard combining volume, risk, and financial impact, Sorting: Sort by "Total Losses" (Defaulted Value), Recommend 3 cities to halt lending in immediately.

WITH CityMetrics AS (
    SELECT 
        c.city_name,
        COUNT(l.loan_id) AS loan_volume,
        ROUND(SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(l.loan_id), 2) AS default_rate,
        ROUND(SUM(l.loan_amount) / 10000000.0, 2) AS portfolio_cr,
        ROUND(SUM(CASE WHEN l.loan_status = 'Defaulted' THEN l.loan_amount ELSE 0 END) / 10000000.0, 2) AS losses_cr
    FROM loans l
    JOIN customers cust ON l.customer_id = cust.customer_id
    JOIN dim_city c ON cust.city_id = c.city_id
    WHERE l.disbursement_date IS NOT NULL
    GROUP BY c.city_name
)
SELECT 
    city_name, loan_volume, default_rate, portfolio_cr, losses_cr,
    CASE 
        WHEN default_rate > 15 THEN 'CRITICAL'
        WHEN default_rate > 10 THEN 'HIGH RISK'
        WHEN default_rate > 5 THEN 'MONITOR'
        ELSE 'SAFE'
    END AS risk_class
FROM CityMetrics
ORDER BY losses_cr DESC;