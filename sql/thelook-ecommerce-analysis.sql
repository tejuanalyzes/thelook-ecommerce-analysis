CREATE OR REPLACE VIEW ecommerce_analysis_.base_orders AS

SELECT
oi.user_id,
oi.order_id,
oi.status,
product_id,
oi.sale_price,
oi.created_at,

p.name,
p.id,
p.brand,
p.category,
p.cost,
p.retail_price,

u.traffic_source AS user_traffic,
u.country AS user_country,
u.state AS user_state,
u.gender AS user_gender,
u.age AS user_age,

EXTRACT ( YEAR FROM oi.created_at) AS order_year,
EXTRACT ( MONTH FROM oi.created_at) AS order_month

FROM `bigquery-public-data.thelook_ecommerce.order_items` AS oi
LEFT JOIN `bigquery-public-data.thelook_ecommerce.products` AS p
ON oi.product_id = p.id 
LEFT JOIN `bigquery-public-data.thelook_ecommerce.users` AS u
ON oi.user_id = u.id;

SELECT *
FROM ecommerce_analysis_.base_orders;

CREATE OR REPLACE VIEW ecommerce_analysis_.product_metrics AS
SELECT 
brand,
category,
order_year,
COUNT (order_id) AS total_orders,
COUNT (CASE WHEN status ='Complete' THEN 1 END) AS completed_orders,
COUNT (CASE WHEN status ='Returned' THEN 1 END) AS returned_orders,
COUNT (CASE WHEN status ='Cancelled' THEN 1 END) AS cancelled_orders,

SAFE_DIVIDE (
  COUNT (CASE WHEN status = 'Cancelled' THEN 1 END ),
  COUNT(order_id)
) AS cancellation_rate,
SAFE_DIVIDE (
  COUNT( CASE WHEN status = 'Returned' THEN 1 END),
  COUNT(order_id)
  ) AS return_rate,
  SUM (CASE WHEN status = 'Complete' THEN sale_price - cost END)
  AS total_profit,
  SUM (CASE WHEN status ='Complete' THEN sale_price END)
  AS total_revenue,

  SAFE_DIVIDE (
    SUM (CASE WHEN status = 'Complete' THEN sale_price - cost ELSE 0 END),
    SUM (CASE WHEN status = 'Complete'THEN sale_price ELSE 0 END)
    )AS profit_margin,
  
FROM ecommerce_analysis_.base_orders
GROUP BY
brand,
category,
order_year;

SELECT *
FROM ecommerce_analysis_.product_metrics;

CREATE OR REPLACE VIEW ecommerce_analysis_.yearly_metrics AS
SELECT
brand,
order_year,
COUNT (order_id) AS total_orders,
SUM ( CASE WHEN status = 'Complete' THEN sale_price ELSE 0 END)
AS yearly_revenue,
SUM ( CASE WHEN status = 'Complete' THEN sale_price - cost ELSE 0 END)
AS yearly_profit
FROM ecommerce_analysis_.base_orders 
GROUP BY
order_year,
brand;

SELECT *
FROM ecommerce_analysis_.yearly_metrics;

CREATE OR REPLACE VIEW ecommerce_analysis_.monthly_metrics AS
SELECT
order_month,
order_year,
SUM (CASE WHEN status = 'Complete' THEN sale_price ELSE 0 END ) AS monthly_revenue,
SUM (CASE WHEN status = 'Complete' THEN sale_price - cost ELSE 0 END) AS monthly_profit,
COUNT(order_id) AS total_orders 
FROM ecommerce_analysis_.base_orders
GROUP BY
order_month,
order_year
ORDER BY order_year, order_month;
SELECT *
FROM ecommerce_analysis_.monthly_metrics;
CREATE OR REPLACE VIEW ecommerce_analysis_.mom_growth_metrics AS
WITH raw_monthly_revenue AS (
  SELECT 
  order_year,
  order_month,
  SUM (CASE WHEN status = 'Complete' THEN sale_price ELSE 0 END) AS monthly_revenue
FROM `newproject-123-470611.ecommerce_analysis_.base_orders`
GROUP BY order_year, order_month
),

 monthly_lag AS (
  SELECT
  order_month,
  order_year,
  monthly_revenue,
  LAG (monthly_revenue,1) OVER (ORDER BY order_year, order_month) AS previous_month_revenue
    FROM raw_monthly_revenue
)
 
SELECT
order_year,
order_month,
monthly_revenue,
COALESCE(previous_month_revenue,0) AS previous_month_revenue,
SAFE_DIVIDE((monthly_revenue - previous_month_revenue), previous_month_revenue) *100 AS mom_growth_percentage
FROM monthly_lag
ORDER BY order_year, order_month; SELECT *
FROM ecommerce_analysis_.mom_growth_metrics;

CREATE OR REPLACE VIEW ecommerce_analysis_.top5_brands AS
SELECT 
brand,
SUM ( CASE WHEN status = 'Complete' THEN sale_price ELSE 0 END) AS brand_revenue,
SUM (CASE WHEN status = 'Complete' THEN sale_price - cost ELSE 0 END) AS brand_profit,
COUNT(order_id) AS total_orders,
FROM ecommerce_analysis_.base_orders 
GROUP BY order_year,brand;

SELECT *
FROM ecommerce_analysis_.top5_brands;

CREATE OR REPLACE VIEW ecommerce_analysis_.top10_categories AS
SELECT
category,
SUM ( CASE WHEN status = 'Complete' THEN  sale_price ELSE 0 END) AS category_revenue,
SUM ( CASE WHEN status = 'Complete' THEN sale_price - cost ELSE 0 END) AS category_profit,
COUNT (order_id) AS total_orders,
FROM ecommerce_analysis_.base_orders
GROUP BY order_year, category;

SELECT *
FROM ecommerce_analysis_.top10_categories;

CREATE OR REPLACE VIEW ecommerce_analysis_.most_selling_products AS 
SELECT
product_id,
name,
order_year,
SUM (CASE WHEN status = 'Complete' THEN sale_price - cost ELSE 0 END) AS product_profit,
COUNT (order_id) AS total_orders
FROM ecommerce_analysis_.base_orders
GROUP BY
product_id,
name,
order_year
ORDER BY product_profit DESC
LIMIT 20;

SELECT *
FROM ecommerce_analysis_.most_selling_products;

CREATE OR REPLACE VIEW ecommerce_analysis_.unsold_products AS
SELECT
   p.id AS product_id,
   p.name,
   p.brand,
   p.category,
   p.retail_price,
   p.cost
   FROM `bigquery-public-data.thelook_ecommerce.products` AS p
   LEFT JOIN ecommerce_analysis_.base_orders AS b
   ON p.id = b.product_id
   WHERE b.product_id IS NULL;

SELECT *
FROM ecommerce_analysis_.unsold_products;

CREATE OR REPLACE VIEW ecommerce_analysis_.yearly_trends AS
SELECT
order_year,
SUM (CASE WHEN status = 'Complete' THEN sale_price ELSE 0 END)AS total_yearly_revenue,
SUM (CASE WHEN status = 'Complete' THEN sale_price - cost ELSE 0 END) AS total_yearly_profit
FROM `newproject-123-470611.ecommerce_analysis_.base_orders`
GROUP BY order_year
ORDER BY order_year;
SELECT *
FROM ecommerce_analysis_.yearly_trends;

CREATE OR REPLACE VIEW  ecommerce_analysis_.lowprofit_revstat AS
SELECT
brand,
SUM (CASE WHEN status = 'Complete' THEN sale_price ELSE 0 END) AS revenue,
SUM (CASE WHEN status = 'Complete' THEN sale_price - cost ELSE 0 END) AS profit,
SAFE_DIVIDE(
  SUM (CASE WHEN status = 'Complete' THEN sale_price - cost ELSE 0 END),
  SUM (CASE WHEN status = 'Complete' THEN sale_price ELSE 0 END)
  ) AS profit_margin
FROM ecommerce_analysis_.base_orders
GROUP BY brand
HAVING revenue > 0
ORDER BY profit_margin ASC
LIMIT 10;

SELECT *
FROM ecommerce_analysis_.lowprofit_revstat;

CREATE OR REPLACE VIEW ecommerce_analysis_.highprof_revstat AS
SELECT 
brand,
SUM ( CASE WHEN status ='Complete'THEN sale_price - cost ELSE 0 END) AS total_profit,
AVG (CASE WHEN status = 'Complete'THEN sale_price ELSE NULL END) AS avg_rev_per_order,
COUNT (order_id) AS total_orders
FROM ecommerce_analysis_.base_orders
GROUP BY brand
ORDER BY total_profit DESC
LIMIT 10;
SELECT *
FROM ecommerce_analysis_.highprof_revstat;

CREATE OR REPLACE VIEW ecommerce_analysis_.regional_order_health AS 
SELECT
user_country,
user_state,
COUNT (DISTINCT order_id) AS total_orders,
COUNT (DISTINCT user_id) AS total_customers,

SAFE_DIVIDE(
  COUNT(DISTINCT CASE WHEN user_id IN(
    SELECT user_id
  FROM ecommerce_analysis_.base_orders
GROUP BY user_id
HAVING COUNT(order_id) > 1
  )THEN user_id END),
  COUNT (DISTINCT user_id)
  ) *100 AS repeat_customer_rate,

  SAFE_DIVIDE(
  COUNT(DISTINCT CASE WHEN status = 'Cancelled' THEN order_id END),
  COUNT (DISTINCT order_id))*100
   AS cancellation_rate,

SAFE_DIVIDE(
  COUNT(DISTINCT CASE WHEN status = 'Returned' THEN order_id END),
  COUNT (DISTINCT order_id)
)*100 AS return_rate

FROM ecommerce_analysis_.base_orders
GROUP BY user_country, user_state;

SELECT *
FROM ecommerce_analysis_.regional_order_health;

CREATE OR REPLACE VIEW ecommerce_analysis_.regional_cohort_retention AS 
WITH user_first_purchase AS (
  SELECT
o.user_id,
  u.country,
  u.state,
  MIN(DATE_TRUNC(EXTRACT(DATE FROM o.created_at),MONTH)) AS cohort_month
  FROM `bigquery-public-data.thelook_ecommerce.orders` AS o
  JOIN `bigquery-public-data.thelook_ecommerce.users` AS u
 ON o.user_id = u.id
  GROUP BY user_id, country, state
),
user_activity AS (
  SELECT DISTINCT user_id,
  DATE_TRUNC(EXTRACT(DATE FROM created_at),MONTH) AS activity_month
  FROM `bigquery-public-data.thelook_ecommerce.orders` 
)
SELECT 
f.country,
f.state,
f.cohort_month,
DATE_DIFF(a.activity_month, f.cohort_month, MONTH) AS month_diff,
COUNT(DISTINCT a.user_id) AS active_users
FROM user_activity AS a
JOIN user_first_purchase AS f
ON a.user_id = f.user_id
GROUP BY f.country, f.state, f.cohort_month, month_diff;

