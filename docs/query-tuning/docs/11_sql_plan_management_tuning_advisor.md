# Lesson 11: SQL Plan Management & SQL Tuning Advisor

Bai 10 xu ly SQL cham vi **lock**. Bai 11 xu ly truong hop khac: SQL khong bi lock, khong doi I/O bat thuong, nhung van cham vi **optimizer chon plan sai**.

Tinh huong rat hay gap:

```text
Hom qua SQL chay 0.1s.
Hom nay cung SQL do chay 30s.
Code khong doi.
Data/statistics/plan da doi.
```

Day goi la **plan regression**.

> **License note:** SQL Tuning Advisor, SQL Profile, SQL Monitor thuoc Oracle Tuning Pack tren production. Oracle Tuning Pack yeu cau Oracle Diagnostics Pack. SQL Plan Management/Baseline **khong can Diagnostics Pack/Tuning Pack** theo Oracle 19c Licensing, nhung van phai kiem tra edition/policy cong ty. Homelab cua ban dang bat `DIAGNOSTIC+TUNING` va co dang training nen co the hoc. Production chua xac nhan license thi dung nhanh free: `v$sql`, `DBMS_XPLAN.DISPLAY_CURSOR`, stats/index/rewrite SQL, va SPM neu edition/policy cho phep.

---

## License Safety Checklist Truoc Khi Chay Bai 11

Muc nay de tranh "Oracle bo tu" khi lam tren moi truong khong phai lab.

### 0.1. Kiem tra dang o lab hay production

```sql
SELECT name, db_unique_name, database_role, open_mode, cdb FROM v$database;
```

```sql
SELECT inst_id, instance_name, host_name, status, database_status FROM gv$instance ORDER BY inst_id;
```

```sql
SHOW CON_NAME
SHOW USER
```

```sql
SELECT username, program, machine, module, status, COUNT(*) AS sessions FROM gv$session WHERE type = 'USER' GROUP BY username, program, machine, module, status ORDER BY sessions DESC;
```

Neu thay app server, user nghiep vu, schema business, nhieu session that: coi nhu production cho toi khi duoc xac nhan nguoc lai.

### 0.2. Kiem tra edition

```sql
SELECT banner_full FROM v$version WHERE banner_full LIKE 'Oracle Database%';
```

Can biet ban dang dung Standard Edition 2, Enterprise Edition, Exadata/Cloud, hay homelab cai bang OTN/developer media. Edition khong tu dong noi rang da mua pack.

### 0.3. Kiem tra management pack dang bat ve mat ky thuat

```sql
SHOW PARAMETER control_management_pack_access
```

Y nghia:

| Gia tri | Nghia ky thuat | Co nghia la da mua license khong? |
|:---|:---|:---|
| `DIAGNOSTIC+TUNING` | Diagnostics Pack va Tuning Pack dang enable | Khong |
| `DIAGNOSTIC` | Chi Diagnostics Pack dang enable | Khong |
| `NONE` | Ca Diagnostics/Tuning Pack bi disable | An toan hon neu production khong license |

Neu production khong co Diagnostics/Tuning Pack license, DBA nen can nhac:

```sql
ALTER SYSTEM SET control_management_pack_access = NONE SCOPE=BOTH SID='*';
```

Khong tu y chay lenh nay tren production neu khong phai DBA phu trach, vi co the anh huong monitoring.

### 0.4. Kiem tra feature/pack da tung bi dung chua

Oracle Licensing guide khuyen dung script `options_packs_usage_statistics.sql` tu My Oracle Support de kiem tra option/pack usage. Neu khong co script, co the xem so bo:

```sql
SELECT name, detected_usages, currently_used, first_usage_date, last_usage_date FROM dba_feature_usage_statistics WHERE name IN ('SQL Tuning Advisor', 'SQL Profile', 'SQL Monitoring and Tuning pages', 'Automatic SQL Tuning Advisor', 'Automatic Workload Repository', 'Active Session History') ORDER BY name;
```

Day la cau mot dong de paste truc tiep trong terminal SQLcl/SQL*Plus.

**Ket qua lab cua ban:**

```text
control_management_pack_access = DIAGNOSTIC+TUNING

NAME                                DETECTED_USAGES CURRENTLY_USED
Automatic SQL Tuning Advisor                      0 FALSE
Automatic Workload Repository                     0 FALSE
SQL Monitoring and Tuning pages                   0 FALSE
SQL Profile                                       0 FALSE
SQL Tuning Advisor                                0 FALSE
```

Cach doc:

- `DIAGNOSTIC+TUNING`: feature dang mo ve mat ky thuat.
- `DETECTED_USAGES = 0`: Oracle chua ghi nhan usage cua feature do trong `dba_feature_usage_statistics`.
- `CURRENTLY_USED = FALSE`: hien tai feature do khong bi danh dau la dang duoc dung.
- Cac dong bi lap co the do thong tin theo container/version/component; neu can phan tach CDB/PDB, dung `cdb_feature_usage_statistics` va them `con_id`.

Ban co the check theo container bang cau mot dong nay neu user co quyen:

```sql
SELECT con_id, name, detected_usages, currently_used, first_usage_date, last_usage_date FROM cdb_feature_usage_statistics WHERE name IN ('SQL Tuning Advisor', 'SQL Profile', 'SQL Monitoring and Tuning pages', 'Automatic SQL Tuning Advisor', 'Automatic Workload Repository', 'Active Session History') ORDER BY con_id, name;
```

Luu y: query tren chi giup soi so bo. Ket luan license chinh thuc van phai dua vao hop dong/license owner va/hoac Oracle LMS tooling.

### 0.5. Bang quyet dinh nhanh

| Neu ban muon dung | Tren homelab/dev/test | Tren production |
|:---|:---|:---|
| `DBMS_SQLTUNE.CREATE_TUNING_TASK` | OK de hoc | Chi khi co Tuning Pack + Diagnostics Pack |
| `DBMS_SQLTUNE.ACCEPT_SQL_PROFILE` | OK de hoc | Chi khi co Tuning Pack + Diagnostics Pack |
| `V$SQL_MONITOR`, SQL Monitor report | OK de hoc | Chi khi co Tuning Pack + Diagnostics Pack |
| `DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE` | OK neu edition cho phep | SPM khong can Diagnostics/Tuning Pack, nhung kiem tra edition/policy |
| `v$sql`, `v$sqlarea`, `DBMS_XPLAN.DISPLAY_CURSOR` | OK | OK |

### 0.6. Ket luan cho lab hien tai cua ban

Tu cac output da kiem tra:

```text
DB: RACDB
Role: PRIMARY
CDB/PDB: CDB$ROOT + PDB1
Instances: racdb1/rac1, racdb2/rac2
Sessions: chu yeu SYS/SYSRAC
Data: QUERY_TUNING.ORDERS_DEMO 100000 rows, CUSTOMERS_DEMO 5000 rows, HR sample
control_management_pack_access: DIAGNOSTIC+TUNING
```

Ket luan thuc hanh: moi truong nay co dang homelab/training, dung bai 11 de hoc la on. Khong lay dieu nay lam bang chung cho production cong ty.

---

## 1. Muc Tieu Bai Hoc

Sau bai nay ban can lam duoc:

1. Kiem tra mot SQL co bi doi plan khong.
2. Doc `plan_hash_value` trong `v$sql`.
3. Chay SQL Tuning Advisor trong lab.
4. Hieu SQL Profile khac SQL Plan Baseline o dau.
5. Load SQL Plan Baseline tu cursor cache.
6. Biet nhanh free khi khong duoc dung Tuning Pack.

---

## 2. Tu Khoa Can Nho

| Tu khoa | Y nghia |
|:---|:---|
| `SQL_ID` | Ma dinh danh cau SQL |
| `PLAN_HASH_VALUE` | Ma hash cua execution plan |
| Plan regression | SQL bi doi sang plan xau hon |
| SQL Profile | Bo thong tin/correction giup optimizer uoc luong tot hon |
| SQL Plan Baseline | Danh sach plan duoc chap nhan de ngan optimizer dung plan la |
| SQL Tuning Advisor | Cong cu Oracle tu phan tich SQL va de xuat fix |

Meo nho:

```text
SQL Profile = giup optimizer doan dung hon
SQL Plan Baseline = chan optimizer chay lung tung ngoai plan duoc chap nhan
```

---

## 3. Tim SQL Can Dieu Tra

Dung `v$sqlarea` de tim SQL ton elapsed/buffer gets. Cau nay free, dung duoc ca production:

```sql
SELECT sql_id, executions, ROUND(elapsed_time / 1e6, 1) AS total_elapsed_sec, ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 3) AS avg_elapsed_sec, buffer_gets, disk_reads, parsing_schema_name, SUBSTR(sql_text, 1, 120) AS sql_preview FROM v$sqlarea WHERE executions > 0 AND parsing_schema_name = 'QUERY_TUNING' ORDER BY elapsed_time DESC FETCH FIRST 20 ROWS ONLY;
```

Neu muon bat query minh vua chay, gan marker:

```sql
SELECT /* L11_PLAN_TEST */ * FROM orders_demo WHERE order_status = 'CANCELLED';
```

Tim lai marker:

```sql
SELECT sql_id, executions, ROUND(elapsed_time / 1e6, 3) AS total_elapsed_sec, buffer_gets, disk_reads, SUBSTR(sql_text, 1, 120) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L11_PLAN_TEST%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Neu output top SQL dai qua, dung cach nay:

1. Gan marker ngan vao query: `/* L11_PLAN_TEST */`
2. Tim marker de lay `SQL_ID`
3. Tu do ve sau chi dung `SQL_ID`, khong can copy lai SQL text dai

**Ket qua lab cua ban:**

```text
SQL_ID        = bjfntw0qqzbgf
EXECUTIONS    = 1
ELAPSED       = 0.12s
BUFFER_GETS   = 1961
DISK_READS    = 656
SQL_PREVIEW   = SELECT /* L11_PLAN_TEST */ * FROM orders_demo WHERE order_status = 'CANCELLED'
```

Tu day, dung SQL_ID that:

```sql
SELECT sql_id, child_number, plan_hash_value, executions, is_bind_sensitive, is_bind_aware, last_active_time FROM v$sql WHERE sql_id = 'bjfntw0qqzbgf' ORDER BY child_number;
```

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'bjfntw0qqzbgf', cursor_child_no => NULL, format => 'ALLSTATS LAST +PEEKED_BINDS +PREDICATE'));
```

Neu muon query khong in ra 10000 rows nua, dung `COUNT(*)` de test nhe hon:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS L11_PLAN_TEST_COUNT */ COUNT(*) FROM orders_demo WHERE order_status = 'CANCELLED';
```

Tim SQL_ID cua ban count:

```sql
SELECT sql_id, executions, ROUND(elapsed_time / 1e6, 3) AS total_elapsed_sec, buffer_gets, disk_reads, SUBSTR(sql_text, 1, 120) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L11_PLAN_TEST_COUNT%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

**Ket qua lab cua ban voi COUNT marker:**

```text
SQL_ID        = 18h6ufv1ttwvw
EXECUTIONS    = 1
ELAPSED       = 0.003s
BUFFER_GETS   = 31
DISK_READS    = 0
SQL_PREVIEW   = SELECT /*+ GATHER_PLAN_STATISTICS L11_PLAN_TEST_COUNT */ COUNT(*) FROM orders_demo WHERE order_status = 'CANCELLED'
```

Nhan xet nhanh:

- `COUNT(*)` khong phai fetch 10000 rows ve terminal nen nhanh hon `SELECT *`.
- `BUFFER_GETS = 31` rat nhe.
- `DISK_READS = 0` nghia la doc tu buffer cache, khong phai doc disk.
- Do query co hint `GATHER_PLAN_STATISTICS`, buoc tiep theo xem duoc `A-Rows/Buffers` trong `DISPLAY_CURSOR`.

Xem plan that cua SQL_ID nay:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => '18h6ufv1ttwvw', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE'));
```

---

## 4. Kiem Tra SQL Co Nhieu Plan Khong

Mot `SQL_ID` co nhieu `PLAN_HASH_VALUE` la dau hieu SQL co the bi doi plan theo thoi gian/session/bind.

Voi lab hien tai cua ban, SQL_ID that la `18h6ufv1ttwvw`, nen paste cau nay:

```sql
SELECT sql_id, child_number, plan_hash_value, executions, is_bind_sensitive, is_bind_aware, last_active_time FROM v$sql WHERE sql_id = '18h6ufv1ttwvw' ORDER BY child_number;
```

**Ket qua lab cua ban:**

```text
SQL_ID          = 18h6ufv1ttwvw
CHILD_NUMBER    = 0
PLAN_HASH_VALUE = 2428763047
EXECUTIONS      = 1
IS_BIND_SENSITIVE = N
IS_BIND_AWARE     = N
LAST_ACTIVE_TIME  = 10-JUN-26
```

Ket luan:

- SQL nay hien co 1 child cursor: `child_number = 0`.
- Hien chi thay 1 plan: `plan_hash_value = 2428763047`.
- `IS_BIND_SENSITIVE = N`, `IS_BIND_AWARE = N`: query nay khong dung bind variable nen ACS khong lien quan.
- Chua thay dau hieu plan regression trong shared pool cho SQL_ID nay.

Cach doc:

| Dau hieu | Y nghia |
|:---|:---|
| Nhieu `child_number` | Co nhieu child cursor |
| Nhieu `plan_hash_value` | SQL co nhieu execution plan |
| `is_bind_sensitive = Y` | Plan co the phu thuoc bind value |
| `is_bind_aware = Y` | Adaptive Cursor Sharing da tao plan theo bind |

---

## 5. Xem Plan That Cua SQL

Dung `DISPLAY_CURSOR`, khong dung `EXPLAIN PLAN` khi can plan da chay that.

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => '18h6ufv1ttwvw', cursor_child_no => NULL, format => 'ALLSTATS LAST +PEEKED_BINDS +PREDICATE'));
```

**Ket qua lab cua ban:**

```text
SQL_ID          = 18h6ufv1ttwvw
PLAN_HASH_VALUE = 2428763047

| Id | Operation        | Name              | Starts | E-Rows | A-Rows | Buffers |
|  0 | SELECT STATEMENT |                   |      1 |        |      1 |      31 |
|  1 | SORT AGGREGATE   |                   |      1 |      1 |      1 |      31 |
|* 2 | INDEX RANGE SCAN | IDX_ORDERS_STATUS |      1 |  10000 |  10000 |      31 |

Predicate:
2 - access("ORDER_STATUS"='CANCELLED')
```

Ket luan:

- Oracle dung `INDEX RANGE SCAN` tren `IDX_ORDERS_STATUS`.
- `E-Rows = 10000`, `A-Rows = 10000`: optimizer uoc luong dung.
- `Buffers = 31`: query rat nhe.
- `PLAN_HASH_VALUE = 2428763047`: day la plan hien tai de so sanh ve sau.
- Chua co dau hieu plan regression trong lab nay.

Neu vua chay query trong session hien tai:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST +PEEKED_BINDS +PREDICATE'));
```

Luu y: `DISPLAY_CURSOR()` khong truyen `sql_id` se lay cau SQL gan nhat trong session. Neu ban vua chay `DISPLAY_CURSOR(sql_id => '18h6ufv1ttwvw')`, cau gan nhat chinh la `DISPLAY_CURSOR`, nen Oracle se hien plan cua `DISPLAY_CURSOR` chu khong phai plan cua query business. De tranh nham trong bai 11, uu tien dung ban co `sql_id => '18h6ufv1ttwvw'`.

**Ket qua lab khi ban bi nham:**

```text
SQL_ID  7t0z7zxdmjmzu
SQL Text:
select * from table(dbms_xplan.display_cursor(format => 'ALLSTATS LAST +PREDICSTE'))

Operation:
COLLECTION ITERATOR PICKLER FETCH DISPLAY_CURSOR
```

Giai thich:

- Day khong phai plan cua query `orders_demo`.
- Day la plan cua chinh cau `DBMS_XPLAN.DISPLAY_CURSOR`.
- Nguyen nhan: ban chay `DISPLAY_CURSOR()` khong truyen `sql_id`, nen Oracle lay SQL gan nhat trong session.
- Cach tranh nham: sau khi tim duoc SQL_ID cua query business, luon truyen SQL_ID ro rang.

Vi du dung cho case xau:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'gyg4fwp4j3ham', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE'));
```

Vi du dung cho case count tot:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => '18h6ufv1ttwvw', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE'));
```

**Loi hay gap: sai chu `PREDICATE`**

Sai:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST +PREDICSTE'));
```

Loi:

```text
Error: format 'ALLSTATS LAST +PREDICSTE' not valid for DBMS_XPLAN.DISPLAY_CURSOR()
```

Dung:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST +PREDICATE'));
```

Meo nho: `PREDICATE` = dieu kien loc trong `WHERE`.

Can nhin:

| Cot/phan | Can hoi |
|:---|:---|
| `E-Rows` vs `A-Rows` | Optimizer doan sai bao nhieu lan? |
| `Buffers` | Buoc nao doc nhieu block nhat? |
| `Predicate Information` | Dieu kien co thanh `access` predicate hay chi la `filter`? |
| `PEEKED_BINDS` | Oracle da peek bind value nao khi compile plan? |
| `plan_hash_value` | Plan hien tai la plan nao? |

---

## 6. SQL Tuning Advisor Trong Lab

Muc nay dung Tuning Pack. Dung trong homelab cua ban thi ok. Production phai co license.

Neu copy tung cau trong terminal bi loi va SQLcl dang chay trong may ao, dung cac lenh 1 dong ben duoi. Khong dung `@labs/...` neu file chi nam tren host Codex, vi may ao se khong thay file do.

```sql
EXEC DBMS_SQLTUNE.DROP_TUNING_TASK('L11_TUNE_TASK');
```

Neu task chua ton tai va lenh drop bao loi, bo qua. Sau do tao task bang `SELECT` 1 dong, khong can `DECLARE`, khong can `/`:

```sql
EXEC DBMS_OUTPUT.PUT_LINE(DBMS_SQLTUNE.CREATE_TUNING_TASK(sql_id => '18h6ufv1ttwvw', scope => 'COMPREHENSIVE', time_limit => 60, task_name => 'L11_TUNE_TASK'));
```

Chay task:

```sql
EXEC DBMS_SQLTUNE.EXECUTE_TUNING_TASK('L11_TUNE_TASK');
```

Xem report:

```sql
SET LONG 100000 LONGCHUNKSIZE 100000 PAGESIZE 500 LINESIZE 200
```

```sql
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('L11_TUNE_TASK', 'TEXT', 'ALL', 'ALL') AS report FROM dual;
```

### 6.1. Tao Tuning Task Cho SQL_ID

Dung 3 lenh mot dong nay. Khong dung `DECLARE`, khong dung `/`.

Buoc 1: clear buffer neu vua paste block loi:

```sql
CLEAR BUFFER
```

Buoc 2: drop task cu neu da ton tai. Neu task chua ton tai va bao loi, bo qua:

```sql
EXEC DBMS_SQLTUNE.DROP_TUNING_TASK('L11_TUNE_TASK');
```

Neu gap loi nay:

```text
ORA-13605: The specified task or object L11_TUNE_TASK does not exist for the current user.
```

Thi **khong sao**. Nghia la task chua ton tai nen khong co gi de drop. Bo qua loi nay va chay tiep buoc tao task.

Buoc 3: tao task bang function mot dong:

```sql
EXEC DBMS_OUTPUT.PUT_LINE(DBMS_SQLTUNE.CREATE_TUNING_TASK(sql_id => '18h6ufv1ttwvw', scope => 'COMPREHENSIVE', time_limit => 60, task_name => 'L11_TUNE_TASK'));
```

Luu y: dung `scope => 'COMPREHENSIVE'`. Khong dung `DBMS_SQLTUNE.SCOPE_COMPREHENSIVE` trong lenh mot dong, vi co the bi `PLS-221`.

Buoc 4: execute task:

```sql
EXEC DBMS_SQLTUNE.EXECUTE_TUNING_TASK('L11_TUNE_TASK');
```

Neu thay `PL/SQL procedure successfully completed.` la xong, khong go them `/`.

**Neu gap loi nay:**

```text
ORA-13616: The current user QUERY_TUNING has not been granted the ADVISOR privilege.
```

Nghia la user `QUERY_TUNING` chua co quyen chay advisor. Can user DBA/SYS grant trong PDB1:

```sql
GRANT ADVISOR TO query_tuning;
```

Neu muon cho user xem cac view DBA lien quan profile/baseline co the can them quyen doc catalog tuy bai lab:

```sql
GRANT SELECT_CATALOG_ROLE TO query_tuning;
```

Sau khi grant, connect lai user `QUERY_TUNING` roi chay lai tuning task.

Neu khong muon grant quyen, bo qua muc SQL Tuning Advisor va di tiep nhanh free: `DISPLAY_CURSOR`, stats, index, rewrite SQL, hoac SPM neu du quyen.

### 6.2. Xem Report

```sql
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('L11_TUNE_TASK') AS report FROM dual;
```

Neu report chi hien:

```text
GENERAL INFORMATION SECTION
----------------------------------------------------
```

thi thuong la SQLcl/SQL*Plus dang cat CLOB qua ngan. Set format truoc roi chay lai:

```sql
SET LONG 100000 LONGCHUNKSIZE 100000 PAGESIZE 500 LINESIZE 200
```

```sql
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('L11_TUNE_TASK', 'TEXT', 'ALL', 'ALL') AS report FROM dual;
```

**Ket qua lab cua ban:**

```text
Tuning Task Name   : L11_TUNE_TASK
Tuning Task Owner  : QUERY_TUNING
Workload Type      : Single SQL Statement
Execution Type     : TUNE SQL
Scope              : COMPREHENSIVE
Completion Status  : COMPLETED
Schema Name        : QUERY_TUNING
Container Name     : PDB1
SQL ID             : 18h6ufv1ttwvw
SQL Text           : SELECT /*+ GATHER_PLAN_STATISTICS L11_PLAN_TEST_COUNT */ COUNT(*) FROM orders_demo WHERE order_status = 'CANCELLED'

There are no recommendations to improve the statement.

Plan hash value    : 2428763047
Operation          : INDEX RANGE SCAN IDX_ORDERS_STATUS
Rows estimate      : 10000
Cost               : 30
Predicate          : access("ORDER_STATUS"='CANCELLED')
```

Giai thich:

- `Completion Status = COMPLETED`: SQL Tuning Advisor da chay thanh cong.
- `There are no recommendations`: Oracle khong thay index/profile/rewrite nao can thiet cho SQL nay.
- Ly do hop ly: query da dung index `IDX_ORDERS_STATUS`, estimate dung 10000 rows, va runtime truoc do rat nhe (`0.003s`, `31 buffers`, `0 disk reads`).
- `Plan hash value = 2428763047`: day la plan hien tai, trung voi plan da xem bang `DISPLAY_CURSOR`.
- Day la ket qua tot: bai 11 khong bat buoc phai co recommendation. Muc tieu la biet chay advisor va biet doc ket luan.
- `Hint Report` bao `L11_PLAN_TEST_COUNT` la syntax error vi Oracle hieu chu trong comment hint `/*+ ... */` nhu hint. Marker nay khong anh huong tuning, nhung ve sau nen dung marker comment thuong `/* L11_PLAN_TEST_COUNT */` neu khong can hint.

Neu muon test marker sach hon:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L11_PLAN_TEST_COUNT_2 */ COUNT(*) FROM orders_demo WHERE order_status = 'CANCELLED';
```

Trong cau tren, `GATHER_PLAN_STATISTICS` la hint that, con `L11_PLAN_TEST_COUNT_2` chi la marker comment.

Kiem tra task da chay xong chua:

```sql
SELECT task_name, status, execution_start, execution_end FROM user_advisor_tasks WHERE task_name = 'L11_TUNE_TASK';
```

Kiem tra log cua task:

```sql
SELECT task_name, status, execution_start, execution_end FROM user_advisor_log WHERE task_name = 'L11_TUNE_TASK';
```

Neu report khong co recommendation, dieu do co the binh thuong vi SQL lab hien tai rat nhe:

```text
SQL_ID        = 18h6ufv1ttwvw
Elapsed       = 0.003s
Buffer gets   = 31
Disk reads    = 0
Plan          = INDEX RANGE SCAN IDX_ORDERS_STATUS
E-Rows/A-Rows = 10000/10000
```

Voi SQL da tot nhu vay, SQL Tuning Advisor co the khong de xuat index/profile nao.

Report co the de xuat:

- Gather stats.
- Tao index.
- Rewrite SQL.
- Accept SQL Profile.

### 6.3. Khi Nao Accept SQL Profile?

Chi accept khi:

- Da doc report va hieu recommendation.
- Da test tren lab/staging.
- SQL Profile giam elapsed/buffer gets that.
- Khong phai dang che loi data model/query qua te.

Lenh accept neu report de xuat profile:

```sql
EXEC DBMS_SQLTUNE.ACCEPT_SQL_PROFILE(task_name => 'L11_TUNE_TASK', replace => TRUE);
```

Kiem tra SQL Profile:

```sql
SELECT name, category, status, created, last_modified FROM dba_sql_profiles ORDER BY created DESC FETCH FIRST 20 ROWS ONLY;
```

> Can than: SQL Profile khong khoa cung mot plan. No giup optimizer uoc luong tot hon, tu do co the chon plan tot hon.

---

## 7. SQL Plan Baseline

SQL Plan Baseline dung de ngan plan regression: Oracle chi uu tien cac plan da duoc chap nhan.

### 7.1. Load Baseline Tu Cursor Cache

Neu SQL hien dang co plan tot trong shared pool:

```sql
EXEC DBMS_OUTPUT.PUT_LINE(DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(sql_id => '18h6ufv1ttwvw'));
```

Neu muon load dung mot `plan_hash_value`, lab hien tai cua ban la `2428763047`:

```sql
EXEC DBMS_OUTPUT.PUT_LINE(DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(sql_id => '18h6ufv1ttwvw', plan_hash_value => 2428763047));
```

### 7.2. Xem Baseline

```sql
SELECT sql_handle, plan_name, enabled, accepted, fixed, origin, created FROM dba_sql_plan_baselines ORDER BY created DESC FETCH FIRST 20 ROWS ONLY;
```

Cot can nho:

| Cot | Y nghia |
|:---|:---|
| `ENABLED` | Baseline co duoc dung khong |
| `ACCEPTED` | Plan da duoc chap nhan khong |
| `FIXED` | Neu `YES`, Oracle uu tien plan nay manh hon |
| `ORIGIN` | Baseline den tu cursor cache/manual/auto capture |

### 7.3. Drop Baseline Neu Can

Dung can than trong lab. Truoc tien xem `sql_handle` va `plan_name` that:

```sql
SELECT sql_handle, plan_name, enabled, accepted, fixed, origin, created FROM dba_sql_plan_baselines ORDER BY created DESC FETCH FIRST 20 ROWS ONLY;
```

Chi drop khi ban da copy dung `sql_handle` va `plan_name` that tu output tren. Khong paste lenh drop mau voi placeholder.

---

## 8. SQL Profile vs SQL Plan Baseline

| Tieu chi | SQL Profile | SQL Plan Baseline |
|:---|:---|:---|
| Muc dich | Cai thien uoc luong optimizer | On dinh plan, ngan plan regression |
| Co khoa plan khong? | Khong khoa cung | Co gioi han vao accepted plans |
| Tao bang | SQL Tuning Advisor | DBMS_SPM |
| Khi dung | Optimizer doan cardinality sai | SQL co plan tot va muon giu |
| Risk | Co the van doi plan | Co the giu plan cu qua lau neu data doi |

Meo nho:

```text
Profile sua "mat kinh" cho optimizer.
Baseline tao "hang rao" cho plan.
```

---

## 9. Nhanh Free Neu Khong Co Tuning Pack

Neu production khong co Tuning Pack, khong dung SQL Tuning Advisor/Profile. Van co the tune bang:

### 9.1. Xem plan that

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => '18h6ufv1ttwvw', cursor_child_no => NULL, format => 'ALLSTATS LAST +PEEKED_BINDS +PREDICATE'));
```

### 9.2. Kiem tra stats

```sql
SELECT table_name, num_rows, blocks, last_analyzed, stale_stats FROM user_tab_statistics WHERE table_name IN ('ORDERS_DEMO', 'CUSTOMERS_DEMO');
```

### 9.3. Gather stats trong lab

```sql
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS_DEMO', method_opt => 'FOR ALL COLUMNS SIZE SKEWONLY');
```

### 9.4. Kiem tra index

```sql
SELECT index_name, table_name, uniqueness, status, visibility FROM user_indexes WHERE table_name = 'ORDERS_DEMO' ORDER BY index_name;
```

### 9.5. Kiem tra cot index

```sql
SELECT index_name, column_name, column_position FROM user_ind_columns WHERE table_name = 'ORDERS_DEMO' ORDER BY index_name, column_position;
```

### 9.6. Rewrite SQL

Ap dung cac bai truoc:

- Bai 2: stats/histogram.
- Bai 5: composite index dung thu tu.
- Bai 6: tranh index suppress.
- Bai 7: partition/ACS/parallel khi dung workload.
- Bai 8: doc `E-Rows` vs `A-Rows`.

---

## 10. Case Xau De Toi Uu: Index Suppress Tren `total_amount`

Case truoc cua ban qua tot nen SQL Tuning Advisor khong co recommendation. De hoc tuning, can mot case xau co the sua bang tay.

Y tuong:

```text
Sai: total_amount * 1.1 > 1000
Dung: total_amount > 1000 / 1.1
```

Khi dat phep tinh len cot `total_amount`, Oracle kho dung index goc tren `total_amount`. Khi chuyen phep tinh sang ve phai, cot sach lai va index co the duoc dung.

### 10.1. Tao index va gather stats

Chay 2 lenh nay. Neu index da ton tai va bao loi, bo qua.

```sql
CREATE INDEX idx_total_amount ON orders_demo(total_amount);
```

```sql
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS_DEMO', cascade => TRUE);
```

### 10.2. Query xau: phep tinh tren cot

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L11_BAD_INDEX_SUPPRESS */ COUNT(*) FROM orders_demo WHERE total_amount * 1.1 > 1000;
```

Xem plan ngay:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST +PREDICATE'));
```

Tim SQL_ID neu can:

```sql
SELECT sql_id, executions, ROUND(elapsed_time / 1e6, 3) AS total_elapsed_sec, buffer_gets, disk_reads, SUBSTR(sql_text, 1, 120) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L11_BAD_INDEX_SUPPRESS%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Ky vong:

```text
TABLE ACCESS FULL ORDERS_DEMO
Predicate co dang filter("TOTAL_AMOUNT"*1.1>1000)
Buffers cao hon case dung index
```

**Ket qua lab cua ban - query xau:**

```text
SQL_ID          = gyg4fwp4j3ham
Operation       = TABLE ACCESS FULL ORDERS_DEMO
E-Rows          = 5000
Buffers         = 627
Disk reads      = 0
Predicate       = filter("TOTAL_AMOUNT"*1.1>1000)
Elapsed         = 0.013s
```

(Chua chay DISPLAY_CURSOR ALLSTATS LAST, do do chua co A-Rows.)

Ket luan:

- Oracle phai full scan `ORDERS_DEMO`.
- Index `IDX_TOTAL_AMOUNT` khong duoc dung vi cot bi boc trong phep tinh `total_amount * 1.1`.
- `E-Rows = 5000`, `A-Rows = 9001`: optimizer doan thap gan 2 lan.
- `Buffers = 625`: doc nhieu block hon case index range scan du kien.

### 10.2.1. Chay SQL Tuning Advisor Cho Case Xau

Day van la quy trinh muc 6, nhung doi SQL_ID sang case xau:

```text
SQL_ID case xau = gyg4fwp4j3ham
Task name       = L11_BAD_TUNE_TASK
```

Buoc 1: drop task cu neu co. Neu gap `ORA-13605` thi bo qua.

```sql
EXEC DBMS_SQLTUNE.DROP_TUNING_TASK('L11_BAD_TUNE_TASK');
```

Neu gap loi:

```text
ORA-13605: The specified task or object L11_BAD_TUNE_TASK does not exist for the current user.
```

Thi **khong sao**. Nghia la task nay chua ton tai nen khong co gi de drop. Bo qua va chay tiep buoc 2.

Buoc 2: tao tuning task cho SQL xau:

```sql
EXEC DBMS_OUTPUT.PUT_LINE(DBMS_SQLTUNE.CREATE_TUNING_TASK(sql_id => 'gyg4fwp4j3ham', scope => 'COMPREHENSIVE', time_limit => 60, task_name => 'L11_BAD_TUNE_TASK'));
```

Buoc 3: chay task:

```sql
EXEC DBMS_SQLTUNE.EXECUTE_TUNING_TASK('L11_BAD_TUNE_TASK');
```

Buoc 4: format report:

```sql
SET LONG 100000 LONGCHUNKSIZE 100000 PAGESIZE 500 LINESIZE 200
```

Buoc 5: xem report:

```sql
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('L11_BAD_TUNE_TASK', 'TEXT', 'ALL', 'ALL') AS report FROM dual;
```

Can doc trong report:

- Advisor co de xuat index/profile/rewrite khong?
- Plan trong report co `TABLE ACCESS FULL ORDERS_DEMO` khong?
- Predicate co con `TOTAL_AMOUNT*1.1` khong?

Luu y: Advisor co the khong tu noi dung rewrite `total_amount > 1000 / 1.1`. DBA van phai doc plan va biet loi index suppress.

**Raw output lab — toàn bộ session Tuning Advisor:**

```sql
QUERY_TUNING@racdb1[PDB1]> EXEC DBMS_SQLTUNE.DROP_TUNING_TASK('L11_BAD_TUNE_TASK');
BEGIN DBMS_SQLTUNE.DROP_TUNING_TASK('L11_BAD_TUNE_TASK'); END;
*
ERROR at line 1:
ORA-13605: The specified task or object L11_BAD_TUNE_TASK does not exist for the current user.
ORA-06512: at "SYS.PRVT_ADVISOR", line 3062
ORA-06512: at "SYS.DBMS_SYS_ERROR", line 86
ORA-06512: at "SYS.PRVT_ADVISOR", line 7277
ORA-06512: at "SYS.PRVT_ADVISOR", line 3046
ORA-06512: at "SYS.DBMS_ADVISOR", line 193
ORA-06512: at "SYS.DBMS_SQLTUNE", line 1289
ORA-06512: at line 1

QUERY_TUNING@racdb1[PDB1]> EXEC DBMS_OUTPUT.PUT_LINE(DBMS_SQLTUNE.CREATE_TUNING_TASK(sql_id => 'gyg4fwp4j3ham', scope => 'COMPREHENSIVE', time_limit => 60, task_name => 'L11_BAD_TUNE_TASK'));
PL/SQL procedure successfully completed.

QUERY_TUNING@racdb1[PDB1]> EXEC DBMS_SQLTUNE.EXECUTE_TUNING_TASK('L11_BAD_TUNE_TASK');
PL/SQL procedure successfully completed.

QUERY_TUNING@racdb1[PDB1]> SET LONG 100000 LONGCHUNKSIZE 100000 PAGESIZE 500 LINESIZE 200
QUERY_TUNING@racdb1[PDB1]> SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('L11_BAD_TUNE_TASK', 'TEXT', 'ALL', 'ALL') AS report FROM dual;

GENERAL INFORMATION SECTION
-------------------------------------------------------------------------------
Tuning Task Name   : L11_BAD_TUNE_TASK
Tuning Task Owner  : QUERY_TUNING
Tuning Task ID     : 14
Workload Type      : Single SQL Statement
Execution Count    : 1
Current Execution  : EXEC_93
Execution Type     : TUNE SQL
Scope              : COMPREHENSIVE
Time Limit(seconds): 60
Completion Status  : COMPLETED
Started at         : 06/10/2026 15:23:48
Completed at       : 06/10/2026 15:23:48
-------------------------------------------------------------------------------
Schema Name   : QUERY_TUNING
Container Name: PDB1
SQL ID        : gyg4fwp4j3ham
SQL Text      : SELECT /*+ GATHER_PLAN_STATISTICS */ /*
                L11_BAD_INDEX_SUPPRESS */ COUNT(*) FROM orders_demo WHERE
                total_amount * 1.1 > 1000
-------------------------------------------------------------------------------
FINDINGS SECTION (2 findings)
-------------------------------------------------------------------------------
1- Index Finding (see explain plans section below)
   Recommendation (estimated benefit: 88.28%)
   - create index QUERY_TUNING.IDX$$_000E0001 on
     QUERY_TUNING.ORDERS_DEMO("TOTAL_AMOUNT"*1.1);
2- Restructure SQL finding
   The predicate "ORDERS_DEMO"."TOTAL_AMOUNT"*1.1>1000 used at line ID 2 of
   the execution plan contains an expression on indexed column TOTAL_AMOUNT.
   This expression prevents the optimizer from selecting indices.
   Recommendation: rewrite predicate or create function-based index.
-------------------------------------------------------------------------------
EXPLAIN PLANS SECTION
-------------------------------------------------------------------------------

1- Original
-----------
Plan hash value: 3210487600

----------------------------------------------------------------------------------
| Id  | Operation          | Name        | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------
|   0 | SELECT STATEMENT   |             |     1 |     4 |   171   (1)| 00:00:01 |
|   1 |  SORT AGGREGATE    |             |     1 |     4 |            |          |
|*  2 |   TABLE ACCESS FULL| ORDERS_DEMO |  5000 | 20000 |   171   (1)| 00:00:01 |
----------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------
   2 - filter("TOTAL_AMOUNT"*1.1>1000)

2- Using New Indices
--------------------
Plan hash value: 3255269567

------------------------------------------------------------------------------------
| Id  | Operation         | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |                |     1 |     4 |    20   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE   |                |     1 |     4 |            |          |
|*  2 |   INDEX RANGE SCAN| IDX$$_000E0001 |  5000 | 20000 |    20   (0)| 00:00:01 |
------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------
   2 - access("ORDERS_DEMO"."SYS_QSMMIX_VCOL_5001">1000)
```

**Luu y:**
- `ORA-13605` khi drop task khong ton tai la binh thuong, bo qua.
- Advisor phat hien **index suppress** va de xuat 2 huong: FBI hoac rewrite.

**Giai thich ket qua Advisor:**

- Advisor da chay thanh cong: `Completion Status = COMPLETED`.
- Advisor tim thay 2 findings:
  - `Index Finding`: de xuat function-based index tren bieu thuc `"TOTAL_AMOUNT"*1.1`.
  - `Restructure SQL finding`: noi thang rang predicate co expression tren indexed column `TOTAL_AMOUNT`, lam optimizer khong chon duoc index.
- Estimated benefit `88.28%`: plan moi co cost `20`, trong khi plan cu cost `171`.
- Plan cu: `TABLE ACCESS FULL ORDERS_DEMO`.
- Plan de xuat: `INDEX RANGE SCAN IDX$$_000E0001`.
- DBA nen uu tien rewrite SQL truoc: `total_amount > 1000 / 1.1`. Chi tao function-based index neu khong sua duoc SQL tu application.

**Lenh xem index cua bang:**

Xem danh sach index tren `ORDERS_DEMO`:

```sql
SELECT index_name, table_name, uniqueness, status, visibility FROM user_indexes WHERE table_name = 'ORDERS_DEMO' ORDER BY index_name;
```

**Ket qua lab cua ban:**

```text
INDEX_NAME                 TABLE_NAME    UNIQUENESS   STATUS   VISIBILITY
IDX_FBI_TRUNC_ORDER_DATE   ORDERS_DEMO   NONUNIQUE    VALID    VISIBLE
IDX_GOOD_ORDER             ORDERS_DEMO   NONUNIQUE    VALID    VISIBLE
IDX_ORDERS_STATUS          ORDERS_DEMO   NONUNIQUE    VALID    VISIBLE
IDX_ORDER_DATE             ORDERS_DEMO   NONUNIQUE    VALID    VISIBLE
IDX_TOTAL_AMOUNT           ORDERS_DEMO   NONUNIQUE    VALID    VISIBLE
SYS_C007627                ORDERS_DEMO   UNIQUE       VALID    VISIBLE
```

Giai thich:

- `IDX_TOTAL_AMOUNT` da ton tai, nhung query xau van full scan vi predicate la `total_amount * 1.1 > 1000`.
- B-tree index thuong tren `total_amount` chi giup tot khi cot dung "sach", vi du `total_amount > 1000 / 1.1`.
- Advisor de xuat function-based index moi tren expression `"TOTAL_AMOUNT"*1.1`, nhung ta nen rewrite SQL truoc de tan dung `IDX_TOTAL_AMOUNT` san co.
- `SYS_C007627` la index unique do primary key/constraint tao ra.

Xem cac cot trong index:

```sql
SELECT index_name, column_name, column_position FROM user_ind_columns WHERE table_name = 'ORDERS_DEMO' ORDER BY index_name, column_position;
```

Xem function-based index expression neu co:

```sql
SELECT index_name, column_expression, column_position FROM user_ind_expressions WHERE table_name = 'ORDERS_DEMO' ORDER BY index_name, column_position;
```

### 10.3. Query da toi uu: cot sach, phep tinh sang ve phai

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L11_GOOD_INDEX_RANGE */ COUNT(*) FROM orders_demo WHERE total_amount > 1000 / 1.1;
```

Xem plan ngay:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST +PREDICATE'));
```

Tim SQL_ID neu can:

```sql
SELECT sql_id, executions, ROUND(elapsed_time / 1e6, 3) AS total_elapsed_sec, buffer_gets, disk_reads, SUBSTR(sql_text, 1, 120) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L11_GOOD_INDEX_RANGE%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Ky vong:

```text
INDEX RANGE SCAN IDX_TOTAL_AMOUNT
Predicate co dang access("TOTAL_AMOUNT">909.09...)
Buffers thap hon query xau
```

### 10.4. Cach ket luan

| Ban | Dau hieu | Ket luan |
|:---|:---|:---|
| Query xau | `TABLE ACCESS FULL`, predicate co phep tinh tren cot | Index bi suppress |
| Query tot | `INDEX RANGE SCAN IDX_TOTAL_AMOUNT` | Rewrite giup Oracle dung index |

Day la case xau phu hop de hoc bai 11 hon query `order_status='CANCELLED'`, vi query status hien da toi uu san.

---

## 11. Gia Lap Plan Regression: Hom Qua Tot, Hom Nay Te

Muc tieu: tao tinh huong cung mot kieu query, nhung moi truong index thay doi lam plan doi tu index scan sang full scan.

### 11.1. Hom qua tot: index visible

Bat index:

```sql
ALTER INDEX idx_total_amount VISIBLE;
```

Chay query tot:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L11_YESTERDAY_GOOD */ COUNT(*) FROM orders_demo WHERE total_amount > 1000 / 1.1;
```

Tim SQL_ID:

```sql
SELECT sql_id, executions, plan_hash_value, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, buffer_gets, disk_reads, SUBSTR(sql_text, 1, 120) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L11_YESTERDAY_GOOD%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

**Ket qua lab cua ban:**

```text
SQL_ID          = 33bf33ab6vg2w
PLAN_HASH_VALUE = 865561492
ELAPSED_SEC     = 0.002
BUFFER_GETS     = 21
DISK_READS      = 0
SQL_PREVIEW     = SELECT /*+ GATHER_PLAN_STATISTICS */ /* L11_YESTERDAY_GOOD */ COUNT(*) FROM orders_demo WHERE total_amount > 1000 / 1.1
```

Ket luan "hom qua":

- Index `IDX_TOTAL_AMOUNT` dang `VISIBLE`.
- Query dung plan hash `865561492`.
- `BUFFER_GETS = 21`, `DISK_READS = 0`, `ELAPSED = 0.002s`: rat tot.
- Day la baseline tot de so sanh.

Xem plan ngay sau query. Cach nay khong can SQL_ID:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST +PREDICATE'));
```

Neu da lo chay cau khac sau query, dung SQL_ID that:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => '33bf33ab6vg2w', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE'));
```

Ky vong:

```text
INDEX RANGE SCAN IDX_TOTAL_AMOUNT
Buffers thap
```

### 11.2. Hom nay te: index invisible

An index:

```sql
ALTER INDEX idx_total_amount INVISIBLE;
```

Chay lai query logic tuong duong voi marker khac:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L11_TODAY_BAD */ COUNT(*) FROM orders_demo WHERE total_amount > 1000 / 1.1;
```

Tim SQL_ID:

```sql
SELECT sql_id, executions, plan_hash_value, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, buffer_gets, disk_reads, SUBSTR(sql_text, 1, 120) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L11_TODAY_BAD%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Xem plan ngay sau query. Cach nay khong can SQL_ID:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(FORMAT => 'ALLSTATS LAST +PREDICATE'));
```

Ky vong:

```text
TABLE ACCESS FULL ORDERS_DEMO
Buffers cao hon
Plan hash value khac
```

**Ket qua lab cua ban:**

```text
SQL_ID          = 554syz0tb0ykm
PLAN_HASH_VALUE = 3210487600
Operation       = TABLE ACCESS FULL ORDERS_DEMO
E-Rows          = 9000
A-Rows          = 9001
Buffers         = 625
Reads           = 623
Predicate       = filter("TOTAL_AMOUNT">909.090909090909...)
```

Ket luan "hom nay":

- Index `IDX_TOTAL_AMOUNT` bi `INVISIBLE`.
- Cung logic filter nhung Oracle khong con dung index duoc.
- Plan doi tu `865561492` sang `3210487600`.
- Buffers tang tu `21` len `625`.
- Physical reads tang tu `0` len `623`.
- Day la plan regression gia lap thanh cong.

### 11.3. Khoi phuc index

Bat lai index:

```sql
ALTER INDEX idx_total_amount VISIBLE;
```

### 11.4. So sanh 2 lan chay

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 120) AS sql_preview FROM v$sqlarea WHERE (sql_text LIKE '%L11_YESTERDAY_GOOD%' OR sql_text LIKE '%L11_TODAY_BAD%') AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Luu y: phai co ngoac quanh dieu kien `OR`. Neu viet:

```sql
WHERE sql_text LIKE '%L11_YESTERDAY_GOOD%' OR sql_text LIKE '%L11_TODAY_BAD%' AND sql_text NOT LIKE '%v$sqlarea%'
```

thi Oracle se uu tien `AND` truoc, lam query so sanh co the tu keo chinh no vao output.

**Ket qua lab cua ban sau khi so sanh:**

```text
Case              SQL_ID         PLAN_HASH    BUFFER_GETS  DISK_READS  ELAPSED
Hom qua tot       33bf33ab6vg2w  865561492            21           0    0.002
Hom nay te        554syz0tb0ykm  3210487600          719         623    0.072
```

Doc ket qua:

- `PLAN_HASH_VALUE` khac nhau: optimizer da chon plan khac.
- `BUFFER_GETS` tang khoang 34 lan: `719 / 21`.
- `DISK_READS` tu `0` thanh `623`: plan moi doc disk.
- `ELAPSED` tang tu `0.002s` len `0.072s`: tren bang 100K dong da thay ro, production bang lon se nang hon nhieu.

Ket luan:

```text
Hom qua: index visible -> INDEX RANGE SCAN -> tot.
Hom nay: index invisible -> TABLE ACCESS FULL -> te.
```

Day la mo phong plan regression: khong can doi data nhieu, chi can index/statistics/environment doi la plan co the doi.

---

## 12. Bai Tap Thuc Hanh

### Bai 1: Tim SQL_ID

```sql
SELECT /* L11_PLAN_TEST */ * FROM orders_demo WHERE order_status = 'CANCELLED';
```

```sql
SELECT sql_id, executions, plan_hash_value, SUBSTR(sql_text, 1, 120) AS sql_preview FROM v$sql WHERE sql_text LIKE '%L11_PLAN_TEST%' AND sql_text NOT LIKE '%v$sql%' ORDER BY last_active_time DESC;
```

### Bai 2: Xem plan

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => '18h6ufv1ttwvw', cursor_child_no => NULL, format => 'ALLSTATS LAST +PEEKED_BINDS +PREDICATE'));
```

### Bai 3: Chay SQL Tuning Advisor trong lab

```sql
EXEC DBMS_OUTPUT.PUT_LINE(DBMS_SQLTUNE.CREATE_TUNING_TASK(sql_id => '18h6ufv1ttwvw', scope => 'COMPREHENSIVE', time_limit => 60, task_name => 'L11_TUNE_TASK'));
EXEC DBMS_SQLTUNE.EXECUTE_TUNING_TASK('L11_TUNE_TASK');
```

```sql
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('L11_TUNE_TASK') AS report FROM dual;
```

```
GENERAL INFORMATION
 SQL ID        : gyg4fwp4j3ham
 SQL Text      : SELECT /*+ GATHER_PLAN_STATISTICS */ /* L11_BAD_INDEX_SUPPRESS */
                 COUNT(*) FROM orders_demo WHERE total_amount * 1.1 > 1000

FINDINGS (2 findings)

1- Index Finding (estimated benefit: 88.28%)
   create index on QUERY_TUNING.ORDERS_DEMO("TOTAL_AMOUNT"*1.1);

2- Restructure SQL finding
   Predicate "TOTAL_AMOUNT"*1.1>1000 contains expression on indexed column.
   Rewrite predicate or create function-based index.

EXPLAIN PLANS
  Original (FTS):      Cost 171    TABLE ACCESS FULL
  With new index:      Cost  20    INDEX RANGE SCAN
```

**Cach doc:**
- Finding 1: Advisor de xuat tao index tren bieu thuc. **Giong function-based index** (Bai 6).
- Finding 2: Phat hien **index suppress** — bieu thuc `total_amount * 1.1` lam mat index, de nghi rewrite sang `total_amount > 1000 / 1.1`.
- Benefit uoc luong: 88.28% (Cost 171 → 20).

### Bai 4: Load baseline trong lab

```sql
EXEC DBMS_OUTPUT.PUT_LINE(DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(sql_id => '18h6ufv1ttwvw'));
```

```sql
SELECT sql_handle, plan_name, enabled, accepted, fixed, origin, created FROM dba_sql_plan_baselines ORDER BY created DESC FETCH FIRST 20 ROWS ONLY;
```

---

## Checklist Ket Thuc Bai 11

- `plan_hash_value` dung de lam gi?
- SQL co nhieu child cursor co nghia gi?
- SQL Profile khac SQL Plan Baseline o dau?
- Khi nao nen accept SQL Profile?
- Khi nao nen tao SQL Plan Baseline?
- Neu production khong co Tuning Pack thi tune bang cach nao?

---

## Tong Ket Bai 11

| Van de | Cong cu |
|:---|:---|
| Tim SQL cham | `v$sqlarea`, `v$sql` |
| Xem plan that | `DBMS_XPLAN.DISPLAY_CURSOR` |
| Tu dong de xuat fix | SQL Tuning Advisor |
| Cai thien cardinality estimate | SQL Profile |
| Ngan plan regression | SQL Plan Baseline / DBMS_SPM |
| Nhanh free khong Tuning Pack | stats, index, rewrite SQL, `DISPLAY_CURSOR` |

**Bài tiếp theo:** [Lesson 12: Optimizer Algorithms](12_optimizer_algorithms.md) — học thuật toán Oracle dùng để chọn access path, join method, group/sort và vì sao plan regression xảy ra.
