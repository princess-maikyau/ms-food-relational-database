-- Analysis 1
-- Products with the highest total waste (units and cost)

SELECT
    p.product_id,
    p.product_name,
    SUM(i.waste_units) AS total_waste_units,
    ROUND(SUM(i.waste_units * p.unit_cost_price), 2) AS total_waste_cost
FROM Inventory AS i
JOIN Product AS p
    ON i.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_waste_cost DESC
LIMIT 10;

-- Analysis 2
-- Products with the highest stockout frequency

SELECT
    p.product_id,
    p.product_name,
    SUM(i.stockout_flag) AS stockout_days,
    COUNT(*) AS total_records,
    ROUND(AVG(i.stockout_flag * 1.0), 4) AS stockout_rate
FROM Inventory AS i
JOIN Product AS p
    ON i.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY stockout_rate DESC,
         stockout_days DESC
LIMIT 10;

-- Analysis 3
-- Products with both high waste cost and high stockout risk

WITH waste_summary AS (
    SELECT
        p.product_id,
        p.product_name,
        SUM(i.waste_units) AS total_waste_units,
        ROUND(SUM(i.waste_units * p.unit_cost_price), 2) AS total_waste_cost
    FROM Inventory AS i
    JOIN Product AS p
        ON i.product_id = p.product_id
    GROUP BY
        p.product_id,
        p.product_name
),

stockout_summary AS (
    SELECT
        p.product_id,
        SUM(i.stockout_flag) AS stockout_days,
        COUNT(*) AS total_records,
        ROUND(AVG(i.stockout_flag * 1.0), 4) AS stockout_rate
    FROM Inventory AS i
    JOIN Product AS p
        ON i.product_id = p.product_id
    GROUP BY
        p.product_id
)

SELECT
    w.product_id,
    w.product_name,
    w.total_waste_units,
    w.total_waste_cost,
    s.stockout_days,
    s.stockout_rate
FROM waste_summary AS w
JOIN stockout_summary AS s
    ON w.product_id = s.product_id
WHERE
    w.total_waste_cost > (SELECT AVG(total_waste_cost) FROM waste_summary)
    AND s.stockout_rate > (SELECT AVG(stockout_rate) FROM stockout_summary)
ORDER BY
    s.stockout_rate DESC,
    w.total_waste_cost DESC;
	
-- Analysis 4
-- On-time delivery performance by supplier

SELECT
    s.supplier_id,
    s.supplier_name,
    COUNT(*) AS total_deliveries,
    SUM(CASE WHEN d.delivery_status <> 'Failed' AND d.delay_hours <= 0 THEN 1 ELSE 0 END) AS on_time_deliveries,
    ROUND(AVG(CASE WHEN d.delivery_status <> 'Failed' AND d.delay_hours <= 0 THEN 1.0 ELSE 0.0 END), 4) AS on_time_rate
FROM Delivery AS d
JOIN Supplier AS s
    ON d.supplier_id = s.supplier_id
GROUP BY
    s.supplier_id,
    s.supplier_name
HAVING COUNT(*) >= 2
ORDER BY on_time_rate ASC,
         total_deliveries DESC
LIMIT 10;

-- Analysis 5
-- Temperature excursion rate by supplier

SELECT
    s.supplier_id,
    s.supplier_name,
    COUNT(*) AS total_delivery_lines,
    SUM(CASE WHEN dl.temp_excursion_flag = 1 THEN 1 ELSE 0 END) AS excursion_lines,
    ROUND(AVG(dl.temp_excursion_flag * 1.0), 4) AS excursion_rate
FROM DeliveryLine AS dl
JOIN Delivery AS d
    ON dl.delivery_id = d.delivery_id
JOIN Supplier AS s
    ON d.supplier_id = s.supplier_id
WHERE d.delivery_status <> 'Failed'
GROUP BY
    s.supplier_id,
    s.supplier_name
HAVING COUNT(*) >= 3
ORDER BY excursion_rate DESC,
         total_delivery_lines DESC
LIMIT 10;

-- Analysis 6
-- Mean and variance of delivery delay by supplier

SELECT
    s.supplier_id,
    s.supplier_name,
    COUNT(*) AS total_deliveries,
    ROUND(AVG(d.delay_hours), 2) AS mean_delay_hours,
    ROUND(AVG(d.delay_hours * d.delay_hours) - AVG(d.delay_hours) * AVG(d.delay_hours), 2) AS variance_delay_hours
FROM Delivery AS d
JOIN Supplier AS s
    ON d.supplier_id = s.supplier_id
WHERE d.delivery_status <> 'Failed'
GROUP BY
    s.supplier_id,
    s.supplier_name
HAVING COUNT(*) >= 2
ORDER BY variance_delay_hours DESC,
         mean_delay_hours DESC
LIMIT 10;

-- Analysis 7
-- Supplier tier classification based on a composite cold chain score

WITH on_time_summary AS (
    SELECT
        s.supplier_id,
        s.supplier_name,
        COUNT(*) AS total_deliveries,
        ROUND(AVG(CASE
            WHEN d.delivery_status <> 'Failed' AND d.delay_hours <= 0 THEN 1.0
            ELSE 0.0
        END), 4) AS on_time_rate
    FROM Delivery AS d
    JOIN Supplier AS s
        ON d.supplier_id = s.supplier_id
    GROUP BY
        s.supplier_id,
        s.supplier_name
    HAVING COUNT(*) >= 2
),

excursion_summary AS (
    SELECT
        s.supplier_id,
        ROUND(AVG(dl.temp_excursion_flag * 1.0), 4) AS excursion_rate
    FROM DeliveryLine AS dl
    JOIN Delivery AS d
        ON dl.delivery_id = d.delivery_id
    JOIN Supplier AS s
        ON d.supplier_id = s.supplier_id
    WHERE d.delivery_status <> 'Failed'
    GROUP BY
        s.supplier_id
    HAVING COUNT(*) >= 3
),

delay_variance_summary AS (
    SELECT
        s.supplier_id,
        ROUND(
            AVG(d.delay_hours * d.delay_hours) - AVG(d.delay_hours) * AVG(d.delay_hours),
            2
        ) AS variance_delay_hours
    FROM Delivery AS d
    JOIN Supplier AS s
        ON d.supplier_id = s.supplier_id
    WHERE d.delivery_status <> 'Failed'
    GROUP BY
        s.supplier_id
    HAVING COUNT(*) >= 2
),

composite_score AS (
    SELECT
        o.supplier_id,
        o.supplier_name,
        o.total_deliveries,
        o.on_time_rate,
        e.excursion_rate,
        v.variance_delay_hours,

        CASE
            WHEN o.on_time_rate >= 0.85 THEN 40
            WHEN o.on_time_rate >= 0.75 THEN 30
            WHEN o.on_time_rate >= 0.65 THEN 20
            ELSE 10
        END AS on_time_score,

        CASE
            WHEN e.excursion_rate <= 0.20 THEN 40
            WHEN e.excursion_rate <= 0.35 THEN 30
            WHEN e.excursion_rate <= 0.50 THEN 20
            ELSE 10
        END AS excursion_score,

        CASE
            WHEN v.variance_delay_hours <= 40 THEN 20
            WHEN v.variance_delay_hours <= 80 THEN 15
            WHEN v.variance_delay_hours <= 120 THEN 10
            ELSE 5
        END AS stability_score

    FROM on_time_summary AS o
    JOIN excursion_summary AS e
        ON o.supplier_id = e.supplier_id
    JOIN delay_variance_summary AS v
        ON o.supplier_id = v.supplier_id
)

SELECT
    supplier_id,
    supplier_name,
    total_deliveries,
    on_time_rate,
    excursion_rate,
    variance_delay_hours,
    on_time_score,
    excursion_score,
    stability_score,
    (on_time_score + excursion_score + stability_score) AS composite_score,
  CASE
    WHEN (on_time_score + excursion_score + stability_score) >= 65 THEN 'Tier 1'
    WHEN (on_time_score + excursion_score + stability_score) >= 50 THEN 'Tier 2'
    ELSE 'Tier 3'
  END AS supplier_tier
FROM composite_score
ORDER BY
    composite_score DESC,
    on_time_rate DESC,
    excursion_rate ASC;