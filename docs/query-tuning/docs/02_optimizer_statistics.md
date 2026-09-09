# Lesson 2: Optimizer Statistics & Cạm Bẫy Lệch Dữ Liệu (Data Skew) 📈

Bài thực hành này ghi lại toàn bộ hành trình tuning chân thực từng bước trên hệ thống Oracle RAC của bạn.

---

## 1. Trạng Thái 1: Chưa Có Statistics (Tự Đoán Mò)

Khi bảng vừa được tạo và chèn 100.000 dòng, chúng ta chạy lệnh gom nhóm:
```sql
select order_status, count(*) from orders_demo group by order_status;
```

**Execution Plan:**
```text
----------------------------------------------------------------------------------
| Id  | Operation          | Name        | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |             | 81462 |   954K|   174   (3)| 00:00:01 |
|   1 |  HASH GROUP BY     |             | 81462 |   954K|   174   (3)| 00:00:01 |
|   2 |   TABLE ACCESS FULL| ORDERS_DEMO | 81462 |   954K|   171   (1)| 00:00:01 |
----------------------------------------------------------------------------------
Note
-----
   - dynamic statistics used: dynamic sampling (level=2)
```
*   **Phân tích:** Cảnh báo `dynamic sampling` xuất hiện. Oracle đoán sai số dòng của bảng (81.462 thay vì 100.000) và đoán sai số nhóm trả về của HASH GROUP BY (81.462 thay vì 2).

---

## 2. Trạng Thái 2: Đã Cập Nhật Thống Kê Cơ Bản

Chúng ta khắc phục bằng cách thu thập thống kê:
```sql
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS_DEMO');
```

**Execution Plan (Chạy lại lệnh GROUP BY):**
```text
----------------------------------------------------------------------------------
| Id  | Operation          | Name        | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |             |     2 |    20 |   174   (3)| 00:00:01 |
|   1 |  HASH GROUP BY     |             |     2 |    20 |   174   (3)| 00:00:01 |
|   2 |   TABLE ACCESS FULL| ORDERS_DEMO |   100K|   976K|   171   (1)| 00:00:01 |
----------------------------------------------------------------------------------
```
*   **Phân tích:** Cảnh báo biến mất. Oracle nhận diện chuẩn xác **100K** dòng và **2** nhóm trả về.

---

## 3. Trạng Thái 3: Cạm Bẫy Data Skew (Có Index Nhưng Thiếu Histograms)

Dữ liệu của chúng ta lệch nặng: `COMPLETED` (90K dòng) và `CANCELLED` (10K dòng).
Ta đã tạo Index: `CREATE INDEX idx_orders_status ON orders_demo(order_status);`

**Chạy lệnh tìm CANCELLED (10K dòng):**
```sql
explain plan for SELECT * FROM orders_demo where order_status='CANCELLED';
```

**Execution Plan:**
```text
---------------------------------------------------------------------------------
| Id  | Operation         | Name        | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |             | 50000 |  1660K|   171   (1)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| ORDERS_DEMO | 50000 |  1660K|   171   (1)| 00:00:01 |
---------------------------------------------------------------------------------
```
*   **Phân tích (Lỗi kinh điển):** Tại sao tìm CANCELLED mà Optimizer đoán **Rows = 50000** và vẫn dùng `TABLE ACCESS FULL`? 
*   Bởi vì bảng có đúng 2 trạng thái. Theo công thức mặc định (Uniform Distribution), Oracle lấy `100.000 / 2 = 50.000`. Nó nghĩ phải truy xuất 50% bảng nên quyết định từ chối xài Index.

---

## 4. Trạng Thái 4: Kích Hoạt Histograms (Thuốc Giải)

Chúng ta dạy cho Oracle biết sự thật (Lệch 90-10) bằng Histograms:
```sql
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS_DEMO', method_opt => 'FOR COLUMNS order_status SIZE 2');
```

### Kết quả khi tìm CANCELLED (10.000 dòng):
```text
---------------------------------------------------------------------------------------------------------
| Id  | Operation                           | Name              | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                    |                   | 10000 |   332K|   154   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID BATCHED| ORDERS_DEMO       | 10000 |   332K|   154   (0)| 00:00:01 |
|*  2 |   INDEX RANGE SCAN                  | IDX_ORDERS_STATUS | 10000 |       |    30   (0)| 00:00:01 |
---------------------------------------------------------------------------------------------------------
```
*   **Phân tích:** Nhờ Histograms, Oracle biết đúng là chỉ có 10.000 dòng. Vì ít, nó quay xe dùng ngay **`INDEX RANGE SCAN`**.

### Kết quả khi tìm COMPLETED (90.000 dòng):
```text
---------------------------------------------------------------------------------
| Id  | Operation         | Name        | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |             | 90000 |  2988K|   171   (1)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| ORDERS_DEMO | 90000 |  2988K|   171   (1)| 00:00:01 |
---------------------------------------------------------------------------------
```
*   **Phân tích:** Nó biết là có 90.000 dòng. Vì quá nhiều (90% dữ liệu), lật Index sẽ chết nghẹt I/O, nó thông minh bỏ Index và dùng **`TABLE ACCESS FULL`**.

**🏆 KẾT LUẬN BÀI HỌC:** Không phải cứ có Index là Oracle sẽ dùng. Optimizer luôn tính toán Cost. Khi dữ liệu phân bố lệch (Skew), bắt buộc phải có **Histograms** thì Optimizer mới ra quyết định chính xác.
