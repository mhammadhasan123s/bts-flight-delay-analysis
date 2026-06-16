# Tool Selection Rationale
## BTS Flight Delay Analysis — December 2025

---

## Overview

This document justifies every tool choice in our big data pipeline
based on the characteristics of the BTS flight delay dataset
and the specific analytical tasks required.

---

## 1. Python — Data Cleaning

**Why Python instead of Pig for cleaning?**

The raw BTS CSV file uses quoted fields with commas inside values:
```
"San Francisco, CA"
"Dallas/Fort Worth, TX"
```

Apache Pig's `PigStorage(',')` splits on every comma including
those inside quoted strings — causing column shifting and wrong values.
Python's built-in `csv` module correctly handles RFC 4180 quoted CSV.

| Factor | Python | Pig |
|--------|--------|-----|
| Quoted CSV support | Native csv module | Requires piggybank CSVExcelStorage |
| Column index selection | Direct list indexing | Complex GENERATE statements |
| Error handling | Try/except per row | Script fails on bad rows |
| Speed for single pass | Fast enough for 644K rows | Adds MapReduce overhead |

**Outcome:** 644,987 rows cleaned in under 5 minutes on the VM.

---

## 2. HDFS — Distributed Storage

**Why HDFS over local filesystem?**

- Dataset is 308 MB raw — large enough to justify distributed storage
- HDFS provides 3x block replication for fault tolerance
- All Hadoop tools (Hive, Pig, Spark, HBase) read from HDFS natively
- Scalable: adding more months just means adding more files to the same directory

**Acknowledged trade-off:**
For a single month's data, HDFS is technically over-engineered.
The choice is justified on scalability grounds — a full year
of BTS data would exceed 3.5 GB, requiring distributed processing.

---

## 3. Apache Hive — Batch SQL Analytics

**Why Hive for analytical queries?**

| Factor | Hive | Direct Spark SQL |
|--------|------|-----------------|
| SQL familiarity | Standard HiveQL | Requires Spark setup |
| Batch aggregations | Optimized for GROUP BY | Better for iterative ML |
| External tables | Points to HDFS without moving data | Requires explicit loading |
| HDP Sandbox support | Native | Requires additional config |

**Key fix applied:**
Hive 1.2 on HDP Sandbox does not support `OTHERWISE` in CASE statements.
All queries use `ELSE` instead.
The `NVL()` function replaces all NULL values in aggregations.
`OpenCSVSerde` was used for cancellation_codes to strip quoted values.

**Beeline over Ambari Hive View:**
Ambari Hive View introduces hidden unicode characters when SQL is
copy-pasted from external sources. Beeline connects directly to
HiveServer2 without encoding issues.

---

## 4. Apache Spark MLlib — Machine Learning

**Why Spark for ML instead of Hive?**

Hive has no built-in machine learning library.
Spark MLlib provides:
- Random Forest with parallel tree building
- In-memory processing (10-100x faster than MapReduce for iteration)
- Pipeline API for reproducible feature engineering
- Built-in evaluation metrics (AUC-ROC, F1, Accuracy)

**Model results:**
- Algorithm: Random Forest (100 trees, max depth 10)
- Training set: 507,447 flights (80%)
- Test set: 127,000 flights (20%)
- AUC-ROC: 0.9639
- Accuracy: 93.0%
- F1 Score: 0.9288

**Top feature: DepDelay (0.8397 importance)**
Departure delay alone explains 84% of the model's predictive power.

---

## 5. HBase — Real-Time Lookups

**Why HBase for result storage?**

| Scenario | Hive Time | HBase + Phoenix Time |
|----------|-----------|---------------------|
| Single airport lookup | ~45 seconds | 0.5 seconds |
| Carrier ranking | ~45 seconds | 0.8 seconds |
| Flight prediction lookup | ~45 seconds | 0.8 seconds |

HBase enables passenger-facing applications to retrieve
delay statistics instantly — Hive batch queries are
completely unsuitable for real-time dashboards.

**CAP Theorem Justification:**

HBase is a **CP system** (Consistent + Partition tolerant).

This is the correct choice because:
- Airport delay statistics must be accurate
- A stale or wrong delay rate would mislead passengers
- We accept reduced availability in exchange for consistency
- Reference data changes infrequently so availability is less critical

If we were building a 24/7 real-time dashboard requiring
high availability, we would choose Cassandra (AP system) instead.

---

## 6. Apache Phoenix — SQL on HBase

**Why Phoenix instead of direct HBase API?**

| Factor | HBase Shell | Phoenix SQL |
|--------|-------------|-------------|
| Syntax | `get 'table', 'rowkey'` | Standard SQL |
| Aggregations | Not supported | AVG, SUM, COUNT |
| Sorting | Not supported | ORDER BY |
| Filtering | Row key only | Full WHERE clause |
| Familiarity | NoSQL only | SQL — familiar to analysts |

Phoenix bridges the gap between HBase's NoSQL model
and the SQL skills that business analysts already have.
Queries run in under 2 seconds — same speed as raw HBase
but with full SQL expressiveness.

---

## CAP Theorem Summary

| System | CAP Type | Why Chosen |
|--------|----------|------------|
| HBase | CP | Consistent + Partition tolerant — delay stats must be accurate |
| Cassandra (not used) | AP | Would choose for 24/7 availability requirement |
| MongoDB (not used) | Configurable | Would choose for variable-schema document storage |

---

## Batch vs Real-Time Decision

| Data Task | Tool Choice | Justification |
|-----------|-------------|---------------|
| Historical analysis of all 644,987 records | Hive (batch) | BTS data released monthly — no streaming needed |
| Single airport or carrier lookup | HBase + Phoenix | Sub-second response for dashboards |
| Iterative ML training | Spark | In-memory iteration for Random Forest |
| Data cleaning (one-time) | Python | Handles quoted CSV that Pig cannot |

---

## Summary

Every tool was chosen based on the specific requirements
of the task, not for completeness.
Python was chosen over Pig because of quoted CSV.
Hive was chosen over Spark for batch SQL because it
integrates natively with HDFS external tables.
Spark was chosen over Hive for ML because Hive has no MLlib.
HBase was chosen over Hive for lookups because 45-second
queries are unsuitable for real-time applications.
Phoenix was added on top of HBase to provide SQL access
without requiring HBase Java API knowledge.
