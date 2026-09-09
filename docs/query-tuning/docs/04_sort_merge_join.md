# Lesson 4: Sort Merge Join và Hiểm Họa Disk Sort 🌪️

Khi nhắc đến Join, mọi người thường chỉ nghĩ đến Hash Join và Nested Loops. Nhưng có một thuật toán thứ 3 luôn âm thầm chờ đợi để xuất hiện mỗi khi có điều kiện "đặc biệt": **Sort Merge Join (SMJ)**.

---

## 1. Khi Nào Sort Merge Join Xuất Hiện?

Hash Join (thuật toán dùng Băm dữ liệu) có tốc độ cực nhanh nhưng lại có một điểm yếu chí mạng: **Nó chỉ hoạt động với phép so sánh bằng (`=`)**.

Khi câu truy vấn của bạn sử dụng **Non-Equi Joins** (các phép so sánh không bằng như `>`, `<`, `>=`, `<=`, `BETWEEN`), Hash Join lập tức bị "phế võ công". Lúc này, Oracle buộc phải lôi **Sort Merge Join** ra để giải quyết bài toán.

**Ví dụ truy vấn thực tế:**
```sql
EXPLAIN PLAN FOR
SELECT o.order_id, c.customer_name, o.total_amount
FROM customers_demo c
JOIN orders_demo o ON o.customer_id > c.customer_id
WHERE c.customer_id BETWEEN 100 AND 105;
```

---

## 2. Cách Sort Merge Join Hoạt Động

Để nối 2 bảng bằng SMJ, Oracle thực hiện 3 bước tuần tự (nhìn vào Execution Plan để đối chiếu):

**Execution Plan:**
```text
-------------------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Rows  | Bytes |TempSpc| Cost (%CPU)| Time     |
-------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |   685K|    20M|       |   645   (2)| 00:00:01 |
|   1 |  MERGE JOIN                  |                |   685K|    20M|       |   645   (2)| 00:00:01 |
|   2 |   TABLE ACCESS BY INDEX ROWID| CUSTOMERS_DEMO |     7 |   126 |       |     3   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN          | SYS_C007628    |     7 |       |       |     2   (0)| 00:00:01 |
|*  4 |   SORT JOIN                  |                | 98020 |  1244K|  4632K|   640   (1)| 00:00:01 |
|*  5 |    TABLE ACCESS FULL         | ORDERS_DEMO    | 98020 |  1244K|       |   171   (1)| 00:00:01 |
-------------------------------------------------------------------------------------------------------
```

1.  **Bước 1: Sắp xếp bảng thứ nhất (Customers)**
    *   Nhờ có Primary Key (`SYS_C007628`) trên cột `customer_id`, dữ liệu của bảng Customers đã được tự động sắp xếp (Sorted) từ trước theo cấu trúc cây B-Tree.
    *   Do đó, Oracle chỉ cần dùng `INDEX RANGE SCAN` (ID=3) để lấy ra 7 dòng thỏa mãn điều kiện `BETWEEN 100 AND 105` mà không cần tốn sức sắp xếp lại.
2.  **Bước 2: Sắp xếp bảng thứ hai (Orders) - `SORT JOIN`**
    *   Cột khóa ngoại `o.customer_id` không có Index theo thứ tự thích hợp cho câu lệnh này, nên Oracle phải quét toàn bộ bảng Orders (`TABLE ACCESS FULL` - ID=5).
    *   Sau đó, nó phải lôi **98.020** dòng này lên RAM và dùng thuật toán **SORT JOIN** (ID=4) để tự sắp xếp lại chúng.
3.  **Bước 3: Trộn (Merge)**
    *   Khi cả 2 tập dữ liệu đã được xếp thành hàng dọc, Oracle chỉ việc chạy một lượt từ trên xuống dưới (giống như kéo khóa áo) để ghép nối các dòng thỏa mãn điều kiện `>`.

---

## 3. Tiếng Còi Báo Động: Cột `TempSpc` 🚨

Điểm đắt giá nhất trong Execution Plan trên không phải là chữ `MERGE JOIN`, mà là con số **`4632K`** ở cột **`TempSpc`**.

*   **TempSpc là gì?** Khi Oracle tiến hành sắp xếp (SORT) bảng Orders, nếu dung lượng RAM cấp cho câu lệnh (PGA) bị hết, nó buộc phải "mượn" không gian trên ổ cứng vật lý (Temp Tablespace) để sắp xếp tạm. Hiện tượng này gọi là **Disk Sort**.
*   **Hiểm họa tiềm tàng:** Đọc ghi trên ổ cứng chậm hơn RAM hàng ngàn lần. Ở đây chúng ta mới sắp xếp 100.000 dòng nên chỉ tốn 4.6MB Temp. Nếu bảng Orders có 1 tỷ dòng, thao tác này sẽ nuốt sạch toàn bộ dung lượng đĩa TEMP của Server, gây lỗi `ORA-01652: unable to extend temp segment` và làm sập (treo) toàn bộ các báo cáo khác đang chạy trên Database.

**🏆 KẾT LUẬN BÀI HỌC:**
*   Chỉ dùng Non-Equi Joins (`>`, `<`) khi thực sự cần thiết, vì nó dễ kích hoạt Sort Merge Join.
*   Bất cứ khi nào thấy cột **`TempSpc`** xuất hiện trong Explain Plan, hãy tìm cách tối ưu ngay lập tức (Tạo Index để tránh bước SORT, hoặc tăng dung lượng RAM PGA cấp cho phiên làm việc).
