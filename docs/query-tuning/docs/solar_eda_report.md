# Solar Energy Data Exploration Report

## 1. Tổng quan dữ liệu

- 2,731,946 rows
- 42 sites
- Time range: Jan 2020 → Apr 2022 (2 năm 4 tháng)
- Granularity: 15 phút
- Weather: 1 tiếng (FACT_WEATHER)
- Timestamp: Local time, không timezone shift

## 2. Gap

- 15 gaps > 15 phút (trên 1 site)
- Gap lớn nhất: 4 ngày (sensor downtime)
- Gap 75 phút: ghi thiếu 5 interval

## 3. Time shift detection

### Correlation giữa energy và radiation

| Shift | CORR avg | Ghi chú |
|---|---|---|
| 0h | 0.85 | 100% sites |
| +1h | 0.83 | |
| -1h | 0.70 | |

**Kết luận: Không cần shift.** Join bằng `FLOOR(TIME_ID/100)` là ổn.

### Peak hour: energy vs radiation

Tất cả 42 sites đều có pattern:
- Energy peak: 12h trưa
- Radiation peak: 13h trưa

Lệch 1h là do cách ghi timestamp khác nhau (energy point, weather avg). Khi train ML chỉ cần thêm feature `radiation_lag1h`.

## 4. Không DST, không timezone

- Mùa hè (tháng 11-3): CORR 0h = 0.839
- Mùa đông (tháng 4-10): CORR 0h = 0.802
- Chênh lệch không đáng kể → không có DST bug

## 5. Join weather

- Match TIME_ID: 25% (weather 1h, energy 15p)
- Match DATE_ID: 100%
- Join đúng: `FLOOR(w.TIME_ID/100) = FLOOR(g.TIME_ID/100)`

## 6. Site distribution

| SITE_ID | rows | min | max |
|---|---|---|---|
| 1 | 65046 | Jan 2020 | Apr 2022 |
| 2 | 65046 | Jan 2020 | Apr 2022 |
| ... | ... | ... | ... |
| 4 | thiếu Sep-Oct 2020 |
| 11 | thiếu Sep-Oct 2020 |

## 7. Seasonal pattern

Mùa hè (tháng 11-3) cao gấp 1.5-2x mùa đông (tháng 6-8).

## 8. Khuyến nghị cho ML

| Item | Khuyến nghị |
|---|---|
| Resolution | Giữ 15p hoặc aggregate xuống 1h |
| Weather | Thêm radiation_lag1h |
| Gap | Forward fill + was_gap flag |
| Outlier | Tự detect IQR + radiation (flag sai) |
| Site scaling | Normalize energy theo KWP |
| Model | XGB/LGBM + feature lag/rolling |

## 9. Raw queries

```sql
-- Date range
SELECT MIN(GEN_TIMESTAMP), MAX(GEN_TIMESTAMP), COUNT(*) FROM FACT_SOLAR_ENERGY_GEN;

-- Correlation 42 sites 0h
SELECT g.SITE_ID, ROUND(CORR(g.ENERGY_GENERATED_KWH, w.SHORTWAVE_RADIATION), 4) AS corr_0h FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND w.TIME_ID = g.TIME_ID GROUP BY g.SITE_ID ORDER BY g.SITE_ID;

-- Join đúng granularity
SELECT ... FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND FLOOR(w.TIME_ID/100) = FLOOR(g.TIME_ID/100);

-- Peak energy vs radiation per site
SELECT t.HOUR_NUM, ROUND(AVG(g.ENERGY_GENERATED_KWH),4) AS avg_energy, ROUND(AVG(w.SHORTWAVE_RADIATION),2) AS avg_radiation FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND FLOOR(w.TIME_ID/100) = FLOOR(g.TIME_ID/100) JOIN DIM_TIME t ON t.TIME_ID = g.TIME_ID WHERE g.SITE_ID = 1 GROUP BY t.HOUR_NUM ORDER BY t.HOUR_NUM;
```

## 10. Kết luận cuối

Data sạch, ít gap, correlation cao. Bắt đầu ML được. Chỉ cần thêm `radiation_lag1h` feature cho 100% sites.
