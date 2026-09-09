# Oracle 19c Query Tuning Study & Practice Lab 🚀

Chào mừng bạn đến với không gian tự học và thực hành tối ưu hóa câu lệnh SQL (Query Tuning) trên cơ sở dữ liệu **Oracle 19c**.

Thư mục này được thiết lập để lưu trữ các tài liệu, hướng dẫn (Skills), kịch bản SQL thực hành (Hands-on labs), và các ghi chú thực tế trong quá trình tối ưu hóa.

---

## 📂 Cấu Trúc Thư Mục Dự Kiến
Để việc học tập và thực hành được ngăn nắp, chúng ta sẽ tổ chức không gian làm việc như sau:

*   **`README.md`**: File hướng dẫn chung (chính là file này).
*   **`docs/`**: Chứa các bài viết lý thuyết, hướng dẫn chi tiết (Skills) về tối ưu hóa.
    *   `docs/01_execution_plan.md`: Tìm hiểu và đọc Execution Plan.
    *   `docs/02_optimizer_statistics.md`: Optimizer statistics, histogram và data skew.
    *   `docs/03_join_operations.md`: Các thuật toán join và lỗi chọn sai driving table.
    *   `docs/04_sort_merge_join.md`: Sort merge join, TempSpc và disk sort.
    *   `docs/05_composite_index.md`: Thiết kế composite index.
    *   `docs/06_index_suppress.md`: Các lỗi làm Oracle không dùng index.
    *   `docs/07_partitioning_acs_parallel.md`: Partitioning, Adaptive Cursor Sharing và Parallel Execution.
    *   `docs/08_sql_runtime_diagnostics.md`: Tìm top SQL, đọc plan thật, wait event và runtime diagnostics.
    *   `docs/09_awr_ash_performance_report.md`: Đọc AWR/ASH report, Top Events, Top SQL và DB Time.
    *   `docs/10_lock_blocking_session.md`: Truy blocking session, row lock contention và xử lý lock an toàn.
    *   `docs/11_sql_plan_management_tuning_advisor.md`: SQL Tuning Advisor, SQL Profile, SQL Plan Baseline và chống plan regression.
    *   `docs/12_optimizer_algorithms.md`: Thuật toán optimizer: cardinality, selectivity, access path, join method và plan regression.
    *   `docs/13_buffer_cache_flow.md`: Buffer cache, LIO/PIO, index leaf block, rowid lookup và clustering factor.
    *   `docs/14_subquery_query_transformation.md`: NOT IN/NULL, EXISTS, semi/anti join, scalar subquery và CTE transformation.
*   **`labs/`**: Chứa các script SQL tạo cấu trúc bảng giả lập và các bài tập thực hành.
    *   `labs/setup_demo_schema.sql`: Khởi tạo bảng dữ liệu demo cỡ lớn (Customers, Orders, Order_Items).
    *   `labs/lab01_execution_plan.sql`: Thực hành xem Execution Plan của các câu lệnh khác nhau.
    *   `labs/lab02_index_scans.sql`: Thực hành so sánh hiệu năng giữa Table Scan và các loại Index Scan.

---

## 🎯 Lộ Trình Thực Hành (Roadmap)

### Phần 1: Xây dựng môi trường Lab (Init Lab Schema)
*   Tạo ra các bảng dữ liệu mẫu có kích thước đủ lớn để thấy rõ sự khác biệt về mặt hiệu năng (ví dụ: bảng `orders` chứa ~1 triệu dòng dữ liệu).
*   Thực hiện truy vấn không tối ưu và đo lường thời gian chạy cũng như tài nguyên tiêu thụ.

### Phần 2: Làm chủ Execution Plan
*   Học cách sử dụng `EXPLAIN PLAN FOR`, `DBMS_XPLAN.DISPLAY`, và `AUTOTRACE`.
*   Đọc và hiểu các thành phần quan trọng: **Operation, Rows, Bytes, Cost (%CPU), Time**.

### Phần 3: Kỹ Thuật Tối Ưu Hóa Thực Tế
*   **Index Tuning**: Tránh Index Suppress (vô hiệu hóa index do hàm/kiểu dữ liệu), sử dụng Composite Index phù hợp.
*   **Join Tuning**: Ép kiểu join thích hợp khi CBO chọn sai bằng cách sử dụng hints.
*   **Histograms**: Giúp Optimizer hiểu được sự phân phối dữ liệu không đồng đều (data skewness).

### Phần 4: Runtime Diagnostics Cho DBA
*   Tìm SQL đang tốn tài nguyên bằng `v$sqlarea`.
*   Xem execution plan thật bằng `DBMS_XPLAN.DISPLAY_CURSOR`.
*   Đọc `E-Rows` vs `A-Rows`, `Buffers`, `Wait Event` để kết luận nguyên nhân trước khi sửa.
*   Đọc AWR/ASH report để xác định Top Events, Top SQL và thời điểm xảy ra sự cố.
*   Truy blocking session khi gặp `enq: TX - row lock contention`.

---

## 🛠️ Công Cụ Cần Chuẩn Bị
Để thực hành tốt nhất, bạn nên có sẵn:
1.  **Oracle Database 19c** (Local, Docker container, hoặc Cloud).
2.  **SQL Developer**, **PL/SQL Developer**, hoặc công cụ dòng lệnh **SQL*Plus / SQLcl**.
