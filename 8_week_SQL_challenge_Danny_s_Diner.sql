/* --------------------
   Case Study Questions
   -------------------- */
  
-- 1. What is the total amount each customer spent at the restaurant?

SELECT sales.customer_id, sum(menu.price) AS total_amount
FROM dannys_diner.sales AS sales
INNER JOIN dannys_diner.menu AS menu
ON sales.product_id = menu.product_id
GROUP BY sales.customer_id;

-- 2. How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(DISTINCT order_date) AS number_of_day
FROM dannys_diner.sales
GROUP BY customer_id 


-- 3. What was the first item from the menu purchased by each customer?

WITH product_ordered_sequence AS
    (SELECT customer_id,  product_id,
        ROW_NUMBER() OVER (PARTITION BY sales.customer_id ORDER BY sales.order_date) AS ordering_sequence
    FROM dannys_diner.sales)

SELECT pos.customer_id, menu.product_name AS first_ordered_product
FROM product_ordered_sequence AS pos
INNER JOIN dannys_diner.menu as menu
ON pos.product_id = menu.product_id
WHERE pos.ordering_sequence = 1 

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

WITH sales_count_by_product AS
    (SELECT product_id, COUNT(*) AS sales_count FROM dannys_diner.sales GROUP BY product_id)

SELECT menu.product_name, sc_t.sales_count
FROM dannys_diner.menu AS menu
INNER JOIN sales_count_by_product AS sc_t
ON menu.product_id = sc_t.product_id
WHERE 
    (SELECT MAX(sc_t.sales_count) 
    FROM sales_count_by_product AS sc_t) = sc_t.sales_count; 

-- 5. Which item was the most popular for each customer?

WITH count_all_sales AS
    (SELECT sales.customer_id, sales.product_id, COUNT(*) AS sales_count
    FROM dannys_diner.sales AS sales
    GROUP BY sales.customer_id, sales.product_id)
    
SELECT cas.customer_id, menu.product_name
FROM count_all_sales AS cas
INNER JOIN dannys_diner.menu AS menu
ON cas.product_id = menu.product_id
INNER JOIN (SELECT customer_id, MAX(sales_count) AS max_count FROM count_all_sales GROUP BY customer_id) AS max_sales
ON cas.customer_id = max_sales.customer_id AND cas.sales_count = max_sales.max_count
ORDER BY cas.customer_id; 

-- 6. Which item was purchased first by the customer after they became a member?

WITH after_member_ordered_date AS
    (SELECT sales.customer_id, sales.product_id, (sales.order_date - members.join_date) AS diff_date
    FROM dannys_diner.sales AS sales
    INNER JOIN dannys_diner.members AS members
    ON sales.customer_id = members.customer_id
    WHERE diff_date > 0)

SELECT ordered_date.customer_id, menu.product_name
FROM after_member_ordered_date AS ordered_date
INNER JOIN (SELECT customer_id, MIN(diff_date) AS min_date FROM after_member_ordered_date GROUP BY customer_id) AS min_ordered_date
ON ordered_date.customer_id = min_ordered_date.customer_id AND ordered_date.diff_date = min_ordered_date.min_date
INNER JOIN dannys_diner.menu AS menu
ON ordered_date.product_id = menu.product_id; 

-- 7. Which item was purchased just before the customer became a member?

WITH before_member_ordered_date AS
    (SELECT sales.customer_id, sales.product_id, (sales.order_date - members.join_date) AS diff_date
    FROM dannys_diner.sales AS sales
    INNER JOIN dannys_diner.members AS members
    ON sales.customer_id = members.customer_id
    WHERE diff_date <= 0)
    
SELECT ordered_date.customer_id, menu.product_name
FROM before_member_ordered_date AS ordered_date
INNER JOIN (SELECT customer_id, MAX(diff_date) AS before_date FROM before_member_ordered_date GROUP BY customer_id) AS before_ordered_date
ON ordered_date.customer_id = before_ordered_date.customer_id AND ordered_date.diff_date = before_ordered_date.before_date
INNER JOIN dannys_diner.menu AS menu
ON ordered_date.product_id = menu.product_id; 

-- 8. What are the total items and amount spent for each member before they became a member?

WITH sales_before_membership AS
    (SELECT sales.customer_id, sales.product_id
    FROM dannys_diner.sales AS sales
    INNER JOIN dannys_diner.members AS members
    ON sales.customer_id = members.customer_id
    WHERE sales.order_date < members.join_date)

SELECT sbm.customer_id, COUNT(sbm.product_id) AS item_count, SUM(menu.price) AS amount_spent
FROM sales_before_membership AS sbm
INNER JOIN dannys_diner.menu AS menu
ON sbm.product_id = menu.product_id
GROUP BY sbm.customer_id
ORDER BY amount_spent DESC; 

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH point AS
    (SELECT *, 
        CASE product_name
            WHEN 'sushi' THEN 20
            ELSE 10
        END AS point,
        ((CASE product_name WHEN 'sushi' THEN 20 ELSE 10 END) * price) AS point_per_sales
    FROM dannys_diner.menu AS menu)

SELECT sales.customer_id, SUM(point.point_per_sales) AS total_point
FROM dannys_diner.sales AS sales
LEFT JOIN point
ON sales.product_id = point.product_id
GROUP BY sales.customer_id; 


-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items,
-- not just sushi - how many points do customer A and B have at the end of January?

WITH jan_membership_records AS
    (SELECT sales.customer_id, sales.product_id, 
        CASE WHEN (sales.order_date - members.join_date) BETWEEN 0 AND 6 THEN '20' 
            WHEN sales.product_id = '2' THEN '20' ELSE '10' 
        END AS point
    FROM dannys_diner.sales AS sales
    INNER JOIN dannys_diner.members AS members
    ON sales.customer_id = members.customer_id
    WHERE month(sales.order_date) < 2)

SELECT jmr.customer_id, SUM(menu.price * jmr.point) AS jan_point
FROM jan_membership_records AS jmr
LEFT JOIN dannys_diner.menu AS menu
ON jmr.product_id = menu.product_id
GROUP BY jmr.customer_id; 

-- 11. Recreate a sales table, with columns = customer_id, order_date, product_name, price, and Y/N column for membership.

SELECT sales.customer_id, sales.order_date, menu.product_name, menu.price,
    IFNULL(
    (CASE
    WHEN sales.order_date >= members.join_date THEN 'Y'
    ELSE 'N'
    END), 'N'
    ) AS member
FROM dannys_diner.sales AS sales
INNER JOIN dannys_diner.menu AS menu
ON sales.product_id = menu.product_id
LEFT JOIN dannys_diner.members AS members
ON sales.customer_id = members.customer_id; 

-- 12. Recreate a ranking table, with a new column named 'ranking' listing the ranking of times visited after registered as a member.

WITH membership_sales_table AS
    (SELECT sales.customer_id, sales.order_date, menu.product_name, menu.price,
        IFNULL(
            (CASE
            WHEN sales.order_date >= members.join_date THEN 'Y'
            ELSE 'N'
            END), 'N'
            ) AS member
    FROM dannys_diner.sales AS sales
    LEFT JOIN dannys_diner.menu AS menu
    ON sales.product_id = menu.product_id
    LEFT JOIN dannys_diner.members AS members
    ON sales.customer_id = members.customer_id)

SELECT *, 
    (CASE member
    WHEN 'N' THEN NULL
    ELSE RANK() OVER (PARTITION BY customer_id, member ORDER BY order_date)
    END) AS ranking
FROM membership_sales_table;