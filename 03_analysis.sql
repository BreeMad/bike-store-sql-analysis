-- =====================================================
-- Bike Store Sales & Operations Analysis in MySQL
-- File: 03_analysis.sql
-- Purpose: Analyze revenue, customers, fulfillment, and inventory
-- =====================================================

USE bike_store_db;

-- =====================================================
-- CORE KPI SUMMARY
-- =====================================================

SELECT
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS total_customers,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_revenue,
    ROUND(
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) / COUNT(DISTINCT o.order_id),
        2
    ) AS avg_order_value
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id;

-- =====================================================
-- SALES PERFORMANCE
-- =====================================================

-- Q1. What are the 5 most recent orders placed?
SELECT
    order_id,
    order_date_clean
FROM orders
ORDER BY order_date_clean DESC
LIMIT 5;

-- Q2. What are total sales by store?
SELECT
    s.store_name,
    ROUND(SUM(oi.list_price * oi.quantity * (1 - oi.discount)), 2) AS total_sales
FROM stores s
JOIN orders o
    ON s.store_id = o.store_id
JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY s.store_name
ORDER BY total_sales DESC;

-- Q3. How does revenue trend by month?
SELECT
    YEAR(o.order_date_clean) AS order_year,
    MONTH(o.order_date_clean) AS order_month,
    ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS monthly_revenue
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY YEAR(o.order_date_clean), MONTH(o.order_date_clean)
ORDER BY order_year, order_month;

-- Q4. What is month-over-month revenue growth?
WITH monthly_revenue AS (
    SELECT
        YEAR(o.order_date_clean) AS order_year,
        MONTH(o.order_date_clean) AS order_month,
        ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS revenue
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY YEAR(o.order_date_clean), MONTH(o.order_date_clean)
)
SELECT
    order_year,
    order_month,
    revenue,
    LAG(revenue) OVER (ORDER BY order_year, order_month) AS prev_month_revenue,
    ROUND(
        100 * (revenue - LAG(revenue) OVER (ORDER BY order_year, order_month))
        / NULLIF(LAG(revenue) OVER (ORDER BY order_year, order_month), 0),
        2
    ) AS mom_growth_pct
FROM monthly_revenue;

-- Q5. Which brands generate the most revenue?
WITH BrandRevenue AS (
    SELECT
        p.brand_id,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
    FROM order_items oi
    JOIN products p
        ON oi.product_id = p.product_id
    GROUP BY p.brand_id
)
SELECT
    b.brand_name,
    ROUND(br.total_revenue, 2) AS total_revenue
FROM BrandRevenue br
JOIN brands b
    ON br.brand_id = b.brand_id
ORDER BY br.total_revenue DESC;

-- Q6. Which product categories generate the most revenue?
WITH CategoryRevenue AS (
    SELECT
        p.category_id,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
    FROM order_items oi
    JOIN products p
        ON oi.product_id = p.product_id
    GROUP BY p.category_id
)
SELECT
    c.category_name,
    ROUND(cr.total_revenue, 2) AS total_revenue
FROM CategoryRevenue cr
JOIN categories c
    ON cr.category_id = c.category_id
ORDER BY cr.total_revenue DESC;

-- Q7. What are the top-selling products by quantity?
SELECT
    p.product_name,
    SUM(oi.quantity) AS total_units_sold
FROM products p
JOIN order_items oi
    ON p.product_id = oi.product_id
GROUP BY p.product_name
ORDER BY total_units_sold DESC
LIMIT 10;

-- =====================================================
-- CUSTOMER ANALYSIS
-- =====================================================

-- Q8. How many customers are repeat vs one-time buyers?
SELECT
    CASE
        WHEN orders_per_customer > 1 THEN 'Repeat'
        ELSE 'One-Time'
    END AS customer_type,
    COUNT(*) AS num_customers
FROM (
    SELECT
        customer_id,
        COUNT(order_id) AS orders_per_customer
    FROM orders
    GROUP BY customer_id
) customer_orders
GROUP BY customer_type;

-- Q9. Which customers have spent the most overall?
WITH CustomerSpending AS (
    SELECT
        o.customer_id,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spent
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY o.customer_id
)
SELECT
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    ROUND(cs.total_spent, 2) AS total_spent
FROM CustomerSpending cs
JOIN customers c
    ON cs.customer_id = c.customer_id
ORDER BY cs.total_spent DESC
LIMIT 10;

-- Q10. How many days pass between customer orders?
SELECT
    customer_id,
    order_id,
    order_date_clean,
    LAG(order_date_clean) OVER (
        PARTITION BY customer_id
        ORDER BY order_date_clean
    ) AS previous_order_date,
    DATEDIFF(
        order_date_clean,
        LAG(order_date_clean) OVER (
            PARTITION BY customer_id
            ORDER BY order_date_clean
        )
    ) AS days_between_orders
FROM orders
ORDER BY customer_id, order_date_clean;

-- =====================================================
-- CUSTOMER SEGMENTATION (RFM-STYLE ANALYSIS)
-- =====================================================

-- Q11. Which customers are the most valuable based on recency, frequency, and monetary value?
WITH customer_metrics AS (
    SELECT
        o.customer_id,
        MAX(o.order_date_clean) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS purchase_frequency,
        ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS total_spent
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    GROUP BY o.customer_id
),
recency_calc AS (
    SELECT
        customer_id,
        last_purchase_date,
        purchase_frequency,
        total_spent,
        DATEDIFF(
            (SELECT MAX(order_date_clean) FROM orders),
            last_purchase_date
        ) AS recency_days
    FROM customer_metrics
)
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    rc.recency_days,
    rc.purchase_frequency,
    rc.total_spent,
    CASE
        WHEN rc.total_spent >= 5000 THEN 'High Value'
        WHEN rc.total_spent >= 2000 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS customer_segment
FROM recency_calc rc
JOIN customers c
    ON rc.customer_id = c.customer_id
ORDER BY rc.total_spent DESC
LIMIT 20;

-- =====================================================
-- FULFILLMENT & OPERATIONS
-- =====================================================

-- Q12. Which orders have not shipped yet?
SELECT
    order_id,
    order_status,
    order_date_clean,
    required_date_clean,
    shipped_date_clean
FROM orders
WHERE shipped_date_clean IS NULL;

-- Q13. Which stores or staff members have the fastest or slowest average shipping times?
SELECT
    st.store_name,
    CONCAT(s.first_name, ' ', s.last_name) AS staff_name,
    ROUND(AVG(DATEDIFF(o.shipped_date_clean, o.order_date_clean)), 2) AS avg_shipping_days,
    RANK() OVER (
        PARTITION BY o.store_id
        ORDER BY AVG(DATEDIFF(o.shipped_date_clean, o.order_date_clean))
    ) AS shipping_speed_rank
FROM orders o
JOIN staffs s
    ON o.staff_id = s.staff_id
JOIN stores st
    ON o.store_id = st.store_id
WHERE o.shipped_date_clean IS NOT NULL
GROUP BY o.store_id, s.staff_id, st.store_name, s.first_name, s.last_name
ORDER BY st.store_name, shipping_speed_rank;

-- =====================================================
-- INVENTORY RISK
-- =====================================================

-- Q14. Which products have critically low stock across all stores?
SELECT
    p.product_name,
    SUM(s.quantity) AS total_stock
FROM products p
JOIN stocks s
    ON p.product_id = s.product_id
GROUP BY p.product_name
HAVING SUM(s.quantity) < 20
ORDER BY total_stock ASC;

-- Q15. Which products combine high demand with low stock?
WITH product_sales AS (
    SELECT
        oi.product_id,
        SUM(oi.quantity) AS total_units_sold
    FROM order_items oi
    GROUP BY oi.product_id
),
product_stock AS (
    SELECT
        s.product_id,
        SUM(s.quantity) AS total_stock
    FROM stocks s
    GROUP BY s.product_id
)
SELECT
    p.product_name,
    ps.total_units_sold,
    pk.total_stock,
    ROUND(ps.total_units_sold / NULLIF(pk.total_stock, 0), 2) AS demand_to_stock_ratio
FROM products p
JOIN product_sales ps
    ON p.product_id = ps.product_id
JOIN product_stock pk
    ON p.product_id = pk.product_id
WHERE pk.total_stock < 50
ORDER BY demand_to_stock_ratio DESC, ps.total_units_sold DESC
LIMIT 10;

-- Q16. Which products are currently out of stock?
SELECT
    st.store_name,
    p.product_name,
    s.quantity
FROM stocks s
JOIN stores st
    ON s.store_id = st.store_id
JOIN products p
    ON s.product_id = p.product_id
WHERE s.quantity = 0
ORDER BY st.store_name, p.product_name;

-- =====================================================
-- DISCOUNT ANALYSIS
-- =====================================================

-- Q17. What is the average discount applied per brand?
WITH BrandDiscounts AS (
    SELECT
        p.brand_id,
        AVG(oi.discount) AS avg_discount
    FROM order_items oi
    JOIN products p
        ON oi.product_id = p.product_id
    GROUP BY p.brand_id
)
SELECT
    b.brand_name,
    ROUND(bd.avg_discount, 4) AS avg_discount
FROM BrandDiscounts bd
JOIN brands b
    ON bd.brand_id = b.brand_id
ORDER BY bd.avg_discount DESC;