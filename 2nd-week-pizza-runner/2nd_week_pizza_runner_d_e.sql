-- Pizza Runner
-- D. Pricing and Ratings

-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
SELECT SUM(CASE pn.pizza_name WHEN 'Meatlovers' THEN 12 WHEN 'Vegetarian' THEN 10 ELSE NULL END) AS total_revenue
FROM pizza_runner.customer_orders_clean AS coc
INNER JOIN pizza_runner.pizza_names AS pn
ON coc.pizza_id = pn.pizza_id
INNER JOIN pizza_runner.runner_orders_clean AS roc
ON coc.order_id = roc.order_id
WHERE roc.cancellation IS NULL; 

-- 2. What if there was an additional $1 charge for any pizza extras?
-- 2.1. Add cheese is $1 extra

WITH exclude_cancellation AS
    (SELECT coc.*
    FROM pizza_runner.customer_orders_clean AS coc
    INNER JOIN pizza_runner.runner_orders_clean AS roc
    ON coc.order_id = roc.order_id
    WHERE roc.cancellation IS NULL),
    
    pizza_price AS
    (SELECT *,
    CASE pizza_name WHEN 'Meatlovers' THEN 12 WHEN 'Vegetarian' THEN 10 ELSE NULL END AS pizza_price
    FROM pizza_runner.pizza_names)

SELECT SUM(pp.pizza_price) + 
    (SELECT COUNT(*)*1 AS extra_rev
    FROM (SELECT * FROM exclude_cancellation, LATERAL SPLIT_TO_TABLE(exclude_cancellation.extras, ', '))) 
    AS total_revenue
FROM exclude_cancellation AS excl_cancel
INNER JOIN pizza_price AS pp
ON excl_cancel.pizza_id = pp.pizza_id; 

-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.

DROP TABLE IF EXISTS runner_rating;
CREATE TABLE runner_rating(
    order_id INT,
    ratings INT);

INSERT INTO pizza_runner.runner_rating 
(order_id, ratings) 
VALUES
(1, 3),
(2, 4),
(3, 4),
(4, 2),
(5, 5),
(7, 4),
(8, 5),
(10, 3); 

-- 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
        --customer_id, order_id, runner_id, ratings, order_time
        --pickup_time, Time between order and pickup, Delivery duration, Average speed, Total number of pizzas

SELECT coc.customer_id, rr.order_id, roc.runner_id, rr.ratings, coc.order_time, roc.pickup_time, 
    TIMEDIFF(MINUTE, coc.order_time, roc.pickup_time) AS time_between_order_and_pickup,
    roc.duration AS delivery_duration,
    ROUND(roc.distance / (roc.duration/60), 2) AS avg_speed_km_per_hr, 
    coc.total_no_of_pizza_per_order
FROM pizza_runner.runner_rating AS rr
INNER JOIN 
    (SELECT customer_id, order_id, order_time, COUNT(*) AS total_no_of_pizza_per_order 
    FROM pizza_runner.customer_orders_clean
    GROUP BY customer_id, order_id, order_time) AS coc
ON rr.order_id = coc.order_id
INNER JOIN pizza_runner.runner_orders_clean AS roc
ON rr.order_id = roc.order_id
ORDER BY rr.order_id; 

-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?

WITH pizza_price AS
    (SELECT *,
    CASE pizza_name WHEN 'Meatlovers' THEN 12 
        WHEN 'Vegetarian' THEN 10 ELSE NULL END AS pizza_price
    FROM pizza_runner.pizza_names),

    total_rev_per_order AS
    (SELECT order_id, SUM(pizza_price) AS total_rev
    FROM pizza_runner.customer_orders_clean AS coc
    INNER JOIN pizza_price AS pp
    ON coc.pizza_id = pp.pizza_id
    GROUP BY order_id)

SELECT SUM(rev.total_rev) - SUM(roc.distance)*0.3 AS net_profit
FROM total_rev_per_order AS rev
INNER JOIN pizza_runner.runner_orders_clean AS roc
ON rev.order_id = roc.order_id
WHERE roc.cancellation IS NULL; 

-- E. Bonus Questions
-- If Danny wants to expand his range of pizzas - how would this impact the existing data design? Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu.
INSERT INTO pizza_runner.pizza_names (pizza_id, pizza_name)
VALUES
(3, 'Supreme');

INSERT INTO pizza_runner.pizza_recipes (pizza_id, toppings)
SELECT 3 AS pizza_id, LISTAGG(topping_id, ', ') AS toppings
FROM pizza_runner.pizza_toppings; 
