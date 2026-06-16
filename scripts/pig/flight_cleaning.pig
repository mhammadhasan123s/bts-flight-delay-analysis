You are right! We should add the Pig script even though we ended up using Python for cleaning. It is important for your assignment because:

The rubric mentions Pig as a required tool
It shows you tried Pig first and explains why you switched to Python
It demonstrates understanding of both tools

markdown# File 16 of 18 — Add Pig Script

## Steps

1. Go to your repository on GitHub
2. Click **Add file → Create new file**
3. In the filename box type exactly:
```
scripts/pig/flight_cleaning.pig
```
4. In the editor paste this content:

```pig
-- =============================================================
-- BTS Flight Delay Analysis
-- Script: flight_cleaning.pig
-- Purpose: ETL cleaning of raw BTS flight data using Apache Pig
-- Pig Version: 0.16 (HDP Sandbox)
-- =============================================================
-- NOTE ON PIG vs PYTHON:
-- This Pig script was developed and tested during the project.
-- However due to the BTS CSV using RFC 4180 quoted fields
-- (e.g. "San Francisco, CA") which Pig 0.16 cannot handle
-- correctly even with CSVExcelStorage, the final cleaning
-- pipeline used Python (scripts/python/clean_flights.py).
--
-- This script is kept for academic purposes to demonstrate:
-- 1. Pig Latin syntax and dataflow model
-- 2. CASE WHEN ELSE for NULL handling (Pig 0.16 compatible)
-- 3. LEFT OUTER JOIN with lookup tables
-- 4. Why Python was chosen over Pig for this specific dataset
-- =============================================================
-- FIXES APPLIED DURING DEVELOPMENT:
-- 1. Replaced ?: ternary operator with CASE WHEN ELSE
--    (Pig 0.16 does not support ternary operator)
-- 2. Replaced OTHERWISE with ELSE
--    (Pig 0.16 uses ELSE not OTHERWISE)
-- 3. Changed PigStorage('\t') to PigStorage(',')
--    (BTS CSV is comma not tab separated)
-- 4. Final switch to Python due to quoted CSV limitation
-- =============================================================

-- =============================================================
-- STEP 1: Load raw flight data
-- NOTE: BTS CSV has quoted fields -- use CSVExcelStorage
-- =============================================================
REGISTER /usr/hdp/2.6.5.0-292/pig/piggybank.jar;

raw_flights_with_header = LOAD '/user/maria_dev/flight_data/raw/'
    USING org.apache.pig.piggybank.storage.CSVExcelStorage(
        ',', 'NO_MULTILINE', 'UNIX', 'SKIP_INPUT_HEADER')
    AS (
        Year:chararray, Quarter:chararray, Month:chararray,
        DayofMonth:chararray, DayOfWeek:chararray,
        FlightDate:chararray,
        Marketing_Airline_Network:chararray,
        Operated_or_Branded_Code_Share_Partners:chararray,
        DOT_ID_Marketing_Airline:chararray,
        IATA_Code_Marketing_Airline:chararray,
        Flight_Number_Marketing_Airline:chararray,
        Originally_Scheduled_Code_Share_Airline:chararray,
        DOT_ID_Originally_Scheduled_Code_Share_Airline:chararray,
        IATA_Code_Originally_Scheduled_Code_Share_Airline:chararray,
        Flight_Num_Originally_Scheduled_Code_Share_Airline:chararray,
        Operating_Airline:chararray,
        DOT_ID_Operating_Airline:chararray,
        IATA_Code_Operating_Airline:chararray,
        Tail_Number:chararray,
        Flight_Number_Operating_Airline:chararray,
        OriginAirportID:chararray, OriginAirportSeqID:chararray,
        OriginCityMarketID:chararray,
        Origin:chararray, OriginCityName:chararray,
        OriginState:chararray, OriginStateFips:chararray,
        OriginStateName:chararray, OriginWac:chararray,
        DestAirportID:chararray, DestAirportSeqID:chararray,
        DestCityMarketID:chararray,
        Dest:chararray, DestCityName:chararray,
        DestState:chararray, DestStateFips:chararray,
        DestStateName:chararray, DestWac:chararray,
        CRSDepTime:chararray, DepTime:chararray,
        DepDelay:chararray, DepDelayMinutes:chararray,
        DepDel15:chararray, DepartureDelayGroups:chararray,
        DepTimeBlk:chararray,
        TaxiOut:chararray, WheelsOff:chararray,
        WheelsOn:chararray, TaxiIn:chararray,
        CRSArrTime:chararray, ArrTime:chararray,
        ArrDelay:chararray, ArrDelayMinutes:chararray,
        ArrDel15:chararray, ArrivalDelayGroups:chararray,
        ArrTimeBlk:chararray,
        Cancelled:chararray, CancellationCode:chararray,
        Diverted:chararray,
        CRSElapsedTime:chararray, ActualElapsedTime:chararray,
        AirTime:chararray, Flights:chararray,
        Distance:chararray, DistanceGroup:chararray,
        CarrierDelay:chararray, WeatherDelay:chararray,
        NASDelay:chararray, SecurityDelay:chararray,
        LateAircraftDelay:chararray,
        FirstDepTime:chararray, TotalAddGTime:chararray,
        LongestAddGTime:chararray,
        DivAirportLandings:chararray,
        DivReachedDest:chararray, DivActualElapsedTime:chararray,
        DivArrDelay:chararray, DivDistance:chararray,
        Div1Airport:chararray, Div1AirportID:chararray,
        Div1AirportSeqID:chararray, Div1WheelsOn:chararray,
        Div1TotalGTime:chararray, Div1LongestGTime:chararray,
        Div1WheelsOff:chararray, Div1TailNum:chararray,
        Div2Airport:chararray, Div2AirportID:chararray,
        Div2AirportSeqID:chararray, Div2WheelsOn:chararray,
        Div2TotalGTime:chararray, Div2LongestGTime:chararray,
        Div2WheelsOff:chararray, Div2TailNum:chararray,
        Div3Airport:chararray, Div3AirportID:chararray,
        Div3AirportSeqID:chararray, Div3WheelsOn:chararray,
        Div3TotalGTime:chararray, Div3LongestGTime:chararray,
        Div3WheelsOff:chararray, Div3TailNum:chararray,
        Div4Airport:chararray, Div4AirportID:chararray,
        Div4AirportSeqID:chararray, Div4WheelsOn:chararray,
        Div4TotalGTime:chararray, Div4LongestGTime:chararray,
        Div4WheelsOff:chararray, Div4TailNum:chararray,
        Div5Airport:chararray, Div5AirportID:chararray,
        Div5AirportSeqID:chararray, Div5WheelsOn:chararray,
        Div5TotalGTime:chararray, Div5LongestGTime:chararray,
        Div5WheelsOff:chararray, Div5TailNum:chararray,
        Duplicate:chararray
    );

-- =============================================================
-- STEP 2: Remove duplicates and invalid records
-- SKIP_INPUT_HEADER already removed header row
-- but we keep Year != 'Year' as safety filter
-- =============================================================
valid_flights = FILTER raw_flights_with_header BY
    Year IS NOT NULL
    AND Year != ''
    AND Year != 'Year'
    AND (Duplicate IS NULL OR Duplicate != 'Y');

-- =============================================================
-- STEP 3: Clean and cast all fields
-- KEY FIX: Use CASE WHEN ELSE not ternary ?: operator
-- KEY FIX: Use ELSE not OTHERWISE (Pig 0.16 syntax)
-- =============================================================
cleaned_flights = FOREACH valid_flights GENERATE
    (int)(Year)                         AS Year,
    (int)(Quarter)                      AS Quarter,
    (int)(Month)                        AS Month,
    (int)(DayofMonth)                   AS DayofMonth,
    (int)(DayOfWeek)                    AS DayOfWeek,
    FlightDate                          AS FlightDate,
    TRIM(Marketing_Airline_Network)     AS Marketing_Airline_Network,
    TRIM(Operating_Airline)             AS Operating_Airline,
    (int)(OriginAirportID)              AS OriginAirportID,
    TRIM(Origin)                        AS Origin,
    TRIM(OriginCityName)                AS OriginCityName,
    TRIM(OriginState)                   AS OriginState,
    (int)(DestAirportID)                AS DestAirportID,
    TRIM(Dest)                          AS Dest,
    TRIM(DestCityName)                  AS DestCityName,
    TRIM(DestState)                     AS DestState,
    (int)(CRSDepTime)                   AS CRSDepTime,
    (float)(CASE
        WHEN DepDelay IS NULL THEN '0'
        WHEN DepDelay == ''   THEN '0'
        WHEN DepDelay == 'NA' THEN '0'
        ELSE DepDelay END)              AS DepDelay,
    (float)(CASE
        WHEN ArrDelay IS NULL THEN '0'
        WHEN ArrDelay == ''   THEN '0'
        WHEN ArrDelay == 'NA' THEN '0'
        ELSE ArrDelay END)              AS ArrDelay,
    (int)(CASE
        WHEN DepDel15 IS NULL THEN '0'
        WHEN DepDel15 == ''   THEN '0'
        WHEN DepDel15 == 'NA' THEN '0'
        ELSE DepDel15 END)              AS DepDel15,
    (int)(CASE
        WHEN ArrDel15 IS NULL THEN '0'
        WHEN ArrDel15 == ''   THEN '0'
        WHEN ArrDel15 == 'NA' THEN '0'
        ELSE ArrDel15 END)              AS ArrDel15,
    (int)(CASE
        WHEN Cancelled IS NULL THEN '0'
        WHEN Cancelled == ''   THEN '0'
        WHEN Cancelled == 'NA' THEN '0'
        ELSE Cancelled END)             AS Cancelled,
    (CASE
        WHEN CancellationCode IS NULL THEN 'NONE'
        WHEN CancellationCode == ''   THEN 'NONE'
        ELSE TRIM(CancellationCode) END) AS CancellationCode,
    (int)(CASE
        WHEN Diverted IS NULL THEN '0'
        WHEN Diverted == ''   THEN '0'
        WHEN Diverted == 'NA' THEN '0'
        ELSE Diverted END)              AS Diverted,
    (float)(CASE
        WHEN CarrierDelay IS NULL THEN '0'
        WHEN CarrierDelay == ''   THEN '0'
        WHEN CarrierDelay == 'NA' THEN '0'
        ELSE CarrierDelay END)          AS CarrierDelay,
    (float)(CASE
        WHEN WeatherDelay IS NULL THEN '0'
        WHEN WeatherDelay == ''   THEN '0'
        WHEN WeatherDelay == 'NA' THEN '0'
        ELSE WeatherDelay END)          AS WeatherDelay,
    (float)(CASE
        WHEN NASDelay IS NULL THEN '0'
        WHEN NASDelay == ''   THEN '0'
        WHEN NASDelay == 'NA' THEN '0'
        ELSE NASDelay END)              AS NASDelay,
    (float)(CASE
        WHEN SecurityDelay IS NULL THEN '0'
        WHEN SecurityDelay == ''   THEN '0'
        WHEN SecurityDelay == 'NA' THEN '0'
        ELSE SecurityDelay END)         AS SecurityDelay,
    (float)(CASE
        WHEN LateAircraftDelay IS NULL THEN '0'
        WHEN LateAircraftDelay == ''   THEN '0'
        WHEN LateAircraftDelay == 'NA' THEN '0'
        ELSE LateAircraftDelay END)     AS LateAircraftDelay,
    (float)(CASE
        WHEN Distance IS NULL THEN '0'
        WHEN Distance == ''   THEN '0'
        WHEN Distance == 'NA' THEN '0'
        ELSE Distance END)              AS Distance,
    (int)(CASE
        WHEN DistanceGroup IS NULL THEN '0'
        WHEN DistanceGroup == ''   THEN '0'
        WHEN DistanceGroup == 'NA' THEN '0'
        ELSE DistanceGroup END)         AS DistanceGroup,
    (float)(CASE
        WHEN TaxiOut IS NULL THEN '0'
        WHEN TaxiOut == ''   THEN '0'
        WHEN TaxiOut == 'NA' THEN '0'
        ELSE TaxiOut END)               AS TaxiOut,
    (float)(CASE
        WHEN TaxiIn IS NULL THEN '0'
        WHEN TaxiIn == ''   THEN '0'
        WHEN TaxiIn == 'NA' THEN '0'
        ELSE TaxiIn END)                AS TaxiIn,
    (float)(CASE
        WHEN AirTime IS NULL THEN '0'
        WHEN AirTime == ''   THEN '0'
        WHEN AirTime == 'NA' THEN '0'
        ELSE AirTime END)               AS AirTime;

-- =============================================================
-- STEP 4: Load airport lookup table (TAB separated)
-- =============================================================
airports_raw = LOAD '/user/maria_dev/flight_data/lookup/L_AIRPORT_ID.csv'
    USING PigStorage('\t')
    AS (AirportCode:chararray, AirportDescription:chararray);

airports = FILTER airports_raw BY AirportCode != 'Code';

airports_clean = FOREACH airports GENERATE
    (int)(AirportCode)      AS AirportID,
    AirportDescription      AS AirportDescription;

-- =============================================================
-- STEP 5: Join flights with airport names (LEFT OUTER)
-- LEFT OUTER keeps all flights even if airport not in lookup
-- =============================================================
flights_with_origin = JOIN cleaned_flights BY OriginAirportID LEFT OUTER,
                           airports_clean  BY AirportID;

enriched_flights = FOREACH flights_with_origin GENERATE
    cleaned_flights::Year                      AS Year,
    cleaned_flights::Quarter                   AS Quarter,
    cleaned_flights::Month                     AS Month,
    cleaned_flights::DayofMonth                AS DayofMonth,
    cleaned_flights::DayOfWeek                 AS DayOfWeek,
    cleaned_flights::FlightDate                AS FlightDate,
    cleaned_flights::Marketing_Airline_Network AS Marketing_Airline_Network,
    cleaned_flights::Operating_Airline         AS Operating_Airline,
    cleaned_flights::OriginAirportID           AS OriginAirportID,
    cleaned_flights::Origin                    AS Origin,
    cleaned_flights::OriginCityName            AS OriginCityName,
    cleaned_flights::OriginState               AS OriginState,
    (CASE
        WHEN airports_clean::AirportDescription IS NULL
        THEN 'Unknown Airport'
        ELSE airports_clean::AirportDescription
    END)                                       AS OriginAirportName,
    cleaned_flights::DestAirportID             AS DestAirportID,
    cleaned_flights::Dest                      AS Dest,
    cleaned_flights::DestCityName              AS DestCityName,
    cleaned_flights::DestState                 AS DestState,
    cleaned_flights::CRSDepTime                AS CRSDepTime,
    cleaned_flights::DepDelay                  AS DepDelay,
    cleaned_flights::ArrDelay                  AS ArrDelay,
    cleaned_flights::DepDel15                  AS DepDel15,
    cleaned_flights::ArrDel15                  AS ArrDel15,
    cleaned_flights::Cancelled                 AS Cancelled,
    cleaned_flights::CancellationCode          AS CancellationCode,
    cleaned_flights::Diverted                  AS Diverted,
    cleaned_flights::CarrierDelay              AS CarrierDelay,
    cleaned_flights::WeatherDelay              AS WeatherDelay,
    cleaned_flights::NASDelay                  AS NASDelay,
    cleaned_flights::SecurityDelay             AS SecurityDelay,
    cleaned_flights::LateAircraftDelay         AS LateAircraftDelay,
    cleaned_flights::Distance                  AS Distance,
    cleaned_flights::DistanceGroup             AS DistanceGroup,
    cleaned_flights::TaxiOut                   AS TaxiOut,
    cleaned_flights::TaxiIn                    AS TaxiIn,
    cleaned_flights::AirTime                   AS AirTime;

-- =============================================================
-- STEP 6: Store cleaned output (pipe separated)
-- Pipe used because city names contain commas
-- =============================================================
STORE enriched_flights
    INTO '/user/maria_dev/flight_data/cleaned'
    USING PigStorage('|');
```
