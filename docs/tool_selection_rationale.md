```markdown
# Tool Selection Rationale
## BTS Flight Delay Analysis — December 2025

---

## Overview

This document justifies every tool choice in our big data pipeline
based on the characteristics of the BTS flight delay dataset
and the specific analytical tasks required.

---

## 1. Apache Pig — Initial ETL Attempt

**What we did with Pig:**

Apache Pig was the first tool selected for data cleaning
because it is the standard Hadoop ETL tool covered in
Week 4 of the course. It provides a high-level dataflow
language (Pig Latin) that simplifies MapReduce operations.

We built a complete Pig Latin script that:
- Loaded raw BTS CSV from HDFS using CSVExcelStorage
- Filtered duplicate records where Duplicate flag equals Y
- Applied CASE WHEN ELSE to handle NULL empty and NA values
- Joined with airport lookup table using LEFT OUTER JOIN
- Stored pipe-separated output back to HDFS

**Errors encountered and fixed during Pig development:**

| Error | Cause | Fix Applied |
|-------|-------|-------------|
| mismatched input '?' expecting SEMI_COLON | Pig 0.16 does not support ternary operator ?: | Replaced all ?: with CASE WHEN ELSE |
| mismatched input 'OTHERWISE' expecting END | Pig 0.16 uses ELSE not OTHERWISE | Replaced all OTHERWISE with ELSE |
| All text fields NULL in output | BTS CSV uses comma separator not tab | Changed PigStorage from tab to comma |
| Still all NULL after separator fix | BTS CSV uses RFC 4180 quoted fields | Switched to CSVExcelStorage piggybank |
| Columns still shifted in output | Quoted city names contain commas inside | Could not be fully resolved in Pig 0.16 |

**Why we switched to Python:**

The root cause was that BTS CSV stores city names
as RFC 4180 quoted fields containing commas:
```
"San Francisco, CA"
"Dallas/Fort Worth, TX"
```

Pig 0.16 CSVExcelStorage handled the outer quotes
but still produced column shifting because commas
inside quoted city names interacted incorrectly
with the schema column definitions.
After multiple debugging attempts the decision was
made to switch to Python which handles RFC 4180
quoted CSV natively and correctly.

The complete Pig script is preserved in
`scripts/pig/flight_cleaning.pig` to demonstrate
the full ETL logic and the systematic debugging process.

**What Pig contributed to the final pipeline:**
Even though Python did the final cleaning,
Pig development was not wasted. The CASE WHEN ELSE
NULL handling logic developed in Pig was directly
transferred to the Python script as the
clean_num() and clean_code() helper functions.

---

## 2. Python — Final Data Cleaning Solution

**Why Python over Pig for this specific dataset:**

| Factor | Python | Pig 0.16 |
|--------|--------|----------|
| Quoted CSV support | Native csv module — RFC 4180 compliant | CSVExcelStorage — partial support only |
| Commas inside quoted fields | Handled correctly | Causes column shifting |
| Column index selection | Direct list indexing by position | Complex GENERATE statements |
| Error handling per row | Try/except skips bad rows | Script fails on first bad row |
| Debugging visibility | Print statements per 100K rows | Limited log visibility |
| Speed for single pass | Under 5 minutes for 644K rows | Adds MapReduce overhead for one pass |

**Outcome:** 644,987 rows cleaned correctly in under 5 minutes.

---

## 3. HDFS — Distributed Storage

**Why HDFS over local filesystem?**

- Dataset is 308 MB raw — large enough to justify distributed storage
- HDFS provides 3x block replication for fault tolerance
- All Hadoop tools (Hive, Pig, Spark, HBase) read from HDFS natively
- Scalable — adding more months just means adding more files
  to the same HDFS directory

**Acknowledged trade-off:**
For a single month HDFS is technically over-engineered.
The choice is justified on scalability grounds — a full year
of BTS data would exceed 3.5 GB requiring distributed processing.

---

## 4. Apache Hive — Batch SQL Analytics

**Why Hive for analytical queries?**

| Factor | Hive | Direct Spark SQL |
|--------|------|-----------------|
| SQL familiarity | Standard HiveQL | Requires Spark setup |
| Batch aggregations | Optimized for GROUP BY | Better for iterative ML |
| External tables | Points to HDFS without moving data | Requires explicit loading |
| HDP Sandbox support | Native | Requires additional config |

**Key fixes applied during Hive development:**

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| NULL outputs from all delay queries | BTS stores missing values as empty string not SQL NULL | Used NVL() on every delay column |
| Cancellation JOIN returns 0 rows | L_CANCELLATION.csv stores codes as "A" with embedded quotes | Used OpenCSVSerde to strip double quotes |
| ParseException in Ambari Hive View | Copy-paste adds hidden unicode characters | Switched all complex queries to Beeline |
| ORDER BY error with CASE WHEN | Hive 1.2 limitation with aliased CASE columns | Used ORDER BY 1 instead of column alias |

**Beeline over Ambari Hive View:**
Ambari Hive View introduces hidden unicode characters
(em dashes and smart quotes) when SQL is copy-pasted
from external sources. Beeline connects directly to
HiveServer2 over JDBC without any encoding issues.

---

## 5. Apache Spark MLlib — Machine Learning

**Why Spark for ML instead of Hive?**

Hive has no built-in machine learning library.
Spark MLlib provides:
- Random Forest with parallel tree building across 100 trees
- In-memory processing 10-100x faster than MapReduce for iteration
- Pipeline API for clean reproducible feature engineering
- Built-in evaluation metrics including AUC-ROC F1 and Accuracy

**Model results:**
- Algorithm: Random Forest (100 trees, max depth 10)
- Training set: 507,447 flights (80%)
- Test set: 127,000 flights (20%)
- AUC-ROC: 0.9639
- Accuracy: 93.0%
- F1 Score: 0.9288
- Top feature: DepDelay (0.8397 importance — 84% of predictive power)

**Cost trade-off acknowledged:**
Spark requires more cluster RAM and is more expensive to run.
Strategy: Use Pig and Hive for all batch ETL and aggregation
(cheaper and simpler). Reserve Spark only for the ML model
where in-memory iteration is genuinely required.

---

## 6. HBase — Real-Time Lookups

**Why HBase for result storage?**

| Scenario | Hive Time | HBase + Phoenix Time | Speedup |
|----------|-----------|---------------------|---------|
| Single airport lookup | ~45 seconds | 0.5 seconds | 90x |
| Carrier ranking | ~45 seconds | 0.8 seconds | 56x |
| Flight prediction lookup | ~45 seconds | 0.8 seconds | 56x |

HBase enables passenger-facing applications to retrieve
delay statistics instantly. Hive batch queries taking
45 seconds per lookup are completely unsuitable for
real-time dashboards or mobile applications.

**CAP Theorem Justification:**

HBase is a CP system (Consistent + Partition tolerant).

This is the correct choice because:
- Airport delay statistics must be accurate at all times
- A stale or wrong delay rate would mislead passengers
  making booking decisions based on incorrect information
- We accept reduced availability in exchange for consistency
- Reference data changes infrequently so availability
  is less critical than accuracy

If we were building a 24/7 real-time dashboard requiring
maximum availability we would choose Cassandra (AP system).
For accurate reference data lookups HBase CP is correct.

---

## 7. Apache Phoenix — SQL on HBase

**Why Phoenix instead of direct HBase API?**

| Factor | HBase Shell | Phoenix SQL |
|--------|-------------|-------------|
| Syntax | get table rowkey scan table | Standard SQL SELECT |
| Aggregations | Not supported | AVG SUM COUNT |
| Sorting | Not supported | ORDER BY |
| Filtering | Row key only | Full WHERE clause |
| Familiarity | NoSQL only | SQL familiar to analysts |
| Query speed | Milliseconds | Milliseconds |

Phoenix bridges the gap between HBase NoSQL model
and the SQL skills that business analysts already have.
All 5 Phoenix queries returned results in under 2 seconds
with full SQL expressiveness including ORDER BY and WHERE.

---

## CAP Theorem Summary

| System | CAP Type | Justification |
|--------|----------|---------------|
| HBase | CP — Consistent + Partition tolerant | Airport and carrier delay stats must be accurate — stale data misleads passengers |
| Cassandra (not used) | AP — Available + Partition tolerant | Would choose for 24/7 high availability dashboard requirement |
| MongoDB (not used) | Configurable | Would choose for variable-schema document storage of analysis outputs |

---

## Batch vs Real-Time Decision

| Data Task | Tool Choice | Justification |
|-----------|-------------|---------------|
| Historical analysis of all 644,987 records | Hive batch | BTS data released monthly — no streaming requirement |
| Single airport or carrier lookup | HBase + Phoenix | Sub-second response needed for dashboards |
| Iterative ML training | Spark MLlib | In-memory iteration for 100-tree Random Forest |
| Data cleaning one-time | Python | Handles RFC 4180 quoted CSV that Pig 0.16 cannot |
| ETL logic demonstration | Pig | Demonstrates Pig Latin dataflow and NULL handling |

---

## Summary

Every tool was chosen based on the specific requirements
of the task not for completeness or to cover all tools.

- Pig was tried first for ETL — genuine attempt documented
- Python replaced Pig due to a specific quoted CSV limitation
- Hive was chosen over Spark for batch SQL — native HDFS integration
- Spark was chosen over Hive for ML — Hive has no MLlib
- HBase was chosen over Hive for lookups — 90x speed improvement
- Phoenix was added over raw HBase — SQL familiarity for analysts
- CP was chosen over AP — accuracy over availability for reference data

This tool selection demonstrates understanding of when
each technology excels and when alternatives are more appropriate.
```
