# Lesson 8: SQL Runtime Diagnostics — Bat Benh SQL Dang Chay That

Sau bai 7, ban da biet partition, ACS va parallel. Bai tiep theo phai tra loi cau hoi thuc chien hon:

> SQL nay cham vi dau: sai plan, doc qua nhieu block, sort spill, wait I/O, hay lock?

Bai 1 dung `EXPLAIN PLAN` de xem du kien. Bai 8 dung cac view runtime de xem **Oracle da chay that nhu the nao**.

---

## Muc Tieu Bai Hoc

Sau bai nay ban can lam duoc 5 viec:

1. Tim SQL dang ton CPU, elapsed time, buffer gets hoac disk reads.
2. Lay `SQL_ID` va `CHILD_NUMBER` cua SQL can dieu tra.
3. Xem execution plan that bang `DBMS_XPLAN.DISPLAY_CURSOR`.
4. So sanh `E-Rows` vs `A-Rows` de biet optimizer doan sai o dau.
5. Doc wait event de biet SQL dang cho CPU, I/O, commit, lock hay network.

---

## Phan 1: Tim Top SQL Trong Shared Pool

Bat dau bang `v$sqlarea`. View nay tong hop theo parent cursor, hop de tim SQL nao dang gay anh huong lon nhat.

### 1. Top SQL Theo Elapsed Time

```sql
SELECT sql_id,
       executions,
       ROUND(elapsed_time / 1e6, 1) AS total_elapsed_sec,
       ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 3) AS avg_elapsed_sec,
       ROUND(cpu_time / 1e6, 1) AS total_cpu_sec,
       buffer_gets,
       disk_reads,
       parsing_schema_name,
       SUBSTR(sql_text, 1, 100) AS sql_preview
FROM   v$sqlarea
WHERE  executions > 0
ORDER  BY elapsed_time DESC
FETCH  FIRST 20 ROWS ONLY;
```

Ban co the paste thanh 1 dong trong SQLcl:

```sql
SELECT sql_id, executions, ROUND(elapsed_time / 1e6, 1) AS total_elapsed_sec, ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 3) AS avg_elapsed_sec, ROUND(cpu_time / 1e6, 1) AS total_cpu_sec, buffer_gets, disk_reads, parsing_schema_name, SUBSTR(sql_text, 1, 100) AS sql_preview FROM v$sqlarea WHERE executions > 0 ORDER BY elapsed_time DESC FETCH FIRST 20 ROWS ONLY;
```

**Cach doc chi tiet tung cot:**

| Cot | Y nghia | Doc the nao? |
|:---|:---|:---|
| `sql_id` | ID duy nhat cua cau SQL | Dung de tra plan, xem chi tiet |
| `executions` | So lan cau SQL duoc chay | Cang nhieu cang pho bien |
| `total_elapsed_sec` | Tong thoi gian wall-clock (giay) | Cao = SQL ban hoac cho wait |
| `avg_elapsed_sec` | Trung binh 1 lan chay (giay) | > 1s la cham cho OLTP |
| `total_cpu_sec` | Thoi gian CPU that su | Cao = SQL nang ve tinh toan |
| `buffer_gets` | So block doc trong buffer cache (logical) | Cao = doc nhieu, co the can index |
| `disk_reads` | So block doc tu disk (physical) | Cao = thieu buffer cache hoac full scan lon |
| `parsing_schema_name` | Schema da parse cau SQL | Loc schema de tim query cua minh |
| `sql_preview` | 100 ky tu dau cua SQL | Nhan biet so bo cau SQL |

> Meo: Neu `elapsed_time` cao nhung `cpu_time` thap: SQL dang doi tai nguyen (I/O, lock, commit). Neu `cpu_time` cao: SQL nang ve tinh toan (sort, hash join).

### 1.1. Vi Du Output Thuc Te: Toan `SYS` Thi Hieu Sao?

Neu ban chay cau top SQL va thay ket qua giong the nay:

```text
SQL_ID          EXECUTIONS TOTAL_ELAPSED_SEC AVG_ELAPSED_SEC TOTAL_CPU_SEC BUFFER_GETS DISK_READS PARSING_SCHEMA_NAME SQL_PREVIEW
cnq31548hb8un            1               1.2           1.150           0.0        1495         67 SYS                 BEGIN :c := dbms_spm_internal.auto_purge_sql_plan_baseline; END;
bxywuzvtp6wjg            1               0.9           0.904           0.3        9479        176 SYS                 call dbms_scheduler.auto_purge ( )
f6cz4n8y72xdc            1               0.5           0.485           0.1       21206       2641 SYS                 SELECT space_usage_kbytes FROM v$sysaux_occupants ...
```

Thi ket luan la: cau lenh dung, nhung hien tai top SQL cua database chu yeu la viec nen/noi bo cua Oracle.

#### Ket Qua Lab Cua Ban

Ban da chay:

```sql
SELECT sql_id, executions, ROUND(elapsed_time / 1e6, 1) AS total_elapsed_sec, ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 3) AS avg_elapsed_sec, ROUND(cpu_time / 1e6, 1) AS total_cpu_sec, buffer_gets, disk_reads, parsing_schema_name, SUBSTR(sql_text, 1, 100) AS sql_preview FROM v$sqlarea WHERE executions > 0 ORDER BY elapsed_time DESC FETCH FIRST 20 ROWS ONLY;
```

Ket qua top dau:

```text
SQL_ID          EXECUTIONS TOTAL_ELAPSED_SEC AVG_ELAPSED_SEC TOTAL_CPU_SEC BUFFER_GETS DISK_READS PARSING_SCHEMA_NAME SQL_PREVIEW
cnq31548hb8un            1               1.2           1.150           0.0        1495         67 SYS                 BEGIN :c := dbms_spm_internal.auto_purge_sql_plan_baseline; END;
bxywuzvtp6wjg            1               0.9           0.904           0.3        9479        176 SYS                 call dbms_scheduler.auto_purge ( )
f6cz4n8y72xdc            1               0.5           0.485           0.1       21206       2641 SYS                 SELECT space_usage_kbytes FROM v$sysaux_occupants ...
b9c6ffh8tc71f           11               0.3           0.027           0.0         143          9 SYS                 BEGIN dbms_output.enable(NULL); END;
ct9ppzr6uuzv9            1               0.3           0.272           0.1       15859       1788 SYS                 select owner, segment_name, nvl(sum(blocks), 0) from dba_segments ...
```

**Ket luan tu output nay:**

- Cau SQL top elapsed da chay dung.
- Top 20 hien tai deu la `PARSING_SCHEMA_NAME = SYS`, tuc la SQL noi bo cua Oracle.
- Chua thay SQL cua schema `QUERY_TUNING` trong top elapsed.
- Tong elapsed cao nhat chi khoang 1.2 giay, nen database hien tai khong co SQL user nao dang nang.
- Viec can lam tiep la loc rieng schema `QUERY_TUNING` hoac chay query lab co marker `/* L8_TEST */`.

**Cach doc dong dau:**

```text
SQL_ID              = cnq31548hb8un
EXECUTIONS          = 1 lan chay
TOTAL_ELAPSED_SEC   = tong mat khoang 1.2 giay
AVG_ELAPSED_SEC     = moi lan chay mat khoang 1.15 giay
TOTAL_CPU_SEC       = gan 0 giay CPU
BUFFER_GETS         = doc 1495 block logic trong memory
DISK_READS          = doc 67 block tu disk
PARSING_SCHEMA_NAME = SYS
SQL_PREVIEW         = job noi bo auto purge SQL plan baseline
```

**Ket luan DBA:**

- `PARSING_SCHEMA_NAME = SYS`: day la SQL noi bo cua Oracle, khong phai query lab cua ban.
- `TOTAL_ELAPSED_SEC` chi 0.1-1.2 giay: khong phai van de lon.
- Neu top 20 toan `SYS`, database dang kha ranh hoac ban chua chay workload user du nang.
- Dung cai nay de biet "database hien tai dang ban vi cai gi", khong phai dong nao trong top cung can sua.

Muon chi xem SQL cua user lab:

```sql
SELECT sql_id, executions, ROUND(elapsed_time / 1e6, 1) AS total_elapsed_sec, ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 3) AS avg_elapsed_sec, ROUND(cpu_time / 1e6, 1) AS total_cpu_sec, buffer_gets, disk_reads, parsing_schema_name, SUBSTR(sql_text, 1, 100) AS sql_preview FROM v$sqlarea WHERE executions > 0 AND parsing_schema_name = 'QUERY_TUNING' ORDER BY elapsed_time DESC FETCH FIRST 20 ROWS ONLY;
```

**Ket qua thuc te lab:**

```text
SQL_ID            EXEC   TOTAL_SEC   AVG_SEC   CPU_SEC   BUFFER_GETS   DISK_READS   SQL_PREVIEW
2jnz9d8909cjy        1         0.1     0.068         0           467           13   select parameter,value from nls_session_parameters...
32mfajmnqqhfx        1         0.1     0.067         0           375           15   select INITCAP(TO_CHAR(last_login...)) from dba_users...
7mvj2k568y4mh        1         0.1     0.064       0.1           168            2   SELECT sql_id, executions, ROUND(elapsed_time...
98n7q1kq9p5a7        1           0     0.047         0           896           35   declare l_theCursor integer default dbms_sql.open_cursor...
97qtbqudbrxr5        1           0     0.015         0           162            5   select * from v$version where banner like '%Oracle%'
dg4k3wmd4u3uu        1           0     0.011         0            11            0   SELECT sql_id, executions, ROUND(elapsed_time...
17d40vwcct4g6        1           0      0.01         0           124            1   select instance_name from v$instance
4rqwrcvdvwa6m        1           0     0.002         0            29            0   select sys_context('USERENV','CON_NAME') con_name from dual
658001za01gf9        1           0     0.001         0             0            0   select USER from dual
```

> Chi thay query he thong, query test (`/*+ PARALLEL */`, `/* ACS_BI */`) khong xuat hien vi da bi flush shared pool hoac chay tu session SYS. Muon bat query cua minh, dung marker comment `/* L8_TEST */`.

Neu muon bat dung query minh vua chay, gan marker comment:

```sql
SELECT /* L8_TEST */ COUNT(*), order_status FROM orders_demo GROUP BY order_status;
```

Tim lai marker do:

```sql
SELECT sql_id, executions, ROUND(elapsed_time / 1e6, 3) AS total_elapsed_sec, buffer_gets, disk_reads, parsing_schema_name, SUBSTR(sql_text, 1, 100) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L8_TEST%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Marker tuy y, mien la nhan biet duoc. VD: `/* L7 */`, `/* ACS_DEMO */`, `/* BUG_123 */`. Dung bat ky ky hieu nao de filter sau.

Neu query test da bi flush khoi shared pool, filter bang schema + ten bang:
```sql
SELECT sql_id, executions, ROUND(elapsed_time / 1e6, 1) AS total_sec, ROUND(cpu_time / 1e6, 1) AS cpu_spec, buffer_gets, disk_reads, SUBSTR(sql_text, 1, 80) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%orders_demo%' OR sql_text LIKE '%PARALLEL%' OR sql_text LIKE '%ACS_BI%' ORDER BY last_active_time DESC FETCH FIRST 10 ROWS ONLY;
```

**Ket qua lab — chi thay chinh cau query nay, query test khong xuat hien:**
```text
SQL_ID            EXEC   TOTAL_SEC   BUFFER_GETS   SQL_PREVIEW
aqpkgyd3jny8w        1           0            13   select sql_id, executions, round(elapsed_time/ 1e6...
```
> Query test (`/*+ PARALLEL */`, `/* ACS_BI */`) da bi flush khoi shared pool hoac chay tu session SYS. Dung marker comment ngay tu dau de tranh mat dau vet.

> Meo nho: Top SQL la bang xep hang. Neu ban chua tao "van dong vien" cua minh bang cach chay workload lab, Oracle se hien cac viec nen cua no len dau bang.

### 2. Top SQL Theo Buffer Gets

`buffer_gets` la chi so DBA rat hay dung, vi no cho biet SQL doc bao nhieu block logic.

```sql
SELECT sql_id,
       executions,
       buffer_gets,
       ROUND(buffer_gets / NULLIF(executions, 0), 0) AS avg_buffer_gets,
       disk_reads,
       ROUND(cpu_time / NULLIF(executions, 0) / 1e6, 3) AS avg_cpu_sec,
       SUBSTR(sql_text, 1, 100) AS sql_preview
FROM   v$sqlarea
WHERE  executions > 0
  AND  buffer_gets > 0
ORDER  BY buffer_gets DESC
FETCH  FIRST 20 ROWS ONLY;
```

**Dau hieu nguy hiem:**

- `avg_buffer_gets` cao cho mot query OLTP tra ve it dong.
- `buffer_gets` cao nhung `disk_reads` thap: ton CPU/memory vi scan qua nhieu block trong cache.
- `disk_reads` cao: buffer cache khong giu duoc du lieu hoac query full scan du lieu lon.

**Ket qua lab — Top 20 theo buffer_gets:**

```text
SQL_ID            EXEC   BUFFER_GETS   AVG_BUF   DISK_READS   AVG_CPU_SEC   SQL_PREVIEW
bxywuzvtp6wjg        1          9479       9479          176         0.314   call dbms_scheduler.auto_purge()
0sbbcuruzd66f      2158          6403          3          170             0   select /*+ rule */ bucket_cnt, row_cnt...
acmvv4fhdc9zh       909          3876          4          121             0   select obj#,type#,ctime,mtime,stime...
b13g21mgg8y98         2          3835       1918           44         0.018   insert /* KSXM:TAKE_SNPSHOT */ ...
175834tqvwuth          2          1457        729          626         0.012   SELECT /* L8_TEST */ COUNT(*)...
7pfr68nf6q2af         1          1256       1256         1006         0.019   DECLARE job BINARY_INTEGER := :job;...
```

> Top 20 chu yeu la SYS job (auto_purge, gather stats). Query `/* L8_TEST */` cua ban dung o vi tri buffer_gets = 1457, disk_reads = 626 — doc kha nhieu block tu disk vi la full scan.

---

## Phan 2: Lay Plan That Bang DISPLAY_CURSOR

`EXPLAIN PLAN` chi la du kien (luu o PLAN_TABLE, khong chay that). Khi tuning, uu tien plan da chay that trong shared pool (SGA - Library Cache). `DBMS_XPLAN.DISPLAY_CURSOR` doc plan tu `v$sql_plan` trong SGA, cho thay so lieu thuc te nhu Starts, A-Rows, A-Time, Buffers.

### 1. Chay Query Co GATHER_PLAN_STATISTICS

```sql
SELECT /*+ GATHER_PLAN_STATISTICS LESSON8_DEMO */
       order_status,
       COUNT(*)
FROM   orders_demo
GROUP  BY order_status;
```

### 2. Xem Plan Gan Nhat Trong Session

```sql
SELECT *
FROM   TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
         format => 'ALLSTATS LAST +PEEKED_BINDS +PREDICATE'
       ));
```

> ⚠️ **Luu y:** DISPLAY_CURSOR khong co `sql_id` se xem **query cuoi cung ban vua chay**. Neu ban chay DISPLAY_CURSOR roi moi chay query co data → no se xem chinh cau DISPLAY_CURSOR (E-Rows), khong phai query data. Luon chay **query co hint TRUOC**, roi ngay lap tuc chay DISPLAY_CURSOR.

**Ket qua thuc te lab — DISPLAY_CURSOR co actual stats:**

```text
-----------------------------------------------------------------------------------------------------------------------
| Id  | Operation          | Name        | Starts | E-Rows | A-Rows |   A-Time   | Buffers |  OMem |  1Mem | Used-Mem |
-----------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |             |      1 |        |      2 |00:00:00.01 |     625 |       |       |          |
|   1 |  HASH GROUP BY     |             |      1 |      2 |      2 |00:00:00.01 |     625 |  1345K|  1345K|  655K (0)|
|   2 |   TABLE ACCESS FULL| ORDERS_DEMO |      1 |    100K|    100K|00:00:00.01 |     625 |       |       |          |
-----------------------------------------------------------------------------------------------------------------------
```

**Ket luan:**
- E-Rows (100K) = A-Rows (100K) ✅ Oracle doan chinh xac
- Starts = 1 ✅ Full scan 1 lan
- A-Time = 0.01s ✅ Rat nhanh
- Buffers = 625 ✅ Hop ly cho bang 100K dong

Neu can xem theo `SQL_ID`:

```sql
SELECT sql_id, child_number, plan_hash_value, executions, sql_text FROM v$sql WHERE sql_text LIKE '%LESSON8_DEMO%' AND sql_text NOT LIKE '%v$sql%' ORDER BY last_active_time DESC;
```

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'SQL_ID_O_DAY', format => 'ALLSTATS LAST +PEEKED_BINDS +PREDICATE'));
```

### 3. Cot Quan Trong Nhat: E-Rows vs A-Rows

**Ket qua thuc te lab cua ban:**

```text
-----------------------------------------------------------------------------------------------------------------------
| Id  | Operation          | Name        | Starts | E-Rows | A-Rows |   A-Time   | Buffers |  OMem |  1Mem | Used-Mem |
-----------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |             |      1 |        |      2 |00:00:00.01 |     625 |       |       |          |
|   1 |  HASH GROUP BY     |             |      1 |      2 |      2 |00:00:00.01 |     625 |  1345K|  1345K|  655K (0)|
|   2 |   TABLE ACCESS FULL| ORDERS_DEMO |      1 |    100K|    100K|00:00:00.01 |     625 |       |       |          |
-----------------------------------------------------------------------------------------------------------------------
```

### 4. Giai Thich Tung Cot Trong Plan

| Cot | Y nghia | Doc the nao? |
|:---|:---|:---|
| `Id` | Buoc trong plan | 0 = ket qua, 1 = group by, 2 = doc bang |
| `Operation` | Thao tac | TABLE ACCESS FULL = full scan, HASH GROUP BY = group bang hash |
| `Name` | Object | Ten bang hoac index |
| `Starts` | So lan thao tac duoc thuc hien | 1 = chay 1 lan. >1 = bi Nested Loops nhieu lan (nguy hiem!) |
| `E-Rows` | Oracle **du kien** so dong | So sanh vs A-Rows de biet optimizer co doan dung khong |
| `A-Rows` | **Thuc te** so dong tra ve | So lieu that, khong phai uoc tinh |
| `A-Time` | Thoi gian thuc te (actual time) | 00:00:00.01 = 0.01 giay (10ms) - rat nhanh |
| `Buffers` | So block doc trong buffer cache | 625 block x 8KB = ~5MB. Cao = nhieu doc |
| `OMem` | Bo nho uoc tinh cho operation | 1345K = Oracle du kien can 1.3MB |
| `1Mem` | Bo nho toi thieu cho 1 pass | 1345K = giong OMem, can 1 pass |
| `Used-Mem` | Bo nho **thuc te** da dung | 655K = chi dung 655KB (tiet kiem hon du kien) |

### 5. Cach Doc Nhu DBA

Voi ket qua lab:

| Check | Ket qua | Danh gia |
|:---|:---|:---|
| E-Rows vs A-Rows (dòng 2) | 100K vs 100K | ✅ Oracle đoán **chính xác** |
| E-Rows vs A-Rows (dòng 1) | 2 vs 2 | ✅ GROUP BY trả về 2 dòng đúng |
| Starts | 1 | ✅ Chỉ full scan 1 lần |
| A-Time | 0.01s | ✅ Rất nhanh |
| Buffers | 625 | ✅ 625 block ~ 5MB, bảng 100K dòng là hợp lý |
| Used-Mem | 655K | ✅ Hash group by tốn ít bộ nhớ |

**Ket luan:** Query nay chay ngon, khong can tune.**

- `E-Rows = 10000`, `A-Rows = 100000`: optimizer doan thieu 10 lan.
- Neu lech tren 10x, nghi ngay den stale stats, missing histogram, predicate phuc tap, bind variable hoac data skew.
- `Buffers = 742`: query da doc 742 block logic.

> Quy tac nhanh: plan sai thuong bat dau tu cardinality sai. Hay nhin `E-Rows` vs `A-Rows` truoc khi them index.

---

## Phan 3: Kiem Tra SQL Dang Wait Gi

Khi SQL dang chay lau, xem session hien tai:

```sql
SELECT sid,
       serial#,
       username,
       status,
       sql_id,
       event,
       wait_class,
       seconds_in_wait,
       blocking_session,
       module,
       program
FROM   v$session
WHERE  status = 'ACTIVE'
  AND  type = 'USER'
ORDER  BY seconds_in_wait DESC;
```

### Bang Dich Wait Event Co Ban

| Wait event / class | Thuong co nghia la | Huong kiem tra |
|:---|:---|:---|
| `db file sequential read` | Doc single block, hay gap khi index lookup nhieu | Index co dung khong, clustering factor, rowid fetch qua nhieu |
| `db file scattered read` | Multiblock read, full table scan | Full scan co dung muc dich khong, can partition/index khong |
| `direct path read` | Direct read, hay gap parallel/full scan lon | Parallel, PGA, temp, workload OLAP |
| `log file sync` | Session doi commit ghi redo | App commit qua nhieu, redo storage cham |
| `enq: TX - row lock contention` | Bi session khac lock row | Tim `blocking_session`, xu ly transaction treo |
| `SQL*Net message from client` | Session dang idle cho app | Thuong bo qua khi tuning SQL |

### Demo Lock That — 2 Session RAC

**Setup:** Terminal 1 (rac1) UPDATE khong commit, Terminal 2 (rac2) UPDATE/FOR UPDATE cung row.

**Ket qua check tu rac1 (gv$session de thay ca 2 RAC instances):**

```sql
SELECT sid, serial#, username, event, wait_class, seconds_in_wait, blocking_session, sql_id FROM gv$session WHERE wait_class != 'Idle' AND state = 'WAITING' AND username = 'QUERY_TUNING';
```

**Output:**
```text
SID   SERIAL#   USERNAME       EVENT                           WAIT_CLASS      SECONDS_IN_WAIT   BLOCKING_SESSION   SQL_ID
54      49528   QUERY_TUNING   enq: TX - row lock contention   Application                 137                 67   565rmtamqv0yy
```

**Y nghia:**
- `SID = 54` (rac2) dang cho SID = 67 (rac1) release lock
- `EVENT = enq: TX - row lock contention` — lock row
- `SECONDS_IN_WAIT = 137` — da cho 137 giay
- `WAIT_CLASS = Application` — loi tu phia user (session 1 chua commit)

**Cach xu ly:** Terminal 1 chay `ROLLBACK;` hoac `COMMIT;`. Session 2 tu chay tiep.

### Bang Ke: Lenh Nao Bi Lock, Lenh Nao Khong?

| Lenh | Bi lock? | Ly do |
|:---|:---|:---|
| `SELECT ... WHERE id = 10` | ❌ **Khong** | Doc UNDO, khong can lock |
| `SELECT ... FOR UPDATE` | ✅ **Co** | Yeu cau lock de chuan bi update sau |
| `UPDATE ... WHERE id = 10` | ✅ **Co** | Can lock moi sua duoc |
| `DELETE ... WHERE id = 10` | ✅ **Co** | Can lock moi xoa duoc |
| `INSERT ...` | ❌ Thuong khong | Insert row moi, khong trung row cu |

### So Sanh Oracle vs Postgres: Co Che Lock & Doc

| Tinh nang | Oracle (UNDO) | Postgres (MVCC) |
|:---|:---|:---|
| **Luu ban cu o dau?** | UNDO tablespace rieng | Ngay trong block cua bang (dead tuples) |
| **Hau qua?** | Khong bloat table | Dead tuples → bang phinh to |
| **Don dep?** | Tu dong (undo retention) | **VACUUM** — phai chay thuong xuyen |
| **SELECT bi lock?** | ❌ Khong (doc UNDO) | ❌ Khong (doc MVCC) |
| **UPDATE bi lock?** | ✅ Co | ✅ Co |
| **Gia thanh** | $47K/core | Free |

---

## Phan 4: Mini Workflow DBA Khi Gap SQL Cham

### Buoc 1: Tim SQL_ID

```sql
SELECT sql_id,
       executions,
       ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 3) AS avg_elapsed_sec,
       ROUND(buffer_gets / NULLIF(executions, 0), 0) AS avg_buffer_gets,
       SUBSTR(sql_text, 1, 100) AS sql_preview
FROM   v$sqlarea
WHERE  sql_text LIKE '%orders_demo%'
  AND  sql_text NOT LIKE '%v$sqlarea%'
ORDER  BY last_active_time DESC;
```

### Buoc 2: Xem Child Cursor

```sql
SELECT sql_id,
       child_number,
       plan_hash_value,
       executions,
       is_bind_sensitive,
       is_bind_aware
FROM   v$sql
WHERE  sql_id = 'SQL_ID_O_DAY'
ORDER  BY child_number;
```

Neu co nhieu `child_number`, co the lien quan den bind variable, adaptive cursor sharing, setting session khac nhau, hoac invalidation.

### Buoc 3: Xem Plan That

```sql
SELECT *
FROM   TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
         sql_id          => 'SQL_ID_O_DAY',
         cursor_child_no => 0,
         format          => 'ALLSTATS LAST +PEEKED_BINDS +PREDICATE'
       ));
```

### Buoc 4: Ket Luan Nguyen Nhan

| Dau hieu | Nguyen nhan kha nang cao | Bai da hoc lien quan |
|:---|:---|:---|
| `E-Rows` lech `A-Rows` rat lon | Stats/histogram sai hoac data skew | Bai 2, Bai 7 ACS |
| Full table scan tren bang lon OLTP | Thieu index hoac index bi suppress | Bai 5, Bai 6 |
| Nested Loops lap qua nhieu lan | Sai driving table hoac thieu index FK | Bai 3 |
| `TempSpc` lon, sort/hash spill | PGA thieu hoac sort/hash qua lon | Bai 4, memory tuning PGA |
| Co `PX COORDINATOR` nhung van cham | Parallel bi thieu tai nguyen/I/O bottleneck | Bai 7 |
| Wait `enq: TX` | Lock, khong phai query plan | DBA session/transaction |

---

## Bai Tap Thuc Hanh

### Bai 1: Chup Plan That Cua Query Group By

```sql
SELECT /*+ GATHER_PLAN_STATISTICS L8_GROUP_BY */
       order_status,
       COUNT(*)
FROM   orders_demo
GROUP  BY order_status;

SELECT *
FROM   TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
         format => 'ALLSTATS LAST +PREDICATE'
       ));
```

Ghi lai:

- Operation chinh la gi?
- `E-Rows` va `A-Rows` co lech khong?
- `Buffers` bao nhieu?

### Bai 2: So Sanh Index Scan Va Full Scan

```sql
SELECT /*+ GATHER_PLAN_STATISTICS L8_CANCELLED */
       *
FROM   orders_demo
WHERE  order_status = 'CANCELLED';

SELECT *
FROM   TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
         format => 'ALLSTATS LAST +PREDICATE'
       ));
```

```sql
SELECT /*+ GATHER_PLAN_STATISTICS L8_COMPLETED */
       *
FROM   orders_demo
WHERE  order_status = 'COMPLETED';

SELECT *
FROM   TABLE(DBMS_XPLAN.DISPLAY_CURSOR(
         format => 'ALLSTATS LAST +PREDICATE'
       ));
```

So sanh:

- Gia tri nao dung index?
- Gia tri nao nen full scan?
- `Buffers` cua 2 query khac nhau bao nhieu?

### Bai 3: Tim Query Cua Minh Trong `v$sqlarea`

```sql
SELECT sql_id,
       executions,
       ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 3) AS avg_elapsed_sec,
       buffer_gets,
       disk_reads,
       SUBSTR(sql_text, 1, 100) AS sql_preview
FROM   v$sqlarea
WHERE  sql_text LIKE '%L8_%'
  AND  sql_text NOT LIKE '%v$sqlarea%'
ORDER  BY last_active_time DESC;
```

---

## Checklist Ket Thuc Bai 8

Truoc khi qua bai tiep theo, ban nen tra loi duoc:

- SQL cham co `SQL_ID` nao?
- Plan dang xem la plan du kien hay plan da chay that?
- `E-Rows` va `A-Rows` lech bao nhieu lan?
- Buoc nao ton `Buffers` nhieu nhat?
- SQL dang ton CPU hay dang wait?
- Neu dang wait, wait event thuoc loai nao?

---

## Tong Ket Bai 8

| Cong cu | Dung khi nao | Gia tri chinh |
|:---|:---|:---|
| `v$sqlarea` | Tim top SQL tong quan | CPU, elapsed, buffer gets, disk reads |
| `v$sql` | Xem child cursor/plan hash | `child_number`, bind sensitive/aware |
| `DBMS_XPLAN.DISPLAY_CURSOR` | Xem plan that da chay | `E-Rows`, `A-Rows`, `Buffers`, predicate |
| `v$session` | SQL dang chay dang wait gi | event, wait class, blocking session |

Bai 9 nen di tiep sang **AWR/ASH va performance report**: cach chup snapshot, doc Top SQL, Top Events, Load Profile va so sanh truoc/sau khi tuning.
