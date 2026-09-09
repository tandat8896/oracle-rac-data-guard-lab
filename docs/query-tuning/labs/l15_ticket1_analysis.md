# Ticket 1: Phân tích & Tối ưu Plan

## Yêu cầu

Top 10 sản phẩm có tổng số lượng bán nhiều nhất.

---

## Version A: Scalar Subquery (chậm)

```sql
SELECT p.product_id, p.product_category, p.product_name,
       (SELECT NVL(SUM(i.quantity), 0)
        FROM order_items_demo i
        WHERE i.product_id = p.product_id) AS total_qty_sold
FROM products_demo p
ORDER BY total_qty_sold DESC
FETCH FIRST 10 ROWS ONLY;
```

### Plan

```
------------------------------------------------------------------------------------------------------------------
| Id  | Operation                            | Name              | Rows  | Bytes |TempSpc| Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                     |                   |    10 |  1310 |       |   962K  (1)| 00:00:38 |
|   1 |  SORT AGGREGATE                      |                   |     1 |     8 |       |            |          |
|   2 |   TABLE ACCESS BY INDEX ROWID BATCHED| ORDER_ITEMS_DEMO  |    20 |   160 |       |    23   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN                  | IDX_ITEMS_PRODUCT |    20 |       |       |     3   (0)| 00:00:01 |
|   4 |  SORT ORDER BY                       |                   |    10 |  1310 |       |   962K  (1)| 00:00:38 |
|*  5 |   VIEW                               |                   |    10 |  1310 |       |   962K  (1)| 00:00:38 |
|*  6 |    WINDOW SORT PUSHED RANK           |                   | 50000 |  1318K|  1976K|   962K  (1)| 00:00:38 |
|   7 |     TABLE ACCESS FULL                | PRODUCTS_DEMO     | 50000 |  1318K|       |   102   (0)| 00:00:01 |
------------------------------------------------------------------------------------------------------------------
```

**Predicate Information:**
```
3 - access("I"."PRODUCT_ID"=:B1)
5 - filter("from$_subquery$_004"."rowlimit_$$_rownumber"<=10)
6 - filter(ROW_NUMBER() OVER (ORDER BY (SELECT ... WHERE I.PRODUCT_ID=:B1)) <=10)
```

### Cách đọc

**Cây plan (từ plan_table):**
```
0 ─── 1 (SORT AGGREGATE) ← nhánh subquery
      └── 2 (TABLE ACCESS BY INDEX ROWID BATCHED)
          └── 3 (INDEX RANGE SCAN)

0 ─── 4 (SORT ORDER BY)  ← nhánh outer
      └── 5 (VIEW)
          └── 6 (WINDOW SORT PUSHED RANK)
              └── 7 (TABLE ACCESS FULL)
```

### Thứ tự chạy

```
1. Id 7 — scan products (50K rows)
2. Id 6 — window sort, xử lý từng product
3.   → gán :B1 = product_id hiện tại
4.   → Id 3 — index range scan (IDX_ITEMS_PRODUCT)
5.   → Id 2 — table access (lấy row từ index)
6.   → Id 1 — tính SUM(quantity)
7.   → trả 1 số về Id 6
8. Lặp bước 2-7 cho 50K products
9. Id 5 — view wrapper
10. Id 4 — sort lấy top 10
11. Id 0 — xuất
```

### Dấu hiệu nhận biết correlated subquery

1. `:B1` xuất hiện ở 2 chỗ trong Predicate Information (Id 3 và Id 6)
2. 2 nhánh độc lập (cùng parent = 0) nhưng dính qua `:B1`
3. Cost 962K — quá cao so với outer query (102)

### Bottleneck

**Id 3→2→1 (subquery) chạy 50K lần.**
50K × cost 23 = ~1.15M → Oracle hiển thị 962K (sai lệch do cost model).

---

## Version B: GROUP BY + JOIN (tối ưu)

```sql
SELECT p.product_id, p.product_category, p.product_name,
       NVL(i.total_qty, 0) AS total_qty_sold
FROM products_demo p
LEFT JOIN (
  SELECT product_id, SUM(quantity) AS total_qty
  FROM order_items_demo
  GROUP BY product_id
) i ON i.product_id = p.product_id
ORDER BY total_qty_sold DESC
FETCH FIRST 10 ROWS ONLY;
```

### Plan

```
------------------------------------------------------------------------------------------------------
| Id  | Operation                 | Name             | Rows  | Bytes |TempSpc| Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT          |                  |    10 |  1310 |       |  1890   (3)| 00:00:01 |
|   1 |  SORT ORDER BY            |                  |    10 |  1310 |       |  1890   (3)| 00:00:01 |
|*  2 |   VIEW                    |                  |    10 |  1310 |       |  1889   (3)| 00:00:01 |
|*  3 |    WINDOW SORT PUSHED RANK|                  | 50000 |  2587K|  3160K|  1889   (3)| 00:00:01 |
|*  4 |     HASH JOIN RIGHT OUTER |                  | 50000 |  2587K|       |  1234   (4)| 00:00:01 |
|   5 |      VIEW                 |                  | 50536 |  1283K|       |  1131   (4)| 00:00:01 |
|   6 |       HASH GROUP BY       |                  | 50536 |   394K|       |  1131   (4)| 00:00:01 |
|   7 |        TABLE ACCESS FULL  | ORDER_ITEMS_DEMO |  1000K|  7812K|       |  1100   (1)| 00:00:01 |
|   8 |      TABLE ACCESS FULL    | PRODUCTS_DEMO    | 50000 |  1318K|       |   102   (0)| 00:00:01 |
------------------------------------------------------------------------------------------------------
```

**Predicate Information:**
```
2 - filter("from$_subquery$_005"."rowlimit_$$_rownumber"<=10)
3 - filter(ROW_NUMBER() OVER ( ORDER BY NVL("I"."TOTAL_QTY",0) DESC )<=10)
4 - access("I"."PRODUCT_ID"(+)="P"."PRODUCT_ID")
```

### Cây plan

```
0 ─── 1 (SORT ORDER BY)
      └── 2 (VIEW)
          └── 3 (WINDOW SORT PUSHED RANK)
              └── 4 (HASH JOIN RIGHT OUTER)
                  ├── 5 (VIEW)
                  │   └── 6 (HASH GROUP BY)
                  │       └── 7 (TABLE ACCESS FULL) ← order_items
                  └── 8 (TABLE ACCESS FULL) ← products
```

### Thứ tự chạy

```
1. Id 7 — scan order_items (1M rows)
2. Id 6 — hash group by (gom theo product_id, tính SUM)
3. Id 5 — view
4. Id 8 — scan products (50K rows)
5. Id 4 — hash join right outer (nối products + order_items đã gom)
6. Id 3 — window sort (đánh rank)
7. Id 2 — view
8. Id 1 — sort lấy top 10
9. Id 0 — xuất
```

### Khác biệt so với Version A

| Tiêu chí | Version A | Version B |
|---|---|---|
| Cost | 962K | 1,890 |
| Scan order_items | 50K lần (mỗi lần 20 rows) | 1 lần (1M rows) |
| :B1 | Có | Không |
| Correlated subquery | Có | Không |
| Thời gian ước tính | 00:00:38 | 00:00:01 |

## Tổng kết

| Plan | Scalar subquery (A) | GROUP BY + JOIN (B) |
|---|---|---|
| Cost | 962K | 1,890 — **~500x nhanh hơn** |
| Bottleneck | Subquery chạy 50K lần qua `:B1` | Không có bottleneck rõ rệt |
| Scan | 1 lần scan products / 50K lần scan order_items | 1 lần scan mỗi table |
| Khi nào dùng? | Khi tập cha nhỏ (< 100 rows) | Khi tập cha lớn (> 1000 rows) |

**Rule:** Scalar subquery trong SELECT chạy N lần (N = số dòng outer). Nếu N lớn → dùng GROUP BY + JOIN.
