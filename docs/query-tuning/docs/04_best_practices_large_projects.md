# 🏆 Cẩm Nang "Sống Sót" Cho DBA/Developer Trong Dự Án Lớn

Dựa trên toàn bộ những bài học khắc nghiệt từ thực tế về Oracle Query Tuning, đây là 5 Mẫu thiết kế (Patterns) và Nguyên tắc vàng bạn bắt buộc phải nằm lòng khi bước chân vào các dự án mang tầm cỡ Enterprise (Dữ liệu hàng trăm triệu đến hàng tỷ dòng).

---

## Pattern 1: Quy Tắc "Bóng Hình" (Foreign Key = Index)
*   **Thực trạng:** Khi thiết kế Database, Lập trình viên thường chỉ tạo khóa chính (PK) mà quên tạo Index cho cột Khóa ngoại (FK).
*   **Hậu quả:** Khi xóa (DELETE) bảng cha, toàn bộ bảng con bị khóa (Table Lock) gây đứng hệ thống. Khi Join bằng Nested Loops, bảng con bị Full Scan hàng ngàn lần (Cost 100.000 như bạn đã trải nghiệm).
*   **Hành động (Action):** **Mọi Khóa Ngoại đều phải có Index đi kèm.** Đây là tiêu chuẩn ép buộc trong các dự án lớn. 

## Pattern 2: Nhận Diện "Gót Chân Achilles" (Data Skew & Histograms)
*   **Thực trạng:** Chạy lệnh lấy thống kê cơ bản (`GATHER_TABLE_STATS`) là chưa đủ. Các cột mang tính phân loại như `status` (Trạng thái: 99% COMPLETED, 1% PENDING), `is_deleted` (0, 1) luôn bị Lệch dữ liệu (Data Skew).
*   **Hậu quả:** Oracle sẽ lấy trung bình cộng và đoán sai bét số dòng trả về, dẫn đến việc dùng sai thuật toán (Dùng Index khi lẽ ra nên quét bảng, hoặc quét bảng khi lẽ ra nên dùng Index).
*   **Hành động (Action):** Chủ động rà soát các cột trạng thái bị lệch dữ liệu và khai báo **Histograms**. (Trên Oracle 19c, hãy bật tính năng `FOR ALL COLUMNS SIZE AUTO` để DB tự học hỏi từ các câu truy vấn).

## Pattern 3: Phân Định Ranh Giới "Trận Địa" (OLTP vs OLAP)
Bạn phải biết câu Query mình đang viết phục vụ cho màn hình nào để tối ưu cho đúng:
*   **OLTP (App/Web API cho user):** Truy xuất thông tin của 1 hoặc vài user. 
    *   *Chiến lược:* Ép hệ thống đi theo con đường **NESTED LOOPS + INDEX UNIQUE SCAN**. Thời gian phản hồi phải tính bằng mili-giây.
*   **OLAP (Báo cáo/Thống kê ban đêm):** Quét hàng triệu đơn hàng để tính tổng doanh thu.
    *   *Chiến lược:* Quên Index đi. Hãy để hệ thống dùng **HASH JOIN + FULL TABLE SCAN**, kết hợp với đọc song song đa luồng (`PARALLEL(4)`).

## Pattern 4: Hội Chứng "Anti-Hint" (Tuyệt Đối Không Hardcode Hint)
*   **Thực trạng:** Thấy câu SQL chạy chậm, Dev lên mạng copy một cái Hint `/*+ USE_NL */` hoặc `/*+ INDEX(idx_name) */` nhét thẳng vào mã nguồn Java/C# rồi deploy.
*   **Hậu quả:** 3 năm sau, bảng phình to gấp 100 lần. Oracle Optimizer CBO biết thừa chạy Index lúc này là chết, nhưng vì bị dính Hint từ code truyền xuống, nó nhắm mắt làm theo làm Server CPU 100%. Sửa lại code Java thì mất hàng tuần để QA test lại.
*   **Hành động (Action):** Đừng viết Hint vào Application Code. Nếu cần sửa Plan gấp, DBA chuyên nghiệp sẽ dùng **SQL Profile** hoặc **SQL Plan Baselines** chèn trực tiếp từ phía Database.

## Pattern 5: Bắt Bệnh Từ "Con Số Kẻ Nói Dối" (Cột Rows)
*   **Thực trạng:** Khi đọc Explain Plan, nhiều người chỉ nhìn chằm chằm vào cột **Cost** hoặc tìm chữ **TABLE ACCESS FULL** để đổ lỗi.
*   **Hành động (Action):** Bí kíp của chuyên gia là nhìn vào cột **`Rows` (E-Rows: Estimated Rows)** đầu tiên. So sánh con số Rows mà Oracle đoán với thực tế dữ liệu của bạn.
    *   Nếu bạn biết chắc chỉ có 50 khách PLATINUM mà Oracle báo `Rows = 1667`, thì bạn đã tìm ra nguyên nhân gốc rễ!
    *   *Sửa bệnh từ gốc:* Cập nhật lại Statistics hoặc Histograms để Oracle tính lại bài toán, chứ đừng cố đi tạo thêm Index vô ích.

## Pattern 6: Top SQL — Vũ Khí Tối Thượng Khi Truy Vấn Chậm

Khi khách hàng báo "chậm", chạy câu này trước tiên:

```sql
SELECT sql_id, executions, ROUND(elapsed_time / 1e6, 1) AS total_elapsed_sec, ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 3) AS avg_elapsed_sec, ROUND(cpu_time / 1e6, 1) AS total_cpu_sec, buffer_gets, disk_reads, parsing_schema_name, SUBSTR(sql_text, 1, 100) AS sql_preview FROM v$sqlarea WHERE executions > 0 AND parsing_schema_name = 'QUERY_TUNING' ORDER BY elapsed_time DESC FETCH FIRST 20 ROWS ONLY;
```

**Kết quả lab — System queries (không có query test):**
```
SQL_ID            EXEC   TOTAL_SEC   SQL_PREVIEW
2jnz9d8909cjy        1         0.1   select parameter,value from nls_session_parameters...
32mfajmnqqhfx        1         0.1   select INITCAP(TO_CHAR(last_login...)) from dba_users...
7mvj2k568y4mh        1         0.1   SELECT sql_id, executions, ROUND(elapsed_time...
98n7q1kq9p5a7        1           0   declare l_theCursor integer default dbms_sql.open_cursor...
```
> Chỉ thấy query hệ thống. Query test (`/*+ PARALLEL */`, `/* ACS_BI */`) không xuất hiện vì đã bị flush khỏi shared pool hoặc chạy từ session SYS.

Muốn tìm query của mình, cần filter cụ thể:

```sql
SELECT sql_id, executions, ROUND(elapsed_time / 1e6, 1) AS total_sec, ROUND(cpu_time / 1e6, 1) AS cpu_spec, buffer_gets, disk_reads, SUBSTR(sql_text, 1, 80) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%orders_demo%' OR sql_text LIKE '%PARALLEL%' ORDER BY last_active_time DESC FETCH FIRST 10 ROWS ONLY;
```

**Kết quả lab — Có query test khi filter đúng:**
```
SQL_ID            EXEC   TOTAL_SEC   SQL_PREVIEW
aqpkgyd3jny8w        1           0   select sql_id, executions, round(elapsed_time...
```
> Kết quả ít vì shared pool đã bị flush. Trên production, filter đúng là thấy ngay.
