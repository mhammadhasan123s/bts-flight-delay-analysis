
```markdown
# Data Dictionary
## BTS Flight Delay Analysis — December 2025

---

## Source Dataset

| Property | Detail |
|----------|--------|
| Name | Marketing Carrier On-Time Performance |
| Source | Bureau of Transportation Statistics (BTS) |
| URL | https://www.transtats.bts.gov |
| Period | December 2025 |
| Raw records | 644,987 |
| Raw columns | 120 |
| Raw size | 308 MB |
| Format | Quoted CSV (RFC 4180) |
| Cleaned columns | 34 selected for analysis |
| Cleaned size | 104 MB |
| Cleaned format | Pipe-separated, no header |

---

## Selected Fields (34 columns used in analysis)

### Temporal Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| Year | INT | Calendar year | 2025 |
| Quarter | INT | Quarter (1-4) | 4 |
| Month | INT | Month (1-12) | 12 |
| DayofMonth | INT | Day of month (1-31) | 23 |
| DayOfWeek | INT | Day (1=Mon, 7=Sun) | 2 |
| FlightDate | STRING | Flight date (yyyy-mm-dd) | 2025-12-23 |

### Carrier Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| Marketing_Airline | STRING | Marketing carrier code | UA |
| Operating_Airline | STRING | Operating carrier code | UA |

### Origin Airport Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| OriginAirportID | INT | Unique airport ID stable across years | 14771 |
| Origin | STRING | 3-letter IATA airport code | SFO |
| OriginCityName | STRING | City and state | San Francisco, CA |
| OriginState | STRING | State abbreviation | CA |

### Destination Airport Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| DestAirportID | INT | Unique destination airport ID | 11278 |
| Dest | STRING | 3-letter IATA destination code | DCA |
| DestCityName | STRING | Destination city and state | Washington, DC |
| DestState | STRING | Destination state | VA |

### Schedule Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| CRSDepTime | STRING | Scheduled departure time (hhmm) | 0840 |

### Delay Fields

| Field | Type | Description | NULL Handling | Example |
|-------|------|-------------|---------------|---------|
| DepDelay | FLOAT | Actual minus scheduled departure (min). Negative means early | Replace NULL with 0 | 4.0 |
| ArrDelay | FLOAT | Actual minus scheduled arrival (min). Negative means early | Replace NULL with 0 | -29.0 |
| DepDel15 | FLOAT | 1 if departure delay is 15 or more min | Replace NULL with 0 | 0.0 |
| ArrDel15 | FLOAT | 1 if arrival delay is 15 or more min. Primary ML target | Replace NULL with 0 | 0.0 |

### Cancellation and Diversion Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| Cancelled | FLOAT | 1.0 means flight cancelled | 0.0 |
| CancellationCode | STRING | A=Carrier B=Weather C=NAS D=Security NONE=not cancelled | NONE |
| Diverted | FLOAT | 1.0 means flight diverted to different airport | 0.0 |

### Delay Cause Fields

> These are only populated when ArrDelay is greater than 0.
> For cancelled flights they are always NULL — replaced with 0.

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| CarrierDelay | FLOAT | Delay caused by airline (maintenance, crew) | 0.0 |
| WeatherDelay | FLOAT | Delay caused by weather | 0.0 |
| NASDelay | FLOAT | Delay caused by Air Traffic Control | 0.0 |
| SecurityDelay | FLOAT | Delay caused by security screening | 0.0 |
| LateAircraftDelay | FLOAT | Delay caused by previous flight arriving late | 28.0 |

### Distance and Time Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| Distance | FLOAT | Distance between airports in miles | 2442.0 |
| DistanceGroup | INT | Distance bucket every 250 miles | 10 |
| TaxiOut | FLOAT | Gate to takeoff time in minutes | 34.0 |
| TaxiIn | FLOAT | Landing to gate time in minutes | 4.0 |
| AirTime | FLOAT | Actual flight time in air in minutes | 246.0 |

---

## Lookup Tables

### L_AIRPORT_ID.csv
- Format: Tab-separated with header row
- Columns: Code (INT), Description (STRING)
- Records: approximately 6,408 airports
- Use: Join on OriginAirportID or DestAirportID

### L_CANCELLATION.csv
- Format: Comma-separated with quoted values and header row
- Columns: Code (STRING), Description (STRING)
- Records: 4 codes (A, B, C, D)
- Note: Uses OpenCSVSerde in Hive to strip double quotes

### L_UNIQUE_CARRIERS.csv
- Format: Comma-separated with header row
- Columns: Code (STRING), CarrierName (STRING)
- Records: approximately 1,700 carriers

---

## Cancellation Code Reference

| Code | Reason | Count in Data | Percentage |
|------|--------|--------------|------------|
| B | Weather | 5,903 | 56.01% |
| A | Carrier | 3,286 | 31.18% |
| C | National Air System | 1,349 | 12.80% |
| D | Security | 2 | 0.02% |

---

## Airline Code Reference

| Code | Airline | Avg Arr Delay | Rank |
|------|---------|--------------|------|
| WN | Southwest Airlines | 7.72 min | 1 Best |
| AS | Alaska Airlines | 8.08 min | 2 |
| UA | United Airlines | 13.63 min | 3 |
| DL | Delta Air Lines | 13.77 min | 4 |
| HA | Hawaiian Airlines | 14.53 min | 5 |
| AA | American Airlines | 15.14 min | 6 |
| G4 | Allegiant Air | 17.99 min | 7 |
| F9 | Frontier Airlines | 18.45 min | 8 |
| NK | Spirit Airlines | 18.63 min | 9 |
| B6 | JetBlue Airways | 21.27 min | 10 Worst |

---

## Data Quality Issues and Resolutions

| Issue | Root Cause | Resolution |
|-------|-----------|------------|
| Delay values all NULL | BTS stores missing values as empty string or NA | Python replaces with 0 before output |
| Column shifting | Trailing comma adds extra field | Python detects and removes trailing empty column |
| Airport names with commas | San Francisco, CA splits into two columns | Pipe separator used instead of comma |
| Quoted fields in raw CSV | BTS wraps all values in double quotes | Python csv module handles RFC 4180 quoting |
| Cancellation codes with quotes | L_CANCELLATION.csv stores "A","Carrier" | OpenCSVSerde strips embedded quotes |
| ArrDel15 as FLOAT | BTS exports binary flags as 0.00 and 1.00 | Hive FLOAT type accepts both — use = 1.0 in WHERE |

---

## Derived Features Created in Spark ML

| Feature | Formula | Purpose |
|---------|---------|---------|
| DepHour | CRSDepTime divided by 100 as integer | Hour of day 0 to 23 |
| IsPeakHour | 1 if DepHour between 16 and 20 else 0 | Peak evening hours flag |
| IsWeekend | 1 if DayOfWeek in 6 or 7 else 0 | Weekend travel flag |
| IsDelayed | 1 if ArrDel15 equals 1 else 0 | ML target variable |
```
