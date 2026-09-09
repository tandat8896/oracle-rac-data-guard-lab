# Lesson 12: Optimizer Algorithms — Vi Sao Oracle Chon Plan Nay?

Bai 11 da cho thay:

```text
Index visible   -> INDEX RANGE SCAN -> nhanh
Index invisible -> TABLE ACCESS FULL -> cham
```

Bai 12 hoc phan "thuat toan" phia sau: Oracle nghi gi khi chon `INDEX RANGE SCAN`, `TABLE ACCESS FULL`, `NESTED LOOPS`, `HASH JOIN`, `HASH GROUP BY`, `SORT GROUP BY`.

> Muc tieu cua bai nay: truoc khi xem plan, ban tap doan Oracle se chon gi va vi sao.

---

## 0. Bai Tap Dat Len Dau: Hoc Thuat Toan Bang Plan

Day la phan quan trong nhat. Bai 12 khong lap lai case "index mat", "viet sai mat index", "blocking" nua. O day minh tap nhin Oracle dang chon **thuat toan nao** va thuat toan do ton tai sao.

Quy tac khi chay:

```sql
SET LINESIZE 220 PAGESIZE 200
```

Sau moi query co marker `L12_...`, neu muon xem dung plan vua chay thi dung SQL_ID ro rang, dung `DISPLAY_CURSOR()` khong truyen SQL_ID chi khi ban chua chay them lenh nao khac.

Tim SQL_ID theo marker:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 140) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L12_%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Xem plan theo SQL_ID that:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'SQL_ID_THAT', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE +NOTE'));
```

> Khi ban co SQL_ID that, thay `SQL_ID_THAT` roi chay. Dung de placeholder trong SQLcl.

---

### Case 1: Covering Index Hay Table Rowid Lookup?

**Tinh huong production:** query count theo status rat nhanh, nhung doi thanh tinh tong tien theo status thi cham hon. Ly do khong phai WHERE doi, ma la cot can doc khac nhau.

Oracle co 2 cach doc bang/index:

```text
INDEX RANGE SCAN only          -> index da du cot can tra loi
INDEX RANGE SCAN + TABLE ROWID -> index loc duoc row, nhung phai quay lai table lay cot khac
```

Dam bao stats:

```sql
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS_DEMO', cascade => TRUE);
```

Query A: index `IDX_ORDERS_STATUS` du de dem row.

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L12_COVERING_COUNT */ COUNT(*) FROM orders_demo WHERE order_status = 'CANCELLED';
```

Tim SQL_ID:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 140) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L12_COVERING_COUNT%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Xem plan, thay SQL_ID that vao:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => '5hj08fru2samk', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE +NOTE'));
```

Query B: cung filter, nhung can doc `total_amount`, index status khong du cot.

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L12_ROWID_LOOKUP_SUM */ SUM(total_amount) FROM orders_demo WHERE order_status = 'CANCELLED';
```

Tim SQL_ID:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 140) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L12_ROWID_LOOKUP_SUM%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Xem plan theo SQL_ID that:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'SQL_ID_THAT', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE +NOTE'));
```

So sanh:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 140) AS sql_preview FROM v$sqlarea WHERE (sql_text LIKE '%L12_COVERING_COUNT%' OR sql_text LIKE '%L12_ROWID_LOOKUP_SUM%') AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

**Can nhin:**

| Dau hieu | Y nghia |
|:---|:---|
| Chi co `INDEX RANGE SCAN` | Index da du de tra loi |
| Co `TABLE ACCESS BY INDEX ROWID` | Oracle phai quay ve table lay cot khac |
| `Buffers` cua query B cao hon | Rowid lookup ton them logical I/O |

**Ket qua lab that:**

Query A — `COUNT(*)` (chi can index):
```
Plan hash value: 2428763047

| Id  | Operation         | Name              | E-Rows | A-Rows | Buffers |
|     | INDEX RANGE SCAN  | IDX_ORDERS_STATUS |  10000 |  10000 |      31 |

Buffers = 31, Elapsed = 0.003s
```

Query B — `SUM(total_amount)` (can rowid ve table):
```
Plan hash value: 3862084843

| Id  | Operation                            | Name              | E-Rows | A-Rows | Buffers |
|     | TABLE ACCESS BY INDEX ROWID BATCHED  | ORDERS_DEMO       |  10000 |  10000 |     649 |
|     |  INDEX RANGE SCAN                    | IDX_ORDERS_STATUS |  10000 |  10000 |      31 |

Buffers = 649, Elapsed = 0.118s
```

So sanh: query B ton **gap 20 lan** buffers (649 vs 31) va cham **gap 39 lan** (0.118s vs 0.003s) vi phai doc them 618 block tu table de lay `total_amount`. Index co `order_status` nhung thieu `total_amount` → khong the covering.

**Muc tieu hoc:** index khong chi de loc row. Neu index bao phu du cot can tra loi, Oracle co the khong can doc table.

---

### Case 2: Cung Mot Predicate, Ep INDEX Va Ep FULL De Thay Cost Trade-off

**Tinh huong production:** DBA va developer cai nhau: "co index thi phai dung index" hay "full scan moi dung". Bai nay cho Oracle chay ca 2 thuat toan de so bang metric.

Dam bao index visible:

```sql
ALTER INDEX idx_total_amount VISIBLE;
```

Ep index range scan:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS INDEX(orders_demo idx_total_amount) */ /* L12_FORCE_INDEX */ COUNT(*) FROM orders_demo WHERE total_amount > 1000 / 1.1;
```

Tim SQL_ID:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 140) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L12_FORCE_INDEX%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Ep full table scan:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS FULL(orders_demo) */ /* L12_FORCE_FULL */ COUNT(*) FROM orders_demo WHERE total_amount > 1000 / 1.1;
```

Tim SQL_ID:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 140) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L12_FORCE_FULL%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

So sanh 2 thuat toan:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 140) AS sql_preview FROM v$sqlarea WHERE (sql_text LIKE '%L12_FORCE_INDEX%' OR sql_text LIKE '%L12_FORCE_FULL%') AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Xem plan theo SQL_ID that cua tung query:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'SQL_ID_THAT', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE +NOTE'));
```

**Can nhin:**

| Dau hieu | Y nghia |
|:---|:---|
| `INDEX RANGE SCAN IDX_TOTAL_AMOUNT` | Doc theo index |
| `TABLE ACCESS FULL ORDERS_DEMO` | Quet bang |
| Query tra 9001/100000 row | Selectivity khoang 9%, index thuong co loi |
| Neu full scan buffers/read cao hon | Full scan doc nhieu block hon |

**Ket qua lab that:**

FORCE_INDEX — `IDX_TOTAL_AMOUNT` (index-only scan, vi `COUNT(*)` khong can cot khac):
```
Plan hash value: 865561492

| Id  | Operation         | Name             | E-Rows | A-Rows | Buffers | Reads |
|     | INDEX RANGE SCAN  | IDX_TOTAL_AMOUNT |   9000 |   9001 |      21 |    24 |

Buffers = 21, Elapsed = 0.05s
```

FORCE_FULL — quet toan bo table:
```
Plan hash value: 3210487600

| Id  | Operation          | Name        | E-Rows | A-Rows | Buffers | Reads |
|     | TABLE ACCESS FULL  | ORDERS_DEMO |   9000 |   9001 |     625 |   623 |

Buffers = 625, Elapsed = 0.076s
```

So sanh:

| Metric | FORCE_INDEX | FORCE_FULL |
|:---|---:|---:|
| Buffers | **21** | 625 |
| Reads | **24** | 623 |
| Elapsed | **0.05s** | 0.076s |

Index thang: buffers = 21 vs 625 (**30x** it hon). Ly do `IDX_TOTAL_AMOUNT` chi co 1 cot + rowid, `COUNT(*)` khong can table → index-only scan. Full table quet 625 blocks du 9000 rows thi doc nguyen table.

**Muc tieu hoc:** optimizer khong ton tho index. No so sanh chi phi giua access path. Hint chi de lab, production khong nen lam mac dinh.

---

### Case 3: Ep Nested Loops Va Hash Join Tren Cung Mot Query

**Tinh huong production:** mot man hinh tim khach VIP join sang orders. Neu tap outer nho, Nested Loops co the tot. Neu tap outer lon, Hash Join thuong tot hon. Bai nay ep ca 2 de thay thuat toan.

Dam bao index tren cot join. Lenh nay chay lai nhieu lan duoc, neu index da ton tai thi bo qua `ORA-00955`:

```sql
BEGIN EXECUTE IMMEDIATE 'CREATE INDEX idx_orders_customer ON orders_demo(customer_id)'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -955 THEN RAISE; END IF; END;
```

Gather stats:

```sql
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'CUSTOMERS_DEMO', cascade => TRUE);
```

```sql
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS_DEMO', cascade => TRUE);
```

Ep Nested Loops:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS LEADING(c) USE_NL(o) INDEX(o idx_orders_customer) */ /* L12_FORCE_NL_JOIN */ COUNT(*) FROM customers_demo c JOIN orders_demo o ON o.customer_id = c.customer_id WHERE c.membership_lvl = 'PLATINUM';
```

Tim SQL_ID:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 140) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L12_FORCE_NL_JOIN%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Ep Hash Join:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS LEADING(c o) USE_HASH(o) FULL(o) */ /* L12_FORCE_HASH_JOIN */ COUNT(*) FROM customers_demo c JOIN orders_demo o ON o.customer_id = c.customer_id WHERE c.membership_lvl = 'PLATINUM';
```

Tim SQL_ID:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 140) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L12_FORCE_HASH_JOIN%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

So sanh:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 140) AS sql_preview FROM v$sqlarea WHERE (sql_text LIKE '%L12_FORCE_NL_JOIN%' OR sql_text LIKE '%L12_FORCE_HASH_JOIN%') AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Xem plan theo SQL_ID that:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'gzqs05anmqj6j', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE +NOTE'));
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => '4tm47d5amtdd7', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE +NOTE'));
```

**Can nhin:**

| Dau hieu | Y nghia |
|:---|:---|
| `NESTED LOOPS` | Voi moi row outer, lookup inner |
| `HASH JOIN` | Build hash table mot ben, scan/probe ben kia |
| `Starts` cua inner index trong NL cao | Inner bi goi lap lai nhieu lan |
| Full scan trong hash join | Hash join thuong doc tap lon theo scan |

**Ket qua lab that:**

FORCE_NL_JOIN — Nested Loops:
```
Plan hash value: 692863948

| Id  | Operation           | Name                | E-Rows | A-Rows | Starts | Buffers |
|     | NESTED LOOPS        |                     |   1000 |   1000 |      1 |      79 |
|     |  TABLE ACCESS FULL  | CUSTOMERS_DEMO      |     50 |     50 |      1 |      25 |
|     |  INDEX RANGE SCAN   | IDX_ORDERS_CUSTOMER |     20 |   1000 |     50 |      54 |

Starts = 50: inner index bi goi 50 lan (1 lan cho moi PLATINUM customer)
Buffers = 79 (25 full scan customers + 54 index range scan * 50 lan)
Elapsed = 0.004s
```

FORCE_HASH_JOIN — Hash Join:
```
Plan hash value: 1584104678

| Id  | Operation           | Name           | E-Rows | A-Rows | Starts | Buffers | Used-Mem |
|     | HASH JOIN           |                |   1000 |   1000 |      1 |     653 |   1676K  |
|     |  TABLE ACCESS FULL  | CUSTOMERS_DEMO |     50 |     50 |      1 |      25 |          |
|     |  TABLE ACCESS FULL  | ORDERS_DEMO    |    100K|    100K|      1 |     625 |          |

Starts = 1: hash build 1 lan, probe 1 lan
Buffers = 653 (25 customers + 625 orders)
Used-Mem = 1676K (hash table trong PGA)
Elapsed = 0.018s
```

So sanh:

| Metric | Nested Loops | Hash Join |
|:---|---:|---:|
| Buffers | **79** | 653 |
| Starts inner | **50** | 1 |
| Elapsed | **0.004s** | 0.018s |
| Memory | PGA (small) | 1676K PGA |

NL nhanh hon vi:
- Outer table chi 50 rows PLATINUM (selectivity 50/100000)
- Moi row lookup index `IDX_ORDERS_CUSTOMER` → chi doc 1-2 leaf blocks
- Hash Join phai doc toan bo ORDERS_DEMO (625 blocks) + build hash table trong memory

**Y nghia cua cac hint:**
- `LEADING(c)` — bao Oracle doc `customers_demo` truoc (driving table)
- `USE_NL(o)` — ep Nested Loops join voi `orders_demo` la inner
- `INDEX(o idx_orders_customer)` — ep dung index tren `customer_id`
- `USE_HASH(o)` — ep Hash Join
- `FULL(o)` — ep full scan `orders_demo` (hash join can quet full)

**Neu nguoc lai:** Neu khong co filter `c.membership_lvl='PLATINUM'`, outer = 100000 customers → NL phai loop 100000 lan → Hash Join se thang.

**Muc tieu hoc:** Nested Loops tot khi outer nho va inner co index tot. Hash Join tot khi join tap lon, can scan/set processing.

---

### Case 4: Hash Group By, Sort Group By, Va Gia Cua ORDER BY

**Tinh huong production:** report group by chay nhanh, nhung them sort/export theo thu tu thi ton them buoc sort. Bai nay nhin thuat toan aggregate.

Query group by binh thuong:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L12_GROUP_ONLY */ order_status, COUNT(*) FROM orders_demo GROUP BY order_status;
```

Tim SQL_ID:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 140) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L12_GROUP_ONLY%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Query group by kem order by:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L12_GROUP_ORDER */ order_status, COUNT(*) FROM orders_demo GROUP BY order_status ORDER BY order_status;
```

Tim SQL_ID:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 140) AS sql_preview FROM v$sqlarea WHERE sql_text LIKE '%L12_GROUP_ORDER%' AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

So sanh:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, ROUND(elapsed_time / 1e6, 3) AS elapsed_sec, SUBSTR(sql_text, 1, 140) AS sql_preview FROM v$sqlarea WHERE (sql_text LIKE '%L12_GROUP_ONLY%' OR sql_text LIKE '%L12_GROUP_ORDER%') AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time DESC;
```

Xem plan theo SQL_ID that:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'SQL_ID_THAT', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE +NOTE'));
```

**Can nhin:**

| Dau hieu | Y nghia |
|:---|:---|
| `HASH GROUP BY` | Gom nhom bang hash table trong memory |
| `SORT GROUP BY` | Sort roi gom nhom |
| `SORT ORDER BY` | Buoc sort them de tra ket qua co thu tu |
| `TempSpc` neu co | Sort/hash tran ra temp |

**Muc tieu hoc:** `GROUP BY` la aggregate algorithm. `ORDER BY` la yeu cau sap xep output, co the them chi phi rieng.

---

## 1. Thuat Toan Tong Quan Cua Cost-Based Optimizer

Oracle CBO khong "doan mo". No lam theo pipeline:

```text
1. Parse SQL
2. Rewrite/transform query
3. Estimate cardinality/selectivity
4. Generate candidate plans
5. Estimate cost cho tung plan
6. Chon plan cost thap nhat
7. Execute va luu cursor trong shared pool
```

Cost la mo hinh uoc luong, khong phai thoi gian that:

```text
Cost = I/O cost + CPU cost + memory/temp penalty
```

Neu stats sai, cost sai. Neu cost sai, plan sai.

---

## 2. Cardinality Estimation — Thuat Toan Doan So Dong

Cardinality la so dong Oracle du doan moi buoc se tra ve.

Trong plan:

```text
E-Rows = estimated rows
A-Rows = actual rows
```

Neu `E-Rows` lech `A-Rows` nhieu, optimizer co kha nang chon sai:

```text
E-Rows 10, A-Rows 100000 -> Oracle nghi tap nho, co the chon Nested Loops sai
E-Rows 90000, A-Rows 10 -> Oracle nghi tap lon, co the bo index sai
```

Cong thuc don gian:

```text
estimated rows = table rows * selectivity
```

Vi du:

```text
ORDERS_DEMO = 100000 rows
CANCELLED = 10000 rows
selectivity = 10000 / 100000 = 10%
```

---

## 3. Selectivity — Khi Nao Index Dang Gia?

Selectivity la ti le row duoc tra ve.

```text
selectivity thap -> tra ve it row -> index co loi
selectivity cao  -> tra ve nhieu row -> full scan co the tot hon
```

Quy tac thuc chien:

| Selectivity | Thuong hop |
|:---|:---|
| < 1% | Index rat dang gia |
| 1% - 10% | Index thuong tot, tuy clustering factor |
| 10% - 30% | Can do `Buffers`, co the index hoac full scan |
| > 30% | Full scan co the dung hon |

Khong co nguong tuyet doi. Phai do bang `ALLSTATS LAST`.

---

## 4. Access Path Algorithm

Oracle chon cach vao data dua tren:

```text
predicate + stats + index + clustering factor + cost
```

| Access path | Khi nao hay duoc chon |
|:---|:---|
| `TABLE ACCESS FULL` | Can doc nhieu row/block, index khong loi |
| `INDEX UNIQUE SCAN` | Predicate tren unique/PK, tra 1 row |
| `INDEX RANGE SCAN` | Predicate range/equality tra it row |
| `INDEX FAST FULL SCAN` | Doc ca index nhu table nho, query can cot trong index |
| `TABLE ACCESS BY INDEX ROWID` | Lay row tu table sau khi tim rowid trong index |

Case 1 minh hoa:

```text
Index visible   -> candidate INDEX RANGE SCAN ton tai -> cost thap
Index invisible -> candidate index bi loai -> TABLE ACCESS FULL thang
```

Case 2 minh hoa:

```text
total_amount * 1.1 > 1000 -> expression tren cot -> index thuong bi suppress
total_amount > 1000 / 1.1 -> cot sach -> index range scan
```

---

## 5. Join Algorithm

Oracle chon join method dua tren kich thuoc 2 tap row va index.

### Nested Loops

Mo hinh:

```text
For each row in outer:
  probe inner by index
```

Tot khi:

- Outer rowset nho.
- Inner table co index tot tren join key.
- OLTP lookup.

Te khi:

- Outer rowset lon.
- Inner lookup lap lai qua nhieu lan.
- `Starts` cua inner step rat cao.

### Hash Join

Mo hinh:

```text
Build hash table tu tap nho
Probe bang tap lon
```

Tot khi:

- Join tap lon.
- Khong co index selective.
- Workload OLAP/report.

Can coi:

- PGA co du khong.
- Co spill temp khong.
- `Buffers` va `TempSpc`.

### Sort Merge Join

Mo hinh:

```text
Sort 2 input theo join key
Merge 2 stream da sort
```

Hay gap khi:

- Inputs da sorted.
- Range join.
- Hash join khong phu hop.
- Sort spill neu PGA thieu.

---

## 6. Group By / Sort Algorithm

Oracle co the dung:

| Operation | Khi nao |
|:---|:---|
| `HASH GROUP BY` | Group many rows, hash vua PGA |
| `SORT GROUP BY` | Can sort, ORDER BY lien quan, hoac hash khong loi |
| `SORT ORDER BY` | Can sap xep output |

Neu PGA thieu:

```text
SORT/HASH -> spill TEMP -> cham
```

Can nhin:

- `TempSpc`
- `Used-Mem`
- `OMem`, `1Mem`
- wait event temp I/O

---

## 7. Plan Regression Algorithm

Plan regression xay ra khi SQL doi plan theo huong xau.

Nguyen nhan hay gap:

| Thay doi | Tac dong |
|:---|:---|
| Index invisible/drop | Access path index bien mat |
| Stats stale/missing | Cardinality sai |
| Histogram bi mat | Data skew khong duoc nhan ra |
| Bind peeking | Plan hop gia tri nay, te cho gia tri kia |
| Parameter/session setting doi | Optimizer search space doi |
| Data volume tang | Cost index/full scan doi |

Case 1 cua bai nay la regression co chu dich:

```text
idx_total_amount visible   -> plan tot
idx_total_amount invisible -> plan te
```

---

## 8. Checklist Doc Plan Theo Thuat Toan

Khi nhin mot plan, hoi theo thu tu:

1. Query tra bao nhieu row? (`A-Rows`)
2. Oracle doan bao nhieu row? (`E-Rows`)
3. Sai lech bao nhieu lan?
4. Predicate la `access` hay `filter`?
5. Access path co dung voi selectivity khong?
6. Join method co dung voi kich thuoc rowset khong?
7. `Buffers` cao o buoc nao?
8. Co `Reads`/TEMP khong?
9. Plan hash co doi so voi lan tot khong?
10. Root cause la stats, index, SQL shape, bind, hay memory?

---

## 9. Tong Ket Bai 12

| Thuat toan | Cau hoi chinh |
|:---|:---|
| Cardinality estimation | Oracle doan bao nhieu row? |
| Selectivity | Predicate tra it hay nhieu row? |
| Access path | Full scan hay index scan re hon? |
| Join method | Nested Loops, Hash Join, hay Sort Merge? |
| Group/sort | Hash hay sort, co spill TEMP khong? |
| Plan regression | Plan hash doi vi sao? |

Bai 13 nen di tiep sang **Statistics Maintenance & Histogram Strategy**: lam sao gather stats dung, giu histogram dung, va tranh auto stats lam doi plan ngoai y muon.
