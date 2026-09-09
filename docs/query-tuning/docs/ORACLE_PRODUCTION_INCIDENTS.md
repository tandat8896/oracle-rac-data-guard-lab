# Oracle Production Incidents & Case Studies Summary
**Ngày tổng hợp:** 2026-06-12
**Người thực hiện:** OpenClaw (Assistant)
**Nguồn:** Tổng hợp từ các blog thực chiến (Savvinov, dbi-services, Tanel Poder, Andrey Nikolaev, Mohamed Houri, Osman's DBlog).

---

## 📋 Mục lục
1. [Chi tiết 5 Production Incidents](#1-chi-tiết-5-production-incidents)
   - Incident 1: TX Row Lock Contention (Unique Index)
   - Incident 2: Library Cache Mutex X (Hot Package)
   - Incident 3: GC Buffer Busy Acquire (RAC Hot Block)
   - Incident 4: TX Row Lock Contention (ForeignKey Missing Index)
   - Incident 5: Library Cache Mutex X (Flashback Parallel Storm)
2. [Tóm tắt nhanh các bài blog đã nghiên cứu](#2-tóm-tắt-nhanh-các-bài-blog-đã-nghiên-cứu)
3. [_scripts_hữu_ích](#3-script-hữu-ích)

---

## 1. Chi tiết 5 Production Incidents

### Incident #1: TX Row Lock Contention - Unique Index Collision
*Chủ đề: TX Row Lock | Nguồn: Magnus Johansson / Oracle Docs*

| Mục | Chi tiết |
| :--- | :--- |
| **Root cause** | Nhiều session concurrent cố gắng `INSERT` cùng một giá trị vào column có **Unique Index**. Session thứ 2 phải chờ session thứ 1 commit/rollback để xác định có ném lỗi `ORA-0001` hay không. |
| **Symptoms** | - Ứng dụng treo ngẫu nhiên khi insert.<br>- Wait event: `enq: TX - row lock contention`.<br>- Không có lỗi SQL, chỉ thấy chờ lâu. |
| **AWR evidence** | - Top Wait Events: `enq: TX - row lock contention` chiếm >30% DB Time.<br>- Section "Segments by Global Cache Service" (nếu RAC) hoặc "Segments by Row Lock Waits" tăng đột biến. |
| **ASH evidence** | - Query `v$active_session_history` thấy nhiều sample cùng chờ `enq: TX` trên cùng một `CURRENT_OBJ#` (object ID của index/table).<br>- `SQL_ID` trùng lặp là các lệnh INSERT vào bảng đích. |
| **Fix** | - **Ứng dụng:** Kiểm tra tồn tại trước khi insert (nhưng coi chừng race condition).<br>- **Design:** Dùng Sequence thay vì tự sinh giá trị trùng.<br>- **Xử lý nhanh:** Kill session blocker (nếu là session treo). |
| **Lesson learned** | `TX lock` mode 4 (unique index) khác với mode 6 (row update). Luôn dùng Sequence hoặc UUID cho primary key trong hệ thống high-concurrency. |

---

### Incident #2: Library Cache Mutex X - Hot Package (Oracle Apps)
*Chủ đề: Mutex Contention | Nguồn: Jagjeet Singh / Andrey Nikolaev*

| Mục | Chi tiết |
| :--- | :--- |
| **Root cause** | Package `MO_GLOBAL` (Oracle Apps) được gọi cực kỳ频繁 (high frequency) bởi hàng nghìn session concurrent. Object này trở thành "hot object", gây tranh chấp mutex khi session nào cũng muốn pin nó vào shared pool. |
| **Symptoms** | - CPU cao bất thường nhưng throughput thấp.<br>- Wait event: `library cache: mutex X` chiếm >40% DB Time.<br>- Phản hồi chậm dần khi số lượng user tăng. |
| **AWR evidence** | - Top Wait Events: `library cache: mutex X` đứng đầu.<br>- "Library Cache Activity": Get Hit Ratio vẫn cao nhưng thời gian chờ tăng.<br>- "Segments by Global Cache Service" không liên quan (vì đây là shared pool). |
| **ASH evidence** | - `v$ash` tập trung vào `event='library cache: mutex X'` và `current_obj#` trỏ vào object ID của package `MO_GLOBAL`.<br>- `sql_id` đa dạng (nhiều query khác nhau cùng gọi package này). |
| **Fix** | - Dùng undocumented procedure `dbms_shared_pool.markhot()` để đánh dấu object là "hot". Oracle sẽ tạo nhiều bản sao (copies) của object này trong shared pool, phân tán mutex theo CPU core.<br>- Cú pháp: `exec dbms_shared_pool.markhot('SCHEMA', 'PACKAGE_NAME', 1);` (chạy ngay sau startup). |
| **Lesson learned** | Với các package dùng chung (global context), contention là không tránh khỏi ở quy mô lớn. `markhot` là giải pháp "cứu cánh" cho hot object mà không cần sửa code. |

---

### Incident #3: GC Buffer Busy Acquire - RAC Hot Block
*Chủ đề: RAC Contention | Nguồn: Harmandeep Singh (LinkedIn) / Oracle RAC Docs*

| Mục | Chi tiết |
| :--- | :--- |
| **Root cause** | Một block dữ liệu "nóng" (hot block - ví dụ: right-most index leaf block của sequence, hoặc bảng cấu hình nhỏ) bị nhiều node RAC truy cập cùng lúc. Các node phải "đá" block qua lại qua interconnect (cache fusion), gây nghẽn cổ chai. |
| **Symptoms** | - Hệ thống RAC chậm đột ngột, đặc biệt khi load cao.<br>- Wait event: `gc buffer busy acquire` hoặc `gc cr request` tăng vọt.<br>- Interconnect traffic cao. |
| **AWR evidence** | - Top Wait Events: `gc buffer busy acquire` đứng đầu.<br>- "Global Cache Stats": High number of `gcr blocks received` nhưng thời gian chờ lớn.<br>- "Segments by Global Cache Service": Chỉ ra đúng bảng/index bị hot block. |
| **ASH evidence** | - `v$ash` filter `wait_class='Cluster'` thấy tập trung vào một `current_obj#`.<br>- Phân tích `p1` (file#), `p2` (block#) để xác định exact block nóng. |
| **Fix** | - **Index:** Dùng **Hash Partitioned Index** hoặc **Reverse Key Index** để phân tán hot block.<br>- **Application:** Thiết kế lại logic để giảm concurrent truy cập cùng 1 bản ghi (ví dụ: dùng local queue thay vì global counter).<br>- **Data Affinity:** Cấu hình service để routing user cùng nhóm vào 1 node. |
| **Lesson learned** | Vấn đề RAC thường không phải do SQL kém, mà do **data distribution** và **access pattern**. Hash partitioning là vũ khí mạnh nhất chống lại hot block. |

---

### Incident #4: TX Row Lock Contention - Missing Index on Foreign Key
*Chủ đề: TX Row Lock | Nguồn: Osman's DBlog*

| Mục | Chi tiết |
| :--- | :--- |
| **Root cause** | Bảng con (child table) không có index trên column Foreign Key (FK). Khi xóa/update record ở bảng mẹ (parent), Oracle phải **lock toàn bộ bảng con** để kiểm tra ràng buộc, gây chặn các session khác insert/update vào bảng con đó. |
| **Symptoms** | - DML trên bảng mẹ bị treo lâu.<br>- Nhiều session chờ `enq: TX - row lock contention` nhưng không rõ lý do vì bảng mẹ không bị lock trực tiếp.<br>- Chỉ xảy ra khi có transaction xóa brand parent record. |
| **AWR evidence** | - Top SQL: Câu lệnh `DELETE` hoặc `UPDATE` trên bảng mẹ có elapsed time rất cao.<br>- Wait events: `enq: TX - row lock contention` xuất hiện kèm theo. |
| **ASH evidence** | - `v$ash` thấy session chờ `TX lock` với `id1` (lock slot) trùng nhau.<br>- Truy vết `blocking_session` thấy session đang chạy `DELETE` trên bảng mẹ. |
| **Fix** | - **Tạo index** ngay trên column Foreign Key của bảng con: `CREATE INDEX idx_fk ON child_table(fk_column);`.<br>- Nếu không thể tạo index, phải commit transaction trên bảng mẹ nhanh hơn. |
| **Lesson learned** | Foreign Key **luôn** cần index ở bảng con để tránh lock toàn bộ bảng (table lock) và cải thiện performance join. Đây là lỗi thiết kế schema phổ biến nhất. |

---

### Incident #5: Library Cache Mutex X - Flashback Parallel Storm
*Chủ đề: Mutex Contention | Nguồn: Mohamed Houri*

| Mục | Chi tiết |
| :--- | :--- |
| **Root cause** | Lệnh `FLASHBACK TABLE` được thực hiện trong production. Oracle tự động khởi động hàng loạt **Parallel Execution Servers** (96 sessions theo công thức `CPU_COUNT * PARALLEL_THREADS_PER_CPU`) để thực hiện flashback. Mỗi server startup đều cần parse và load objects vào library cache, gây bão mutex. |
| **Symptoms** | - Database gần như "chết" (unusable) trong thời gian flashback.<br>- Wait event: `library cache: mutex X` chiếm 90-100% DB Time.<br>- Số lượng session active tăng vọt lên hàng trăm. |
| **AWR evidence** | - Report cho thấy số lượng session active cực đại.<br>- Top Event: `library cache: mutex X`. |
| **ASH evidence** | -ASH tập trung vào các session background/parallel đang khởi động.<br>- `sql_id` liên quan đến internal recursive SQL của flashback. |
| **Fix** | - Giới hạn `parallel_max_servers` xuống mức thấp (ví dụ: 8) trước khi chạy flashback.<br>- Tránh chạy flashback trên production giờ cao điểm.<br>- Nếu bắt buộc, hãy test trước để ước lượng thời gian và impact. |
| **Lesson learned** | Các lệnh "trợ giúp" (như Flashback, Gather Stats tự động) có thể kích hoạt parallelism không kiểm soát được. Luôn set giới hạn `parallel_max_servers` trong production nhạy cảm. |

---

## 2. Tóm tắt nhanh các bài blog đã nghiên cứu

| STT | Bài viết | Chủ đề chính | Điểm nhấn (Key Takeaway) |
|-----|----------|--------------|--------------------------|
| 1 | **SQL tuning: real-life example** (Savvinov) | SQL Tuning, Bind variables | Không tin `V$SQL_BIND_CAPTURE`. Phải tìm ra "heavy values" để reproduce plan sai. Dùng Outline để fix không cần sửa code. |
| 2 | **Troubleshooting Oracle Data Guard** (dbi-services) | Data Guard Sync | Checklist 3 bước: FRA đầy? `standby_file_management`? Tail alert log khi enable/disable config. |
| 3 | **Divide and conquer mutex contention** (A. Nikolaev) | Mutex X | Giải pháp `dbms_shared_pool.markhot()` cho hot objects. |
| 4 | **Resolving Enq: TX Row Lock** (Osman's DBlog) | Row Lock | Phân tích chi tiết blocker/waiter. Thiếu index FK là nguyên nhân số 1. |
| 5 | **Flash back causing mutex X** (M. Houri) | Mutex X, Parallel | Flashback kích hoạt parallel storm → mutex explosion. Giới hạn `parallel_max_servers`. |
| 6 | **RAC waits: A costly bottleneck** (LinkedIn) | RAC, GC waits | Hot block trong RAC cần Hash Partitioning hoặc Data Affinity, không chỉ tuning SQL. |

---

## 3. Script hữu ích (Dùng ngay)

### Check TX Lock Contention (Tìm Blocker)
```sql
SELECT s.sid, s.serial#, s.username, s.status, s.event, s.wait_class, s.seconds_in_wait,
       s.blocking_session, q.sql_text
FROM v$session s
LEFT JOIN v$sql q ON s.sql_id = q.sql_id
WHERE s.event = 'enq: TX - row lock contention'
   OR s.sid IN (SELECT blocking_session FROM v$session WHERE blocking_session IS NOT NULL);
```

### Check Library Cache Mutex X (Tìm Hot Object)
```sql
SELECT kglnaobj AS object_name,
       kglhdnsp AS namespace,
       kglhdclc AS locked_count,
       kglhdclc AS pinned_count
FROM x$kglob
WHERE kglhdnsp IN (2, 3, 4, 5) -- Package, Procedure, Function, Trigger
ORDER BY kglhdclc DESC
FETCH FIRST 10 ROWS ONLY;
-- Lưu ý: Cần quyền truy cập x$kglob (thường là SYS)
```

### Check RAC GC Buffer Busy (Tìm Hot Block)
```sql
SELECT o.owner, o.object_name, o.subobject_name, o.object_type,
       SUM(ash.wait_time + ash.time_waited) / 1000000 AS total_wait_sec
FROM v$active_session_history ash
JOIN dba_objects o ON ash.current_obj# = o.object_id
WHERE ash.event = 'gc buffer busy acquire'
  AND ash.sample_time > SYSDATE - 1/24
GROUP BY o.owner, o.object_name, o.subobject_name, o.object_type
ORDER BY total_wait_sec DESC;
```

### Check Data Guard Lag & FRA
```sql
-- Check Lag
SELECT name, value, unit FROM v$dataguard_stats WHERE name LIKE '%lag%';

-- Check FRA Usage
SELECT name,
       ROUND(space_limit/1024/1024, 2) AS limit_mb,
       ROUND(space_used/1024/1024, 2) AS used_mb,
       ROUND(space_reclaimable/1024/1024, 2) AS reclaimable_mb
FROM v$flash_recovery_area_usage;
```

---
*Lưu ý: Tài liệu này được tạo tự động bởi OpenClaw Assistant dựa trên yêu cầu của ông xã Đạt.*