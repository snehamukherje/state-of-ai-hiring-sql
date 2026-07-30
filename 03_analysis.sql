-- MySQL 8.0.4+ | Part B: Skill premium and geographic demand analysis.
USE ai_hiring_2026;

-- B1. Skills with at least 15 postings, benchmarked against the overall average salary.
WITH overall_bench AS (
    SELECT AVG(annual_salary_usd) AS baseline_avg_salary
    FROM fact_job_postings
)
SELECT
    k.skill_name,
    COUNT(m.job_id) AS total_job_postings,
    ROUND(AVG(f.annual_salary_usd), 2) AS avg_salary_usd,
    ROUND(AVG(CASE WHEN salary_rank.rn IN (salary_rank.low_middle, salary_rank.high_middle)
                   THEN f.annual_salary_usd END), 2) AS median_salary_usd,
    ROUND((AVG(f.annual_salary_usd) - b.baseline_avg_salary) / b.baseline_avg_salary * 100, 2)
        AS premium_vs_baseline_pct
FROM dim_skills AS k
JOIN map_job_skills AS m ON m.skill_id = k.skill_id
JOIN fact_job_postings AS f ON f.job_id = m.job_id
JOIN (
    SELECT
        m2.skill_id,
        f2.job_id,
        ROW_NUMBER() OVER (PARTITION BY m2.skill_id ORDER BY f2.annual_salary_usd, f2.job_id) AS rn,
        FLOOR((COUNT(*) OVER (PARTITION BY m2.skill_id) + 1) / 2) AS low_middle,
        CEILING((COUNT(*) OVER (PARTITION BY m2.skill_id) + 1) / 2) AS high_middle
    FROM map_job_skills AS m2
    JOIN fact_job_postings AS f2 ON f2.job_id = m2.job_id
) AS salary_rank ON salary_rank.skill_id = k.skill_id AND salary_rank.job_id = f.job_id
CROSS JOIN overall_bench AS b
GROUP BY k.skill_id, k.skill_name, b.baseline_avg_salary
HAVING COUNT(m.job_id) >= 15
ORDER BY avg_salary_usd DESC, total_job_postings DESC
LIMIT 15;

-- B2. Geography and company-size pay/demand aggregation.
SELECT
    f.country,
    c.company_size_name AS company_size,
    COUNT(f.job_id) AS total_openings,
    ROUND(AVG(f.annual_salary_usd), 2) AS avg_salary_usd,
    ROUND(AVG(f.demand_score), 1) AS avg_demand_index,
    ROUND(100.0 * SUM(CASE WHEN f.is_llm_role THEN 1 ELSE 0 END) / COUNT(*), 2) AS llm_role_share_pct
FROM fact_job_postings AS f
JOIN dim_company AS c ON c.company_size_id = f.company_size_id
GROUP BY f.country, c.company_size_name
HAVING COUNT(f.job_id) >= 10
ORDER BY avg_salary_usd DESC, total_openings DESC;

-- Part C: salary quartiles and skill feature importance.
WITH ranked_jobs AS (
    SELECT
        job_id,
        job_title,
        annual_salary_usd,
        years_of_experience,
        NTILE(4) OVER (ORDER BY annual_salary_usd, job_id) AS salary_quartile
    FROM fact_job_postings
),
quartile_skills AS (
    SELECT r.salary_quartile, k.skill_name, COUNT(*) AS skill_freq
    FROM ranked_jobs AS r
    JOIN map_job_skills AS m ON m.job_id = r.job_id
    JOIN dim_skills AS k ON k.skill_id = m.skill_id
    GROUP BY r.salary_quartile, k.skill_name
)
SELECT
    skill_name,
    SUM(CASE WHEN salary_quartile = 4 THEN skill_freq ELSE 0 END) AS top_quartile_count,
    SUM(CASE WHEN salary_quartile = 1 THEN skill_freq ELSE 0 END) AS bottom_quartile_count,
    ROUND(
        SUM(CASE WHEN salary_quartile = 4 THEN skill_freq ELSE 0 END) /
        NULLIF(SUM(CASE WHEN salary_quartile = 1 THEN skill_freq ELSE 0 END), 0), 2
    ) AS top_vs_bottom_ratio
FROM quartile_skills
GROUP BY skill_name
HAVING SUM(skill_freq) >= 10
ORDER BY top_vs_bottom_ratio IS NULL, top_vs_bottom_ratio DESC, skill_name
LIMIT 10;

-- Supporting predictive metrics: association between experience and salary.
WITH regression_terms AS (
    SELECT
        COUNT(*) AS n,
        SUM(years_of_experience) AS sum_x,
        SUM(annual_salary_usd) AS sum_y,
        SUM(years_of_experience * annual_salary_usd) AS sum_xy,
        SUM(years_of_experience * years_of_experience) AS sum_x2,
        SUM(annual_salary_usd * annual_salary_usd) AS sum_y2,
        STDDEV_SAMP(annual_salary_usd) AS salary_standard_deviation
    FROM fact_job_postings
)
SELECT
    ROUND(
        (n * sum_xy - sum_x * sum_y) /
        NULLIF(SQRT((n * sum_x2 - sum_x * sum_x) * (n * sum_y2 - sum_y * sum_y)), 0), 4
    ) AS experience_salary_correlation,
    ROUND(POW(
        (n * sum_xy - sum_x * sum_y) /
        NULLIF(SQRT((n * sum_x2 - sum_x * sum_x) * (n * sum_y2 - sum_y * sum_y)), 0), 2
    ), 4) AS experience_only_salary_r_squared,
    ROUND(salary_standard_deviation, 2) AS salary_standard_deviation_usd
FROM regression_terms;
