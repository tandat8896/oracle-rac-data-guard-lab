# SGA Tuning — System Global Area

SGA là vùng nhớ chia sẻ cho mọi session và background process. Gồm: Buffer Cache, Shared Pool, Large Pool, Java Pool, Redo Log Buffer.

---

## 1. Xem Cấu Hình SGA Hiện Tại

```sql
SELECT name, value FROM v$parameter WHERE name IN ('sga_target', 'sga_max_size', 'memory_target');
```
```text
NAME            VALUE
sga_max_size    1610612736
sga_target      1610612736
memory_target   0
```
> `SGA_TARGET = 1.5GB`, `MEMORY_TARGET = 0` → đang dùng **ASMM** (Oracle tự phân bổ trong SGA).

```sql
SELECT pool, name, bytes/1024/1024 AS mb FROM v$sgastat ORDER BY bytes DESC FETCH FIRST 20 ROWS ONLY;
```
```text
POOL          NAME                                MB
              buffer_cache                       880
              shared_io_pool                      80
shared pool   free memory                      44.24
shared pool   SQLA                             34.45
shared pool   gcs resources                    29.80
shared pool   KGLH0                            19.90
shared pool   SQLA                             18.84
shared pool   gcs shadows                      16.25
shared pool   ges big msg buffers              15.19
large pool    free memory                      15.04
shared pool   SO private sga                   13.54
shared pool   ksunfy_meta 1                    12.01
shared pool   PLMCD                            11.88
shared pool   reader lock mitigation en        10.00
shared pool   KGLH0                             9.61
              fixed_sga                         8.71
shared pool   row cache mutex                   8.60
shared pool   KGLS                              7.55
              log_buffer                        7.29
shared pool   KJSC rnb slots                    6.57
```
> **Buffer Cache = 880MB** lớn nhất — đúng cho OLTP.  
> **Shared Pool free memory = 44MB** — còn trống, chưa bị áp lực.  
> **Log Buffer = 7.29MB** — đủ với workload hiện tại.  
> **Fixed SGA = 8.71MB** — overhead của instance.

```sql
SELECT name, value/1024/1024 AS mb FROM v$sga ORDER BY value DESC;
```
```text
NAME                                MB
Database Buffers                   960
Variable Size                      560
Fixed Size           8.712127685546875
Redo Buffers                7.28515625
```
> **Database Buffers = 960MB** (buffer cache).  
> **Variable Size = 560MB** (shared pool + large pool + java pool).  
> **Fixed Size = 8.7MB** + **Redo Buffers = 7.3MB**.  
> Tổng SGA ≈ 1.5GB khớp với `sga_target`.

---

## 2. Buffer Cache — Lõi Của SGA

Buffer cache chứa các block data đọc từ disk. Lớn nhất và quan trọng nhất.

### Oracle Đọc Dữ Liệu Như Thế Nào?

```text
User chạy: SELECT * FROM orders_demo WHERE order_id = 100;

    ┌─────────────────────────────────────────────────┐
    │                    BUFFER CACHE                 │
    │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐        │
    │  │ ... │ │ ... │ │ ... │ │ ... │ │ ... │  RAM    │
    │  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘  4KB-32KB│
    └──────────────────────┬──────────────────────────┘
                           │ Cache hit? (tìm block có sẵn)
                 ┌─────────┴─────────┐
                 ▼                   ▼
           Có sẵn (Cache Hit)   Không (Cache Miss)
            Lấy từ RAM           Đọc từ ổ cứng (disk)
            Nhanh ~1μs           Chậm ~5-10ms
                                 (chậm hơn 5000-10000 lần)
```

- **Buffer Cache** = tầng RAM đệm giữa user và ổ cứng. Mỗi block data (8KB) khi đọc từ disk xong được giữ lại trong cache cho lần sau.
- **Lần đầu:** block chưa có trong cache → phải xuống ổ cứng đọc (physical read).
- **Lần sau:** block đã có sẵn trong cache → lấy từ RAM (cache hit).
- Nếu cache đủ lớn chứa hết "block nóng" (thường xuyên được truy cập) → hit ratio cao → I/O ít.

### RAM Nhanh Hơn Disk Bao Nhiêu?

```text
RAM (DDR4):        ~10-50 nanoseconds  (1ns = 1/1,000,000,000 giây)
NVMe SSD:          ~10-50 microseconds  (1μs = 1/1,000,000 giây)
HDD:               ~5-10 milliseconds   (1ms = 1/1,000 giây)

So sánh: nếu RAM là xe đua F1 (1 giây):
  NVMe SSD  ~ 1 ngày
  HDD       ~ 6 tháng
```

**Con số thực tế với Oracle:**
- Read 1 block (8KB) từ RAM: ~1 μs
- Read 1 block từ SSD: ~100 μs → chậm hơn **100 lần**
- Read 1 block từ HDD: ~5,000 μs → chậm hơn **5,000 lần**

**Physical reads = 19371** nghĩa là: Oracle đã phải xuống ổ cứng đọc 19371 block — thay vì lấy từ RAM nếu cache đủ lớn. Mỗi lần xuống disk là mất thời gian hơn cache hàng trăm đến hàng ngàn lần.

> Buffer cache tồn tại vì lý do này: biến hàng ngàn lần I/O chậm thành vài lần I/O (lần đầu), còn lại lấy từ RAM nhanh.

### Ba Loại Thống Kê Quan Trọng

| Thống kê | Ý nghĩa | Ví dụ |
|:---|:---|:---|
| **db block gets** | Số lần đọc block để **UPDATE/DELETE/INSERT** (current mode — đọc block mới nhất) | User update 1 row → Oracle đọc block đó vào cache, sửa, ghi lại |
| **consistent gets** | Số lần đọc block để **SELECT** (consistent mode — đọc snapshot tại thời điểm query bắt đầu) | User SELECT 100 rows → Oracle đọc các block chứa 100 row đó |
| **physical reads** | Số block phải xuống ổ cứng đọc (vì không có sẵn trong cache) | "Mò xuống ổ cứng" |

**Ví dụ thực tế:**
```sql
SELECT * FROM orders_demo WHERE order_id = 100;
-- Nếu block chứa order_id = 100 chưa có trong cache:
--   db block gets = 0 (SELECT)
--   consistent gets = 1 (đọc block để lấy row)
--   physical reads = 1 (block đó phải xuống disk)
-- Nếu block đã có sẵn trong cache:
--   consistent gets = 1
--   physical reads = 0 (khỏi xuống disk)
```

### Hit Ratio

```sql
SELECT ROUND((1 - (phy.value / NULLIF(dbg.value + cong.value, 0))) * 100, 2) AS buffer_hit_pct FROM v$sysstat phy, v$sysstat dbg, v$sysstat cong WHERE phy.name = 'physical reads' AND dbg.name = 'db block gets' AND cong.name = 'consistent gets';
```
> OLTP: hit ratio > 95% là tốt. Nhưng đừng mê tín — nhìn absolute physical reads nữa.

**Kết quả thực tế:**
```text
BUFFER_HIT_PCT
        93.19
```
> Hơi thấp (dưới 95%), cần check advice xem cache có đang thiếu không.

### Buffer Cache Advice — Có Nên Tăng?

```sql
SELECT size_for_estimate AS cache_size_mb, size_factor, estd_physical_reads, ROUND((1 - estd_physical_read_factor) * 100, 1) AS pct_reduction FROM v$db_cache_advice WHERE name = 'DEFAULT' AND block_size = (SELECT TO_NUMBER(value) FROM v$parameter WHERE name = 'db_block_size') ORDER BY size_for_estimate;
```
**Kết quả thực tế:**
```text
CACHE_SIZE_MB   SIZE_FACTOR   ESTD_PHYSICAL_READS   PCT_REDUCTION
          80         0.0909                 22894           -18.2
         160         0.1818                 19402            -0.2
         240         0.2727                 19371               0
         320         0.3636                 19371               0
         ...            ...                  ...             ...
         880              1                 19371               0
        1600         1.8182                 19371               0
```
> **Phân tích:** Cache 240MB đã đủ chứa hết block "nóng" (19371 reads). Cache 880MB hiện tại là **dư thừa** — tăng lên 1.6GB cũng không giả thêm physical read. Nên hạ DB_CACHE_SIZE xuống ~256-320MB để dành RAM cho PGA hoặc OS.

> **Công thức:** Buffer Hit Ratio = 1 - (physical reads / (db block gets + consistent gets)).  
> 93.19% nghĩa là: 100 lần đọc → 93 lần từ cache, 7 lần xuống disk.  
> Nếu cache đủ, hit ratio sẽ cao > 95% và advice cho thấy tăng thêm không giảm physical reads.

### Keep Pool — Pin Bảng Nhỏ Vào Memory

**Khi nào dùng:** Bảng nhỏ (< 1000 blocks), rất hay được truy cập, không muốn bị đẩy ra khỏi cache vì bảng lớn khác. Ví dụ: bảng `countries`, `status_codes`, `config`.

**Không phải lúc nào cũng cần.** Chỉ dùng khi bạn thấy bảng quan trọng bị aging out vì cache không đủ.

**Thứ tự chạy:**

```sql
-- Bước 1 (SYS): Cấp riêng 64MB trong SGA cho Keep Pool
ALTER SYSTEM SET DB_KEEP_CACHE_SIZE = 64M;

-- Bước 2 (user sở hữu bảng): Đưa bảng vào Keep Pool
ALTER TABLE customers_demo STORAGE (BUFFER_POOL KEEP);

-- Bước 3 (user sở hữu bảng): Kiểm tra
SELECT segment_name, buffer_pool FROM user_segments WHERE segment_name = 'CUSTOMERS_DEMO';
```
```text
SEGMENT_NAME     BUFFER_POOL
CUSTOMERS_DEMO   KEEP
```
> **Segment** = object vật lý chiếm dung lượng (TABLE, INDEX, PARTITION...). `BUFFER_POOL = KEEP` xác nhận bảng đã được pin vào Keep Pool.

---

## 3. Shared Pool — Parsing & Dictionary Cache

Lưu: parsed SQL, execution plans, data dictionary cache.

### Library Cache Health

```sql
SELECT namespace, gets, gethits, ROUND(gethitratio * 100, 2) AS get_hit_pct, pins, pinhits, ROUND(pinhitratio * 100, 2) AS pin_hit_pct, reloads, invalidations FROM v$librarycache ORDER BY gets DESC FETCH FIRST 10 ROWS ONLY;
```

**Kết quả thực tế:**
```text
NAMESPACE            GETS   GETHITS   GET_HIT_PCT    PINS   PINHITS   PIN_HIT_PCT   RELOADS   INVALIDATIONS
TABLE/PROCEDURE     13121      9171          69.9   21418     17049         79.6       117               0
SQL AREA            10223      5703         55.79   68551     61393        89.56       262             284
SCHEMA               6590      6563         99.59       0         0          100         0               0
SQL AREA STATS       2590       142          5.48    2590       142         5.48         0               0
CLUSTER               885       859         97.06     996       970        97.39         0               0
BODY                  350       256         73.14     692       583        84.25         1               0
INDEX                 293       128         43.69     195        29        14.87         1               0
QUEUE                 287       236         82.23     290       214        73.79        23               0
TRANSFORMATION        137       136         99.27     137       136        99.27         0               0
```
> **Phân tích:**
> - **SQL AREA: GET_HIT_PCT = 55.79%** — rất thấp (chuẩn > 99%). Mỗi lần parse phải load lại SQL từ disk, không tìm thấy trong shared pool. Có **284 invalidations** — SQL bị mất khỏi cache do shared pool đầy hoặc DDL.
> - **TABLE/PROCEDURE: GET_HIT_PCT = 69.9%** — thấp. Nhiều hard parse cho PL/SQL.
> - **RELOADS = 262** — SQL bị evict khỏi cache rồi phải parse lại.
>
> **Shared pool đang thiếu hoặc bị fragment.** Hard parse nhiều — kiểm tra xem ứng dụng có dùng bind variable không, nếu không thì shared pool luôn bị chèn SQL mới.

### Dictionary Cache Miss

```sql
SELECT parameter, gets, getmisses, ROUND(getmisses / NULLIF(gets, 0) * 100, 2) AS miss_pct FROM v$rowcache WHERE gets > 0 ORDER BY getmisses DESC FETCH FIRST 10 ROWS ONLY;
```

**Kết quả thực tế:**
```text
PARAMETER                 GETS   GETMISSES   MISS_PCT
dc_histogram_defs        83647        9216      11.02
dc_histogram_data        22171        2875      12.97
dc_objects               37058        2814       7.59
dc_segments               3564        1502      42.14
dc_histogram_data         1556         267      17.16
dc_props                  1525         190      12.46
dc_users                 19210         186       0.97
dc_global_oids             890          88       9.89
dc_rollback_segments      1464          42       2.87
dc_tablespaces            1135          24       2.11
```
> **Phân tích:**
> - **dc_segments: miss 42.14%** — rất cao. Mỗi lần truy cập bảng, Oracle phải load metadata segment từ disk.
> - **dc_histogram_defs + dc_histogram_data: miss ~11-17%** — cao, do bạn vừa gather stats với histograms nên dictionary cache chưa kịp warm up.
> - **dc_objects: miss 7.59%** — hơi cao.
> - **dc_users: miss 0.97%** — OK.
> - Nguyên nhân: Database mới start, cache chưa warm up đủ, và workload đang scan nhiều object lạ.

### Shared Pool Advice

```sql
SELECT shared_pool_size_for_estimate / 1024 / 1024 AS sp_mb, estd_lc_size / 1024 / 1024 AS lc_mb, estd_lc_memory_objects, estd_lc_time_saved_factor FROM v$shared_pool_advice ORDER BY shared_pool_size_for_estimate;
```

**Kết quả thực tế:**
```text
SP_MB        LC_MB        ESTD_LC_MEMORY_OBJECTS   ESTD_LC_TIME_SAVED_FACTOR
0.000457     0.000042                         2128                      0.6939
0.000473     0.000056                         2976                      0.7662
0.000488     0.000072                         3620                      0.8441
0.000504     0.000086                         4137                      0.9202
0.000519     0.000100                         4654                           1
0.000534     0.000115                         5113                           1
...           ...                              ...                        ...
```
> **Phân tích:**
> - Từ **0.000519 MB (~0.5 KB)** cho library cache, `estd_lc_time_saved_factor = 1.0` → **shared pool hiện tại đã đủ**, tăng thêm không giúp ích gì.
> - Library cache chỉ cần ~0.5 KB để chứa hết parsed SQL — vì database là test, workload rất nhẹ.
> - Vấn đề get_hit_pct thấp (55%) không phải do shared pool thiếu, mà do **invalidations (284)** — SQL bị mất khỏi cache vì lý do khác (DDL, flush, hay do bạn chạy `EXPLAIN PLAN FOR` liên tục với SQL khác nhau, không dùng bind variable).

### Free Memory & Fragmentation

```sql
SELECT name, bytes/1024/1024 AS mb FROM v$sgastat WHERE pool = 'shared pool' AND name = 'free memory';
```

**Kết quả thực tế:**
```text
NAME                             MB
free memory     31.8169097900390625
```
> **Free memory = 31.8 MB** — shared pool còn rất nhiều chỗ trống. Không bị áp lực bộ nhớ.
>
> **Kết luận chung:** Shared pool không thiếu. Get hit pct thấp là do workload học tập: bạn chạy nhiều câu SQL khác nhau, không dùng bind variable, mỗi lần là 1 câu mới → hard parse liên tục. Trên production có bind variable, hit ratio sẽ > 99%.

### Pin Package Thường Dùng

```sql
EXEC DBMS_SHARED_POOL.KEEP('SYS.STANDARD', 'P');
SELECT owner, name, type, kept FROM v$db_object_cache WHERE kept = 'YES';
```

---

## 4. Large Pool

Dùng cho RMAN, parallel query, shared server.

```sql
SELECT name, bytes/1024/1024 AS mb FROM v$sgastat WHERE pool = 'large pool' ORDER BY bytes DESC;
ALTER SYSTEM SET LARGE_POOL_SIZE = 256M;
```

**Kết quả thực tế:**
```text
NAME                                MB
free memory                   15.15625
PX msg pool                    0.46875
ASM map operations hashta        0.375
```
> **Large pool = 16MB** (free 15MB). Rất nhỏ, nhưng đủ vì bạn không dùng RMAN parallel hay shared server. Chỉ có PX msg pool (parallel query) dùng 0.47MB.

---

## 5. Redo Log Buffer

```sql
SELECT name, bytes/1024 AS kb FROM v$sgainfo WHERE name = 'Redo Buffers';
SELECT name, value FROM v$sysstat WHERE name IN ('redo log space requests', 'redo buffer allocation retries');
```

**Kết quả thực tế:**
```text
Redo Buffers     7460 KB (~7.3MB)
redo buffer allocation retries         0
redo log space requests                0
```
> **Redo buffer = 7.3MB**, cả 2 counter đều = 0 → không có contention. Redo buffer đủ lớn cho workload hiện tại.

---

## 6. SGA Target Advice — Có Nên Tăng SGA?

```sql
SELECT sga_size AS sga_mb, sga_size_factor, estd_db_time, estd_db_time_factor, estd_physical_reads FROM v$sga_target_advice ORDER BY sga_size;
```

**Kết quả thực tế:**
```text
SGA_MB   SIZE_FACTOR   ESTD_DB_TIME   ESTD_DB_TIME_FACTOR   ESTD_PHYSICAL_READS
  768           0.50            123                3.4167                 23597
 1152           0.75             36                     1                 19766
 1536              1             36                     1                 19766
 1920           1.25             36                     1                 19766
 2304            1.5             36                     1                 19766
 2688           1.75             36                     1                 19766
 3072              2             36                     1                 19766
```
> **Phân tích:**
> - **SGA 768MB (0.5x):** db_time = 123 (gấp 3.4 lần) — quá nhỏ, physical reads cao.
> - **SGA 1152MB (0.75x):** db_time = 36, physical reads = 19766 — **đã đủ**.
> - **SGA 1536MB → 3072MB (1x → 2x):** db_time và physical reads **không đổi**.
> - **Kết luận:** SGA hiện tại (1536MB = 1.5GB) đã thừa. Có thể giảm xuống **1152MB** mà không ảnh hưởng hiệu năng. Buffer cache 240MB là đủ, 816MB là lãng phí.

## 7. ASMM và Minimum Size

Với ASMM (`SGA_TARGET > 0`), các tham số như `DB_CACHE_SIZE` chỉ là **minimum**, Oracle có thể giữ cao hơn.

```sql
ALTER SYSTEM SET DB_CACHE_SIZE = 512M;
SELECT component, current_size/1024/1024 AS mb FROM v$sga_dynamic_components WHERE component = 'DEFAULT buffer cache';
```

```text
COMPONENT                 MB
DEFAULT buffer cache     816
```

> `DB_CACHE_SIZE = 512M` nhưng Oracle vẫn giữ 816MB vì:
> - Shared pool còn 32MB free → không có áp lực bộ nhớ
> - Oracle không thu hẹp component khi không cần
> - Nếu muốn Oracle thu hẹp ngay, cần tạo áp lực hoặc đặt `DB_CACHE_SIZE` thấp hơn và restart

Để thực sự ép Oracle giảm, có thể:
```sql
-- Đặt sga_target thấp hơn (ví dụ 1152MB)
ALTER SYSTEM SET SGA_TARGET = 1152M;
-- Hoặc đặt DB_CACHE_SIZE và restart
ALTER SYSTEM SET DB_CACHE_SIZE = 256M SCOPE = SPFILE;
-- (cần restart instance)
```

---

## 7. Thực Hành: Tuning Buffer Cache

**Bước 1 — Check hiện tại:**
```sql
SELECT component, current_size/1024/1024 AS mb FROM v$sga_dynamic_components WHERE component = 'DEFAULT buffer cache';
```

**Bước 2 — Check advice:**
```sql
SELECT size_for_estimate, estd_physical_reads, estd_physical_read_factor FROM v$db_cache_advice WHERE name = 'DEFAULT' ORDER BY size_for_estimate;
```

**Bước 3 — Tăng (nếu cần):**
```sql
ALTER SYSTEM SET DB_CACHE_SIZE = 512M;
```

**Bước 4 — Verify change:**
```sql
SELECT component, current_size/1024/1024 AS mb FROM v$sga_dynamic_components WHERE component = 'DEFAULT buffer cache';
```

---

## Tổng Kết

| Component | View để check | Advice | Khi nào tăng |
|:---|:---|:---|:---|
| Buffer Cache | `v$sysstat` physical reads | `v$db_cache_advice` | Hit ratio < 95%, advice cho thấy giảm reads nhiều |
| Shared Pool | `v$librarycache` reloads | `v$shared_pool_advice` | reloads > 0, hard parse nhiều |
| Large Pool | `v$sgastat` | — | Có RMAN parallel hoặc shared server |
| Redo Log Buffer | `v$sysstat` redo log space requests | — | requests > 0 |

---

## 8. Production Checklist & Emergency

### Checklist Khi Lên Production

```text
[ ] SGA_TARGET có đủ không?     → v$sga_target_advice (db_time_factor 1.0 là ổn)
[ ] PGA có bị overalloc không?   → v$pga_target_advice (overalloc_count = 0)
[ ] Buffer cache hit ratio?      → > 95% cho OLTP
[ ] Sorts (disk) có > 1%?        → v$sysstat (gần 0 là tốt)
[ ] Shared pool có bị ORA-04031? → v$sgastat free memory > 0
[ ] Redo log space requests?     → = 0 là tốt
[ ] Hard parse có nhiều?         → v$librarycache get_hit_pct > 99%
[ ] Row cache miss?              → v$rowcache miss_pct < 2%
[ ] Có Index cho mọi FK?         → dba_constraints + dba_indexes
[ ] Histograms cho cột skew?     → dba_tab_col_statistics
```

### Free Alternative (Không Cần AWR License)

```text
Top SQL:
→ SELECT sql_id, ROUND(elapsed_time/1000000,2) AS sec, executions, sql_text FROM v$sql ORDER BY elapsed_time DESC FETCH FIRST 10 ROWS ONLY;

Plan + actual stats:
→ SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('sql_id', FORMAT => 'ALLSTATS LAST'));

SQL Monitor (nếu có license):
→ SELECT DBMS_SQLTUNE.REPORT_SQL_MONITOR(sql_id => 'sql_id', type => 'TEXT') FROM dual;

Top wait events:
→ SELECT event, total_waits, time_waited_micro/1000000 AS wait_sec FROM v$system_event WHERE wait_class != 'Idle' ORDER BY time_waited_micro DESC FETCH FIRST 10 ROWS ONLY;

Session đang chờ gì:
→ SELECT sid, event, wait_class, seconds_in_wait FROM v$session WHERE wait_class != 'Idle' AND state = 'WAITING' ORDER BY seconds_in_wait DESC;

Blocking:
→ SELECT sid, blocking_session, wait_class, event FROM v$session WHERE blocking_session > 0;

Alert log:
→ tail -200 $ORACLE_BASE/diag/rdbms/*/trace/alert_*.log
```

### Khi Gặp Sự Cố (Emergency)

```text
1. CPU 100% ?
   → SELECT sql_id, cpu_time FROM v$sql ORDER BY cpu_time DESC FETCH FIRST 5 ROWS ONLY;

2. Query chạy chậm bất thường ?
   → DBMS_XPLAN.DISPLAY_CURSOR('sql_id', FORMAT => 'ALLSTATS LAST')
   → So sánh E-Rows vs A-Rows (lệch > 10x là statistics sai hoặc histograms thiếu)

3. ORA-04031 (shared pool) ?
   → v$sgastat WHERE pool = 'shared pool'; tăng SHARED_POOL_SIZE

4. ORA-01652 (TEMP hết) ?
   → v$sort_usage; tăng PGA_AGGREGATE_TARGET

5. Buffer busy waits / Free buffer waits ?
   → Check v$db_cache_advice, tăng DB_CACHE_SIZE

6. LOG_FILE_SYNC chậm ?
   → Commit nhiều? redo log disk chậm? Check redo log space requests

7. Instance treo / không start được ?
   → tail -200 $ORACLE_BASE/diag/rdbms/*/trace/alert_*.log
```
