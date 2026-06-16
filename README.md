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
| Source | [Bureau of Transportation Statistics (BTS)](https://www.transtats.bts.gov) |
| Table | Marketing Carrier On-Time Performance |
| Period | December 2025 |
| Records | 644,987 flights |
| Raw fields | 120 variables |
| Selected fields | 34 for analysis |
| Raw size | 308 MB |
| Cleaned size | 104 MB |

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

```
BTS Raw CSV (308MB, 644,987 rows, 120 cols, quoted)
          |
          | Python clean_flights.py
          | - Select 34 columns
          | - Strip quotes, fix NULLs
          v
Cleaned CSV (104MB, pipe-separated)
          |
          | hdfs dfs -put
          v
     HDFS Storage
          |
    ------+------+--------+
    |            |        |
    v            v        v
  Hive         Spark    HBase
  (Batch)      (ML)     (Real-time)
  7 queries    RF Model  3 tables
               93% acc   Phoenix SQL
          |
          v
    Python Charts
    (Google Colab)
    7 visualizations
```

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

### Chart 1 — Delay by Day of Week
![Delay by Day](visualizations/chart1_delay_by_day.png)

### Chart 2 — Carrier Performance
![Carrier Performance](visualizations/chart2_carrier_performance.png)

### Chart 3 — Cancellation Reasons
![Cancellations](visualizations/chart3_cancellation_reasons.png)

### Chart 4 — Delay by Hour of Day
![Hourly Delay](visualizations/chart4_delay_by_hour.png)

### Chart 5 — Delay Causes
![Delay Causes](visualizations/chart5_delay_causes.png)

### Chart 6 — Feature Importance
![Feature Importance](visualizations/chart6_feature_importance.png)

### Chart 7 — Confusion Matrix
![Confusion Matrix](visualizations/chart7_confusion_matrix.png)

---


