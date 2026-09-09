# Lesson 10: Lock & Blocking Session — Truy Sat `enq: TX - row lock contention`

Bai 9 da bat duoc mot case rat thuc te trong AWR:

```text
Top Event: enq: TX - row lock contention
Time: 52.9s
%DB Time: 98.9%
Top SQL: update orders_demo set total_amount=888 where order_id=10
```

Ket luan: database khong cham vi CPU, khong cham vi I/O, ma cham vi **mot session giu lock va session khac phai doi**.

Bai 10 hoc cach tra loi:

1. Session nao dang bi block?
2. Session nao la blocker?
3. SQL nao dang doi lock?
4. Object/row nao co kha nang dang bi khoa?
5. Nen doi, `COMMIT`/`ROLLBACK`, hay kill session?

> **License note:** Cac phan realtime trong bai nay dung `gv$session`, `gv$lock`, `gv$locked_object`, `gv$transaction`, `v$session_blockers`, `v$wait_chains` la nhanh free phu hop production. Phan ASH/AWR chi dung trong homelab/dev/test hoac production co Diagnostics Pack license.

---

## 0. Tu Khoa Can Nho

| Tu khoa | Y nghia |
|:---|:---|
| Lock | Khoa du lieu/object de bao ve transaction |
| Blocker | Session dang giu lock |
| Waiter | Session dang doi lock |
| `TX` | Transaction lock, thuong lien quan row-level lock |
| `TM` | Table lock, thuong lien quan DML/DDL tren table |
| `enq: TX - row lock contention` | Wait event khi session doi row lock do transaction khac giu |
| `blocking_session` | SID cua session dang chan minh |
| `blocking_instance` | Instance RAC noi blocker dang nam |
| `sid, serial#` | Cap dinh danh session de trace/kill |

Meo nho:

```text
TX = Transaction
row lock contention = tranh chap khoa row
```

Gap `enq: TX - row lock contention` thi dung them index voi vang. Dau tien phai tim transaction nao chua `COMMIT` hoac `ROLLBACK`.

---

## 1. Tao Lab Lock Bang 2 Session

Mo 2 terminal SQLcl rieng vao `PDB1`.

### Session A: Giu Lock

```sql
CONN query_tuning/your_password@PDB1

UPDATE orders_demo SET total_amount = 888 WHERE order_id = 10;
```

Khong `COMMIT`, khong `ROLLBACK`.

### Session B: Bi Block

Mo terminal khac:

```sql
CONN query_tuning/your_password@PDB1

UPDATE orders_demo SET total_amount = 999 WHERE order_id = 10;
```

Session B se bi dung/treo, vi dang doi Session A release lock.

---

## 2. Query Nhanh Nhat: Ai Dang Bi Block?

Trong RAC, uu tien `gv$session` thay vi `v$session`, vi blocker co the nam o instance khac.

```sql
SELECT inst_id, sid, serial#, username, status, sql_id, event, wait_class, seconds_in_wait, blocking_instance, blocking_session, machine, program FROM gv$session WHERE type = 'USER' AND blocking_session IS NOT NULL ORDER BY seconds_in_wait DESC;
```

Luu y: cot dung la `sid`, khong phai `sid_id`. Neu go `sid_id` se bi `ORA-00904: invalid identifier`.

Output lab:

```
INST_ID SID SERIAL# USERNAME      STATUS SQL_ID        EVENT                         WAIT_CLASS  SECONDS_IN_WAIT BLOCKING_INSTANCE BLOCKING_SESSION
------- --- ------- ------------- ------ ------------  ---------------------------- ----------- ---------------- ----------------- ----------------
      2 310    2610 QUERY_TUNING  ACTIVE 4qcu4ra4ua8xt enq: TX - row lock contention Application              212                 1              297
```

Cach doc:

- `INST_ID = 2`, `SID = 108`: session dang bi block nam o instance 2.
- `EVENT = enq: TX - row lock contention`: dang doi row lock.
- `SECONDS_IN_WAIT = 72`: da doi 72 giay.
- `BLOCKING_INSTANCE = 1`, `BLOCKING_SESSION = 42`: blocker nam o instance 1, SID 42.

---

## 3. Blocker + Waiter Join

Day la cau nen nho nhat bai 10:

```sql
SELECT b.inst_id AS blocker_inst, b.sid AS blocker_sid, b.serial# AS blocker_serial, b.username AS blocker_user, b.status AS blocker_status, b.sql_id AS blocker_sql_id, b.prev_sql_id AS blocker_prev_sql_id, b.machine AS blocker_machine, b.program AS blocker_program, w.inst_id AS waiter_inst, w.sid AS waiter_sid, w.serial# AS waiter_serial, w.username AS waiter_user, w.sql_id AS waiter_sql_id, w.event AS waiter_event, w.seconds_in_wait FROM gv$session w JOIN gv$session b ON b.sid = w.blocking_session AND b.inst_id = w.blocking_instance WHERE w.blocking_session IS NOT NULL ORDER BY w.seconds_in_wait DESC;
```

Output lab:

```
BLOCKER_INST BLOCKER_SID BLOCKER_SERIAL BLOCKER_USER   BLOCKER_STATUS BLOCKER_SQL_ID   BLOCKER_PREV_SQL_ID BLOCKER_MACHINE BLOCKER_PROGRAM         WAITER_INST WAITER_SID WAITER_SERIAL WAITER_USER  WAITER_SQL_ID   WAITER_EVENT                      SECONDS_IN_WAIT
------------ ----------- -------------- --------------- -------------- ---------------- ------------------- --------------- --------------------- ----------- ---------- ------------- ------------ --------------- ---------------------------------- ---------------
          1         297          65200 QUERY_TUNING   ACTIVE         74cxnphavp31u   b4cu2w55kydgm       rac1            java@rac1 (TNS V1-V3)          2         310          2610 QUERY_TUNING 4qcu4ra4ua8xt  enq: TX - row lock contention                292
```

Diem quan trong:

| Cot | Doc nhu the nao |
|:---|:---|
| `waiter_*` | Session dang bi treo/doi lock |
| `blocker_*` | Session dang giu lock |
| `blocker_status = ACTIVE` | Blocker van dang chay (co the dang execute transaction) |
| `blocker_status = INACTIVE` | Van co the dang giu lock neu chua commit |
| `blocker_sql_id` | SQL blocker dang chay ngay luc nay |
| `blocker_prev_sql_id` | SQL truoc do cua blocker, rat huu ich khi blocker dang idle |

---

## 4. Xem SQL Text Cua Waiter Va Blocker

Thay `WAITER_SQL_ID`, `BLOCKER_SQL_ID`, `BLOCKER_PREV_SQL_ID` bang gia tri tu cau join o muc 3.

```sql
SELECT inst_id, sql_id, sql_text FROM gv$sql WHERE sql_id IN ('WAITER_SQL_ID', 'BLOCKER_SQL_ID', 'BLOCKER_PREV_SQL_ID');
```

**Output lab** — chi blocker co SQL trong shared pool, waiter chua kip execute nen khong co:

```
no rows selected  <-- 2 sql_id cu tu bai 9 khong con trong shared pool
```

```sql
SELECT inst_id, sql_id, sql_text FROM gv$sql WHERE sql_id IN ('74cxnphavp31u', 'b4cu2w55kydgm', '4qcu4ra4ua8xt');
```

Output:
```
INST_ID SQL_ID          SQL_TEXT
------- --------------- ---------------------------------------------------------------
      1 aa7t6babr24zf   update orders_demo set total_amount = 888 where order_id = 10
```

Suy ra lock nam tren table `ORDERS_DEMO`, kha nang cao row `order_id = 10`.

> **Note:** `gv$sql` chi giu SQL dang o trong shared pool. Neu bi aged out thi phai dung AWR (`dba_hist_sqltext`).

---

## 5. Xem Object Dang Bi Lock

```sql
SELECT s.inst_id, s.sid, s.serial#, s.username, o.owner, o.object_name, o.object_type, lo.locked_mode FROM gv$locked_object lo JOIN dba_objects o ON o.object_id = lo.object_id JOIN gv$session s ON s.sid = lo.session_id AND s.inst_id = lo.inst_id ORDER BY s.inst_id, s.sid, o.object_name;
```

**Output lab:**
```
INST_ID   SID   SERIAL# USERNAME       OWNER          OBJECT_NAME   OBJECT_TYPE     LOCKED_MODE
      1   297     65200 QUERY_TUNING   QUERY_TUNING   ORDERS_DEMO   TABLE                     3
      2   310      2610 QUERY_TUNING   QUERY_TUNING   ORDERS_DEMO   TABLE                     3
```

Ca blocker va waiter deu co `LOCKED_MODE = 3` (Row-X / SX) tren `ORDERS_DEMO`. Blocker giu lock, waiter dang xin lock cung hang.

**Giai thich:**
- `LOCKED_MODE = 3` (Row-X) la mode mac dinh khi chay `UPDATE`/`DELETE`/`INSERT` — row exclusive, cho phep cac DML khac cung hang nhung khong cho DDL (`LOCK TABLE`, `ALTER TABLE`).
- Ca 2 dong deu hien thi mode 3 vi:
  - Blocker (SID 297) dang giu Row-X tren table.
  - Waiter (SID 310) cung da lay duoc Row-X o table level, nhung bi block o row level (TX lock). Waiter luon phai co table lock truoc khi cho row lock.
- De biet ai dang block, can nhin `blocking_session` trong `gv$session`, khong phai `gv$locked_object`. `gv$locked_object` chi cho biet object nao bi lock, khong cho biet blocker-waiter.
- Row lock cu the (order_id = 10) khong hien thi trong `gv$locked_object` — `gv$locked_object` chi show lock o table level. Row lock o trong `gv$lock` (TX enqueue).

`locked_mode` hay gap:

| locked_mode | Nghia co ban |
|---:|:---|
| 2 | Row-S / SS |
| 3 | Row-X / SX, thuong gap voi DML |
| 4 | Share |
| 5 | S/Row-X |
| 6 | Exclusive |

---

## 6. Xem Transaction Dang Mo

```sql
SELECT s.inst_id, s.sid, s.serial#, s.username, t.xidusn, t.xidslot, t.xidsqn, t.start_time, t.used_ublk, t.used_urec FROM gv$transaction t JOIN gv$session s ON s.saddr = t.ses_addr AND s.inst_id = t.inst_id ORDER BY t.start_time;
```

**Output lab:**
```
INST_ID   SID   SERIAL# USERNAME         XIDUSN   XIDSLOT   XIDSQN START_TIME            USED_UBLK   USED_UREC
      1   297     65200 QUERY_TUNING          3        14      876 06/10/26 14:21:32             1           3
```

**Giai thich:**
- Chi co **blocker** (SID 297) moi co dong trong `gv$transaction` — vi blocker dang giu transaction chua commit/rollback.
- Waiter (SID 310) **khong co** dong trong `gv$transaction` — vi waiter dang bi block, transaction cua waiter chua bat dau.
- `XIDUSN=3, XIDSLOT=14, XIDSQN=876` la transaction ID, co the dung de trace trong redo log hoac xac dinh lock trong `gv$lock`.
- `START_TIME = 06/10/26 14:21:32` — transaction da bat dau tu luc 14:21. So voi thoi diem hien tai, transaction nay da ton tai khoang 5+ phut.
- `USED_UBLK=1` — chi dung 1 undo block, transaction nho (cap nhat 1 row).
- `USED_UREC=3` — 3 undo records, co the gom UPDATE va cac hoat dong internal khac.
- Voi `USED_UBLK` va `USED_UREC` nho, neu can kill session thi rollback se nhanh, khong gay anh huong lon.

---

## 7. Xem Lock Mode Bang `gv$lock`

```sql
SELECT l.inst_id, l.sid, s.serial#, s.username, l.type, l.lmode, l.request, l.block, l.ctime, s.event, s.sql_id FROM gv$lock l JOIN gv$session s ON s.sid = l.sid AND s.inst_id = l.inst_id WHERE l.type IN ('TX', 'TM') ORDER BY l.id1, l.id2, l.block DESC, l.request DESC;
```

**Output lab:**
```
INST_ID   SID   SERIAL# USERNAME       TYPE     LMODE   REQUEST   BLOCK   CTIME EVENT                           SQL_ID
      1   297     65200 QUERY_TUNING   TM           3         0       2     839 PX Deq: Execute Reply           4p6kq55pt9dkx
      2   310      2610 QUERY_TUNING   TM           3         0       2     643 enq: TX - row lock contention   4qcu4ra4ua8xt
      1   297     65200 QUERY_TUNING   TX           6         0       2     839 PX Deq: Execute Reply           4p6kq55pt9dkx
      2   310      2610 QUERY_TUNING   TX           0         6       0     643 enq: TX - row lock contention   4qcu4ra4ua8xt
```

**Giai thich:**

4 dong = 2 sessions x 2 lock types (TM + TX):

| SID | Type | LMODE | REQUEST | BLOCK | CTIME | Y nghia |
|:---|:---|:---|---:|---:|---:|:---|
| 297 (blk) | TM | 3 | 0 | 2 | 839s | Giu Row-X tren table, dang block 2 session khac |
| 310 (wait) | TM | 3 | 0 | 2 | 643s | Giu Row-X tren table, chua block ai |
| **297 (blk)** | **TX** | **6** | **0** | **2** | **839s** | **Giu Exclusive TX lock (da lock row)** |
| **310 (wait)** | **TX** | **0** | **6** | **0** | **643s** | **Dang xin Exclusive TX lock (bi block)** |

**Cach doc nhanh:**
- `TX type, LMODE=6` = dang giu row lock exclusive — **day la blocker**
- `TX type, REQUEST=6` = dang xin row lock exclusive nhung bi tu choi — **day la waiter**
- `TM type, BLOCK=2` = session nay dang block 2 session khac (chi blocker moi co BLOCK > 0)
- `CTIME` = thoi gian (giay) da giu lock. Blocker 839s (~14 phut), waiter 643s (~11 phut). So chenh = blocker da chay truoc waiter ~3 phut

---

## 8. View Chuyen Biet Trong 19c

```sql
SELECT * FROM v$session_blockers;
```

```sql
SELECT chain_id, chain_is_cycle, blocker_is_valid, blocker_instance_id, blocker_sid, blocker_sess_serial#, sid, sess_serial#, wait_event_text, in_wait FROM v$wait_chains ORDER BY chain_id;
```

---

## 9. ASH: Tim Lock Da Xay Ra Trong Qua Khu

Muc nay chi dung trong lab hoac production co Diagnostics Pack license.

```sql
SELECT sample_time, session_id, session_serial#, sql_id, event, wait_class, blocking_inst_id, blocking_session, blocking_session_serial# FROM v$active_session_history WHERE event = 'enq: TX - row lock contention' AND sample_time > SYSTIMESTAMP - INTERVAL '1' HOUR ORDER BY sample_time DESC;
```

---

## 10. Xu Ly Lock Dung Cach

### Cach 1: Bao owner session `COMMIT` hoac `ROLLBACK`

```sql
ROLLBACK;
-- hoac
COMMIT;
```

Ngay khi blocker commit/rollback, waiter se chay tiep.

### Cach 2: Kill Session Khi That Su Can

Chi kill khi da xac nhan:

- Blocker la session treo/bo quen.
- Da biet user/app nao so huu.
- Viec rollback khong gay hau qua nghiem trong.
- Co approval neu la production.

```sql
ALTER SYSTEM KILL SESSION '42,12345' IMMEDIATE;
```

Voi RAC:

```sql
ALTER SYSTEM KILL SESSION '42,12345,@1' IMMEDIATE;
```

---

## 11. Nguyen Nhan Hay Gap

| Nguyen nhan | Dau hieu | Cach sua |
|:---|:---|:---|
| User/app quen commit | Blocker `INACTIVE`, co transaction trong `gv$transaction` | Sua transaction boundary |
| Batch update qua lau | Transaction giu lau, undo lon | Chia batch, commit theo lo hop ly |
| 2 app update cung 1 row | Nhieu waiter doi 1 blocker | Sua logic tranh hot row |
| Foreign key khong co index | Delete/update parent lam child table bi lock/scan | Tao index tren FK child |
| Bitmap index tren bang OLTP | DML block lan nhau theo bitmap | Doi sang B-tree hoac bo bitmap index |

---

## Checklist Ket Thuc Bai 10

- `enq: TX - row lock contention` nghia la gi?
- `blocking_session` va `blocking_instance` nam o dau?
- Vi sao session `INACTIVE` van co the chan session khac?
- Xem object bi lock bang view nao?
- Xem transaction dang mo bang view nao?
- Khi nao dung `COMMIT/ROLLBACK`, khi nao moi kill session?
- Trong RAC vi sao nen dung `gv$session` thay vi `v$session`?

---

## Tong Ket Bai 10

| Viec can lam | View/lenh |
|:---|:---|
| Tim session dang doi lock | `gv$session` |
| Tim blocker | `blocking_session`, `blocking_instance` |
| Xem object bi lock | `gv$locked_object` + `dba_objects` |
| Xem transaction dang mo | `gv$transaction` |
| Xem TX/TM lock mode | `gv$lock` |
| Xem wait chain | `v$wait_chains` |
| Xem lock trong qua khu | `v$active_session_history` |
| Giai phong lock dung cach | `COMMIT` / `ROLLBACK` |
| Xu ly cuoi cung | `ALTER SYSTEM KILL SESSION` |

**Bài tiếp theo:** [Lesson 11: SQL Plan Management & SQL Tuning Advisor](11_sql_plan_management_tuning_advisor.md) — khi SQL không bị lock nhưng chậm vì optimizer chọn plan sai, học cách dùng tuning advisor/profile/baseline và nhánh free không Tuning Pack.
