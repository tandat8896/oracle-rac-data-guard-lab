# PGA Tuning — Program Global Area

PGA là vùng nhớ riêng cho mỗi session. Chứa: sort area, hash area, bitmap operations, cursor state.

---

## 1. Xem Cấu Hình PGA Hiện Tại

```sql
SELECT name, value FROM v$parameter WHERE name IN ('pga_aggregate_target', 'pga_aggregate_limit', 'workarea_size_policy');
```

**Kết quả thực tế:**
```text
NAME                   VALUE
pga_aggregate_limit    2147483648      (2GB)
pga_aggregate_target   536870912       (512MB)
workarea_size_policy   AUTO
```

```sql
SELECT name, value FROM v$pgastat WHERE name IN ('aggregate PGA target parameter', 'aggregate PGA auto target', 'total PGA inuse', 'total PGA allocated', 'maximum PGA allocated', 'total freeable PGA memory', 'cache hit percentage', 'recompute count (total)');
```

**Kết quả trước tune (CDB root = 512MB, overalloc_count = 3):**
```text
NAME                                    VALUE
aggregate PGA target parameter      536870912       (512MB — target)
total PGA inuse                     722772461       (689MB — đang xài > target!)
total freeable PGA memory             60334592       (57MB — có thể free)
cache hit percentage                      100       (tốt)
```

**Kết quả sau tune (CDB root = 2GB, overalloc_count = 0):**
```text
NAME                                    VALUE
aggregate PGA target parameter     2147483648       (2048MB — target 2GB)
total PGA inuse                     722772461       (689MB — đã < target)
total freeable PGA memory             60334592       (57MB)
cache hit percentage                      100       (tốt)
```
> **Trước tune:** total PGA inuse (689MB) > target (512MB), overalloc_count = 3.
> **Sau tune:** target 2048MB, overalloc_count = 0 (factor 0.5 là 1024MB đã overalloc = 0).
> **Khuyến nghị:** CDB root ≥ 2GB, PDB1 = 1GB.

---

## 2. PGA Advice — Có Nên Tăng?

```sql
SELECT pga_target_for_estimate/1024/1024 AS pga_target_mb, pga_target_factor, estd_pga_cache_hit_percentage, estd_overalloc_count FROM v$pga_target_advice ORDER BY pga_target_for_estimate;
```

**Kết quả thực tế:**
```text
PGA_TARGET_MB   FACTOR   OVERALLOC_COUNT
           64     0.125                 1
          128      0.25                 1
          256       0.5                 0   ← đủ từ đây!
          384      0.75                 0
          512         1                 0   ← hiện tại PDB1 = 1GB
          614       1.2                 0
          717       1.4                 0
          819       1.6                 0
          922       1.8                 0
         1024         2                 0
```
> **Phân tích:** CDB root 2048MB + PDB1 1024MB → overalloc_count = 0 ngay từ factor 0.5. PGA đã đủ.
> 
> **Trước tune (CDB root 512MB):** overalloc_count = 3 ở factor 1.0, phải lên 1.6 mới hết.
> **Sau tune (CDB root 2048MB):** overalloc_count = 0 ở factor 0.5 — dư sức.

---

## 3. Top Session Dùng PGA Nhiều Nhất

```sql
SELECT s.sid, s.username, s.program, s.sql_id, p.pga_used_mem/1024/1024 AS pga_used_mb, p.pga_alloc_mem/1024/1024 AS pga_alloc_mb, p.pga_max_mem/1024/1024 AS pga_max_mb FROM v$session s JOIN v$process p ON s.paddr = p.addr WHERE s.type = 'USER' ORDER BY p.pga_used_mem DESC FETCH FIRST 10 ROWS ONLY;
```

**Kết quả thực tế:**
```text
SID USERNAME     PROGRAM                        PGA_USED_MB  PGA_ALLOC_MB  PGA_MAX_MB
311 SYS          java@rac1 (TNS V1-V3)               6.63          7.29         7.29
 62 QUERY_TUNING java@rac1 (TNS V1-V3)               4.87          6.53        11.09
 45 SYSRAC       oraagent.bin@rac1                   3.95          4.92         6.54
280 SYSRAC       oraagent.bin@rac1                   3.56          4.17         4.17
 48 SYSRAC       oraagent.bin@rac1                   2.64          3.79         3.79
 47 SYSRAC       oraagent.bin@rac1                   2.64          3.86         4.11
```
> PGA mỗi session chỉ từ 2-7MB — không có session nào "ngốn" PGA. Vấn đề overalloc_count = 4 là do có nhiều session (RAC agents + java connections) cộng dồn vượt target 512MB.

---

## 4. Sort Spill — Khi PGA Không Đủ
...
> `sorts (disk)` phải là phần rất nhỏ so với `sorts (memory)`. Nếu disk sort > 1%, PGA đang thiếu.

**Kết quả thực tế:**
```text
sorts (memory)     31930
sorts (disk)           0
```
> Disk sort = 0 — hiện tại chưa có sort spill ra disk. Nhưng nếu chạy sort trên bảng lớn hơn, với PGA target 512MB và overalloc_count = 4, sort có thể spill bất cứ lúc nào.

### Demo: Tạo Sort Spill

```sql
EXPLAIN PLAN FOR SELECT * FROM orders_demo ORDER BY total_amount, order_date, customer_id;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

**Kết quả thực tế:**
```text
------------------------------------------------------------------------------------------
| Id  | Operation          | Name        | Rows  | Bytes |TempSpc| Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |             |   100K|  3320K|       |  1083   (1)| 00:00:01 |
|   1 |  SORT ORDER BY     |             |   100K|  3320K|  5104K|  1083   (1)| 00:00:01 |
|   2 |   TABLE ACCESS FULL| ORDERS_DEMO |   100K|  3320K|       |   171   (1)| 00:00:01 |
------------------------------------------------------------------------------------------
```
> **TempSpc = 5104K (5MB)** — Oracle dự kiến sẽ tốn **5MB temp** cho sort này. Nếu PGA đủ, sort chạy trong RAM, TempSpc = 0. Khi TempSpc > 0, sort sẽ phải xuống disk (chậm). PGA 512MB là không đủ — nếu có nhiều session sort cùng lúc, disk sort sẽ xuất hiện ngay.

---

## 5. PGA Tuning Workflow

**Bước 1 — Check advice:**
```sql
SELECT pga_target_factor, estd_pga_cache_hit_percentage, estd_overalloc_count FROM v$pga_target_advice ORDER BY pga_target_for_estimate;
```

**Bước 2 — Tăng PGA (nếu overalloc_count > 0):**
```sql
ALTER SYSTEM SET PGA_AGGREGATE_TARGET = 2G;
ALTER SYSTEM SET PGA_AGGREGATE_LIMIT  = 4G;
```

**Bước 3 — Verify:**
```sql
SELECT name, value FROM v$pgastat WHERE name IN ('aggregate PGA target parameter', 'cache hit percentage');
```

---

## 6. ASMM vs AMM — Nên Dùng Cái Nào?

### ASMM (Automatic Shared Memory Management) — Khuyên Dùng

```sql
ALTER SYSTEM SET MEMORY_TARGET = 0;
ALTER SYSTEM SET SGA_TARGET    = 4G;
ALTER SYSTEM SET PGA_AGGREGATE_TARGET = 1G;
ALTER SYSTEM SET DB_CACHE_SIZE    = 1G;
ALTER SYSTEM SET SHARED_POOL_SIZE = 512M;
```

### AMM (Automatic Memory Management)

```sql
ALTER SYSTEM SET MEMORY_TARGET     = 6G;
ALTER SYSTEM SET MEMORY_MAX_TARGET = 8G;
```
> **Không dùng AMM với HugePages** — AMM và HugePages không tương thích. Trên Linux production, ASMM + HugePages là chuẩn.

### Kiểm Tra Chế Độ Hiện Tại

```sql
SELECT name, value FROM v$parameter WHERE name IN ('memory_target', 'sga_target', 'pga_aggregate_target');
```
> `MEMORY_TARGET > 0` → AMM.  
> `MEMORY_TARGET = 0` và `SGA_TARGET > 0` → ASMM.

---

## Tổng Kết

| Indicator | View | OK | Bad |
|:---|:---|:---|:---|
| Cache hit % | `v$pgastat` | > 90% | < 80% |
| Disk sorts | `v$sysstat` | < 1% sorts (disk) | > 5% |
| Overalloc count | `v$pga_target_advice` | 0 | > 0 |
| PGA per session | `v$process` | < target | Gần limit |

**Nguyên tắc:** PGA thiếu → sort spill ra disk → chậm. PGA thừa → lãng phí RAM. Dùng `v$pga_target_advice` để tìm điểm vàng.
