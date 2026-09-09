# Lesson 1: Làm Chủ Execution Plan Trong Oracle 19c 📊

Execution Plan (Kế hoạch thực thi) là tấm bản đồ chỉ đường mà Oracle Database (Optimizer) vẽ ra để lấy dữ liệu cho câu lệnh SQL của bạn. Học cách đọc bản đồ này là kỹ năng bắt buộc để tối ưu hóa câu lệnh.

---

## 1. Cách Tạo và Xem Execution Plan cơ bản

### Cách A: Giải thích kế hoạch dự kiến (Explain Plan)
Cách này không chạy câu lệnh thực tế mà chỉ hỏi Optimizer xem nó dự kiến sẽ chạy thế nào.

```sql
EXPLAIN PLAN FOR
SELECT * FROM employees WHERE department_id = 90;

-- Xem kết quả dưới dạng bảng đẹp mắt
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

### Cách B: Lấy kế hoạch thực tế kèm số liệu vận hành (GATHER_PLAN_STATISTICS)
Đây là cách tốt nhất khi điều chỉnh hiệu năng vì nó so sánh được ước tính của Oracle với thực tế.

```sql
-- Chạy câu lệnh kèm hint thu thập chỉ số
SELECT /*+ GATHER_PLAN_STATISTICS */ e.first_name, d.department_name
FROM employees e JOIN departments d ON e.department_id = d.department_id
WHERE d.location_id = 1700;

-- Hiển thị kế hoạch thực tế của câu lệnh gần nhất trong session
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST'));
```

---

## 2. Các Thành Phần Quan Trọng Trong Bảng Kế Hoạch

Khi bạn chạy `DBMS_XPLAN.DISPLAY_CURSOR`, bạn sẽ thấy một bảng có các cột như sau:

| Tên Cột | Ý nghĩa | Lưu ý khi tối ưu |
| :--- | :--- | :--- |
| **Id** | Số thứ tự định danh bước thực thi. | Dùng để xác định luồng chạy. |
| **Operation** | Thao tác vật lý được thực hiện (ví dụ: `TABLE ACCESS FULL`, `INDEX RANGE SCAN`, `HASH JOIN`). | Tìm kiếm các thao tác tốn kém như `TABLE ACCESS FULL` trên bảng lớn. |
| **Starts** | Số lần bước này được lặp lại. | Nếu `Starts` lớn (như trong Nested Loops), tổng thời gian sẽ tăng nhanh. |
| **E-Rows** | Estimated Rows: Số dòng Optimizer dự đoán sẽ trả về. | Dựa vào Statistics hiện tại. |
| **A-Rows** | Actual Rows: Số dòng thực tế trả về sau khi chạy. | **So sánh với E-Rows**: Nếu lệch nhau nhiều -> Statistics bị sai. |
| **A-Time** | Actual Time: Thời gian thực tế chạy bước đó. | Giúp định vị chính xác bước nào đang ngốn thời gian nhất. |
| **Buffers** | Số lượng block dữ liệu được đọc từ bộ nhớ (Logical Reads). | Càng nhỏ càng tốt. Chỉ số này phản ánh chính xác hiệu năng câu lệnh hơn là thời gian chạy đơn thuần. |

---

## 3. Quy Tắc Đọc Execution Plan
1. **Quy tắc Thụt Lề (Indentation Rule):** Thao tác nào thụt lề sâu hơn (nằm bên trong hơn) sẽ được thực hiện trước.
2. **Quy tắc Từ Trên Xuống Dưới (Top-Down):** Nếu hai thao tác có cùng mức thụt lề, thao tác nào nằm phía trên sẽ được thực hiện trước.

### Ví dụ phân tích:
```text
-------------------------------------------------------------------------------------
| Id  | Operation                    | Name              | E-Rows | A-Rows | Buffers|
-------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |                   |        |     10 |       7|
|   1 |  NESTED LOOPS                |                   |     10 |     10 |       7|
|   2 |   TABLE ACCESS FULL          | DEPARTMENTS       |      1 |      1 |       4|
|   3 |   TABLE ACCESS BY INDEX ROWID| EMPLOYEES         |     10 |     10 |       3|
|*  4 |    INDEX RANGE SCAN          | EMP_DEPT_FK_I     |     10 |     10 |       1|
-------------------------------------------------------------------------------------
```
*   **Bước 4 (`INDEX RANGE SCAN`)** thụt lề sâu nhất -> thực hiện trước để tìm các ROWID của nhân viên thuộc phòng ban đó.
*   **Bước 3 (`TABLE ACCESS BY INDEX ROWID`)** lấy thông tin chi tiết nhân viên từ bảng `EMPLOYEES` thông qua ROWID tìm được từ bước 4.
*   **Bước 2 (`TABLE ACCESS FULL`)** đọc bảng `DEPARTMENTS`.
*   **Bước 1 (`NESTED LOOPS`)** kết hợp dữ liệu giữa bước 2 và bước 3.
