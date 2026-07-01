-- ============================================================================
-- TELCO CUSTOMER CHURN ANALYSIS
-- Data cleaning + churn/connect rate analysis by segment, tenure, contract type
--
-- Source data: Telco_churn_CSV.csv (7,043 rows, 33 columns)
-- Written for a standard SQL database (PostgreSQL/MySQL/SQL Server syntax;
-- minor adjustments may be needed for CASE/date syntax on some engines).
-- ============================================================================


-- ============================================================================
-- SECTION 0: TABLE SETUP
-- Assumes the raw CSV has already been loaded into a staging table
-- called `customers_raw` with all columns typed as TEXT/VARCHAR.
-- ============================================================================

-- Example load (adjust to your DB's bulk-load syntax):
-- COPY customers_raw FROM 'Telco_churn_CSV.csv' WITH (FORMAT csv, HEADER true);


-- ============================================================================
-- SECTION 1: DATA QUALITY CHECKS
-- Run these before cleaning to confirm the issues found in the initial audit.
-- ============================================================================

-- 1a. Row count and basic shape
SELECT COUNT(*) AS total_rows FROM customers_raw;

-- 1b. Duplicate CustomerIDs (should be 0)
SELECT "CustomerID", COUNT(*) AS n
FROM customers_raw
GROUP BY "CustomerID"
HAVING COUNT(*) > 1;

-- 1c. Fully duplicate rows (should be 0)
SELECT "CustomerID", COUNT(*) AS n
FROM customers_raw
GROUP BY ALL  -- or list every column explicitly if your engine doesn't support GROUP BY ALL
HAVING COUNT(*) > 1;

-- 1d. "Total Charges" blank/non-numeric rows
SELECT "CustomerID", "Tenure Months", "Total Charges"
FROM customers_raw
WHERE "Total Charges" IS NULL OR TRIM("Total Charges") = '';

-- 1e. Confirm every blank Total Charges row has zero tenure
SELECT COUNT(*) AS unexpected_rows
FROM customers_raw
WHERE (TRIM("Total Charges") = '' OR "Total Charges" IS NULL)
  AND "Tenure Months" <> 0;
-- Expect 0 rows back. If not, the blanks aren't purely a "brand new customer" artifact.

-- 1f. "Churn Reason" missing values, and confirm they align with non-churned customers
SELECT "Churn Label", COUNT(*) AS n,
       SUM(CASE WHEN "Churn Reason" IS NULL THEN 1 ELSE 0 END) AS missing_reason
FROM customers_raw
GROUP BY "Churn Label";

-- 1g. Constant / low-value columns
SELECT DISTINCT "Count" FROM customers_raw;
SELECT DISTINCT "Country" FROM customers_raw;
SELECT DISTINCT "State" FROM customers_raw;

-- 1h. Redundant target encoding (Churn Label vs Churn Value)
SELECT "Churn Label", "Churn Value", COUNT(*) AS n
FROM customers_raw
GROUP BY "Churn Label", "Churn Value";

-- 1i. Placeholder categories dependent on another column
SELECT "Internet Service", "Online Security", COUNT(*) AS n
FROM customers_raw
GROUP BY "Internet Service", "Online Security"
ORDER BY 1, 2;

SELECT "Phone Service", "Multiple Lines", COUNT(*) AS n
FROM customers_raw
GROUP BY "Phone Service", "Multiple Lines"
ORDER BY 1, 2;


-- ============================================================================
-- SECTION 2: CLEANING
-- Builds a cleaned table `customers` from `customers_raw`.
-- ============================================================================

DROP TABLE IF EXISTS customers;

CREATE TABLE customers AS
SELECT
    "CustomerID",
    "Count",
    "Country",
    "State",
    "City",
    "Zip Code",
    "Lat Long",
    "Latitude",
    "Longitude",
    "Gender",
    "Senior Citizen",
    "Partner",
    "Dependents",
    "Tenure Months",
    "Phone Service",

    -- Fix: collapse "No phone service" into "No" (perfectly redundant with Phone Service = 'No')
    CASE WHEN "Multiple Lines" = 'No phone service' THEN 'No' ELSE "Multiple Lines" END AS "Multiple Lines",

    "Internet Service",

    -- Fix: collapse "No internet service" into "No" for all six dependent columns
    -- (perfectly redundant with Internet Service = 'No')
    CASE WHEN "Online Security" = 'No internet service' THEN 'No' ELSE "Online Security" END AS "Online Security",
    CASE WHEN "Online Backup" = 'No internet service' THEN 'No' ELSE "Online Backup" END AS "Online Backup",
    CASE WHEN "Device Protection" = 'No internet service' THEN 'No' ELSE "Device Protection" END AS "Device Protection",
    CASE WHEN "Tech Support" = 'No internet service' THEN 'No' ELSE "Tech Support" END AS "Tech Support",
    CASE WHEN "Streaming TV" = 'No internet service' THEN 'No' ELSE "Streaming TV" END AS "Streaming TV",
    CASE WHEN "Streaming Movies" = 'No internet service' THEN 'No' ELSE "Streaming Movies" END AS "Streaming Movies",

    "Contract",
    "Paperless Billing",
    "Payment Method",
    "Monthly Charges",

    -- Fix: cast Total Charges to numeric; blank values (all zero-tenure customers
    -- who haven't been billed yet) are set to 0 rather than left null, so
    -- SUM/AVG/charting behave correctly downstream.
    CAST(
        CASE WHEN TRIM("Total Charges") = '' THEN '0' ELSE "Total Charges" END
    AS DECIMAL(10,2)) AS "Total Charges",

    "Churn Label",
    "Churn Value",
    "Churn Score",
    "CLTV",

    -- Fix: nulls here mean "customer never churned," not "unknown" — made explicit
    COALESCE("Churn Reason", 'Not Applicable') AS "Churn Reason"

FROM customers_raw;

-- Note: Count, Country, State, and Churn Label/Churn Value are left in place
-- (not dropped) in case future data loads introduce variation in these fields.


-- ============================================================================
-- SECTION 3: CHURN ANALYSIS
-- ============================================================================

-- 3.1 Churn rate by contract type
SELECT
    "Contract",
    COUNT(*) AS total_customers,
    SUM("Churn Value") AS churned_customers,
    ROUND(100.0 * SUM("Churn Value") / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY "Contract"
ORDER BY churn_rate_pct DESC;


-- 3.2 Churn rate by tenure bucket
SELECT
    CASE
        WHEN "Tenure Months" <= 6 THEN '0-6 mo'
        WHEN "Tenure Months" <= 12 THEN '7-12 mo'
        WHEN "Tenure Months" <= 24 THEN '13-24 mo'
        WHEN "Tenure Months" <= 48 THEN '25-48 mo'
        ELSE '49-72 mo'
    END AS tenure_bucket,
    COUNT(*) AS total_customers,
    SUM("Churn Value") AS churned_customers,
    ROUND(100.0 * SUM("Churn Value") / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY tenure_bucket
ORDER BY
    CASE tenure_bucket
        WHEN '0-6 mo' THEN 1
        WHEN '7-12 mo' THEN 2
        WHEN '13-24 mo' THEN 3
        WHEN '25-48 mo' THEN 4
        ELSE 5
    END;


-- 3.3 Contract x Tenure interaction
-- (the headline finding: contract type drives churn independent of tenure)
SELECT
    "Contract",
    CASE
        WHEN "Tenure Months" <= 12 THEN '0-12 mo'
        WHEN "Tenure Months" <= 24 THEN '13-24 mo'
        ELSE '25+ mo'
    END AS tenure_bucket,
    COUNT(*) AS total_customers,
    SUM("Churn Value") AS churned_customers,
    ROUND(100.0 * SUM("Churn Value") / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY "Contract", tenure_bucket
ORDER BY "Contract",
    CASE tenure_bucket WHEN '0-12 mo' THEN 1 WHEN '13-24 mo' THEN 2 ELSE 3 END;


-- 3.4 Churn rate by customer segment (Senior Citizen / Partner / Dependents)
SELECT
    "Senior Citizen",
    "Partner",
    "Dependents",
    COUNT(*) AS total_customers,
    SUM("Churn Value") AS churned_customers,
    ROUND(100.0 * SUM("Churn Value") / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY "Senior Citizen", "Partner", "Dependents"
ORDER BY churn_rate_pct DESC;


-- 3.5 Churn rate by internet service type
SELECT
    "Internet Service",
    COUNT(*) AS total_customers,
    SUM("Churn Value") AS churned_customers,
    ROUND(100.0 * SUM("Churn Value") / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY "Internet Service"
ORDER BY churn_rate_pct DESC;


-- 3.6 Churn rate by payment method
SELECT
    "Payment Method",
    COUNT(*) AS total_customers,
    SUM("Churn Value") AS churned_customers,
    ROUND(100.0 * SUM("Churn Value") / COUNT(*), 2) AS churn_rate_pct
FROM customers
GROUP BY "Payment Method"
ORDER BY churn_rate_pct DESC;


-- 3.7 Top stated reasons for churn (excludes customers who didn't churn)
SELECT
    "Churn Reason",
    COUNT(*) AS customers,
    ROUND(100.0 * COUNT(*) / (SELECT SUM("Churn Value") FROM customers), 2) AS pct_of_churned
FROM customers
WHERE "Churn Reason" != 'Not Applicable'
GROUP BY "Churn Reason"
ORDER BY customers DESC
LIMIT 10;


-- 3.8 Average monthly charges and tenure: churned vs. retained
SELECT
    "Churn Label",
    COUNT(*) AS customers,
    ROUND(AVG("Monthly Charges"), 2) AS avg_monthly_charges,
    ROUND(AVG("Tenure Months"), 1) AS avg_tenure_months
FROM customers
GROUP BY "Churn Label";


-- 3.9 Headline KPIs (overall churn rate, CLTV at risk)
SELECT
    COUNT(*) AS total_customers,
    SUM("Churn Value") AS churned_customers,
    ROUND(100.0 * SUM("Churn Value") / COUNT(*), 2) AS overall_churn_rate_pct,
    SUM(CASE WHEN "Churn Value" = 1 THEN "CLTV" ELSE 0 END) AS cltv_at_risk
FROM customers;

-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
