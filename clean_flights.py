"""
=============================================================
BTS Flight Delay Analysis
Script: clean_flights.py
Purpose: Clean raw BTS quoted CSV and output pipe-separated file
Author: [Your Name]
Date: December 2025
=============================================================
Usage:
    python clean_flights.py

Input:
    /home/maria_dev/flight_data/On_Time_Marketing_2025_12.csv
    - 644,987 rows
    - 120 columns
    - Quoted CSV format with commas inside city names

Output:
    /home/maria_dev/flight_data/On_Time_Clean.csv
    - 644,987 rows
    - 34 selected columns
    - Pipe-separated (avoids comma conflicts in city names)
    - No header row
    - NULL/empty/NA replaced with 0

Column Index Reference (from BTS header):
    0=Year, 1=Quarter, 2=Month, 3=DayofMonth, 4=DayOfWeek
    5=FlightDate, 6=Marketing_Airline_Network
    15=Operating_Airline, 20=OriginAirportID
    23=Origin, 24=OriginCityName, 25=OriginState
    29=DestAirportID, 32=Dest, 33=DestCityName, 34=DestState
    38=CRSDepTime, 40=DepDelay, 51=ArrDelay
    42=DepDel15, 53=ArrDel15, 56=Cancelled
    57=CancellationCode, 58=Diverted
    65=CarrierDelay, 66=WeatherDelay, 67=NASDelay
    68=SecurityDelay, 69=LateAircraftDelay
    63=Distance, 64=DistanceGroup
    45=TaxiOut, 48=TaxiIn, 61=AirTime
    118=Duplicate flag
=============================================================
"""

import csv

input_file  = '/home/maria_dev/flight_data/On_Time_Marketing_2025_12.csv'
output_file = '/home/maria_dev/flight_data/On_Time_Clean.csv'

print("=" * 50)
print("BTS Flight Data Cleaning Script")
print("=" * 50)
print("Input:  " + input_file)
print("Output: " + output_file)
print("Starting...")

count   = 0
skipped = 0

with open(input_file, 'rb') as fin, \
     open(output_file, 'wb') as fout:

    reader = csv.reader(fin)
    header = next(reader)
    print("Header columns found: " + str(len(header)))

    for row in reader:

        # Skip rows with unexpected column count
        if len(row) != 120:
            skipped += 1
            continue

        # Skip duplicate records (Duplicate flag = 'Y' at index 118)
        if row[118].strip() == 'Y':
            skipped += 1
            continue

        # Helper functions
        def clean_num(val):
            """Replace empty/NA values with 0 for numeric fields."""
            v = val.strip()
            if v == '' or v == 'NA':
                return '0'
            return v

        def clean_str(val):
            """Strip whitespace from string fields."""
            return val.strip()

        def clean_code(val):
            """Replace empty cancellation codes with NONE."""
            v = val.strip()
            if v == '':
                return 'NONE'
            return v

        # Build output row with 34 selected columns
        out = [
            clean_num(row[0]),    # Year
            clean_num(row[1]),    # Quarter
            clean_num(row[2]),    # Month
            clean_num(row[3]),    # DayofMonth
            clean_num(row[4]),    # DayOfWeek
            clean_str(row[5]),    # FlightDate
            clean_str(row[6]),    # Marketing_Airline_Network
            clean_str(row[15]),   # Operating_Airline
            clean_num(row[20]),   # OriginAirportID
            clean_str(row[23]),   # Origin
            clean_str(row[24]),   # OriginCityName
            clean_str(row[25]),   # OriginState
            clean_num(row[29]),   # DestAirportID
            clean_str(row[32]),   # Dest
            clean_str(row[33]),   # DestCityName
            clean_str(row[34]),   # DestState
            clean_num(row[38]),   # CRSDepTime
            clean_num(row[40]),   # DepDelay
            clean_num(row[51]),   # ArrDelay
            clean_num(row[42]),   # DepDel15
            clean_num(row[53]),   # ArrDel15
            clean_num(row[56]),   # Cancelled
            clean_code(row[57]),  # CancellationCode
            clean_num(row[58]),   # Diverted
            clean_num(row[65]),   # CarrierDelay
            clean_num(row[66]),   # WeatherDelay
            clean_num(row[67]),   # NASDelay
            clean_num(row[68]),   # SecurityDelay
            clean_num(row[69]),   # LateAircraftDelay
            clean_num(row[63]),   # Distance
            clean_num(row[64]),   # DistanceGroup
            clean_num(row[45]),   # TaxiOut
            clean_num(row[48]),   # TaxiIn
            clean_num(row[61]),   # AirTime
        ]

        # Write pipe-separated row
        fout.write('|'.join(out) + '\n')
        count += 1

        if count % 100000 == 0:
            print("  Processed " + str(count) + " rows...")

print("=" * 50)
print("Done!")
print("Rows written:  " + str(count))
print("Rows skipped:  " + str(skipped))
print("=" * 50)
print("Next step: upload to HDFS")
print("  hdfs dfs -put " + output_file + " /user/maria_dev/flight_data/cleaned/")
