-- =============================================================
-- BTS Flight Delay Analysis
-- Script: create_tables.hql
-- Purpose: Create all Hive tables for flight delay analysis
-- Run via Beeline:
--   beeline -u jdbc:hive2://localhost:10000 -n maria_dev -p maria_dev
-- Then paste each block one at a time
-- =============================================================

-- Step 1: Create and select database
CREATE DATABASE IF NOT EXISTS flight_analysis
COMMENT 'BTS On-Time Performance Analysis Database';

USE flight_analysis;

-- =============================================================
-- TABLE 1: flights_cleaned
-- External table pointing to Python-cleaned pipe-separated data
-- 34 columns, 644,987 rows, December 2025
-- =============================================================
DROP TABLE IF EXISTS flights_cleaned;

CREATE EXTERNAL TABLE flights_cleaned (
    Year              INT,
    Quarter           INT,
    Month             INT,
    DayofMonth        INT,
    DayOfWeek         INT,
    FlightDate        STRING,
    Marketing_Airline STRING,
    Operating_Airline STRING,
    OriginAirportID   INT,
    Origin            STRING,
    OriginCityName    STRING,
    OriginState       STRING,
    DestAirportID     INT,
    Dest              STRING,
    DestCityName      STRING,
    DestState         STRING,
    CRSDepTime        STRING,
    DepDelay          FLOAT,
    ArrDelay          FLOAT,
    DepDel15          FLOAT,
    ArrDel15          FLOAT,
    Cancelled         FLOAT,
    CancellationCode  STRING,
    Diverted          FLOAT,
    CarrierDelay      FLOAT,
    WeatherDelay      FLOAT,
    NASDelay          FLOAT,
    SecurityDelay     FLOAT,
    LateAircraftDelay FLOAT,
    Distance          FLOAT,
    DistanceGroup     INT,
    TaxiOut           FLOAT,
    TaxiIn            FLOAT,
    AirTime           FLOAT
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '|'
STORED AS TEXTFILE
LOCATION '/user/maria_dev/flight_data/cleaned/'
TBLPROPERTIES ('serialization.null.format'='');

-- =============================================================
-- TABLE 2: airports
-- Lookup table: AirportID to Airport Name
-- Source: L_AIRPORT_ID.csv (comma-separated, has header)
-- =============================================================
DROP TABLE IF EXISTS airports;

CREATE TABLE airports (
    AirportID   INT,
    AirportName STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');

LOAD DATA INPATH '/user/maria_dev/flight_data/lookup/L_AIRPORT_ID.csv'
OVERWRITE INTO TABLE airports;

-- =============================================================
-- TABLE 3: cancellation_codes
-- Lookup table: A/B/C/D to cancellation reason
-- Source: L_CANCELLATION.csv (comma-separated, quoted, has header)
-- NOTE: Uses OpenCSVSerde to strip double quotes from values
-- =============================================================
DROP TABLE IF EXISTS cancellation_codes;

CREATE TABLE cancellation_codes (
    Code        STRING,
    Description STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    "separatorChar" = ",",
    "quoteChar"     = "\""
)
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');

LOAD DATA INPATH '/user/maria_dev/flight_data/lookup/L_CANCELLATION.csv'
OVERWRITE INTO TABLE cancellation_codes;

-- =============================================================
-- TABLE 4: carriers
-- Lookup table: carrier code to airline name
-- Source: L_UNIQUE_CARRIERS.csv (comma-separated, has header)
-- =============================================================
DROP TABLE IF EXISTS carriers;

CREATE TABLE carriers (
    Code        STRING,
    CarrierName STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');

LOAD DATA INPATH '/user/maria_dev/flight_data/lookup/L_UNIQUE_CARRIERS.csv'
OVERWRITE INTO TABLE carriers;

-- =============================================================
-- VERIFY: Check row counts for all tables
-- =============================================================
SELECT 'flights_cleaned'  AS table_name, COUNT(*) AS row_count FROM flights_cleaned
UNION ALL
SELECT 'airports',                        COUNT(*) FROM airports
UNION ALL
SELECT 'cancellation_codes',              COUNT(*) FROM cancellation_codes
UNION ALL
SELECT 'carriers',                        COUNT(*) FROM carriers;
