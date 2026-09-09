# Lesson 13: Buffer Cache Flow — Oracle Doc/Ghi Tren RAM Nhu The Nao?

## 1. Buffer Cache La Gi?

**Buffer cache** = vung RAM trong SGA (System Global Area) chua copy cua cac database block.

Khi Oracle can doc 1 block (8KB), no tim trong buffer cache truoc:

- `cache hit`: block co trong RAM → doc ngay, khong can disk
- `cache miss`: block khong co trong RAM → doc tu disk vao RAM, roi moi dung

## 2. Quy Trinh Khi INSERT / UPDATE

```
User thuc hien: UPDATE orders_demo SET total_amount = 100 WHERE order_id = 10;
```

| Buoc | Noi dung | Xay ra o dau? |
|:---:|:---|---|
| 1 | Tim block chua order_id=10 trong buffer cache | Buffer cache (RAM) |
| 2a | **Co san** → dung luon | ✅ Cache hit |
| 2b | **Chua co** → doc tu disk vao buffer cache | Disk → RAM |
| 3 | Ghi total_amount = 100 vao block trong buffer cache | Buffer cache (RAM) |
| 4 | Danh dau block do la **dirty** (do, chua ghi disk) | Buffer cache |
| 5 | **Tra ve ket qua cho user** (ngay lap tuc, khong cho disk) | ✅ |

**Ghi disk xay ra sau,** khong dong bo voi cau lenh cua user:

```
DBWn (Database Writer) chay ngam:
  - Khi checkpoint
  - Khi buffer cache day
  - Khi Oracle can free buffer, checkpoint, fast-start recovery hoac cac co che ghi nen khac

Ghi dirty block tu buffer cache xuong disk
```

**Dong giai thich:** Cau `INSERT/UPDATE` thay doi data block trong buffer cache va tao redo. `COMMIT` yeu cau LGWR flush redo cua transaction xuong online redo log truoc khi bao `Commit complete`; COMMIT khong bat DBWn ghi ngay dirty data block xuong datafile. Neu instance crash sau COMMIT, Oracle dung redo de recovery.

## 3. Quy Trinh Khi SELECT (Lan 1)

```
User: SELECT SUM(total_amount) FROM orders_demo WHERE order_status = 'CANCELLED';
```

**Tinh huong minh hoa cold cache** — cac block query can chua co trong buffer cache cua instance dang chay:

| Buoc | Noi dung | Trang thai |
|:---:|---|---|
| 1 | INDEX RANGE SCAN: tim leaf block cua status='CANCELLED' | Cache miss → doc 31 leaf blocks tu disk |
| 2 | Co 10000 rowid | Luu trong RAM (PGA) |
| 3 | TABLE ACCESS: voi moi rowid, tinh ra file+block+row | - |
| 4 | Doc block table tu disk → buffer cache | Cache miss → 618 table blocks tu disk |
| 5 | Doc total_amount tu block do, tinh SUM | buffer cache (RAM) |
| 6 | Tra ve ket qua | ✅ |

```
buffer_gets = 649  (31 index + 618 table)  
disk_reads  = 649  (lan dau, tat ca deu cache miss)
```

## 4. Quy Trinh Khi SELECT (Lan 2)

**Chay lai cung cau lenh** — block da co trong buffer cache:

| Buoc | Trang thai |
|:---|---|
| 1 | INDEX RANGE SCAN: leaf block da co san | ✅ Cache hit |
| 2 | TABLE ACCESS: table block da co san | ✅ Cache hit |

```
buffer_gets = 649  (van doc 649 blocks, nhung tu RAM)
disk_reads  = 0    (khong can doc disk lan nao)
```

## 5. Khi Buffer Cache Day

Buffer cache co gioi han (DB_CACHE_SIZE). Khi day:

| Su kien | Oracle lam gi? |
|---|---|
| Cache day, can cho block moi vao | Day block **it dung nhat** (LRU) ra ngoai |
| Block dirty bi day | DBWn ghi xuong disk truoc, roi moi day ra |
| Block clean (da dong bo disk) | Day ra ngay, mat khoi RAM |

Lan sau can block do → cache miss → doc lai tu disk.

## 6. So Do Tong Quat

```
                    +------------------+
                    |   Buffer Cache   |
                    |     (RAM/SGA)    |
                    +--------+---------+
                             |
            +----------------+----------------+
            |                |                |
       cache hit        cache miss        dirty write
            |                |                |
       doc tu RAM     doc tu disk      DBWn ghi xuong
            |                |                |
       tra ket qua    vao cache roi     dirty -> clean
                      tra ket qua
```

## 7. Buffer Cache vs Index Leaf Block

| | Leaf block (index) | Table block |
|:---|---:|---:|
| Kich thuoc | 8KB | 8KB |
| So entry / block | ~300-500 | ~50-100 rows |
| De compress | Cao (cot it, du lieu sorted) | Thap (nhieu cot, du lieu thap) |
| **Buffers cho 10000 rows** | **31** | **~100-200** (thuong phai doc ~618 vi rowid ban tung) |

Index leaf block chua nhieu entry hon vi moi entry chi co (value + rowid). Table block chua row day du voi nhieu cot → it row hon → can nhieu block hon.

## 8. Lab: Kiem Tra LIO Va PIO Tren Mot RAC Instance

Lab nay chay co dinh tren:

```text
DB_UNIQUE_NAME = racdb
DATABASE_ROLE  = PRIMARY
INSTANCE_NAME  = racdb1
HOST_NAME      = rac1
PDB            = PDB1
```

Khong can mo `racdb2` hay standby. Khong flush buffer cache.

### Buoc 1: Xac Nhan Dung Instance

```sql
SELECT d.db_unique_name, d.database_role, d.open_mode, i.instance_name, i.host_name FROM v$database d CROSS JOIN v$instance i;
```

### Buoc 2: Chay Lan Thu Nhat

Marker rieng giup cursor nay chi co mot execution trong lab:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L13_CACHE_RUN1 */ SUM(total_amount) FROM orders_demo WHERE order_status = 'CANCELLED';
```

### Buoc 3: Chay Lan Thu Hai

Cung logic va plan, nhung marker khac de tao SQL_ID khac va metric khong bi cong don:

```sql
SELECT /*+ GATHER_PLAN_STATISTICS */ /* L13_CACHE_RUN2 */ SUM(total_amount) FROM orders_demo WHERE order_status = 'CANCELLED';
```

### Buoc 4: So Sanh Hai Cursor

```sql
SELECT sql_id, executions, buffer_gets, disk_reads, ROUND(buffer_gets / NULLIF(executions, 0), 1) AS lio_per_exec, ROUND(disk_reads / NULLIF(executions, 0), 1) AS pio_per_exec, ROUND(elapsed_time / NULLIF(executions, 0) / 1e6, 3) AS sec_per_exec, SUBSTR(sql_text, 1, 100) AS sql_preview FROM v$sqlarea WHERE (sql_text LIKE '%L13_CACHE_RUN1%' OR sql_text LIKE '%L13_CACHE_RUN2%') AND sql_text NOT LIKE '%v$sqlarea%' ORDER BY last_active_time;
```

### Buoc 5: Xem Plan That

SQL_ID that cua hai cursor trong lab:

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => '6kx9tcbc64r89', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE +IOSTATS'));
```

```sql
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => '3wpny0cm44xgv', cursor_child_no => NULL, format => 'ALLSTATS LAST +PREDICATE +IOSTATS'));
```

### Cach Ket Luan

| Metric | Y nghia |
|:---|:---|
| `BUFFER_GETS` / `lio_per_exec` | Logical I/O: so lan truy cap block |
| `DISK_READS` / `pio_per_exec` | Physical I/O: block phai doc tu storage |
| LIO hai lan gan nhau | Query van can xu ly cung luong block |
| PIO lan 2 thap hon | Nhieu block da co trong buffer cache cua `racdb1` |

Khong bat buoc RUN1 phai co PIO cao. Co the block da duoc bai hoc/query truoc do nap vao cache. Muc tieu la doc dung LIO/PIO, khong co gang tao cold cache bang `ALTER SYSTEM FLUSH BUFFER_CACHE`.

### Ket Qua Lab That Tren racdb1

Ket qua `v$sqlarea`:

| Run | SQL_ID | Executions | LIO/exec | PIO/exec | Sec/exec |
|:---|:---|---:|---:|---:|---:|
| RUN1 | `6kx9tcbc64r89` | 1 | 649 | 0 | 0.004 |
| RUN2 | `3wpny0cm44xgv` | 1 | 649 | 0 | 0.004 |

Ca hai cursor co cung:

```text
Plan hash value = 3862084843
E-Rows          = 10000
A-Rows          = 10000
Buffers         = 649
Disk reads      = 0
```

Plan:

```text
SORT AGGREGATE
  TABLE ACCESS BY INDEX ROWID BATCHED ORDERS_DEMO  Buffers=649
    INDEX RANGE SCAN IDX_ORDERS_STATUS             Buffers=31
```

Phan tich:

1. `IDX_ORDERS_STATUS` loc dung 10000 row va ton 31 LIO.
2. Query can cot `total_amount`, nhung cot nay khong co trong index.
3. Oracle dung rowid quay lai `ORDERS_DEMO`, tong LIO tang thanh 649.
4. Phan table lookup ton khoang `649 - 31 = 618` LIO.
5. RUN1 va RUN2 deu `PIO = 0`: cac index/table block da co trong buffer cache cua `racdb1` truoc khi lab bat dau.
6. RUN2 khong giam LIO vi cache hit chi tranh doc storage; Oracle van phai truy cap va xu ly cung 649 block logic.

Ket luan:

```text
LIO do khoi luong block query phai xu ly.
PIO do so block khong co san trong buffer cache va phai doc tu storage.
Warm cache co the giam PIO va elapsed time, nhung khong tu dong giam LIO.
```

Lab nay dat muc tieu bai 13: phan biet duoc `BUFFER_GETS` va `DISK_READS`, dong thoi giai thich duoc 649 LIO den tu 31 index blocks + khoang 618 table blocks.

## 9. Internals: INDEX RANGE SCAN vs FULL vs ROWID Lookup

### 9.1 INDEX RANGE SCAN — B-Tree + Linked List

```
SELECT COUNT(*) FROM orders_demo WHERE total_amount > 909.09;
```

Oracle chon `IDX_TOTAL_AMOUNT` (single column B-tree):

```
                    Root Block
                  [500, 1000, 2000]
                  /       |        \
           Branch       Branch    Branch
        [900, 950]   [1000, 1500]  ...
           |
        Leaf Chain (doubly linked list):
        ┌─────────┐ ← → ┌─────────┐ ← → ┌─────────┐
        │909.10   │      │950.20   │      │1000.00  │
        │  rowid1 │      │  rowid9 │      │  rowidN │
        │909.15   │      │955.00   │      │1002.50  │
        │  rowid2 │      │  rowid10│      │  rowidN+1│
        │...      │      │...      │      │...      │
        │950.00   │      │999.99   │      │1250.00  │
        │  rowid8 │      │  rowid20│      │  rowidN+2│
        └─────────┘      └─────────┘      └─────────┘
        ^--- bat dau scan tu day
```

| Buoc | Noi dung |
|:---:|---|
| 1 | Oracle tinh `1000 / 1.1 = 909.090909` (1 lan, khong dung table) |
| 2 | **Root → Branch**: tim branch block chua gia tri >= 909.09 |
| 3 | **Branch → Leaf**: tim leaf block dau tien co `total_amount > 909.09` |
| 4 | **Linked list (doubly)**: tu leaf block do, doc sang phai (next pointer), khong can quay lai branch/root |
| 5 | Moi leaf block chua ~400-500 entry (value + rowid, ~20-30 bytes/entry) |
| 6 | Dem entry pass filter tu leaf block hien tai → next leaf → ... cho den khi gap entry <= 909.09 |
| 7 | Vi `COUNT(*)` khong can cot khac → **khong can rowid lookup** → chi doc leaf blocks |

So leaf blocks can doc = `ceil(9001 entries / 400 entries per block) = ~21 blocks`

**Tai sao 21 ma khong phai 31 o case truoc?** Vi `IDX_TOTAL_AMOUNT` chi co 1 cot (total_amount) + rowid, entry rat nho. `IDX_ORDERS_STATUS` cung chi 1 cot + rowid, nhung status la VARCHAR2 dai hon number → entry to hon → can nhieu leaf block hon (31).

### 9.2 TABLE ACCESS FULL — HWM (High Water Mark)

```
SELECT /*+ FULL(orders_demo) */ COUNT(*) FROM orders_demo WHERE total_amount > 909.09;
```

Oracle quet toan bo tu block dau tien den HWM:

```
Segment ORDERS_DEMO (HWM = 625):

Block 1: [cust1, 500$] [cust2, 1500$] ... (50 rows)
  ├── filter total_amount > 909.09? → YES → count++
  ├── NO → bo qua
  └── ...
Block 2: [cust51, 100$] ...
  ├── NO → bo qua
  └── ...
...
Block 625: [..., ...] (row cuoi)
  └── HWM → dung lai

Block 626: (chua dung bao gio)
Block 627: (chua dung bao gio)
  └── FULL SCAN KHONG DOC NHUNG BLOCK NAY
```

**HWM la gi?**

- HWM = block cuoi cung trong segment da co du lieu (tung co insert)
- **INSERT** → HWM day len
- **DELETE** → HWM **khong tuot xuong** — du xoa 99999 rows, HWM van o block 625
- FULL SCAN doc tu block 1 → HWM (625 blocks), khong the doc it hon

**Tai sao HWM = 625 cho table 100000 rows?**

Neu moi block chua ~160 rows, 100000 rows can ~625 blocks. Con so hop ly.

**Tai sao `IDX_TOTAL_AMOUNT` chi 21 blocks?**

Vi leaf entry chi co (value + rowid) = ~20 bytes. Block 8KB → ~400 entries/block. 9001 entries → ~21 blocks.

Table block chua toan bo row (nhieu cot: order_id, customer_id, order_date, order_status, total_amount, ...) → block chi chua ~50-80 rows (du lieu 100000 rows, nhung chi 625 blocks do block chua ~160 rows moi — du lieu co the khong day).

| Block type | Entry size | Blocks for 9001 filter-pass rows |
|:---|---:|---:|
| Index leaf (total_amount + rowid) | ~20 bytes | **21** |
| Table block (full row) | ~50-100 bytes | **625** (full table) |

**Tóm lại:** FORCE_FULL doc 625 blocks vi HWM = 625. FORCE_INDEX chi doc 21 leaf blocks vi linked list chi phi di qua leaf entries pass filter.

### 9.3 TABLE ACCESS BY INDEX ROWID — Rowid Lookup

```
SELECT SUM(total_amount) FROM orders_demo WHERE order_status = 'CANCELLED';
```

Oracle co rowid tu index, giai ma thanh dia chi vat ly:

```
Rowid = AAAABb AAAA AAAA
        ───── ──── ────
        object file block
        number  ↑
               row slot
```

| Rowid sample | File# | Block# | Row slot |
|:---|:---:|:---:|:---:|
| AAAShP AAE AAAABX AAA | 14 | 87 | 0 |
| AAAShP AAE AAAABX AAB | 14 | 87 | 1 |
| AAAShP AAE AAAABY AAA | 14 | 88 | 0 |
| ... | ... | ... | ... |

**Rowid lookup step-by-step:**

1. Tuong tuong 10000 rowid tu INDEX RANGE SCAN
2. Oracle sort rowid theo block (de doc block 1 lan cho nhieu row trong cung block)
3. Rowid `AAAABX` → File 14, Block 87 → doc block 87 vao buffer cache
4. Doc row slot 0 → `total_amount`
5. Doc row slot 1 → `total_amount`
6. Rowid `AAAABY` → File 14, Block 88 → doc block 88
7. ... tiep tuc cho toi het 10000 rowid

**Vi sao 10000 rowid can 618 table blocks?**

- 10000 rows trong 1 table co 625 blocks (HWM)
- Rowid re rai rac khap 625 blocks, khong du clone vao 1 block
- Trung binh moi block co ~16 row pass filter
- Nhung rowid khong duoc sap xep theo block tu nhien → 618 blocks doc du 10000 rows
- 31 blocks index + 618 blocks table = **649 buffers**

### 9.4 Vi Sao Optimizer Chon Index Cho COUNT(*) Nhung Co The Tu Choi Cho SELECT *?

| Query | Can lay tu table? | Strategy |
|:---|---:|:---|
| `COUNT(*) WHERE total_amount > X` | Khong can | Index-only scan (21 buffers) |
| `SUM(total_amount) WHERE order_status = 'C'` | Can `total_amount` | Rowid lookup (649 buffers) |
| `SELECT * WHERE total_amount > X` | Can **het** cac cot | Rowid lookup (nhieu buffers) |

Voi `SELECT *`, optimizer tinh:

```
Index scan cost = leaf blocks + table blocks (rowid lookup)
Full scan cost  = HWM blocks

Neu index scan cost > full scan cost → optimizer chon FULL
```

Co 2 yeu to lam index scan dat:
- **Selectivity cao** (nhieu row pass filter → nhieu rowid lookup)
- **Clustering factor xau** (rowid phan tan nhieu block → rowid lookup dat)

Clustering factor = so block Oracle phai doc neu doc table theo rowid tu index. Neu clustering factor ~= num_blocks → tot (rows gan nhau). Neu ~= num_rows → xau (rows rac).

---

## Bai Tiep Theo

[Lesson 14: Subquery Va Query Transformation](14_subquery_query_transformation.md)
