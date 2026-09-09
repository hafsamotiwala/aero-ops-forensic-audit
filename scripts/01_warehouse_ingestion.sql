-- ============================================================================
-- FILE: /scripts/01_warehouse_ingestion.sql
-- DESCRIPTION: Database initialization, Star-Schema DDL, and Bulk Ingestion
-- ARCHITECTURE LAYER: Data Definition (DDL) & Data Ingestion Pipeline
-- ============================================================================

CREATE DATABASE IF NOT EXISTS aero_ops_audit;
USE aero_ops_audit;

-- ----------------------------------------------------------------------------
-- 1. INFRASTRUCTURE CLEANUP & DEPENDENCY DROPS
-- ----------------------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS fact_flights;
DROP TABLE IF EXISTS dim_aircraft;
DROP TABLE IF EXISTS dim_engine;
SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------------------------
-- 2. STAR-SCHEMA DATA DEFINITION LAYER (DDL)
-- ----------------------------------------------------------------------------

-- Dimension Table A: Engine Technical Specifications (Sourced from ICAO Databank)
CREATE TABLE dim_engine (
    manufacturer VARCHAR(100),
    engine_identification VARCHAR(100) PRIMARY KEY,
    fuel_flow_idle_kg_sec DECIMAL(10, 4),    -- Fuel flow rate during ground idling
    fuel_flow_app_kg_sec DECIMAL(10, 4),     -- Fuel flow rate during airborne approach
    nvpm_lto_total_mass_mg DECIMAL(20, 4)    -- Solid soot emission mass for carbon penalties
);

-- Dimension Table B: Aircraft Fleet Crosswalk Register (Fleet Register Dimension)
CREATE TABLE dim_aircraft (
    tail_number VARCHAR(20) PRIMARY KEY,
    engine_identification VARCHAR(100),
    FOREIGN KEY (engine_identification) REFERENCES dim_engine(engine_identification)
);

-- Core Transactional Fact Table: Flight Telemetry Core Logs (Sourced from US BTS)
CREATE TABLE fact_flights (
    flight_date DATE,
    reporting_airline VARCHAR(10),
    tail_number VARCHAR(20),
    origin VARCHAR(10),
    dest VARCHAR(10),
    taxi_out INT,                            -- Out-Gate to Runway Takeoff Latency (Minutes)
    taxi_in INT,                             -- Runway Landing to In-Gate Latency (Minutes)
    air_time INT,                            -- Actual Airborne Block Time (Minutes)
    cancelled INT,                           -- Operational Cancellation Binary Flag
    carrier_delay INT,                       -- Disaggregated Airline Internal Delay (Minutes)
    weather_delay INT,                       -- Meteorological Disruption Vector (Minutes)
    nas_delay INT                            -- National Airspace System/ATC Traffic Vector (Minutes)
);

-- ----------------------------------------------------------------------------
-- 3. ENVIRONMENT VERIFICATION
-- ----------------------------------------------------------------------------
-- Executed to isolate the local directory path mandated for secure file loads
-- SHOW VARIABLES LIKE 'secure_file_priv';

-- ----------------------------------------------------------------------------
-- 4. BULK DATA INGESTION ENGINE (LOAD DATA INFILE AUTOMATION)
-- ----------------------------------------------------------------------------

-- Ingestion Engine String 01: Parsing Engine Dimensional Specifications
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/clean_icao_engines.csv'
IGNORE INTO TABLE dim_engine
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES 
(manufacturer, engine_identification, fuel_flow_idle_kg_sec, fuel_flow_app_kg_sec, @v_nvpm_mass)
SET nvpm_lto_total_mass_mg = NULLIF(TRIM(@v_nvpm_mass), '');

-- Ingestion Engine String 02: Synchronizing Fleet Register Crosswalk Records
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/clean_fleet_register.csv'
IGNORE INTO TABLE dim_aircraft
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES 
(tail_number, engine_identification);

-- Ingestion Engine String 03: Bulk Parsing 513,455 Core Flight Transactions
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/clean_bts_flights.csv'
INTO TABLE fact_flights
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES 
(flight_date, reporting_airline, tail_number, origin, dest, @v_taxi_out, @v_taxi_in, @v_air_time, @v_cancelled, @v_carrier, @v_weather, @v_nas)
SET 
    -- Technical Data Cleaning Overrides: Forces empty strings to safe numeric NULL constants
    cancelled = COALESCE(NULLIF(TRIM(@v_cancelled), ''), 0),
    taxi_out = NULLIF(TRIM(@v_taxi_out), ''),
    taxi_in = NULLIF(TRIM(@v_taxi_in), ''),
    air_time = NULLIF(TRIM(@v_air_time), ''),
    carrier_delay = NULLIF(TRIM(@v_carrier), ''),
    weather_delay = NULLIF(TRIM(@v_weather), ''),
    nas_delay = NULLIF(TRIM(@v_nas), '');

-- ----------------------------------------------------------------------------
-- 5. WAREHOUSE RELIABILITY VALIDATION VERIFICATION
-- ----------------------------------------------------------------------------
SELECT 'dim_engine' AS Table_Name, COUNT(*) AS Target_Row_Count FROM dim_engine
UNION ALL
SELECT 'dim_aircraft', COUNT(*) FROM dim_aircraft
UNION ALL
SELECT 'fact_flights', COUNT(*) FROM fact_flights;
