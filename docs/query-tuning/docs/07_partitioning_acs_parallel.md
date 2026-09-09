# Lesson 7: Partitioning, Adaptive Cursor Sharing & Parallel Execution

Bài học này tổng hợp 3 kỹ thuật nâng cao khi bảng quá lớn, index không còn đủ, hoặc Full Table Scan là bắt buộc.

---

## Phần 1: Partitioning & Partition Pruning

### 1. Khi Nào Cần Partition

Khi bảng > 10-50GB, index dù có cũng không giúp ích cho các query quét lịch sử (vd: bảng orders 1 tỷ dòng, query theo tháng).

### 2. Partition Types Cơ Bản

**Range Partition — phổ biến nhất:**
```sql
CREATE TABLE orders_part (
    order_id NUMBER,
    order_date DATE,
    total_amount NUMBER,
    status VARCHAR2(20)
)
PARTITION BY RANGE (order_date) (
    PARTITION p_2024_q1 VALUES LESS THAN (DATE '2024-04-01'),
    PARTITION p_2024_q2 VALUES LESS THAN (DATE '2024-07-01'),
    PARTITION p_2024_q3 VALUES LESS THAN (DATE '2024-10-01'),
    PARTITION p_2024_q4 VALUES LESS THAN (DATE '2025-01-01'),
    PARTITION p_future VALUES LESS THAN (MAXVALUE)
);
```

**List Partition — cho cột trạng thái:**
```sql
CREATE TABLE orders_list (
    order_id NUMBER,
    region VARCHAR2(20),
    total_amount NUMBER
)
PARTITION BY LIST (region) (
    PARTITION p_north VALUES ('NORTH', 'NE', 'NW'),
    PARTITION p_south VALUES ('SOUTH', 'SE', 'SW'),
    PARTITION p_other VALUES (DEFAULT)
);
```

### 3. Partition Pruning — Tự Động Bỏ Partition Không Cần

```sql
-- Oracle chỉ đọc partition p_2024_q4, không đụng 4 partition còn lại
EXPLAIN PLAN FOR SELECT COUNT(*) FROM orders_part WHERE order_date >= DATE '2024-10-01' AND order_date < DATE '2025-01-01';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

Plan sẽ hiện `PARTITION RANGE SINGLE` hoặc `PARTITION RANGE ITERATOR` — chỉ scan đúng partition liên quan.

### 4. Local Index vs Global Index

```sql
-- Local Index: mỗi partition có index riêng (dễ maintain)
CREATE INDEX idx_orders_part_date ON orders_part(order_date) LOCAL;

-- Global Index: index trên toàn bộ table (giống index thường)
CREATE INDEX idx_orders_part_id ON orders_part(order_id) GLOBAL;
```

**Local Index:** Khi DROP/TRUNCATE partition, index vẫn sống (DBA mơ ước).  
**Global Index:** Phải rebuild sau DDL.

### 5. Thực Hành: So Sánh Query Có vs Không Partition Pruning

```sql
-- Không partition pruning (sai format)
EXPLAIN PLAN FOR SELECT COUNT(*) FROM orders_part WHERE order_date = TO_DATE('2024-10-15', 'YYYY-MM-DD');
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Có partition pruning (range)
EXPLAIN PLAN FOR SELECT COUNT(*) FROM orders_part WHERE order_date >= DATE '2024-10-01' AND order_date < DATE '2025-01-01';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

---

## Phần 2: Adaptive Cursor Sharing (ACS)

### 0. Kiến Thức Nền: Literal, Hard Parse, Soft Parse, Bind Variable

**Literal** — giá trị viết thẳng trong câu SQL:
```sql
SELECT * FROM customers WHERE id = 123;   -- 123 là literal
```

**Parse** — Oracle đọc câu SQL, kiểm tra cú pháp, object tồn tại, tìm execution plan.

**Hard parse** — SQL chưa có trong shared pool, phải parse từ đầu (tìm plan, tối ưu) → tốn CPU, tốn latch, chậm.
```sql
SELECT * FROM customers WHERE id = 123;  -- hard parse
SELECT * FROM customers WHERE id = 456;  -- hard parse (câu khác)
```

**Soft parse** — SQL đã có trong shared pool rồi, lấy plan ra xài lại → nhanh, rẻ.
```sql
SELECT * FROM customers WHERE id = :id;  -- parse 1 lần, xài mãi
```

**Bind variable** — dùng `:id` thay vì literal, giúp 1 câu SQL dùng chung cho mọi giá trị → tránh hard parse.

```sql
-- Không bind: mỗi ID là 1 câu SQL mới → 1M hard parse → CPU chết
SELECT * FROM logs WHERE user_id = 1;
SELECT * FROM logs WHERE user_id = 2;
...

-- Có bind: 1 câu SQL → 1 lần parse, 1M user xài chung
SELECT * FROM logs WHERE user_id = :id;
```

**Vấn đề:** Bind variable tiết kiệm CPU nhưng chỉ tạo 1 plan — nếu data skew (FRAUD 1%, NORMAL 99%), 1 plan không thể tối ưu cho cả 2.

**ACS = Bind + nhiều plan** — giữ lợi ích của bind (1 parse) + tạo plan riêng cho từng giá trị skew.

### 1. Vấn Đề: Bind Variable + Data Skew

Cột `order_status` có 10000 CANCELLED + 90000 COMPLETED. Khi dùng bind, Oracle tạo 1 plan duy nhất — không biết lúc nào là ít (CANCELLED nên dùng INDEX) lúc nào là nhiều (COMPLETED nên dùng FULL SCAN).

### 2. Demo ACS — Copy Cả Khối Này, Paste Vào Terminal Chạy Từng Dòng

#### 👉 LỆNH ĐẦU TIÊN — CHẠY CÁI NÀY TRƯỚC:
```sql
VARIABLE v_status VARCHAR2(20);
```

#### Sau đó chạy lần lượt các lệnh dưới đây:

```sql
SELECT order_status, COUNT(*) FROM orders_demo GROUP BY order_status;
EXEC :v_status := 'CANCELLED';
SELECT /* ACS_BI */ * FROM orders_demo WHERE order_status = :v_status;
EXEC :v_status := 'COMPLETED';
SELECT /* ACS_BI */ * FROM orders_demo WHERE order_status = :v_status;
EXEC DBMS_STATS.GATHER_TABLE_STATS(user, 'ORDERS_DEMO', method_opt => 'FOR ALL COLUMNS SIZE SKEWONLY');
VARIABLE v_status VARCHAR2(20);
EXEC :v_status := 'CANCELLED';
SELECT /* ACS_BI */ * FROM orders_demo WHERE order_status = :v_status;
EXEC :v_status := 'COMPLETED';
SELECT /* ACS_BI */ * FROM orders_demo WHERE order_status = :v_status;
EXEC :v_status := 'CANCELLED';
SELECT /* ACS_BI */ * FROM orders_demo WHERE order_status = :v_status;
EXEC :v_status := 'COMPLETED';
SELECT /* ACS_BI */ * FROM orders_demo WHERE order_status = :v_status;
```

#### Check kết quả:

```sql
SELECT sql_id, child_number, plan_hash_value, executions, is_bind_sensitive, is_bind_aware FROM v$sql WHERE sql_text LIKE '%ACS_BI%' AND sql_text NOT LIKE '%v$sql%' ORDER BY child_number;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'SQL_ID_ACS_BI', cursor_child_no => 0, format => 'ALLSTATS LAST'));
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'SQL_ID_ACS_BI', cursor_child_no => 1, format => 'ALLSTATS LAST'));
```

### 3. Kết Quả Thực Tế Lab Của Bạn

#### Query chạy:
```sql
SELECT /* ACS_BI */ * FROM orders_demo WHERE order_status = :v_status;
```

#### Dữ liệu:
```
ORDER_STATUS     COUNT(*)
CANCELLED           10000
COMPLETED           90000
```

#### Sau 6 lần chạy (3 lần CANCELLED + 3 lần COMPLETED):
```
SQL_ID            CHILD_NUMBER   PLAN_HASH_VALUE   EXECUTIONS   IS_BIND_SENSITIVE   IS_BIND_AWARE
gydp4xqk7zf64                0        4033692512            6   Y                   N
```

- **is_bind_sensitive = Y** — Oracle biết có bind variable, đang track
- **is_bind_aware = N** — ACS chưa kick in, chỉ có 1 child plan duy nhất

#### Plan duy nhất cho cả 2 giá trị (INDEX RANGE SCAN):
```
--------------------------------------------------------------------------
| Id  | Operation                           | Name              | E-Rows |
--------------------------------------------------------------------------
|   0 | SELECT STATEMENT                    |                   |        |
|   1 |  TABLE ACCESS BY INDEX ROWID BATCHED| ORDERS_DEMO       |  10000 |
|*  2 |   INDEX RANGE SCAN                  | IDX_ORDERS_STATUS |  10000 |
--------------------------------------------------------------------------
Predicate: access("ORDER_STATUS"=:V_STATUS)
```

#### Khi thêm hint gather_plan_statistics và chạy COMPLETED:
```
| Id  | Operation         | Name        | Starts | E-Rows | A-Rows |   A-Time   | Buffers |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |             |      1 |        |  90000 |00:00:00.03 |    6582 |
|*  1 |  TABLE ACCESS FULL| ORDERS_DEMO |      1 |  90000 |  90000 |00:00:00.03 |    6582 |
```
- FULL TABLE SCAN cho COMPLETED (90000 rows) chỉ mất 0.03s

#### Kiểm tra histogram ACS:
```
v$sql_cs_histogram WHERE sql_id = 'gydp4xqk7zf64':

BUCKET_ID   COUNT
        0       0
        1       3
        2       0
```
Bucket 1 count = 3 — đã track được 3 lần execution

#### Kết luận:
- Cả INDEX scan và FULL scan đều nhanh như nhau (0.03s) trên bảng 100K dòng
- Oracle không thấy lý do gì để tạo plan riêng — ACS không kick in
- ACS chỉ thực sự hoạt động khi bảng lớn (triệu dòng), INDEX scan 90000 dòng chậm hơn FULL SCAN rõ rệt

### 3. Extended Statistics Cho Bind Variable

```sql
-- Dạy ACS biết distribution của cột
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS_DEMO', method_opt => 'FOR ALL COLUMNS SIZE SKEWONLY');
```

### 4. Khi Nào ACS Không Giúp?

- Câu query phức tạp, nhiều bảng join — ACS chỉ track bind của 1 cột
- Bind variable là số (NUMBER) — Oracle khó phân biệt "ít" vs "nhiều"
- Có hint hardcode trong query → ACS bị vô hiệu

---

## Phần 3: Parallel Execution

### 1. Khi Nào Dùng Parallel

**Cần parallel:**
- `Full Table Scan + GROUP BY` — báo cáo, sum, count trên triệu dòng
- `ALTER INDEX ... REBUILD PARALLEL 4` — rebuild index bảng lớn
- `INSERT /*+ APPEND PARALLEL(8) */ INTO ... SELECT ...` — data loading
- `CREATE TABLE ... AS SELECT ... PARALLEL 4` — tạo bảng từ query
- `Hash Join` — join 2 bảng lớn full scan
- `Sort + Order By` — sort dữ liệu lớn

**Không cần parallel:**
- OLTP — `SELECT * FROM orders WHERE id = 123` (1 thread đủ)
- Bảng nhỏ < 1M dòng — serial nhanh hơn vì không có overhead
- Query dùng index — index scan không parallel được
- PGA đang thiếu — parallel làm overalloc nặng hơn

### 2. Kiểm Tra Trước Khi Chạy Parallel

```sql
-- 1. PGA có đủ không?
SELECT name, value/1024/1024 AS mb FROM v$pgastat WHERE name IN ('aggregate PGA target parameter', 'total PGA inuse', 'total freeable PGA memory');

-- 2. Large Pool có cho PX msg không?
SELECT pool, name, bytes/1024/1024 AS mb FROM v$sgastat WHERE pool = 'large pool';

-- 3. Parallel max servers?
SELECT name, value FROM v$parameter WHERE name IN ('parallel_max_servers', 'parallel_degree_limit');

-- 4. Table có bao nhiêu dòng? (thay QUERY_TUNING bằng schema của bạn)
SELECT COUNT(*) FROM query_tuning.orders_demo;
```

#### Phân tích kết quả:

| Thông số | Giá trị lab | Ý nghĩa | OK? |
|----------|:-----------:|---------|:---:|
| `aggregate PGA target parameter` | 512MB | PGA mục tiêu | ✅ |
| `total PGA inuse` | 702MB | PGA đang xài | ❌ vượt target |
| `total freeable PGA memory` | 103MB | Có thể free | ✅ |
| `large pool free memory` | 15MB | Đủ cho PX msg | ✅ |
| `parallel_max_servers` | 40 | Tối đa 40 slave | ✅ |
| `parallel_degree_limit` | CPU | Giới hạn theo core | ✅ |
| `COUNT(*)` | 100K | Bảng nhỏ | ⚠️ dễ suppress |

> **PGA đang thiếu** (inuse 702MB > target 512MB) — chạy parallel degree cao sẽ làm overalloc nặng hơn. Nên dùng degree thấp (2-4) hoặc tăng PGA target trước.

> **Lưu ý RAC Multitenant:** PDB's `pga_aggregate_target` không được lớn hơn CDB root. Cần check CDB root trước, rồi set PDB ≤ CDB root. Nếu CDB root = 512MB, PDB max = 512MB.

**Kết quả lab từ `v$pga_target_advice`:**
```text
PGA_TARGET_FACTOR   ESTD_OVERALLOC_COUNT
              1.0                      3   ← hiện tại (512MB)
              1.4                      1   ← gần hết
              1.6                      0   ← đủ!
```
Cần tăng PGA target lên factor 1.6 (~820MB) để overalloc_count = 0. Nhưng PDB không thể vượt CDB root → tăng CDB root trước.

### 3. Cách Dùng

```sql
-- Hint parallel
EXPLAIN PLAN FOR SELECT /*+ PARALLEL(2) */ COUNT(*), order_status FROM orders_demo GROUP BY order_status;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

#### Kết quả thực tế lab:

```text
---------------------------------------------------------------------------------------------------------------------
| Id  | Operation                | Name        | Rows  | Cost (%CPU)|    TQ  |IN-OUT| PQ Distrib |
---------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT         |             |     2 |    97   (4)|        |      |            |
|   1 |  PX COORDINATOR          |             |       |            |        |      |            |
|   2 |   PX SEND QC (RANDOM)    | :TQ10001    |     2 |    97   (4)| Q1,01 | P->S | QC (RAND)  |
|   3 |    HASH GROUP BY         |             |     2 |    97   (4)| Q1,01 | PCWP |            |
|   4 |     PX RECEIVE           |             |     2 |    97   (4)| Q1,01 | PCWP |            |
|   5 |      PX SEND HASH        | :TQ10000    |     2 |    97   (4)| Q1,00 | P->P | HASH       |
|   6 |       HASH GROUP BY      |             |     2 |    97   (4)| Q1,00 | PCWP |            |
|   7 |        PX BLOCK ITERATOR |             |   100K|    95   (2)| Q1,00 | PCWC |            |
|   8 |         TABLE ACCESS FULL| ORDERS_DEMO |   100K|    95   (2)| Q1,00 | PCWP |            |
---------------------------------------------------------------------------------------------------------------------
Note: Degree of Parallelism is 2 because of hint
```

> `PX COORDINATOR` → parallel chạy thành công. `PX SEND/RECEIVE` → 2 slave giao tiếp. `PX BLOCK ITERATOR` → full scan chia đều cho 2 slave. Không bị suppress dù PGA đang thiếu vì GROUP BY + FULL SCAN là workload lý tưởng cho parallel.

#### ⚠️ PGA Overalloc — Phát Hiện Khi Chạy Parallel

Khi kiểm tra PGA để chuẩn bị chạy parallel, phát hiện:

```text
aggregate PGA target parameter       512MB
total PGA inuse                      702MB  ← vượt target
overalloc_count = 3
```

PGA thiếu — Nếu chạy parallel degree cao sẽ overalloc nặng hơn. Nên tune PGA trước:

```sql
-- CDB root
ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER SYSTEM SET PGA_AGGREGATE_TARGET = 2G;
ALTER SYSTEM SET PGA_AGGREGATE_LIMIT = 4G;

-- PDB1
ALTER SESSION SET CONTAINER = PDB1;
ALTER SYSTEM SET PGA_AGGREGATE_TARGET = 1G;
ALTER SYSTEM SET PGA_AGGREGATE_LIMIT = 4G;
```

> Lưu ý: Trên RAC Multitenant, PDB's `pga_aggregate_target` ≤ CDB root's. Phải tăng CDB root trước rồi mới tăng PDB.

```sql
-- Set session level
ALTER SESSION SET parallel_degree_policy = AUTO;

-- Force parallel cho table
ALTER TABLE orders_demo PARALLEL 4;
```

### 4. Các Thông Số Quan Trọng

```sql
SELECT name, value FROM v$parameter WHERE name LIKE '%parallel%';
```

-- Quan trọng:
-- parallel_degree_limit — giới hạn
-- parallel_max_servers — tối đa slave
-- parallel_min_percent — % tối thiểu slave yêu cầu
```

### 4. Cạm Bẫy: Parallel Suppress

Parallel bị vô hiệu khi:
- **Full Table Scan không được chọn** — Oracle dùng index
- **Serial DML** — `INSERT` không có `/*+ APPEND */`
- **Query có hàm PL/SQL** — không thể parallel
- **Quá ít dữ liệu** — Oracle thấy 1 thread đủ nhanh rồi

```sql
-- Kiểm tra parallel suppress
EXPLAIN PLAN FOR SELECT /*+ PARALLEL(4) */ COUNT(*) FROM customers_demo;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Nếu không có PX COORDINATOR → parallel bị suppress
```

---

## Problem / Issue Phát Hiện Trong Lab

**Issue:** PGA overalloc — `total PGA inuse (689MB) > pga_aggregate_target (512MB)`, `overalloc_count = 3`.

**Phát hiện khi:** Check PGA trước khi chạy parallel test.

**Nguyên nhân:** CDB root target quá thấp (512MB), không đủ cho các session.

**Fix:**
```sql
-- CDB root
ALTER SYSTEM SET PGA_AGGREGATE_TARGET = 2G;
ALTER SYSTEM SET PGA_AGGREGATE_LIMIT = 4G;
-- PDB1
ALTER SYSTEM SET PGA_AGGREGATE_TARGET = 1G;
ALTER SYSTEM SET PGA_AGGREGATE_LIMIT = 4G;
```

**Kết quả:** `overalloc_count = 0`, PGA inuse (689MB) < target (2048MB).

**Bài học:** Luôn check PGA/SGA trước khi chạy parallel. Parallel không chỉ là thêm `/*+ PARALLEL */` — nó đòi hỏi PGA và Large Pool đủ.

---

## Tổng Kết Bài 7

| Kỹ thuật | Khi dùng | Lợi ích |
|:---|:---|:---|
| **Partitioning** | Bảng > 10-50GB, query theo range | Chỉ scan partition cần, DROP/TRUNCATE partition nhanh |
| **Adaptive Cursor Sharing** | Bind variable + data skew | Tự động tạo nhiều plan cho cùng 1 câu SQL |
| **Parallel Execution** | OLAP/Full Scan lớn, rebuild index | Chia công việc cho nhiều CPU, giảm thời gian |

**Bài tiếp theo:** [Lesson 8: SQL Runtime Diagnostics](08_sql_runtime_diagnostics.md) — tìm top SQL, xem plan thật bằng `DISPLAY_CURSOR`, đọc wait event và kết luận nguyên nhân SQL chậm.
