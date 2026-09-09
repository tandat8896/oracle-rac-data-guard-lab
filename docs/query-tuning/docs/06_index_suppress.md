# Lesson 6: Index Suppress — Khi Developer Vô Tình "Phá" Index Của DBA

Bài học này ghi lại các thực nghiệm chứng minh hiện tượng **Index Suppress**: Index đã tạo nhưng Oracle không thể dùng vì câu query bị viết sai cách — và cách DBA giải quyết bằng Function-Based Index.

---

## Kịch Bản 1: Hàm TRUNC() Vô Hiệu Hóa Index Trên order_date

**Setup:** Tạo index thường trên `order_date`:
```sql
CREATE INDEX idx_order_date ON orders_demo(order_date);
```

---

### Trạng Thái 1: Developer Dùng TRUNC() — Index Bị Suppress

Developer quen viết `TRUNC(order_date)` để so sánh ngày, bỏ qua giờ phút giây:
```sql
EXPLAIN PLAN FOR SELECT COUNT(*) FROM orders_demo WHERE TRUNC(order_date) = DATE '2025-10-31';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```
```text
| Id  | Operation             | Name           | Rows  | Cost (%CPU)|
|*  2 |   INDEX FAST FULL SCAN| IDX_ORDER_DATE |  1000 |    77   (4)|

filter(TRUNC(INTERNAL_FUNCTION("ORDER_DATE"))=TO_DATE('2025-10-31 00:00:00'...))
```
*   **INDEX FAST FULL SCAN (Cost 77):** Oracle biết không thể tra index theo giá trị TRUNC, nên đọc **toàn bộ index** từ đầu đến cuối rồi áp `TRUNC()` từng entry một.
*   **E-Rows: 1000** — CBO ước tính sai vì không tính được kết quả của hàm TRUNC trước.
*   **Thực tế:** Bảng có 274 dòng ngày `2025-10-31` nhưng Oracle phải duyệt 100,000 entries index để tìm ra.

---

### Trạng Thái 2: DBA Viết Lại Query Dạng Range — Index Hoạt Động

```sql
EXPLAIN PLAN FOR SELECT COUNT(*) FROM orders_demo WHERE order_date >= DATE '2025-10-31' AND order_date < DATE '2025-11-01';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```
```text
| Id  | Operation         | Name           | Rows  | Cost (%CPU)|
|*  2 |   INDEX RANGE SCAN| IDX_ORDER_DATE |   267 |     2   (0)|

access("ORDER_DATE">=TO_DATE('2025-10-31 00:00:00'...) AND "ORDER_DATE"<TO_DATE('2025-11-01 00:00:00'...))
```
*   **INDEX RANGE SCAN (Cost 2):** Oracle nhảy thẳng vào đúng vùng ngày `2025-10-31` trong index.
*   **E-Rows: 267** — ước tính chính xác (thực tế 274).
*   **Nhanh hơn 38 lần** so với Trạng Thái 1.

**Nguyên lý:** Oracle DATE luôn chứa cả giờ phút giây (vd: `2025-10-31 14:35:22`). Index lưu giá trị gốc có giờ. Khi dùng `TRUNC()` trên cột, Oracle không thể tra index vì không biết kết quả hàm trước khi đọc từng dòng.

---

### Trạng Thái 3: DBA Tạo Function-Based Index — Câu Query Gốc Chạy Được

Khi **không sửa được code ứng dụng** (đã deploy, developer không hợp tác), DBA dùng FBI:
```sql
CREATE INDEX idx_fbi_trunc_order_date ON orders_demo(TRUNC(order_date));
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS_DEMO', cascade => TRUE);
```

Chạy lại câu query gốc của developer (không sửa gì):
```sql
EXPLAIN PLAN FOR SELECT COUNT(*) FROM orders_demo WHERE TRUNC(order_date) = DATE '2025-10-31';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```
```text
| Id  | Operation         | Name                     | Rows  | Cost (%CPU)|
|*  2 |   INDEX RANGE SCAN| IDX_FBI_TRUNC_ORDER_DATE |  1000 |     1   (0)|

access(TRUNC(INTERNAL_FUNCTION("ORDER_DATE"))=TO_DATE('2025-10-31 00:00:00'...))
```
*   **INDEX RANGE SCAN (Cost 1)** trên FBI — Oracle tra thẳng vào index đã lưu sẵn kết quả `TRUNC`.
*   Nhanh hơn cả câu viết đúng dạng range (Cost 2).

**Tổng kết Kịch Bản 1:**

| Trạng thái | Operation | Cost |
|---|---|---|
| TRUNC() không có FBI | INDEX FAST FULL SCAN | 77 |
| Range >= < | INDEX RANGE SCAN | 2 |
| TRUNC() có FBI | INDEX RANGE SCAN | **1** |

---

## Kịch Bản 2: Phép Toán Số Học Trên Cột Có Index

**Setup:**
```sql
CREATE INDEX idx_total_amount ON orders_demo(total_amount);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS_DEMO', cascade => TRUE);
```

---

### Trạng Thái 1: total_amount * 1.1 > 1000 — Index Bị Suppress

Developer viết phép tính `total_amount * 1.1` ngay trên cột WHERE:

```sql
EXPLAIN PLAN FOR SELECT COUNT(*) FROM orders_demo WHERE total_amount * 1.1 > 1000;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```
```text
----------------------------------------------------------------------------------
| Id  | Operation          | Name        | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |             |     1 |     4 |   171   (1)| 00:00:01 |
|   1 |  SORT AGGREGATE    |             |     1 |     4 |            |          |
|*  2 |   TABLE ACCESS FULL| ORDERS_DEMO |  5000 | 20000 |   171   (1)| 00:00:01 |
----------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter("TOTAL_AMOUNT"*1.1>1000)
```
*   **TABLE ACCESS FULL (Cost 171):** Oracle không thể tra index `IDX_TOTAL_AMOUNT` vì giá trị index lưu là `total_amount` thô, không phải `total_amount * 1.1`.
*   **E-Rows: 5000** — Optimizer ước tính 5000 dòng thỏa mãn, buộc phải quét toàn bộ bảng.

---

### Trạng Thái 2: total_amount > 1000 / 1.1 — Index Hoạt Động

Chuyển phép tính sang vế phải, giữ cột `total_amount` "sạch":

```sql
EXPLAIN PLAN FOR SELECT COUNT(*) FROM orders_demo WHERE total_amount > 1000 / 1.1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```
```text
--------------------------------------------------------------------------------------
| Id  | Operation         | Name             | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |                  |     1 |     4 |    20   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE   |                  |     1 |     4 |            |          |
|*  2 |   INDEX RANGE SCAN| IDX_TOTAL_AMOUNT |  9000 | 36000 |    20   (0)| 00:00:01 |
--------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("TOTAL_AMOUNT">909.090909090909090909090909090909090909)
```
*   **INDEX RANGE SCAN (Cost 20):** Oracle tính `1000/1.1 = 909.09` trước, rồi dùng index để tra thẳng các dòng có `total_amount > 909.09`.
*   **Nhanh hơn 8.5 lần** so với Trạng Thái 1 (Cost 20 vs 171).

**Tổng kết Kịch Bản 2:**

| Trạng thái | Operation | Cost |
|---|---|---|
| `total_amount * 1.1 > 1000` | TABLE ACCESS FULL | 171 |
| `total_amount > 1000 / 1.1` | INDEX RANGE SCAN | **20** |

---

## Kịch Bản 3: Ngầm Chuyển Kiểu Dữ Liệu (Implicit Type Conversion)

Cột `order_status` là `VARCHAR2(20)`. `IDX_ORDERS_STATUS` đã có từ Lesson 2.

---

### Trạng Thái 1: Truyền Số (order_status = 1) — Index Bị Suppress

```sql
EXPLAIN PLAN FOR SELECT COUNT(*) FROM orders_demo WHERE order_status = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```
```text
----------------------------------------------------------------------------------
| Id  | Operation          | Name        | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |             |     1 |    10 |   171   (1)| 00:00:01 |
|   1 |  SORT AGGREGATE    |             |     1 |    10 |            |          |
|*  2 |   TABLE ACCESS FULL| ORDERS_DEMO |     1 |    10 |   171   (1)| 00:00:01 |
----------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter(TO_NUMBER("ORDER_STATUS")=1)
```
*   **TABLE ACCESS FULL (Cost 171):** Oracle thấy cột `VARCHAR2` so sánh với số `1` nên ngầm chạy `TO_NUMBER("ORDER_STATUS")` trên mỗi dòng. Hàm này suppress index hoàn toàn.
*   **filter(...)** — Không phải `access(...)` vì Oracle phải tính `TO_NUMBER` từng dòng, không thể dùng index.

---

### Trạng Thái 2: Đúng Kiểu VARCHAR2 (order_status = 'CANCELLED') — Index Hoạt Động

```sql
EXPLAIN PLAN FOR SELECT COUNT(*) FROM orders_demo WHERE order_status = 'CANCELLED';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```
```text
---------------------------------------------------------------------------------------
| Id  | Operation         | Name              | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |                   |     1 |    10 |    30   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE   |                   |     1 |    10 |            |          |
|*  2 |   INDEX RANGE SCAN| IDX_ORDERS_STATUS | 10000 |    97K|    30   (0)| 00:00:01 |
---------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("ORDER_STATUS"='CANCELLED')
```
*   **INDEX RANGE SCAN (Cost 30):** Kiểu dữ liệu khớp (`VARCHAR2` = `'CANCELLED'`), Oracle dùng index ngay.
*   **Nhanh hơn 5.7 lần** so với Trạng Thái 1 (Cost 30 vs 171).

**Tổng kết Kịch Bản 3:**

| Trạng thái | Operation | Cost |
|---|---|---|
| `order_status = 1` (sai kiểu) | TABLE ACCESS FULL | 171 |
| `order_status = 'CANCELLED'` (đúng kiểu) | INDEX RANGE SCAN | **30** |

---

## Kịch Bản 4: LIKE Với Wildcard Dẫn Đầu

**Setup:**
```sql
CREATE INDEX idx_cust_name ON customers_demo(customer_name);
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'CUSTOMERS_DEMO', cascade => TRUE);
```

> ⚠️ **Lưu ý:** Với `COUNT(*)`, Oracle chỉ việc quét index để đếm — không cần đụng table — nên cả 2 trường hợp đều dùng `INDEX FAST FULL SCAN` (Cost 7). Sự khác biệt chỉ rõ khi truy xuất dữ liệu thật (`SELECT *`). Xem bên dưới.

### Trạng Thái 1: SELECT * — '%_100' — Full Table Scan

```sql
EXPLAIN PLAN FOR SELECT * FROM customers_demo WHERE customer_name LIKE '%_100';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```
```text
------------------------------------------------------------------------------------
| Id  | Operation         | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |                |   250 |  6750 |     9   (0)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| CUSTOMERS_DEMO |   250 |  6750 |     9   (0)| 00:00:01 |
------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter("CUSTOMER_NAME" LIKE '%_100' AND "CUSTOMER_NAME" IS NOT NULL)
```
*   **TABLE ACCESS FULL (Cost 9):** `%` ở đầu nên Oracle không thể dùng index — quét toàn bộ bảng.

### Trạng Thái 2: SELECT * — 'Customer_%' — Full Table Scan (Giống!)

```sql
EXPLAIN PLAN FOR SELECT * FROM customers_demo WHERE customer_name LIKE 'Customer_%';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```
```text
------------------------------------------------------------------------------------
| Id  | Operation         | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |                |  4999 |   131K|     9   (0)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| CUSTOMERS_DEMO |  4999 |   131K|     9   (0)| 00:00:01 |
------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter("CUSTOMER_NAME" LIKE 'Customer_%')
```
*   **TABLE ACCESS FULL (Cost 9):** Cũng vẫn là Full Table Scan! Dù `%` ở cuối có thể dùng `INDEX RANGE SCAN`, nhưng Oracle thấy bảng chỉ 5000 dòng → Full Table Scan Cost 9 là rẻ nhất rồi.

### Trạng Thái 3: Ép Dùng Index — Để Thấy Cost Thực Sự

Dùng hint `/*+ INDEX */` ép Oracle dùng index để thấy cost nếu bảng lớn:

```sql
EXPLAIN PLAN FOR SELECT /*+ INDEX(customers_demo idx_cust_name) */ *
FROM customers_demo WHERE customer_name LIKE 'Customer_%';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```
```text
------------------------------------------------------------------------------------------------------
| Id  | Operation                           | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                    |                |  4999 |   131K|   965   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID BATCHED| CUSTOMERS_DEMO |  4999 |   131K|   965   (0)| 00:00:01 |
|*  2 |   INDEX RANGE SCAN                  | IDX_CUST_NAME  |  4999 |       |    19   (0)| 00:00:01 |
------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("CUSTOMER_NAME" LIKE 'Customer_%')
       filter("CUSTOMER_NAME" LIKE 'Customer_%')
```
*   **INDEX RANGE SCAN (Cost 965):** Khi bị ép dùng index, cost tăng từ **9 → 965** (hơn **107 lần**). Oracle hoàn toàn đúng khi chọn Full Table Scan.

**Tại sao Index lại đắt hơn?**
- **Full Table Scan (Cost 9):** Đọc 9 blocks liên tục (sequential I/O) — 1 lần đọc là xong.
- **INDEX RANGE SCAN (Cost 19):** Tìm được **4999 ROWID** trong index.
- **TABLE ACCESS BY INDEX ROWID BATCHED (Cost 965):** Mỗi ROWID là 1 lần **random I/O** vào table. 4999 lần random I/O đắt hơn nhiều so với 9 lần sequential I/O.

Index chỉ lợi khi **filter chọn rất ít dòng** (ví dụ: 1-5% bảng). Còn `LIKE 'Customer_%'` trả về 4999/5000 dòng (~99.98%), quét toàn bộ bảng 1 lần luôn rẻ hơn từng đó random access.

> ⚠️ **Bài học quan trọng:** Trên **bảng nhỏ** (< 10K dòng), Oracle luôn chọn Full Table Scan vì rẻ hơn index access. Sự khác biệt giữa `%` đầu và `%` cuối **chỉ thể hiện trên bảng lớn** (hàng triệu dòng), khi Index Range Scan thực sự có lợi hơn Full Scan.

**Tổng kết Kịch Bản 4:**

| Query | `%` ở đầu | `%` ở cuối |
|---|---|---|
| `COUNT(*)` — bảng nhỏ | INDEX FAST FULL SCAN — Cost 7 | INDEX FAST FULL SCAN — Cost 7 |
| `SELECT *` — bảng nhỏ (5K dòng) | TABLE ACCESS FULL — Cost 9 | TABLE ACCESS FULL — Cost 9 |
| `SELECT *` — bảng lớn (triệu dòng) | TABLE ACCESS FULL | **INDEX RANGE SCAN** — nhanh hơn nhiều |

---

## Bonus: Xem Row Nằm Ở File/Block Nào

```sql
SELECT DBMS_ROWID.ROWID_RELATIVE_FNO(rowid) AS file_no, DBMS_ROWID.ROWID_BLOCK_NUMBER(rowid) AS block_no, DBMS_ROWID.ROWID_ROW_NUMBER(rowid) AS row_no FROM customers_demo WHERE ROWNUM <= 5;
```

```sql
-- Cần quyền SELECT ANY DICTIONARY hoặc DBA
SELECT value FROM v$parameter WHERE name = 'db_block_size';
-- Block size mặc định Oracle là 8192 (8KB)
```

---

## Checklist DBA Khi Query Chậm Dù Đã Có Index

*   Có hàm nào áp trực tiếp lên cột có Index trong `WHERE` không?
*   Có phép toán số học trên cột Index không?
*   Kiểu dữ liệu của literal/bind variable có khớp chính xác với kiểu cột không?
*   `LIKE` pattern có `%` ở đầu không?
*   Không sửa được query → tạo **Function-Based Index**.

---

## Bonus: Oracle Không Cần VACUUM — Chứng Minh

### 1. Undo tự quản — xem undo đang dùng bao nhiêu

```sql
SELECT tablespace_name, sum(bytes)/1024/1024 AS mb_used FROM dba_undo_extents WHERE status = 'ACTIVE' GROUP BY tablespace_name;
```

### 2. Mỗi block chứa bao nhiêu row?

```sql
SELECT DBMS_ROWID.ROWID_BLOCK_NUMBER(rowid) AS block_no, COUNT(*) AS rows_in_block FROM customers_demo GROUP BY DBMS_ROWID.ROWID_BLOCK_NUMBER(rowid) ORDER BY block_no;
```

### 3. Flashback Query — đọc dữ liệu cũ nhờ undo (Postgres muốn vậy phải dùng page-level hack)

```sql
-- Giả sử có 1000 dòng
SELECT COUNT(*) FROM customers_demo AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '1' MINUTE);
```

### 4. So sánh: Postgres VACUUM liên tục chạy

```sql
-- Postgres: kiểm tra dead tuples
-- SELECT relname, n_dead_tup, n_live_tup FROM pg_stat_user_tables WHERE n_dead_tup > 0;
```

Oracle dùng **Undo tablespace** riêng: undo tự động recycle, không gây bloat table/index, không có transaction wraparound, không cần vacuum. Đây là lợi thế lớn so với Postgres và SQL Server (tempdb).
