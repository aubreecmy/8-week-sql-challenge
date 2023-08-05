-- Pizza Runner
-- Part B. Runner and Customer Experience

-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
WITH week_starts AS 
    (SELECT '2021-01-01'::DATE AS week_start
    UNION ALL
    SELECT DATEADD(DAY, 7, week_start)
    FROM week_starts
    WHERE DATEADD(DAY, 7, week_start) <= (SELECT MAX(registration_date) FROM pizza_runner.runners))
SELECT week_starts.week_start, COUNT(runner_id) AS count_runners_signed_up
FROM week_starts
INNER JOIN pizza_runner.runners AS runners
ON runners.registration_date >= week_starts.week_start 
AND runners.registration_date < DATEADD(DAY, 7, week_starts.week_start)
GROUP BY week_starts.week_start
ORDER BY week_starts.week_start; 

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
SELECT roc.runner_id, 
    ROUND(AVG(TIMEDIFF(MINUTE, coc.order_time, roc.pickup_time))) AS avg_time_needed_for_pickup_min
FROM (SELECT DISTINCT order_time, order_id FROM pizza_runner.customer_orders_clean) AS coc
INNER JOIN (SELECT order_id, pickup_time, runner_id FROM pizza_runner.runner_orders_clean WHERE cancellation IS NULL) AS roc
ON coc.order_id = roc.order_id
GROUP BY roc.runner_id
ORDER BY roc.runner_id; 

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
SELECT number_of_pizza_per_order , ROUND(AVG(TIMEDIFF(SECOND, coc.order_time, roc.pickup_time)), 2) AS avg_time_needed_for_pickup_second
FROM (SELECT order_id, order_time, COUNT(pizza_id) AS number_of_pizza_per_order 
        FROM pizza_runner.customer_orders_clean GROUP BY order_id, order_time) AS coc
INNER JOIN (SELECT order_id, pickup_time, runner_id FROM pizza_runner.runner_orders_clean WHERE cancellation IS NULL) AS roc
ON coc.order_id = roc.order_id
GROUP BY number_of_pizza_per_order; 

-- 4. What was the average distance travelled for each customer?
SELECT coc.customer_id, ROUND(AVG(distance),2) AS avg_distance_per_customer
FROM (SELECT DISTINCT order_id, customer_id FROM pizza_runner.customer_orders_clean) AS coc
INNER JOIN (SELECT order_id, distance FROM pizza_runner.runner_orders_clean WHERE cancellation IS NULL) AS roc
ON coc.order_id = roc.order_id
GROUP BY coc.customer_id; 

-- 5. What was the difference between the longest and shortest delivery times for all orders?
SELECT MAX(duration) - MIN(duration) AS MAX_duration_diff_in_min
FROM pizza_runner.runner_orders_clean; 

SELECT *
FROM (SELECT order_id, runner_id, distance, duration, RANK() OVER (PARTITION BY runner_id ORDER BY pickup_time) AS number_of_pickup FROM pizza_runner.runner_orders_clean)
WHERE duration = (SELECT MAX(duration) FROM pizza_runner.runner_orders_clean) 
OR duration = (SELECT MIN(duration) FROM pizza_runner.runner_orders_clean); 

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT RANK() OVER (PARTITION BY runner_id ORDER BY pickup_time) AS number_of_pickup,
    runner_id, distance, duration, ROUND(distance/(duration/60),2) AS speed_km_per_hour
FROM pizza_runner.runner_orders_clean AS roc
WHERE cancellation IS NULL
ORDER BY runner_id, pickup_time; 

-- 7. What is the successful delivery percentage for each runner?
WITH successful_delivery_percentage AS
    (SELECT runner_id, 
        ROUND((1 - (COUNT(cancellation) / COUNT(order_id))) * 100, 2) AS successful_delivery_percentage
    FROM pizza_runner.runner_orders_clean AS roc
    GROUP BY runner_id
    ORDER BY runner_id)

SELECT runner_id, order_id, cancellation, RANK() OVER (PARTITION BY runner_id ORDER BY pickup_time) AS number_of_cancellation
FROM pizza_runner.runner_orders_clean AS roc
WHERE runner_id in (SELECT runner_id FROM successful_delivery_percentage WHERE successful_delivery_percentage < 100)
AND cancellation IS NOT NULL; 