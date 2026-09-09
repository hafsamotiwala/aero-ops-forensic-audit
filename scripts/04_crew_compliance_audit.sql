-- ============================================================================
-- FILE: /scripts/04_crew_compliance_audit.sql
-- DESCRIPTION: Domain D Analytics - Deadhead Overhead Ratios, Fatigue Analysis & Compliance Lags
-- ARCHITECTURE LAYER: Crew Resource Management (CRM) & Legal Regulatory Audits
-- ============================================================================

USE aero_ops_audit;

-- ----------------------------------------------------------------------------
-- SYNTHESIS LAYER: DDL and Data Generation Core Scripts
-- ----------------------------------------------------------------------------
-- Generates historical crew tracking pairings by mapping real transactional
-- flight legs directly into strict legal Flight Duty Period (FDP) thresholds.

DROP TABLE IF EXISTS fact_crew_duty;

CREATE TABLE fact_crew_duty (
    flight_date DATE,
    reporting_airline VARCHAR(10),
    tail_number VARCHAR(20),
    origin VARCHAR(10),
    dest VARCHAR(10),
    crew_pairing_id VARCHAR(50),
    duty_start_timestamp DATETIME,
    duty_accumulated_hours DECIMAL(10, 2),
    crew_timeout_flag INT,
    hotel_voucher_cost_usd DECIMAL(10, 2),
    standby_callout_cost_usd DECIMAL(10, 2),
    is_deadhead INT
);

INSERT INTO fact_crew_duty
SELECT 
    flight_date, 
    reporting_airline, 
    tail_number, 
    origin, 
    dest,
    CONCAT('PAIR-', reporting_airline, '-', FLOOR(1000 + (RAND(3) * 9000))) AS crew_pairing_id,
    
    -- Mandates duty start exactly 60 minutes prior to pushback (Briefing Window)
    DATE_SUB(CAST(CONCAT(flight_date, ' 06:00:00') AS DATETIME), INTERVAL 1 HOUR) AS duty_start_timestamp,
    
    -- Computes accumulated duty day hours: (AirTime + TaxiOut + TaxiIn + 60min Briefing) / 60
    ROUND((COALESCE(air_time, 0) + COALESCE(taxi_out, 0) + COALESCE(taxi_in, 0) + 60) / 60.0, 2) AS duty_accumulated_hours,
    
    -- Enforces regulatory timeout flag if the absolute duty clock limits break past 13.5 hours
    CASE WHEN (COALESCE(air_time, 0) + COALESCE(taxi_out, 0) + COALESCE(taxi_in, 0) + 60) / 60.0 > 13.5 THEN 1 ELSE 0 END AS crew_timeout_flag,
    
    -- Maps operational overhead penalties triggered when a crew times out away from home base
    CASE WHEN (COALESCE(air_time, 0) + COALESCE(taxi_out, 0) + COALESCE(taxi_in, 0) + 60) / 60.0 > 13.5 THEN 850.00 ELSE 0.00 END AS hotel_voucher_cost_usd,
    CASE WHEN (COALESCE(air_time, 0) + COALESCE(taxi_out, 0) + COALESCE(taxi_in, 0) + 60) / 60.0 > 13.5 THEN 1200.00 ELSE 0.00 END AS standby_callout_cost_usd,
    
    -- Establishes a standard 4% network probability tracking deadhead staff allocations
    CASE WHEN RAND(4) < 0.04 THEN 1 ELSE 0 END AS is_deadhead
FROM fact_flights 
WHERE cancelled = 0 AND air_time IS NOT NULL;


-- ----------------------------------------------------------------------------
-- QUESTION 16 & 17: Outstation Legal Timeouts Incident Monitoring
-- ----------------------------------------------------------------------------
-- Identifies cascading cancellations or delays caused by crew pairings hitting 
-- terminal Flight Duty Period limits, aggregating direct financial line penalties.

SELECT 
    reporting_airline AS airline, 
    COUNT(*) AS total_monitored_flights, 
    SUM(crew_timeout_flag) AS total_crew_timeout_events,
    ROUND(SUM(hotel_voucher_cost_usd + standby_callout_cost_usd), 2) AS total_crew_leakage_penalty_usd,
    MAX(duty_accumulated_hours) AS maximum_logged_duty_hours
FROM fact_crew_duty
GROUP BY reporting_airline
ORDER BY total_crew_timeout_events DESC;


-- ----------------------------------------------------------------------------
-- QUESTION 18: Non-Revenue Positioning Deadhead Seat Revenue Opportunity Losses
-- ----------------------------------------------------------------------------
-- Quantifies the exact opportunity cost of deadhead penetration rates, assuming 
-- a standardized baseline foregone short-haul passenger ticket value of $120.00.

SELECT 
    reporting_airline AS airline, 
    COUNT(*) AS total_crew_legs_tracked,
    SUM(CASE WHEN is_deadhead = 1 THEN 1 ELSE 0 END) AS total_deadhead_passengers,
    SUM(CASE WHEN is_deadhead = 0 THEN 1 ELSE 0 END) AS total_active_operating_crew,
    ROUND((SUM(CASE WHEN is_deadhead = 1 THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS deadhead_penetration_rate,
    ROUND(SUM(CASE WHEN is_deadhead = 1 THEN 1 ELSE 0 END) * 120.00, 2) AS foregone_passenger_revenue_usd
FROM fact_crew_duty
GROUP BY reporting_airline
ORDER BY foregone_passenger_revenue_usd DESC;


-- ----------------------------------------------------------------------------
-- QUESTION 19: High-Stress Roster Fatigue Loop Analysis
-- ----------------------------------------------------------------------------
-- Pinpoints airport route combinations that push flight logs closest to 
-- fatigue threshold barriers, highlighting critical bottlenecks in structural scheduling templates.

SELECT 
    reporting_airline AS airline, 
    CONCAT(origin, ' -> ', dest) AS flight_corridor,
    COUNT(*) AS total_scheduled_loops,
    ROUND(AVG(duty_accumulated_hours), 2) AS avg_crew_duty_day_hours,
    ROUND(MAX(duty_accumulated_hours), 2) AS max_single_duty_day_hours,
    SUM(CASE WHEN duty_accumulated_hours > 3.5 THEN 1 ELSE 0 END) AS high_fatigue_risk_count
FROM fact_crew_duty
GROUP BY reporting_airline, origin, dest
ORDER BY avg_crew_duty_day_hours DESC
LIMIT 10;


-- ----------------------------------------------------------------------------
-- QUESTION 20: Telemetry Corruptions and Safety Compliance Sync Lags
-- ----------------------------------------------------------------------------
-- Audits synchronization disconnects where aircraft sensors record active tarmac
-- movement while the core air_time engine field returns zero or null values. 
-- Maps fine exposures using civil aviation audit penalty expectations ($5,000/record).

WITH crew_sync_audit AS (
    SELECT 
        reporting_airline AS airline, 
        air_time,
        CASE 
            WHEN (air_time = 0 OR air_time IS NULL) AND (taxi_out > 0 OR taxi_in > 0) THEN 1 
            ELSE 0 
        END AS telemetry_sync_lag_flag
    FROM fact_flights 
    WHERE cancelled = 0
)
SELECT 
    airline, 
    COUNT(*) AS total_monitored_flight_legs, 
    SUM(telemetry_sync_lag_flag) AS recorded_compliance_sync_lags,
    ROUND((SUM(telemetry_sync_lag_flag) / COUNT(*)) * 100, 4) AS data_sync_error_rate_percentage,
    ROUND(SUM(telemetry_sync_lag_flag) * 5000.00, 2) AS projected_regulatory_fine_risk_usd
FROM crew_sync_audit
GROUP BY airline
ORDER BY projected_regulatory_fine_risk_usd DESC;
