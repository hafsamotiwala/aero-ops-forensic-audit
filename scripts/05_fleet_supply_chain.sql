-- ============================================================================
-- FILE: /scripts/05_fleet_supply_chain.sql
-- DESCRIPTION: Domain B Analytics - AOG Revenue Leakages, Inventory Valuation & ROP Triggers
-- ARCHITECTURE LAYER: Engineering Logistics & Fleet Material Management
-- ============================================================================

USE aero_ops_audit;

-- ----------------------------------------------------------------------------
-- SYNTHESIS LAYER: DDL and Data Generation Core Scripts
-- ----------------------------------------------------------------------------
-- Simulates a localized warehouse stock tracking system across active hubs,
-- populating wear-and-tear aviation components mapped to random stockout events.

DROP TABLE IF EXISTS fact_maintenance_inventory;

CREATE TABLE fact_maintenance_inventory (
    warehouse_hangar VARCHAR(10),
    tail_number VARCHAR(20),
    component_name VARCHAR(50),
    component_class CHAR(1),               -- ABC Inventory Classification Code
    current_stock_qty INT,
    average_monthly_demand INT,
    lead_time_days INT,                    -- Manufacturing + Shipping Pipeline Window
    unit_cost_usd DECIMAL(10, 2),
    aog_grounded_days INT                  -- Number of days aircraft sat paralyzed waiting for part
);

INSERT INTO fact_maintenance_inventory
SELECT 
    f.origin AS warehouse_hangar, 
    f.tail_number,
    -- Simulates localized component wear requirements
    CASE 
        WHEN RAND(5) < 0.33 THEN 'Main Landing Gear Tire' 
        WHEN RAND(5) < 0.66 THEN 'Carbon Brake Wear Pad' 
        ELSE 'High-Efficiency Engine Oil Filter' 
    END AS component_name,
    -- Segment classes: A (High value/critical), B (Medium), C (Low value/volume)
    CASE 
        WHEN RAND(6) < 0.20 THEN 'A' 
        WHEN RAND(6) < 0.60 THEN 'B' 
        ELSE 'C' 
    END AS component_class,
    FLOOR(1 + (RAND(7) * 8)) AS current_stock_qty, 
    FLOOR(5 + (RAND(8) * 15)) AS average_monthly_demand, 
    FLOOR(5 + (RAND(9) * 25)) AS lead_time_days,
    -- Establishes standard commercial fleet spare pricing
    CASE 
        WHEN RAND(5) < 0.33 THEN 2500.00 
        WHEN RAND(5) < 0.66 THEN 8500.00 
        ELSE 450.00 
    END AS unit_cost_usd,
    -- Generates isolated out-of-stock events creating AOG constraints
    CASE 
        WHEN RAND(10) < 0.08 THEN FLOOR(1 + (RAND(11) * 4)) 
        ELSE 0 
    END AS aog_grounded_days
FROM fact_flights f 
WHERE f.cancelled = 0
GROUP BY f.origin, f.tail_number;

SELECT 'Fleet supply chain logs populated' AS Status, COUNT(*) FROM fact_maintenance_inventory;


-- ----------------------------------------------------------------------------
-- QUESTION 06 & 10: ABC Inventory Segmentations & Trapped Hangar Capital
-- ----------------------------------------------------------------------------
-- Exposes liquidity restrictions by tracking exactly where corporate capital 
-- is frozen on storage shelves, cross-referencing global pipeline lead times.

SELECT 
    warehouse_hangar AS hangar_location, 
    component_class, 
    COUNT(*) AS total_tracked_components,
    SUM(current_stock_qty) AS total_parts_on_hand,
    ROUND(SUM(current_stock_qty * unit_cost_usd), 2) AS trapped_inventory_capital_usd,
    ROUND(AVG(lead_time_days), 1) AS avg_manufacturer_lead_time_days
FROM fact_maintenance_inventory
GROUP BY warehouse_hangar, component_class
ORDER BY trapped_inventory_capital_usd DESC
LIMIT 5;


-- ----------------------------------------------------------------------------
-- QUESTION 07: Sunk Out-of-Stock AOG Fleet Operational Revenue Leakage
-- ----------------------------------------------------------------------------
-- Quantifies the severe financial impact of under-stocking. Maps grounded days 
-- straight to lost ticket velocity ($25,000 USD/day standard asset grounding penalty).

SELECT 
    warehouse_hangar AS failure_location, 
    COUNT(CASE WHEN aog_grounded_days > 0 THEN 1 END) AS total_aircraft_grounded_events,
    SUM(aog_grounded_days) AS cumulative_days_grounded,
    ROUND(SUM(unit_cost_usd), 2) AS emergency_parts_cost_usd,
    ROUND(SUM(aog_grounded_days) * 25000.00, 2) AS total_aog_revenue_leakage_usd
FROM fact_maintenance_inventory
WHERE aog_grounded_days > 0
GROUP BY warehouse_hangar
ORDER BY total_aog_revenue_leakage_usd DESC
LIMIT 5;


-- ----------------------------------------------------------------------------
-- QUESTION 08 & 09: Dynamic Safety Stock & Automated Reorder Point (ROP)
-- ----------------------------------------------------------------------------
-- Applies an automated inventory defense framework to secure a 0% stockout path.
-- Safety Stock = (Max Lead Time * Max Demand) - (Avg Lead Time * Avg Demand)
-- Reorder Point (ROP) = (Average Daily Demand * Lead Time) + Safety Stock

WITH supply_chain_stats AS (
    SELECT 
        warehouse_hangar, 
        component_name,
        AVG(average_monthly_demand / 30.0) AS daily_demand_avg,
        AVG(lead_time_days) AS lead_time_avg,
        (AVG(average_monthly_demand / 30.0) * 1.5) AS max_daily_demand,
        (AVG(lead_time_days) * 1.3) AS max_lead_time_days
    FROM fact_maintenance_inventory
    GROUP BY warehouse_hangar, component_name
),
safety_stock_calc AS (
    SELECT 
        warehouse_hangar, 
        component_name, 
        daily_demand_avg, 
        lead_time_avg,
        -- Employs max capacity vs average consumption variance vectors
        ROUND((max_lead_time_days * max_daily_demand) - (lead_time_avg * daily_demand_avg), 0) AS calculated_safety_stock
    FROM supply_chain_stats
)
SELECT 
    warehouse_hangar AS hangar_location, 
    component_name, 
    calculated_safety_stock AS optimal_safety_stock_units,
    -- Triggers an automatic order when physical counts intersect this level
    ROUND((daily_demand_avg * lead_time_avg) + calculated_safety_stock, 0) AS automated_reorder_point_trigger_level
FROM safety_stock_calc
ORDER BY automated_reorder_point_trigger_level DESC
LIMIT 5;
