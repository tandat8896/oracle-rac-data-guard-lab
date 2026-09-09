# Lesson 3: Các Thuật Toán Join và Cạm Bẫy Khóa Ngoại 🔗

Trong bài học này, chúng ta đã chứng kiến cách Oracle Optimizer đưa ra quyết định khi phải nối (Join) 2 bảng với nhau, cũng như những hậu quả tàn khốc khi thiết kế Database bị thiếu sót.

---

## 1. Trạng Thái 1: Sự Khôn Ngoan Của Hash Join

Khi tìm kiếm những khách hàng hạng `PLATINUM` (bảng `customers_demo`) và nối sang bảng `orders_demo`.

*   **Vì sao Hash Join xuất hiện?** 
    Oracle nhận thấy cột Khóa Ngoại (`customer_id`) trên bảng `orders_demo` không có Index. Nếu dùng Nested Loops, Oracle sẽ phải lật tung toàn bộ bảng Orders (100.000 dòng) mỗi lần duyệt qua một khách hàng. Đó là một thảm họa I/O.
*   **Giải pháp của Oracle:** Băm bảng nhỏ (Customers) lên RAM, sau đó quét bảng lớn (Orders) đúng 1 lần duy nhất (Full Table Scan). Kết quả: Cost cực tốt chỉ có **180**.

---

## 2. Trạng Thái 2: Ép Tử Nested Loops (Không Index)

Chúng ta đã dùng Hint `/*+ USE_NL(c o) */` để ép Oracle dùng Nested Loops.
*   **Kết quả:** Cost tăng vọt lên **100.000**.
*   **Bài học rút ra:** Tuyệt đối không bao giờ dùng Nested Loops nếu bảng con (nằm bên trong vòng lặp) không có Index trên cột dùng để Join. Đây là nguyên nhân hàng đầu gây sập hệ thống (Locking và High CPU) trong môi trường OLTP.

---

## 3. Trạng Thái 3: Cạm Bẫy Kép (Có Index Nhưng Thiếu Histograms)

Chúng ta tạo Index cho khóa ngoại: `CREATE INDEX idx_orders_cust_id ON orders_demo(customer_id);`
*   **Kết quả:** Cost giảm từ 100.000 xuống **35.025**.
*   **Tại sao vẫn cao?** Mặc dù đã có Index bên bảng Orders, nhưng Oracle lại tính toán sai lầm số lượng vòng lặp bên bảng Customers. Oracle nghĩ rằng có 1.667 khách hàng hạng PLATINUM (chia trung bình 5000/3 hạng) nên phải chọc vào Index 1.667 lần.

---

## 4. Trạng Thái 4: Hoàn Mỹ - Sự Kết Hợp Của Index + Histograms

Chúng ta tạo Histograms cho bảng Customers:
```sql
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'CUSTOMERS_DEMO', method_opt => 'FOR COLUMNS membership_lvl SIZE 3');
```

*   **Sự Tinh Tế:** Oracle nhận ra chỉ có đúng **50 khách hàng PLATINUM**. Nó quyết định quét Full bảng Customers 1 lần (Cost 9), sau đó lặp đúng 50 lần chọc vào Index của bảng Orders. 
*   **Tổng Cost:** Rơi tự do từ 35.025 xuống chỉ còn **1.059**. 

---

## 5. Trạng Thái 5: Sân Nhà Của Nested Loops (Kịch Bản Thực Tế OLTP)

Truy vấn lịch sử mua hàng của riêng một user (`WHERE c.customer_id = 123`).
*   **Kết quả:** Oracle KHÔNG CẦN HINT vẫn tự động chọn `NESTED LOOPS`.
*   **Tổng Cost:** Sập sàn chỉ còn **23** (nhanh hơn 8 lần so với Hash Join Cost 180).
*   **Bài học:** Nested Loops là Vua của OLTP (khi tìm kiếm các bản ghi đơn lẻ) với điều kiện bắt buộc phải có Index.

---

## 6. Trạng Thái 6: Thảm Họa Chọn Sai Bảng Dẫn (Driving Table)

Quy tắc sống còn của Nested Loops: **Bảng nào trả về ÍT DÒNG NHẤT sau khi lọc thì phải là Vòng Lặp Cha (Driving Table).**

Chúng ta đã cố tình dùng Hint `/*+ USE_NL(c o) LEADING(o c) */` để ép Oracle dùng bảng `Orders` (chứa 100.000 dòng, không có điều kiện lọc) làm vòng lặp cha, và chọc vào bảng `Customers` 100.000 lần.

**Execution Plan (Bị ép buộc):**
```text
-----------------------------------------------------------------------------------------------
| Id  | Operation                    | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                |  1000 | 36000 |   100K  (1)| 00:00:04 |
|   1 |  NESTED LOOPS                |                |  1000 | 36000 |   100K  (1)| 00:00:04 |
|   2 |   NESTED LOOPS               |                |   100K| 36000 |   100K  (1)| 00:00:04 |
|   3 |    TABLE ACCESS FULL         | ORDERS_DEMO    |   100K|   878K|   171   (1)| 00:00:01 |
|*  4 |    INDEX UNIQUE SCAN         | SYS_C007628    |     1 |       |     0   (0)| 00:00:01 |
|*  5 |   TABLE ACCESS BY INDEX ROWID| CUSTOMERS_DEMO |     1 |    27 |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------------
```
*   **Hậu quả:** Cost lại nhảy vọt lên **100.000**.
*   **Nguyên nhân:** Nó phải duyệt toàn bộ 100.000 dòng của bảng Orders (Cost 171), sau đó với mỗi dòng, nó thực hiện 1 phép `INDEX UNIQUE SCAN` vào bảng Customers. Dù Index Scan cực kỳ nhanh (Cost=1), nhưng lặp lại 100.000 lần thì tổng chi phí vẫn trở thành thảm họa.

**🏆 TỔNG KẾT BÀI HỌC:**
Chúng ta là **Kiến trúc sư (Architect)**, Oracle là **Bộ não tính toán (CBO)**. 
CBO của Oracle đủ thông minh để tự chọn Bảng Dẫn (Trạng thái 4) và Thuật Toán (Trạng thái 5) với Cost tối ưu nhất. Nhưng nó chỉ làm được điều đó nếu con người Thiết kế Index và Cung cấp Bản đồ Histograms chính xác! Tuyệt đối không lạm dụng Hint ép buộc hệ thống!
