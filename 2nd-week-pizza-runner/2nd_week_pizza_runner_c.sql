-- Pizza Runner
-- Part C. Ingredient Optimization

-- 1. What are the standard ingredients for each pizza?
SELECT pn.pizza_name, LISTAGG(pt.topping_name, ', ') AS name_list_of_ingredient
FROM (SELECT pizza_id, TRIM(value) AS topping_id 
    FROM pizza_runner.pizza_recipes, LATERAL SPLIT_TO_TABLE(pizza_runner.pizza_recipes.toppings, ',')) AS pr
INNER JOIN pizza_runner.pizza_names AS pn
ON pr.pizza_id = pn.pizza_id
INNER JOIN pizza_runner.pizza_toppings AS pt
ON pr.topping_id = pt.topping_id
GROUP BY pn.pizza_name; 

-- 2. What was the most commonly added extra?
SELECT MODE(pt.topping_name) AS most_common_extra
FROM pizza_runner.customer_orders_clean, 
    LATERAL SPLIT_TO_TABLE(pizza_runner.customer_orders_clean.extras, ', ') AS coc_split_extras
INNER JOIN pizza_runner.pizza_toppings AS pt
ON coc_split_extras.value = pt.topping_id; 

-- 3. What was the most common exclusion?
SELECT MODE(pt.topping_name) AS most_common_exclusion
FROM pizza_runner.customer_orders_clean, 
    LATERAL SPLIT_TO_TABLE(pizza_runner.customer_orders_clean.exclusions, ', ') AS coc_split_excl
INNER JOIN pizza_runner.pizza_toppings AS pt
ON coc_split_excl.value = pt.topping_id; 

-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
--        Meat Lovers
--        Meat Lovers - Exclude Beef
--        Meat Lovers - Extra Bacon
--        Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

WITH change_topping_table AS
    (SELECT exclusions AS topping_id FROM pizza_runner.customer_orders_clean
    UNION
    SELECT extras AS topping_id FROM pizza_runner.customer_orders_clean),

    change_topping_name_table AS
    (SELECT split_topping.topping_id, LISTAGG(pt.topping_name, ', ') AS change_topping_name_list
    FROM (SELECT DISTINCT * FROM change_topping_table, LATERAL SPLIT_TO_TABLE(change_topping_table.topping_id, ', ')) AS split_topping
    INNER JOIN pizza_runner.pizza_toppings as pt
    ON split_topping.value = pt.topping_id
    GROUP BY split_topping.topping_id)

SELECT coc.order_id, coc.customer_id, coc.pizza_id, coc.order_time, coc.exclusions, coc.extras, 
    CONCAT(pn.pizza_name, 
        COALESCE(' - Exclude ' || ctn1.change_topping_name_list_excl, ''), 
        COALESCE(' - Extra ' || ctn2.change_topping_name_list_extra, '')) AS order_item
FROM pizza_runner.customer_orders_clean AS coc
INNER JOIN pizza_runner.pizza_names AS pn
ON coc.pizza_id = pn.pizza_id
LEFT JOIN 
    (SELECT topping_id, change_topping_name_list AS change_topping_name_list_excl 
    FROM change_topping_name_table) as ctn1
ON coc.exclusions = ctn1.topping_id
LEFT JOIN 
    (SELECT topping_id, change_topping_name_list AS change_topping_name_list_extra 
    FROM change_topping_name_table) as ctn2
on coc.extras = ctn2.topping_id; 

-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
--        For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
WITH customer_orders_clean_ingred_list AS
    (SELECT coc.order_id, coc.customer_id, coc.pizza_id, coc.order_time, coc.exclusions, coc.extras, 
        coc.pizza_id || COALESCE(' - ' || coc.exclusions, '') || COALESCE(' + ' || coc.extras, '') AS change_record_id
    FROM pizza_runner.customer_orders_clean AS coc),

    records_with_change AS
    (SELECT DISTINCT coc_ingred_list.exclusions, coc_ingred_list.extras, pr.toppings, change_record_id
    FROM customer_orders_clean_ingred_list AS coc_ingred_list
    INNER JOIN pizza_runner.pizza_recipes AS pr
    ON coc_ingred_list.pizza_id = pr.pizza_id
    WHERE coc_ingred_list.exclusions IS NOT NULL OR coc_ingred_list.extras IS NOT NULL),

    record_with_change_expanded AS
    (SELECT exclusions, extras, change_record_id, value AS topping_id, +1 AS topping_count
    FROM records_with_change, LATERAL SPLIT_TO_TABLE (records_with_change.extras, ', ')
    UNION
    SELECT exclusions, extras, change_record_id, value AS topping_id, -1 AS topping_count
    FROM records_with_change, LATERAL SPLIT_TO_TABLE (records_with_change.exclusions, ', ')
    UNION ALL
    SELECT exclusions, extras, change_record_id, value AS topping_id, +1 AS topping_count
    FROM records_with_change, LATERAL SPLIT_TO_TABLE (records_with_change.toppings, ', ')),

    grouped_records_with_change_expanded AS
    (SELECT change_record_id, topping_id, SUM(topping_count) AS topping_sum    
    FROM record_with_change_expanded
    GROUP BY change_record_id, topping_id
    HAVING topping_sum > 0),

    records_with_change_name_count AS
    (SELECT change_record_id,
        CASE WHEN topping_sum > 1 THEN topping_sum || 'x' || topping_name ELSE topping_name END AS topping_name_count
    FROM grouped_records_with_change_expanded AS grp_records
    INNER JOIN pizza_runner.pizza_toppings AS pt
    ON grp_records.topping_id = pt.topping_id
    ORDER BY topping_name),

    records_with_change_name_list AS
    (SELECT change_record_id, LISTAGG(topping_name_count, ', ') AS change_toppings
    FROM records_with_change_name_count
    GROUP BY change_record_id),

    default_pizza_topping_name_list AS
    (SELECT pr.pizza_id, LISTAGG(pt.topping_name, ', ') AS default_toppings, pn.pizza_name
    FROM (SELECT * FROM pizza_runner.pizza_recipes, LATERAL SPLIT_TO_TABLE(pizza_runner.pizza_recipes.toppings, ', ')) AS pr
    INNER JOIN pizza_runner.pizza_toppings AS pt
    ON pr.value = pt.topping_id
    INNER JOIN pizza_runner.pizza_names AS pn
    ON pr.pizza_id = pn.pizza_id
    GROUP BY pr.pizza_id, pn.pizza_name
    ORDER BY pr.pizza_id)

SELECT coc_ingred_list.order_id, coc_ingred_list.customer_id, coc_ingred_list.pizza_id, 
    coc_ingred_list.order_time, coc_ingred_list.exclusions, coc_ingred_list.extras,
    CONCAT(default_name_list.pizza_name || ': ', 
        COALESCE(change_name_list.change_toppings, default_name_list.default_toppings, '')) AS ingredient_list
FROM customer_orders_clean_ingred_list AS coc_ingred_list
LEFT JOIN records_with_change_name_list AS change_name_list
ON coc_ingred_list.change_record_id = change_name_list.change_record_id
INNER JOIN default_pizza_topping_name_list AS default_name_list
ON coc_ingred_list.pizza_id = default_name_list.pizza_id; 


-- 6. What is the total quantity of each ingredient used in all delivered pizzas
-- sorted by most frequent first?

WITH customer_orders_clean_ingred_list AS
    (SELECT coc.order_id, coc.customer_id, coc.pizza_id, 
        coc.order_time, coc.exclusions, coc.extras, pr.toppings,
        pr.toppings || COALESCE(', ' || coc.extras, '') AS default_and_extras
    FROM pizza_runner.customer_orders_clean AS coc
    INNER JOIN pizza_runner.pizza_recipes AS pr
    ON coc.pizza_id = pr.pizza_id
    INNER JOIN pizza_runner.runner_orders_clean AS roc
    ON coc.order_id = roc.order_id
    WHERE roc.cancellation IS NULL),

    total_qty_ingredient AS
    (SELECT topping_id, SUM(count_toppings) AS total_qty
    FROM
        ((SELECT value AS topping_id, COUNT(*) AS count_toppings
        FROM customer_orders_clean_ingred_list, 
            LATERAL SPLIT_TO_TABLE(customer_orders_clean_ingred_list.default_and_extras, ', ')
        GROUP BY value)
        UNION ALL
        (SELECT * 
        FROM
        (SELECT value AS topping_id, -1 AS count_toppings
        FROM customer_orders_clean_ingred_list, 
            LATERAL SPLIT_TO_TABLE(customer_orders_clean_ingred_list.exclusions, ', '))))
    GROUP BY topping_id)

SELECT pt.topping_name, total_qty
FROM total_qty_ingredient AS ingred_qty
INNER JOIN pizza_runner.pizza_toppings AS pt
ON ingred_qty.topping_id = pt.topping_id
ORDER BY total_qty DESC; 
