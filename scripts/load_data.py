from __future__ import annotations
import os
import pandas as pd
from pandas import Timestamp as PdTimestamp
import oracledb  # type: ignore[import]
from dotenv import load_dotenv
from pathlib import Path

load_dotenv()

DSN = f"{os.getenv('ORACLE_HOST')}:{os.getenv('ORACLE_PORT')}/{os.getenv('ORACLE_SERVICE')}"
RAW = Path(os.getenv('RAW_DIR', '../raw'))

def get_conn():
    return oracledb.connect(
        user=os.getenv('ORACLE_USER'),
        password=os.getenv('ORACLE_PASSWORD'),
        dsn=DSN
    )

# ─── helpers ──────────────────────────────────────────────────────────────────

def clean(val):
    """NaN → None so Oracle gets NULL"""
    if pd.isna(val):
        return None
    return val

def bulk_insert(cur, sql, rows, batch=1000):
    for i in range(0, len(rows), batch):
        cur.executemany(sql, rows[i:i+batch])
    print(f"  inserted {len(rows)} rows")

# ─── 1. DIM_CAMPUS ────────────────────────────────────────────────────────────

def load_campus(cur):
    print("Loading DIM_CAMPUS...")
    df = pd.read_csv(RAW / 'campus_meta.csv')
    rows = [(int(r.id), r['name'], int(r.capacity)) for _, r in df.iterrows()]
    bulk_insert(cur,
        "INSERT INTO QUERY_TUNING.DIM_CAMPUS (campus_id, campus_name, capacity) VALUES (:1,:2,:3)",
        rows)

# ─── 2. DIM_SOLAR_SITE ────────────────────────────────────────────────────────

def load_solar_site(cur):
    print("Loading DIM_SOLAR_SITE...")
    df = pd.read_csv(RAW / 'Solar_Site_Details.csv')
    df.columns = df.columns.str.strip().str.lower().str.replace(' ', '_')
    rows = []
    for _, r in df.iterrows():
        rows.append((
            int(r.sitekey), int(r.campuskey),
            clean(r.kwp), clean(r.number_of_panels),
            clean(r.get('panel')), clean(r.get('inverter')),
            clean(r.get('optimizers')), clean(r.get('metric')),
            float(r.lat), float(r.lon)
        ))
    # dedupe by site_id
    seen = set()
    unique = []
    for row in rows:
        if row[0] not in seen:
            seen.add(row[0])
            unique.append(row)
    bulk_insert(cur,
        "INSERT INTO QUERY_TUNING.DIM_SOLAR_SITE "
        "(site_id,campus_id,kwp,num_panels,panel,inverter,optimizers,metric,latitude,longitude) "
        "VALUES (:1,:2,:3,:4,:5,:6,:7,:8,:9,:10)",
        unique)

# ─── 3. DIM_DATE ──────────────────────────────────────────────────────────────

def load_date(cur):
    print("Loading DIM_DATE...")
    df = pd.read_csv(RAW / 'calender.csv', parse_dates=['date'])
    rows = []
    for _, r in df.iterrows():
        d: PdTimestamp = r['date']  # type: ignore[assignment]
        date_id = int(d.strftime('%Y%m%d'))
        rows.append((
            date_id, d.to_pydatetime().date(),
            d.day, d.month, d.year, d.quarter,
            int(r['is_holiday']) if r['is_holiday'] == r['is_holiday'] else 0,
            int(r['is_semester']),
            int(r['is_exam'])
        ))
    bulk_insert(cur,
        "INSERT INTO QUERY_TUNING.DIM_DATE "
        "(date_id,full_date,day_num,month_num,year_num,quarter_num,is_holiday,is_semester,is_exam) "
        "VALUES (:1,:2,:3,:4,:5,:6,:7,:8,:9)",
        rows)

# ─── 4. DIM_TIME ──────────────────────────────────────────────────────────────

def load_time(cur):
    print("Loading DIM_TIME...")
    # generate all 15-min slots in a day (matching solar data granularity)
    rows = []
    for h in range(24):
        for m in range(0, 60, 15):
            time_id = h * 100 + m
            rows.append((time_id, f"{h:02d}:{m:02d}", h, m))
    bulk_insert(cur,
        "INSERT INTO QUERY_TUNING.DIM_TIME (time_id,time_string,hour_num,minute_num) VALUES (:1,:2,:3,:4)",
        rows)

# ─── 5. FACT_SOLAR_ENERGY_GEN ─────────────────────────────────────────────────

def load_solar_gen(cur):
    print("Loading FACT_SOLAR_ENERGY_GEN (80MB — may take a while)...")
    df = pd.read_csv(RAW / 'Solar_Energy_Generation.csv',
                     parse_dates=['Timestamp'])
    rows = []
    for i, (_, r) in enumerate(df.iterrows(), start=1):
        ts: PdTimestamp = r['Timestamp']  # type: ignore[assignment]
        date_id = int(ts.strftime('%Y%m%d'))
        time_id = ts.hour * 100 + (ts.minute // 15) * 15
        rows.append((
            i, int(r['SiteKey']), date_id, time_id,
            ts.to_pydatetime(),
            clean(r['SolarGeneration']), 0
        ))
    bulk_insert(cur,
        "INSERT INTO QUERY_TUNING.FACT_SOLAR_ENERGY_GEN "
        "(gen_id,site_id,date_id,time_id,gen_timestamp,energy_generated_kwh,rolling_outlier_flag) "
        "VALUES (:1,:2,:3,:4,:5,:6,:7)",
        rows)

# ─── 6. FACT_WEATHER ──────────────────────────────────────────────────────────

def load_weather(cur):
    print("Loading FACT_WEATHER (78MB — may take a while)...")
    df = pd.read_csv(RAW / 'open_meteo_weather_raw_2020_2022.csv',
                     parse_dates=['timestamp'])
    # strip BOM from column names
    df.columns = df.columns.str.lstrip('﻿')
    rows = []
    for i, (_, r) in enumerate(df.iterrows(), start=1):
        ts: PdTimestamp = r['timestamp']  # type: ignore[assignment]
        date_id = int(ts.strftime('%Y%m%d'))
        time_id = ts.hour * 100 + (ts.minute // 15) * 15
        rows.append((
            i, int(r['SiteKey']), date_id, time_id, None,
            ts.to_pydatetime(),
            clean(r['shortwave_radiation']), clean(r['direct_radiation']),
            clean(r['diffuse_radiation']), clean(r['temperature_2m']),
            int(r['is_day']),
            clean(r['cloud_cover']), clean(r['cloud_cover_low']),
            clean(r['cloud_cover_mid']), clean(r['cloud_cover_high']),
            clean(r['wind_speed_10m']), clean(r['precipitation']),
            clean(r['sunshine_duration'])
        ))
    bulk_insert(cur,
        "INSERT INTO QUERY_TUNING.FACT_WEATHER "
        "(weather_id,site_id,date_id,time_id,weather_type_id,weather_timestamp,"
        "shortwave_radiation,direct_radiation,diffuse_radiation,temperature_c,"
        "is_day,cloud_cover_total,cloud_cover_low,cloud_cover_mid,cloud_cover_high,"
        "wind_speed,precipitation_mm,sunshine_duration) "
        "VALUES (:1,:2,:3,:4,:5,:6,:7,:8,:9,:10,:11,:12,:13,:14,:15,:16,:17,:18)",
        rows)

# ─── MAIN ─────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    conn = get_conn()
    cur = conn.cursor()
    cur.setinputsizes(None)  # let oracledb infer types

    try:
        load_campus(cur)
        load_solar_site(cur)
        load_date(cur)
        load_time(cur)
        load_solar_gen(cur)
        load_weather(cur)
        conn.commit()
        print("\nDone! All data loaded.")
    except Exception as e:
        conn.rollback()
        print(f"Error: {e}")
        raise
    finally:
        cur.close()
        conn.close()
