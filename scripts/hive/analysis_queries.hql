markdown# File 3 of 18 — analysis_queries.hql

## Steps

1. Go to your repository on GitHub
2. Click **Add file → Create new file**
3. In the filename box type exactly:
```
scripts/hive/analysis_queries.hql
```
4. In the editor paste this content:

```sql
-- =============================================================
-- BTS Flight Delay Analysis
-- Script: analysis_queries.hql
-- Purpose: 7 analytical queries on cleaned flight data
-- Run via Beeline after create_tables.hql
-- Results from December 2025 BTS data (644,987 flights)
-- =============================================================

USE flight_analysis;

-- =============================================================
-- QUERY 1: Overall Dataset Summary
-- Result: 644,987 records, 26.4% delay rate, avg 13.20 min
-- =============================================================
SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN Cancelled=1 THEN 1 ELSE 0 END)  AS total_cancellations,
    SUM(CASE WHEN Diverted=1 THEN 1 ELSE 0 END)   AS total_diversions,
    SUM(CASE WHEN ArrDel15=1 THEN 1 ELSE 0 END)   AS total_delayed_15min,
    ROUND(AVG(NVL(ArrDelay,0)),2)                  AS avg_arrival_delay_min,
    ROUND(AVG(NVL(DepDelay,0)),2)                  AS avg_departure_delay_min,
    COUNT(DISTINCT Marketing_Airline)              AS unique_carriers,
    COUNT(DISTINCT Origin)                         AS unique_origin_airports
FROM flights_cleaned
WHERE Year IS NOT NULL;

-- =============================================================
-- QUERY 2: Top 10 Airports by Average Departure Delay
-- Excludes cancelled flights and airports with less than 100 flights
-- =============================================================
SELECT
    Origin,
    OriginCityName,
    COUNT(*) AS total_flights,
    ROUND(AVG(CASE WHEN DepDelay > 0 THEN DepDelay END), 2)
        AS avg_dep_delay_when_late,
    SUM(CASE WHEN DepDel15=1 THEN 1 ELSE 0 END) AS flights_delayed,
    ROUND(SUM(CASE WHEN DepDel15=1 THEN 1 ELSE 0 END)*100.0/COUNT(*), 2)
        AS pct_delayed
FROM flights_cleaned
WHERE Cancelled = 0
GROUP BY Origin, OriginCityName
HAVING COUNT(*) >= 100
ORDER BY avg_dep_delay_when_late DESC
LIMIT 10;

-- =============================================================
-- QUERY 3: Delay Breakdown by Cause (Minutes)
-- Only for flights delayed 15 or more minutes
-- NVL() used to replace NULL with 0 for accurate totals
-- =============================================================
SELECT
    ROUND(SUM(NVL(CarrierDelay,0)),0)      AS carrier_delay_min,
    ROUND(SUM(NVL(WeatherDelay,0)),0)      AS weather_delay_min,
    ROUND(SUM(NVL(NASDelay,0)),0)          AS nas_delay_min,
    ROUND(SUM(NVL(SecurityDelay,0)),0)     AS security_delay_min,
    ROUND(SUM(NVL(LateAircraftDelay,0)),0) AS late_aircraft_delay_min
FROM flights_cleaned
WHERE ArrDel15 = 1;

-- =============================================================
-- QUERY 4: Cancellation Reasons Distribution
-- JOIN with cancellation_codes for human-readable descriptions
-- Result: Weather 56%, Carrier 31%, NAS 13%, Security 0.02%
-- =============================================================
SELECT
    f.CancellationCode,
    c.Description,
    COUNT(*) AS cancellation_count,
    ROUND(COUNT(*)*100.0/SUM(COUNT(*)) OVER(), 2) AS percentage
FROM flights_cleaned f
JOIN cancellation_codes c
    ON f.CancellationCode = c.Code
WHERE f.Cancelled = 1.0
    AND f.CancellationCode NOT IN ('NONE', '')
GROUP BY f.CancellationCode, c.Description
ORDER BY cancellation_count DESC;

-- =============================================================
-- QUERY 5: Average Delay by Day of Week
-- Result: Wednesday best (5.68 min), Sunday worst (28.15 min)
-- NOTE: ORDER BY 1 used due to Hive 1.2 limitation with CASE WHEN
-- =============================================================
SELECT
    CASE DayOfWeek
        WHEN 1 THEN '1-Monday'
        WHEN 2 THEN '2-Tuesday'
        WHEN 3 THEN '3-Wednesday'
        WHEN 4 THEN '4-Thursday'
        WHEN 5 THEN '5-Friday'
        WHEN 6 THEN '6-Saturday'
        WHEN 7 THEN '7-Sunday'
        ELSE 'Unknown'
    END AS day_of_week,
    COUNT(*) AS total_flights,
    ROUND(AVG(NVL(ArrDelay,0)),2) AS avg_arr_delay,
    ROUND(AVG(NVL(DepDelay,0)),2) AS avg_dep_delay,
    ROUND(SUM(CASE WHEN ArrDel15=1 THEN 1 ELSE 0 END)*100.0/COUNT(*),2)
        AS delay_rate_pct
FROM flights_cleaned
WHERE DayOfWeek BETWEEN 1 AND 7
    AND Cancelled = 0
GROUP BY DayOfWeek
ORDER BY 1;

-- =============================================================
-- QUERY 6: Carrier Performance Comparison
-- LEFT JOIN with carriers table for airline names
-- Result: Southwest best (7.72 min), JetBlue worst (21.27 min)
-- =============================================================
SELECT
    f.Marketing_Airline AS code,
    c.CarrierName       AS airline_name,
    COUNT(*)            AS total_flights,
    ROUND(AVG(NVL(f.ArrDelay,0)),2) AS avg_arr_delay,
    ROUND(AVG(NVL(f.DepDelay,0)),2) AS avg_dep_delay,
    ROUND(SUM(CASE WHEN f.ArrDel15=1 THEN 1 ELSE 0 END)*100.0/COUNT(*),2)
        AS delay_rate_pct,
    SUM(CASE WHEN f.Cancelled=1 THEN 1 ELSE 0 END) AS cancellations
FROM flights_cleaned f
LEFT JOIN carriers c
    ON TRIM(f.Marketing_Airline) = TRIM(c.Code)
GROUP BY f.Marketing_Airline, c.CarrierName
HAVING COUNT(*) >= 500
ORDER BY avg_arr_delay ASC;

-- =============================================================
-- QUERY 7: Average Delay by Hour of Day
-- Result: 5AM best (2.09 min, 12.47%), 7PM worst (21.01 min, 35.08%)
-- =============================================================
SELECT
    FLOOR(CAST(CRSDepTime AS INT)/100) AS dep_hour,
    COUNT(*) AS total_flights,
    ROUND(AVG(NVL(ArrDelay,0)),2) AS avg_arr_delay,
    ROUND(SUM(CASE WHEN ArrDel15=1 THEN 1 ELSE 0 END)*100.0/COUNT(*),2)
        AS delay_rate_pct
FROM flights_cleaned
WHERE CRSDepTime IS NOT NULL
    AND Cancelled = 0
GROUP BY FLOOR(CAST(CRSDepTime AS INT)/100)
ORDER BY dep_hour;
