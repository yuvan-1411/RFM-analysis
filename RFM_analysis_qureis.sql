-- Step 1: Calculate Recency, Frequency, Monetary ranks
CREATE OR REPLACE VIEW salesmetrics AS
WITH 
  current_date_cte AS (SELECT CAST('2026-03-06' AS DATE) AS analysis_date),
  rfm AS (
    SELECT
      CustomerID,
      MAX(orderdate) AS last_order_date,
      -- MySQL DATEDIFF returns days by default: DATEDIFF(later, earlier)
      DATEDIFF((SELECT analysis_date FROM current_date_cte), MAX(orderdate)) AS recency,
      COUNT(*) AS frequency,
      SUM(ordervalue) AS monetary
    FROM sales_2025
    GROUP BY CustomerID
  )
SELECT
  *,
  ROW_NUMBER() OVER (ORDER BY recency ASC) AS r_rank,
  ROW_NUMBER() OVER (ORDER BY frequency DESC) AS f_rank,
  ROW_NUMBER() OVER (ORDER BY monetary DESC) AS m_rank
FROM rfm;

-- Step 2: Assign deciles (10=best, 1=worst)
CREATE OR REPLACE VIEW rfm_scores AS
SELECT
  *,
  -- Note: Higher Recency (days) is worse, so we order by r_rank DESC to give 
  -- the lowest days the highest score.
  NTILE(10) OVER (ORDER BY r_rank DESC) AS r_score,
  NTILE(10) OVER (ORDER BY f_rank DESC) AS f_score,
  NTILE(10) OVER (ORDER BY m_rank DESC) AS m_score
FROM salesmetrics;

-- Step 3: Total Score View
CREATE OR REPLACE VIEW rfm_total_score AS
SELECT
  CustomerID,
  recency,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score,
  (r_score + f_score + m_score) AS rfm_total_score
FROM rfm_scores;

-- Step 4: BI Ready RFM Segment Table
CREATE TABLE rfm_segments_final AS
SELECT
  CustomerID,
  recency,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score,
  (r_score + f_score + m_score) AS rfm_total_score,
  CASE
    WHEN (r_score + f_score + m_score) >= 28 THEN 'Champions'
    WHEN (r_score + f_score + m_score) >= 24 THEN 'Loyal Customers'
    WHEN (r_score + f_score + m_score) >= 20 THEN 'Potential Loyalists'
    WHEN (r_score + f_score + m_score) >= 16 THEN 'Promising'
    WHEN (r_score + f_score + m_score) >= 12 THEN 'Engaged'
    WHEN (r_score + f_score + m_score) >= 8 THEN 'Requires Attention'
    WHEN (r_score + f_score + m_score) >= 4 THEN 'At Risk'
    ELSE 'Lost/Inactive'
  END AS rfm_segment
FROM rfm_scores
ORDER BY rfm_total_score DESC;
