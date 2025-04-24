--Analysis - I
--1.To simplify its financial reports, Amazon India needs to standardize payment values. 
--Round the average payment values to integer (no decimal) for each payment type and display the results sorted in ascending order.
SELECT payment_type,ROUND(AVG(payment_value)) AS rounded_Avg_payment
FROM amazon_brazil.payments
GROUP BY payment_type
ORDER BY rounded_Avg_payment DESC;

--2.To refine its payment strategy, Amazon India wants to know the distribution of orders by payment type.
--Calculate the percentage of total orders for each payment type, rounded to one decimal place, and display them in descending order.
SELECT 
    payment_type,
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM amazon_brazil.payments)), 1) AS percentage_orders
FROM 
    amazon_brazil.payments
GROUP BY 
    payment_type
ORDER BY 
    percentage_orders DESC;	

--3.Amazon India seeks to create targeted promotions for products within specific price ranges. 
--Identify all products priced between 100 and 500 BRL that contain the word 'Smart' in their name. Display these products, sorted by price in descending order.
SELECT O.product_id, O.price 
FROM amazon_brazil.order_items AS O
INNER JOIN amazon_brazil.product AS P
ON O.product_id = P.product_id
WHERE O.price BETWEEN 100 AND 500
AND P.product_category_name LIKE '%smart%'
ORDER BY O.price DESC;

--4.To identify seasonal sales patterns, Amazon India needs to focus on the most successful months.
--Determine the top 3 months with the highest total sales value, rounded to the nearest integer.
SELECT 
    EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
    ROUND(SUM(oi.price)::NUMERIC) AS total_sales
FROM 
    amazon_brazil.orders o
JOIN 
    amazon_brazil.order_items oi ON o.order_id = oi.order_id
WHERE 
    o.order_status = 'delivered'
GROUP BY 
    EXTRACT(MONTH FROM o.order_purchase_timestamp)
ORDER BY 
    total_sales DESC
LIMIT 3;

--5.Amazon India is interested in product categories with significant price variations. 
--Find categories where the difference between the maximum and minimum product prices is greater than 500 BRL.
SELECT 
    p.product_category_name,
    MAX(oi.price) - MIN(oi.price) AS price_difference
FROM 
    amazon_brazil.order_items oi
JOIN 
    amazon_brazil.product p ON oi.product_id = p.product_id
GROUP BY 
    p.product_category_name
HAVING 
    MAX(oi.price) - MIN(oi.price) > 500     
ORDER BY 
    price_difference DESC;

--6.To enhance the customer experience, Amazon India wants to find which payment types have the most consistent transaction amounts.
--Identify the payment types with the least variance in transaction amounts, sorting by the smallest standard deviation first.
SELECT 
    p.payment_type,
    ROUND(STDDEV(p.payment_value), 2) AS payment_stddev
FROM 
    amazon_brazil.payments p
GROUP BY 
    p.payment_type
ORDER BY 
    payment_stddev ASC;

--7.Amazon India wants to identify products that may have incomplete name in order to fix it from their end. 
--Retrieve the list of products where the product category name is missing or contains only a single character.
SELECT 
    product_id, 
    product_category_name
FROM 
    amazon_brazil.product
WHERE 
    product_category_name IS NULL 
    OR LENGTH(product_category_name) = 1;

--Analysis - II
--1.Amazon India wants to understand which payment types are most popular across different order value segments (e.g., low, medium, high). 
--Segment order values into three ranges: orders less than 200 BRL, between 200 and 1000 BRL, and over 1000 BRL. Calculate the count of each payment type within these ranges and display the results in descending order of count
WITH CTE AS(
SELECT 
	payment_type ,
CASE
	WHEN payment_value < 200 THEN 'low'
	WHEN payment_value BETWEEN 200 AND 1000 THEN 'medium'
	WHEN payment_value > 1000 THEN 'high'
	END AS segment 
FROM amazon_brazil.payments
)
SELECT segment , payment_type , COUNT(*)  
FROM CTE
GROUP BY payment_type, segment
ORDER BY COUNT(*) DESC;

--2.Amazon India wants to analyse the price range and average price for each product category.
--Calculate the minimum, maximum, and average price for each category, and list them in descending order by the average price.
SELECT 
    p.product_category_name,
    MIN(oi.price) AS min_price,
    MAX(oi.price) AS max_price,
    ROUND(AVG(oi.price)::NUMERIC, 2) AS avg_price
FROM 
    amazon_brazil.product p
JOIN 
    amazon_brazil.order_items oi
    ON p.product_id = oi.product_id
GROUP BY 
    p.product_category_name
ORDER BY 
    avg_price DESC;

--3.Amazon India wants to identify the customers who have placed multiple orders over time.
--Find all customers with more than one order, and display their customer unique IDs along with the total number of orders they have placed.
SELECT 
    c.customer_unique_id,
    COUNT(o.order_id) AS total_orders
FROM 
    amazon_brazil.customers c
JOIN 
    amazon_brazil.orders o
    ON c.customer_id = o.customer_id
GROUP BY 
    c.customer_unique_id
HAVING 
    COUNT(o.order_id) > 1
ORDER BY 
    total_orders DESC;

--4.Amazon India wants to categorize customers into different types ('New – order qty. = 1' ;  'Returning' –order qty. 2 to 4;  'Loyal' – order qty. >4) based on their purchase history.
--Use a temporary table to define these categories and join it with the customers table to update and display the customer types.
CREATE TEMPORARY TABLE temp_customer_orders AS
SELECT 
    customer_id,
    COUNT(DISTINCT order_id) AS orders
FROM 
    amazon_brazil.orders
GROUP BY 
    customer_id;

SELECT 
    c.customer_id,
    CASE 
        WHEN t.orders = 1 THEN 'New'
        WHEN t.orders BETWEEN 2 AND 4 THEN 'Returning'
        WHEN t.orders >= 5 THEN 'Loyal'
        ELSE 'New' 
    END AS customer_type
FROM 
    amazon_brazil.customers c
LEFT JOIN 
    temp_customer_orders t
    ON c.customer_id = t.customer_id

--5.Amazon India wants to know which product categories generate the most revenue. 
--Use joins between the tables to calculate the total revenue for each product category. Display the top 5 categories.
SELECT 
    p.product_category_name,
    SUM(oi.price) AS total_revenue
FROM 
    amazon_brazil.order_items oi
JOIN 
    amazon_brazil.product p
ON 
    oi.product_id = p.product_id
JOIN 
    amazon_brazil.orders o
ON 
    oi.order_id = o.order_id
WHERE 
    o.order_status = 'delivered'
GROUP BY 
    p.product_category_name
ORDER BY 
    total_revenue DESC
LIMIT 5;

--Analysis - III
--1.The marketing team wants to compare the total sales between different seasons. 
--Use a subquery to calculate total sales for each season (Spring, Summer, Autumn, Winter) based on order purchase dates, and display the results. Spring is in the months of March, April and May. Summer is from June to August and Autumn is between September and November and rest months are Winter. 
SELECT 
    season,
    SUM(total_sales) AS total_sales
FROM (
    SELECT 
        CASE
            WHEN EXTRACT(MONTH FROM o.order_purchase_timestamp) IN (3, 4, 5) THEN 'Spring'
            WHEN EXTRACT(MONTH FROM o.order_purchase_timestamp) IN (6, 7, 8) THEN 'Summer'
            WHEN EXTRACT(MONTH FROM o.order_purchase_timestamp) IN (9, 10, 11) THEN 'Autumn'
            ELSE 'Winter'
        END AS season,
        oi.price AS total_sales
    FROM 
        amazon_brazil.orders o
    JOIN 
        amazon_brazil.order_items oi
    ON 
        o.order_id = oi.order_id
) seasonal_sales
GROUP BY 
    season
ORDER BY 
    total_sales DESC;

--2.The inventory team is interested in identifying products that have sales volumes above the overall average.
--Write a query that uses a subquery to filter products with a total quantity sold above the average quantity.
SELECT 
    product_id,
    COUNT(order_item_id) AS total_quantity_sold
FROM 
    amazon_brazil.order_items
GROUP BY 
    product_id
HAVING 
    COUNT(order_item_id) > (
        SELECT 
            AVG(total_quantity)
        FROM (
            SELECT 
                COUNT(order_item_id) AS total_quantity
            FROM 
                amazon_brazil.order_items
            GROUP BY 
                product_id
        ) product_totals
    );

--3.To understand seasonal sales patterns, the finance team is analysing the monthly revenue trends over the past year (year 2018).
--Run a query to calculate total revenue generated each month and identify periods of peak and low sales. Export the data to Excel and create a graph to visually represent revenue changes across the months.
SELECT 
    EXTRACT(MONTH FROM o.order_purchase_timestamp) AS month,
    SUM(oi.price) AS total_revenue
FROM 
    amazon_brazil.orders AS o
JOIN 
    amazon_brazil.order_items AS oi
ON 
    o.order_id = oi.order_id
WHERE 
    EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
GROUP BY 
    EXTRACT(MONTH FROM o.order_purchase_timestamp)
ORDER BY 
    month;

--4.A loyalty program is being designed  for Amazon India.
--Create a segmentation based on purchase frequency: ‘Occasional’ for customers with 1-2 orders, ‘Regular’ for 3-5 orders, and ‘Loyal’ for more than 5 orders. Use a CTE to classify customers and their count and generate a chart in Excel to show the proportion of each segment.
WITH customer_segments AS (
    SELECT 
        o.customer_id,
        COUNT(o.order_id) AS order_count
    FROM 
        amazon_brazil.orders AS o
    GROUP BY 
        o.customer_id
),
customer_classification AS (
    SELECT 
        CASE 
            WHEN order_count BETWEEN 1 AND 2 THEN 'Occasional'
            WHEN order_count BETWEEN 3 AND 5 THEN 'Regular'
            WHEN order_count > 5 THEN 'Loyal'
        END AS customer_type
    FROM 
        customer_segments
)
SELECT 
    customer_type,
    COUNT(*) AS count
FROM 
    customer_classification
GROUP BY 
    customer_type
ORDER BY 
    count DESC;

--5.Amazon wants to identify high-value customers to target for an exclusive rewards program. 
--You are required to rank customers based on their average order value (avg_order_value) to find the top 20 customers.
WITH customer_avg_order_value AS (
    SELECT 
        o.customer_id,
        AVG(oi.price) AS avg_order_value
    FROM 
        amazon_brazil.orders AS o
    JOIN 
        amazon_brazil.order_items AS oi
    ON 
        o.order_id = oi.order_id
    GROUP BY 
        o.customer_id
),
customer_ranking AS (
    SELECT 
        customer_id,
        avg_order_value,
        RANK() OVER (ORDER BY avg_order_value DESC) AS customer_rank
    FROM 
        customer_avg_order_value
)
SELECT 
    customer_id,
    avg_order_value,
    customer_rank
FROM 
    customer_ranking
WHERE 
    customer_rank <= 20
ORDER BY 
    customer_rank;

--6.Amazon wants to analyze sales growth trends for its key products over their lifecycle. 
--Calculate monthly cumulative sales for each product from the date of its first sale. Use a recursive CTE to compute the cumulative sales (total_sales) for each product month by month.
WITH RECURSIVE MonthlySales AS (
   
    SELECT 
        product_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS sale_month,
        SUM(oi.price) AS monthly_sales,
        SUM(oi.price) AS total_sales -- Start with the first month's sales as total_sales
    FROM amazon_brazil.Orders o
    JOIN amazon_brazil.Order_Items oi ON o.order_id = oi.order_id
    GROUP BY product_id

    UNION ALL

    
    SELECT 
        ms.product_id,
        ms.sale_month + INTERVAL '1 month' AS sale_month,
        COALESCE(next_month.monthly_sales, 0) AS monthly_sales,
        ms.total_sales + COALESCE(next_month.monthly_sales, 0) AS total_sales
    FROM MonthlySales ms
    LEFT JOIN (
        SELECT 
            product_id,
            DATE_TRUNC('month', o.order_purchase_timestamp) AS sale_month,
            SUM(oi.price) AS monthly_sales
        FROM amazon_brazil.orders o
        JOIN amazon_brazil.order_Items oi ON o.order_id = oi.order_id
        GROUP BY product_id, DATE_TRUNC('month', o.order_purchase_timestamp)
    ) next_month 
    ON ms.product_id = next_month.product_id 
       AND next_month.sale_month = ms.sale_month + INTERVAL '1 month'
    WHERE ms.sale_month < (SELECT MAX(DATE_TRUNC('month', order_purchase_timestamp)) FROM amazon_brazil.Orders)
)
SELECT 
    product_id,
    TO_CHAR(sale_month, 'YYYY-MM') AS sale_month, 
    monthly_sales,
    total_sales
FROM MonthlySales
ORDER BY product_id, sale_month;

--7.To understand how different payment methods affect monthly sales growth, Amazon wants to compute the total sales for each payment method and calculate the month-over-month growth rate for the past year (year 2018).
-- Write query to first calculate total monthly sales for each payment method, then compute the percentage change from the previous month.
WITH monthly_sales AS (
    
    SELECT 
        p.payment_type,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS sale_month,
        SUM(p.payment_value) AS monthly_total
    FROM 
        amazon_brazil.orders o
    JOIN 
        amazon_brazil.payments p
    ON 
        o.order_id = p.order_id
    WHERE 
        DATE_PART('year', o.order_purchase_timestamp) = 2018
    GROUP BY 
        p.payment_type, DATE_TRUNC('month', o.order_purchase_timestamp)
),
monthly_growth AS (
   
    SELECT 
        payment_type,
        sale_month,
        monthly_total,
      
        LAG(monthly_total) OVER (PARTITION BY payment_type ORDER BY sale_month) AS previous_month_total,
      
        ROUND(
            (monthly_total - LAG(monthly_total) OVER (PARTITION BY payment_type ORDER BY sale_month)) 
            / NULLIF(LAG(monthly_total) OVER (PARTITION BY payment_type ORDER BY sale_month), 0) * 100, 
            2
        ) AS monthly_change
    FROM 
        monthly_sales
)

SELECT 
    payment_type,
    sale_month,
    monthly_total,
    COALESCE(monthly_change, 0) AS monthly_change
FROM 
    monthly_growth
ORDER BY 
    payment_type, sale_month;






