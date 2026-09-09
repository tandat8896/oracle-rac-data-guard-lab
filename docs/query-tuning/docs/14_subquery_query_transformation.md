# Lesson 14: Subquery Va Query Transformation

Bai nay quay lai query tuning thuan SQL:

```text
NOT IN / NOT EXISTS
EXISTS / JOIN DISTINCT
Correlated scalar subquery
```

Muc tieu khong phai hoc cu phap. Muc tieu la nhin SQL duoc viet mot kieu, nhung Oracle co the bien doi thanh `SEMI JOIN`, `ANTI JOIN`, view merge, subquery unnest hoac temporary table transformation.

---

## 0. Bai Tap Thuc Te Dat Len Dau

Lab chay tren:

```text
DB_UNIQUE_NAME = racdb
DATABASE_ROLE  = PRIMARY
INSTANCE_NAME  = racdb1
PDB            = PDB1
USER           = QUERY_TUNING
```

Khong thay doi parameter, memory, index hay du lieu. Tat ca cau SQL chinh deu viet mot dong de paste trong SQLcl.

### Cach Hoc

Moi case gom hai phan:

```text
DE BAI   -> tu viet query va chay thu
LOI GIAI -> doi chieu ket qua, SQL_ID va execution plan
```

Dung mo phan loi giai ngay. Hay tu viet query truoc, ke ca khi query dau tien chua toi uu.

### Buoc 1: Xac Nhan Du Lieu

```sql
SELECT COUNT(*) AS customers FROM customers_demo;
```

```sql
SELECT order_status, COUNT(*) AS orders FROM orders_demo GROUP BY order_status ORDER BY order_status;
```

Ket qua du kien cua lab hien tai:

```text
CUSTOMERS_DEMO = 5000 rows
CANCELLED      = 10000 rows
COMPLETED      = 90000 rows
```

---

## Phan A: Tinh Huong Tu Viet Query

### Ticket 1: Chien Dich Cham Soc Khach Hang

Phong marketing can danh sach customer **chua tung co order bi huy**.

Yeu cau:

```text
Input:
  CUSTOMERS_DEMO
  ORDERS_DEMO

Output:
  customer_id
  customer_name

Dieu kien:
  Khong ton tai order co order_status = 'CANCELLED'
```

Viet hai phien ban:

1. Dung `NOT IN`.
2. Dung `NOT EXISTS`.

Sau do tra loi:

- Neu subquery cua `NOT IN` co mot `NULL`, ket qua thay doi the nao?
- Cach nao the hien dung nhat y nghia "khong ton tai"?
- Hai query co tra cung tap customer khong?

Query kiem tra nhanh so dong:

```sql
SELECT COUNT(*) FROM (QUERY_CUA_BAN);
```

---

### Ticket 2: Dem Khach Hang Co Don Bi Huy

Dashboard can hien:

```text
So customer co it nhat mot order CANCELLED
```

Viet hai phien ban:

1. Dung correlated `EXISTS`.
2. Dung `JOIN`.

Khong duoc dem trung customer.

Sau do tra loi:

- Tai sao `JOIN` co the tao duplicate customer?
- Khi dung join, ban can `DISTINCT` o dau?
- Query nao dien dat dung nghiep vu "co it nhat mot order" hon?

---

### Ticket 3: Bao Cao Doanh Thu Khach VIP

Bao cao can tra moi customer `PLATINUM` va tong tien order cua ho:

```text
customer_id
customer_name
order_total
```

Customer chua co order van phai xuat hien voi `order_total = 0`.

Viet hai phien ban:

1. Scalar subquery trong `SELECT`.
2. Aggregate `ORDERS_DEMO` theo `customer_id`, sau do `LEFT JOIN`.

Sau khi chay:

- Query nao doc `ORDERS_DEMO` lap lai?
- Operation nao co `Starts` cao?
- Rewrite co giam `BUFFER_GETS` khong?

---

### Ticket 4: Tim Don Hang Cao Hon Trung Binh Cua Chinh Khach Hang

Can tim cac order co `total_amount` lon hon muc trung binh cua customer tao order do.

Output:

```text
order_id
customer_id
total_amount
customer_avg_amount
```

Viet hai phien ban:

1. Correlated subquery tinh `AVG(total_amount)`.
2. Analytic function `AVG(total_amount) OVER (PARTITION BY customer_id)`.

Sau do so sanh:

- Scalar subquery co bao nhieu `Starts`?
- Analytic query co operation `WINDOW` nao?
- Hai query co tra cung so dong va cung ket qua khong?

---

## Phan B: Loi Giai Va Phan Tich Plan

## Case 1: NOT IN Gap NULL - Query Khong Tra Dong Nao

### Tinh Huong

Developer can tim khach hang khong co order `CANCELLED`. Subquery vo tinh chua mot gia tri `NULL`.

Query de sai:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L14_NOT_IN_NULL */ COUNT(*) FROM customers_demo c WHERE c.customer_id NOT IN (SELECT o.customer_id FROM orders_demo o WHERE o.order_status = 'CANCELLED' UNION ALL SELECT CAST(NULL AS NUMBER) FROM dual);
```

**Du doan truoc khi chay:** ket qua bang `0`, du van co customer khong nam trong tap con.

Ly do:

```text
x NOT IN (1, 2, NULL)
= x <> 1 AND x <> 2 AND x <> NULL
= TRUE/FALSE AND UNKNOWN
= khong du dieu kien WHERE
```

Query dung bang `NOT EXISTS`:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L14_NOT_EXISTS */ COUNT(*) FROM customers_demo c WHERE NOT EXISTS (SELECT 1 FROM orders_demo o WHERE o.customer_id = c.customer_id AND o.order_status = 'CANCELLED');
```

Tim SQL_ID va metric:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, rows_processed, ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 3) AS sec_per_exec, SUBSTR(sql_text, 1, 130) AS sql_preview FROM v$sqlarea WHERE (sql_text LIKE '%L14_NOT_IN_NULL%' OR sql_text LIKE '%L14_NOT_EXISTS%') AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time;
```

Sau khi co SQL_ID that, xem plan:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'SQL_ID_NOT_IN', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE +NOTE'));
```

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'SQL_ID_NOT_EXISTS', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE +NOTE'));
```

### Can Nhin

- Ket qua hai query co khac nhau khong?
- Plan co `HASH JOIN ANTI`, `NESTED LOOPS ANTI` hay `ANTI NA` khong?
- `NA` la null-aware anti join, Oracle phai xu ly kha nang subquery co NULL.

### Bai Hoc

Dung `NOT EXISTS` khi y nghia nghiep vu la "khong ton tai dong lien quan". Neu dung `NOT IN`, phai chac chan subquery khong the tra `NULL`.

---

## Case 2: EXISTS Hay JOIN DISTINCT?

### Tinh Huong

Can dem bao nhieu customer co it nhat mot order `CANCELLED`.

Query dung `EXISTS`:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L14_EXISTS_SEMI */ COUNT(*) FROM customers_demo c WHERE EXISTS (SELECT 1 FROM orders_demo o WHERE o.customer_id = c.customer_id AND o.order_status = 'CANCELLED');
```

Query viet bang join va sua duplicate bang `COUNT(DISTINCT)`:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L14_JOIN_DISTINCT */ COUNT(DISTINCT c.customer_id) FROM customers_demo c JOIN orders_demo o ON o.customer_id = c.customer_id WHERE o.order_status = 'CANCELLED';
```

Tim SQL_ID va metric:

```sql
SELECT sql_id, plan_hash_value, executions, buffer_gets, disk_reads, rows_processed, ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 3) AS sec_per_exec, SUBSTR(sql_text, 1, 130) AS sql_preview FROM v$sqlarea WHERE (sql_text LIKE '%L14_EXISTS_SEMI%' OR sql_text LIKE '%L14_JOIN_DISTINCT%') AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time;
```

Xem plan theo SQL_ID that:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'SQL_ID_EXISTS', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE +NOTE'));
```

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => 'SQL_ID_JOIN_DISTINCT', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE +NOTE'));
```

### Can Nhin

| Query | Y nghia |
|:---|:---|
| `EXISTS` | Chi can biet co it nhat mot dong lien quan |
| `JOIN` | Tao mot dong cho moi cap customer-order khop |
| `COUNT(DISTINCT)` | Phai loai duplicate do join tao ra |

Plan `EXISTS` co the duoc Oracle unnest thanh `HASH JOIN SEMI` hoac `NESTED LOOPS SEMI`.

### Ket Qua Lab: Truoc Va Sau Composite Index

Query duoc so sanh:

```sql
SELECT COUNT(*) FROM customers_demo c WHERE EXISTS (SELECT 1 FROM orders_demo o WHERE o.customer_id = c.customer_id AND o.order_status = 'CANCELLED');
```

Ket qua business that:

```text
COUNT(*) = 500 customer
```

#### Truoc Khi Tao Composite Index

Luc nay Oracle chi co `IDX_ORDERS_STATUS(order_status)` cho dieu kien loc:

```text
Plan hash value: 2035071161
Cost: 156

SORT AGGREGATE
  NESTED LOOPS
    SORT UNIQUE
      TABLE ACCESS BY INDEX ROWID BATCHED ORDERS_DEMO
        INDEX RANGE SCAN IDX_ORDERS_STATUS
    INDEX UNIQUE SCAN SYS_C007628
```

Predicate:

```text
IDX_ORDERS_STATUS: ORDER_STATUS = 'CANCELLED'
SYS_C007628:       O.CUSTOMER_ID = C.CUSTOMER_ID
```

Phan tich:

1. `IDX_ORDERS_STATUS` tim 10000 index entries cua order `CANCELLED`.
2. Index nay khong co `customer_id`.
3. Oracle phai `TABLE ACCESS BY INDEX ROWID` quay lai `ORDERS_DEMO` de lay `customer_id`.
4. `SORT UNIQUE` loai cac `customer_id` trung nhau.
5. Oracle lookup customer bang primary-key index `SYS_C007628`.

#### Sau Khi Tao Composite Index

Composite index:

```sql
CREATE INDEX idx_orders_status_customer ON orders_demo(order_status, customer_id);
```

Plan moi:

```text
Plan hash value: 1571415905
Cost: 39

SORT AGGREGATE
  NESTED LOOPS
    SORT UNIQUE
      INDEX RANGE SCAN IDX_ORDERS_STATUS_CUSTOMER
    INDEX UNIQUE SCAN SYS_C007628
```

Oracle khong con operation:

```text
TABLE ACCESS BY INDEX ROWID BATCHED ORDERS_DEMO
```

Ly do: `IDX_ORDERS_STATUS_CUSTOMER` co du ca hai cot subquery can:

```text
order_status -> loc order CANCELLED
customer_id  -> join voi CUSTOMERS_DEMO
```

Day la covering index cho subquery. Oracle lay `customer_id` ngay trong index, khong can quay lai table.

#### Bang So Sanh

| Metric | Truoc composite index | Sau composite index |
|:---|:---|:---|
| Plan hash | `2035071161` | `1571415905` |
| Cost uoc tinh | 156 | 39 |
| Orders access | Index + table ROWID | Index-only |
| Table lookup `ORDERS_DEMO` | Co | Khong |
| Ket qua business | 500 | 500 |

Cost uoc tinh giam:

```text
156 / 39 = 4 lan
```

> Day la ket qua `EXPLAIN PLAN`, chua phai runtime measurement. Muon xac nhan hieu nang that, so sanh `A-Rows`, `Starts`, `Buffers` va elapsed bang `DISPLAY_CURSOR`.

#### Lab Them: Dao Thu Tu Cot Trong Composite Index

Index hien tai:

```text
IDX_ORDERS_STATUS_CUSTOMER(order_status, customer_id)
```

Tao index thu nghiem voi thu tu nguoc lai:

```sql
CREATE INDEX idx_orders_customer_status ON orders_demo(customer_id, order_status);
```

So sanh cung query nhung ep dung index nguoc:

```sql
EXPLAIN PLAN FOR SELECT COUNT(*) FROM customers_demo c WHERE EXISTS (SELECT /*+ INDEX(o IDX_ORDERS_CUSTOMER_STATUS) */ 1 FROM orders_demo o WHERE o.customer_id = c.customer_id AND o.order_status = 'CANCELLED');
```

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

Sau do so sanh voi index cu:

```sql
EXPLAIN PLAN FOR SELECT COUNT(*) FROM customers_demo c WHERE EXISTS (SELECT /*+ INDEX(o IDX_ORDERS_STATUS_CUSTOMER) */ 1 FROM orders_demo o WHERE o.customer_id = c.customer_id AND o.order_status = 'CANCELLED');
```

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

##### Ket Qua Lab That: Dao Thu Tu Cot

Index co `ORDER_STATUS` dung dau:

```text
Index:           IDX_ORDERS_STATUS_CUSTOMER
Thu tu cot:      (ORDER_STATUS, CUSTOMER_ID)
Plan hash:       1571415905
Operation:       INDEX RANGE SCAN
Cost:            39
```

Predicate:

```text
access("O"."ORDER_STATUS"='CANCELLED')
```

Oracle di thang den vung `CANCELLED` trong B-tree, lay `customer_id` ngay trong index va khong can doc toan bo index.

Index co `CUSTOMER_ID` dung dau:

```text
Index:           IDX_ORDERS_CUSTOMER_STATUS
Thu tu cot:      (CUSTOMER_ID, ORDER_STATUS)
Plan hash:       3498336547
Operation:       INDEX FULL SCAN
Cost:            352
```

Predicate:

```text
access("O"."ORDER_STATUS"='CANCELLED')
filter("O"."ORDER_STATUS"='CANCELLED')
```

Query khong co mot `customer_id` cu the de mo dau viec tim kiem. Vi `ORDER_STATUS` dung thu hai, Oracle phai quet toan bo index roi loc `CANCELLED`.

So sanh:

| Index | Operation | Cost | Danh gia cho query hien tai |
|:---|:---|---:|:---|
| `(ORDER_STATUS, CUSTOMER_ID)` | `INDEX RANGE SCAN` | 39 | Tot |
| `(CUSTOMER_ID, ORDER_STATUS)` | `INDEX FULL SCAN` | 352 | Dat hon |

```text
352 / 39 = khoang 9 lan
```

Ket luan: cung hai cot nhung thu tu cot thay doi access path. Query loc toan bo order theo status nen `ORDER_STATUS` phai la leading column.

##### Runtime Lab Voi GATHER_PLAN_STATISTICS

Query L1 ep index `(CUSTOMER_ID, ORDER_STATUS)`:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /*l1_status_first */ COUNT(*) FROM customers_demo c WHERE EXISTS (SELECT /*+ INDEX(o IDX_ORDERS_CUSTOMER_STATUS) */ 1 FROM orders_demo o WHERE o.customer_id = c.customer_id AND o.order_status = 'CANCELLED');
```

Ket qua:

```text
COUNT(*) = 500
SQL_ID   = ath0az1pbmt6j
```

Metric tong:

| Metric | Gia tri |
|:---|---:|
| Executions | 1 |
| Buffer gets | 417 |
| Disk reads | 353 |
| Elapsed | 0.0307 giay |

Plan actual:

```text
Plan hash value: 3498336547

| Operation                              | Starts | E-Rows | A-Rows | Buffers | Reads |
| INDEX FULL SCAN IDX_ORDERS_CUSTOMER_STATUS | 1 | 10000 | 10000 | 350 | 353 |
| SORT UNIQUE                           | 1      | 10000  | 500    | 350     | 353   |
| INDEX UNIQUE SCAN SYS_C007628         | 500    | 1      | 500    | 65      | 0     |
| NESTED LOOPS                          | 1      | 5000   | 500    | 415     | 353   |
```

Predicate:

```text
access("O"."ORDER_STATUS"='CANCELLED')
filter("O"."ORDER_STATUS"='CANCELLED')
```

Query L2 ep index `(ORDER_STATUS, CUSTOMER_ID)`:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* l2_status_second */ COUNT(*) FROM customers_demo c WHERE EXISTS (SELECT /*+ INDEX(o IDX_ORDERS_STATUS_CUSTOMER) */ 1 FROM orders_demo o WHERE o.customer_id = c.customer_id AND o.order_status = 'CANCELLED');
```

Ket qua:

```text
COUNT(*) = 500
SQL_ID   = c3pcju8n5mmaf
```

Metric tong:

| Metric | Gia tri |
|:---|---:|
| Executions | 1 |
| Buffer gets | 104 |
| Disk reads | 0 |
| Elapsed | 0.0026 giay |

Plan actual:

```text
Plan hash value: 1571415905

| Operation                               | Starts | E-Rows | A-Rows | Buffers |
| INDEX RANGE SCAN IDX_ORDERS_STATUS_CUSTOMER | 1 | 10000 | 10000 | 37 |
| SORT UNIQUE                            | 1      | 10000  | 500    | 37      |
| INDEX UNIQUE SCAN SYS_C007628          | 500    | 1      | 500    | 65      |
| NESTED LOOPS                           | 1      | 5000   | 500    | 102     |
```

Predicate:

```text
access("O"."ORDER_STATUS"='CANCELLED')
```

##### Phan Tich Runtime

| Metric | Customer first | Status first | Chenh lech |
|:---|---:|---:|---:|
| SQL_ID | `ath0az1pbmt6j` | `c3pcju8n5mmaf` | |
| Plan hash | `3498336547` | `1571415905` | |
| Index operation | Full scan | Range scan | |
| Index buffers | 350 | 37 | 9.5 lan |
| Tong buffers trong plan | 415 | 102 | 4.1 lan |
| `v$sqlarea.buffer_gets` | 417 | 104 | 4 lan |
| Disk reads | 353 | 0 | |
| Elapsed | 0.0307s | 0.0026s | 11.8 lan |
| Ket qua | 500 | 500 | Giong nhau |

Ket luan:

1. Hai query tra cung ket qua, nen co the so sanh performance.
2. `(CUSTOMER_ID, ORDER_STATUS)` khong co dieu kien tren leading column cu the; Oracle full scan 350 index blocks.
3. `(ORDER_STATUS, CUSTOMER_ID)` tim thang vung `CANCELLED`; range scan chi ton 37 buffers.
4. Ca hai plan deu `SORT UNIQUE` 10000 order entries thanh 500 customer, sau do lookup primary key 500 lan.
5. `E-Rows = 5000` tai Nested Loops nhung `A-Rows = 500`: optimizer uoc tinh cao gap 10 lan o buoc nay.
6. Elapsed L1 cham hon con do co 353 physical reads, trong khi L2 chay sau va duoc warm cache. Vi vay khong dung rieng elapsed de ket luan muc chenh lech.
7. Bang chung cong bang nhat trong lan test nay la LIO: 417 vs 104 buffer gets. Index status-first van tot hon khoang 4 lan ve logical I/O.

De so elapsed cong bang hon, chay xen ke moi query vai lan va so `buffer_gets/executions`, `elapsed_time/executions`; khong flush buffer cache tren RAC.

Cach du doan:

| Index | Loi the |
|:---|:---|
| `(order_status, customer_id)` | Tot khi query bat dau bang `order_status = 'CANCELLED'`, sau do lay `customer_id` |
| `(customer_id, order_status)` | Tot khi da co mot/vai `customer_id`, sau do kiem tra status cua customer do |

Voi query hien tai, Oracle can tim toan bo customer co order `CANCELLED`, nen `(order_status, customer_id)` thuong phu hop hon:

```text
Loc theo status truoc -> lay danh sach customer -> unique -> join
```

Index nguoc phu hop hon voi query OLTP:

```sql
SELECT COUNT(*) FROM orders_demo WHERE customer_id = 123 AND order_status = 'CANCELLED';
```

Sau khi ghi lai plan, xoa index thu nghiem de tranh duy tri hai index gan trung nhau:

```sql
DROP INDEX idx_orders_customer_status;
```

> `CREATE INDEX` va `DROP INDEX` la DDL, Oracle tu dong commit. Chi chay trong homelab. Hint trong muc nay chi dung de so sanh hai thu tu cot, khong phai khuyen nghi production.

### Bai Hoc

Neu khong can cot cua bang con va chi hoi "co ton tai hay khong", viet `EXISTS` de dien dat dung y nghia. Dung `JOIN DISTINCT` de che duplicate thuong lam SQL kho doc va co the them aggregate/sort.

---

## Case 3A: So Sanh Co NVL Va Khong Co NVL

### Muc Tieu Dang Hoc

Chi so sanh hai query gan nhu giong nhau:

```text
Query 1: co NVL(..., 0)
Query 2: khong co NVL
```

Chua hoc scalar-vs-join trong muc nay.

### Query 1: Co NVL

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L3_NVL */ c.customer_id, c.customer_name, NVL((SELECT SUM(o.total_amount) FROM orders_demo o WHERE o.customer_id = c.customer_id), 0) AS order_total FROM customers_demo c WHERE c.membership_lvl = 'PLATINUM';
```

Y nghia:

```text
Customer co order    -> tra tong tien
Customer khong order -> tra 0
```

### Query 2: Khong Co NVL

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L4_NO_NVL */ c.customer_id, c.customer_name, (SELECT SUM(o.total_amount) FROM orders_demo o WHERE o.customer_id = c.customer_id) AS order_total FROM customers_demo c WHERE c.membership_lvl = 'PLATINUM';
```

Y nghia:

```text
Customer co order    -> tra tong tien
Customer khong order -> tra NULL
```

Voi du lieu hien tai, moi customer deu co order nen hai query tra cung ket qua. Khac biet logic chi xuat hien khi customer khong co order.

### Tim SQL_ID

```sql
SELECT sql_id, executions, buffer_gets, disk_reads, ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 4) AS sec_per_exec, SUBSTR(sql_text, 1, 120) AS sql_preview FROM v$sqlarea WHERE (sql_text LIKE '%L3_NVL%' OR sql_text LIKE '%L4_NO_NVL%') AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time;
```

### Ket Qua Plan Da Thay

Query co `NVL`:

```text
Plan hash: 2425363251

TABLE ACCESS FULL CUSTOMERS_DEMO
  SORT AGGREGATE
    TABLE ACCESS BY INDEX ROWID ORDERS_DEMO
      INDEX RANGE SCAN IDX_ORDERS_CUSTOMER
```

Oracle giu correlated scalar subquery va lookup orders theo `customer_id`.

Query khong co `NVL`:

```text
Plan hash: 344269074

HASH GROUP BY
  HASH JOIN OUTER
    TABLE ACCESS FULL CUSTOMERS_DEMO
    TABLE ACCESS FULL ORDERS_DEMO
```

Oracle tu dong unnest/transform scalar subquery thanh outer join + group by.

### Ket Luan Case 3A

| Query | Khi customer khong co order | Plan da thay |
|:---|:---|:---|
| Co `NVL` | `0` | Correlated scalar + index lookup |
| Khong `NVL` | `NULL` | Hash outer join + group by |

`NVL` khong chi doi cach hien thi `NULL` thanh `0`; trong case nay no con lam optimizer chon transformation khac.

> Hai lan truoc ban viet nham `GATHER_PLAN_STATISTIC` thieu chu `S`, nen plan chua co `Starts`, `A-Rows`, `Buffers`. Khi can so runtime, chay lai dung hai query o dau Case 3A.

---

## Case 3B: Bai Mo Rong - Scalar Subquery Va Aggregate Join

> Muc nay la bai khac. Chua can hoc thi bo qua.

Scalar bi co dinh chay lap:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS NO_MERGE */ /* L14_SCALAR_REPEAT */ SUM(order_total) FROM (SELECT c.customer_id, (SELECT /*+ NO_UNNEST */ SUM(o.total_amount) FROM orders_demo o WHERE o.customer_id = c.customer_id) AS order_total FROM customers_demo c WHERE c.membership_lvl = 'PLATINUM');
```

Aggregate + join:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L14_PREAGG_JOIN */ SUM(NVL(x.order_total, 0)) FROM customers_demo c LEFT JOIN (SELECT customer_id, SUM(total_amount) AS order_total FROM orders_demo GROUP BY customer_id) x ON x.customer_id = c.customer_id WHERE c.membership_lvl = 'PLATINUM';
```

Ket qua da do:

| Metric | Scalar | Aggregate + join |
|:---|---:|---:|
| SQL_ID | `9x8r7mnxpk6ax` | `bax8zz2tf2jcg` |
| Starts tren Orders | 50 | 1 |
| Buffers | 1079 | 650 |

Day khong phai ket qua cua bai NVL. No la bai rieng ve lookup lap va set processing.

---

## 1. Query Transformation Pipeline

Truoc khi cost cac plan, optimizer co the bien doi SQL:

```text
SQL text
  -> view merging
  -> predicate pushing
  -> subquery unnesting
  -> OR expansion
  -> join elimination
  -> generate candidate plans
  -> estimate cost
  -> choose plan
```

Vi vay hai SQL text khac nhau co the tao cung plan. Nguoc lai, mot SQL text co the tao plan khac khi stats, bind, version hoac optimizer setting thay doi.

---

## 2. SEMI JOIN Va ANTI JOIN

| Operation | Cau hoi |
|:---|:---|
| `SEMI JOIN` | Dong ben trai co it nhat mot match khong? |
| `ANTI JOIN` | Dong ben trai co hoan toan khong co match khong? |
| `ANTI NA` | Anti join co xu ly kha nang NULL |

Semi join khong nhan ban dong ben trai theo so match. Normal join co the nhan ban.

---

## 3. EXISTS Khong Co Nghia La Chay Subquery Tung Dong

SQL viet correlated:

```sql
WHERE EXISTS (SELECT 1 FROM orders_demo o WHERE o.customer_id = c.customer_id)
```

Oracle co the unnest thanh join. Hay xem plan:

```text
HASH JOIN SEMI
NESTED LOOPS SEMI
```

Khong mo ta performance bang cau "subquery chay mot lan cho moi row" neu chua xem `Starts`.

---

## 4. Doc Starts De Phat Hien Cong Viec Lap

Trong `ALLSTATS LAST`:

| Cot | Y nghia |
|:---|:---|
| `Starts` | Operation duoc khoi dong bao nhieu lan |
| `A-Rows` | Tong row operation tra ve |
| `Buffers` | Logical I/O cua operation |

Neu scalar subquery co `Starts = 50`, no da duoc khoi dong 50 lan. Neu `Starts = 1`, optimizer co the da transform hoac xu ly tap hop.

---

## 5. Khi Nao Nen Rewrite?

| Dau hieu | Huong xem xet |
|:---|:---|
| `NOT IN` subquery co the co NULL | Dung `NOT EXISTS` |
| Chi can kiem tra ton tai | Dung `EXISTS` |
| `JOIN DISTINCT` chi de xoa duplicate | Xem lai `EXISTS` |
| Scalar subquery co `Starts` cao | Pre-aggregate/join hoac them index phu hop |

Khong rewrite theo cong thuc may moc. So sanh ket qua nghiep vu truoc, sau do so plan va runtime metric.

---

## 6. Ly Thuyet CTE: INLINE Va MATERIALIZE

Phan nay chi giu ly thuyet, khong con lab tren data hien tai.

```text
INLINE
  Oracle chen noi dung CTE vao query chinh.
  Khong tao temporary result rieng.
  CTE dung nhieu lan co the bi tinh lai nhieu lan.

MATERIALIZE
  Oracle tinh CTE truoc.
  Ket qua trung gian co the duoc luu trong temporary segment.
  Nhieu noi trong cung statement co the doc lai ket qua nay.
```

Plan `MATERIALIZE` co the hien:

```text
TEMP TABLE TRANSFORMATION
LOAD AS SELECT
TABLE ACCESS FULL SYS_TEMP_...
```

Temporary object `SYS_TEMP_...`:

- Khong phai table vinh vien cua schema.
- Oracle tu dong giai phong temporary segment khi statement/session khong con can.
- Khong can `DROP TABLE SYS_TEMP_...`.
- Khong lam datafile nghiep vu tang vinh vien.

Cursor cua hai query co the con trong shared pool mot thoi gian. Oracle tu dong aging out khi can memory; khong can flush shared pool.

---

## 7. Checklist Dieu Tra Subquery Cham

1. Hai SQL co tra cung ket qua khong?
2. Co `NULL` trong tap cua `NOT IN` khong?
3. Plan co `SEMI`, `ANTI`, `FILTER` hay `SCALAR SUBQUERY`?
4. Operation nao co `Starts` cao?
5. `E-Rows` va `A-Rows` co lech lon?
6. Duplicate co bi tao ra roi moi `DISTINCT` khong?
7. Rewrite co giam `Buffers` va elapsed khong?

---

## 8. License Note

Bai nay chi dung:

```text
V$SQLAREA
DBMS_XPLAN.DISPLAY_CURSOR
Execution plan runtime statistics
```

Khong can AWR, ASH, SQL Monitor, SQL Tuning Advisor hay Tuning Pack.

---

## 9. Checklist Hoan Thanh Bai 14

- [ ] Chung minh `NOT IN` gap NULL co the tra sai ket qua mong doi.
- [ ] Doc duoc `SEMI JOIN` va `ANTI JOIN`.
- [ ] So sanh `EXISTS` voi `JOIN DISTINCT`.
- [ ] Dung `Starts` phat hien scalar subquery chay lap.

Bat dau tu Case 1. Sau moi case, gui output query ket qua + metric SQL_ID; minh se dien SQL_ID that va ket qua lab vao file.
