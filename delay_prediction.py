"""
=================================================================
Spark MLlib: Flight Delay Prediction
BTS On-Time Performance Dataset
=================================================================
Model:   Random Forest Classifier (binary: ArrDel15 >= 15min)
Metrics: AUC-ROC, Accuracy, Precision, Recall, F1
Outputs: Feature importance plot, confusion matrix, predictions CSV
=================================================================
Run options:
  1. PySpark on Hadoop cluster:
       spark-submit scripts/spark/delay_prediction.py
  2. Google Colab (PySpark via pip):
       See cell comments below
=================================================================
"""

# ── COLAB SETUP (uncomment if running in Google Colab) ───────────
# !pip install pyspark -q
# from google.colab import drive
# drive.mount('/content/drive')
# DATA_PATH = "/content/drive/MyDrive/flight_data/cleaned/"
# ─────────────────────────────────────────────────────────────────

import os
import warnings
warnings.filterwarnings("ignore")

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import IntegerType, FloatType

from pyspark.ml.feature import VectorAssembler, StringIndexer, StandardScaler
from pyspark.ml.classification import RandomForestClassifier, GBTClassifier
from pyspark.ml.evaluation import (BinaryClassificationEvaluator,
                                    MulticlassClassificationEvaluator)
from pyspark.ml import Pipeline
from pyspark.ml.tuning import CrossValidator, ParamGridBuilder

import pandas as pd
import matplotlib
matplotlib.use("Agg")          # headless backend for cluster
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

# ── CONFIG ────────────────────────────────────────────────────────
DATA_PATH     = "/user/maria_dev/flight_data/cleaned/"   # Hadoop path
OUTPUT_DIR    = "visualizations/"                        # local output
SEED          = 42
MIN_FLIGHTS   = 50             # minimum records to include a carrier/airport

os.makedirs(OUTPUT_DIR, exist_ok=True)

# ── 1. SPARK SESSION ─────────────────────────────────────────────
spark = SparkSession.builder \
    .appName("BTS_FlightDelayPrediction") \
    .config("spark.sql.shuffle.partitions", "200") \
    .config("spark.executor.memory", "4g") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")
print("✓ Spark session started:", spark.version)

# ── 2. LOAD CLEANED DATA ─────────────────────────────────────────
print("\n[2] Loading cleaned flight data...")
schema_cols = [
    "Year", "Quarter", "Month", "DayofMonth", "DayOfWeek",
    "FlightDate", "Marketing_Airline_Network", "Operating_Airline",
    "OriginAirportID", "Origin", "OriginCityName", "OriginState",
    "OriginAirportName", "DestAirportID", "Dest", "DestCityName",
    "DestState", "CRSDepTime", "DepDelay", "DepDelayMinutes",
    "DepDel15", "ArrDelay", "ArrDelayMinutes", "ArrDel15",
    "Cancelled", "CancellationCode", "Diverted",
    "CarrierDelay", "WeatherDelay", "NASDelay",
    "SecurityDelay", "LateAircraftDelay",
    "Distance", "DistanceGroup", "TaxiOut", "TaxiIn", "AirTime"
]

flights_raw = spark.read.option("sep", "|") \
                        .option("header", "false") \
                        .option("inferSchema", "true") \
                        .csv(DATA_PATH)

# Rename columns to match schema
for i, col in enumerate(schema_cols[:len(flights_raw.columns)]):
    flights_raw = flights_raw.withColumnRenamed(f"_c{i}", col)

# ── 3. FEATURE ENGINEERING ───────────────────────────────────────
print("[3] Feature engineering...")

flights = flights_raw.filter(
    (F.col("Cancelled") == 0) &           # exclude cancelled flights
    (F.col("Year").isNotNull()) &
    (F.col("ArrDel15").isNotNull())
)

# Derive hour-of-day feature (0-23)
flights = flights.withColumn(
    "DepHour", (F.col("CRSDepTime") / 100).cast(IntegerType())
)

# Is the flight departing in peak hours? (7-9am, 4-8pm)
flights = flights.withColumn(
    "IsPeakHour",
    F.when((F.col("DepHour").between(7, 9)) |
           (F.col("DepHour").between(16, 20)), 1).otherwise(0)
)

# Target variable: 1 = arrival delayed ≥15 min
flights = flights.withColumn(
    "IsDelayed", F.col("ArrDel15").cast(IntegerType())
)

# Drop rows where target is null
flights = flights.filter(F.col("IsDelayed").isNotNull())

total = flights.count()
delayed = flights.filter(F.col("IsDelayed") == 1).count()
print(f"  Total flights : {total:,}")
print(f"  Delayed (≥15m): {delayed:,} ({100*delayed/total:.1f}%)")
print(f"  On-time       : {total-delayed:,} ({100*(total-delayed)/total:.1f}%)")

# ── 4. PREPARE ML PIPELINE ───────────────────────────────────────
print("\n[4] Building ML pipeline...")

# Encode categorical carrier code
carrier_indexer = StringIndexer(
    inputCol="Marketing_Airline_Network",
    outputCol="CarrierIndex",
    handleInvalid="keep"
)

# Encode origin state
state_indexer = StringIndexer(
    inputCol="OriginState",
    outputCol="StateIndex",
    handleInvalid="keep"
)

FEATURE_COLS = [
    "Month",            # seasonality
    "DayOfWeek",        # day pattern
    "DayofMonth",       # day of month
    "DepHour",          # time of day
    "IsPeakHour",       # peak/off-peak binary
    "CarrierIndex",     # airline (encoded)
    "OriginAirportID",  # origin airport
    "DestAirportID",    # destination airport
    "StateIndex",       # origin state (encoded)
    "Distance",         # route distance
    "DistanceGroup",    # distance bucket
    "DepDelay",         # departure delay (strong predictor)
    "TaxiOut",          # gate to takeoff time
]

assembler = VectorAssembler(
    inputCols=FEATURE_COLS,
    outputCol="raw_features",
    handleInvalid="keep"
)

scaler = StandardScaler(
    inputCol="raw_features",
    outputCol="features",
    withMean=False, withStd=True
)

# ── 5. MODELS ────────────────────────────────────────────────────

# Model A: Random Forest
rf = RandomForestClassifier(
    labelCol="IsDelayed",
    featuresCol="features",
    numTrees=100,
    maxDepth=10,
    seed=SEED
)

# Model B: Gradient Boosted Trees (for comparison)
gbt = GBTClassifier(
    labelCol="IsDelayed",
    featuresCol="features",
    maxIter=50,
    seed=SEED
)

# ── 6. TRAIN / TEST SPLIT ────────────────────────────────────────
print("[5] Splitting data (80/20)...")
train, test = flights.randomSplit([0.8, 0.2], seed=SEED)
print(f"  Train: {train.count():,}  |  Test: {test.count():,}")

# ── 7. BUILD & FIT RF PIPELINE ───────────────────────────────────
print("[6] Training Random Forest...")
rf_pipeline = Pipeline(stages=[carrier_indexer, state_indexer, assembler, scaler, rf])
rf_model    = rf_pipeline.fit(train)
print("  ✓ Random Forest trained")

print("[6b] Training GBT...")
gbt_pipeline = Pipeline(stages=[carrier_indexer, state_indexer, assembler, scaler, gbt])
gbt_model    = gbt_pipeline.fit(train)
print("  ✓ GBT trained")

# ── 8. EVALUATE ──────────────────────────────────────────────────
print("\n[7] Evaluating models on test set...")

auc_evaluator  = BinaryClassificationEvaluator(labelCol="IsDelayed",
                                                metricName="areaUnderROC")
f1_evaluator   = MulticlassClassificationEvaluator(labelCol="IsDelayed",
                                                    predictionCol="prediction",
                                                    metricName="f1")
acc_evaluator  = MulticlassClassificationEvaluator(labelCol="IsDelayed",
                                                    predictionCol="prediction",
                                                    metricName="accuracy")
prec_evaluator = MulticlassClassificationEvaluator(labelCol="IsDelayed",
                                                    predictionCol="prediction",
                                                    metricName="weightedPrecision")

rf_preds  = rf_model.transform(test)
gbt_preds = gbt_model.transform(test)

results = {}
for name, preds in [("Random Forest", rf_preds), ("GBT", gbt_preds)]:
    results[name] = {
        "AUC-ROC"  : round(auc_evaluator.evaluate(preds), 4),
        "F1"       : round(f1_evaluator.evaluate(preds), 4),
        "Accuracy" : round(acc_evaluator.evaluate(preds), 4),
        "Precision": round(prec_evaluator.evaluate(preds), 4),
    }
    print(f"\n  {name}:")
    for k, v in results[name].items():
        print(f"    {k:12s}: {v}")

# Best model selection
best_model  = "Random Forest" if results["Random Forest"]["AUC-ROC"] >= results["GBT"]["AUC-ROC"] else "GBT"
best_preds  = rf_preds if best_model == "Random Forest" else gbt_preds
best_fitted = rf_model if best_model == "Random Forest" else gbt_model
print(f"\n  ★ Best model: {best_model} (AUC-ROC = {results[best_model]['AUC-ROC']})")

# ── 9. FEATURE IMPORTANCE ────────────────────────────────────────
print("\n[8] Computing feature importance...")
rf_stage = rf_model.stages[-1]
importances = rf_stage.featureImportances.toArray()
feat_df = pd.DataFrame({
    "Feature"   : FEATURE_COLS,
    "Importance": importances
}).sort_values("Importance", ascending=False)

print(feat_df.to_string(index=False))

# ── 10. PLOT: Feature Importance ────────────────────────────────
fig, ax = plt.subplots(figsize=(9, 6))
colors = ["#2196F3" if i == 0 else "#90CAF9" for i in range(len(feat_df))]
ax.barh(feat_df["Feature"][::-1], feat_df["Importance"][::-1], color=colors[::-1])
ax.set_xlabel("Importance Score", fontsize=12)
ax.set_title("Random Forest — Feature Importance\n(Flight Delay ≥15 min)", fontsize=13, fontweight="bold")
ax.axvline(0, color="black", linewidth=0.5)
for i, (imp, feat) in enumerate(zip(feat_df["Importance"][::-1], feat_df["Feature"][::-1])):
    ax.text(imp + 0.001, i, f"{imp:.3f}", va="center", fontsize=9)
plt.tight_layout()
plt.savefig(f"{OUTPUT_DIR}feature_importance.png", dpi=150, bbox_inches="tight")
plt.close()
print(f"  ✓ Saved: {OUTPUT_DIR}feature_importance.png")

# ── 11. CONFUSION MATRIX ─────────────────────────────────────────
cm_df = best_preds.groupBy("IsDelayed", "prediction").count().toPandas()
cm = pd.pivot_table(cm_df, values="count", index="IsDelayed",
                     columns="prediction", fill_value=0)
cm.columns = [f"Pred {int(c)}" for c in cm.columns]
cm.index   = [f"Actual {int(i)}" for i in cm.index]

fig, ax = plt.subplots(figsize=(6, 5))
sns.heatmap(cm, annot=True, fmt=",d", cmap="Blues",
            linewidths=0.5, ax=ax, cbar_kws={"label": "Count"})
ax.set_title(f"Confusion Matrix — {best_model}", fontsize=13, fontweight="bold")
ax.set_xlabel("Predicted Label")
ax.set_ylabel("True Label")
plt.tight_layout()
plt.savefig(f"{OUTPUT_DIR}confusion_matrix.png", dpi=150, bbox_inches="tight")
plt.close()
print(f"  ✓ Saved: {OUTPUT_DIR}confusion_matrix.png")

# ── 12. MODEL COMPARISON BAR CHART ───────────────────────────────
metrics = ["AUC-ROC", "F1", "Accuracy", "Precision"]
rf_vals  = [results["Random Forest"][m] for m in metrics]
gbt_vals = [results["GBT"][m] for m in metrics]

x = np.arange(len(metrics))
w = 0.35
fig, ax = plt.subplots(figsize=(9, 5))
bars1 = ax.bar(x - w/2, rf_vals,  w, label="Random Forest", color="#1976D2", alpha=0.85)
bars2 = ax.bar(x + w/2, gbt_vals, w, label="GBT",           color="#F57C00", alpha=0.85)
ax.set_xticks(x)
ax.set_xticklabels(metrics, fontsize=11)
ax.set_ylim(0, 1.05)
ax.set_ylabel("Score")
ax.set_title("Model Comparison: Random Forest vs GBT", fontsize=13, fontweight="bold")
ax.legend()
ax.axhline(0.8, color="gray", linestyle="--", linewidth=0.8, label="0.8 baseline")
for bar in list(bars1) + list(bars2):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01,
            f"{bar.get_height():.3f}", ha="center", va="bottom", fontsize=9)
plt.tight_layout()
plt.savefig(f"{OUTPUT_DIR}model_comparison.png", dpi=150, bbox_inches="tight")
plt.close()
print(f"  ✓ Saved: {OUTPUT_DIR}model_comparison.png")

# ── 13. SAVE PREDICTIONS SAMPLE ──────────────────────────────────
sample_preds = best_preds.select(
    "Origin", "Dest", "Marketing_Airline_Network",
    "DayOfWeek", "DepDelay", "IsDelayed", "prediction",
    F.round("probability", 4).alias("probability")
).limit(5000)

sample_preds.toPandas().to_csv(
    f"{OUTPUT_DIR}predictions_sample.csv", index=False
)
print(f"  ✓ Saved: {OUTPUT_DIR}predictions_sample.csv")

print("\n========== Spark ML complete ==========")
spark.stop()
