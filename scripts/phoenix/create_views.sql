-- =============================================================
-- BTS Flight Delay Analysis
-- Script: create_views.sql
-- Purpose: Create Phoenix SQL views on HBase tables
--          and run analytical queries
-- Run via:
--   /usr/hdp/current/phoenix-client/bin/sqlline.py
--   localhost:2181:/hbase-unsecure
-- =============================================================
-- WHY PHOENIX?
-- HBase get/scan commands return data but do not support
-- SQL operations like ORDER BY, GROUP BY, or AVG.
-- Phoenix provides a SQL layer that translates standard SQL
-- into HBase operations running in under 2 seconds.
-- This is 20-90x faster than equivalent Hive queries.
-- =============================================================

-- =============================================================
-- STEP 1: Create Phoenix Views on HBase Tables
-- Views map HBase column families to SQL columns
-- Column family names must be in double quotes
-- =============================================================

-- View 1: airport_delays
CREATE VIEW "airport_delays" (
    pk                       VARCHAR PRIMARY KEY,
    "info"."city"            VARCHAR,
    "info"."state"           VARCHAR,
    "stats"."avg_dep_delay"  VARCHAR,
    "stats"."delay_rate_pct" VARCHAR,
    "stats"."total_flights"  VARCHAR
);

-- View 2: carrier_performance
CREATE VIEW "carrier_performance" (
    pk                        VARCHAR PRIMARY KEY,
    "info"."name"             VARCHAR,
    "stats"."avg_arr_delay"   VARCHAR,
    "stats"."avg_dep_delay"   VARCHAR,
    "stats"."delay_rate_pct"  VARCHAR,
    "stats"."total_flights"   VARCHAR,
    "stats"."cancellations"   VARCHAR,
    "stats"."rank"            VARCHAR
);

-- View 3: flight_predictions
CREATE VIEW "flight_predictions" (
    pk                         VARCHAR PRIMARY KEY,
    "route"."origin"           VARCHAR,
    "route"."dest"             VARCHAR,
    "route"."carrier"          VARCHAR,
    "route"."date"             VARCHAR,
    "prediction"."delay_prob"  VARCHAR,
    "prediction"."label"       VARCHAR,
    "actual"."arr_delay"       VARCHAR,
    "actual"."arr_del15"       VARCHAR
);

-- =============================================================
-- STEP 2: Analytical Queries via Phoenix SQL
-- =============================================================

-- Query 1: All airports ranked by delay rate
-- Result time: 1.051 seconds vs 45 seconds in Hive
SELECT
    pk                AS airport_code,
    "city",
    "avg_dep_delay",
    "delay_rate_pct",
    "total_flights"
FROM "airport_delays"
ORDER BY "delay_rate_pct" DESC;

-- Query 2: Airlines ranked by performance
-- Result time: 0.845 seconds vs 45 seconds in Hive
SELECT
    pk                AS carrier_code,
    "name"            AS airline_name,
    "avg_arr_delay",
    "delay_rate_pct",
    "rank"
FROM "carrier_performance"
ORDER BY "rank";

-- Query 3: Single airport real-time lookup
-- Key use case: instant response for dashboards
-- Result time: 0.502 seconds
SELECT
    pk                AS airport,
    "city",
    "avg_dep_delay",
    "delay_rate_pct"
FROM "airport_delays"
WHERE pk = 'JFK';

-- Query 4: Find high-risk flights (predicted delayed)
-- Result time: 0.760 seconds
SELECT
    pk                AS flight_id,
    "origin",
    "dest",
    "carrier",
    "delay_prob",
    "label"
FROM "flight_predictions"
WHERE "label" = '1';

-- Query 5: Compare ML predictions vs actual outcomes
-- Validates model accuracy on sample flights
-- Result time: 1.689 seconds
SELECT
    pk                AS flight_id,
    "carrier",
    "origin",
    "dest",
    "delay_prob"      AS predicted_probability,
    "label"           AS predicted_delayed,
    "arr_delay"       AS actual_delay,
    "arr_del15"       AS actually_delayed
FROM "flight_predictions"
ORDER BY "delay_prob" DESC;

-- =============================================================
-- STEP 3: Exit Phoenix Shell
-- =============================================================
-- !quit
