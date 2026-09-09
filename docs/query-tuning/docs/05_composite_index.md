# Lesson 5: Composite Index và Quyền Lực Của DBA 🥇

Trong thiết kế Database, Index đa cột (Composite Index) là một vũ khí cực kỳ sắc bén để giải quyết các câu truy vấn phức tạp. Tuy nhiên, nó cũng là con dao hai lưỡi nếu DBA không hiểu rõ nguyên lý hoạt động của nó.

---

## 1. Nguyên Tắc "Dẫn Đầu" (Leading Column)
Một Composite Index giống như một cuốn danh bạ điện thoại được sắp xếp theo cấu trúc phân cấp: **(Cột 1, Cột 2)**.
*   Dữ liệu sẽ được sắp xếp ưu tiên theo Cột 1 trước.
*   Nếu Cột 1 giống nhau, nó mới dùng Cột 2 để sắp xếp tiếp.

**Quy tắc Sinh Tử:** Để Oracle có thể sử dụng được Composite Index một cách hiệu quả nhất (Index Range Scan), câu truy vấn của bạn **BẮT BUỘC phải chứa điều kiện lọc trên Cột Dẫn Đầu (Cột 1)**.

---

## 2. Bằng Chứng Thực Nghiệm Khoa Học

Để chứng minh "Thứ tự sắp xếp cột là quyền lực của DBA", chúng ta đã thực hiện một bài lab tối ưu hóa câu truy vấn sau:
`SELECT * FROM orders_demo WHERE customer_id = 5;`
*(Khách hàng số 5 có 20 đơn hàng trên tổng số 100.000 đơn trong bảng)*

### Kịch bản 1: DBA gà mờ tạo Index sai thứ tự
```sql
CREATE INDEX idx_bad_order ON orders_demo(order_date, customer_id);
```
*   **Vấn đề:** Cột `order_date` được đẩy lên làm Cột Dẫn Đầu, nhưng trong câu `WHERE` của user hoàn toàn không có `order_date`.
*   **Hành động của Oracle:** Oracle lật Index ra và nhận thấy việc tìm `customer_id` bị kẹp giữa hàng trăm nghìn ngày tháng hỗn độn là bất khả thi.
*   **Kết quả:** Vứt bỏ Index, chọn **`TABLE ACCESS FULL`** (Cost: 171).

### Kịch bản 2: DBA thực thụ ra tay
```sql
CREATE INDEX idx_good_order ON orders_demo(customer_id, order_date);
```
*   **Vấn đề:** Đảo lại thứ tự. Đưa cột thường xuyên bị truy vấn (`customer_id`) lên làm Cột Dẫn Đầu.
*   **Hành động của Oracle:** Nhận ra Cột Dẫn Đầu khớp với điều kiện `WHERE`. Nó lao thẳng vào Index tìm đúng khu vực của khách hàng số 5, nhặt ra 20 địa chỉ ROWID và ra ổ cứng lấy dữ liệu.
*   **Kết quả:** Kích hoạt **`INDEX RANGE SCAN`** hoàn hảo (Cost: 22). Nhanh hơn gần 8 lần so với việc quét Full Bảng.

---

## 3. Nghề DBA Có Bị Thay Thế Bởi Oracle Optimizer Không?
**KHÔNG! VÀ KHÔNG BAO GIỜ!**

Bài lab này là bằng chứng thép cho thấy: **Cost-Based Optimizer (CBO) của Oracle cực kỳ thông minh, nhưng nó vô dụng nếu không có người thiết kế nền tảng cho nó.**
*   CBO biết tính toán toán học để chọn ra con đường ngắn nhất (Cost thấp nhất).
*   Nhưng **DBA mới là người xây nên những con đường đó**. Nếu DBA không tạo Index (hoặc tạo sai thứ tự), CBO không thể tự "hô biến" ra một cái Index để chạy. Nó sẽ cắn răng chọn con đường duy nhất còn lại: Full Table Scan.

**🏆 Lời khuyên vàng khi thiết kế Composite Index:**
1. Hãy quan sát ứng dụng: Cột nào luôn luôn xuất hiện trong các câu `WHERE` với dấu `=`, hãy đưa nó lên làm **Leading Column**.
2. Cột nào có tính phân loại cao (Selectivity cao - ví dụ như ID, Mã số) thì nên đứng trước cột có tính phân loại thấp (như Giới tính, Trạng thái).
