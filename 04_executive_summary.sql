-- MySQL 8.0.4+ | Part D: reproducible metrics for the executive HR client pitch.
-- Results are calculated from the loaded CSV rather than being stated as fixed claims.
USE ai_hiring_2026;

-- Specialized Generative-AI/RAG skill premium versus postings without these skills.
WITH generative_jobs AS (
    SELECT DISTINCT m.job_id
    FROM map_job_skills AS m
    JOIN dim_skills AS k ON k.skill_id = m.skill_id
    WHERE k.skill_name IN ('langchain', 'rag', 'agentic ai', 'agentic workflows')
)
SELECT
    'Generative AI / RAG premium' AS insight,
    SUM(CASE WHEN g.job_id IS NOT NULL THEN 1 ELSE 0 END) AS specialized_postings,
    ROUND(AVG(CASE WHEN g.job_id IS NOT NULL THEN f.annual_salary_usd END), 2) AS specialized_avg_salary_usd,
    ROUND(AVG(CASE WHEN g.job_id IS NULL THEN f.annual_salary_usd END), 2) AS other_avg_salary_usd,
    ROUND(
        100.0 * (
            AVG(CASE WHEN g.job_id IS NOT NULL THEN f.annual_salary_usd END) /
            NULLIF(AVG(CASE WHEN g.job_id IS NULL THEN f.annual_salary_usd END), 0) - 1
        ), 2
    ) AS premium_vs_other_postings_pct
FROM fact_job_postings AS f
LEFT JOIN generative_jobs AS g ON g.job_id = f.job_id;

-- Highest-growth country markets, with enough volume to make the comparison useful.
SELECT
    country,
    COUNT(*) AS postings,
    ROUND(AVG(demand_growth_yoy_pct), 2) AS avg_demand_growth_yoy_pct,
    ROUND(AVG(annual_salary_usd), 2) AS avg_salary_usd
FROM fact_job_postings
GROUP BY country
HAVING COUNT(*) >= 25
ORDER BY avg_demand_growth_yoy_pct DESC, postings DESC
LIMIT 5;

-- Pay by experience/specialization intersection: useful for upskilling decisions.
SELECT
    CASE WHEN is_senior THEN 'Senior' ELSE 'Non-senior' END AS seniority,
    CASE WHEN is_llm_role THEN 'LLM role' ELSE 'Non-LLM role' END AS role_type,
    COUNT(*) AS postings,
    ROUND(AVG(annual_salary_usd), 2) AS avg_salary_usd,
    ROUND(AVG(demand_score), 1) AS avg_demand_score
FROM fact_job_postings
GROUP BY is_senior, is_llm_role
ORDER BY avg_salary_usd DESC;
