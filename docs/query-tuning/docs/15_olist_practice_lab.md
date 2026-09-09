# Lesson 15: Query Tuning với Olist E-commerce Schema

## Schema

```
SELLERS_DEMO       (5K rows)   seller_id, city, state, zip
CUSTOMERS_DEMO     (100K rows) customer_id, city, state, zip, segment (PLATINUM/GOLD/SILVER/REGULAR)
PRODUCTS_DEMO      (50K rows)  product_id, category, name, weight, dimensions, freight
ORDERS_DEMO        (500K rows) order_id, customer_id, status, dates, freight, total_amount
ORDER_ITEMS_DEMO   (~2M rows)  order_id, item_no, product_id, seller_id, qty, unit_price, total_price
PAYMENTS_DEMO      (500K rows) payment_id, order_id, type, installments, value
REVIEWS_DEMO       (400K rows) review_id, order_id, score, comment, created, answered
```

---

## Bài 1: Đọc Execution Plan căn bản

### 1.1 Explain Plan cho 1 table

```sql
EXPLAIN PLAN FOR
SELECT * FROM orders_demo WHERE order_status = 'cancelled';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

Chú ý các cột: **Id, Operation, Name, Rows, Bytes, Cost, Time**.

### 1.2 Plan thật — có A-Rows

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ *
FROM orders_demo WHERE order_status = 'cancelled';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST'));
```

So sánh **E-Rows** (ước lượng) vs **A-Rows** (thực tế).

### 1.3 Join 3 bảng

```sql
EXPLAIN PLAN FOR
SELECT o.order_id, c.customer_city, p.payment_type
FROM orders_demo o
JOIN customers_demo c ON c.customer_id = o.customer_id
JOIN payments_demo p ON p.order_id = o.order_id
WHERE o.order_status = 'delivered';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

Quan sát **access predicate** vs **filter predicate**.

---

## Bài 2: Index Suppress

### 2.1 Function trên cột

```sql
EXPLAIN PLAN FOR
SELECT * FROM orders_demo
WHERE TRUNC(order_date) = DATE '2024-06-15';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

Có dùng index `idx_orders_date` không? Tại sao?

Sửa:

```sql
EXPLAIN PLAN FOR
SELECT * FROM orders_demo
WHERE order_date >= DATE '2024-06-15'
  AND order_date < DATE '2024-06-16';
```

### 2.2 Expression trên cột

```sql
EXPLAIN PLAN FOR
SELECT COUNT(*) FROM orders_demo
WHERE total_amount * 1.1 > 1000;
```

So sánh:

```sql
EXPLAIN PLAN FOR
SELECT COUNT(*) FROM orders_demo
WHERE total_amount > 1000 / 1.1;
```

Rule: **Để cột sạch, đưa phép tính sang vế phải**.

---

## Bài 3: Data Skew & Histogram

### 3.1 Check distribution

```sql
SELECT order_status, COUNT(*),
       ROUND(RATIO_TO_REPORT(COUNT(*)) OVER() * 100, 1) AS pct
FROM orders_demo
GROUP BY order_status
ORDER BY 2 DESC;
```

### 3.2 So sánh plan cùng status khác selectivity

```sql
EXPLAIN PLAN FOR
SELECT * FROM orders_demo WHERE order_status = 'delivered';  -- 85%
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

EXPLAIN PLAN FOR
SELECT * FROM orders_demo WHERE order_status = 'cancelled';  -- ~3%
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

Status nào dùng **INDEX**? Status nào **FULL TABLE SCAN**? Tại sao Oracle chọn vậy?

### 3.3 Histogram

```sql
SELECT column_name, histogram, num_buckets
FROM user_tab_columns
WHERE table_name = 'ORDERS_DEMO' AND column_name = 'ORDER_STATUS';
```

---

## Bài 4: Composite Index

### 4.1 Index hiện tại

```sql
SELECT index_name, column_name, column_position
FROM user_ind_columns
WHERE table_name = 'ORDERS_DEMO'
ORDER BY index_name, column_position;
```

### 4.2 Tìm orders theo customer + date range

```sql
EXPLAIN PLAN FOR
SELECT * FROM orders_demo
WHERE customer_id BETWEEN 100 AND 200
  AND order_date BETWEEN DATE '2024-03-01' AND DATE '2024-04-01';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

Oracle dùng index `idx_orders_customer` hay `idx_orders_date` hay cả 2?

### 4.3 Tạo composite index

```sql
CREATE INDEX idx_orders_cust_date ON orders_demo(customer_id, order_date);

EXPLAIN PLAN FOR
SELECT * FROM orders_demo
WHERE customer_id BETWEEN 100 AND 200
  AND order_date BETWEEN DATE '2024-03-01' AND DATE '2024-04-01';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

So sánh Cost và Rows trước vs sau.

### 4.4 Reverse column order — sai thứ tự

```sql
CREATE INDEX idx_orders_date_cust ON orders_demo(order_date, customer_id);

EXPLAIN PLAN FOR
SELECT * FROM orders_demo
WHERE customer_id BETWEEN 100 AND 200
  AND order_date BETWEEN DATE '2024-03-01' AND DATE '2024-04-01';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

Kết luận: **Leading column = cột có filter = (equality), không phải range**.

---

## Bài 5: Join Tuning

### 5.1 Driving table — Small first

```sql
EXPLAIN PLAN FOR
SELECT c.customer_id, c.customer_city, o.order_id, o.total_amount
FROM orders_demo o
JOIN customers_demo c ON c.customer_id = o.customer_id
WHERE c.customer_segment = 'PLATINUM';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

PLATINUM chỉ 0.5% — Oracle có chọn **customers** làm driving table không?

### 5.2 Nested Loops vs Hash Join

```sql
-- Nếu filter ít row → Nested Loops
SELECT /*+ USE_NL(c o) */ c.customer_id, o.total_amount
FROM customers_demo c
JOIN orders_demo o ON o.customer_id = c.customer_id
WHERE c.customer_segment = 'PLATINUM';

-- Nếu filter nhiều row → Hash Join
SELECT /*+ USE_HASH(c o) */ c.customer_id, o.total_amount
FROM customers_demo c
JOIN orders_demo o ON o.customer_id = c.customer_id
WHERE c.customer_segment = 'REGULAR';
```

---

## Bài 6: Scalar Subquery vs Aggregate Join

### 6.1 Scalar subquery

```sql
SET TIMING ON
SELECT c.customer_id, c.customer_segment,
  (SELECT COUNT(*) FROM orders_demo o WHERE o.customer_id = c.customer_id) AS cnt,
  (SELECT NVL(SUM(o.total_amount),0) FROM orders_demo o WHERE o.customer_id = c.customer_id) AS total
FROM customers_demo c
WHERE c.customer_segment = 'GOLD';
```

### 6.2 Aggregate join

```sql
SELECT c.customer_id, c.customer_segment,
  NVL(x.cnt, 0), NVL(x.total, 0)
FROM customers_demo c
LEFT JOIN (
  SELECT customer_id, COUNT(*) AS cnt, SUM(total_amount) AS total
  FROM orders_demo GROUP BY customer_id
) x ON x.customer_id = c.customer_id
WHERE c.customer_segment = 'GOLD';
```

So sánh elapsed time và buffer_gets qua plan:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST'));
```

---

## Bài 7: NOT EXISTS / NOT IN vs ANTI JOIN

### 7.1 NOT EXISTS

```sql
SELECT * FROM customers_demo c
WHERE NOT EXISTS (SELECT 1 FROM orders_demo o WHERE o.customer_id = c.customer_id);
```

### 7.2 NOT IN

```sql
SELECT * FROM customers_demo c
WHERE c.customer_id NOT IN (SELECT customer_id FROM orders_demo);
```

Q: Kết quả có giống nhau không? Tại sao?

### 7.3 LEFT JOIN + NULL check

```sql
SELECT c.* FROM customers_demo c
LEFT JOIN orders_demo o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;
```

---

## Bài 8: Aggregation

### 8.1 Hash Group By (low cardinality)

```sql
EXPLAIN PLAN FOR
SELECT order_status, COUNT(*), SUM(total_amount)
FROM orders_demo GROUP BY order_status;
```

### 8.2 Sort Group By (high cardinality)

```sql
EXPLAIN PLAN FOR
SELECT customer_id, COUNT(*), SUM(total_amount)
FROM orders_demo GROUP BY customer_id;
```

### 8.3 Materialize intermediate result

```sql
WITH cust_stats AS (
  SELECT customer_id,
    COUNT(*) AS cnt,
    SUM(total_amount) AS total
  FROM orders_demo
  GROUP BY customer_id
)
SELECT c.customer_segment, AVG(cs.cnt), AVG(cs.total)
FROM customers_demo c
JOIN cust_stats cs ON cs.customer_id = c.customer_id
GROUP BY c.customer_segment;
```

---

## Bài 9: Window Functions

### 9.1 Row number per customer

```sql
SELECT order_id, customer_id, total_amount,
  ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
FROM orders_demo;
```

Xem plan — có **WINDOW SORT** không?

### 9.2 Top 3 products per category

```sql
SELECT * FROM (
  SELECT p.product_category, p.product_name,
    SUM(i.total_price) AS revenue,
    DENSE_RANK() OVER (
      PARTITION BY p.product_category
      ORDER BY SUM(i.total_price) DESC
    ) AS rnk
  FROM order_items_demo i
  JOIN products_demo p ON p.product_id = i.product_id
  GROUP BY p.product_category, p.product_name
) WHERE rnk <= 3;
```

---

## Bài 10: Runtime Diagnostics

### 10.1 Top SQL trong schema

```sql
SELECT sql_id, executions,
  ROUND(elapsed_time/1e6, 2) AS sec,
  buffer_gets, disk_reads,
  ROUND(rows_processed/ GREATEST(executions,1)) AS rows_per_exec,
  SUBSTR(sql_text, 1, 80) AS sql_preview
FROM v$sql
WHERE parsing_schema_name = 'QUERY_TUNING'
  AND command_type = 3   -- SELECT only
ORDER BY elapsed_time DESC
FETCH FIRST 10 ROWS ONLY;
```

### 10.2 Plan thật của 1 SQL

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => '<SQL_ID>', format => 'ALLSTATS LAST'));
```

### 10.3 Blocking session

```sql
SELECT sid, serial#, username, blocking_session, wait_class, event, state
FROM v$session
WHERE blocking_session IS NOT NULL;
```

---

## Bonus: Index Maintenance

### Drop unused index

```sql
-- Check index usage
SELECT i.index_name, i.table_name,
  s.unique_keys, s.clustering_factor, s.leaf_blocks,
  s.distinct_keys, s.sample_size
FROM user_indexes i
JOIN user_ind_statistics s ON s.index_name = i.index_name;
```

---

Từng bài làm xong ghi lại câu hỏi / thắc mắc vào `docs/problems.md`. Học xong L15 chắc chắn bạn sẽ vững execution plan.
