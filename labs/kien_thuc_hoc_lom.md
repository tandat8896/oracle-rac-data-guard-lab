# Oracle DBA & MongoDB Operations Notes

> Tổng hợp theo hướng: **cơ chế → vấn đề → cách nhận biết → cách xử lý →
> điểm cần nhớ khi phỏng vấn**.

------------------------------------------------------------------------

## 1. Linux Memory: Normal Pages, HugePages và Oracle SGA

### 1.1 Linux quản lý RAM bằng page

Linux không quản lý RAM như một khối liên tục mà chia thành các **memory
page**.

-   Normal Page trên x86_64 thường: **4 KB**
-   HugePage thường: **2 MB**
-   Một số hệ thống hỗ trợ HugePage **1 GB**

Ví dụ Oracle có:

``` text
SGA = 100 GB
```

Nếu dùng page 4 KB:

``` text
100 GB / 4 KB ≈ 26 triệu pages
```

Nếu dùng HugePage 2 MB:

``` text
100 GB / 2 MB = 51,200 HugePages
```

### 1.2 Vấn đề HugePages giải quyết

SGA của Oracle có thể rất lớn. Nếu SGA dùng hàng triệu page 4 KB, Linux
phải quản lý rất nhiều page-table entries và CPU/TLB phải xử lý nhiều
mapping hơn.

HugePages làm giảm mạnh số page:

``` text
SGA lớn
  ↓
Normal Page 4 KB
  ↓
Hàng triệu pages
  ↓
Page-table/TLB overhead lớn hơn

SGA lớn
  ↓
HugePage 2 MB
  ↓
Ít pages hơn rất nhiều
  ↓
Giảm memory-management overhead
```

HugePages chủ yếu được dùng cho **SGA**, không phải PGA.

``` text
Oracle Memory
├── SGA (shared memory)
│   └── HugePages chủ yếu áp dụng ở đây
└── PGA (private memory của process)
    └── normal memory; vẫn có khả năng chịu memory pressure/swap
```

------------------------------------------------------------------------

## 2. Tính số HugePages cho SGA

Giả sử:

``` text
SGA = 80 GB
HugePageSize = 2 MB
```

Số HugePages xấp xỉ:

``` text
80 × 1024 / 2 = 40,960 HugePages
```

Linux thường reserve explicit HugePages bằng `vm.nr_hugepages`.

Kiểm tra:

``` bash
grep -i Huge /proc/meminfo
```

Ví dụ:

``` text
HugePages_Total: 40960
HugePages_Free:  40960
Hugepagesize:     2048 kB
```

Trước khi Oracle sử dụng chúng, `Free` có thể gần bằng `Total`.

Sau khi database startup:

``` text
HugePages_Total: 40960
HugePages_Free:    100
```

Điều này cho thấy phần lớn pool đã được cấp phát, nhưng khi kiểm tra
Oracle nên kết hợp **alert log** thay vì chỉ suy luận từ
`HugePages_Free`.

Oracle alert log có thể hiển thị dạng:

``` text
PAGESIZE  AVAILABLE_PAGES  EXPECTED_PAGES  ALLOCATED_PAGES  ERROR(s)
2048K              2362            2361             2361     NONE
```

`ALLOCATED_PAGES` cho biết HugePages thực tế đã được Oracle cấp phát.

------------------------------------------------------------------------

## 3. memlock và HugePages

### Cơ chế

`memlock` (`RLIMIT_MEMLOCK`) giới hạn lượng memory mà một process/user
được phép **lock vào RAM**.

HugePages dùng cho Oracle SGA cần khả năng lock memory phù hợp.

Ví dụ:

``` text
SGA     = 40 GB
memlock = 18 GB
```

Oracle cần lock khoảng 40 GB nhưng OS chỉ cho phép tối đa 18 GB.

Đây là một nguyên nhân quan trọng cần kiểm tra khi Oracle không sử dụng
HugePages như dự kiến.

Cấu hình thường liên quan:

``` text
/etc/security/limits.conf
```

Ví dụ cho phép 256 GB:

``` text
oracle soft memlock 268435456
oracle hard memlock 268435456
```

Giá trị trên thường tính theo **KB**:

``` text
268435456 KB ≈ 256 GB
```

### Điểm nhớ

``` text
HugePages đủ
     +
memlock đủ
     +
Oracle cấu hình phù hợp
     =
SGA có thể sử dụng HugePages đúng thiết kế
```

------------------------------------------------------------------------

## 4. Explicit HugePages và Transparent HugePages (THP)

Không được nhầm:

``` text
Explicit HugePages ≠ Transparent HugePages
```

**Explicit/static HugePages** được DBA/OS reserve có chủ đích, phù hợp
với yêu cầu predictable memory của Oracle.

**Transparent HugePages (THP)** là cơ chế Linux tự động cố gắng sử dụng
huge pages cho memory thông thường. Việc collapse/compaction có thể tạo
latency không mong muốn cho database workload.

Với Oracle Database, thực tế triển khai thường kiểm tra và disable THP
theo khuyến nghị/platform guidance tương ứng, trong khi sử dụng explicit
HugePages cho SGA.

------------------------------------------------------------------------

# 5. Linux Swap trong Oracle Server

## 5.1 Swap là gì?

Khi Linux chịu memory pressure, một số memory pages ít hoạt động có thể
được chuyển từ RAM xuống swap.

``` text
RAM
 ↓
cold/inactive pages
 ↓
SWAP trên disk
```

Swap chậm hơn RAM rất nhiều.

Nhưng:

> **Swap Used \> 0 không tự động đồng nghĩa server đang thiếu RAM hoặc
> đang có sự cố.**

Linux có thể giữ các cold pages cũ trong swap ngay cả khi hiện tại máy
đã có nhiều available RAM.

------------------------------------------------------------------------

## 5.2 `free -h` chỉ cho tổng swap

Ví dụ:

``` bash
free -h
```

cho biết:

``` text
Swap: 32G  25G  7G
```

Nó trả lời:

> Tổng cộng đang có bao nhiêu swap được sử dụng?

Nhưng không trả lời:

> Process nào đang chiếm swap?

------------------------------------------------------------------------

## 5.3 Tìm process sử dụng swap

Linux expose thông tin từng process qua:

``` text
/proc/<PID>/status
```

Trong đó:

``` text
VmSwap: ...
```

cho biết lượng swap gắn với process đó.

Có thể scan:

``` bash
for status in /proc/[0-9]*/status; do
    pid=${status#/proc/}
    pid=${pid%/status}

    swap_kb=$(awk '/^VmSwap:/ {print $2}' "$status" 2>/dev/null)

    if [ -n "$swap_kb" ] && [ "$swap_kb" -gt 0 ]; then
        user=$(ps -o user= -p "$pid" 2>/dev/null)
        cmd=$(tr '\0' ' ' < /proc/"$pid"/cmdline 2>/dev/null)
        swap_mb=$((swap_kb / 1024))
        printf "%10d MB  %-12s PID=%-8s %s\n" \
            "$swap_mb" "$user" "$pid" "$cmd"
    fi
done | sort -nr | head -10
```

Cơ chế:

``` text
/proc/PID/status
      ↓
    VmSwap
      ↓
swap của từng process
      ↓
sort descending
      ↓
Top process dùng swap
```

------------------------------------------------------------------------

## 5.4 Oracle `ora_p000`, `ora_p001` là gì?

Các process như:

``` text
ora_p000
ora_p001
ora_p002
...
```

thường là **Oracle Parallel Execution Server/Slave processes**.

Chúng phục vụ các workload như parallel query/parallel execution.

Nếu chúng có `VmSwap`, điều đó cho biết private memory pages của process
có phần nằm trong swap; không nên lập tức kết luận chính process đó đang
gây ra active swapping.

------------------------------------------------------------------------

## 5.5 AHF là gì?

AHF = **Oracle Autonomous Health Framework**.

Nó phục vụ monitoring/diagnostics/health collection và các thành phần
chẩn đoán Oracle liên quan.

Nếu AHF process có lượng `VmSwap` lớn, điều đó cho biết process đang có
pages trong swap.

Nhưng:

``` text
Process có 10 GB VmSwap
```

**không tương đương với**

``` text
Process đang swap 10 GB mỗi giây
```

Đây là hai khái niệm khác nhau.

------------------------------------------------------------------------

# 6. Swap Used và Active Swapping

Đây là điểm quan trọng khi troubleshooting.

### Swap Used

``` bash
free -h
```

cho biết lượng page hiện đang nằm trong swap.

### Active swapping

Kiểm tra:

``` bash
vmstat 1
```

Chú ý:

``` text
si = swap in
so = swap out
```

Nếu liên tục:

``` text
si = 0
so = 0
```

trong khi `free -h` vẫn báo 25 GB swap used, có khả năng đó là
**historical/cold swapped pages**, không phải hệ thống đang thrashing
ngay lúc đó.

Nếu:

``` text
si > 0
so > 0
```

cao và kéo dài, kết hợp với memory pressure/latency, mới đáng lo về
active swapping.

Do đó troubleshooting đúng hướng:

``` text
Swap Used cao
    ↓
Đừng swapoff ngay
    ↓
Xem vmstat si/so
    ↓
Xem MemAvailable
    ↓
Xác định process VmSwap
    ↓
Kiểm tra SGA/PGA/process khác
    ↓
Tìm root cause
```

------------------------------------------------------------------------

# 7. Script tự động `swapoff` / `swapon`

Ví dụ:

``` bash
THRESHOLD=$((512 * 1024 * 1024))
SWAP_USED=$(free -b | awk '/^Swap:/ {print $3}')
MEM_AVAILABLE=$(free -b | awk '/^Mem:/ {print $7}')

if [ "$SWAP_USED" -gt "$THRESHOLD" ]; then
    if [ "$MEM_AVAILABLE" -gt "$SWAP_USED" ]; then
        /sbin/swapoff -a
        /sbin/swapon -a
    fi
fi
```

### `swapoff -a`

Disable toàn bộ configured swap và buộc các swapped pages cần thiết quay
lại RAM nếu hệ thống có thể thực hiện.

### `swapon -a`

Enable lại các swap area được cấu hình.

Nó **không phải lệnh xóa dữ liệu kiểu file delete**.

### Rủi ro

Chỉ thấy:

``` text
Swap Used > 512 MB
```

không đủ để kết luận cần clear swap.

Nếu RAM headroom thấp, `swapoff` có thể tạo memory pressure rất mạnh,
thậm chí dẫn đến OOM/rủi ro dịch vụ.

Với production Oracle, nên xem việc này là một **controlled
remediation** sau khi hiểu root cause, thay vì housekeeping chạy mù theo
lịch.

------------------------------------------------------------------------

# 8. Cron và PATH

Cron:

``` cron
0 20-23 * * * /root/scripts/check_clear_swap.sh
```

có nghĩa chạy:

``` text
20:00
21:00
22:00
23:00
```

mỗi ngày.

Không phải chỉ chạy một lần lúc 20:00.

Một lần/ngày lúc 20:00:

``` cron
0 20 * * * /root/scripts/check_clear_swap.sh
```

## Vì sao `/sbin/swapoff` chạy dù không `export PATH`?

Vì:

``` bash
/sbin/swapoff
```

là **absolute path**.

Shell không cần tìm executable trong `$PATH`.

Ngược lại:

``` bash
free
awk
date
```

không có absolute path, nên shell phải tìm chúng trong `$PATH`.

``` text
free
 ↓
search PATH
 ↓
/usr/bin/free
```

Trong khi:

``` text
/sbin/swapoff
 ↓
chạy trực tiếp file đó
```

Cron có environment tối giản và thường có một PATH cơ bản, nhưng không
nên giả định cron sẽ load đầy đủ `.bashrc`, `.profile`, `JAVA_HOME`,
`SPARK_HOME` hay PATH custom của interactive shell.

Script cron quan trọng có thể khai báo rõ:

``` bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
```

hoặc dùng absolute path.

------------------------------------------------------------------------

# 9. HugePages không có nghĩa server không bao giờ swap

Đây là chỗ rất dễ nhầm.

``` text
HugePages
   ↓
chủ yếu SGA
```

Nhưng server còn:

``` text
PGA
Oracle process private memory
AHF / Java
OS services
Application processes
...
```

Các vùng này vẫn có thể sử dụng normal pages và chịu swap/memory
pressure.

Do đó hoàn toàn có thể xảy ra:

``` text
Oracle SGA dùng HugePages đúng
+
Linux vẫn báo Swap Used > 0
```

Hai việc này **không mâu thuẫn**.

------------------------------------------------------------------------

# 10. RAC: Datafile đặt nhầm local filesystem thay vì ASM

## Cơ chế

Trong Oracle RAC, nhiều database instances trên nhiều node cùng truy cập
một database.

Datafile vì thế cần nằm trên storage mà các RAC nodes có thể truy cập,
phổ biến là ASM:

``` text
RAC Node 1 ─┐
            ├── +DATA (ASM/shared storage)
RAC Node 2 ─┘
```

Nếu DBA vô tình:

``` sql
ADD DATAFILE '/u01/datafile/xxx.dbf';
```

và `/u01` là local filesystem riêng của Node 1:

``` text
Node 1 → thấy file
Node 2 → không thấy file
```

Controlfile/database metadata biết datafile tồn tại nhưng instance trên
node khác không truy cập được physical file.

Có thể gặp lỗi liên quan không identify/lock/open datafile, ví dụ
ORA-01157 cùng thông tin file liên quan.

## Hướng xử lý

Nếu version/điều kiện hỗ trợ online datafile move:

``` sql
ALTER DATABASE MOVE DATAFILE
'/u01/datafile/xxx.dbf'
TO '+DATA';
```

Mục tiêu:

``` text
Local /u01
    ↓
Shared ASM +DATA
    ↓
mọi RAC instance truy cập được
```

Sau đó verify datafile location/status và service/database state.

Nếu không thể online move thì có thể cần quy trình
offline/copy/switch/recovery phù hợp, thường dùng RMAN và maintenance
procedure.

### Root cause cần nhớ

> Trong RAC, vấn đề không phải `/u01` tự thân xấu; vấn đề là **datafile
> nằm trên storage không shared giữa các RAC instances**.

------------------------------------------------------------------------

# 11. "Pool ghi lớn" khi maintenance database

Nếu ứng dụng có queue/buffer đủ lớn, write có thể tạm thời được giữ bên
ngoài DB:

``` text
Application
    ↓
Queue / Buffer
    ↓
Database
```

Trong maintenance:

``` text
Application
    ↓
Queue giữ backlog
    X
Database tạm unavailable
```

DB hoạt động trở lại:

``` text
Queue
 ↓
consumer drain backlog
 ↓
Database
```

Ví dụ kiến trúc có thể sử dụng Kafka/message queue.

Đây là **application architecture**, không phải một tính năng mặc định
của Oracle connection pool.

------------------------------------------------------------------------

# 12. FIO: benchmark storage trước migration

Ví dụ:

``` bash
fio \
  --name=u01_randrw \
  --filename=/u01/fio_test.dat \
  --size=10G \
  --direct=1 \
  --rw=randrw \
  --rwmixread=70 \
  --bs=8k \
  --iodepth=32 \
  --numjobs=4 \
  --runtime=120 \
  --time_based \
  --group_reporting
```

Ý nghĩa:

-   `--filename`: file test.
-   `--size=10G`: kích thước test file.
-   `--direct=1`: direct I/O, giảm ảnh hưởng page cache.
-   `--rw=randrw`: random mixed read/write.
-   `--rwmixread=70`: mục tiêu workload khoảng 70% read, 30% write.
-   `--bs=8k`: mỗi I/O request 8 KiB.
-   `--iodepth=32`: queue depth.
-   `--numjobs=4`: 4 workers/jobs.
-   `--runtime=120`: chạy 120 giây.
-   `--time_based`: chạy theo thời gian.
-   `--group_reporting`: tổng hợp kết quả.

## IOPS

IOPS = **Input/Output Operations Per Second**.

Ví dụ FIO trả:

``` text
read:  IOPS=19.7k
write: IOPS=8.4k
```

nghĩa là khoảng:

``` text
19,700 read operations / second
8,400  write operations / second
```

Tổng xấp xỉ:

``` text
19.7k + 8.4k = 28.1k IOPS
```

Quan trọng:

> `19.7k` và `8.4k` là **kết quả FIO đo được**, không phải con số tính
> trực tiếp từ `iodepth`, `numjobs`, `bs`.

Vì workload đặt `70% read / 30% write`, nếu total đo được khoảng 28.1k
thì:

``` text
28.1k × 70% ≈ 19.7k
28.1k × 30% ≈ 8.4k
```

Nhưng **28.1k total IOPS vẫn là performance thực tế FIO benchmark được
từ storage**.

Khi benchmark DB storage, không chỉ nhìn IOPS. Cần quan tâm thêm:

``` text
IOPS
Bandwidth
Latency
P95/P99/P99.9 latency
```

Và phải benchmark old/new storage bằng workload profile tương đương.

------------------------------------------------------------------------

# 13. Oracle RAC: Sequence và Index Contention

Giả sử:

``` sql
CREATE SEQUENCE orders_seq
CACHE 50000
NOORDER;
```

và:

``` sql
INSERT INTO orders(id, ...)
VALUES (orders_seq.NEXTVAL, ...);
```

Sequence tạo ID tăng dần:

``` text
1001
1002
1003
1004
...
```

Nếu `id` được index bằng B-tree, các INSERT mới có xu hướng đi về
**right-most/high-key area** của index.

``` text
B-tree index

[low keys] [....] [....] [highest keys]
                              ↑
                         INSERT mới
```

Trong workload concurrent cao, khu vực này có thể trở thành hot
block/hot leaf area.

Trong RAC:

``` text
Instance 1 ─┐
            ├── tranh chấp/cần current version của index blocks
Instance 2 ─┘
```

Global Cache Service có thể phải phối hợp/chuyển block giữa instance
caches, làm tăng interconnect/GCS overhead và giảm throughput nếu
contention cao.

### CACHE giải quyết cái gì?

``` sql
CACHE 50000
```

giảm tần suất Oracle phải cấp phát sequence values từ sequence metadata.

Nó chủ yếu giải quyết:

> **sequence allocation overhead**

Nó không tự động giải quyết hoàn toàn:

> **right-most index hot-block contention**

### NOORDER

Trong RAC:

``` sql
NOORDER
```

cho phép các instances lấy sequence values mà không phải đảm bảo một
global issuance order nghiêm ngặt.

Mục tiêu là throughput/scalability.

Không nên dùng sequence value như bằng chứng tuyệt đối về **commit
order**.

### Sequence có gap

`CACHE` có thể làm mất unused cached values khi instance
restart/failure.

Nhưng kể cả `NOCACHE`, sequence **không đảm bảo gapless**, vì:

``` text
NEXTVAL
 ↓
transaction rollback
 ↓
sequence value không quay lại
```

Nếu business bắt buộc numbering không có gap, cần thiết kế cơ chế
business numbering/serialization riêng.

### Câu phỏng vấn nên nhớ

> `CACHE` giảm sequence allocation overhead; monotonically increasing
> indexed keys mới là nguyên nhân có thể làm INSERT tập trung vào
> right-most B-tree leaf blocks.

Các hướng khác tùy workload có thể gồm reverse-key index, partitioning
hoặc sequence/index design khác; phải benchmark theo access pattern thực
tế.

------------------------------------------------------------------------

# 14. Oracle 19c Release Update (RU) Patching

Oracle 19c được duy trì bằng các **Release Update (RU)** định kỳ.

Ví dụ:

``` text
19.18
  ↓
19.30
```

đây vẫn là **Oracle Database 19c**, nhưng ở patch/RU level mới hơn.

RU thường chứa security fixes, bug fixes, regression fixes và các cập
nhật liên quan.

RUs có tính **cumulative**, vì vậy về nguyên tắc không phải cài lần lượt
từng RU trung gian, nhưng luôn phải đọc README, prerequisites, OPatch
requirements và conflict checks của RU đích.

Quy trình production nên theo hướng:

``` text
Đọc README / Known Issues
        ↓
DEV / TEST
        ↓
Regression/Application test
        ↓
Backup + rollback plan
        ↓
Change/Maintenance window
        ↓
Patch PROD
        ↓
datapatch
        ↓
Validation
```

Trong RAC/Grid Infrastructure còn phải phân biệt:

``` text
Grid Infrastructure Home
Database Oracle Home
OPatch / OPatchAuto
datapatch
```

Một số patch/RU hỗ trợ rolling theo điều kiện tương ứng, cho phép patch
từng node để giảm downtime.

Không nên hiểu patching là:

``` text
có RU mới → lập tức patch production
```

mà là:

``` text
Oracle phát hành maintenance/security update
              ↓
DBA đánh giá + test
              ↓
triển khai theo patch policy của tổ chức
```

------------------------------------------------------------------------

# 15. MongoDB Sharding và Shard Key

## Sharding giải quyết vấn đề gì?

Khi một collection quá lớn hoặc workload vượt khả năng một
server/replica set, MongoDB có thể phân phối data trên nhiều **shard**.

``` text
Application
    ↓
  mongos
    ↓
┌────────┬────────┬────────┐
Shard A  Shard B  Shard C
```

**Shard key** là field hoặc nhóm field MongoDB dùng để xác định cách
document được phân vùng/routing trong sharded collection.

Ví dụ:

``` json
{
  "_id": 1,
  "customer_id": 123,
  "amount": 500000
}
```

Shard key:

``` javascript
{ customer_id: 1 }
```

------------------------------------------------------------------------

## 16. Cardinality của Shard Key

Giả sử có 100 triệu documents nhưng chọn:

``` text
username
```

và tất cả đều:

``` text
username = "banks"
```

thì shard key có cardinality cực thấp.

``` text
banks
banks
banks
banks
...
```

MongoDB không có đủ key-space diversity để phân phối dữ liệu hiệu quả
như mong muốn.

Có 5 shard nhưng workload/data có thể bị tập trung nghiêm trọng.

### Cardinality

Cardinality = số lượng giá trị distinct.

``` text
gender
male/female
→ cardinality ≈ 2

customer_id
1 ... 10,000,000
→ cardinality ≈ 10 triệu
```

Shard key thường cần cardinality đủ cao, nhưng **cardinality cao một
mình chưa đủ**.

------------------------------------------------------------------------

# 17. Distribution và hotspot

Ví dụ:

``` javascript
{ timestamp: 1 }
```

Timestamp có cardinality rất cao.

Nhưng insert mới luôn có timestamp ngày càng lớn:

``` text
10:00
10:01
10:02
10:03
...
```

Với ranged sharding, write có thể tập trung vào vùng key mới nhất và tạo
hotspot.

Do đó thiết kế shard key phải xem đồng thời:

``` text
Cardinality
+
Frequency distribution
+
Write distribution
+
Query pattern
```

------------------------------------------------------------------------

# 18. Hashed Shard Key

Ví dụ:

``` javascript
{ customer_id: "hashed" }
```

MongoDB hash giá trị trước khi dùng nó để phân phối:

``` text
customer 1 → hash → vùng A
customer 2 → hash → vùng C
customer 3 → hash → vùng B
...
```

Ưu điểm:

``` text
write distribution thường đều hơn
```

Đổi lại, range locality của giá trị gốc bị mất.

Query kiểu:

``` text
customer_id >= 1000 AND customer_id <= 2000
```

không còn tương ứng với một vùng hash liên tục.

Do đó hashed shard key thường tốt cho distribution nhưng không tối ưu
cho các range query dựa trên giá trị gốc.

------------------------------------------------------------------------

# 19. Targeted Query và Scatter-Gather

Nếu shard key là:

``` javascript
{ customer_id: 1 }
```

query:

``` javascript
find({ customer_id: 123 })
```

có thể cho phép `mongos` xác định shard đích:

``` text
mongos
  ↓
Shard B
```

Đây là **targeted query**.

Nếu query:

``` javascript
find({ status: "PAID" })
```

và predicate không đủ thông tin để route theo shard key:

``` text
          mongos
      ↙     ↓     ↘
   Shard A Shard B Shard C
      ↘     ↓     ↙
       merge result
```

Đây là **scatter-gather**.

Scatter-gather không phải lúc nào cũng sai, nhưng query quan
trọng/frequent mà luôn fan-out toàn cluster sẽ làm scalability kém.

------------------------------------------------------------------------

# 20. Compound Shard Key

Nếu một field không đạt đồng thời distribution và query locality, có thể
dùng compound key:

``` javascript
{ tenant_id: 1, order_id: 1 }
```

Ví dụ mục tiêu:

``` text
tenant_id
→ giúp các query theo tenant có routing/locality phù hợp

order_id
→ tăng cardinality và phân biệt documents
```

Thứ tự field quan trọng:

``` javascript
{ tenant_id: 1, order_id: 1 }
```

không tương đương về access/routing characteristics với:

``` javascript
{ order_id: 1, tenant_id: 1 }
```

------------------------------------------------------------------------

# 21. Hai mục tiêu của shard-key design

Một shard key tốt cố gắng cân bằng:

``` text
             SHARD KEY
                 │
        ┌────────┴────────┐
        ↓                 ↓
      WRITE              READ
        ↓                 ↓
phân tán workload     targeted query
giữa các shard        ít shard nhất có thể
```

Đây là trade-off.

-   Hashed key có thể phân tán write tốt nhưng làm mất range locality.
-   Ranged key có thể thuận lợi cho một số query nhưng có nguy cơ
    hotspot nếu key tăng đơn điệu.
-   Compound key có thể cân bằng các yêu cầu, nhưng phải thiết kế dựa
    trên workload thực tế.

> **Không có shard key "tốt nhất cho mọi hệ thống". Shard key phải được
> chọn dựa trên data distribution + read pattern + write pattern.**

------------------------------------------------------------------------

# 22. Kiến trúc Shard và Replica Set

Không nên hiểu:

``` text
3 nodes = 3 production shards
```

Một shard production thường được triển khai dưới dạng **replica set**.

Ví dụ:

``` text
Shard 1
├── Primary
├── Secondary
└── Secondary

Shard 2
├── Primary
├── Secondary
└── Secondary

Shard 3
├── Primary
├── Secondary
└── Secondary
```

Ba shard, mỗi shard ba data-bearing members, có thể tương ứng 9 `mongod`
members, chưa kể config server replica set và các `mongos` routers.

------------------------------------------------------------------------

# 23. Resharding

Nếu shard key ban đầu không còn phù hợp, MongoDB các version hiện đại hỗ
trợ **resharding** để thay đổi shard key theo các điều kiện và quy trình
được MongoDB hỗ trợ.

Đây vẫn là operation cần capacity planning, testing và theo dõi kỹ;
không nên xem việc chọn shard key ban đầu là không quan trọng chỉ vì có
resharding.

------------------------------------------------------------------------

# 24. Checklist troubleshooting nhanh

## Oracle memory/swap

``` text
1. free -h
2. vmstat 1 → si/so
3. /proc/PID/status → VmSwap
4. kiểm tra SGA/PGA
5. grep Huge /proc/meminfo
6. alert log → HugePages allocation
7. kiểm tra memlock
8. kiểm tra THP
9. tìm root cause trước khi swapoff
```

## RAC datafile

``` text
1. File nằm ở đâu?
2. Local filesystem hay shared storage?
3. Node nào nhìn thấy file?
4. Có thể online MOVE DATAFILE không?
5. Move sang ASM/shared storage
6. Verify v$datafile / instance / service
```

## Storage benchmark

``` text
1. Xác định workload profile
2. FIO direct I/O
3. random/sequential?
4. read/write ratio?
5. block size?
6. IOPS
7. bandwidth
8. latency percentiles
9. benchmark old/new bằng cùng profile
```

## MongoDB shard key

``` text
1. Cardinality đủ cao?
2. Distribution có skew?
3. Write có hotspot?
4. Query phổ biến có shard-key predicate?
5. Targeted hay scatter-gather?
6. Range hay hashed?
7. Có cần compound key?
8. Benchmark bằng workload thật
```

------------------------------------------------------------------------

# 25. Các câu cần nhớ khi phỏng vấn

### HugePages

> HugePages giảm số lượng memory pages/page-table entries cho SGA lớn,
> giúp giảm memory-management/TLB overhead. Cần kiểm tra HugePages
> sizing, memlock và THP.

### Swap

> Swap Used cao không đồng nghĩa đang active swapping. Tôi sẽ kiểm tra
> `vmstat` si/so, MemAvailable và `VmSwap` theo process trước khi xử lý.

### RAC datafile

> RAC datafile phải nằm trên storage mà tất cả instances truy cập được.
> Nếu file bị tạo trên local filesystem, cần contain impact và move/copy
> nó sang shared storage như ASM rồi verify.

### Sequence contention

> Sequence CACHE giảm sequence allocation overhead; monotonically
> increasing indexed keys mới là nguyên nhân có thể tạo right-edge
> B-tree contention khi concurrent inserts cao.

### FIO

> IOPS là kết quả storage thực sự xử lý được dưới workload profile đã
> cấu hình; `iodepth`, `numjobs` và block size là tải tạo ra, không phải
> công thức trực tiếp để suy ra IOPS.

### MongoDB

> Shard key tốt phải cân bằng write distribution và query targeting.
> Cardinality cao là cần thiết trong nhiều workload nhưng không đủ; phải
> xét distribution và query pattern.

------------------------------------------------------------------------

## Mental model tổng thể

Các bài toán trên nhìn khác nhau nhưng đều có chung tư duy DBA:

``` text
Hiểu cơ chế
    ↓
Xác định resource/data được phân bố thế nào
    ↓
Đo bằng metric đúng
    ↓
Xác định bottleneck/root cause
    ↓
Contain impact
    ↓
Fix
    ↓
Verify
```

Không nên thấy một metric bất thường rồi xử lý ngay:

``` text
Swap cao    → không tự động swapoff
IOPS thấp   → không tự động kết luận disk hỏng
Shard lệch  → không tự động add shard
RAC lỗi     → không tự động restart database
```

DBA trước hết phải xác định **cơ chế nào tạo ra triệu chứng**, sau đó
mới chọn biện pháp xử lý.


---

# 26. Oracle Process, Thread, Connection Pool, SGA và PGA

Phần này dùng để nối toàn bộ kiến thức Oracle memory với cách một request từ application đi vào database.

## 26.1 Mental model tổng thể

Khi application kết nối Oracle, luồng đơn giản có thể hình dung:

```text
Application
    ↓
Connection Pool
    ↓
Oracle Listener
    ↓
Server Process
    ↓
SQL execution
    ↓
SGA + PGA
    ↓
Datafile / Redo / Temp
```

Các khái niệm này khác nhau:

```text
Connection
≠ Process
≠ Thread
≠ Session
≠ SGA
≠ PGA
```

---

# 27. Process là gì?

**Process** là một chương trình đang chạy và được OS cấp PID riêng.

Ví dụ Linux:

```bash
ps -ef | grep ora_
```

có thể thấy:

```text
ora_pmon_ORCL
ora_smon_ORCL
ora_dbw0_ORCL
ora_lgwr_ORCL
ora_ckpt_ORCL
ora_p000_ORCL
```

Mỗi dòng thường là một OS process.

Một process có:

```text
PID
address space
CPU state
open files
private memory
```

Trong Oracle có hai nhóm lớn:

```text
Oracle Processes
├── Background Processes
└── Server Processes
```

---

# 28. Background Process là gì?

Background processes phục vụ instance chứ không đại diện trực tiếp cho một user request.

Các process quan trọng:

### PMON

```text
Process Monitor
```

Theo dõi và cleanup một số process/session bất thường, tham gia service registration tùy kiến trúc/version.

### SMON

```text
System Monitor
```

Thực hiện instance recovery và một số cleanup hệ thống.

### DBWn

```text
Database Writer
```

Ghi **dirty buffers** từ Buffer Cache xuống datafile.

```text
UPDATE
  ↓
Buffer Cache thay đổi
  ↓
dirty buffer
  ↓
DBWn
  ↓
datafile
```

### LGWR

```text
Log Writer
```

Ghi redo từ Redo Log Buffer xuống Online Redo Log.

```text
Transaction
  ↓
Redo Log Buffer
  ↓
LGWR
  ↓
Online Redo Log
```

Khi `COMMIT`, Oracle đặc biệt quan tâm redo phải được flush phù hợp trước khi xác nhận commit cho client.

### CKPT

```text
Checkpoint Process
```

Phối hợp checkpoint và cập nhật metadata/header liên quan; không phải process chính đi ghi toàn bộ dirty data block thay DBWn.

### ARCn

```text
Archiver
```

Khi chạy ARCHIVELOG mode:

```text
Online Redo Log
    ↓
ARCn
    ↓
Archived Redo Log
```

### MMON/MMNL

Phục vụ monitoring và statistics-related background work.

### P000, P001...

Là Parallel Execution Servers.

Khi một SQL chạy parallel:

```text
Query Coordinator
      ↓
 ┌────┼────┐
P000 P001 P002 ...
```

---

# 29. Server Process là gì?

Server process là process thực hiện công việc SQL thay cho client/session.

Ví dụ:

```text
Application
    ↓
Oracle Net
    ↓
Server Process
    ↓
parse
execute
fetch
```

Nó có thể:

```text
đọc block từ Buffer Cache
đọc block từ disk
sort
hash join
execute PL/SQL
tạo redo
sử dụng PGA
truy cập SGA
```

---

# 30. Dedicated Server

Mô hình phổ biến:

```text
Client 1 ── Session 1 ── Server Process 1
Client 2 ── Session 2 ── Server Process 2
Client 3 ── Session 3 ── Server Process 3
```

Tức là gần như:

```text
1 active client connection
        ↓
1 dedicated server process
```

Ưu điểm:

```text
đơn giản
predictable
phù hợp workload phổ biến
```

Nhược điểm:

Nếu có quá nhiều connection:

```text
10,000 connections
      ↓
rất nhiều server processes
      ↓
PGA + OS process overhead tăng
```

Do đó application thường dùng **connection pool**.

---

# 31. Shared Server

Oracle cũng có mô hình Shared Server.

Khái niệm đơn giản:

```text
Nhiều sessions
     ↓
Dispatcher
     ↓
Shared Server Processes
```

Thay vì mỗi client giữ riêng một dedicated server process, nhiều sessions có thể chia sẻ một tập server processes.

Mental model:

```text
Client A ─┐
Client B ─┼→ Dispatcher → Request Queue → Shared Server
Client C ─┘
```

Shared Server giúp giảm số lượng server processes trong workload có rất nhiều concurrent connections nhưng không phải session nào cũng liên tục chạy SQL.

Tuy nhiên kiến trúc và memory placement khác Dedicated Server ở một số điểm, nên khi troubleshooting phải biết database đang dùng mode nào.

---

# 32. Thread là gì?

**Thread** là execution unit nằm bên trong một process.

Mental model:

```text
Process
├── Thread 1
├── Thread 2
└── Thread 3
```

Các threads trong cùng process chia sẻ phần lớn address space của process.

So sánh:

```text
Process A          Process B
memory riêng       memory riêng
PID A              PID B

Process A
├── Thread 1
├── Thread 2
└── Thread 3
    ↑
chia sẻ address space của Process A
```

Trên Linux Oracle Database truyền thống thường dễ quan sát dưới dạng nhiều OS processes.

Điều quan trọng khi học Oracle là không đồng nhất:

```text
Oracle Process
```

với:

```text
Application Thread
```

Một Java application có thể có hàng trăm threads nhưng chỉ dùng một số lượng connection Oracle giới hạn bởi connection pool.

---

# 33. Connection là gì?

Connection là đường giao tiếp network giữa client và Oracle.

Ví dụ:

```text
Java App
   ↓ TCP
Oracle Listener
   ↓
Oracle Database
```

Connection không phải bản thân SQL session logic, mặc dù trong thực tế hai khái niệm thường đi sát nhau.

---

# 34. Session là gì?

**Session** là logical database login/context bên trong Oracle.

Session chứa context như:

```text
user
NLS settings
transaction state
session state
SQL context
```

Có thể xem:

```sql
SELECT sid, serial#, username, status
FROM v$session;
```

Mental model đơn giản:

```text
TCP Connection
      ↓
Oracle Session
      ↓
Server Process
```

Trong Dedicated Server thường mapping khá trực quan.

Nhưng không nên học thuộc tuyệt đối:

```text
1 session = 1 process
```

vì Shared Server và một số kiến trúc khác làm mapping phức tạp hơn.

---

# 35. Connection Pool là gì?

Connection Pool thường nằm ở **application side** hoặc middleware side.

Ví dụ Java:

```text
Application
    ↓
HikariCP / UCP
    ↓
20 Oracle Connections
```

Thay vì mỗi HTTP request:

```text
request
  ↓
create DB connection
  ↓
login/authentication
  ↓
SQL
  ↓
disconnect
```

application tạo sẵn một pool:

```text
Pool
├── Connection 1
├── Connection 2
├── Connection 3
...
└── Connection 20
```

Khi request tới:

```text
Request A → mượn Connection 3
Request B → mượn Connection 7
Request C → chờ nếu pool hết
```

xử lý xong:

```text
Connection trả lại pool
```

chứ không nhất thiết đóng physical DB connection.

---

# 36. Tại sao cần Connection Pool?

Tạo Oracle connection có overhead:

```text
TCP setup
authentication
session creation
server process/session resources
```

Nếu app liên tục:

```text
connect
query
disconnect
```

với hàng nghìn requests/giây thì rất lãng phí.

Connection pool:

```text
create connection một lần
        ↓
reuse nhiều lần
```

giúp giảm:

```text
connection setup overhead
login storm
server process churn
```

---

# 37. Connection Pool quá lớn có thể gây gì?

Không phải pool càng lớn càng nhanh.

Ví dụ:

```text
App Server 1: pool 200
App Server 2: pool 200
App Server 3: pool 200
App Server 4: pool 200
```

Tổng:

```text
800 DB connections
```

Nếu Dedicated Server:

```text
≈ rất nhiều Oracle server processes
```

Mỗi server process có PGA/private memory.

Nếu mỗi process trung bình 100 MB private memory:

```text
800 × 100 MB
≈ 80 GB
```

Đây chỉ là ví dụ minh họa, PGA thực tế thay đổi theo workload.

Do đó:

> Connection pool sizing là bài toán concurrency + DB capacity, không phải đặt số càng lớn càng tốt.

---

# 38. Thread Pool khác Connection Pool

Hai khái niệm rất dễ nhầm.

### Thread Pool

Quản lý **CPU execution workers** của application.

```text
HTTP Requests
    ↓
Thread Pool
├── Worker 1
├── Worker 2
├── Worker 3
└── Worker 4
```

### Connection Pool

Quản lý **database connections**.

```text
DB Calls
   ↓
Connection Pool
├── Conn 1
├── Conn 2
├── Conn 3
└── Conn 4
```

Một application có thể:

```text
100 worker threads
20 DB connections
```

Khi hơn 20 threads cùng lúc cần DB:

```text
20 threads → có connection
80 threads → chờ
```

Do đó:

```text
Thread Pool Size
≠
Connection Pool Size
```

---

# 39. SGA là gì?

SGA = **System Global Area**.

Đây là vùng memory **shared bởi các Oracle processes của instance**.

Mental model:

```text
Oracle Instance
     │
     ├── SGA
     │    ↑
     │    shared
     │
     ├── Server Process 1
     ├── Server Process 2
     ├── DBWn
     └── LGWR
```

Các process cùng instance có thể truy cập các cấu trúc shared trong SGA.

Các thành phần quan trọng gồm:

```text
SGA
├── Database Buffer Cache
├── Shared Pool
│   ├── Library Cache
│   └── Data Dictionary Cache
├── Redo Log Buffer
├── Large Pool
├── Java Pool
└── Streams Pool
```

Không phải database nào cũng sử dụng mọi optional pool với kích thước lớn.

---

# 40. Database Buffer Cache

Buffer Cache lưu các **database blocks** đã/đang được truy cập trong RAM.

Ví dụ:

```sql
SELECT *
FROM customers
WHERE id = 100;
```

Nếu block đã có trong Buffer Cache:

```text
Server Process
      ↓
Buffer Cache
      ↓
RAM access
```

Nếu chưa có:

```text
Server Process
      ↓
Datafile read
      ↓
Buffer Cache
      ↓
return data
```

Khi UPDATE:

```text
block trong Buffer Cache
      ↓
modify
      ↓
dirty buffer
      ↓
DBWn ghi xuống datafile sau đó
```

Oracle không cần ghi datafile ngay tại thời điểm mỗi `COMMIT`.

Redo durability và data block write là hai cơ chế khác nhau.

---

# 41. Shared Pool

Shared Pool chứa nhiều shared structures, nổi bật là:

```text
Library Cache
Data Dictionary Cache
```

### Library Cache

Giữ:

```text
parsed SQL
PL/SQL
execution-related shared structures
```

Ví dụ nhiều session chạy:

```sql
SELECT * FROM users WHERE id = :id;
```

Oracle có thể reuse parsed/shared structures tốt hơn so với hard parse liên tục.

### Data Dictionary Cache

Cache metadata:

```text
tables
columns
users
privileges
objects
```

---

# 42. Redo Log Buffer

Redo Log Buffer nằm trong SGA.

Khi database thay đổi data:

```text
UPDATE
  ↓
change information
  ↓
Redo Log Buffer
  ↓
LGWR
  ↓
Online Redo Log
```

Redo phục vụ recovery/durability.

Một cách nhớ:

```text
Data block → Buffer Cache → DBWn → Datafile

Redo      → Redo Log Buffer → LGWR → Online Redo Log
```

Hai đường đi khác nhau.

---

# 43. Large Pool

Large Pool có thể được dùng cho các workload/cấu trúc như:

```text
RMAN
Shared Server
Parallel Execution
một số large allocations
```

Việc có Large Pool giúp giảm áp lực phải lấy một số allocation lớn từ Shared Pool.

---

# 44. PGA là gì?

PGA = **Program Global Area**.

Đây là private memory gắn với Oracle server/background process, không shared giống SGA.

Mental model:

```text
Server Process 1
└── PGA 1

Server Process 2
└── PGA 2

Server Process 3
└── PGA 3

       ↓
tất cả cùng truy cập
       ↓
      SGA
```

Nếu có nhiều server processes:

```text
nhiều process
    ↓
nhiều PGA allocations
```

Vì vậy số connections/processes có thể ảnh hưởng rất mạnh đến total PGA/private memory.

---

# 45. PGA chứa gì?

PGA thường liên quan đến:

```text
sort
hash join
bitmap operations
session/process private state
work areas
```

Ví dụ:

```sql
SELECT ...
FROM A
JOIN B ...
ORDER BY ...
```

Server process có thể cần memory cho:

```text
Hash Area
Sort Area
```

Nếu work area đủ RAM:

```text
optimal execution
```

Nếu không đủ:

```text
spill xuống TEMP
```

---

# 46. PGA và TEMP

Ví dụ sort 20 GB nhưng work area chỉ được cấp 2 GB.

Không có nghĩa Oracle bắt buộc đưa cả 20 GB vào PGA.

Có thể xảy ra:

```text
sort/hash operation
      ↓
PGA không đủ
      ↓
spill
      ↓
TEMP tablespace
```

Do đó query chậm có thể liên quan:

```text
PGA pressure
TEMP I/O
```

Không nên chỉ nhìn CPU.

---

# 47. SGA vs PGA

Bảng nhớ nhanh:

| Đặc điểm | SGA | PGA |
|---|---|---|
| Shared/private | Shared | Private |
| Thuộc | Instance | Process |
| Buffer Cache | Có | Không |
| Shared Pool | Có | Không |
| Redo Log Buffer | Có | Không |
| Sort/hash work area | Không phải nơi chính | Có |
| HugePages | Chủ yếu dùng cho SGA | Không phải mục tiêu chính |
| Tăng theo số process | Không tuyến tính như PGA | Có thể tăng mạnh |

Mental model:

```text
             Oracle Instance
                   │
        ┌──────────┴──────────┐
        ↓                     ↓
       SGA               Oracle Processes
     shared               ├── Process 1 → PGA 1
                          ├── Process 2 → PGA 2
                          └── Process 3 → PGA 3
```

---

# 48. Ví dụ end-to-end một câu SQL

Application có connection pool:

```text
HTTP Request
    ↓
mượn connection từ pool
    ↓
Oracle session
    ↓
Dedicated Server Process
```

SQL:

```sql
SELECT *
FROM orders
WHERE customer_id = :id
ORDER BY created_at;
```

Server process:

```text
1. Parse/lookup SQL
      ↓
   Shared Pool

2. Tìm data block
      ↓
   Buffer Cache

3. Nếu miss
      ↓
   đọc Datafile

4. Nếu phải sort/hash
      ↓
   PGA

5. PGA không đủ
      ↓
   TEMP

6. Trả result
      ↓
   client

7. connection được trả lại pool
```

Đây là flow rất quan trọng khi đi phỏng vấn vì nó nối:

```text
Application
→ connection pool
→ process/session
→ SGA
→ PGA
→ storage
```

---

# 49. Ví dụ UPDATE + COMMIT

```sql
UPDATE accounts
SET balance = balance - 100
WHERE id = 1;

COMMIT;
```

Mental model:

```text
Server Process
     ↓
đọc block vào Buffer Cache nếu cần
     ↓
modify buffer
     ↓
dirty buffer
```

Đồng thời tạo redo:

```text
change
  ↓
Redo Log Buffer
  ↓
LGWR
  ↓
Online Redo Log
```

Khi commit:

```text
COMMIT
  ↓
redo cần được flush phù hợp
  ↓
LGWR
  ↓
commit complete
```

Dirty data block:

```text
không nhất thiết được DBWn ghi xuống datafile ngay tại COMMIT
```

Vì Oracle có thể recovery datafile dựa trên redo.

---

# 50. Vì sao quá nhiều connections làm memory tăng?

Giả sử application pool:

```text
500 DB connections
```

và Dedicated Server.

Có thể có rất nhiều:

```text
server processes
+
PGA/private memory
+
session structures
+
OS process overhead
```

Trong khi SGA:

```text
shared
```

không nhân lên 500 lần.

Mental model:

```text
500 connections
       ↓
~500 server processes
       ↓
500 PGA/private-memory consumers
       ↓
Total memory pressure tăng
```

Đây cũng là lý do một server có SGA HugePages rất đẹp vẫn có thể swap:

```text
SGA protected/using HugePages
        +
PGA/process memory tăng
        +
AHF/Java/OS memory
        ↓
normal RAM pressure
        ↓
swap vẫn có thể xảy ra
```

---

# 51. Login Storm / Connection Storm

Nếu application không dùng pool tốt hoặc toàn bộ app restart đồng thời:

```text
10,000 clients
     ↓
connect cùng lúc
     ↓
authentication
session/process creation
     ↓
CPU + memory spike
```

Đây là **connection/login storm**.

Connection pooling, gradual startup, sane pool limits và DB capacity planning giúp giảm tình trạng này.

---

# 52. Session Pool, Connection Pool và Process Pool

Các từ “pool” phải đọc đúng context.

### Connection Pool

```text
Application giữ sẵn physical DB connections để reuse
```

Ví dụ:

```text
HikariCP
Oracle UCP
```

### Thread Pool

```text
Application giữ sẵn worker threads để xử lý task/request
```

### Shared Server Pool

Oracle giữ một tập shared server processes phục vụ nhiều sessions.

### Parallel Execution Server Pool

Oracle có các PX server processes (`P000`, `P001`...) để phục vụ parallel execution.

Vì vậy nghe từ:

```text
pool
```

không được tự động hiểu là một loại duy nhất.

Phải hỏi:

> Pool của connection, thread, shared server hay parallel execution process?

---

# 53. RAC và Process/Memory

Trong RAC:

```text
Node 1
├── Instance 1
├── SGA 1
└── Oracle processes + PGA

Node 2
├── Instance 2
├── SGA 2
└── Oracle processes + PGA
```

Mỗi RAC instance có **SGA riêng trong RAM của node đó**.

Không phải:

```text
RAC 2 nodes
→ dùng chung một SGA vật lý
```

Mà là:

```text
SGA Node 1
     ↕
Global Cache / interconnect
     ↕
SGA Node 2
```

Oracle RAC phối hợp block state giữa instance buffer caches qua Global Cache Services.

Đây là lý do hot blocks có thể gây RAC cache-fusion/global-cache contention.

---

# 54. Cache Fusion liên quan SGA thế nào?

Ví dụ block X đang ở Buffer Cache của Instance 1.

Instance 2 cần current version của block X:

```text
Instance 1 SGA
Buffer Cache
   block X
      ↓
RAC interconnect
      ↓
Instance 2 SGA
Buffer Cache
```

Oracle cố gắng chuyển block qua interconnect thay vì bắt Instance 2 đọc block từ disk nếu block phù hợp đang ở cache node khác.

Đây là **Cache Fusion**.

Vì vậy:

```text
SGA của mỗi node riêng
+
RAC Global Cache
=
các instances phối hợp như một database cluster
```

---

# 55. Process Memory và Swap

HugePages chủ yếu bảo vệ/tối ưu SGA.

Nhưng:

```text
Server Process PGA
PX process PGA
AHF
Java
OS processes
```

vẫn dùng normal memory.

Do đó khi tìm swap:

```text
/proc/PID/status
→ VmSwap
```

có thể thấy:

```text
ora_p000
ora_p001
AHF process
```

dùng swap dù SGA đang dùng HugePages hoàn toàn bình thường về mặt cơ chế.

Câu cần nhớ:

> HugePages xử lý bài toán SGA page management và locking; nó không biến toàn bộ Oracle host thành môi trường “không thể swap”.

---

# 56. Checklist khi Oracle host memory cao

```text
1. Tổng RAM bao nhiêu?
2. SGA bao nhiêu?
3. PGA aggregate bao nhiêu?
4. Bao nhiêu sessions/processes?
5. Connection pool có tăng bất thường không?
6. Có PX workload không?
7. TEMP có spill lớn không?
8. HugePages đã dùng đúng chưa?
9. memlock đủ chưa?
10. Swap chỉ "used" hay đang active si/so?
11. Process nào có VmSwap lớn?
```

Không nên chỉ nhìn:

```text
free -h
```

rồi kết luận.

---

# 57. Các câu phỏng vấn về Process / SGA / PGA

### SGA là gì?

> SGA là shared memory của Oracle instance, chứa các cấu trúc như Buffer Cache, Shared Pool và Redo Log Buffer để nhiều Oracle processes cùng truy cập.

### PGA là gì?

> PGA là private memory của từng Oracle process, thường chứa work areas cho sort/hash và process/session-private state.

### Dedicated Server là gì?

> Trong Dedicated Server, một client/session thường được phục vụ bởi một dedicated server process; số connection lớn vì thế có thể làm số process và tổng PGA tăng.

### Connection Pool để làm gì?

> Connection Pool reuse các physical database connections, giảm login/session creation overhead và giới hạn concurrency vào database.

### Thread Pool khác Connection Pool thế nào?

> Thread Pool quản lý execution workers của application; Connection Pool quản lý database connections. Hai kích thước này độc lập.

### COMMIT có bắt DBWn ghi data block xuống datafile ngay không?

> Không nhất thiết. COMMIT phụ thuộc redo durability do LGWR đảm bảo; dirty buffers có thể được DBWn ghi xuống datafile sau đó.

### HugePages bảo vệ PGA không?

> Không. HugePages chủ yếu dùng cho SGA; PGA và private process memory vẫn dùng normal memory và có thể chịu swap/memory pressure.

### RAC có dùng chung một SGA không?

> Không. Mỗi RAC instance có SGA riêng trên node của nó; RAC dùng Global Cache/Cache Fusion qua interconnect để phối hợp database blocks giữa các instance caches.

