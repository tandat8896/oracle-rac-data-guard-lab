from __future__ import annotations
import os
import pandas as pd
import oracledb  # type: ignore[import]
from dotenv import load_dotenv
from pathlib import Path

load_dotenv()

DSN = f"{os.getenv('ORACLE_HOST')}:{os.getenv('ORACLE_PORT')}/{os.getenv('ORACLE_SERVICE')}"
RAW = Path(os.getenv('RAW_DIR', '../raw'))

WMO_DESC: dict[int, tuple[str, str]] = {
    0:  ("Clear sky",                      "No clouds"),
    1:  ("Mainly clear",                   "Sky is mainly clear"),
    2:  ("Partly cloudy",                  "Some clouds present"),
    3:  ("Overcast",                       "Completely cloudy"),
    45: ("Fog",                            "Visibility reduced by fog"),
    48: ("Rime fog",                       "Freezing fog depositing rime"),
    51: ("Light drizzle",                  "Light intermittent drizzle"),
    53: ("Moderate drizzle",               "Moderate drizzle"),
    55: ("Dense drizzle",                  "Dense drizzle"),
    61: ("Slight rain",                    "Slight rain"),
    63: ("Moderate rain",                  "Moderate rain"),
    65: ("Heavy rain",                     "Heavy rain"),
    71: ("Slight snow",                    "Slight snowfall"),
    73: ("Moderate snow",                  "Moderate snowfall"),
    75: ("Heavy snow",                     "Heavy snowfall"),
    77: ("Snow grains",                    "Snow grains"),
    80: ("Slight rain showers",            "Slight rain showers"),
    81: ("Moderate rain showers",          "Moderate rain showers"),
    82: ("Violent rain showers",           "Violent rain showers"),
    85: ("Slight snow showers",            "Slight snow showers"),
    86: ("Heavy snow showers",             "Heavy snow showers"),
    95: ("Thunderstorm",                   "Thunderstorm without hail"),
    96: ("Thunderstorm + slight hail",     "Thunderstorm with slight hail"),
    99: ("Thunderstorm + heavy hail",      "Thunderstorm with heavy hail"),
}

def get_conn():
    return oracledb.connect(
        user=os.getenv('ORACLE_USER'),
        password=os.getenv('ORACLE_PASSWORD'),
        dsn=DSN
    )

def load_weather_type(cur) -> dict[tuple[int, int], int]:
    print("Loading DIM_WEATHER_TYPE...")
    df = pd.read_csv(RAW / 'open_meteo_weather_raw_2020_2022.csv',
                     usecols=['weather_code', 'is_day'])
    df.columns = df.columns.str.lstrip('﻿')

    combos = df[['weather_code', 'is_day']].drop_duplicates().sort_values(['weather_code', 'is_day'])

    rows = []
    lookup: dict[tuple[int, int], int] = {}
    for wtype_id, (_, r) in enumerate(combos.iterrows(), start=1):
        code = int(r['weather_code'])
        is_day = int(r['is_day'])
        condition, desc = WMO_DESC.get(code, (f"Code {code}", "Unknown weather code"))
        label = f"{condition} ({'Day' if is_day else 'Night'})"
        rows.append((wtype_id, code, is_day, label, desc))
        lookup[(code, is_day)] = wtype_id

    cur.executemany(
        "INSERT INTO QUERY_TUNING.DIM_WEATHER_TYPE "
        "(weather_type_id,weather_code,is_day,weather_condition,description) "
        "VALUES (:1,:2,:3,:4,:5)",
        rows
    )
    print(f"  inserted {len(rows)} weather types")
    return lookup

def update_fact_weather(cur, lookup: dict[tuple[int, int], int]):
    print("Updating FACT_WEATHER.weather_type_id...")
    df = pd.read_csv(RAW / 'open_meteo_weather_raw_2020_2022.csv',
                     usecols=['weather_code', 'is_day'])
    df.columns = df.columns.str.lstrip('﻿')

    rows = []
    for weather_id, (_, r) in enumerate(df.iterrows(), start=1):
        wtype_id = lookup.get((int(r['weather_code']), int(r['is_day'])))
        rows.append((wtype_id, weather_id))

    batch = 5000
    for i in range(0, len(rows), batch):
        cur.executemany(
            "UPDATE QUERY_TUNING.FACT_WEATHER SET weather_type_id=:1 WHERE weather_id=:2",
            rows[i:i+batch]
        )
    print(f"  updated {len(rows)} rows")

if __name__ == '__main__':
    conn = get_conn()
    cur = conn.cursor()
    try:
        lookup = load_weather_type(cur)
        update_fact_weather(cur, lookup)
        conn.commit()
        print("\nDone!")
    except Exception as e:
        conn.rollback()
        print(f"Error: {e}")
        raise
    finally:
        cur.close()
        conn.close()
