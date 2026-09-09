# Lesson 17: Solar Energy Forecasting — ML Plan

## Data Summary (from 16_solar_data_exploration)

| Item | Value |
|---|---|
| Sites | 42 |
| Date range | Jan 2020 → Apr 2022 (2 yr 4 mo) |
| Granularity | 15 phút, đều |
| Gaps | 15 gaps >15 phút / 2.7M rows (<0.02%) |
| Time zone | Local time, không shift |
| Outlier flag | Rolling flag sai → cần tự detect |
| Seasonal pattern | Rõ, summer cao gấp 1.5-2x winter |
| Weather | FACT_WEATHER đã join được, match 100% |

---

## 1. Mục Tiêu

**Forecast ENERGY_GENERATED_KWH** với 2 horizons:

| Horizon | Use case | Resolution |
|---|---|---|
| Ngắn (next 6h) | Grid dispatch, battery control | 15 phút |
| Dài (next 7 days) | Maintenance schedule, trading | 1 giờ |

---

## 2. Features Engineering

### Time features
```
hour, minute, day_of_week, day_of_month, month, year, is_weekend
sin_hour = sin(2π * hour/24), cos_hour = cos(2π * hour/24)
sin_month = sin(2π * month/12), cos_month = cos(2π * month/12)
```

### Lag features (target)
```
lag_1, lag_2, lag_4, lag_8, lag_12, lag_24     (15p → 1h, 2h, 4h, 6h)
lag_96 = same hour yesterday                     (15p × 96 = 24h)
lag_672 = same hour last week                    (15p × 672 = 7 days)
lag_2928 = same hour last month                  (15p × 2928 ≈ 30.5 days)
```

### Rolling window features
```
rolling_mean_6h  = mean(prev 24 rows)
rolling_mean_24h = mean(prev 96 rows)
rolling_std_6h   = std(prev 24 rows)
rolling_max_24h  = max(prev 96 rows)
```

### Weather features (nếu forecast ≤ 6h hoặc có weather forecast input)
```
SHORTWAVE_RADIATION, TEMPERATURE_C, IS_DAY
```

### Site features
```
KWP — normalize energy theo KWP (specific yield = energy / KWP)
longitude, latitude — nếu dùng spatial model
```

### Binary flags
```
was_gap: forward fill gap hay không
was_outlier: tự detect bằng IQR per site
is_night: energy = 0 nhưng còn nắng (radiation > 50)
```

---

## 3. Preprocessing

### Resampling
```
Daily forecast:     aggregate 15p → 1 ngày (sum)
Hourly forecast:    aggregate 15p → 1 giờ (mean)  
15p forecast:       keep nguyên
```

### Normalization
```
Mỗi site normalize riêng:
- MinMaxScaler(0,1) cho LSTM/DLinear/NLinear
- StandardScaler cho XGB/LGBM/RF
- KWP divide → specific yield (kWh/kWp)
```

### Gap handling
```
Forward fill + was_gap flag
Không drop — time series không drop được
```

### Outlier handling
```
IQR theo site:
  Q1 - 3*IQR < energy < Q3 + 3*IQR → clip
  Ngoài khoảng → gán flag = 1, thay bằng forward fill
```

---

## 4. Models

### Baseline
| Model | Ưu | Nhược |
|---|---|---|
| Prophet | Auto seasonality, trend, holiday | Không weather feature |
| SARIMA | Statistical, confidence interval | Không weather, không scale lớn |
| Naive (last value) | Baseline rẻ nhất | Dở |

### Chính
| Model | Ưu | Nhược | Khi nào dùng |
|---|---|---|---|
| XGBoost | Feature importance, missing handle | Không temporal order | Có weather feature, feature nhiều |
| LightGBM | Nhanh hơn XGB, leaf-wise | Overfit nếu data ít | Large data (>1M rows) |
| RandomForest | Robust, ít tuning | Chậm, không extrapolate | Baseline trước XGB |
| LSTM | Temporal sequence | Nặng, cần tune | Data > 3 năm, short horizon |
| DLinear | Đơn giản, beat LSTM on trend | Không complex pattern | Univariate, daily forecast |
| NLinear | Temporal + feature | Mới, ít tài liệu | Thử nghiệm |

### Ensemble
```
Stacking:
  Level 1: XGB + LGBM + DLinear
  Meta: Linear Regression hoặc XGB nhỏ
```

---

## 5. Evaluation Protocol

### Cross validation (temporal, không shuffle)
```
Training:     Jan 2020 → Jun 2021 (18 tháng)
Validation:   Jul 2021 → Dec 2021 (6 tháng)
Test:         Jan 2022 → Apr 2022 (4 tháng)

Nếu muốn kỹ:
  CV1: train → Nov 2020, val Dec 2020
  CV2: train → May 2021, val Jun 2021
  CV3: train → Nov 2021, val Dec 2021
```

### Metrics
| Metric | Ý nghĩa |
|---|---|
| MAE | Sai số tuyệt đối trung bình (dễ hiểu) |
| RMSE | Phạt nặng sai số lớn |
| sMAPE | % sai số (so sánh giữa sites) |
| R² | % variance giải thích được |

Luôn track theo site + mùa để biết site nào model kém.

---

## 6. Pipeline

```
1. Extract    — Oracle → CSV/Parquet (SQL trong 16_solar_data_exploration.md)
2. Clean      — forward fill gap, detect outlier, thêm flags
3. Feature    — time, lag, rolling, weather, site
4. Split      — temporal train/val/test
5. Normalize  — per site scaler
6. Train      — models
7. Eval       — metrics per site + season
8. Ensemble   — stacking
9. Deploy     — ONNX / PMML / API
```

---

## 7. Risk

| Risk | Impact | Mitigation |
|---|---|---|
| Chỉ 2 năm data | Model không học được multi-year pattern | Dùng cyclic features + transfer từ pretrained |
| Outlier flag sai | Model học noise | Tự detect bằng IQR + radiation |
| 42 sites KWP khác nhau | Model bias site lớn | Normalize energy/KWP |
| Gap 4 ngày | Lag feature sai | Fill + flag, train bỏ chunk có gap dài |
| Time zone ẩn | Feature hour sai | Confirm: timestamp local time, không issue |
| Weather forecast không có | Không predict được xa >6h | Model pure time series cho dài hạn |

---

## 8. Kế hoạch tuần

| Ngày | Công việc |
|---|---|
| Ngày 1 | Preprocess pipeline: extract → clean → feature → split |
| Ngày 2 | Baseline: Prophet + SARIMA, RF, XGB, LGBM |
| Ngày 3 | Deep: DLinear, NLinear, LSTM |
| Ngày 4 | Ensemble + tune hyperparams |
| Ngày 5 | Eval + deploy script |
