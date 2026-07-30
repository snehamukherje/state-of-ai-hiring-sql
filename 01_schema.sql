-- Assignment 5: Pure SQL implementation (MySQL 8.0.4+)
-- Creates a raw landing table and a normalized 3NF reporting model.

CREATE DATABASE IF NOT EXISTS ai_hiring_2026;
USE ai_hiring_2026;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS map_job_skills;
DROP TABLE IF EXISTS fact_job_postings;
DROP TABLE IF EXISTS dim_skills;
DROP TABLE IF EXISTS dim_company;
DROP TABLE IF EXISTS staging_ai_jobs;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE staging_ai_jobs (
    job_id                  VARCHAR(50),
    job_title               VARCHAR(200),
    job_category            VARCHAR(100),
    experience_level        VARCHAR(50),
    years_of_experience     INTEGER,
    education_required      VARCHAR(100),
    annual_salary_usd       DECIMAL(12, 2),
    salary_min_usd          DECIMAL(12, 2),
    salary_max_usd          DECIMAL(12, 2),
    city                    VARCHAR(100),
    country                 VARCHAR(100),
    remote_work             VARCHAR(50),
    company_size            VARCHAR(50),
    industry                VARCHAR(100),
    required_skills         TEXT,
    ai_salary_premium_pct   DECIMAL(6, 2),
    demand_score            INTEGER,
    demand_growth_yoy_pct   DECIMAL(6, 2),
    benefits_score_10       DECIMAL(4, 2),
    posting_year            INTEGER,
    posting_month           INTEGER,
    is_senior               INTEGER,
    is_remote_friendly      INTEGER,
    is_llm_role             INTEGER,
    salary_tier             VARCHAR(100)
);

CREATE TABLE dim_company (
    company_size_id   SMALLINT AUTO_INCREMENT PRIMARY KEY,
    company_size_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE dim_skills (
    skill_id   INT AUTO_INCREMENT PRIMARY KEY,
    skill_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE fact_job_postings (
    job_id                VARCHAR(50) PRIMARY KEY,
    job_title             VARCHAR(200) NOT NULL,
    job_category          VARCHAR(100) NOT NULL,
    experience_level      VARCHAR(50),
    years_of_experience   INTEGER CHECK (years_of_experience >= 0),
    education_required    VARCHAR(100),
    annual_salary_usd     NUMERIC(12, 2) NOT NULL CHECK (annual_salary_usd > 0),
    salary_min_usd        NUMERIC(12, 2),
    salary_max_usd        NUMERIC(12, 2),
    city                  VARCHAR(100),
    country               VARCHAR(100),
    remote_work           VARCHAR(50),
    company_size_id       SMALLINT NOT NULL,
    industry              VARCHAR(100),
    ai_salary_premium_pct DECIMAL(6, 2),
    demand_score          INTEGER,
    demand_growth_yoy_pct DECIMAL(6, 2),
    benefits_score_10     DECIMAL(4, 2),
    posting_year          INTEGER,
    posting_month         INTEGER CHECK (posting_month BETWEEN 1 AND 12),
    is_senior             BOOLEAN NOT NULL,
    is_remote_friendly    BOOLEAN NOT NULL,
    is_llm_role           BOOLEAN NOT NULL,
    salary_tier           VARCHAR(100),
    CONSTRAINT fk_fact_company FOREIGN KEY (company_size_id)
        REFERENCES dim_company(company_size_id)
);

CREATE TABLE map_job_skills (
    job_id   VARCHAR(50) NOT NULL,
    skill_id INT NOT NULL,
    PRIMARY KEY (job_id, skill_id),
    CONSTRAINT fk_map_job FOREIGN KEY (job_id) REFERENCES fact_job_postings(job_id) ON DELETE CASCADE,
    CONSTRAINT fk_map_skill FOREIGN KEY (skill_id) REFERENCES dim_skills(skill_id)
);

CREATE INDEX idx_fact_country_company ON fact_job_postings (country, company_size_id);
CREATE INDEX idx_map_job_skills_skill ON map_job_skills (skill_id);
