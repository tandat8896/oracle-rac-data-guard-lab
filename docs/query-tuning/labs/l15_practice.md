# Lab 15: Query Practice Ticket

> Format: mỗi ticket viết 2 phiên bản SQL, chạy trên SQLcl, ghi lại kết quả.

---

## Ticket 1: Top 10 Sản Phẩm Bán Chạy

Top 10 sản phẩm có tổng số lượng bán ra nhiều nhất, kèm tên category.

Output: `product_id | product_category | product_name | total_qty_sold`

### Version A: GROUP BY + ORDER BY

```sql
-- Viết tại đây
```

### Version B: Dùng subquery / CTE

```sql
-- Viết tại đây
```

---

## Ticket 2: Khách Hàng Chưa Mua Gì

Tìm customer chưa có order nào.

Output: `customer_id | customer_city | customer_state | customer_segment`

### Version A: NOT EXISTS

```sql

```

### Version B: LEFT JOIN + NULL

```sql

```

### Version C: NOT IN

```sql

```

---

## Ticket 3: Doanh Thu Theo Tuần

Mỗi tuần trong năm 2024 có tổng doanh thu bao nhiêu?

Output: `week_number | total_revenue | order_count`

### Version A: TO_CHAR + GROUP BY

```sql
SELECT TO_CHAR(order_date, 'WW') AS week_number,
       SUM(total_amount) AS total_revenue,
       COUNT(*) AS order_count
FROM orders_demo
WHERE order_date >= DATE '2024-01-01'
  AND order_date < DATE '2025-01-01'
GROUP BY TO_CHAR(order_date, 'WW')
ORDER BY week_number;
```

Plan: INDEX FAST FULL SCAN (IDX_ORDERS_DATE_AMOUNT) — Cost 449

### Version B: TRUNC + GROUP BY

```sql
SELECT TRUNC(order_date, 'WW') AS week_start,
       SUM(total_amount) AS total_revenue,
       COUNT(*) AS order_count
FROM orders_demo
WHERE order_date >= DATE '2024-01-01'
  AND order_date < DATE '2025-01-01'
GROUP BY TRUNC(order_date, 'WW')
ORDER BY week_start;
```

Plan: INDEX FAST FULL SCAN (IDX_ORDERS_DATE_AMOUNT) + SORT ORDER BY — Cost 459

### Phân tích plan

| Version | Operation | Cost | Ghi chú |
|---|---|---|---|
| TO_CHAR | INDEX FAST FULL SCAN → HASH GROUP BY | 449 | Không cần sort vì TO_CHAR output đã sort? |
| TRUNC | INDEX FAST FULL SCAN → HASH GROUP BY → SORT ORDER BY | 459 | Thêm SORT ORDER BY vì kết quả TRUNC chưa được sort |

Composite index `IDX_ORDERS_DATE_AMOUNT (order_date, total_amount)` cho phép **INDEX FAST FULL SCAN** — không cần đụng table. Clustering Factor không còn ảnh hưởng.

So sánh với plan cũ (TO_CHAR, chưa có composite index — TABLE ACCESS FULL cost 1244): cost giảm ~3 lần nhờ index-only scan.

### Nhận xét

- `TO_CHAR` nhanh hơn `TRUNC` nhẹ (~10 cost) vì không cần sort sau GROUP BY
- Số chênh lệch không đáng kể — chọn version nào dễ đọc kết quả hơn
- `TRUNC` trả về DATE (ví dụ 01-JAN-24) — dễ đọc tuần hơn số '01'

---

## Ticket 4: Order Có Giá Trị Cao Nhất Mỗi Customer

Tìm order có total_amount lớn nhất của mỗi customer.

Output: `customer_id | order_id | total_amount`

### Version A: Subquery + GROUP BY

```sql

```

### Version B: Window Function (ROW_NUMBER / RANK)

```sql

```

---

## Ticket 5: Đánh Giá Trung Bình Theo Category

Mỗi category sản phẩm có review_score trung bình bao nhiêu?

Output: `product_category | avg_score | review_count`

### Version A: JOIN + GROUP BY

```sql

```

### Version B: Scalar subquery

```sql

```
