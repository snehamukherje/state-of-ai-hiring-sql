# State of AI Hiring 2026 - Pure SQL Analysis

MySQL 8.0 implementation for Assignment 5. The project ingests the supplied AI-jobs CSV, normalizes its pipe-delimited skills into a third-normal-form schema, and answers the required compensation, geography, and salary-tier questions using SQL only.

## Contents

- `data/ai_jobs_market_2025_2026.csv` - supplied source data (1,500 postings)
- `sql/01_schema.sql` - staging and normalized MySQL tables
- `sql/02_load_and_transform.sql` - CSV import plus cleaning and normalization
- `sql/03_analysis.sql` - Parts B and C analysis queries
- `sql/04_executive_summary.sql` - data-driven client-pitch metrics

## Requirements

- MySQL Server 8.0.4 or later (MySQL Workbench is supported)

## Run the project

In MySQL Workbench, open and run the files in this order:

1. Run `sql/01_schema.sql`.
2. Edit the one file path at the top of `sql/02_load_and_transform.sql` to the absolute path to `data/ai_jobs_market_2025_2026.csv`, then run the file.
3. Run `sql/03_analysis.sql` and `sql/04_executive_summary.sql`.

If Workbench reports that `LOCAL INFILE` is disabled, enable it in the connection's **Advanced** settings (`OPT_LOCAL_INFILE=1`) and ensure the MySQL server permits `local_infile`, then reconnect. The CSV can alternatively be imported into `staging_ai_jobs` with Workbench's **Table Data Import Wizard**, then run only the section below `LOAD DATA` in `02_load_and_transform.sql`.

## Design notes

The actual data stores skills with `|` separators, not commas as in the original brief. The ETL uses MySQL's `JSON_TABLE`, followed by `TRIM` and `LOWER`, to create unique skills and the `map_job_skills` junction table. All analytical logic is MySQL SQL; no Python or R is required.

The source contains salary values that can sit outside their stated min/max range. The analysis intentionally uses `annual_salary_usd`, the supplied annual compensation field, without replacing source values.
