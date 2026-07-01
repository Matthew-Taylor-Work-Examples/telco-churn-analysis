Telco Customer Churn Analysis
A SQL-driven analysis of customer churn for a telecom provider, built as a portfolio
project to demonstrate data cleaning, exploratory analysis, and dashboard design
end to end.

What this is
7,043 customer records were audited for data quality issues, cleaned, and analyzed
in SQL to answer one question: what actually drives churn? The standout finding —
contract type, not tenure, is the dominant factor — is visualized in an interactive
dashboard and summarized for a non-technical audience.
Key finding
Month-to-month customers churn at 42.7%, versus 11.3% for one-year and
2.8% for two-year contracts — and that gap holds even among long-tenured
customers. Tenure alone looked predictive at first, but that was mostly because new
customers are disproportionately on month-to-month plans.
Repo contents
File	What it is
`telco_churn_dashboard.html`	Interactive dashboard — filterable by contract, internet service, payment method, and household segment. Single file, no build step.
`telco_churn_analysis.sql`	Full SQL script: data quality checks, cleaning logic, and every query behind the analysis.
`Churn_Executive_Summary.docx`	One-page summary written for a leadership audience.
`Telco_churn_CSV.csv`	Source data.
How to view it
Dashboard: open `telco_churn_dashboard.html` directly in a browser, or visit the
GitHub Pages link above.
SQL: run `telco_churn_analysis.sql` against a Postgres/MySQL/SQL Server
instance loaded with the source CSV, or just read through it — it's commented
section by section.
Tools
SQL (analysis), Python/pandas (data cleaning), HTML/CSS/JS + Chart.js (dashboard).
