# Solar Energy Query Tuning Lab

Schema: Dimensional Model (Star Schema) cho Solar Power Plant Monitoring.

## Domain Knowledge

| KPI | Formula | Ý nghĩa |
|---|---|---|
| Specific Yield | `SUM(energy_kwh) / KWP` | kWh sinh ra trên mỗi kWp lắp đặt |
| Performance Ratio | `actual_energy / (irradiation × KWP / 1000)` | Hiệu suất so với lý thuyết |
| Capacity Factor | `actual_energy / (KWP × 24h × số_ngày)` | Mức độ tận dụng công suất |
| Temperature Loss | Nhiệt độ cao → giảm hiệu suất (~0.4%/°C) | Panel càng nóng càng kém |

---

## Ticket 1: Tổng Sản Lượng Theo Campus Theo Tháng

Báo cáo cho management: mỗi campus sản xuất được bao nhiêu kWh mỗi tháng?

Output: `campus_name | month | total_kwh | kwp | specific_yield`

Gợi ý: JOIN `FACT_SOLAR_ENERGY_GEN` → `DIM_SOLAR_SITE` → `DIM_CAMPUS` → `DIM_DATE`

### Version A
```sql

```

### Version B (specific yield)
```sql

```

---

## Ticket 2: So Sánh Performance Ratio Giữa Các Site

Site nào đang chạy tốt, site nào chạy kém?

Output: `site_id | month | total_kwh | avg_irradiation | performance_ratio`

Gợi ý: FACT_WEATHER có `SHORTWAVE_RADIATION` (W/m²). Cần đổi sang kWh/m².

### Version A: JOIN fact_weather + fact_solar_energy_gen
```sql

```

### Version B: Window function so sánh PR từng site vs trung bình
```sql

```

---

## Ticket 3: Phát Hiện Bất Thường — Outlier

Tìm các bản ghi có `ROLLING_OUTLIER_FLAG = 1`. Bao nhiêu % dữ liệu bị đánh dấu? Có trend theo thời gian không?

Output: `month | total_rows | outlier_count | outlier_pct`

```sql

```

---

## Ticket 4: Nhiệt Độ Ảnh Hưởng Đến Sản Lượng

Panel càng nóng càng kém hiệu suất. Chứng minh bằng data.

Output: Xếp ngày theo bucket nhiệt độ — mỗi bucket có avg energy / avg irradiation (hiệu suất).

Gợi ý: `FACT_WEATHER.TEMPERATURE_C`, `FACT_SOLAR_ENERGY_GEN.ENERGY_GENERATED_KWH`

```sql
SELECT ROUND(TEMPERATURE_C / 5) * 5 AS temp_bucket,
       AVG(e.ENERGY_GENERATED_KWH) / NULLIF(AVG(w.SHORTWAVE_RADIATION), 0) AS efficiency_ratio,
       COUNT(*) AS samples
FROM FACT_SOLAR_ENERGY_GEN e
JOIN FACT_WEATHER w ON w.SITE_ID = e.SITE_ID
   AND w.DATE_ID = e.DATE_ID AND w.TIME_ID = e.TIME_ID
GROUP BY ROUND(TEMPERATURE_C / 5) * 5
ORDER BY temp_bucket;
```

---

## Ticket 5: Ranking Site Theo Sản Lượng Trung Bình Ngày

Site nào sản xuất ổn định nhất (CV thấp nhất)?

Output: `site_id | avg_daily_kwh | stddev_daily_kwh | coefficient_of_variation`

```sql

```

---

## Ticket 6: Thời Gian Nào Trong Ngày Sản Xuất Nhiều Nhất?

Buổi sáng, trưa, chiều? Phân tích theo `DIM_TIME.HOUR_NUM`.

Output: `hour | avg_energy | avg_irradiation | samples`

```sql

```

---

## Ticket 7: Join 5 Bảng — Executive Dashboard

Dashboard 1 câu query: campus nào, tháng nào, hiệu suất ra sao, thời tiết thế nào.

Output: `campus_name | year | month | total_kwh | avg_temperature | total_sunshine_hours | performance_ratio | site_count`

Gợi ý: JOIN `DIM_CAMPUS` → `DIM_SOLAR_SITE` → `FACT_SOLAR_ENERGY_GEN` → `FACT_WEATHER` → `DIM_DATE`

```sql

```
