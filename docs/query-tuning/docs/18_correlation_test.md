# Lesson 18: Correlation Test — Time Shift Detection

Kiểm tra correlation giữa `ENERGY_GENERATED_KWH` (FACT_SOLAR_ENERGY_GEN) và `SHORTWAVE_RADIATION` (FACT_WEATHER) để phát hiện time shift.

## Kết quả

### Site 1 — các mức shift

| Shift | CORR | Ghi chú |
|---|---|---|
| 0h | 0.8310 | Không shift |
| +1h | 0.6388 | Giảm mạnh |
| -1h | ? | Chưa chạy |

→ **Kết luận:** Site 1 không có time shift. Correlation cao nhất ở shift 0h.

## Query

### 1. Correlation không shift — 42 sites

```sql
explain plan for SELECT g.SITE_ID, CORR(g.ENERGY_GENERATED_KWH, w.SHORTWAVE_RADIATION) AS corr_0h FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND FLOOR(w.TIME_ID / 100) = FLOOR(g.TIME_ID / 100) GROUP BY g.SITE_ID ORDER BY g.SITE_ID;
```

```sql
SELECT g.SITE_ID, CORR(g.ENERGY_GENERATED_KWH, w.SHORTWAVE_RADIATION) AS corr_0h FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND FLOOR(w.TIME_ID / 100) = FLOOR(g.TIME_ID / 100) GROUP BY g.SITE_ID ORDER BY g.SITE_ID;
```

### 2. Correlation shift +1h — 42 sites

```sql
SELECT g.SITE_ID, CORR(g.ENERGY_GENERATED_KWH, w.SHORTWAVE_RADIATION) AS corr_p1h FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND FLOOR(w.TIME_ID / 100) = FLOOR(g.TIME_ID / 100) - 1 GROUP BY g.SITE_ID ORDER BY g.SITE_ID;
```

### 3. Correlation shift -1h — 42 sites

```sql
SELECT g.SITE_ID, CORR(g.ENERGY_GENERATED_KWH, w.SHORTWAVE_RADIATION) AS corr_m1h FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND FLOOR(w.TIME_ID / 100) = FLOOR(g.TIME_ID / 100) + 1 GROUP BY g.SITE_ID ORDER BY g.SITE_ID;
```

## Raw output

### 42 sites — không shift

```

```

### 42 sites — shift +1h

```

```

### 42 sites — shift -1h

```

```

## Phân tích

- [x] Toàn bộ 42 sites CORR -1h > CORR 0h → không phải DST
- [x] CORR summer 0h = 0.839, winter 0h = 0.802 → không có DST shift

### Phát hiện: CORR -1h cao hơn CORR 0h ở tất cả 42 sites

| Shift | CORR avg |
|---|---|
| 0h | ~0.81 |
| -1h (weather sớm hơn) | **~0.86** 🏆 |
| +1h (weather trễ hơn) | ~0.62 |

### Nguyên nhân: Timestamp convention mismatch

| Data | Cách đo | Timestamp ghi |
|---|---|---|
| Radiation | Trung bình **1 tiếng** (12:00→13:00) | Ghi ở **cuối giờ** 13:00 |
| Energy | Điểm 15 phút | Ghi đúng thời điểm |

→ Weather 13:00 = avg radiation từ 12:00→13:00 → ảnh hưởng đến energy 12:15, 12:30, 12:45, 13:00
→ Ghép theo TIME_ID = 13:00 bị lệch 1 slot

**Chạy thử DST:**
- Summer (tháng 11-3, DST on): CORR 0h = **0.839**
- Winter (tháng 4-10, DST off): CORR 0h = **0.802**
- Cả 2 gần bằng nhau → **không phải DST**

### Kết luận cho ML

Align trước khi train: **weather - 1h so với energy** (lấy radiation của 1 tiếng trước ghép vào energy hiện tại).

```python
weather['aligned_timestamp'] = weather['timestamp'] + pd.Timedelta(hours=1)  # hoặc
energy['weather_hour'] = energy['hour'] + 1  # join theo hour+1
```

### Auto detect best shift per site

```sql
SELECT site_id, ROUND(CORR(energy, radiation_0h), 4) AS corr_0h, ROUND(CORR(energy, radiation_p1h), 4) AS corr_p1h, ROUND(CORR(energy, radiation_m1h), 4) AS corr_m1h, ROUND(CORR(energy, radiation_p2h), 4) AS corr_p2h, ROUND(CORR(energy, radiation_m2h), 4) AS corr_m2h FROM ( SELECT g.SITE_ID, g.ENERGY_GENERATED_KWH AS energy, w.SHORTWAVE_RADIATION AS radiation_0h, LEAD(w.SHORTWAVE_RADIATION, 1) OVER (PARTITION BY g.SITE_ID ORDER BY g.DATE_ID, g.TIME_ID) AS radiation_p1h, LAG(w.SHORTWAVE_RADIATION, 1) OVER (PARTITION BY g.SITE_ID ORDER BY g.DATE_ID, g.TIME_ID) AS radiation_m1h, LEAD(w.SHORTWAVE_RADIATION, 2) OVER (PARTITION BY g.SITE_ID ORDER BY g.DATE_ID, g.TIME_ID) AS radiation_p2h, LAG(w.SHORTWAVE_RADIATION, 2) OVER (PARTITION BY g.SITE_ID ORDER BY g.DATE_ID, g.TIME_ID) AS radiation_m2h FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND w.TIME_ID = g.TIME_ID ) GROUP BY site_id ORDER BY site_id;
```

## Data Quality — Sites missing data

Phát hiện: Site 4 & 11 không có data tháng 09 & 10 năm 2020.

Cần kiểm tra thêm:
- [ ] Sites khác có missing months không?
- [ ] Site 4 & 11 missing từ khi nào? (điện chưa lắp? sensor hỏng?)
- [ ] Ảnh hưởng đến train/val split: nếu val set chọn tháng 09/2020, site 4&11 = 0 dòng

**Kiểm tra TIME_ID lệch 75 phút:**
```sql
SELECT g.GEN_TIMESTAMP, g.ENERGY_GENERATED_KWH, g.TIME_ID, w.TIME_ID AS weather_time_id, t.HOUR_NUM, t.MINUTE_NUM, w.SHORTWAVE_RADIATION FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID JOIN DIM_TIME t ON t.TIME_ID = g.TIME_ID WHERE g.SITE_ID = 5 AND g.GEN_TIMESTAMP >= DATE '2021-01-01' AND ROWNUM <= 20 ORDER BY g.GEN_TIMESTAMP;
```

```sql
-- Kiểm tra tất cả sites: tháng nào có 0 dòng
SELECT g.SITE_ID, d.MONTH_NUM, COUNT(*) AS rows FROM FACT_SOLAR_ENERGY_GEN g JOIN DIM_DATE d ON d.DATE_ID = g.DATE_ID GROUP BY g.SITE_ID, d.MONTH_NUM ORDER BY g.SITE_ID, d.MONTH_NUM;
```
