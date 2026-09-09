# Lesson 16: Khám Phá Dữ Liệu Solar Energy

Schema Solar gồm 7 tables: 5 dimension + 2 fact.
Dữ liệu energy generation 2,731,946 rows.

Mỗi câu hỏi bên dưới trả lời 1 vấn đề cụ thể trước khi build forecast model.

---

## 1. Phạm Vi Thời Gian

**Câu hỏi:** Data bắt đầu từ khi nào? Kết thúc khi nào? Có bao nhiêu dòng?

**Tại sao cần biết?**
- Biết khoảng time có sẵn → xác định train period, validation period, test period
- Dữ liệu < 1 năm → không đủ 1 chu kỳ seasonality → không thể học annual pattern → phải dùng external data hoặc model đơn giản hơn
- Biết tổng số dòng → ước lượng dung lượng lưu trữ, cost query, thời gian train
- Phát hiện data gần đây nhất là khi nào → có cần chờ thêm data không

**Query:**
```sql
SELECT MIN(GEN_TIMESTAMP), MAX(GEN_TIMESTAMP), COUNT(*)
FROM FACT_SOLAR_ENERGY_GEN;
```

**Raw output:**
```
MIN_TS                            MAX_TS
01-JAN-20 12.15.00.000000000 AM   23-APR-22 11.45.00.000000000 PM
-- COUNT(*) = 2,731,946 (chạy sau)
```

---

## 2. Granularity

**Câu hỏi:** Dữ liệu ghi cách nhau bao nhiêu phút? Có đều không?

**Tại sao cần biết?**
- Forecast daily aggregate → cần biết data gốc là 5p, 15p, hay 1h để quyết định resampling strategy
- Nếu gap không đều (có lúc 5p, có lúc 10p) → cần resample về interval cố định trước khi feature engineering
- Biết granularity để chọn window size: nếu gap 5p thì window=12 tương ứng 1 tiếng, window=288 tương ứng 1 ngày
- Nếu có multiple sites với granularity khác nhau → phải đồng bộ về cùng interval

**Query:**
```sql
SELECT gen_timestamp, next_ts,
       ROUND((CAST(next_ts AS DATE) - CAST(gen_timestamp AS DATE)) * 24 * 60, 2) AS gap_minutes
FROM (
  SELECT gen_timestamp,
         LEAD(gen_timestamp) OVER (PARTITION BY site_id ORDER BY gen_timestamp) AS next_ts
  FROM FACT_SOLAR_ENERGY_GEN
  WHERE site_id = (SELECT MIN(site_id) FROM FACT_SOLAR_ENERGY_GEN)
)
WHERE ROWNUM <= 30
ORDER BY gen_timestamp;
```

**Giải thích query (3 lớp subquery):**

```
L3 (ngoài cùng): SELECT * WHERE gap_minutes > 15 ORDER BY gap_minutes DESC
                           ↑ lấy từ L2
L2 (giữa):       SELECT ..., CAST(next_ts - gen_timestamp) * 24 * 60 AS gap_minutes
                           ↑ next_ts từ L1
L1 (trong cùng): SELECT gen_timestamp, LEAD(gen_timestamp) OVER (...) AS next_ts
                           ↑ chỉ 1 site
```

**Công thức từng bước:**

| Bước | Công thức | Ý nghĩa |
|---|---|---|
| 1 | `LEAD(gen_timestamp) OVER (PARTITION BY site_id ORDER BY gen_timestamp)` | Lấy timestamp của dòng kế tiếp → cột `next_ts` |
| 2 | `next_ts - gen_timestamp` | Hiệu 2 timestamp → số ngày (VD: 0.010416) |
| 3 | `(next_ts - gen_timestamp) × 24 × 60` | Đổi ngày → phút (VD: 0.010416 × 24 × 60 = 15) |
| 4 | `CAST(... AS DATE)` | Bắt buộc vì TIMESTAMP trừ nhau ra INTERVAL không nhân được với số |

**Tại sao cần 3 lớp?** Vì Oracle không dùng được alias `gap_minutes` trong WHERE cùng cấp — phải SELECT thêm 1 lớp bọc ngoài để filter.

**Plan:**
```
--------------------------------------------------------------------------------------------
| Id  | Operation                       | Name                     | Rows  | Cost          |
--------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                |                          |    30 |   7           |
|   1 |  SORT ORDER BY                  |                          |    30 |   7           |
|*  2 |   COUNT STOPKEY                 |                          |       |               |
|   3 |    VIEW                         |                          |    31 |   6           |
|   4 |     WINDOW BUFFER               |                          |    31 |   6           |
|*  5 |      INDEX RANGE SCAN           | IDX_FACT_SOLAR_SITE_TIME |    31 |   3           |
|   6 |       SORT AGGREGATE            |                          |     1 |               |
|   7 |        INDEX FULL SCAN (MIN/MAX)| IDX_FACT_SOLAR_SITE_TIME |     1 |   3           |
--------------------------------------------------------------------------------------------
```
- Id 7: INDEX MIN/MAX lấy MIN site_id (cost 3) — nhờ IDX_FACT_SOLAR_SITE_TIME
- Id 5: INDEX RANGE SCAN trên composite index (site_id, timestamp) — cost chỉ 3
- Tổng cộng cost 7 — rất nhanh

**Raw output (30 dòng đầu, site nhỏ nhất):**
```
GEN_TIMESTAMP                   NEXT_TS                       GAP_MINUTES
01-JAN-20 12.15.00.000 AM      01-JAN-20 12.30.00.000 AM             15
01-JAN-20 12.30.00.000 AM      01-JAN-20 12.45.00.000 AM             15
01-JAN-20 12.45.00.000 AM      01-JAN-20 01.00.00.000 AM             15
01-JAN-20 01.00.00.000 AM      01-JAN-20 01.15.00.000 AM             15
... (tất cả gap = 15 phút, 30 dòng)
```

**Kết luận:** Granularity cơ bản = **15 phút**. Nhưng có 15 khoảng gap > 15 phút.

**Raw output — tất cả gap > 15 phút (1 site):**
```
GEN_TIMESTAMP                   NEXT_TS                       GAP_MINUTES
01-OCT-20 12.00.00.000 AM      05-OCT-20 12.15.00.000 AM          5775  ← ~4 ngày
25-DEC-20 09.30.00.000 PM      28-DEC-20 12.15.00.000 AM          3045  ← ~2 ngày
27-SEP-20 10.45.00.000 PM      30-SEP-20 12.15.00.000 AM          2970  ← ~2 ngày
10-AUG-21 08.15.00.000 AM      12-AUG-21 12.15.00.000 AM          2400  ← ~1.7 ngày
26-NOV-21 05.00.00.000 PM      28-NOV-21 12.15.00.000 AM          1875  ← ~1.3 ngày
24-JUL-20 05.45.00.000 PM      26-JUL-20 12.15.00.000 AM          1830  ← ~1.3 ngày
23-FEB-21 08.45.00.000 PM      25-FEB-21 12.15.00.000 AM          1650  ← ~1.1 ngày
09-JUL-21 09.15.00.000 PM      11-JUL-21 12.15.00.000 AM          1620  ← ~1.1 ngày
04-JUL-20 04.00.00.000 AM      05-JUL-20 02.00.00.000 AM          1320  ← ~22 giờ
19-FEB-21 04.45.00.000 AM      20-FEB-21 12.15.00.000 AM          1170  ← ~19.5 giờ
09-APR-21 12.00.00.000 PM      10-APR-21 12.15.00.000 AM           735  ← ~12 giờ
07-APR-21 01.00.00.000 PM      08-APR-21 12.15.00.000 AM           675  ← ~11 giờ
17-SEP-20 07.30.00.000 AM      17-SEP-20 04.30.00.000 PM           540  ← ~9 giờ
31-MAR-21 10.30.00.000 PM      01-APR-21 12.15.00.000 AM           105  ← ~1.75 giờ
03-OCT-21 02.00.00.000 AM      03-OCT-21 03.15.00.000 AM            75  ← 5 interval
```
Đa số gap dài >1 ngày — downtime/sensor hỏng hơn là irregular sampling.
Chỉ 1 gap 75 phút (mất 5 interval) và 1 gap 105 phút (mất 7 interval) là đáng ngờ.

**Fix SORT ORDER BY — bỏ ORDER BY:**
- Với `ORDER BY gap_minutes DESC`: `SORT ORDER BY` + TempSpc 2312K, cost 700
- Bỏ `ORDER BY`: **không SORT, TempSpc = 0**, cost giảm còn 216
- Nếu chỉ cần biết "có gap không" → không cần ORDER BY

**Tại sao không index được gap_minutes?**
- `gap_minutes` là cột **computed** (từ LEAD + CAST + ROUND)
- Oracle chỉ index cột vật lý trong table
- Muốn index → phải precompute gap vào table vật lý → **nợ ETL maintain**
- Đây là bản chất của analytical function: kết quả không index được

---

## 3. Missing Timestamps

**Câu hỏi:** Có ngày nào bị thiếu dữ liệu không? Bao nhiêu %?

**Tại sao cần biết?**
- Model không học được từ data bị missing → phải xử lý trước
- Gap ngắn (1-2 interval) → có thể fill forward (lấy giá trị trước đó)
- Gap dài (nhiều giờ/ngày) → cần investigation: sensor hỏng? downtime? bảo trì?
- Nếu missing > 10% tổng số dòng → model quality sẽ kém đáng kể → cần cân nhắc có nên dùng model không
- Pattern missing có tính chu kỳ không (vd: ban đêm không ghi?) → ảnh hưởng đến feature engineering

**Query:**
```sql
-- % missing dates per site
SELECT d.date_id, COUNT(f.date_id) AS has_data
FROM DIM_DATE d
LEFT JOIN FACT_SOLAR_ENERGY_GEN f ON f.date_id = d.date_id
GROUP BY d.date_id
HAVING COUNT(f.date_id) = 0;

**Kiểm tra gap 4 ngày — site-specific hay global:**
```sql
SELECT g.SITE_ID, MIN(g.GEN_TIMESTAMP) AS first_ts, MAX(g.GEN_TIMESTAMP) AS last_ts, COUNT(*) AS total_rows FROM FACT_SOLAR_ENERGY_GEN g WHERE g.GEN_TIMESTAMP BETWEEN DATE '2020-10-01' AND DATE '2020-10-10' GROUP BY g.SITE_ID ORDER BY g.SITE_ID;
```
```

---

## 4. Time Zone

**Câu hỏi:** Timestamp lưu UTC hay local? Các site có cùng time zone không?

**Tại sao cần biết?**
- Feature "hour of day" dựa vào UTC sẽ sai lệch so với giờ mặt trời thực tế
- Nếu site ở Vietnam (UTC+7), site ở US (UTC-5) → timestamp UTC nhưng local time khác nhau → không thể so sánh sản lượng theo giờ trực tiếp
- Daily aggregation sai time zone → daily_kwh bị lệch do cắt ngày sai
- Solar forecast phụ thuộc vào giờ mặt trời mọc/lặn → cần convert về local time hoặc solar time

**Query — kiểm tra time zone:**
```sql
SELECT g.SITE_ID, g.GEN_TIMESTAMP, EXTRACT(HOUR FROM g.GEN_TIMESTAMP) AS utc_hour, ROUND(s.LONGITUDE / 15) AS tz_offset FROM FACT_SOLAR_ENERGY_GEN g JOIN DIM_SOLAR_SITE s ON s.SITE_ID = g.SITE_ID WHERE ROWNUM <= 10;
```

**Query — phát hiện time shift (so sánh peak mùa hè vs mùa đông):**
```sql
SELECT s.SITE_ID, ROUND(AVG(CASE WHEN d.MONTH_NUM IN (11,12,1,2) THEN g.ENERGY_GENERATED_KWH END), 4) AS avg_summer, ROUND(AVG(CASE WHEN d.MONTH_NUM IN (5,6,7,8) THEN g.ENERGY_GENERATED_KWH END), 4) AS avg_winter, COUNT(*) AS samples FROM FACT_SOLAR_ENERGY_GEN g JOIN DIM_DATE d ON d.DATE_ID = g.DATE_ID JOIN DIM_SOLAR_SITE s ON s.SITE_ID = g.SITE_ID WHERE EXTRACT(HOUR FROM g.GEN_TIMESTAMP) = 11 GROUP BY s.SITE_ID ORDER BY s.SITE_ID;
```
Nếu summer peak khác winter peak → DST bug (time shift theo mùa).
Nếu peak không đúng giữa trưa (11h-13h local) → time zone sai.

**Tối ưu cách 1: Function-based index:**
```sql
-- Covering index tối ưu (tránh TABLE ACCESS):
DROP INDEX IDX_GEN_HOUR_ENERGY;
CREATE INDEX idx_gen_hour_full ON FACT_SOLAR_ENERGY_GEN(EXTRACT(HOUR FROM GEN_TIMESTAMP), DATE_ID, ENERGY_GENERATED_KWH, SITE_ID);
-- Sau đó verify plan:
explain plan for SELECT s.SITE_ID, ROUND(AVG(CASE WHEN d.MONTH_NUM IN (11,12,1,2) THEN g.ENERGY_GENERATED_KWH END), 4) AS avg_summer, ROUND(AVG(CASE WHEN d.MONTH_NUM IN (5,6,7,8) THEN g.ENERGY_GENERATED_KWH END), 4) AS avg_winter, COUNT(*) AS samples FROM FACT_SOLAR_ENERGY_GEN g JOIN DIM_DATE d ON d.DATE_ID = g.DATE_ID JOIN DIM_SOLAR_SITE s ON s.SITE_ID = g.SITE_ID WHERE EXTRACT(HOUR FROM g.GEN_TIMESTAMP) = 11 GROUP BY s.SITE_ID ORDER BY s.SITE_ID;
-- Kết quả: cost giảm từ 3946 → 48
-- Giải thích: INDEX chứa đủ (hour, date_id, energy, site_id) → INDEX RANGE SCAN filter hour=11, đọc thẳng energy và site_id, không cần TABLE ACCESS BY INDEX ROWID. Chỉ còn HASH JOIN với DIM_DATE (27K rows) rồi SORT GROUP BY 42 rows — cost rất thấp.
```

**Tối ưu cách 2: dùng DIM_TIME thay EXTRACT (tránh FULL TABLE SCAN):**
```sql
SELECT s.SITE_ID, ROUND(AVG(CASE WHEN d.MONTH_NUM IN (11,12,1,2) THEN g.ENERGY_GENERATED_KWH END), 4) AS avg_summer, ROUND(AVG(CASE WHEN d.MONTH_NUM IN (5,6,7,8) THEN g.ENERGY_GENERATED_KWH END), 4) AS avg_winter, COUNT(*) AS samples FROM FACT_SOLAR_ENERGY_GEN g JOIN DIM_DATE d ON d.DATE_ID = g.DATE_ID JOIN DIM_SOLAR_SITE s ON s.SITE_ID = g.SITE_ID JOIN DIM_TIME t ON t.TIME_ID = g.TIME_ID AND t.HOUR_NUM = 11 GROUP BY s.SITE_ID ORDER BY s.SITE_ID;
```

**Phát hiện time shift — join FACT_WEATHER vs FACT_SOLAR_ENERGY_GEN:**
```sql
explain plan for SELECT EXTRACT(HOUR FROM g.GEN_TIMESTAMP) AS hour_utc, ROUND(AVG(g.ENERGY_GENERATED_KWH), 4) AS avg_energy, ROUND(AVG(w.SHORTWAVE_RADIATION), 2) AS avg_radiation, COUNT(*) AS samples FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND w.TIME_ID = g.TIME_ID WHERE g.SITE_ID = 1 GROUP BY EXTRACT(HOUR FROM g.GEN_TIMESTAMP) ORDER BY hour_utc;
```
Nếu giờ nào avg_radiation cao mà avg_energy = 0 → time zone mismatch (weather local time, energy UTC).

**Raw output — site 1:**
```
HOUR_UTC | AVG_ENERGY | AVG_RADIATION | SAMPLES
0        | 0          | 0             | 818
6        | 0.13       | 0             | 829
7        | 1.03       | 13.84         | 829
8        | 3.08       | 94.04         | 828
12       | 14.0       | 589.92        | 827  ← peak energy
13       | 13.69      | 622.54        | 826  ← peak radiation
14       | 12.98      | 609.55        | 825
20       | 0.58       | 28.77         | 824
21       | 0          | 1.15          | 823
22       | 0          | 0             | 821
```  
**Kết luận:** Energy và radiation chạy đồng bộ → không có time zone shift giữa FACT_WEATHER và FACT_SOLAR_ENERGY_GEN. Peak lúc HOUR = 12-14 (giữa trưa) → **GEN_TIMESTAMP là local time** (không phải UTC). Không cần convert time zone cho forecast.

**Kiểm tra time zone cụ thể từ DIM_TIME:**
```sql
SELECT w.DATE_ID, w.TIME_ID, t.HOUR_NUM, t.MINUTE_NUM, g.DATE_ID, g.TIME_ID, g.GEN_TIMESTAMP FROM FACT_WEATHER w JOIN FACT_SOLAR_ENERGY_GEN g ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND w.TIME_ID = g.TIME_ID JOIN DIM_TIME t ON t.TIME_ID = w.TIME_ID WHERE g.SITE_ID = 1 AND ROWNUM <= 10;
-- Kết quả: GEN_TIMESTAMP 04:00 = HOUR_NUM 4 → timestamp là local time, FACT_WEATHER và FACT_SOLAR_ENERGY_GEN đồng bộ, không time shift.
```

---

## 5. Outlier

**Câu hỏi:** Có giá trị bất thường không? ROLLING_OUTLIER_FLAG đã đánh dấu được chưa?

**Tại sao cần biết?**
- Outlier làm lệch lag features, rolling mean, rolling std → model học sai pattern
- Energy = 0 ban đêm là bình thường, energy = 0 ban ngày → bất thường (sensor hỏng hoặc bảo trì)
- Cần quyết định chiến lược: drop outliers? replace bằng median của N ngày trước? clip theo percentile?
- Nếu outlier > 5% → có vấn đề về data quality, cần investigation trước

**Query:**
```sql
SELECT month, total_rows, outlier_count,
       ROUND(outlier_count / total_rows * 100, 2) AS outlier_pct
FROM (
  SELECT TO_CHAR(GEN_TIMESTAMP, 'YYYY-MM') AS month,
         COUNT(*) AS total_rows,
         SUM(CASE WHEN ROLLING_OUTLIER_FLAG = 1 THEN 1 ELSE 0 END) AS outlier_count
  FROM FACT_SOLAR_ENERGY_GEN
  GROUP BY TO_CHAR(GEN_TIMESTAMP, 'YYYY-MM')
)
ORDER BY month;
```

---

## 6. Join Fact_Weather

**Câu hỏi:** Weather data có overlap time với energy data không? JOIN được bao nhiêu %?

**Tại sao cần biết?**
- Radiation (SHORTWAVE_RADIATION) là feature quan trọng nhất cho solar forecast — không có radiation thì không thể predict chính xác
- Nếu JOIN match < 80% → phải quyết định: fill missing weather features (interpolation, ERA5 data) hoặc bỏ weather feature khỏi model
- Nếu weather bị gap mà energy có → gap đó không thể dùng weather feature → phải có fallback strategy
- Nếu weather và energy không cùng granularity → cần aggregation trước khi join

**Query:**
```sql
SELECT COUNT(*) AS total_energy_rows,
       COUNT(w.date_id) AS matched_weather,
       ROUND(COUNT(w.date_id) / COUNT(*) * 100, 2) AS match_pct
FROM FACT_SOLAR_ENERGY_GEN g
LEFT JOIN FACT_WEATHER w
  ON w.SITE_ID = g.SITE_ID
  AND w.DATE_ID = g.DATE_ID
  AND w.TIME_ID = g.TIME_ID;

**Kết quả & giải thích:**
- Match theo TIME_ID: **25%** — weather 1h, energy 15p, chỉ match 1/4
- Match theo DATE_ID (bỏ TIME_ID): **100%** — cùng ngày là match
- Trong ML: upscale weather lên 15p (interpolation) hoặc aggregate energy xuống 1h

```sql
-- Match theo ngày (100%):
SELECT COUNT(*) AS total_rows, COUNT(w.date_id) AS matched_date, ROUND(COUNT(w.date_id) / COUNT(*) * 100, 2) AS pct FROM FACT_SOLAR_ENERGY_GEN g LEFT JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID;
```

**Kiểm tra correlation shift +1h (weather ảnh hưởng trễ):**
```sql
-- Không shift: CORR = 0.79
SELECT CORR(g.ENERGY_GENERATED_KWH, w.SHORTWAVE_RADIATION) AS corr_no_shift FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND FLOOR(w.TIME_ID / 100) = FLOOR(g.TIME_ID / 100) WHERE g.SITE_ID = 1;
```
```sql
-- Shift +1h: CORR = 0.83
SELECT CORR(g.ENERGY_GENERATED_KWH, w.SHORTWAVE_RADIATION) AS corr_shift_1h FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND FLOOR(w.TIME_ID / 100) = FLOOR(g.TIME_ID / 100) - 1 WHERE g.SITE_ID = 1;
```

**Kiểm tra correlation 42 sites — không shift vs shift ±1h:**
```sql
SELECT g.SITE_ID, CORR(g.ENERGY_GENERATED_KWH, w.SHORTWAVE_RADIATION) AS corr_0h FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND FLOOR(w.TIME_ID / 100) = FLOOR(g.TIME_ID / 100) GROUP BY g.SITE_ID ORDER BY g.SITE_ID;
```

---

## 7. Số Site

**Câu hỏi:** Có bao nhiêu site? Site nào nhiều data nhất? Site nào ít nhất?

**Tại sao cần biết?**
- Mỗi site có thể có performance khác nhau (hướng panel, góc nghiêng, bóng che) → cần model riêng hoặc global model
- Site có ít data (< 1 năm) → không đủ train riêng → phải dùng global model (train chung nhiều site) hoặc transfer learning
- Site có KWP khác nhau → daily_kwh không so sánh trực tiếp được → cần specific yield (kWh/kWp)
- Nếu 1 site chiếm > 80% dữ liệu → model sẽ biased toward site đó

**Query:**
```sql
SELECT g.SITE_ID, s.KWP,
       COUNT(*) AS row_count,
       MIN(GEN_TIMESTAMP) AS first_ts,
       MAX(GEN_TIMESTAMP) AS last_ts
FROM FACT_SOLAR_ENERGY_GEN g
JOIN DIM_SOLAR_SITE s ON s.SITE_ID = g.SITE_ID
GROUP BY g.SITE_ID, s.KWP
ORDER BY row_count DESC;
```

---

## 8. IS_DAY vs Radiation

**Câu hỏi:** Có dòng nào IS_DAY = 0 mà radiation > 0 không? Có dòng IS_DAY = 1 mà radiation = 0 không?

**Tại sao cần biết?**
- Phát hiện sensor lỗi: nếu sai nhiều ( > 1%) → cần sửa hoặc drop những dòng đó
- Radiation = 0 ban ngày → sensor bẩn, bị che bóng, hoặc hỏng → model sẽ học sai: trời tối nhưng thực tế sáng
- Nếu IS_DAY sai → feature "day/night" sẽ nhiễu → model có thể predict energy ban đêm (vô lý)
- Quyết định: drop dòng lỗi, sửa IS_DAY dựa trên radiation threshold, hay sửa radiation dựa trên interpolation?

**Query:**
```sql
SELECT CASE
         WHEN IS_DAY = 0 AND SHORTWAVE_RADIATION > 0 THEN 'IS_DAY=0 but radiation>0'
         WHEN IS_DAY = 1 AND SHORTWAVE_RADIATION = 0 THEN 'IS_DAY=1 but radiation=0'
       END AS anomaly_type,
       COUNT(*) AS count,
       ROUND(COUNT(*) / (SELECT COUNT(*) FROM FACT_WEATHER) * 100, 4) AS pct
FROM FACT_WEATHER
WHERE (IS_DAY = 0 AND SHORTWAVE_RADIATION > 0)
   OR (IS_DAY = 1 AND SHORTWAVE_RADIATION = 0)
GROUP BY CASE
           WHEN IS_DAY = 0 AND SHORTWAVE_RADIATION > 0 THEN 'IS_DAY=0 but radiation>0'
           WHEN IS_DAY = 1 AND SHORTWAVE_RADIATION = 0 THEN 'IS_DAY=1 but radiation=0'
         END;
```

---

## 9. Seasonal Patterns

**Câu hỏi:** Trung bình mỗi tháng sản lượng bao nhiêu? Mùa hè vs mùa đông chênh lệch thế nào?

**Tại sao cần biết?**
- Xác nhận có seasonality rõ rệt không → có cần dùng lag_365, seasonal decompose, hay dùng model hỗ trợ seasonality (Prophet, SARIMA) không
- Biên độ dao động theo mùa → model có cần feature về mùa (month, season) không? Nếu biên độ lớn → cần mạnh tay với seasonal features
- Nếu data < 1 năm → không thể học seasonality từ data → phải dùng external data (ví dụ: solar irradiation từ NASA POWER) hoặc dùng model không cần seasonality
- Nếu có trend tăng/giảm theo thời gian → cần detrend hoặc dùng model hỗ trợ trend

**Query:**
```sql
SELECT d.MONTH_NUM,
       ROUND(AVG(g.ENERGY_GENERATED_KWH), 2) AS avg_daily_kwh,
       SUM(g.ENERGY_GENERATED_KWH) AS total_kwh,
       COUNT(DISTINCT g.DATE_ID) AS days_with_data
FROM FACT_SOLAR_ENERGY_GEN g
JOIN DIM_DATE d ON d.DATE_ID = g.DATE_ID
GROUP BY d.MONTH_NUM
ORDER BY d.MONTH_NUM;
```

**Plan:**
```
-----------------------------------------------------------------------------------------------
| Id  | Operation              | Name                  | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT       |                       |   838 | 43576 |  3963   (3)| 00:00:01 |
|   1 |  SORT GROUP BY         |                       |   838 | 43576 |  3963   (3)| 00:00:01 |
|   2 |   VIEW                 | VW_DAG_0              |   838 | 43576 |  3962   (3)| 00:00:01 |
|*  3 |    HASH JOIN           |                       |   838 | 54470 |  3962   (3)| 00:00:01 |
|   4 |     VIEW               | VW_GBC_6              |   838 | 32682 |  3957   (3)| 00:00:01 |
|   5 |      HASH GROUP BY     |                       |   838 |  7542 |  3957   (3)| 00:00:01 |
|   6 |       TABLE ACCESS FULL| FACT_SOLAR_ENERGY_GEN |  2731K|    23M|  3867   (1)| 00:00:01 |
|   7 |     TABLE ACCESS FULL  | DIM_DATE              |  2312 | 60112 |     5   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------
Predicate: 3 - access("D"."DATE_ID"="ITEM_1")
Note: dynamic sampling used (level=2), adaptive plan
```
Cost 3867 — 2.7M rows FTS, HASH JOIN, HASH GROUP BY. Chấp nhận được cho exploration.
Cần tối ưu cho dashboard thì tạo composite index covering `(MONTH_NUM, ENERGY_GENERATED_KWH, DATE_ID)`.
