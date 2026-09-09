# EDA: Phân bố năng lượng ban ngày (weekday 6h-18h)

## Nguyên tắc
42 sites KWP từ 21 → 540 → không gộp chung, phân tích theo từng site.

## Query A: Utilization % phân bố theo site

```sql
SELECT e.SITE_ID, ROUND(s.KWP, 2) AS kwp, ROUND(AVG(e.ENERGY_GENERATED_KWH / NULLIF(s.KWP, 0) * 100), 2) AS avg_util_pct, COUNT(*) AS total, ROUND(MIN(e.ENERGY_GENERATED_KWH / NULLIF(s.KWP, 0) * 100), 2) AS min_util, ROUND(MAX(e.ENERGY_GENERATED_KWH / NULLIF(s.KWP, 0) * 100), 2) AS max_util FROM FACT_SOLAR_ENERGY_GEN e JOIN DIM_TIME t ON t.TIME_ID = e.TIME_ID JOIN DIM_DATE d ON d.DATE_ID = e.DATE_ID JOIN DIM_SOLAR_SITE s ON s.SITE_ID = e.SITE_ID WHERE t.HOUR_NUM BETWEEN 6 AND 18 AND TO_CHAR(d.FULL_DATE, 'D') NOT IN (1, 7) AND s.KWP IS NOT NULL GROUP BY e.SITE_ID, s.KWP ORDER BY avg_util_pct DESC;
```

**→ Site 19 outlier rõ: avg_util = 46%, các site khác 4-16%.**

## Query B: Site 19 — kiểm tra data completeness

```sql
SELECT d.YEAR_NUM, d.MONTH_NUM, COUNT(*) AS cnt FROM FACT_SOLAR_ENERGY_GEN e JOIN DIM_DATE d ON d.DATE_ID = e.DATE_ID WHERE e.SITE_ID = 19 GROUP BY d.YEAR_NUM, d.MONTH_NUM ORDER BY d.YEAR_NUM, d.MONTH_NUM;
```

**→ Nếu thiếu tháng → ngờ gap data. Nếu đủ → utilization 19 thực sự cao.**

## Query C: Utilization % chi tiết site 19 các giờ

```sql
SELECT t.HOUR_NUM, ROUND(AVG(e.ENERGY_GENERATED_KWH / 34.32 * 100), 2) AS avg_util, ROUND(MAX(e.ENERGY_GENERATED_KWH / 34.32 * 100), 2) AS max_util, COUNT(*) AS cnt FROM FACT_SOLAR_ENERGY_GEN e JOIN DIM_TIME t ON t.TIME_ID = e.TIME_ID JOIN DIM_DATE d ON d.DATE_ID = e.DATE_ID WHERE e.SITE_ID = 19 AND t.HOUR_NUM BETWEEN 6 AND 18 AND TO_CHAR(d.FULL_DATE, 'D') NOT IN (1, 7) GROUP BY t.HOUR_NUM ORDER BY t.HOUR_NUM;
```

## Query D: So sánh site 19 với site cùng KWP (30-40)

```sql
SELECT e.SITE_ID, s.KWP, t.HOUR_NUM, ROUND(AVG(e.ENERGY_GENERATED_KWH / NULLIF(s.KWP, 0) * 100), 2) AS avg_util FROM FACT_SOLAR_ENERGY_GEN e JOIN DIM_TIME t ON t.TIME_ID = e.TIME_ID JOIN DIM_DATE d ON d.DATE_ID = e.DATE_ID JOIN DIM_SOLAR_SITE s ON s.SITE_ID = e.SITE_ID WHERE t.HOUR_NUM = 12 AND s.KWP BETWEEN 30 AND 45 AND s.KWP IS NOT NULL AND TO_CHAR(d.FULL_DATE, 'D') NOT IN (1, 7) GROUP BY e.SITE_ID, s.KWP, t.HOUR_NUM ORDER BY avg_util DESC;
```

## Query E: Site 19 — daily check (gap ngày)

```sql
SELECT e.SITE_ID, d.FULL_DATE, COUNT(*) AS cnt, ROUND(MIN(e.ENERGY_GENERATED_KWH), 2) AS min_kwh, ROUND(MAX(e.ENERGY_GENERATED_KWH), 2) AS max_kwh FROM FACT_SOLAR_ENERGY_GEN e JOIN DIM_DATE d ON d.DATE_ID = e.DATE_ID WHERE e.SITE_ID = 19 GROUP BY e.SITE_ID, d.FULL_DATE ORDER BY d.FULL_DATE;
```

## Query F: Phát hiện site KWP sai (max_util > 100%)

```sql
SELECT e.SITE_ID, s.KWP, ROUND(MAX(e.ENERGY_GENERATED_KWH), 2) AS max_kwh, ROUND(MAX(e.ENERGY_GENERATED_KWH) / (NULLIF(s.KWP, 0) / 4) * 100, 2) AS max_util_pct FROM FACT_SOLAR_ENERGY_GEN e JOIN DIM_SOLAR_SITE s ON s.SITE_ID = e.SITE_ID WHERE s.KWP IS NOT NULL GROUP BY e.SITE_ID, s.KWP HAVING MAX(e.ENERGY_GENERATED_KWH) / (NULLIF(s.KWP, 0) / 4) * 100 > 100 ORDER BY max_util_pct DESC;
```

## Nhận xét

- **Không zero bucket** — không có energy = 0 giữa 6h-18h ngày thường.
- **24/25 site có avg_util 4-16%** — bình thường cho solar daytime.
- **Site 19: KWP bị ghi sai.** MAX_KWH=42.22 với KWP=34.32 là bất khả thi vật lý (panel 34.32 kW chỉ sản xuất tối đa ~8.58 kWh/15ph). KWP thực tế phải ~169 kW. Không phải utilization cao, mà là KWP khai thiếu.
- Site 19 có gap ngày rải rác (~5-10 ngày) nhưng không ảnh hưởng kết luận.
- Cần kiểm tra lại KWP site 19 trước khi dùng cho ML. Hiện tại phải bỏ site 19 hoặc dùng KWP thực tế.
- **Không gộp chung** — aggregate toàn bộ sites không ý nghĩa do KWP chênh lệch lớn.
