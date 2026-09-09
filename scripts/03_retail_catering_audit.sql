-- ============================================================================
-- FILE: /scripts/03_retail_catering_audit.sql
-- DESCRIPTION: Domain C Analytics - Catering Spoilage Density & Retail Margin Optimization
-- ARCHITECTURE LAYER: Retail Operations & Inventory Data Systems
-- ============================================================================

USE aero_ops_audit;

-- ----------------------------------------------------------------------------
-- SYNTHESIS LAYER: DDL and Data Generation Core Scripts
-- ----------------------------------------------------------------------------
-- Generates buy-on-board retail menu matrices by mapping flight leg lengths
-- to simulated inventory constraints, introducing distinct market mismatches.

DROP TABLE IF EXISTS fact_catering;

CREATE TABLE fact_catering (
    flight_date DATE,
    reporting_airline VARCHAR(10),
    tail_number VARCHAR(20),
    origin VARCHAR(10),
    dest VARCHAR(10),
    fresh_meals_boarded INT,
    fresh_meals_ordered INT,
    unit_cost_usd DECIMAL(10, 2),
    retail_price_usd DECIMAL(10, 2)
);

INSERT INTO fact_catering
SELECT 
    flight_date, 
    reporting_airline, 
    tail_number, 
    origin, 
    dest,
    -- Simulates standard short-haul menu loading thresholds (20-60 meals)
    FLOOR(20 + (RAND(1) * 40)) AS fresh_meals_boarded,
    
    -- Introduces high-friction purchasing drops on specific short commuter loops
    CASE 
        WHEN reporting_airline IN ('AA', 'DL') AND air_time < 90 THEN FLOOR(2 + (RAND(2) * 8)) 
        ELSE FLOOR(10 + (RAND(2) * 25)) 
    END AS fresh_meals_ordered,
    
    4.50 AS unit_cost_usd,       -- Procurement baseline contract pricing
    12.00 AS retail_price_usd    -- Public menu listed passenger price
FROM fact_flights 
WHERE cancelled = 0 AND air_time IS NOT NULL;


-- ----------------------------------------------------------------------------
-- QUESTION 11: Short-Haul Perishable Spoilage Density (Week-Over-Week)
-- ----------------------------------------------------------------------------
-- Calculates the exact percentage of perishable food items incinerated at 
-- flight destinations due to narrow operational cabin service windows.

WITH weekly_short_haul_spoilage AS (
    SELECT 
        WEEK(c.flight_date) AS calendar_week,
        f.air_time,
        c.fresh_meals_boarded,
        c.fresh_meals_ordered,
        (c.fresh_meals_boarded - c.fresh_meals_ordered) AS meals_thrown_in_trash
    FROM fact_catering c
    INNER JOIN fact_flights f ON c.flight_date = f.flight_date 
                             AND c.reporting_airline = f.reporting_airline 
                             AND c.tail_number = f.tail_number 
                             AND c.origin = f.origin 
                             AND c.dest = f.dest
    WHERE f.air_time < 90
)
SELECT 
    calendar_week,
    SUM(fresh_meals_boarded) AS total_meals_uploaded,
    SUM(fresh_meals_ordered) AS total_meals_sold,
    SUM(meals_thrown_in_trash) AS total_meals_trashed,
    ROUND((SUM(meals_thrown_in_trash) / SUM(fresh_meals_boarded)) * 100, 2) AS meal_spoilage_percentage
FROM weekly_short_haul_spoilage
GROUP BY calendar_week
ORDER BY calendar_week ASC;


-- ----------------------------------------------------------------------------
-- QUESTION 12 & 13: Top Sunk-Cost Corridor Inventory Mismatches
-- ----------------------------------------------------------------------------
-- Isolates specific airport route vectors bleeding the highest absolute capital,
-- mapping both physical sunk costs and foregone premium markup revenues.

SELECT 
    reporting_airline AS airline, 
    CONCAT(origin, ' -> ', dest) AS flight_corridor, 
    COUNT(*) AS total_monitored_flights,
    SUM(fresh_meals_boarded) AS total_meals_boarded,
    SUM(fresh_meals_ordered) AS total_meals_ordered,
    SUM(fresh_meals_boarded - fresh_meals_ordered) AS total_meals_wasted,
    ROUND(AVG(fresh_meals_boarded - fresh_meals_ordered), 1) AS avg_excess_meals_per_flight,
    
    -- Direct Sunk Cost: Value of physical assets trashed
    ROUND(SUM(fresh_meals_boarded - fresh_meals_ordered) * 4.50, 2) AS direct_sunk_cost_loss_usd,
    
    -- Opportunity Loss: Uncaptured retail demand value
    ROUND(SUM(fresh_meals_boarded - fresh_meals_ordered) * 12.00, 2) AS lost_retail_revenue_opportunity_usd
FROM fact_catering
GROUP BY reporting_airline, origin, dest
ORDER BY direct_sunk_cost_loss_usd DESC
LIMIT 5;


-- ----------------------------------------------------------------------------
-- QUESTION 14: The flynas-Style Packaged Snack Margin Turnaround Simulation
-- ----------------------------------------------------------------------------
-- Evaluates the financial viability of moving from perishable catering networks
-- to non-perishable models, removing waste variables to secure optimal margins.
-- Aggregates use MAX/AVG wrappers to bypass database full_group_by strict constraints.

SELECT 
    reporting_airline AS airline, 
    COUNT(*) AS total_short_haul_flights,
    SUM(fresh_meals_boarded) AS total_fresh_meals_loaded,
    SUM(fresh_meals_ordered) AS total_meals_sold,
    
    -- Current Performance Framework (Subtracts absolute cost of ALL boarding logs)
    ROUND(SUM(fresh_meals_ordered * retail_price_usd) - SUM(fresh_meals_boarded * unit_cost_usd), 2) AS current_fresh_net_margin_usd,
    
    -- Non-Perishable Flow Model (Airline only absorbs procurement bills for items consumed)
    ROUND(SUM(fresh_meals_ordered * retail_price_usd) - SUM(fresh_meals_ordered * unit_cost_usd), 2) AS simulated_shelf_stable_margin_usd,
    
    -- Net Capital Reclaimed by moving away from perishable items
    ROUND(SUM(fresh_meals_boarded - fresh_meals_ordered) * MAX(unit_cost_usd), 2) AS total_capital_saved_usd
FROM fact_catering
GROUP BY reporting_airline
ORDER BY total_capital_saved_usd DESC;
