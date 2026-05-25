-- ============================================================
-- E-COMMERCE SALES ANALYSIS
-- Tool: PostgreSQL
-- Author: diana-data-analyst
-- Description: Analysis of e-commerce sales data including
--              revenue, customer behavior, and key business metrics
-- ============================================================


-- ============================================================
-- SECTION 1: DATABASE SETUP
-- ============================================================

CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL
);

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(200) NOT NULL,
    category_id INT REFERENCES categories(category_id),
    price NUMERIC(10,2) NOT NULL
);

CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(200) UNIQUE NOT NULL,
    city VARCHAR(100),
    country VARCHAR(100),
    registration_date DATE NOT NULL
);

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id),
    order_date DATE NOT NULL,
    status VARCHAR(50) NOT NULL
);

CREATE TABLE order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(order_id),
    product_id INT REFERENCES products(product_id),
    quantity INT NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL
);


-- ============================================================
-- SECTION 2: BASIC ANALYSIS
-- ============================================================

-- Q1: What is the total revenue of the store?
-- Result: $25,354.71
SELECT 
    ROUND(SUM(quantity * unit_price), 2) AS total_revenue
FROM order_items;


-- Q2: How many orders were placed each year?
-- Result: 2022→16, 2023→22, 2024→25, 2025→15
SELECT 
    EXTRACT(YEAR FROM order_date) AS year,
    COUNT(*) AS total_orders
FROM orders
GROUP BY EXTRACT(YEAR FROM order_date)
ORDER BY year;


-- Q3: Top 5 best-selling products by revenue
-- Result: Electronics dominate the top 5
SELECT 
    p.product_name,
    SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_name
ORDER BY revenue DESC
LIMIT 5;


-- Q4: Revenue and order count by product category
-- Result: Electronics = 58% of total revenue
SELECT 
    c.category_name,
    SUM(oi.quantity * oi.unit_price) AS revenue,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN orders o ON oi.order_id = o.order_id
GROUP BY c.category_name
ORDER BY revenue DESC;


-- Q5: Revenue and customer count by country
-- Result: Ukraine = 65% of revenue, Hungary has highest spend per customer
SELECT 
    c.country,
    COUNT(DISTINCT c.customer_id) AS customers,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.country
ORDER BY revenue DESC;


-- ============================================================
-- SECTION 3: ADVANCED ANALYSIS
-- ============================================================

-- Q6: Customers with more than 1 order (loyal customers)
-- Result: 21 out of 50 customers made repeat purchases
SELECT 
    c.first_name,
    c.last_name,
    c.country,
    COUNT(o.order_id) AS total_orders,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.country
HAVING COUNT(o.order_id) > 1
ORDER BY total_orders DESC;


-- Q7: Top 5 months by revenue
-- Result: September 2024 was the best month ($2,149.97)
SELECT 
    EXTRACT(YEAR FROM o.order_date) AS year,
    EXTRACT(MONTH FROM o.order_date) AS month,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY 
    EXTRACT(YEAR FROM o.order_date),
    EXTRACT(MONTH FROM o.order_date)
ORDER BY revenue DESC
LIMIT 5;


-- Q8: Average order value (AOV) by country
-- Result: Hungary has highest AOV at $933, Spain lowest at $113
SELECT 
    c.country,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_revenue,
    ROUND(SUM(oi.quantity * oi.unit_price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.country
ORDER BY avg_order_value DESC;


-- ============================================================
-- SECTION 4: WINDOW FUNCTIONS
-- ============================================================

-- Q9: Rank customers by revenue within each country
-- Uses RANK() - skips numbers when there's a tie
SELECT 
    c.country,
    c.first_name,
    c.last_name,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_spent,
    RANK() OVER (PARTITION BY c.country ORDER BY SUM(oi.quantity * oi.unit_price) DESC) AS rank_in_country
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.country, c.customer_id, c.first_name, c.last_name
ORDER BY c.country, rank_in_country;


-- Q10: Running total of revenue by month
-- Shows cumulative growth from store launch to present
SELECT 
    EXTRACT(YEAR FROM o.order_date) AS year,
    EXTRACT(MONTH FROM o.order_date) AS month,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS monthly_revenue,
    ROUND(SUM(SUM(oi.quantity * oi.unit_price)) OVER (ORDER BY EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)), 2) AS running_total
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)
ORDER BY year, month;


-- Q11: Month-over-month revenue comparison using LAG
-- Shows growth or decline compared to previous month
SELECT 
    EXTRACT(YEAR FROM o.order_date) AS year,
    EXTRACT(MONTH FROM o.order_date) AS month,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS monthly_revenue,
    ROUND(LAG(SUM(oi.quantity * oi.unit_price)) OVER (ORDER BY EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)), 2) AS prev_month_revenue,
    ROUND(SUM(oi.quantity * oi.unit_price) - LAG(SUM(oi.quantity * oi.unit_price)) OVER (ORDER BY EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)), 2) AS difference
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY EXTRACT(YEAR FROM o.order_date), EXTRACT(MONTH FROM o.order_date)
ORDER BY year, month;


-- ============================================================
-- SECTION 5: BUSINESS METRICS
-- ============================================================

-- Q12: AOV (Average Order Value) by month
-- Key metric: how much does a customer spend per order on average
SELECT 
    EXTRACT(YEAR FROM o.order_date) AS year,
    EXTRACT(MONTH FROM o.order_date) AS month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
    ROUND(SUM(oi.quantity * oi.unit_price) / COUNT(DISTINCT o.order_id), 2) AS aov
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY 
    EXTRACT(YEAR FROM o.order_date),
    EXTRACT(MONTH FROM o.order_date)
ORDER BY year, month;


-- Q13: Customer Retention Rate
-- Result: 42% retention (above industry average of 20-30%)
SELECT 
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT CASE WHEN order_count > 1 THEN customer_id END) AS returning_customers,
    COUNT(DISTINCT CASE WHEN order_count = 1 THEN customer_id END) AS one_time_customers,
    ROUND(COUNT(DISTINCT CASE WHEN order_count > 1 THEN customer_id END) * 100.0 / COUNT(DISTINCT customer_id), 2) AS retention_rate
FROM (
    SELECT 
        customer_id,
        COUNT(order_id) AS order_count
    FROM orders
    GROUP BY customer_id
) subquery;


-- Q14: Customer LTV (Lifetime Value)
-- Result: Avg LTV = $507, Min = $12.99, Max = $2,407.92
SELECT 
    ROUND(AVG(total_spent), 2) AS avg_ltv,
    ROUND(MIN(total_spent), 2) AS min_ltv,
    ROUND(MAX(total_spent), 2) AS max_ltv
FROM (
    SELECT 
        c.customer_id,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id
) subquery;


-- ============================================================
-- SECTION 6: CTE ANALYSIS
-- ============================================================

-- Q15: Customer segments by total spending (using CTE)
-- Segments: VIP (>$500), Regular ($100-500), New (<$100)

WITH customer_spending AS (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        c.country,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY c.customer_id, c.first_name, c.last_name, c.country
)
SELECT
    customer_id,
    first_name,
    last_name,
    country,
    total_spent,
    CASE
        WHEN total_spent > 500  THEN 'VIP'
        WHEN total_spent >= 100 THEN 'Regular'
        ELSE                         'New'
    END AS segment
FROM customer_spending
ORDER BY total_spent DESC;


-- Q16: Revenue contribution by segment (using CTE chain)
-- Shows how much % of revenue comes from VIP vs Regular vs New

WITH customer_spending AS (
    SELECT
        c.customer_id,
        ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY c.customer_id
),
customer_segments AS (
    SELECT
        customer_id,
        total_spent,
        CASE
            WHEN total_spent > 500  THEN 'VIP'
            WHEN total_spent >= 100 THEN 'Regular'
            ELSE                         'New'
        END AS segment
    FROM customer_spending
)
SELECT
    segment,
    COUNT(customer_id)                                        AS customer_count,
    ROUND(SUM(total_spent), 2)                                AS segment_revenue,
    ROUND(SUM(total_spent) * 100.0 / SUM(SUM(total_spent)) OVER (), 2) AS revenue_pct
FROM customer_segments
GROUP BY segment
ORDER BY segment_revenue DESC;


-- Q17: First purchase analysis — what do customers buy first?
-- Shows the most popular products as a first purchase

WITH first_orders AS (
    SELECT
        customer_id,
        MIN(order_date) AS first_order_date
    FROM orders
    GROUP BY customer_id
),
first_order_ids AS (
    SELECT
        o.order_id,
        o.customer_id
    FROM orders o
    JOIN first_orders fo
        ON o.customer_id = fo.customer_id
       AND o.order_date  = fo.first_order_date
)
SELECT
    p.product_name,
    c.category_name,
    COUNT(*) AS times_bought_first
FROM first_order_ids foi
JOIN order_items oi  ON foi.order_id   = oi.order_id
JOIN products p      ON oi.product_id  = p.product_id
JOIN categories c    ON p.category_id  = c.category_id
GROUP BY p.product_name, c.category_name
ORDER BY times_bought_first DESC
LIMIT 10;


-- Q18: Days between first and second purchase (time to return)
-- Helps understand how quickly loyal customers come back

WITH customer_orders AS (
    SELECT
        customer_id,
        order_date,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS order_num
    FROM orders
    WHERE status = 'completed'
),
first_purchase  AS (SELECT customer_id, order_date AS first_date  FROM customer_orders WHERE order_num = 1),
second_purchase AS (SELECT customer_id, order_date AS second_date FROM customer_orders WHERE order_num = 2)
SELECT
    fp.customer_id,
    c.first_name,
    c.last_name,
    fp.first_date,
    sp.second_date,
    (sp.second_date - fp.first_date) AS days_to_return
FROM first_purchase fp
JOIN second_purchase sp ON fp.customer_id = sp.customer_id
JOIN customers c        ON fp.customer_id = c.customer_id
ORDER BY days_to_return;
