# Hướng Dẫn Setup Olist Schema

## Bước 1: Copy file lên VM (chạy trên máy local)

```bash
scp -P 2222 -i ~/.ssh/rac_ed25519 /home/tandat/Desktop/query_tuning/labs/setup_olist_schema.sql tandat8896@192.168.122.205:~/
```

## Bước 2: Trong VM, copy vào /tmp

```bash
cp ~/setup_olist_schema.sql /tmp/
```

## Bước 3: Chạy trong SQLcl (session QUERY_TUNING)

```sql
@/tmp/setup_olist_schema.sql
```

---

## Bug đã gặp và nguyên nhân

**Triệu chứng:** Script chạy xong, tất cả bảng đều 0 rows. Terminal thấy 400K dòng data in ra màn hình nhưng không có gì trong bảng.

**Nguyên nhân:** SQLcl xử lý script file khác SQL\*Plus — khi gặp `INSERT...SELECT` viết trên nhiều dòng:

```sql
-- SQLcl tách đây thành 2 câu RIÊNG:
INSERT INTO reviews_demo (review_id, order_id, ...)   -- câu 1: thiếu VALUES → fail silent
SELECT LEVEL, LEVEL, ...                               -- câu 2: chạy như SELECT thường
FROM dual CONNECT BY LEVEL <= 400000;                  --        → in ra màn hình, không insert
```

**Fix:** Bọc mỗi INSERT vào `BEGIN...END;` — PL/SQL engine parse cả block như 1 đơn vị, INSERT và SELECT không bị tách:

```sql
BEGIN
  INSERT INTO reviews_demo (review_id, order_id, ...)
  SELECT LEVEL, LEVEL, ...
  FROM dual CONNECT BY LEVEL <= 400000;
  COMMIT;
END;
/
```

**Kết quả đúng sau fix:**

| Table | Rows |
|---|---|
| sellers_demo | 5,000 |
| customers_demo | 100,000 |
| products_demo | 50,000 |
| orders_demo | 500,000 |
| order_items_demo | 1,000,000 |
| payments_demo | 500,000 |
| reviews_demo | 400,000 |
