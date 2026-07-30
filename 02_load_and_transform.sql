-- Run in MySQL Workbench after sql/01_schema.sql.
-- Change this path to the absolute path of data/ai_jobs_market_2025_2026.csv.
-- The CSV supplied for this assignment uses pipe-delimited required_skills.

USE ai_hiring_2026;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE map_job_skills;
TRUNCATE TABLE fact_job_postings;
TRUNCATE TABLE dim_skills;
TRUNCATE TABLE dim_company;
TRUNCATE TABLE staging_ai_jobs;
SET FOREIGN_KEY_CHECKS = 1;

LOAD DATA LOCAL INFILE '/REPLACE/WITH/YOUR/ABSOLUTE/PATH/ai_jobs_market_2025_2026.csv'
INTO TABLE staging_ai_jobs
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- Dimension first, ensuring whitespace and case variations do not create duplicates.
INSERT INTO dim_company (company_size_name)
SELECT DISTINCT TRIM(company_size)
FROM staging_ai_jobs
WHERE NULLIF(TRIM(company_size), '') IS NOT NULL
ORDER BY company_size_name;

INSERT INTO fact_job_postings (
    job_id, job_title, job_category, experience_level, years_of_experience,
    education_required, annual_salary_usd, salary_min_usd, salary_max_usd,
    city, country, remote_work, company_size_id, industry,
    ai_salary_premium_pct, demand_score, demand_growth_yoy_pct, benefits_score_10,
    posting_year, posting_month, is_senior, is_remote_friendly, is_llm_role, salary_tier
)
SELECT
    TRIM(s.job_id), TRIM(s.job_title), TRIM(s.job_category), TRIM(s.experience_level),
    s.years_of_experience, TRIM(s.education_required), s.annual_salary_usd,
    s.salary_min_usd, s.salary_max_usd, TRIM(s.city), TRIM(s.country),
    TRIM(s.remote_work), c.company_size_id, TRIM(s.industry),
    s.ai_salary_premium_pct, s.demand_score, s.demand_growth_yoy_pct, s.benefits_score_10,
    s.posting_year, s.posting_month, IF(s.is_senior <> 0, TRUE, FALSE),
    IF(s.is_remote_friendly <> 0, TRUE, FALSE), IF(s.is_llm_role <> 0, TRUE, FALSE),
    TRIM(s.salary_tier)
FROM staging_ai_jobs AS s
JOIN dim_company AS c ON c.company_size_name = TRIM(s.company_size)
WHERE NULLIF(TRIM(s.job_id), '') IS NOT NULL;

INSERT INTO dim_skills (skill_name)
SELECT DISTINCT TRIM(LOWER(j.raw_skill))
FROM staging_ai_jobs AS s
JOIN JSON_TABLE(
    CONCAT('["', REPLACE(REPLACE(s.required_skills, '\\', '\\\\'), '|', '","'), '"]'),
    '$[*]' COLUMNS (raw_skill VARCHAR(100) PATH '$')
) AS j ON 1 = 1
WHERE NULLIF(TRIM(j.raw_skill), '') IS NOT NULL
ORDER BY 1;

INSERT INTO map_job_skills (job_id, skill_id)
SELECT DISTINCT f.job_id, k.skill_id
FROM staging_ai_jobs AS s
JOIN fact_job_postings AS f ON f.job_id = TRIM(s.job_id)
JOIN JSON_TABLE(
    CONCAT('["', REPLACE(REPLACE(s.required_skills, '\\', '\\\\'), '|', '","'), '"]'),
    '$[*]' COLUMNS (raw_skill VARCHAR(100) PATH '$')
) AS j ON 1 = 1
JOIN dim_skills AS k ON k.skill_name = TRIM(LOWER(j.raw_skill))
WHERE NULLIF(TRIM(j.raw_skill), '') IS NOT NULL;

-- ETL acceptance checks: expected results are 1,500 jobs and zero orphan skill mappings.
SELECT COUNT(*) AS loaded_job_postings FROM fact_job_postings;
SELECT COUNT(*) AS normalized_skills FROM dim_skills;
SELECT COUNT(*) AS job_skill_mappings FROM map_job_skills;
SELECT COUNT(*) AS orphan_skill_mappings
FROM map_job_skills AS m
LEFT JOIN fact_job_postings AS f ON f.job_id = m.job_id
WHERE f.job_id IS NULL;
