-- ============================================================================
-- FILE: /scripts/02_fuel_leakage_audit.sql
-- DESCRIPTION: Domain A Analytics - Taxi Latency, Propulsion Fuel Burn, & Carbon Tax Audits
-- ARCHITECTURE LAYER: Forensic Business Intelligence & Core Analytics
-- ============================================================================

USE aero_ops_audit;

-- ----------------------------------------------------------------------------
-- QUESTION 01 & 02: MACRO FLEET FUEL BLEED ACCOUNTING & CASH DESTRUCTION
-- ----------------------------------------------------------------------------
-- Computes total financial dollar loss from tarmac idling delays, 
-- applying a mandatory 4-minute engine stabilization warm-up buffer.
-- Fuel metrics assume Jet A-1 standard mass density (1 Gallon = 3.02 kg) 
-- and global IATA baseline fuel planning benchmark pricing ($3.00 USD/Gallon).

WITH flight_leakage_calculations AS (
    SELECT 
        f.reporting_airline AS airline,
        f.taxi_out AS total_taxi_out_minutes,
        e.fuel_flow_idle_kg_sec AS idle_burn_rate_kg_sec,
        
        -- Filter out mandatory pre-flight engine thermal stabilization window
        CASE 
            WHEN f.taxi_out > 4 THEN (f.taxi_out - 4)
            ELSE 0 
        END AS excess_delay_minutes
    FROM fact_flights f
    INNER JOIN dim_aircraft a ON f.tail_number = a.tail_number
    INNER JOIN dim_engine e ON a.engine_identification = e.engine_identification
    WHERE f.cancelled = 0 AND f.taxi_out IS NOT NULL
)
SELECT 
    airline,
    COUNT(*) AS total_monitored_flights,
    ROUND(AVG(total_taxi_out_minutes), 2) AS avg_taxi_out_mins,
    ROUND(SUM(excess_delay_minutes), 0) AS cumulative_delayed_minutes,
    
    -- Delay duration to seconds multiplied by engine mass flow rate (kg/sec)
    ROUND(SUM(excess_delay_minutes * 60 * idle_burn_rate_kg_sec), 0) AS total_wasted_fuel_kg,
    
    -- Mass-to-volume density translation: (Kilograms / 3.02) * $3.00 USD/Gallon Price Parameter
    ROUND(SUM(excess_delay_minutes * 60 * idle_burn_rate_kg_sec) / 3.02 * 3.00, 2) AS total_financial_loss_usd
FROM flight_leakage_calculations
GROUP BY airline
ORDER BY total_financial_loss_usd DESC;


-- ----------------------------------------------------------------------------
-- SPATIAL NETWORK AUDIT: Top Airport Corridors Generating Runway Queue Holds
-- ----------------------------------------------------------------------------
-- Utilizes analytical window functions to rank airport infrastructure nodes 
-- globally by their aggregate tarmac fuel cash burn parameters.

WITH route_leakage AS (
    SELECT 
        f.origin AS departure_airport,
        e.fuel_flow_idle_kg_sec AS engine_idle_coefficient,
        CASE WHEN f.taxi_out > 4 THEN (f.taxi_out - 4) ELSE 0 END AS excess_delay_minutes
    FROM fact_flights f
    INNER JOIN dim_aircraft a ON f.tail_number = a.tail_number
    INNER JOIN dim_engine e ON a.engine_identification = e.engine_identification
    WHERE f.cancelled = 0 AND f.taxi_out IS NOT NULL
)
SELECT 
    departure_airport,
    COUNT(*) AS total_departures,
    ROUND(AVG(excess_delay_minutes + 4), 2) AS avg_tarmac_time_mins,
    ROUND(SUM(excess_delay_minutes), 0) AS total_excess_minutes,
    ROUND(SUM(excess_delay_minutes * 60 * engine_idle_coefficient) / 3.02 * 3.00, 2) AS total_wasted_capital_usd,
    
    -- Window aggregation framework establishing bottleneck impact rankings
    DENSE_RANK() OVER (ORDER BY SUM(excess_delay_minutes * 60 * engine_idle_coefficient) DESC) AS bottleneck_rank
FROM route_leakage
GROUP BY departure_airport
ORDER BY total_wasted_capital_usd DESC
LIMIT 10;


-- ----------------------------------------------------------------------------
-- ROOT CAUSE AGGREGATION: Disaggregating Delay Vectors Across Gridlocked Hubs
-- ----------------------------------------------------------------------------
-- Safely references null values to split delays between carrier internal operational failures, 
-- severe weather limits, and National Airspace System (NAS/ATC) constraints across top nodes.

SELECT 
    origin AS departure_airport,
    COUNT(*) AS total_analyzed_records,
    ROUND(AVG(taxi_out), 2) AS avg_taxi_out_mins,
    ROUND(SUM(COALESCE(carrier_delay, 0)), 0) AS total_carrier_delay_minutes,
    ROUND(SUM(COALESCE(weather_delay, 0)), 0) AS total_weather_delay_minutes,
    ROUND(SUM(COALESCE(nas_delay, 0)), 0) AS total_atc_nas_delay_minutes
FROM fact_flights
WHERE cancelled = 0 AND origin IN ('ORD', 'DFW', 'JFK', 'LAX', 'IAH', 'ATL', 'DEN', 'PHL', 'EWR', 'BOS')
GROUP BY origin
ORDER BY avg_taxi_out_mins DESC;


-- ----------------------------------------------------------------------------
-- QUESTION 03: High-Value Wide-Body Propulsion Penalties Analysis
-- ----------------------------------------------------------------------------
-- Exposes wide-body scale anomalies by analyzing which engine variations incur 
-- the highest financial penalties during runway traffic holds.

WITH engine_leakage_ranking AS (
    SELECT 
        e.manufacturer AS engine_manufacturer,
        e.engine_identification AS engine_model,
        f.taxi_out AS total_taxi_out_minutes,
        CASE WHEN f.taxi_out > 4 THEN (f.taxi_out - 4) ELSE 0 END AS excess_delay_minutes,
        e.fuel_flow_idle_kg_sec AS idle_coefficient
    FROM fact_flights f
    INNER JOIN dim_aircraft a ON f.tail_number = a.tail_number
    INNER JOIN dim_engine e ON a.engine_identification = e.engine_identification
    WHERE f.cancelled = 0 AND f.taxi_out IS NOT NULL
)
SELECT 
    engine_manufacturer,
    engine_model,
    COUNT(*) AS total_flights_equipped,
    ROUND(AVG(total_taxi_out_minutes), 2) AS avg_taxi_time_mins,
    SUM(excess_delay_minutes) AS cumulative_excess_ground_minutes,
    ROUND(SUM(excess_delay_minutes * 60 * idle_coefficient), 0) AS total_wasted_fuel_kg,
    ROUND(SUM(excess_delay_minutes * 60 * idle_coefficient) / 3.02 * 3.00, 2) AS total_fuel_penalty_usd
FROM engine_leakage_ranking
GROUP BY engine_manufacturer, engine_model
ORDER BY total_fuel_penalty_usd DESC
LIMIT 10;


-- ----------------------------------------------------------------------------
-- QUESTION 04: Environmental Emissions Cap-and-Trade Carbon Tax Audit
-- ----------------------------------------------------------------------------
-- Models aircraft carbon weight generation metrics based on official ICAO chemical thresholds 
-- (1 kg fuel burn releases 3.16 kg CO2 gas) and maps liabilities using standard 
-- global Cap-and-Trade carbon tracking pricing ($90.00 USD per Metric Ton / 1,000 kg).

SELECT 
    f.reporting_airline AS airline,
    COUNT(*) AS total_flights_analyzed,
    ROUND(SUM(f.air_time), 0) AS cumulative_air_time_mins,
    
    -- True approach fuel weight generation calculation: minutes * 60 * approach flow coefficient
    ROUND(SUM(f.air_time * 60 * e.fuel_flow_app_kg_sec), 0) AS total_approach_fuel_burned_kg,
    
    -- Applying global chemical combustion constant 
    ROUND(SUM(f.air_time * 60 * e.fuel_flow_app_kg_sec) * 3.16, 0) AS total_co2_emitted_kg,
    
    -- Financial Green Tax Valuation mapping
    ROUND((SUM(f.air_time * 60 * e.fuel_flow_app_kg_sec) * 3.16 / 1000.0) * 90.00, 2) AS environmental_carbon_fine_usd
FROM fact_flights f
INNER JOIN dim_aircraft a ON f.tail_number = a.tail_number
INNER JOIN dim_engine e ON a.engine_identification = e.engine_identification
WHERE f.cancelled = 0 AND f.air_time IS NOT NULL
GROUP BY f.reporting_airline
ORDER BY environmental_carbon_fine_usd DESC;


-- ----------------------------------------------------------------------------
-- QUESTION 05: High-Volume Airway Overrun Optimization & Variance Models
-- ----------------------------------------------------------------------------
-- Builds a dynamic median corridor baseline model to filter out statistical variance noise, 
-- isolating the top 5 flights with severe holding pattern air-time duration delays.

WITH high_volume_routes AS (
    SELECT 
        origin, 
        dest, 
        ROUND(AVG(air_time), 0) AS baseline_route_air_time_mins, 
        COUNT(*) AS flight_count
    FROM fact_flights 
    WHERE cancelled = 0 AND air_time IS NOT NULL
    GROUP BY origin, dest 
    HAVING flight_count >= 5
),
flight_airborne_variance AS (
    SELECT 
        f.reporting_airline AS airline, 
        f.flight_date, 
        f.origin AS departure_airport, 
        f.dest AS arrival_airport, 
        f.tail_number,
        f.air_time AS actual_airborne_minutes, 
        b.baseline_route_air_time_mins,
        (f.air_time - b.baseline_route_air_time_mins) AS air_time_overrun_minutes, 
        e.fuel_flow_app_kg_sec AS approach_burn_rate
    FROM fact_flights f
    INNER JOIN high_volume_routes b ON f.origin = b.origin AND f.dest = b.dest
    INNER JOIN dim_aircraft a ON f.tail_number = a.tail_number
    INNER JOIN dim_engine e ON a.engine_identification = e.engine_identification
    WHERE f.cancelled = 0 AND f.air_time > b.baseline_route_air_time_mins
)
SELECT 
    airline, 
    flight_date, 
    CONCAT(departure_airport, ' -> ', arrival_airport) AS flight_corridor, 
    tail_number,
    actual_airborne_minutes,
    baseline_route_air_time_mins,
    air_time_overrun_minutes AS airborne_delay_duration_mins,
    ROUND((air_time_overrun_minutes * 60 * approach_burn_rate) / 3.02 * 3.00, 2) AS airborne_fuel_burn_loss_usd
FROM flight_airborne_variance
ORDER BY airborne_fuel_burn_loss_usd DESC
LIMIT 5;
