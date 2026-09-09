# Session: Correlation & Time Shift Test

**Ngày:** 26-Jun-2026

## Mục tiêu

Kiểm tra correlation energy vs weather, xác định time shift trước train ML.

## Kết quả

### Correlation 42 sites

| Shift | CORR avg | Ghi chú |
|---|---|---|
| 0h | ~0.85 | **Best cho 34/42 sites** |
| +1h | ~0.83 | Best cho 8 sites (5,6,13,17,29,30,31,40) |
| -1h | ~0.70 | Kém nhất |

→ Không hardcode. Dùng `site_shift` table lookup.

### Không DST, không timezone

- Summer (11-3): 0.839
- Winter (4-10): 0.802
- Gần bằng → loại DST

### Weather 1h, Energy 15p

Weather: hourly avg ghi cuối giờ. Energy: 15p point. Join bằng `FLOOR(TIME_ID / 100)`.

### Data Quality

- 2.7M rows, 42 sites
- Site 4 & 11: missing Sep-Oct 2020
- Gap 4 ngày (Oct 2020) — sensor downtime
- 15 gaps >15p trên site 1

## Key Query

```sql
-- Correlation 42 sites 0h
SELECT g.SITE_ID, ROUND(CORR(g.ENERGY_GENERATED_KWH, w.SHORTWAVE_RADIATION), 4) AS corr_0h FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND w.TIME_ID = g.TIME_ID GROUP BY g.SITE_ID ORDER BY g.SITE_ID;

-- Join đúng granularity
SELECT ... FROM FACT_SOLAR_ENERGY_GEN g JOIN FACT_WEATHER w ON w.SITE_ID = g.SITE_ID AND w.DATE_ID = g.DATE_ID AND FLOOR(w.TIME_ID / 100) = FLOOR(g.TIME_ID / 100);
```

## Kết luận ML

Algin weather- energy: dùng `FLOOR(TIME_ID / 100)` join, shift 0h mặc định. 8 sites lệch +1h thì tra `site_shift`. Feature `is_shift_site` nếu muốn đơn giản.
