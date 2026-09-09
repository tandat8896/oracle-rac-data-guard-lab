# Lesson 9: AWR & ASH — Performance Report

## 0. AWR/ASH Là Gì?

- **AWR** (Automatic Workload Repository): Snapshot hiệu năng DB định kỳ (mỗi 1h), giữ 8 ngày.
- **ASH** (Active Session History): Lịch sử session active, xem được query đã chạy trong quá khứ.

Cả 2 có sẵn trong Oracle, không cần cài thêm. Lab học tập xài thoải mái.

> **License note quan trong:** AWR/ASH thuoc Oracle Diagnostics Pack. Homelab/dev/test/prototype/demo de hoc thi co the dung trong pham vi lab. Production hoac moi truong xu ly du lieu business/commercial chi dung AWR/ASH khi da co Diagnostics Pack license. Neu production khong co license, dung nhanh free o muc 8.

## 1. Kiểm Tra AWR Đang Bật

```sql
SELECT snap_interval, retention, topnsql FROM dba_hist_wr_control;
```

**Kết quả lab:**
```
SNAP_INTERVAL          RETENTION            TOPNSQL
+00 01:00:00.000000    +08 00:00:00.000000  DEFAULT
```

> Snapshot mỗi 1 giờ, giữ 8 ngày.

## 2. Xem Snapshot

```sql
SELECT MIN(snap_id), MAX(snap_id), COUNT(*) FROM dba_hist_snapshot;
```

## 3. Tạo Snapshot Tay

```sql
EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();
```

## 4. Tìm DBID Cho AWR Report

```sql
SELECT dbid, instance_number, instance_name FROM dba_hist_database_instance;
```

**Kết quả lab (RAC 2 node):**
```
DBID             INSTANCE_NUMBER   INSTANCE_NAME
2326306786                      1   racdb1
2326306786                      2   racdb2
1231980070                      1   racdb1
1231980070                      2   racdb2
```

> PDB1 có dbid = 1231980070.

## 5. Generate AWR Report

```sql
-- Xem snapshot thuoc instance nao
SELECT snap_id, instance_number FROM dba_hist_snapshot ORDER BY snap_id;
```

**Ket qua lab (RAC, PDB1 dbid=1231980070):**
```
SNAP_ID   INSTANCE_NUMBER
     33                 1
     34                 1
     35                 1
     36                 1
     37                 1
     38                 1
```

```sql
-- Generate AWR text report (thay begin_snap, end_snap bang snap_id co that)
SELECT * FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_TEXT(1231980070, 1, 37, 38));
```

> Neu bi loi "re-started during specified snapshot interval", chon 2 snap_id lien nhau tu cung 1 instance khong co restart DB.

## 6. Đọc AWR Report — Phân Tích Kết Quả Lab

### Kết quả AWR Report (snap 37-38, PDB1):

**Thông tin hệ thống:**
```
DB Name: RACDB | DB Id: 1231980070 | RAC: YES | CDB: YES
Host: rac1 | CPUs: 2 | RAM: 7.31 GB
Instance: racdb1 | Startup: 10-Jun-26 08:22
Container: PDB1 (CON_ID: 4)
```

**Load Profile — Tổng quan workload:**
| Metric | Giá trị |
|:---|---:|
| DB Time | 0.89 phút |
| Elapsed | 60.00 phút |
| DB Time/s | 0.0s |
| Redo size/s | 2.4 bytes |
| Logical reads/s | 2.1 blocks |
| Physical reads/s | 0.0 blocks |
| Hard parses/s | 0.1 |
| Executes/s | 0.6 |

**Top Events — Sự kiện chờ nhiều nhất:**
| Event | Waits | Time (s) | %DB Time | Wait Class |
|:---|---:|---:|---:|:---|
| **enq: TX - row lock contention** ⚠️ | 1 | **52.9** | **98.9%** | Application |
| DB CPU | | 0.4 | 0.8% | |
| db file sequential read | 13 | 0 | 0.1% | User I/O |
| log file sync | 2 | 0 | 0.1% | Commit |

**Top SQL (theo Elapsed Time) — SQL tốn thời gian nhất:**
| Elapsed (s) | Exec | Per Exec (s) | %Total | SQL Id | SQL Text |
|---:|---:|---:|---:|:---|---:|
| **52.9** ⚠️ | 1 | **52.86** | **98.9%** | aa7t6babr24zf | update orders_demo set total_amount=888 where order_id=10 |
| 0.1 | 15 | 0.01 | 0.2% | 6hnhqahphpk8n | select free_mb from v$asm_diskgroup_stat |
| 0.1 | 2 | 0.05 | 0.2% | fxzttyhrt9ggu | update orders_demo set total_amount=888 where order_id=10 |
| 0.1 | 3 | 0.03 | 0.2% | 3kqrku32p6sfn | MERGE INTO OPTSTAT_USER_PREFS$ |

### Các dòng cần lưu ý khi đọc AWR report:

| Mục | Nhìn vào | Dấu hiệu nguy hiểm |
|:---|:---|:---|
| **Top Events** | Hàng đầu tiên | Một event chiếm > 50% DB time |
| **Top SQL (Elapsed)** | Elapsed time vs CPU | Elapsed cao nhưng CPU thấp = đang chờ (lock, I/O) |
| **Top SQL (CPU)** | CPU time | CPU cao = query nặng về tính toán |
| **Top SQL (Gets)** | Buffer gets/exec | > 100K buffer gets/exec là cao |
| **Top SQL (Reads)** | Physical reads/exec | > 10K disk reads/exec là nhiều |
| **Load Profile** | DB Time vs Elapsed | DB Time << Elapsed = DB rảnh |

### Kết luận từ AWR lab:

> ⚠️ **98.9% DB time** do 1 câu `UPDATE` bị lock — lock là sát thủ số 1 trên production.
>
> DB hầu như idle, không có vấn đề hiệu năng thực sự.
>
> AWR report này là **bằng chứng sống**: 1 user quên commit cũng đủ làm production tê liệt.

## 7. ASH — Active Session History

```sql
-- ASH có dữ liệu không?
SELECT COUNT(*) FROM v$active_session_history;

-- Top SQL trong ASH gần đây
SELECT sql_id, session_state, COUNT(*) AS cnt
FROM v$active_session_history
WHERE sample_time > SYSTIMESTAMP - INTERVAL '1' HOUR
GROUP BY sql_id, session_state
ORDER BY cnt DESC
FETCH FIRST 10 ROWS ONLY;

-- Session đang ON CPU
SELECT sql_id, COUNT(*) AS cpu_samples
FROM v$active_session_history
WHERE session_state = 'ON CPU'
  AND sample_time > SYSTIMESTAMP - INTERVAL '1' HOUR
GROUP BY sql_id
ORDER BY cpu_samples DESC
FETCH FIRST 10 ROWS ONLY;
```

## 7. Lưu ý License

- AWR/ASH thuộc **Oracle Diagnostics Pack**.
- SQL Tuning Advisor, SQL Profiles, SQL Monitor thuộc **Tuning Pack** hoặc lien quan Tuning Pack.
- Homelab/dev/test/prototype/demo de hoc: co the dung trong pham vi lab.
- Production hoac moi truong xu ly du lieu business/commercial: phai co license pack tuong ung.
- Parameter `control_management_pack_access = DIAGNOSTIC+TUNING` chi noi rang feature dang bat ve mat ky thuat, khong chung minh da mua license.
- Neu production khong co license, DBA nen set `control_management_pack_access = NONE` va dung nhanh free ben duoi.

Kiem tra:

```sql
SHOW PARAMETER control_management_pack_access;
```

Neu ket qua:

```text
control_management_pack_access string DIAGNOSTIC+TUNING
```

Thi AWR/ASH/Tuning Pack dang mo ve mat ky thuat.

**Ket qua kiem tra lab hien tai cua ban:**

```text
DB: RACDB
Role: PRIMARY
CDB: YES
PDB: PDB1 READ WRITE
Instances: racdb1/rac1, racdb2/rac2
User sessions: chu yeu SYS/SYSRAC
User workload: QUERY_TUNING.ORDERS_DEMO 100000 rows, CUSTOMERS_DEMO 5000 rows, HR sample
```

Ket luan: day co dang homelab/training, khong thay dau hieu app production that. Dung AWR/ASH de hoc bai 9/10 la on. Nhung khong ap dung len production neu chua xac nhan license.

## 8. Nhanh Free Neu Khong Co Diagnostics Pack

Neu khong duoc dung AWR/ASH, van co the chan doan bang cac view/runtime tool free:

```sql
-- Top SQL hien tai trong shared pool
SELECT sql_id, executions, ROUND(elapsed_time / 1e6, 1) AS total_elapsed_sec, ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 3) AS avg_elapsed_sec, ROUND(cpu_time / 1e6, 1) AS total_cpu_sec, buffer_gets, disk_reads, parsing_schema_name, SUBSTR(sql_text, 1, 100) AS sql_preview FROM v$sqlarea WHERE executions > 0 ORDER BY elapsed_time DESC FETCH FIRST 20 ROWS ONLY;
```

```sql
-- Session dang wait/block hien tai
SELECT sid, serial#, username, status, sql_id, event, wait_class, seconds_in_wait, blocking_session, program FROM v$session WHERE type = 'USER' AND wait_class != 'Idle' ORDER BY seconds_in_wait DESC;
```

```sql
-- Top system wait tu luc instance start
SELECT event, wait_class, total_waits, ROUND(time_waited_micro / 1e6, 1) AS time_waited_sec, ROUND(time_waited_micro / NULLIF(total_waits, 0) / 1000, 3) AS avg_wait_ms FROM v$system_event WHERE wait_class != 'Idle' ORDER BY time_waited_micro DESC FETCH FIRST 20 ROWS ONLY;
```

```sql
-- Xem plan that cua SQL vua chay
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST +PREDICATE'));
```

## Tổng Kết

| Công cụ | Mục đích | License? |
|:---|:---|:---|
| AWR Report | Top SQL, Top Events, Load Profile theo thời gian | Diagnostics Pack tren production |
| ASH | Lịch sử session active real-time | Diagnostics Pack tren production |
| `v$sql` + DISPLAY_CURSOR | Xem plan từng SQL | Free |

**Bài tiếp theo:** [Lesson 10: Lock & Blocking Session](10_lock_blocking_session.md) — từ AWR event `enq: TX - row lock contention` truy ra waiter, blocker, object bị lock và cách xử lý an toàn.



report example :

SYS@racdb1[PDB1]> SELECT snap_id, instance_number FROM dba_hist_snapshot ORDER BY snap_id;
  SNAP_ID   INSTANCE_NUMBER
        1                 1
        1                 2
       23                 2
       23                 1
       24                 2
       24                 1
       25                 2
       25                 1
       26                 1
       27                 2
       27                 1
       28                 2
       28                 1
       29                 2

  SNAP_ID   INSTANCE_NUMBER
       29                 1
       30                 2
       30                 1
       31                 1
       32                 2
       32                 1
       33                 1
       34                 1
       35                 1
       36                 1
       37                 1
       38                 2
       38                 1


27 rows selected.

SYS@racdb1[PDB1]> SELECT * FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_TEXT(1231980070, 1, 37, 38));
OUTPUT
WORKLOAD REPOSITORY PDB report (root snapshots)

DB Name         DB Id    Unique Name DB Role          Edition Release    RAC CDB
------------ ----------- ----------- ---------------- ------- ---------- --- ---
RACDB         1231980070 racdb       PRIMARY          EE      19.0.0.0.0 YES YES

Instance     Inst Num Startup Time
------------ -------- ---------------
racdb1              1 10-Jun-26 08:22

Container DB Id  Container Name       Open Time
--------------- --------------- ---------------
     2326306786 PDB1            10-Jun-26 08:22


OUTPUT
Host Name        Platform                         CPUs Cores Sockets Memory(GB)
---------------- -------------------------------- ---- ----- ------- ----------
rac1             Linux x86 64-bit                    2     2       2       7.31

              Snap Id      Snap Time      Sessions Curs/Sess Instances
            --------- ------------------- -------- --------- ---------
Begin Snap:        37 10-Jun-26 10:00:07         1      11.0         1
  End Snap:        38 10-Jun-26 11:00:08         0        .0         2
   Elapsed:               60.00 (mins)
   DB Time:                0.89 (mins)

Load Profile                    Per Second   Per Transaction  Per Exec  Per Call
~~~~~~~~~~~~~~~            ---------------   --------------- --------- ---------
             DB Time(s):               0.0              26.7      0.03      0.33

OUTPUT
              DB CPU(s):               0.0               0.2      0.00      0.00
      Background CPU(s):               0.0               0.1      0.00      0.00
      Redo size (bytes):               2.4           4,272.0
  Logical read (blocks):               2.1           3,712.0
          Block changes:               0.0              32.0
 Physical read (blocks):               0.0              11.5
Physical write (blocks):               0.0               0.5
       Read IO requests:               0.0              10.0
      Write IO requests:               0.0               0.5
           Read IO (MB):               0.0               0.1
          Write IO (MB):               0.0               0.0
           IM scan rows:               0.0               0.0
Session Logical Read IM:               0.0               0.0
 RAC GC blocks received:               0.0               5.5

OUTPUT
   RAC GC blocks served:               0.0               1.0
             User calls:               0.1              81.5
           Parses (SQL):               0.1             257.5
      Hard parses (SQL):               0.1             152.5
     SQL Work Area (MB):               0.0              30.2
                 Logons:               0.0              13.0
            User logons:               0.0               0.0
         Executes (SQL):               0.6           1,062.5
              Rollbacks:               0.0               1.0
           Transactions:               0.0

Top 10 Foreground Events by Total Wait Time
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                           Total Wait       Avg   % DB Wait

OUTPUT
Event                                Waits Time (sec)      Wait   time Class
------------------------------ ----------- ---------- --------- ------ --------
enq: TX - row lock contention            1       52.9   52.86 s   98.9 Applicat
DB CPU                                             .4               .8
db file sequential read                 13          0    3.23ms     .1 User I/O
log file sync                            2          0   19.72ms     .1 Commit
control file sequential read            48          0  268.69us     .0 System I
PX Deq: Slave Session Stats             25          0  482.88us     .0 Other
IPC send completion sync                43          0  146.07us     .0 Other
enq: PS - contention                    15          0  355.73us     .0 Other
PX Deq: Join ACK                         2          0    1.28ms     .0 Other
library cache pin                        4          0  564.00us     .0 Concurre


Wait Classes by Total Wait Time

OUTPUT
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                                          Avg             Avg
                                        Total Wait       Wait   % DB   Active
Wait Class                  Waits       Time (sec)       Time   time Sessions
---------------- ---------------- ---------------- ---------- ------ --------
Application                    15               53  3524.27ms   98.9      0.0
DB CPU                                           0                .8      0.0
Other                       1,134                0   244.79us     .5      0.0
Cluster                       576                0   130.09us     .1      0.0
System I/O                    268                0   239.68us     .1      0.0
User I/O                      145                0   321.45us     .1      0.0
Commit                          2                0    19.72ms     .1      0.0
Concurrency                    36                0   628.11us     .0      0.0
Configuration                   1                0   345.00us     .0      0.0

OUTPUT
Network                        26                0     3.08us     .0      0.0

IO Profile                  Read+Write/Second     Read/Second    Write/Second
~~~~~~~~~~                  ----------------- --------------- ---------------
            Total Requests:               0.0             0.0             0.0
         Database Requests:               0.0             0.0             0.0
        Optimized Requests:               0.0             0.0             0.0
             Redo Requests:
                Total (MB):               0.0             0.0             0.0
             Database (MB):               0.0             0.0             0.0
      Optimized Total (MB):               0.0             0.0             0.0
                 Redo (MB):
         Database (blocks):               0.0             0.0             0.0
 Via Buffer Cache (blocks):               0.0             0.0             0.0

OUTPUT
           Direct (blocks):               0.0             0.0             0.0



Time Model Statistics                      DB/Inst: RACDB/racdb1  Snaps: 37-38
-> DB Time represents total time in user calls
-> DB CPU represents CPU time of foreground processes
-> Total CPU Time represents foreground and background processes
-> Statistics including the word "background" measure background process
   time, therefore do not contribute to the DB time statistic
-> Ordered by % of DB time in descending order, followed by Statistic Name

                                                                % of  % of Total
Statistic Name                                       Time (s) DB Time   CPU Time
------------------------------------------ ------------------ ------- ----------

OUTPUT
sql execute elapsed time                                 53.2    99.6
DB CPU                                                    0.4      .8       75.5
parse time elapsed                                        0.4      .7
hard parse elapsed time                                   0.3      .6
failed parse elapsed time                                 0.1      .2
hard parse (sharing criteria) elapsed time                0.1      .1
PL/SQL execution elapsed time                             0.0      .0
repeated bind elapsed time                                0.0      .0
connection management call elapsed time                   0.0      .0
DB time                                                  53.4
background elapsed time                                   0.2
background cpu time                                       0.1               24.5
total CPU time                                            0.6
                          ------------------------------------------------------

OUTPUT

Foreground Wait Class                      DB/Inst: RACDB/racdb1  Snaps: 37-38
-> s  - second, ms - millisecond, us - microsecond, ns - nanosecond
-> ordered by wait time desc, waits desc
-> %Timeouts: value of 0 indicates value was < .5%.  Value of null is truly 0
-> Captured Time accounts for        100.0%  of Total DB time          53.43 (s)
-> Total FG Wait Time:                52.99 (s)  DB CPU time:            .44 (s)

                                     %Time      Total Wait
Wait Class                     Waits -outs        Time (s)   Avg wait  %DB time
-------------------- --------------- ----- --------------- ---------- ---------
Application                        7     0              53  7551.59ms      98.9
DB CPU                                                   0                  0.8
User I/O                          16     0               0     2.66ms       0.1

OUTPUT
Commit                             2     0               0    19.72ms       0.1
Other                            278    54               0   101.77us       0.1
System I/O                        48     0               0   268.69us       0.0
Cluster                           14     0               0   378.29us       0.0
Concurrency                        4     0               0   564.00us       0.0
Network                           21     0               0     1.81us       0.0
Configuration                      0                     0                  0.0
                          ------------------------------------------------------



Foreground Wait Events                     DB/Inst: RACDB/racdb1  Snaps: 37-38
-> s  - second, ms - millisecond, us - microsecond, ns - nanosecond
-> Only events with Total Wait Time (s) >= .001 are shown
-> ordered by wait time desc, waits desc (idle events last)

OUTPUT
-> %Timeouts: value of 0 indicates value was < .5%.  Value of null is truly 0

                                                Total
                                       %Time     Wait              Waits   % DB
Event                            Waits -outs Time (s)  Avg wait     /txn   time
-------------------------- ----------- ----- -------- --------- -------- ------
enq: TX - row lock content           1             53   52.86 s      0.5   98.9
db file sequential read             13              0    3.23ms      6.5     .1
log file sync                        2              0   19.72ms      1.0     .1
control file sequential re          48              0  268.69us     24.0     .0
PX Deq: Slave Session Stat          25              0  482.88us     12.5     .0
IPC send completion sync            43              0  146.07us     21.5     .0
enq: PS - contention                15              0  355.73us      7.5     .0
PX Deq: Join ACK                     2              0    1.28ms      1.0     .0

OUTPUT
library cache pin                    4              0  564.00us      2.0     .0
gc current block busy                4              0  420.50us      2.0     .0
gc cr block 2-way                    3              0  534.00us      1.5     .0
gc cr grant 2-way                    4              0  329.00us      2.0     .0
SQL*Net message from clien          20          3,730  186.48 s     10.0
PX Deq: Execution Msg               69              0    2.39ms     34.5
PX Deq: Parse Reply                  2              0   46.81ms      1.0
PX Deq: Execute Reply                2              0    2.02ms      1.0
                          ------------------------------------------------------



Service Statistics                         DB/Inst: RACDB/racdb1  Snaps: 37-38
-> ordered by DB Time


OUTPUT
                                                           Physical      Logical
Service Name                  DB Time (s)   DB CPU (s)    Reads (K)    Reads (K)
---------------------------- ------------ ------------ ------------ ------------
pdb1                                   53            0            0            4
                          ------------------------------------------------------

Service Wait Class Stats                   DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Wait Class info for services in the Service Statistics section.
-> Total Waits and Time Waited displayed for the following wait
   classes:  User I/O, Concurrency, Administrative, Network
-> Time Waited (Wt Time) in seconds

Service Name
----------------------------------------------------------------

OUTPUT
 User I/O  User I/O  Concurcy  Concurcy     Admin     Admin   Network   Network
Total Wts   Wt Time Total Wts   Wt Time Total Wts   Wt Time Total Wts   Wt Time
--------- --------- --------- --------- --------- --------- --------- ---------
pdb1
       20         0         0         0         0         0        21         0
                          ------------------------------------------------------



Top Process Types by Wait Class            DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------




OUTPUT
Top Process Types by CPU Used              DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------



SQL ordered by Elapsed Time                DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Resources reported for PL/SQL code includes the resources used by all SQL
   statements called by the code.
-> % Total DB Time is the Elapsed Time of the SQL statement divided
   into the Total Database Time multiplied by 100
-> %Total - Elapsed Time  as a percentage of Total DB time
-> %CPU   - CPU Time      as a percentage of Elapsed Time
-> %IO    - User I/O Time as a percentage of Elapsed Time

OUTPUT
-> Captured SQL account for  100.3% of Total DB Time (s):              53
-> Captured PL/SQL account for    0.2% of Total DB Time (s):              53

        Elapsed                  Elapsed Time
        Time (s)    Executions  per Exec (s)  %Total   %CPU    %IO    SQL Id
---------------- -------------- ------------- ------ ------ ------ -------------
            52.9              1         52.86   98.9     .1     .0 aa7t6babr24zf
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
update orders_demo set total_amount = 888 where order_id = 10

             0.1             15          0.01     .2    3.3     .0 6hnhqahphpk8n
   PDB: PDB1
select free_mb from v$asm_diskgroup_stat where name=:1

OUTPUT

             0.1              2          0.05     .2   60.1   35.4 fxzttyhrt9ggu
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
update orders_demo set total_amount = 888 where order_id =10

             0.1              3          0.03     .2   80.3     .0 3kqrku32p6sfn
   PDB: PDB1
MERGE /*+ OPT_PARAM('_parallel_syspls_obey_force' 'false') */ INTO OPTSTAT_USER_
PREFS$ D USING ( SELECT * FROM (SELECT O.OBJ#, SYSTIMESTAMP CHGTIME, ROUND(MAX(S
.DELTA_READ_IO_BYTES/S.DELTA_TIME), 3) SCANRATE FROM GV$ACTIVE_SESSION_HISTORY S
, GV$SQL_PLAN P, OBJ$ O, USER$ U WHERE S.INST_ID = P.INST_ID AND S.SQL_ID = P.SQ

             0.1              3          0.02     .1   78.4     .0 5pj6mtazkhmdd

OUTPUT
   PDB: PDB1
BEGIN /* KSXM:FLUSH DML_MON */ dbms_stats_internal.gather_scan_rate_by_mmon;
 END;

             0.1              1          0.06     .1   28.1   63.1 7vrjq0uc1mudx
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
select sid, serial#, username, event, wait_class, seconds_in_wait, blocking_sess
ion, sql_id from gv$session where blocking_session >0 or event LIKE '%TX%'

             0.0              6          0.01     .1   72.8     .0 d8g9jhjnjn206
   PDB: PDB1
select tablespace_id, rfno, allocated_space, file_size, file_maxsize, changescn8
, flag, inst_id from sys.ts$, GV$FILESPACE_USAGE where ts# = tablespace_id and o

OUTPUT
nline$ != 3 and inst_id != :inst and (changescn8 > :s)

             0.0              1          0.05     .1   93.3     .0 gzwv5dn1f1h6m
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
select sid, serial#, username, event, wait_class, seconds_in_wait, blocking_sess
ion, sql_id from v$session where blocking_session >0 or event Like '%TX%'

             0.0              2          0.02     .1   92.8    1.1 a8xypykqc348c
   PDB: PDB1
BEGIN dbms_stats_internal.advisor_setup_obj_filter(:tid, :rid, 'EXECUTE', FAL
SE); END;

             0.0              1          0.04     .1   94.3    2.0 f705bwx3q0ydq

OUTPUT
   PDB: PDB1
select count(*) from dba_autotask_window_clients c, (select window_name, max(log
_date) max_log_date from dba_scheduler_window_log where operation = 'OPEN' group
 by window_name) wo, (select window_name, max(log_date) max_log_date from dba_sc
heduler_window_log where operation = 'CLOSE' group by window_name) wc where c.wi

                          ------------------------------------------------------



SQL ordered by CPU Time                    DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Resources reported for PL/SQL code includes the resources used by all SQL
   statements called by the code.
-> %Total - CPU Time      as a percentage of Total DB CPU
-> %CPU   - CPU Time      as a percentage of Elapsed Time

OUTPUT
-> %IO    - User I/O Time as a percentage of Elapsed Time
-> Captured SQL account for  118.7% of Total CPU Time (s):               0
-> Captured PL/SQL account for   22.5% of Total CPU Time (s):               0

    CPU                   CPU per           Elapsed
  Time (s)  Executions    Exec (s) %Total   Time (s)   %CPU    %IO    SQL Id
---------- ------------ ---------- ------ ---------- ------ ------ -------------
       0.1            3       0.02   16.5        0.1   80.3     .0 3kqrku32p6sfn
   PDB: PDB1
MERGE /*+ OPT_PARAM('_parallel_syspls_obey_force' 'false') */ INTO OPTSTAT_USER_
PREFS$ D USING ( SELECT * FROM (SELECT O.OBJ#, SYSTIMESTAMP CHGTIME, ROUND(MAX(S
.DELTA_READ_IO_BYTES/S.DELTA_TIME), 3) SCANRATE FROM GV$ACTIVE_SESSION_HISTORY S
, GV$SQL_PLAN P, OBJ$ O, USER$ U WHERE S.INST_ID = P.INST_ID AND S.SQL_ID = P.SQ


OUTPUT
       0.1            2       0.03   15.0        0.1   60.1   35.4 fxzttyhrt9ggu
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
update orders_demo set total_amount = 888 where order_id =10

       0.1            3       0.02   13.0        0.1   78.4     .0 5pj6mtazkhmdd
   PDB: PDB1
BEGIN /* KSXM:FLUSH DML_MON */ dbms_stats_internal.gather_scan_rate_by_mmon;
 END;

       0.1            1       0.05   11.5       52.9     .1     .0 aa7t6babr24zf
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
update orders_demo set total_amount = 888 where order_id = 10

OUTPUT

       0.0            1       0.04   10.1        0.0   93.3     .0 gzwv5dn1f1h6m
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
select sid, serial#, username, event, wait_class, seconds_in_wait, blocking_sess
ion, sql_id from v$session where blocking_session >0 or event Like '%TX%'

       0.0            2       0.02    9.5        0.0   92.8    1.1 a8xypykqc348c
   PDB: PDB1
BEGIN dbms_stats_internal.advisor_setup_obj_filter(:tid, :rid, 'EXECUTE', FAL
SE); END;

       0.0            1       0.04    9.0        0.0   94.3    2.0 f705bwx3q0ydq
   PDB: PDB1

OUTPUT
select count(*) from dba_autotask_window_clients c, (select window_name, max(log
_date) max_log_date from dba_scheduler_window_log where operation = 'OPEN' group
 by window_name) wo, (select window_name, max(log_date) max_log_date from dba_sc
heduler_window_log where operation = 'CLOSE' group by window_name) wc where c.wi

       0.0           75       0.00    8.0        0.0   89.9     .0 121ffmrc95v7g
   PDB: PDB1
select i.obj#,i.ts#,i.file#,i.block#,i.intcols,i.type#,i.flags,i.property,i.pctf
ree$,i.initrans,i.maxtrans,i.blevel,i.leafcnt,i.distkey,i.lblkkey,i.dblkkey,i.cl
ufac,i.cols,i.analyzetime,i.samplesize,i.dataobj#,nvl(i.degree,1),nvl(i.instance
s,1),i.rowcnt,mod(i.pctthres$,256),i.indmethod#,i.trunccnt,nvl(c.unicols,0),nvl(

       0.0            6       0.01    7.9        0.0   72.8     .0 d8g9jhjnjn206
   PDB: PDB1

OUTPUT
select tablespace_id, rfno, allocated_space, file_size, file_maxsize, changescn8
, flag, inst_id from sys.ts$, GV$FILESPACE_USAGE where ts# = tablespace_id and o
nline$ != 3 and inst_id != :inst and (changescn8 > :s)

       0.0            1       0.03    7.7        0.0   93.7    2.9 9sg6u8xys290z
   PDB: PDB1
select count(*) num_enabled, sum(case optimizer_stats when 'ENABLED' then 1 else
 0 end) stats_enabled from dba_autotask_window_clients where autotask_status = '
ENABLED'

       0.0          277       0.00    4.8        0.0   69.5    3.5 f3ww8rgva3hrs


SQL ordered by CPU Time                    DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Resources reported for PL/SQL code includes the resources used by all SQL

OUTPUT
   statements called by the code.
-> %Total - CPU Time      as a percentage of Total DB CPU
-> %CPU   - CPU Time      as a percentage of Elapsed Time
-> %IO    - User I/O Time as a percentage of Elapsed Time
-> Captured SQL account for  118.7% of Total CPU Time (s):               0
-> Captured PL/SQL account for   22.5% of Total CPU Time (s):               0

    CPU                   CPU per           Elapsed
  Time (s)  Executions    Exec (s) %Total   Time (s)   %CPU    %IO    SQL Id
---------- ------------ ---------- ------ ---------- ------ ------ -------------
   PDB: PDB1
update /* KSXM:FLUSH COL */ sys.col_usage$ set equality_preds
 = equality_preds + decode(bitand(:flag,1),0,0,1), equijoin_preds = equ
ijoin_preds + decode(bitand(:flag,2),0,0,1), nonequijoin_preds = nonequijoi

OUTPUT
n_preds + decode(bitand(:flag,4),0,0,1), range_preds = range_preds

       0.0            1       0.02    4.1        0.1   28.1   63.1 7vrjq0uc1mudx
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
select sid, serial#, username, event, wait_class, seconds_in_wait, blocking_sess
ion, sql_id from gv$session where blocking_session >0 or event LIKE '%TX%'

       0.0          289       0.00    4.0        0.0   89.1     .0 acmvv4fhdc9zh
   PDB: PDB1
select obj#,type#,ctime,mtime,stime, status, dataobj#, flags, oid$, spare1, spar
e2, spare3, signature, spare7, spare8, spare9, nvl(dflcollid, 16382), creappid,
creverid, modappid, modverid, crepatchid, modpatchid from obj$ where owner#=:1 a
nd name=:2 and namespace=:3 and remoteowner is null and linkname is null and sub

OUTPUT

       0.0            0        N/A    3.7        0.0   92.4     .0 1bk6w14asu6wh
   PDB: PDB1
select SADDR , SID , SERIAL# , AUDSID , PADDR , USER# , USERNAME , COMMAND , OW
NERID, TADDR , LOCKWAIT , STATUS , SERVER , SCHEMA# , SCHEMANAME ,OSUSER , PROCE
SS , MACHINE , PORT , TERMINAL , PROGRAM , TYPE , SQL_ADDRESS , SQL_HASH_VALUE,
 SQL_ID, SQL_CHILD_NUMBER , SQL_EXEC_START, SQL_EXEC_ID, PREV_SQL_ADDR , PREV_HA

       0.0           92       0.00    3.6        0.0  100.9    2.0 g0t052az3rx44
   PDB: PDB1
select name,intcol#,segcol#,type#,length,nvl(precision#,0),decode(type#,2,nvl(sc
ale,-127/*MAXSB1MINAL*/),178,scale,179,scale,180,scale,181,scale,182,scale,183,s
cale,231,scale,0),null$,fixedstorage,nvl(deflength,0),default$,rowid,col#,proper
ty, nvl(charsetid,0),nvl(charsetform,0),spare1,spare2,nvl(spare3,0), nvl(evaledi

OUTPUT

       0.0           44       0.00    3.2        0.0   90.7    4.9 3un99a0zwp4vd
   PDB: PDB1
select owner#,name,namespace,remoteowner,linkname,p_timestamp,p_obj#, nvl(proper
ty,0),subname,type#,flags,d_attrs from dependency$ d, obj$ o where d_obj#=:1 and
 p_obj#=obj#(+) order by order#

       0.0           14       0.00    2.4        0.0   93.4     .0 gngtvs38t0060
Module: oraagent.bin@rac1 (TNS V1-V3)
   PDB: PDB1
SELECT /*+ CONNECT_BY_FILTERING */ s.privilege# FROM sys.sysauth$ s CONNE
CT BY s.grantee# = PRIOR s.privilege# AND (s.pri
vilege# > 0 OR s.privilege# = -352) START WITH (s.p
rivilege# > 0 OR s.privilege# = -352) AND s.grantee# IN (SELECT c1.privilege

OUTPUT

       0.0           87       0.00    1.5        0.0  103.4     .0 5u7g54s63p4ts
   PDB: PDB1
select toid from type$ where package_obj#=:1 and typ_name=:2

       0.0           15       0.00    1.4        0.0   99.7     .0 6qz82dptj0qr7
   PDB: PDB1
select l.col#, l.intcol#, l.lobj#, l.ind#, l.ts#, l.file#, l.block#, l.chunk, l.
pctversion$, l.flags, l.property, l.retention, l.freepools from lob$ l where l.o
bj# = :1 order by l.intcol# asc

       0.0           10       0.00    1.0        0.0   78.2     .0 50vxqdkj4zu1w
   PDB: PDB1
select user#,password,datats#,tempts#,type#,defrole,resource$,ptime,decode(defsc

OUTPUT


SQL ordered by CPU Time                    DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Resources reported for PL/SQL code includes the resources used by all SQL
   statements called by the code.
-> %Total - CPU Time      as a percentage of Total DB CPU
-> %CPU   - CPU Time      as a percentage of Elapsed Time
-> %IO    - User I/O Time as a percentage of Elapsed Time
-> Captured SQL account for  118.7% of Total CPU Time (s):               0
-> Captured PL/SQL account for   22.5% of Total CPU Time (s):               0

    CPU                   CPU per           Elapsed
  Time (s)  Executions    Exec (s) %Total   Time (s)   %CPU    %IO    SQL Id
---------- ------------ ---------- ------ ---------- ------ ------ -------------
hclass,NULL,'DEFAULT_CONSUMER_GROUP',defschclass),spare1,spare4,ext_username,spa

OUTPUT
re2,nvl(spare3,16382),spare9,spare10 from user$ where name=:1

                          ------------------------------------------------------



SQL ordered by User I/O Wait Time          DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Resources reported for PL/SQL code includes the resources used by all SQL
   statements called by the code.
-> %Total - User I/O Time as a percentage of Total User I/O Wait time
-> %CPU   - CPU Time      as a percentage of Elapsed Time
-> %IO    - User I/O Time as a percentage of Elapsed Time
-> Captured SQL account for  178.8% of Total User I/O Wait Time (s):
-> Captured PL/SQL account for    1.1% of Total User I/O Wait Time (s):


OUTPUT
  User I/O                UIO per           Elapsed
  Time (s)  Executions    Exec (s) %Total   Time (s)   %CPU    %IO    SQL Id
---------- ------------ ---------- ------ ---------- ------ ------ -------------
       0.0            1       0.04   86.9        0.1   28.1   63.1 7vrjq0uc1mudx
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
select sid, serial#, username, event, wait_class, seconds_in_wait, blocking_sess
ion, sql_id from gv$session where blocking_session >0 or event LIKE '%TX%'

       0.0            2       0.02   83.4        0.1   60.1   35.4 fxzttyhrt9ggu
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
update orders_demo set total_amount = 888 where order_id =10


OUTPUT
       0.0          277       0.00    2.3        0.0   69.5    3.5 f3ww8rgva3hrs
   PDB: PDB1
update /* KSXM:FLUSH COL */ sys.col_usage$ set equality_preds
 = equality_preds + decode(bitand(:flag,1),0,0,1), equijoin_preds = equ
ijoin_preds + decode(bitand(:flag,2),0,0,1), nonequijoin_preds = nonequijoi
n_preds + decode(bitand(:flag,4),0,0,1), range_preds = range_preds

       0.0            1       0.00    2.2        0.0   93.7    2.9 9sg6u8xys290z
   PDB: PDB1
select count(*) num_enabled, sum(case optimizer_stats when 'ENABLED' then 1 else
 0 end) stats_enabled from dba_autotask_window_clients where autotask_status = '
ENABLED'

       0.0            1       0.00    1.7        0.0   94.3    2.0 f705bwx3q0ydq

OUTPUT
   PDB: PDB1
select count(*) from dba_autotask_window_clients c, (select window_name, max(log
_date) max_log_date from dba_scheduler_window_log where operation = 'OPEN' group
 by window_name) wo, (select window_name, max(log_date) max_log_date from dba_sc
heduler_window_log where operation = 'CLOSE' group by window_name) wc where c.wi

       0.0           44       0.00    1.6        0.0   90.7    4.9 3un99a0zwp4vd
   PDB: PDB1
select owner#,name,namespace,remoteowner,linkname,p_timestamp,p_obj#, nvl(proper
ty,0),subname,type#,flags,d_attrs from dependency$ d, obj$ o where d_obj#=:1 and
 p_obj#=obj#(+) order by order#

       0.0            2       0.00    1.1        0.0   92.8    1.1 a8xypykqc348c
   PDB: PDB1

OUTPUT
BEGIN dbms_stats_internal.advisor_setup_obj_filter(:tid, :rid, 'EXECUTE', FAL
SE); END;

       0.0           92       0.00    0.7        0.0  100.9    2.0 g0t052az3rx44
   PDB: PDB1
select name,intcol#,segcol#,type#,length,nvl(precision#,0),decode(type#,2,nvl(sc
ale,-127/*MAXSB1MINAL*/),178,scale,179,scale,180,scale,181,scale,182,scale,183,s
cale,231,scale,0),null$,fixedstorage,nvl(deflength,0),default$,rowid,col#,proper
ty, nvl(charsetid,0),nvl(charsetform,0),spare1,spare2,nvl(spare3,0), nvl(evaledi

       0.0           75       0.00    0.0        0.0   89.9     .0 121ffmrc95v7g
   PDB: PDB1
select i.obj#,i.ts#,i.file#,i.block#,i.intcols,i.type#,i.flags,i.property,i.pctf
ree$,i.initrans,i.maxtrans,i.blevel,i.leafcnt,i.distkey,i.lblkkey,i.dblkkey,i.cl

OUTPUT
ufac,i.cols,i.analyzetime,i.samplesize,i.dataobj#,nvl(i.degree,1),nvl(i.instance
s,1),i.rowcnt,mod(i.pctthres$,256),i.indmethod#,i.trunccnt,nvl(c.unicols,0),nvl(

       0.0            0        N/A    0.0        0.0   92.4     .0 1bk6w14asu6wh
   PDB: PDB1
select SADDR , SID , SERIAL# , AUDSID , PADDR , USER# , USERNAME , COMMAND , OW
NERID, TADDR , LOCKWAIT , STATUS , SERVER , SCHEMA# , SCHEMANAME ,OSUSER , PROCE


SQL ordered by User I/O Wait Time          DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Resources reported for PL/SQL code includes the resources used by all SQL
   statements called by the code.
-> %Total - User I/O Time as a percentage of Total User I/O Wait time
-> %CPU   - CPU Time      as a percentage of Elapsed Time
-> %IO    - User I/O Time as a percentage of Elapsed Time

OUTPUT
-> Captured SQL account for  178.8% of Total User I/O Wait Time (s):
-> Captured PL/SQL account for    1.1% of Total User I/O Wait Time (s):

  User I/O                UIO per           Elapsed
  Time (s)  Executions    Exec (s) %Total   Time (s)   %CPU    %IO    SQL Id
---------- ------------ ---------- ------ ---------- ------ ------ -------------
SS , MACHINE , PORT , TERMINAL , PROGRAM , TYPE , SQL_ADDRESS , SQL_HASH_VALUE,
 SQL_ID, SQL_CHILD_NUMBER , SQL_EXEC_START, SQL_EXEC_ID, PREV_SQL_ADDR , PREV_HA

                          ------------------------------------------------------



SQL ordered by Gets                        DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Resources reported for PL/SQL code includes the resources used by all SQL

OUTPUT
   statements called by the code.
-> %Total - Buffer Gets   as a percentage of Total Buffer Gets
-> %CPU   - CPU Time      as a percentage of Elapsed Time
-> %IO    - User I/O Time as a percentage of Elapsed Time
-> Total Buffer Gets:           7,424
-> Captured SQL account for  194.3% of Total

     Buffer                 Gets              Elapsed
      Gets   Executions   per Exec   %Total   Time (s)  %CPU   %IO    SQL Id
----------- ----------- ------------ ------ ---------- ----- ----- -------------
      3,542           2      1,771.0   47.7        0.0  92.8   1.1 a8xypykqc348c
   PDB: PDB1
BEGIN dbms_stats_internal.advisor_setup_obj_filter(:tid, :rid, 'EXECUTE', FAL
SE); END;

OUTPUT

      1,847           2        923.5   24.9        0.1  60.1  35.4 fxzttyhrt9ggu
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
update orders_demo set total_amount = 888 where order_id =10

      1,563           6        260.5   21.1        0.0  72.8     0 d8g9jhjnjn206
   PDB: PDB1
select tablespace_id, rfno, allocated_space, file_size, file_maxsize, changescn8
, flag, inst_id from sys.ts$, GV$FILESPACE_USAGE where ts# = tablespace_id and o
nline$ != 3 and inst_id != :inst and (changescn8 > :s)

      1,501         289          5.2   20.2        0.0  89.1     0 acmvv4fhdc9zh
   PDB: PDB1

OUTPUT
select obj#,type#,ctime,mtime,stime, status, dataobj#, flags, oid$, spare1, spar
e2, spare3, signature, spare7, spare8, spare9, nvl(dflcollid, 16382), creappid,
creverid, modappid, modverid, crepatchid, modpatchid from obj$ where owner#=:1 a
nd name=:2 and namespace=:3 and remoteowner is null and linkname is null and sub

      1,453           1      1,453.0   19.6        0.0  94.3     2 f705bwx3q0ydq
   PDB: PDB1
select count(*) from dba_autotask_window_clients c, (select window_name, max(log
_date) max_log_date from dba_scheduler_window_log where operation = 'OPEN' group
 by window_name) wo, (select window_name, max(log_date) max_log_date from dba_sc
heduler_window_log where operation = 'CLOSE' group by window_name) wc where c.wi

      1,133         277          4.1   15.3        0.0  69.5   3.5 f3ww8rgva3hrs
   PDB: PDB1

OUTPUT
update /* KSXM:FLUSH COL */ sys.col_usage$ set equality_preds
 = equality_preds + decode(bitand(:flag,1),0,0,1), equijoin_preds = equ
ijoin_preds + decode(bitand(:flag,2),0,0,1), nonequijoin_preds = nonequijoi
n_preds + decode(bitand(:flag,4),0,0,1), range_preds = range_preds

      1,091           3        363.7   14.7        0.1  78.4     0 5pj6mtazkhmdd
   PDB: PDB1
BEGIN /* KSXM:FLUSH DML_MON */ dbms_stats_internal.gather_scan_rate_by_mmon;
 END;

      1,071           3        357.0   14.4        0.1  80.3     0 3kqrku32p6sfn
   PDB: PDB1
MERGE /*+ OPT_PARAM('_parallel_syspls_obey_force' 'false') */ INTO OPTSTAT_USER_
PREFS$ D USING ( SELECT * FROM (SELECT O.OBJ#, SYSTIMESTAMP CHGTIME, ROUND(MAX(S

OUTPUT
.DELTA_READ_IO_BYTES/S.DELTA_TIME), 3) SCANRATE FROM GV$ACTIVE_SESSION_HISTORY S
, GV$SQL_PLAN P, OBJ$ O, USER$ U WHERE S.INST_ID = P.INST_ID AND S.SQL_ID = P.SQ

        948          44         21.5   12.8        0.0  90.7   4.9 3un99a0zwp4vd
   PDB: PDB1
select owner#,name,namespace,remoteowner,linkname,p_timestamp,p_obj#, nvl(proper
ty,0),subname,type#,flags,d_attrs from dependency$ d, obj$ o where d_obj#=:1 and
 p_obj#=obj#(+) order by order#

        930           1        930.0   12.5        0.0  93.7   2.9 9sg6u8xys290z
   PDB: PDB1
select count(*) num_enabled, sum(case optimizer_stats when 'ENABLED' then 1 else
 0 end) stats_enabled from dba_autotask_window_clients where autotask_status = '
ENABLED'

OUTPUT


SQL ordered by Gets                        DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Resources reported for PL/SQL code includes the resources used by all SQL
   statements called by the code.
-> %Total - Buffer Gets   as a percentage of Total Buffer Gets
-> %CPU   - CPU Time      as a percentage of Elapsed Time
-> %IO    - User I/O Time as a percentage of Elapsed Time
-> Total Buffer Gets:           7,424
-> Captured SQL account for  194.3% of Total

     Buffer                 Gets              Elapsed
      Gets   Executions   per Exec   %Total   Time (s)  %CPU   %IO    SQL Id
----------- ----------- ------------ ------ ---------- ----- ----- -------------


OUTPUT
        886          75         11.8   11.9        0.0  89.9     0 121ffmrc95v7g
   PDB: PDB1
select i.obj#,i.ts#,i.file#,i.block#,i.intcols,i.type#,i.flags,i.property,i.pctf
ree$,i.initrans,i.maxtrans,i.blevel,i.leafcnt,i.distkey,i.lblkkey,i.dblkkey,i.cl
ufac,i.cols,i.analyzetime,i.samplesize,i.dataobj#,nvl(i.degree,1),nvl(i.instance
s,1),i.rowcnt,mod(i.pctthres$,256),i.indmethod#,i.trunccnt,nvl(c.unicols,0),nvl(

        832           1        832.0   11.2        0.0  93.3     0 gzwv5dn1f1h6m
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
select sid, serial#, username, event, wait_class, seconds_in_wait, blocking_sess
ion, sql_id from v$session where blocking_session >0 or event Like '%TX%'

        552          92          6.0    7.4        0.0 100.9     2 g0t052az3rx44

OUTPUT
   PDB: PDB1
select name,intcol#,segcol#,type#,length,nvl(precision#,0),decode(type#,2,nvl(sc
ale,-127/*MAXSB1MINAL*/),178,scale,179,scale,180,scale,181,scale,182,scale,183,s
cale,231,scale,0),null$,fixedstorage,nvl(deflength,0),default$,rowid,col#,proper
ty, nvl(charsetid,0),nvl(charsetform,0),spare1,spare2,nvl(spare3,0), nvl(evaledi

        468          87          5.4    6.3        0.0 103.4     0 5u7g54s63p4ts
   PDB: PDB1
select toid from type$ where package_obj#=:1 and typ_name=:2

        433           0          N/A    5.8        0.0  92.4     0 1bk6w14asu6wh
   PDB: PDB1
select SADDR , SID , SERIAL# , AUDSID , PADDR , USER# , USERNAME , COMMAND , OW
NERID, TADDR , LOCKWAIT , STATUS , SERVER , SCHEMA# , SCHEMANAME ,OSUSER , PROCE

OUTPUT
SS , MACHINE , PORT , TERMINAL , PROGRAM , TYPE , SQL_ADDRESS , SQL_HASH_VALUE,
 SQL_ID, SQL_CHILD_NUMBER , SQL_EXEC_START, SQL_EXEC_ID, PREV_SQL_ADDR , PREV_HA

        264          15         17.6    3.6        0.0  99.7     0 6qz82dptj0qr7
   PDB: PDB1
select l.col#, l.intcol#, l.lobj#, l.ind#, l.ts#, l.file#, l.block#, l.chunk, l.
pctversion$, l.flags, l.property, l.retention, l.freepools from lob$ l where l.o
bj# = :1 order by l.intcol# asc

        120           1        120.0    1.6        0.1  28.1  63.1 7vrjq0uc1mudx
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
select sid, serial#, username, event, wait_class, seconds_in_wait, blocking_sess
ion, sql_id from gv$session where blocking_session >0 or event LIKE '%TX%'

OUTPUT

        119          14          8.5    1.6        0.0  93.4     0 gngtvs38t0060
Module: oraagent.bin@rac1 (TNS V1-V3)
   PDB: PDB1
SELECT /*+ CONNECT_BY_FILTERING */ s.privilege# FROM sys.sysauth$ s CONNE
CT BY s.grantee# = PRIOR s.privilege# AND (s.pri
vilege# > 0 OR s.privilege# = -352) START WITH (s.p
rivilege# > 0 OR s.privilege# = -352) AND s.grantee# IN (SELECT c1.privilege

        118         118          1.0    1.6        0.0  66.8     0 gjaap3w3qbf8c
   PDB: PDB1
select count(*) from ilmobj$ where rownum = 1

         90          19          4.7    1.2        0.0  77.1     0 afx304d90ps3z

OUTPUT
   PDB: PDB1
select rowcnt, blkcnt, empcnt, avgspc, chncnt, avgrln, analyzetime, samplesize,
avgspc_flb, flbcnt, flags from tab_stats$ where obj#=:1


SQL ordered by Gets                        DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Resources reported for PL/SQL code includes the resources used by all SQL
   statements called by the code.
-> %Total - Buffer Gets   as a percentage of Total Buffer Gets
-> %CPU   - CPU Time      as a percentage of Elapsed Time
-> %IO    - User I/O Time as a percentage of Elapsed Time
-> Total Buffer Gets:           7,424
-> Captured SQL account for  194.3% of Total

     Buffer                 Gets              Elapsed

OUTPUT
      Gets   Executions   per Exec   %Total   Time (s)  %CPU   %IO    SQL Id
----------- ----------- ------------ ------ ---------- ----- ----- -------------

                          ------------------------------------------------------



SQL ordered by Reads                       DB/Inst: RACDB/racdb1  Snaps: 37-38
-> %Total - Physical Reads as a percentage of Total Disk Reads
-> %CPU   - CPU Time      as a percentage of Elapsed Time
-> %IO    - User I/O Time as a percentage of Elapsed Time
-> Total Disk Reads:              23
-> Captured SQL account for  113.0% of Total

   Physical              Reads              Elapsed

OUTPUT
      Reads  Executions per Exec   %Total   Time (s)   %CPU    %IO    SQL Id
----------- ----------- ---------- ------ ---------- ------ ------ -------------
         10           1       10.0   43.5        0.1   28.1   63.1 7vrjq0uc1mudx
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
select sid, serial#, username, event, wait_class, seconds_in_wait, blocking_sess
ion, sql_id from gv$session where blocking_session >0 or event LIKE '%TX%'

          8           2        4.0   34.8        0.1   60.1   35.4 fxzttyhrt9ggu
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
update orders_demo set total_amount = 888 where order_id =10

          3         277        0.0   13.0        0.0   69.5    3.5 f3ww8rgva3hrs

OUTPUT
   PDB: PDB1
update /* KSXM:FLUSH COL */ sys.col_usage$ set equality_preds
 = equality_preds + decode(bitand(:flag,1),0,0,1), equijoin_preds = equ
ijoin_preds + decode(bitand(:flag,2),0,0,1), nonequijoin_preds = nonequijoi
n_preds + decode(bitand(:flag,4),0,0,1), range_preds = range_preds

          2          44        0.0    8.7        0.0   90.7    4.9 3un99a0zwp4vd
   PDB: PDB1
select owner#,name,namespace,remoteowner,linkname,p_timestamp,p_obj#, nvl(proper
ty,0),subname,type#,flags,d_attrs from dependency$ d, obj$ o where d_obj#=:1 and
 p_obj#=obj#(+) order by order#

          1           1        1.0    4.3        0.0   93.7    2.9 9sg6u8xys290z
   PDB: PDB1

OUTPUT
select count(*) num_enabled, sum(case optimizer_stats when 'ENABLED' then 1 else
 0 end) stats_enabled from dba_autotask_window_clients where autotask_status = '
ENABLED'

          1           2        0.5    4.3        0.0   92.8    1.1 a8xypykqc348c
   PDB: PDB1
BEGIN dbms_stats_internal.advisor_setup_obj_filter(:tid, :rid, 'EXECUTE', FAL
SE); END;

          1           1        1.0    4.3        0.0   94.3    2.0 f705bwx3q0ydq
   PDB: PDB1
select count(*) from dba_autotask_window_clients c, (select window_name, max(log
_date) max_log_date from dba_scheduler_window_log where operation = 'OPEN' group
 by window_name) wo, (select window_name, max(log_date) max_log_date from dba_sc

OUTPUT
heduler_window_log where operation = 'CLOSE' group by window_name) wc where c.wi

          1          92        0.0    4.3        0.0  100.9    2.0 g0t052az3rx44
   PDB: PDB1
select name,intcol#,segcol#,type#,length,nvl(precision#,0),decode(type#,2,nvl(sc
ale,-127/*MAXSB1MINAL*/),178,scale,179,scale,180,scale,181,scale,182,scale,183,s
cale,231,scale,0),null$,fixedstorage,nvl(deflength,0),default$,rowid,col#,proper
ty, nvl(charsetid,0),nvl(charsetform,0),spare1,spare2,nvl(spare3,0), nvl(evaledi

          0          75        0.0    0.0        0.0   89.9     .0 121ffmrc95v7g
   PDB: PDB1
select i.obj#,i.ts#,i.file#,i.block#,i.intcols,i.type#,i.flags,i.property,i.pctf
ree$,i.initrans,i.maxtrans,i.blevel,i.leafcnt,i.distkey,i.lblkkey,i.dblkkey,i.cl
ufac,i.cols,i.analyzetime,i.samplesize,i.dataobj#,nvl(i.degree,1),nvl(i.instance

OUTPUT
s,1),i.rowcnt,mod(i.pctthres$,256),i.indmethod#,i.trunccnt,nvl(c.unicols,0),nvl(

          0           0        N/A    0.0        0.0   92.4     .0 1bk6w14asu6wh
   PDB: PDB1
select SADDR , SID , SERIAL# , AUDSID , PADDR , USER# , USERNAME , COMMAND , OW
NERID, TADDR , LOCKWAIT , STATUS , SERVER , SCHEMA# , SCHEMANAME ,OSUSER , PROCE


SQL ordered by Reads                       DB/Inst: RACDB/racdb1  Snaps: 37-38
-> %Total - Physical Reads as a percentage of Total Disk Reads
-> %CPU   - CPU Time      as a percentage of Elapsed Time
-> %IO    - User I/O Time as a percentage of Elapsed Time
-> Total Disk Reads:              23
-> Captured SQL account for  113.0% of Total


OUTPUT
   Physical              Reads              Elapsed
      Reads  Executions per Exec   %Total   Time (s)   %CPU    %IO    SQL Id
----------- ----------- ---------- ------ ---------- ------ ------ -------------
SS , MACHINE , PORT , TERMINAL , PROGRAM , TYPE , SQL_ADDRESS , SQL_HASH_VALUE,
 SQL_ID, SQL_CHILD_NUMBER , SQL_EXEC_START, SQL_EXEC_ID, PREV_SQL_ADDR , PREV_HA

                          ------------------------------------------------------



SQL ordered by Physical Reads (UnOptimized)DB/Inst: RACDB/racdb1  Snaps: 37-38
-> UnOptimized Read Reqs = Physical Read Reqs -
     (Optimized Read Reqs - Cell Flash Cache Read Hits for Controlfile)
-> %Opt   - Optimized Reads as percentage of SQL Read Requests
-> %Total - UnOptimized Read Reqs as a percentage of Total UnOptimized Read Reqs

OUTPUT
-> Total Physical Read Requests:              20
-> Captured SQL account for  100.0% of Total
-> Total UnOptimized Read Requests:              20
-> Captured SQL account for  100.0% of Total
-> Total Optimized Read Requests:               1
-> Captured SQL account for    0.0% of Total

UnOptimized   Physical              UnOptimized
  Read Reqs   Read Reqs Executions Reqs per Exe   %Opt %Total    SQL Id
----------- ----------- ---------- ------------ ------ ------ -------------
         10          10          1         10.0    0.0   50.0 7vrjq0uc1mudx
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
select sid, serial#, username, event, wait_class, seconds_in_wait, blocking_sess

OUTPUT
ion, sql_id from gv$session where blocking_session >0 or event LIKE '%TX%'

          5           5          2          2.5    0.0   25.0 fxzttyhrt9ggu
Module: java@rac1 (TNS V1-V3)
   PDB: PDB1
update orders_demo set total_amount = 888 where order_id =10

          3           3        277          0.0    0.0   15.0 f3ww8rgva3hrs
   PDB: PDB1
update /* KSXM:FLUSH COL */ sys.col_usage$ set equality_preds
 = equality_preds + decode(bitand(:flag,1),0,0,1), equijoin_preds = equ
ijoin_preds + decode(bitand(:flag,2),0,0,1), nonequijoin_preds = nonequijoi
n_preds + decode(bitand(:flag,4),0,0,1), range_preds = range_preds


OUTPUT
          1           1          1          1.0    0.0    5.0 9sg6u8xys290z
   PDB: PDB1
select count(*) num_enabled, sum(case optimizer_stats when 'ENABLED' then 1 else
 0 end) stats_enabled from dba_autotask_window_clients where autotask_status = '
ENABLED'

          1           1          2          0.5    0.0    5.0 a8xypykqc348c
   PDB: PDB1
BEGIN dbms_stats_internal.advisor_setup_obj_filter(:tid, :rid, 'EXECUTE', FAL
SE); END;

          1           1          1          1.0    0.0    5.0 f705bwx3q0ydq
   PDB: PDB1
select count(*) from dba_autotask_window_clients c, (select window_name, max(log

OUTPUT
_date) max_log_date from dba_scheduler_window_log where operation = 'OPEN' group
 by window_name) wo, (select window_name, max(log_date) max_log_date from dba_sc
heduler_window_log where operation = 'CLOSE' group by window_name) wc where c.wi

          0           0         75          0.0    N/A    0.0 121ffmrc95v7g
   PDB: PDB1
select i.obj#,i.ts#,i.file#,i.block#,i.intcols,i.type#,i.flags,i.property,i.pctf
ree$,i.initrans,i.maxtrans,i.blevel,i.leafcnt,i.distkey,i.lblkkey,i.dblkkey,i.cl
ufac,i.cols,i.analyzetime,i.samplesize,i.dataobj#,nvl(i.degree,1),nvl(i.instance
s,1),i.rowcnt,mod(i.pctthres$,256),i.indmethod#,i.trunccnt,nvl(c.unicols,0),nvl(

          0           0          0          N/A    N/A    0.0 1bk6w14asu6wh
   PDB: PDB1
select SADDR , SID , SERIAL# , AUDSID , PADDR , USER# , USERNAME , COMMAND , OW

OUTPUT
NERID, TADDR , LOCKWAIT , STATUS , SERVER , SCHEMA# , SCHEMANAME ,OSUSER , PROCE
SS , MACHINE , PORT , TERMINAL , PROGRAM , TYPE , SQL_ADDRESS , SQL_HASH_VALUE,
 SQL_ID, SQL_CHILD_NUMBER , SQL_EXEC_START, SQL_EXEC_ID, PREV_SQL_ADDR , PREV_HA

          0           0          3          0.0    N/A    0.0 3kqrku32p6sfn
   PDB: PDB1
MERGE /*+ OPT_PARAM('_parallel_syspls_obey_force' 'false') */ INTO OPTSTAT_USER_
PREFS$ D USING ( SELECT * FROM (SELECT O.OBJ#, SYSTIMESTAMP CHGTIME, ROUND(MAX(S
.DELTA_READ_IO_BYTES/S.DELTA_TIME), 3) SCANRATE FROM GV$ACTIVE_SESSION_HISTORY S
, GV$SQL_PLAN P, OBJ$ O, USER$ U WHERE S.INST_ID = P.INST_ID AND S.SQL_ID = P.SQ

          0           0          2          0.0    N/A    0.0 3ms7w0c6ph91t
   PDB: PDB1
insert /* KSXM:FLUSH COL */ into sys.col_usage$ (obj#, intcol#, equality_preds,

OUTPUT


SQL ordered by Physical Reads (UnOptimized)DB/Inst: RACDB/racdb1  Snaps: 37-38
-> UnOptimized Read Reqs = Physical Read Reqs -
     (Optimized Read Reqs - Cell Flash Cache Read Hits for Controlfile)
-> %Opt   - Optimized Reads as percentage of SQL Read Requests
-> %Total - UnOptimized Read Reqs as a percentage of Total UnOptimized Read Reqs
-> Total Physical Read Requests:              20
-> Captured SQL account for  100.0% of Total
-> Total UnOptimized Read Requests:              20
-> Captured SQL account for  100.0% of Total
-> Total Optimized Read Requests:               1
-> Captured SQL account for    0.0% of Total

UnOptimized   Physical              UnOptimized

OUTPUT
  Read Reqs   Read Reqs Executions Reqs per Exe   %Opt %Total    SQL Id
----------- ----------- ---------- ------------ ------ ------ -------------
equijoin_preds, nonequijoin_preds, range_preds, like_preds, null_preds, flags, t
imestamp) values ( :objn, :coln, decode(bitand(:flag,1),0,0,1), decode(bit
and(:flag,2),0,0,1), decode(bitand(:flag,4),0,0,1), decode(bitand(:flag,8),0

                          ------------------------------------------------------



SQL ordered by Executions                  DB/Inst: RACDB/racdb1  Snaps: 37-38
-> %CPU   - CPU Time      as a percentage of Elapsed Time
-> %IO    - User I/O Time as a percentage of Elapsed Time
-> Total Executions:           2,125
-> Captured SQL account for   53.3% of Total

OUTPUT

                                              Elapsed
 Executions   Rows Processed  Rows per Exec   Time (s)  %CPU   %IO    SQL Id
------------ --------------- -------------- ---------- ----- ----- -------------
         289             277            1.0        0.0  89.1     0 acmvv4fhdc9zh
   PDB: PDB1
select obj#,type#,ctime,mtime,stime, status, dataobj#, flags, oid$, spare1, spar
e2, spare3, signature, spare7, spare8, spare9, nvl(dflcollid, 16382), creappid,
creverid, modappid, modverid, crepatchid, modpatchid from obj$ where owner#=:1 a
nd name=:2 and namespace=:3 and remoteowner is null and linkname is null and sub

         277             275            1.0        0.0  69.5   3.5 f3ww8rgva3hrs
   PDB: PDB1
update /* KSXM:FLUSH COL */ sys.col_usage$ set equality_preds

OUTPUT
 = equality_preds + decode(bitand(:flag,1),0,0,1), equijoin_preds = equ
ijoin_preds + decode(bitand(:flag,2),0,0,1), nonequijoin_preds = nonequijoi
n_preds + decode(bitand(:flag,4),0,0,1), range_preds = range_preds

         118             118            1.0        0.0  66.8     0 gjaap3w3qbf8c
   PDB: PDB1
select count(*) from ilmobj$ where rownum = 1

          92           1,188           12.9        0.0 100.9     2 g0t052az3rx44
   PDB: PDB1
select name,intcol#,segcol#,type#,length,nvl(precision#,0),decode(type#,2,nvl(sc
ale,-127/*MAXSB1MINAL*/),178,scale,179,scale,180,scale,181,scale,182,scale,183,s
cale,231,scale,0),null$,fixedstorage,nvl(deflength,0),default$,rowid,col#,proper
ty, nvl(charsetid,0),nvl(charsetform,0),spare1,spare2,nvl(spare3,0), nvl(evaledi

OUTPUT

          87              87            1.0        0.0 103.4     0 5u7g54s63p4ts
   PDB: PDB1
select toid from type$ where package_obj#=:1 and typ_name=:2

          75             115            1.5        0.0  89.9     0 121ffmrc95v7g
   PDB: PDB1
select i.obj#,i.ts#,i.file#,i.block#,i.intcols,i.type#,i.flags,i.property,i.pctf
ree$,i.initrans,i.maxtrans,i.blevel,i.leafcnt,i.distkey,i.lblkkey,i.dblkkey,i.cl
ufac,i.cols,i.analyzetime,i.samplesize,i.dataobj#,nvl(i.degree,1),nvl(i.instance
s,1),i.rowcnt,mod(i.pctthres$,256),i.indmethod#,i.trunccnt,nvl(c.unicols,0),nvl(

          59              59            1.0        0.0 100.1     0 7am4w4pp3nwtm
   PDB: PDB1

OUTPUT
select count(*) from undo$

          44             326            7.4        0.0  90.7   4.9 3un99a0zwp4vd
   PDB: PDB1
select owner#,name,namespace,remoteowner,linkname,p_timestamp,p_obj#, nvl(proper
ty,0),subname,type#,flags,d_attrs from dependency$ d, obj$ o where d_obj#=:1 and
 p_obj#=obj#(+) order by order#

          19              19            1.0        0.0  77.1     0 afx304d90ps3z
   PDB: PDB1
select rowcnt, blkcnt, empcnt, avgspc, chncnt, avgrln, analyzetime, samplesize,
avgspc_flb, flbcnt, flags from tab_stats$ where obj#=:1

          15              15            1.0        0.1   3.3     0 6hnhqahphpk8n

OUTPUT
   PDB: PDB1
select free_mb from v$asm_diskgroup_stat where name=:1

                          ------------------------------------------------------



SQL ordered by Parse Calls                 DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Total Parse Calls:             515
-> Captured SQL account for  131.8% of Total

                            % Total
 Parse Calls  Executions     Parses    SQL Id
------------ ------------ --------- -------------
         125            2     24.27 3ms7w0c6ph91t

OUTPUT
   PDB: PDB1
insert /* KSXM:FLUSH COL */ into sys.col_usage$ (obj#, intcol#, equality_preds,
equijoin_preds, nonequijoin_preds, range_preds, like_preds, null_preds, flags, t
imestamp) values ( :objn, :coln, decode(bitand(:flag,1),0,0,1), decode(bit
and(:flag,2),0,0,1), decode(bitand(:flag,4),0,0,1), decode(bitand(:flag,8),0

         125          277     24.27 f3ww8rgva3hrs
   PDB: PDB1
update /* KSXM:FLUSH COL */ sys.col_usage$ set equality_preds
 = equality_preds + decode(bitand(:flag,1),0,0,1), equijoin_preds = equ
ijoin_preds + decode(bitand(:flag,2),0,0,1), nonequijoin_preds = nonequijoi
n_preds + decode(bitand(:flag,4),0,0,1), range_preds = range_preds

         118          118     22.91 gjaap3w3qbf8c

OUTPUT
   PDB: PDB1
select count(*) from ilmobj$ where rownum = 1

          87           87     16.89 5u7g54s63p4ts
   PDB: PDB1
select toid from type$ where package_obj#=:1 and typ_name=:2

          59           59     11.46 7am4w4pp3nwtm
   PDB: PDB1
select count(*) from undo$

          44           44      8.54 3un99a0zwp4vd
   PDB: PDB1
select owner#,name,namespace,remoteowner,linkname,p_timestamp,p_obj#, nvl(proper

OUTPUT
ty,0),subname,type#,flags,d_attrs from dependency$ d, obj$ o where d_obj#=:1 and
 p_obj#=obj#(+) order by order#

          19           19      3.69 afx304d90ps3z
   PDB: PDB1
select rowcnt, blkcnt, empcnt, avgspc, chncnt, avgrln, analyzetime, samplesize,
avgspc_flb, flbcnt, flags from tab_stats$ where obj#=:1

          15           15      2.91 6hnhqahphpk8n
   PDB: PDB1
select free_mb from v$asm_diskgroup_stat where name=:1

          15           15      2.91 6qz82dptj0qr7
   PDB: PDB1

OUTPUT
select l.col#, l.intcol#, l.lobj#, l.ind#, l.ts#, l.file#, l.block#, l.chunk, l.
pctversion$, l.flags, l.property, l.retention, l.freepools from lob$ l where l.o
bj# = :1 order by l.intcol# asc

          14           14      2.72 gngtvs38t0060
Module: oraagent.bin@rac1 (TNS V1-V3)
   PDB: PDB1
SELECT /*+ CONNECT_BY_FILTERING */ s.privilege# FROM sys.sysauth$ s CONNE
CT BY s.grantee# = PRIOR s.privilege# AND (s.pri
vilege# > 0 OR s.privilege# = -352) START WITH (s.p
rivilege# > 0 OR s.privilege# = -352) AND s.grantee# IN (SELECT c1.privilege

          13            6      2.52 d8g9jhjnjn206
   PDB: PDB1

OUTPUT
select tablespace_id, rfno, allocated_space, file_size, file_maxsize, changescn8
, flag, inst_id from sys.ts$, GV$FILESPACE_USAGE where ts# = tablespace_id and o
nline$ != 3 and inst_id != :inst and (changescn8 > :s)


SQL ordered by Parse Calls                 DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Total Parse Calls:             515
-> Captured SQL account for  131.8% of Total

                            % Total
 Parse Calls  Executions     Parses    SQL Id
------------ ------------ --------- -------------

           9           75      1.75 121ffmrc95v7g
   PDB: PDB1

OUTPUT
select i.obj#,i.ts#,i.file#,i.block#,i.intcols,i.type#,i.flags,i.property,i.pctf
ree$,i.initrans,i.maxtrans,i.blevel,i.leafcnt,i.distkey,i.lblkkey,i.dblkkey,i.cl
ufac,i.cols,i.analyzetime,i.samplesize,i.dataobj#,nvl(i.degree,1),nvl(i.instance
s,1),i.rowcnt,mod(i.pctthres$,256),i.indmethod#,i.trunccnt,nvl(c.unicols,0),nvl(

           8          289      1.55 acmvv4fhdc9zh
   PDB: PDB1
select obj#,type#,ctime,mtime,stime, status, dataobj#, flags, oid$, spare1, spar
e2, spare3, signature, spare7, spare8, spare9, nvl(dflcollid, 16382), creappid,
creverid, modappid, modverid, crepatchid, modpatchid from obj$ where owner#=:1 a
nd name=:2 and namespace=:3 and remoteowner is null and linkname is null and sub

           8           92      1.55 g0t052az3rx44
   PDB: PDB1

OUTPUT
select name,intcol#,segcol#,type#,length,nvl(precision#,0),decode(type#,2,nvl(sc
ale,-127/*MAXSB1MINAL*/),178,scale,179,scale,180,scale,181,scale,182,scale,183,s
cale,231,scale,0),null$,fixedstorage,nvl(deflength,0),default$,rowid,col#,proper
ty, nvl(charsetid,0),nvl(charsetform,0),spare1,spare2,nvl(spare3,0), nvl(evaledi

           6            3      1.17 3kqrku32p6sfn
   PDB: PDB1
MERGE /*+ OPT_PARAM('_parallel_syspls_obey_force' 'false') */ INTO OPTSTAT_USER_
PREFS$ D USING ( SELECT * FROM (SELECT O.OBJ#, SYSTIMESTAMP CHGTIME, ROUND(MAX(S
.DELTA_READ_IO_BYTES/S.DELTA_TIME), 3) SCANRATE FROM GV$ACTIVE_SESSION_HISTORY S
, GV$SQL_PLAN P, OBJ$ O, USER$ U WHERE S.INST_ID = P.INST_ID AND S.SQL_ID = P.SQ

                          ------------------------------------------------------


OUTPUT


SQL ordered by Sharable Memory             DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------



SQL ordered by Version Count               DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------



SQL ordered by Cluster Wait Time           DB/Inst: RACDB/racdb1  Snaps: 37-38

OUTPUT

                  No data exists for this section of the report.
                          ------------------------------------------------------



Key Instance Activity Stats                DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Ordered by statistic name

Statistic                                     Total     per Second     per Trans
-------------------------------- ------------------ -------------- -------------
db block changes                                 64            0.0          32.0
execute count                                 2,125            0.6       1,062.5
logons cumulative                                26            0.0          13.0
opened cursors cumulative                     2,112            0.6       1,056.0

OUTPUT
parse count (total)                             515            0.1         257.5
parse time elapsed                               48            0.0          24.0
physical reads                                   23            0.0          11.5
redo size                                     8,544            2.4       4,272.0
session cursor cache hits                     2,121            0.6       1,060.5
session logical reads                         7,424            2.1       3,712.0
user calls                                      163            0.1          81.5
workarea executions - optimal                   135            0.0          67.5
                          ------------------------------------------------------



Instance Activity Stats                    DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Ordered by statistic name


OUTPUT
Statistic                                     Total     per Second     per Trans
-------------------------------- ------------------ -------------- -------------
CCursor + sql area evicted                        7            0.0           3.5
CPU used by this session                         50            0.0          25.0
CPU used when call started                       36            0.0          18.0
CR blocks created                                 0            0.0           0.0
Client Advertised Receive Window                  0            0.0           0.0
Client Advertised Send Window                     0            0.0           0.0
Client Data Segments In                          29            0.0          14.5
Client Data Segments Out                         26            0.0          13.0
Client Path Maximum Transmission                  0            0.0           0.0
Client Send Congestion Window                     0            0.0           0.0
Client Time (usec) Busy Sending             280,000           77.8     140,000.0
Client Time (usec) Round Trip Ti                420            0.1         210.0

OUTPUT
Client Total Bytes Acked                     13,673            3.8       6,836.5
Client Total Bytes Received                   9,059            2.5       4,529.5
DFO trees parallelized                            1            0.0           0.5
HSC Heap Segment Block Changes                    8            0.0           4.0
Heap Segment Array Updates                        0            0.0           0.0
PX local messages recv'd                         20            0.0          10.0
PX local messages sent                           20            0.0          10.0
PX remote messages recv'd                        30            0.0          15.0
PX remote messages sent                          30            0.0          15.0
Parallel operations not downgrad                  1            0.0           0.5
Requests to/from client                          20            0.0          10.0
SQL*Net roundtrips to/from clien                 19            0.0           9.5
active txn count during cleanout                  1            0.0           0.5
blocks cleaned out using minact                   2            0.0           1.0

OUTPUT
buffer is not pinned count                    5,710            1.6       2,855.0
buffer is pinned count                          115            0.0          57.5
bytes received via SQL*Net from              12,519            3.5       6,259.5
bytes sent via SQL*Net to client              6,334            1.8       3,167.0
calls to get snapshot scn: kcmgs              2,553            0.7       1,276.5
calls to kcmgas                                   8            0.0           4.0
calls to kcmgcs                                 193            0.1          96.5
cell physical IO interconnect by            974,848          270.8     487,424.0
change write time                                 0            0.0           0.0
cleanout - number of ktugct call                  1            0.0           0.5
cleanouts and rollbacks - consis                  0            0.0           0.0
cluster key scan block gets                     884            0.3         442.0
cluster key scans                               721            0.2         360.5
commit batch/immediate performed                  2            0.0           1.0

OUTPUT
commit batch/immediate requested                  2            0.0           1.0
commit cleanout failures: callba                  0            0.0           0.0
commit cleanouts                                  8            0.0           4.0
commit cleanouts successfully co                  8            0.0           4.0
commit immediate performed                        2            0.0           1.0
commit immediate requested                        2            0.0           1.0
commit txn count during cleanout                  0            0.0           0.0
consistent changes                                0            0.0           0.0
consistent gets                               7,367            2.1       3,683.5
consistent gets examination                   3,231            0.9       1,615.5
consistent gets examination (fas              3,219            0.9       1,609.5
consistent gets from cache                    7,367            2.1       3,683.5
consistent gets pin                           4,136            1.2       2,068.0
consistent gets pin (fastpath)                4,123            1.2       2,061.5

OUTPUT
cursor authentications                           45            0.0          22.5
cursor reload failures                            0            0.0           0.0
data blocks consistent reads - u                  0            0.0           0.0
db block changes                                 64            0.0          32.0
db block gets                                    57            0.0          28.5
db block gets from cache                         57            0.0          28.5


Instance Activity Stats                    DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Ordered by statistic name

Statistic                                     Total     per Second     per Trans
-------------------------------- ------------------ -------------- -------------
db block gets from cache (fastpa                 44            0.0          22.0
deferred (CURRENT) block cleanou                  3            0.0           1.5

OUTPUT
enqueue conversions                               4            0.0           2.0
enqueue releases                                303            0.1         151.5
enqueue requests                                308            0.1         154.0
enqueue waits                                    22            0.0          11.0
execute count                                 2,125            0.6       1,062.5
file io service time                          2,201            0.6       1,100.5
free buffer requested                            45            0.0          22.5
gc cr blocks received                             4            0.0           2.0
gc cr multiblock grants received                  4            0.0           2.0
gc current blocks received                        7            0.0           3.5
gc local grants                                  13            0.0           6.5
gc merge pi fg                                    1            0.0           0.5
gc reader bypass grants                           2            0.0           1.0
gc remote grants                                 14            0.0           7.0

OUTPUT
gc status messages received                      10            0.0           5.0
gcs data block access records                    32            0.0          16.0
gcs messages sent                                27            0.0          13.5
ges messages sent                                55            0.0          27.5
global enqueue get time                       5,291            1.5       2,645.5
global enqueue gets sync                     15,255            4.2       7,627.5
global enqueue releases                      15,246            4.2       7,623.0
heap block compress                               3            0.0           1.5
immediate (CR) block cleanout ap                  0            0.0           0.0
index fetch by key                              951            0.3         475.5
index range scans                             1,233            0.3         616.5
logical read bytes from cache            60,817,408       16,893.2  30,408,704.0
logons cumulative                                26            0.0          13.0
messages sent                                     6            0.0           3.0

OUTPUT
no work - consistent read gets                3,947            1.1       1,973.5
non-idle wait count                           1,037            0.3         518.5
opened cursors cumulative                     2,112            0.6       1,056.0
parse count (failures)                            7            0.0           3.5
parse count (hard)                              305            0.1         152.5
parse count (total)                             515            0.1         257.5
parse time cpu                                   41            0.0          20.5
parse time elapsed                               48            0.0          24.0
physical read IO requests                        20            0.0          10.0
physical read bytes                         188,416           52.3      94,208.0
physical read total IO requests                  68            0.0          34.0
physical read total bytes                   974,848          270.8     487,424.0
physical read total multi block                   0            0.0           0.0
physical reads                                   23            0.0          11.5

OUTPUT
physical reads cache                             23            0.0          11.5
physical reads cache prefetch                     3            0.0           1.5
physical reads prefetch warmup                    3            0.0           1.5
queries parallelized                              1            0.0           0.5
recursive calls                               6,339            1.8       3,169.5
recursive cpu usage                              41            0.0          20.5
redo entries                                     32            0.0          16.0
redo size                                     8,544            2.4       4,272.0
redo subscn max counts                            3            0.0           1.5
redo synch time                                   4            0.0           2.0
redo synch time (usec)                       39,461           11.0      19,730.5
redo synch time overhead (usec)                  71            0.0          35.5
redo synch time overhead count (                  2            0.0           1.0
redo synch writes                                 2            0.0           1.0

OUTPUT
redo write info find                              2            0.0           1.0
rollback changes - undo records                   7            0.0           3.5


Instance Activity Stats                    DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Ordered by statistic name

Statistic                                     Total     per Second     per Trans
-------------------------------- ------------------ -------------- -------------
rollbacks only - consistent read                  0            0.0           0.0
rows fetched via callback                       134            0.0          67.0
session cursor cache hits                     2,121            0.6       1,060.5
session logical reads                         7,424            2.1       3,712.0
shared hash latch upgrades - no                   7            0.0           3.5
sorts (memory)                                  715            0.2         357.5

OUTPUT
sorts (rows)                                  8,837            2.5       4,418.5
sql area evicted                                  9            0.0           4.5
sql area purged                                   7            0.0           3.5
switch current caused by our pin                  0            0.0           0.0
switch current to new buffer                      0            0.0           0.0
table fetch by rowid                          1,228            0.3         614.0
table fetch continued row                        16            0.0           8.0
table scan blocks gotten                        673            0.2         336.5
table scan disk non-IMC rows got             34,915            9.7      17,457.5
table scan rows gotten                       34,915            9.7      17,457.5
table scans (short tables)                      101            0.0          50.5
transaction rollbacks                             2            0.0           1.0
undo change vector size                       2,184            0.6       1,092.0
user calls                                      163            0.1          81.5

OUTPUT
user logons cumulative                            0            0.0           0.0
user logouts cumulative                           1            0.0           0.5
user rollbacks                                    2            0.0           1.0
workarea executions - optimal                   135            0.0          67.5
                          ------------------------------------------------------



Instance Activity Stats - Absolute Values  DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Statistics with absolute values (should not be diffed)

Statistic                            Begin Value       End Value
-------------------------------- --------------- ---------------
session cursor cache count                   412             584
session uga memory                    19,359,064      25,763,192

OUTPUT
session uga memory max                30,988,208      65,559,160
                          ------------------------------------------------------

IOStat by Filetype summary                 DB/Inst: RACDB/racdb1  Snaps: 37-38
-> 'Data' columns suffixed with M,G,T,P are in multiples of 1024
    other columns suffixed with K,M,G,T,P are in multiples of 1000
-> Small Read and Large Read are average service times
-> Ordered by (Data Read + Write) desc

                Reads:  Reqs    Data   Writes:  Reqs    Data      Small    Large
Filetype Name     Data per sec per sec    Data per sec per sec     Read     Read
-------------- ------- ------- ------- ------- ------- ------- -------- --------
Data File           0M     0.0      0M      1M     0.0      0M   2.11ms
Temp File           0M     0.0      0M      0M     0.0      0M    .00ns

OUTPUT
TOTAL:              0M     0.0      0M      1M     0.0      0M   1.90ms
                          ------------------------------------------------------



Tablespace IO Stats                        DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------



File IO Stats                              DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------

OUTPUT

Buffer Wait Statistics                     DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------



Undo Segment Summary                       DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------

Undo Segment Stats                         DB/Inst: RACDB/racdb1  Snaps: 37-38


OUTPUT
                  No data exists for this section of the report.
                          ------------------------------------------------------



Segments by Logical Reads                  DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Total Logical Reads:           7,424
-> Captured Segments account for  152.6% of Total
-> When ** MISSING ** occurs, some of the object attributes may not be available

                     Tablespace
Owner                   Name
-------------------- ----------
                     Subobject  Obj.                             Logical
Object Name            Name     Type        Obj#   Dataobj#        Reads  %Total

OUTPUT
-------------------- ---------- ----- ---------- ---------- ------------ -------
SYS                  SYSTEM
I_HH_OBJ#_INTCOL#               INDEX         70         70        2,224   29.96
   PDB: PDB1
SYS                  SYSTEM
I_OBJ#_INTCOL#                  INDEX         65         65        1,472   19.83
   PDB: PDB1
SYS                  SYSTEM
I_OBJ1                          INDEX         36         36        1,328   17.89
   PDB: PDB1
SYS                  SYSTEM
AUD_OBJECT_OPT$                 TABLE        531        531        1,104   14.87
   PDB: PDB1
SYS                  SYSTEM

OUTPUT
HIST_HEAD$                      TABLE         68         68        1,056   14.22
   PDB: PDB1
                          ------------------------------------------------------

Segments by Physical Reads                 DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Total Physical Reads:              23
-> Captured Segments account for   34.8% of Total
-> When ** MISSING ** occurs, some of the object attributes may not be available

                     Tablespace
Owner                   Name
-------------------- ----------
                     Subobject  Obj.                            Physical
Object Name            Name     Type        Obj#   Dataobj#        Reads  %Total

OUTPUT
-------------------- ---------- ----- ---------- ---------- ------------ -------
QUERY_TUNING         USERS
SYS_C007627                     INDEX      73141      73141            5   21.74
   PDB: PDB1
SYS                  SYSTEM
COL_USAGE$                      TABLE        669        669            3   13.04
   PDB: PDB1
                          ------------------------------------------------------

Segments by Physical Read Requests         DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Total Physical Read Requests:              20
-> Captured Segments account for   25.0% of Total
-> When ** MISSING ** occurs, some of the object attributes may not be available


OUTPUT
                     Tablespace
Owner                   Name
-------------------- ----------
                     Subobject  Obj.                           Phys Read
Object Name            Name     Type        Obj#   Dataobj#     Requests  %Total
-------------------- ---------- ----- ---------- ---------- ------------ -------
SYS                  SYSTEM
COL_USAGE$                      TABLE        669        669            3   15.00
   PDB: PDB1
QUERY_TUNING         USERS
SYS_C007627                     INDEX      73141      73141            2   10.00
   PDB: PDB1
                          ------------------------------------------------------


OUTPUT
Segments by UnOptimized Reads              DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Total UnOptimized Read Requests:              20
-> Captured Segments account for   25.0% of Total
-> When ** MISSING ** occurs, some of the object attributes may not be available

                     Tablespace
Owner                   Name
-------------------- ----------
                     Subobject  Obj.                         UnOptimized
Object Name            Name     Type        Obj#   Dataobj#        Reads  %Total
-------------------- ---------- ----- ---------- ---------- ------------ -------
SYS                  SYSTEM
COL_USAGE$                      TABLE        669        669            3   15.00
   PDB: PDB1

OUTPUT
QUERY_TUNING         USERS
SYS_C007627                     INDEX      73141      73141            2   10.00
   PDB: PDB1
                          ------------------------------------------------------

Segments by Optimized Reads                DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------

Segments by Direct Physical Reads          DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------

OUTPUT

Segments by Physical Writes                DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Total Physical Writes:               1
-> Captured Segments account for   1.4E+03% of Total
-> When ** MISSING ** occurs, some of the object attributes may not be available

                     Tablespace
Owner                   Name
-------------------- ----------
                     Subobject  Obj.                            Physical
Object Name            Name     Type        Obj#   Dataobj#       Writes  %Total
-------------------- ---------- ----- ---------- ---------- ------------ -------
SYS                  SYSAUX
SMON_SCN_TIME                   TABLE        423        421            5  500.00

OUTPUT
   PDB: PDB1
SYS                  SYSTEM
COL_USAGE$                      TABLE        669        669            3  300.00
   PDB: PDB1
SYS                  SYSTEM
I_COL_USAGE$                    INDEX        670        670            2  200.00
   PDB: PDB1
SYS                  SYSTEM
MON_MODS_ALL$                   TABLE        675        675            1  100.00
   PDB: PDB1
SYS                  SYSTEM
OBJ$                            TABLE         18         18            1  100.00
   PDB: PDB1
                          ------------------------------------------------------

OUTPUT

Segments by Physical Write Requests        DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Total Physical Write Requests:               1
-> Captured Segments account for   1.2E+03% of Total
-> When ** MISSING ** occurs, some of the object attributes may not be available

                     Tablespace
Owner                   Name
-------------------- ----------
                     Subobject  Obj.                          Phys Write
Object Name            Name     Type        Obj#   Dataobj#     Requests  %Total
-------------------- ---------- ----- ---------- ---------- ------------ -------
SYS                  SYSAUX
SMON_SCN_TIME                   TABLE        423        421            5  500.00

OUTPUT
   PDB: PDB1
SYS                  SYSTEM
I_COL_USAGE$                    INDEX        670        670            2  200.00
   PDB: PDB1
SYS                  SYSTEM
COL_USAGE$                      TABLE        669        669            1  100.00
   PDB: PDB1
SYS                  SYSTEM
MON_MODS_ALL$                   TABLE        675        675            1  100.00
   PDB: PDB1
SYS                  SYSTEM
OBJ$                            TABLE         18         18            1  100.00
   PDB: PDB1
                          ------------------------------------------------------

OUTPUT

Segments by Direct Physical Writes         DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------

Segments by Table Scans                    DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------

Segments by DB Blocks Changes              DB/Inst: RACDB/racdb1  Snaps: 37-38
-> % of Capture shows % of DB Block Changes for each top segment compared
-> with total DB Block Changes for all segments captured by the Snapshot

OUTPUT
-> When ** MISSING ** occurs, some of the object attributes may not be available

                     Tablespace
Owner                   Name
-------------------- ----------
                     Subobject  Obj.                            DB Block    % of
Object Name            Name     Type        Obj#   Dataobj#      Changes Capture
-------------------- ---------- ----- ---------- ---------- ------------ -------
SYS                  SYSTEM
COL_USAGE$                      TABLE        669        669          272   80.95
   PDB: PDB1
SYS                  SYSTEM
OBJ$                            TABLE         18         18           16    4.76
   PDB: PDB1

OUTPUT
QUERY_TUNING         USERS
ORDERS_DEMO                     TABLE      73139      73139           16    4.76
   PDB: PDB1
SYS                  SYSAUX
SMON_SCN_TIME                   TABLE        423        421           16    4.76
   PDB: PDB1
SYS                  SYSTEM
SMON_SCN_TO_TIME_AUX            INDEX        422        422           16    4.76
   PDB: PDB1
                          ------------------------------------------------------



Segments by Row Lock Waits                 DB/Inst: RACDB/racdb1  Snaps: 37-38
-> % of Capture shows % of row lock waits for each top segment compared

OUTPUT
-> with total row lock waits for all segments captured by the Snapshot
-> When ** MISSING ** occurs, some of the object attributes may not be available

                     Tablespace
Owner                   Name
-------------------- ----------
                                                                     Row
                     Subobject  Obj.                                Lock    % of
Object Name            Name     Type        Obj#   Dataobj#        Waits Capture
-------------------- ---------- ----- ---------- ---------- ------------ -------
QUERY_TUNING         USERS
ORDERS_DEMO                     TABLE      73139      73139            1  100.00
   PDB: PDB1
                          ------------------------------------------------------

OUTPUT

Segments by ITL Waits                      DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------

Segments by Buffer Busy Waits              DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------

Segments by Global Cache Buffer Busy       DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.

OUTPUT
                          ------------------------------------------------------



Segments by CR Blocks Received             DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Total CR Blocks Received:               4
-> Captured Segments account for  575.0% of Total
-> When ** MISSING ** occurs, some of the object attributes may not be available

                     Tablespace
Owner                   Name
-------------------- ----------
                                                                   CR
                     Subobject  Obj.                             Blocks
Object Name            Name     Type        Obj#   Dataobj#     Received  %Total

OUTPUT
-------------------- ---------- ----- ---------- ---------- ------------ -------
SYS                  SYSAUX
SMON_SCN_TIME                   TABLE        423        421           13  325.00
   PDB: PDB1
SYS                  SYSTEM
I_MON_MODS_ALL$_OBJ             INDEX        676        676            2   50.00
   PDB: PDB1
SYS                  SYSTEM
MON_MODS_ALL$                   TABLE        675        675            2   50.00
   PDB: PDB1
SYS                  SYSAUX
SMON_SCN_TIME_SCN_ID            INDEX        425        425            2   50.00
   PDB: PDB1
SYS                  SYSTEM

OUTPUT
SYS_FBA_BARRIERSCN              TABLE       1527       1527            2   50.00
   PDB: PDB1
                          ------------------------------------------------------

Segments by Current Blocks Received        DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Total Current Blocks Received:               7
-> Captured Segments account for  442.9% of Total
-> When ** MISSING ** occurs, some of the object attributes may not be available

                     Tablespace
Owner                   Name
-------------------- ----------
                                                                 Current
                     Subobject  Obj.                             Blocks

OUTPUT
Object Name            Name     Type        Obj#   Dataobj#     Received  %Total
-------------------- ---------- ----- ---------- ---------- ------------ -------
SYS                  SYSTEM
COL_USAGE$                      TABLE        669        669           14  200.00
   PDB: PDB1
QUERY_TUNING         USERS
ORDERS_DEMO                     TABLE      73139      73139            4   57.14
   PDB: PDB1
SYS                  SYSAUX
SMON_SCN_TIME                   TABLE        423        421            4   57.14
   PDB: PDB1
SYS                  SYSTEM
MON_MODS_ALL$                   TABLE        675        675            3   42.86
   PDB: PDB1

OUTPUT
SYS                  SYSTEM
I_MON_MODS_ALL$_OBJ             INDEX        676        676            2   28.57
   PDB: PDB1
                          ------------------------------------------------------

Segments by Global Cache Remote Grants     DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Total Global Cache Remote Grants:              14
-> Captured Segments account for  121.4% of Total
-> When ** MISSING ** occurs, some of the object attributes may not be available

                     Tablespace
Owner                   Name
-------------------- ----------
                                                                      GC

OUTPUT
                     Subobject  Obj.                              Remote
Object Name            Name     Type        Obj#   Dataobj#       Grants  %Total
-------------------- ---------- ----- ---------- ---------- ------------ -------
QUERY_TUNING         USERS
SYS_C007627                     INDEX      73141      73141            5   35.71
   PDB: PDB1
SYS                  SYSTEM
COL_USAGE$                      TABLE        669        669            3   21.43
   PDB: PDB1
SYS                  SYSTEM
OBJ$                            TABLE         18         18            3   21.43
   PDB: PDB1
SYS                  SYSTEM
I_COL_USAGE$                    INDEX        670        670            2   14.29

OUTPUT
   PDB: PDB1
SYS                  SYSTEM
I_MON_MODS_ALL$_OBJ             INDEX        676        676            1    7.14
   PDB: PDB1
                          ------------------------------------------------------



Parameters modified by this container      DB/Inst: RACDB/racdb1  Snaps: 37-38
-> This section shows all the modified initialization parameters that
were in effect during the entire snapshot interval
-> End Value is displayed only if the parameter value was modified within
the snapshot interval

                                                                End value

OUTPUT
Parameter Name                Begin value                       (if different)
----------------------------- --------------------------------- --------------
db_cache_size                 0
   PDB: PDB1
db_create_file_dest           +DATA
   PDB: PDB1
pga_aggregate_limit           4294967296
   PDB: PDB1
pga_aggregate_target          1073741824
   PDB: PDB1
sga_target                    0
   PDB: PDB1
undo_tablespace               UNDOTBS1
   PDB: PDB1

OUTPUT
                          ------------------------------------------------------



Parameters modified by other containers    DB/Inst: RACDB/racdb1  Snaps: 37-38
-> This section shows all the modified initialization parameters that
were in effect during the snapshot interval
-> End Value is displayed only if the parameter value was changed within
the snapshot interval

                                                                End value
Parameter Name                Begin value                       (if different)
----------------------------- --------------------------------- --------------
_ipddb_enable                 TRUE
audit_file_dest               /u01/app/oracle/admin/racdb/adump

OUTPUT
audit_trail                   DB
cluster_database              TRUE
cluster_interconnects         10.10.10.11
compatible                    19.0.0
control_files                 +DATA/RACDB/CONTROLFILE/current.2
db_block_size                 8192
db_cache_size                 536870912
db_create_file_dest           +DATA
db_domain                     localdomain
db_keep_cache_size            67108864
db_name                       racdb
db_recovery_file_dest         +FRA
db_recovery_file_dest_size    14687404032
diagnostic_dest               /u01/app/oracle

OUTPUT
dispatchers                   (PROTOCOL=TCP) (SERVICE=racdbXDB)
enable_pluggable_database     TRUE
instance_number               1
listener_networks
local_listener                 (ADDRESS=(PROTOCOL=TCP)(HOST=192
nls_language                  AMERICAN
nls_territory                 AMERICA
open_cursors                  300
pga_aggregate_limit           4294967296
pga_aggregate_target          2147483648
processes                     300
remote_listener                rac-scan:1521
remote_login_passwordfile     EXCLUSIVE
sga_target                    1610612736

OUTPUT
thread                        1
undo_tablespace               UNDOTBS1
                          ------------------------------------------------------



Multi-Valued Parameters modified by this containerDB/Inst: RACDB/racdb1  Snaps

                  No data exists for this section of the report.
                          ------------------------------------------------------



Multi-Valued Parameters modified by other containersDB/Inst: RACDB/racdb1  Sna
-> This section only displays parameters that have more than one value
->'(NULL)' indicates a missing parameter value

OUTPUT
-> A blank in the 'End Snapshot' indicates the same value as the 'Begin Snapshot

                                                                End value
Parameter Name                Begin value                       (if different)
----------------------------- --------------------------------- --------------
control_files                 +DATA/RACDB/CONTROLFILE/current.2
                              +FRA/RACDB/CONTROLFILE/current.25
                          ------------------------------------------------------

Top SQL with Top Events                    DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Top SQL statements by DB Time along with the top events by DB Time
   for those SQLs.
-> % Activity is the percentage of DB Time due to the SQL.
-> % Event is the percentage of DB Time due to the event that the SQL is

OUTPUT
   waiting on.
-> % Row Source is the percentage of DB Time due to the row source for the
   SQL waiting on the event.
-> Executions is the number of executions of the SQL that were sampled in ASH.

                 SQL ID            Plan Hash           Executions     % Activity
----------------------- -------------------- -------------------- --------------
                                                                           % Row
Event                          % Event Top Row Source                     Source
------------------------------ ------- --------------------------------- -------
                              Container Name
 -------------------------------------------
          aa7t6babr24zf           3410170971                    1         100.00
enq: TX - row lock contention   100.00 UPDATE                             100.00

OUTPUT
update orders_demo set total_amount = 888 where order_id = 10
                                        PDB1

                          ------------------------------------------------------

Top SQL with Top Row Sources               DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Top SQL statements by DB Time along with the top row sources by DB Time
   for those SQLs.
-> % Activity is the percentage of DB Time due to the SQL.
-> % Row Source is the percentage of DB Time spent on the row source by
   that SQL.
-> % Event is the percentage of DB Time spent on the event by the
   SQL executing the row source.
-> Executions is the number of executions of the SQL that were sampled in ASH.

OUTPUT

                 SQL ID            Plan Hash           Executions     % Activity
----------------------- -------------------- -------------------- --------------
                                           % Row
Row Source                                Source Top Event               % Event
---------------------------------------- ------- ----------------------- -------
                              Container Name
 -------------------------------------------
          aa7t6babr24zf           3410170971                    1         100.00
UPDATE                                    100.00 enq: TX - row lock cont  100.00
update orders_demo set total_amount = 888 where order_id = 10
                                        PDB1

                          ------------------------------------------------------

OUTPUT

Top Sessions                               DB/Inst: RACDB/racdb1  Snaps: 37-38
-> '# Samples Active' shows the number of ASH samples in which the session
      was found waiting for that particular event. The percentage shown
      in this column is calculated with respect to wall clock time
      and not total database activity.
-> 'XIDs' shows the number of distinct transaction IDs sampled in ASH
      when the session was waiting for that particular event

   Sid, Serial# % Activity Event                             % Event
--------------- ---------- ------------------------------ ----------
User                 Program                          # Samples Active     XIDs
-------------------- ------------------------------ ------------------ --------
       67,56163     100.00 enq: TX - row lock contention      100.00

OUTPUT
QUERY_TUNING         java@rac1 (TNS V1-V3)                6/360 [  2%]        0

                          ------------------------------------------------------

Top Blocking Sessions                      DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Blocking session activity percentages are calculated with respect to
      waits on enqueues, latches and "buffer busy" only
-> '% Activity' represents the load on the database caused by
      a particular blocking session
-> '# Samples Active' shows the number of ASH samples in which the
      blocking session was found active.
-> 'XIDs' shows the number of distinct transaction IDs sampled in ASH
      when the blocking session was found active.


OUTPUT
 Blocking Sid (Inst) % Activity Event Caused                      % Event
-------------------- ---------- ------------------------------ ----------
User                 Program                          # Samples Active     XIDs
-------------------- ------------------------------ ------------------ --------
    54,49528(     2)      83.33 enq: TX - row lock contention       83.33
** NOT FOUND **      BLOCKING SESSION NOT FOUND           0/360 [  0%]      N/A

                          ------------------------------------------------------

Top PL/SQL Procedures                      DB/Inst: RACDB/racdb1  Snaps: 37-38

                  No data exists for this section of the report.
                          ------------------------------------------------------


OUTPUT
Top Events                                 DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Top Events by DB Time
-> % Activity is the percentage of DB Time due to the event

Event                               Event Class     Session Type
----------------------------------- --------------- ---------------
           Avg Active
% Activity   Sessions
---------- ----------
enq: TX - row lock contention       Application     FOREGROUND
    100.00       0.02
                          ------------------------------------------------------

Top Event P1/P2/P3 Values                  DB/Inst: RACDB/racdb1  Snaps: 37-38

OUTPUT
-> Top Events by DB Time and the top P1/P2/P3 values for those events.
-> % Event is the percentage of DB Time due to the event
-> % Activity is the percentage of DB Time due to the event with the given
   P1,P2,P3 Values.

Event                          % Event             P1, P2, P3 Values % Activity
------------------------------ ------- ----------------------------- ----------
Parameter 1                Parameter 2                Parameter 3
-------------------------- -------------------------- --------------------------
enq: TX - row lock contention   100.00    "1415053318","917532","34"     100.00
name|mode                  usn<<16 | slot             sequence

                          ------------------------------------------------------


OUTPUT
Top DB Objects                             DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Top DB Objects by DB Time with respect to Application, Cluster,
   User I/O,  buffer busy waits and In-Memory DB events only.
-> Tablespace name is not available for reports generated from the root PDB
   of a consolidated database.
-> When ** MISSING ** occurs, some of the object attributes may not be available

      Object ID % Activity Event                             % Event
--------------- ---------- ------------------------------ ----------
Object Name (Type)                                    Tablespace
----------------------------------------------------- --------------------------
                             Container Name
-------------------------------------------
          73139     100.00 enq: TX - row lock contention      100.00

OUTPUT
QUERY_TUNING.ORDERS_DEMO (TABLE)                      USERS
                                       PDB1
                          ------------------------------------------------------

Activity Over Time                         DB/Inst: RACDB/racdb1  Snaps: 37-38
-> Analysis period is divided into smaller time slots as indicated
   in the 'Slot Time (Duration)'.
-> Top 3 events are reported in each of those slots
-> 'Slot Count' shows the number of ASH samples in that slot
-> 'Event Count' shows the number of ASH samples waiting for
   that event in that slot
-> '% Event' is 'Event Count' over all ASH samples in the analysis period

                         Slot                                   Event

OUTPUT
Slot Time (Duration)    Count Event                             Count % Event
-------------------- -------- ------------------------------ -------- -------
10:20:00   (5.0 min)        2 enq: TX - row lock contention         2   33.33
10:25:00   (5.0 min)        4 enq: TX - row lock contention         4   66.67
                          ------------------------------------------------------

End of Report


1869 rows selected.

SYS@racdb1[PDB1]>
SYS@racdb1[PDB1]>
