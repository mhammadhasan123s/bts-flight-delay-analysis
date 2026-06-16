```markdown
# Pipeline Architecture
## BTS Flight Delay Analysis — December 2025

---

## Complete Data Pipeline

```
BTS Website (transtats.bts.gov)
    |
    | Download
    v
Raw CSV File (308 MB)
    - 644,987 rows
    - 120 columns
    - Quoted fields with commas inside city names
    - Example: "San Francisco, CA"
    |
    | Python clean_flights.py (runs on VM via PuTTY)
    | - Strip double quotes
    | - Select 34 key columns by exact index
    | - Replace NULL/empty/NA with 0
    | - Skip duplicate records (Duplicate flag = Y)
    | - Write pipe-separated output
    v
Cleaned CSV (104 MB)
    - 644,987 rows
    - 34 columns
    - Pipe-separated (avoids comma conflicts)
    - No header row
    |
    | hdfs dfs -put
    v
HDFS /user/maria_dev/flight_data/cleaned/
    |
    |-----> Apache Hive (Batch Analytics)
    |           - 4 tables created
    |           - 7 analytical queries
    |           - Results: delays, cancellations, carriers, trends
    |
    |-----> Apache Spark MLlib (Machine Learning)
    |           - Random Forest Classifier (100 trees)
    |           - 14 features including departure delay
    |           - AUC-ROC: 0.9639, Accuracy: 93.0%
    |           - Feature importance analysis
    |
    v
Aggregated Results
    |
    | HBase put commands (via HBase shell in PuTTY)
    v
HBase Tables (3 tables)
    - airport_delays: 5 airports with delay stats
    - carrier_performance: 10 airlines with performance metrics
    - flight_predictions: 3 sample ML predictions
    |
    | Phoenix CREATE VIEW
    v
Phoenix SQL Views (3 views)
    - SQL queries on HBase data
    - Sub-second response times
    - 5 analytical queries run

Python Visualizations (Google Colab)
    - 7 charts generated from Hive query results
    - Saved as PNG files
    - Embedded in Jupyter notebook
```

---

## Environment Details

| Component | Version | Where |
|-----------|---------|-------|
| Operating System | CentOS 7 | HDP Sandbox VM |
| Hadoop | 2.7.3 | HDP Sandbox |
| Apache Hive | 1.2.1 | HDP Sandbox |
| Apache Pig | 0.16.0 | HDP Sandbox |
| Apache Spark | 3.x | Google Colab |
| HBase | 1.1.x | HDP Sandbox |
| Apache Phoenix | 4.7.x | HDP Sandbox |
| Python | 2.7.5 | HDP Sandbox VM |
| Python | 3.12 | Google Colab |

---

## Key Design Decisions

### 1. Python over Pig for Data Cleaning
BTS CSV uses RFC 4180 quoted fields with commas inside
city names. Pig PigStorage splits on all commas causing
column shifting. Python csv module handles quoted CSV
correctly by design.

### 2. Pipe Separator for HDFS Storage
City names contain commas (San Francisco, CA).
Using pipe as field delimiter prevents Hive from
misreading comma-separated city names as multiple columns.

### 3. Beeline over Ambari Hive View
Ambari Hive View introduces hidden unicode characters
when SQL is copy-pasted from external sources.
These cause ParseException errors that do not appear
in Beeline. Beeline connects directly to HiveServer2
over JDBC without any text encoding issues.

### 4. OpenCSVSerde for cancellation_codes Table
The L_CANCELLATION.csv file stores values with double
quotes: "A","Carrier". Standard Hive TEXTFILE serde
reads the quotes as part of the value causing
JOIN failures. OpenCSVSerde strips the quotes correctly.

### 5. HBase CP Model over Cassandra AP
Airport and carrier delay statistics must be accurate.
A passenger dashboard showing wrong delay rates would
mislead booking decisions. HBase CP model guarantees
accurate reads at the cost of some availability during
network partitions.

### 6. FLOAT over INT for Delay Columns in Hive
The BTS CSV stores delay values as 4.00 with decimal
places. Defining Hive columns as FLOAT instead of INT
prevents silent truncation and avoids NULL values
from failed integer casting.

---

## Data Quality Issues Encountered and Fixed

| Issue | Root Cause | Fix Applied |
|-------|-----------|------------|
| All text fields NULL in Pig output | BTS CSV uses quoted format | Switched to Python for cleaning |
| Column shifting in output | Trailing comma added phantom column | Python strips trailing empty field |
| Wrong column values | Incorrect column indices | Printed all 120 column names and mapped correctly |
| Hive query returns 0 rows | Cleaned folder existed but was empty | Re-uploaded clean file to HDFS |
| AVG delay = 1488 minutes | ArrDelay column was reading wrong index | Fixed column indices in Python script |
| Cancellation JOIN returns empty | L_CANCELLATION.csv stored with embedded quotes | Used OpenCSVSerde to strip quotes |
| Hive ParseException | Ambari adds hidden unicode characters | Switched all complex queries to Beeline |
| Pig CASE WHEN error | Pig 0.16 uses ELSE not OTHERWISE | Replaced all OTHERWISE with ELSE |
| Pig ternary operator error | Pig 0.16 does not support ?: syntax | Replaced with CASE WHEN ELSE |

---

## Files in This Repository

```
bts-flight-delay-analysis/
|
|-- README.md
|-- creative_banner.png
|-- pipeline_flowchart.png
|
|-- scripts/
|   |-- python/
|   |   |-- clean_flights.py
|   |-- hive/
|   |   |-- create_tables.hql
|   |   |-- analysis_queries.hql
|   |-- hbase/
|   |   |-- create_tables.txt
|   |-- phoenix/
|   |   |-- create_views.sql
|
|-- notebooks/
|   |-- BTS_Flight_Delay_Visualizations.ipynb
|   |-- BTS_Flight_Delay_Spark_ML.ipynb
|
|-- visualizations/
|   |-- chart1_delay_by_day.png
|   |-- chart2_carrier_performance.png
|   |-- chart3_cancellation_reasons.png
|   |-- chart4_delay_by_hour.png
|   |-- chart5_delay_causes.png
|   |-- chart6_feature_importance.png
|   |-- chart7_confusion_matrix.png
|
|-- docs/
|   |-- tool_selection_rationale.md
|   |-- pipeline_architecture.md
|   |-- data_dictionary.md
|
|-- data/
|   |-- samples/
|   |   |-- sample_5rows.csv
```
