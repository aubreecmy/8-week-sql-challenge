-- Case Study Questions
-- Part A. Pizza Metrics

-- 1. How many pizzas were ordered?
SELECT COUNT(*) AS count_pizza_order 
FROM pizza_runner.customer_orders_clean; 

-- 2. How many unique customer orders were made?
SELECT COUNT(DISTINCT customer_id) AS count_distinct_customers 
FROM pizza_runner.customer_orders_clean; 

-- 3. How many successful orders were delivered by each runner?
SELECT COUNT(*) AS count_successful_delivery 
FROM pizza_runner.runner_orders_clean
WHERE cancellation IS NULL; 
    
-- 4. How many of each type of pizza was delivered?
SELECT pn.pizza_name, COUNT(*) AS count_pizza_delivered
FROM pizza_runner.runner_orders_clean AS roc
INNER JOIN pizza_runner.customer_orders_clean AS coc
ON roc.order_id = coc.order_id
INNER JOIN pizza_runner.pizza_names as pn
ON coc.pizza_id = pn.pizza_id
WHERE roc.cancellation IS NULL
GROUP BY pn.pizza_name; 


-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT coc.customer_id, pn.pizza_name, COUNT(*) AS count_pizza_ordered
FROM pizza_runner.customer_orders_clean AS coc
INNER JOIN pizza_runner.pizza_names AS pn
ON coc.pizza_id = pn.pizza_id
GROUP BY coc.customer_id, pn.pizza_name
ORDER BY coc.customer_id, pn.pizza_name; 

-- 6. What was the maximum number of pizzas delivered in a single order?
SELECT MAX(coc.count_pizza_per_order) AS max_count_pizza_per_order
FROM 
    (SELECT order_id, COUNT(pizza_id) AS count_pizza_per_order 
    FROM pizza_runner.customer_orders_clean 
    GROUP BY order_id) AS coc
INNER JOIN pizza_runner.runner_orders_clean AS roc
ON coc.order_id = roc.order_id
WHERE roc.cancellation IS NULL; 

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT coc.customer_id, coc.change_on_pizza, COUNT(*) AS count_pizza_delivered
FROM (
    SELECT order_id, customer_id, 
    CASE WHEN exclusions IS NULL and extras IS NULL THEN 'No Changes' ELSE 'At least 1 change' END AS change_on_pizza 
    FROM pizza_runner.customer_orders_clean) AS coc
INNER JOIN (SELECT * FROM pizza_runner.runner_orders_clean WHERE cancellation IS NULL) AS roc
ON coc.order_id = roc.order_id
GROUP BY coc.customer_id, coc.change_on_pizza
ORDER BY coc.customer_id, coc.change_on_pizza; 

-- 8. How many pizzas were delivered that had both exclusions and extras?
SELECT COUNT(*) AS count_pizza_delivered_both_exclusions_and_extras
FROM (
    SELECT order_id
    FROM pizza_runner.customer_orders_clean
    WHERE exclusions IS NOT NULL and extras IS NOT NULL) AS coc
INNER JOIN (SELECT * FROM pizza_runner.runner_orders_clean WHERE cancellation IS NULL) AS roc
ON coc.order_id = roc.order_id; 
    
-- 9. What was the total volume of pizzas ordered for each hour of the day?
SELECT hour(order_time), COUNT(pizza_id) AS count_pizza
FROM pizza_runner.customer_orders_clean
GROUP BY hour(order_time)
ORDER BY hour(order_time); 

-- 10. What was the volume of orders for each day of the week?
SELECT dayname(order_time), COUNT(DISTINCT order_id) AS count_order
FROM pizza_runner.customer_orders_clean
GROUP BY dayofweek(order_time), dayname(order_time)
ORDER BY dayofweek(order_time); 
