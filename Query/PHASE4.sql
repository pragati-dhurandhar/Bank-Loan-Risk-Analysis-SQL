--PHASE 4: Institutional Partnership Risk Analysis

--A.Calculate: Loan volume and total funding per institution,  Identify key partners by size.

SELECT inst.institution_name, COUNT(l.loan_id) AS total_loan_volume,
    CAST(SUM(l.loan_amount) / 10000000.0 AS DECIMAL(10, 2)) AS total_funding_crores,
    
    CAST(AVG(l.loan_amount) / 100000.0 AS DECIMAL(10, 2)) AS avg_ticket_size_lakhs
FROM loans l
JOIN institutions inst ON l.institution_id = inst.institution_id
WHERE l.disbursement_date IS NOT NULL
GROUP BY inst.institution_name
ORDER BY total_funding_crores DESC;

--B.Default rate per university/college, Filter: Minimum 50 loans to ensure statistical significance.

SELECT 
    inst.institution_name,
    COUNT(l.loan_id) AS total_student_loans,
    -- Default Rate Calculation
    CAST(SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(l.loan_id) AS DECIMAL(10, 2) ) AS default_rate_pct,
    -- Average loan amount taken by students of this university (in Lakhs)
    CAST(AVG(l.loan_amount) / 100000.0 AS DECIMAL(10, 2)) AS avg_student_debt_lakhs
FROM loans l
JOIN institutions inst ON l.institution_id = inst.institution_id
WHERE l.disbursement_date IS NOT NULL
GROUP BY inst.institution_name
HAVING COUNT(l.loan_id) >= 50
ORDER BY default_rate_pct DESC;

--C.Total value of defaulted loans attributed to each institution.

SELECT 
    inst.institution_name, CAST(SUM(l.loan_amount) / 10000000.0 AS DECIMAL(10, 2)) AS total_funded_crores,
    
    CAST(SUM(CASE WHEN l.loan_status = 'Defaulted' THEN l.loan_amount ELSE 0 END) / 100000.0 AS DECIMAL(10, 2)) AS defaulted_value_lakhs,
    
    CAST(
        SUM(CASE WHEN l.loan_status = 'Defaulted' THEN l.loan_amount ELSE 0 END) * 100.0 / 
        SUM(SUM(CASE WHEN l.loan_status = 'Defaulted' THEN l.loan_amount ELSE 0 END)) OVER() AS DECIMAL(10, 2)) AS loss_contribution_pct
FROM loans l
JOIN institutions inst ON l.institution_id = inst.institution_id
WHERE l.disbursement_date IS NOT NULL
GROUP BY inst.institution_name
ORDER BY defaulted_value_lakhs DESC;

--D.Categorize partners (Preferred vs. Probation vs. Blacklist), Default rate > 15% = Blacklist Candidate.
SELECT 
    inst.institution_name,
    COUNT(l.loan_id) AS total_loans_processed,
    -- Calculate the Default Rate
    CAST(
        SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(l.loan_id) 
        AS DECIMAL(10, 2)
    ) AS default_rate_pct,
    CASE 
        WHEN (SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(l.loan_id)) > 15 THEN 'BLACKLIST CANDIDATE'
        WHEN (SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(l.loan_id)) BETWEEN 5 AND 15 THEN 'PROBATION'
        ELSE 'PREFERRED PARTNER'
    END AS partnership_status
FROM loans l
JOIN institutions inst ON l.institution_id = inst.institution_id
WHERE l.disbursement_date IS NOT NULL
GROUP BY inst.institution_name
HAVING COUNT(l.loan_id) >= 50 -- Ensure we don't blacklist based on small sample sizes
ORDER BY default_rate_pct DESC;

--E.Comprehensive partner scorecard, Sorting: Highest Default Rate first, REQUIRED Text Summary: List of top 5 institutions to blacklist immediately.

WITH PartnerScorecard AS (
    SELECT 
        inst.institution_name,
        COUNT(l.loan_id) AS total_loans,
        -- Calculate Default Rate
        ROUND(SUM(CASE WHEN l.loan_status = 'Defaulted' THEN 1 ELSE 0 END) * 100.0 / COUNT(l.loan_id), 2) AS default_rate_pct,
        -- Total Loss in Lakhs
        ROUND(SUM(CASE WHEN l.loan_status = 'Defaulted' THEN l.loan_amount ELSE 0 END) / 100000.0, 2) AS total_loss_lakhs,
        -- Total Disbursed in Crores
        ROUND(SUM(l.loan_amount) / 10000000.0, 2) AS total_funding_cr
    FROM loans l
    JOIN institutions inst ON l.institution_id = inst.institution_id
    WHERE l.disbursement_date IS NOT NULL
    GROUP BY inst.institution_name
)
SELECT institution_name, total_loans, total_funding_cr, total_loss_lakhs,
    CAST(default_rate_pct AS DECIMAL(10,2)) AS default_rate_pct,
    CASE 
        WHEN default_rate_pct > 15 THEN 'BLACKLIST'
        WHEN default_rate_pct > 10 THEN 'PROBATION'
        ELSE 'PREFERRED'
    END AS final_status
FROM PartnerScorecard
WHERE total_loans >= 50
ORDER BY default_rate_pct DESC;