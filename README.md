![BTS Flight Delay Analysis](visualizations/creative_banner.png)

# ✈️ BTS Flight Delay Analysis
### Big Data Management Assignment — MSc Data Science & Analytics

---

## Project Overview

End-to-end big data analysis of **644,987 U.S. domestic flights**
from the BTS Marketing Carrier On-Time Performance dataset (December 2025)
using the complete Hadoop ecosystem.

**Problem Statement:**
> Identifying systemic delay patterns in U.S. domestic aviation
> to provide actionable recommendations for airlines,
> passengers, and airport operators.

---

## Dataset

| Property | Detail |
|----------|--------|
| Source | Bureau of Transportation Statistics (BTS) |
| Table | Marketing Carrier On-Time Performance |
| Period | December 2025 |
| Records | 644,987 flights |
| Raw fields | 120 variables |
| Selected fields | 34 for analysis |
| Raw size | 308 MB |
| Cleaned size | 104 MB |

---

## Data Download Links

### Raw Data (308 MB)
Download directly from BTS Official Website:

[![Download from BTS](https://img.shields.io/badge/Download-BTS%20Official%20Website-blue?style=for-the-badge)](https://www.transtats.bts.gov/DL_SelectFields.aspx?gnoyr_VQ=FGK&QO_fu146_anzr=b0-gvzr)

> Select **December 2025** after opening the link
> then click **Download** to get the CSV file

### Lookup Tables (included in this repository)

| File | Description | Size |
|------|-------------|------|
| [L_AIRPORT_ID.csv](data/lookup/L_AIRPORT_ID.csv) | Airport ID to name mapping | 324 KB |
| [L_CANCELLATION.csv](data/lookup/L_CANCELLATION.csv) | Cancellation reason codes A B C D | 91 bytes |
| [L_UNIQUE_CARRIERS.csv](data/lookup/L_UNIQUE_CARRIERS.csv) | Carrier codes to airline names | 53 KB |

### Sample Data (included in this repository)

| File | Description | Rows |
|------|-------------|------|
| [sample_5rows.csv](data/samples/sample_5rows.csv) | 5 sample cleaned records | 5 |

---

## Tools and Technologies

| Tool | Version | Purpose | Key Result |
|------|---------|---------|-----------|
| Python 2.7 | 2.7.5 | Data cleaning | 644,987 records cleaned |
| HDFS | 2.7.3 | Distributed storage | 104 MB stored |
| Apache Hive | 1.2.1 | Batch SQL analytics | 7 queries completed |
| Apache Spark | 3.x | ML prediction | AUC-ROC 0.9639 |
| HBase | 1.1.x | Real-time lookups | Sub-second queries |
| Apache Phoenix | 4.7.x | SQL on HBase | 5 queries under 2 sec |
| Python 3.12 | 3.12 | Visualizations | 7 charts generated |

---

## Pipeline Architecture

![Pipeline Flowchart](visualizations/pipeline_flowchart.png)

---

## Key Results

### Overall Statistics
| Metric | Value |
|--------|-------|
| Total flights analyzed | 644,987 |
| Overall delay rate (>=15 min) | 26.4% |
| Average arrival delay | 13.20 minutes |
| Total cancellations | 10,540 (1.6%) |
| Total diversions | 1,577 (0.2%) |
| Unique airlines | 10 |
| Unique airports | 359 |

### Best vs Worst Day to Fly
| Day | Avg Delay | Delay Rate |
|-----|-----------|------------|
| Wednesday (Best) | 5.68 min | 21.07% |
| Sunday (Worst) | 28.15 min | 35.64% |

### Best vs Worst Airline
| Airline | Avg Arrival Delay | Delay Rate |
|---------|------------------|------------|
| Southwest (Best) | 7.72 min | 24.43% |
| JetBlue (Worst) | 21.27 min | 35.07% |

### Cancellation Reasons
| Reason | Percentage |
|--------|------------|
| Weather | 56.01% |
| Carrier | 31.18% |
| National Air System | 12.80% |
| Security | 0.02% |

### Spark ML Model
| Metric | Value |
|--------|-------|
| Algorithm | Random Forest (100 trees) |
| AUC-ROC | 0.9639 |
| Accuracy | 93.0% |
| F1 Score | 0.9288 |
| Top predictor | Departure Delay (84% importance) |

### HBase + Phoenix Query Speed
| Query | Hive Time | Phoenix Time | Speedup |
|-------|-----------|-------------|---------|
| Single airport lookup | ~45 seconds | 0.5 seconds | 90x |
| Carrier ranking | ~45 seconds | 0.8 seconds | 56x |
| Flight prediction lookup | ~45 seconds | 0.8 seconds | 56x |

---

## Visualizations

### Delay Dashboard
![Delay Dashboard](visualizations/delay_dashboard.png)

### Carrier Performance Heatmap
![Carrier Performance](visualizations/carrier_performance_heatmap.png)

### Cancellation Risk Map
![Cancellation Risk](visualizations/cancellation_risk_map.png)

### Delay Cause by Carrier
![Delay Causes](visualizations/delay_cause_by_carrier.png)

### Feature Importance
![Feature Importance](visualizations/chart6_feature_importance.png)

### Confusion Matrix
![Confusion Matrix](visualizations/chart7_confusion_matrix.png)

---

## Repository Structure

````
bts-flight-delay-analysis/
|
|-- README.md
|-- visualizations/
|   |-- creative_banner.png
|   |-- pipeline_flowchart.png
|   |-- delay_dashboard.png
|   |-- carrier_performance_heatmap.png
|   |-- cancellation_risk_map.png
|   |-- delay_cause_by_carrier.png
|   |-- chart6_feature_importance.png
|   |-- chart7_confusion_matrix.png
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
|   |-- BTS_Flight_Delay_Analysis_Visualizations.ipynb
|   |-- BTS_Flight_Delay_Spark_ML.ipynb
|
|-- docs/
|   |-- tool_selection_rationale.md
|   |-- pipeline_architecture.md
|   |-- data_dictionary.md
|
|-- data/
|   |-- lookup/
|   |   |-- L_AIRPORT_ID.csv
|   |   |-- L_CANCELLATION.csv
|   |   |-- L_UNIQUE_CARRIERS.csv
|   |-- samples/
|   |   |-- sample_5rows.csv
````

---

## How to Reproduce

### Prerequisites
- VirtualBox with HDP Sandbox 2.6.5
- PuTTY (Windows SSH client)
- WinSCP (Windows SFTP client)
- Google Colab account

### Step 1 — Download BTS Data
[![Download from BTS](https://img.shields.io/badge/Download-BTS%20Official%20Website-blue)](https://www.transtats.bts.gov/DL_SelectFields.aspx?gnoyr_VQ=FGK&QO_fu146_anzr=b0-gvzr)

Select December 2025 then download the CSV file.
Also download the lookup files from the same page.

### Step 2 — Transfer Files to VM
Use WinSCP to transfer all CSV files to:
````
/home/maria_dev/flight_data/
````

### Step 3 — Clean the Data
```bash
python scripts/python/clean_flights.py
hdfs dfs -mkdir /user/maria_dev/flight_data/cleaned
hdfs dfs -put /home/maria_dev/flight_data/On_Time_Clean.csv \
    /user/maria_dev/flight_data/cleaned/
```

### Step 4 — Create Hive Tables
```bash
beeline -u jdbc:hive2://localhost:10000 -n maria_dev -p maria_dev
```
Then paste contents of `scripts/hive/create_tables.hql`

### Step 5 — Run Analytical Queries
In Beeline paste `scripts/hive/analysis_queries.hql`

### Step 6 — Run Spark ML (Google Colab)
1. Upload On_Time_Clean.csv to Colab
2. Open `notebooks/BTS_Flight_Delay_Spark_ML.ipynb`
3. Run all cells

### Step 7 — Create Visualizations (Google Colab)
1. Open `notebooks/BTS_Flight_Delay_Analysis_Visualizations.ipynb`
2. Run all cells
3. Download PNG charts

### Step 8 — Set Up HBase
```bash
hbase shell
```
Paste commands from `scripts/hbase/create_tables.txt`

### Step 9 — Run Phoenix Queries
```bash
/usr/hdp/current/phoenix-client/bin/sqlline.py \
    localhost:2181:/hbase-unsecure
```
Paste `scripts/phoenix/create_views.sql`

---

## Key Insights and Recommendations

### For Passengers
1. Book morning flights (5AM-6AM) — delay rate 12.5% vs 35% in evening
2. Fly Tuesday Wednesday or Thursday — avoid Friday and Sunday
3. Choose Southwest or Alaska Airlines for December travel
4. Build 3 hour connection buffers at New York and Chicago airports

### For Airlines
1. Add 10-15 minute schedule buffers to afternoon rotations
2. Invest in predictive maintenance to reduce carrier delays
3. Deploy ML delay prediction for proactive passenger rebooking
4. Focus operational improvements on Friday and Sunday schedules

### For Airport Operators
1. LaGuardia and JFK need expanded runway capacity
2. Chicago O Hare requires better ground crew coordination in peak hours
3. Implement real-time delay monitoring dashboards using HBase and Phoenix

---

## Author

**[Your Name]**
MSc Data Science and Analytics
[Your University]
Student ID: [Your ID]

---

## License

MIT License
````

6. Click **Commit changes**

---

## ✅ What this README now has

| Section | Content |
|---------|---------|
| Banner image | creative_banner.png from visualizations/ |
| BTS download button | Badge linking to official BTS website |
| Lookup table links | Direct links to files in data/lookup/ |
| Pipeline flowchart | pipeline_flowchart.png from visualizations/ |
| All 6 chart images | Correct paths to visualizations/ folder |
| Full repo structure | Updated with all actual folders |
| Reproduce steps | Complete step by step guide |
