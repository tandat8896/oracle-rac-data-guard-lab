# Báo cáo Điều tra và Xử lý Sự cố FRA / ORA-19815 (Oracle RAC 19c)

Tài liệu ghi lại toàn bộ chuỗi điều tra, phân tích nguyên nhân gốc rễ (Root Cause Analysis - RCA), các bước remediation giải phóng dung lượng FRA và quy trình chuẩn hóa vận hành trên hệ thống Oracle RAC 19c hai node.

## 1. Kiểm tra FRA tổng thể

    SELECT name, space_limit, space_used, space_reclaimable, number_of_files
    FROM v$recovery_file_dest;

Kết quả lần gần nhất:

    NAME   SPACE_LIMIT    SPACE_USED    SPACE_RECLAIMABLE   NUMBER_OF_FILES
    +FRA   14687404032   12490637312           210763776               252

→ FRA khoảng **13.68 GiB**, đang dùng khoảng **11.63 GiB (\~85%)**.

------------------------------------------------------------------------

## 2. Xem thành phần nào chiếm FRA

    SELECT file_type,
           percent_space_used,
           percent_space_reclaimable,
           number_of_files
    FROM v$recovery_area_usage
    ORDER BY percent_space_used DESC;

Kết quả ghi nhận ban đầu:

    ARCHIVED LOG    ~47.38%   reclaimable 0%   228 files
    BACKUP PIECE    ~17.30%
    REDO LOG        ~14.35%
    FLASHBACK LOG    ~5.74%
    CONTROL FILE     ~0.14%

Lần kiểm tra mới nhất:

    SELECT file_type,
           percent_space_used,
           percent_space_reclaimable
    FROM v$recovery_area_usage
    ORDER BY percent_space_used DESC;

    FILE_TYPE                   PERCENT_SPACE_USED   PERCENT_SPACE_RECLAIMABLE
    ARCHIVED LOG                              47.5                           0
    BACKUP PIECE                              17.3                           0
    REDO LOG                                 14.35                           0
    FLASHBACK LOG                             5.74                        1.43
    CONTROL FILE                              0.14                           0
    AUXILIARY DATAFILE COPY                      0                           0
    IMAGE COPY                                   0                           0
    FOREIGN ARCHIVED LOG                         0                           0

→ Archive log là thành phần lớn nhất và **0% reclaimable**.

------------------------------------------------------------------------

## 3. Đếm archive log trong FRA theo RAC thread

    SELECT thread#,
           COUNT(*) files,
           MIN(completion_time) oldest,
           MAX(completion_time) newest
    FROM v$archived_log
    WHERE is_recovery_dest_file='YES'
      AND deleted='NO'
    GROUP BY thread#
    ORDER BY thread#;

Kết quả:

    THREAD#   FILES   OLDEST       NEWEST
    1         134     04-JUN-26    18-SEP-26
    2          94     01-JUN-26    17-SEP-26

→ Tổng **228 archived logs** lúc đó.

------------------------------------------------------------------------

## 4. Kiểm tra archive đã được backup chưa

    SELECT thread#, backup_count, COUNT(*) files
    FROM v$archived_log
    WHERE is_recovery_dest_file='YES'
      AND deleted='NO'
    GROUP BY thread#, backup_count
    ORDER BY thread#, backup_count;

Kết quả:

    THREAD#   BACKUP_COUNT   FILES
    1         0              134
    2         0               94

→ Toàn bộ archive đang xét có `BACKUP_COUNT = 0`.

------------------------------------------------------------------------

# 5. Sang RMAN kiểm tra configuration

    rman target /

Sau đó:

    SHOW ALL;

Kết quả chính:

    using target database control file instead of recovery catalog

    CONFIGURE RETENTION POLICY TO REDUNDANCY 1;
    CONFIGURE BACKUP OPTIMIZATION OFF;
    CONFIGURE DEFAULT DEVICE TYPE TO DISK;
    CONFIGURE CONTROLFILE AUTOBACKUP ON;
    CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '%F';
    CONFIGURE DEVICE TYPE DISK PARALLELISM 1 BACKUP TYPE TO BACKUPSET;
    CONFIGURE DATAFILE BACKUP COPIES FOR DEVICE TYPE DISK TO 1;
    CONFIGURE ARCHIVELOG BACKUP COPIES FOR DEVICE TYPE DISK TO 1;
    CONFIGURE MAXSETSIZE TO UNLIMITED;
    CONFIGURE ENCRYPTION FOR DATABASE OFF;
    CONFIGURE ENCRYPTION ALGORITHM 'AES128';
    CONFIGURE COMPRESSION ALGORITHM 'BASIC' AS OF RELEASE 'DEFAULT' OPTIMIZE FOR LOAD TRUE;
    CONFIGURE RMAN OUTPUT TO KEEP FOR 7 DAYS;
    CONFIGURE ARCHIVELOG DELETION POLICY TO NONE;
    CONFIGURE SNAPSHOT CONTROLFILE NAME TO
    '/u01/app/oracle/product/19.0.0/dbhome_1/dbs/snapcf_racdb1.f';

Điểm đáng chú ý:

    RETENTION POLICY             = REDUNDANCY 1
    ARCHIVELOG DELETION POLICY   = NONE
    CONTROLFILE AUTOBACKUP       = ON

------------------------------------------------------------------------

## 6. Kiểm tra RMAN backup của archived logs

    LIST BACKUP OF ARCHIVELOG ALL;

Kết quả chỉ có:

    BS Key  Type LV Size    Device Type Elapsed Time Completion Time
    ------- ---- -- ------- ----------- ------------ ---------------
    5       Full    20.50K  DISK        00:00:01     01-JUN-26

    Tag: RACDB_FIRST_RMAN_BACKUP

    Piece Name:
    +FRA/RACDB/BACKUPSET/2026_06_01/annnf0_racdb_first_rman_backup_0.269.1234800161

    Archived Logs:
    Thread 1 Sequence 11
    Thread 2 Sequence 5

→ RMAN chỉ thấy archived-log backup rất cũ từ **01-Jun-26**, gồm thread
1 seq 11 và thread 2 seq 5.

------------------------------------------------------------------------

## 7. Xem toàn bộ backup summary

    LIST BACKUP SUMMARY;

Kết quả:

    Key  TY LV S Device Type Completion Time
    ---- -- -- - ----------- ---------------
    2    B  F  A DISK        01-JUN-26
    3    B  F  A DISK        01-JUN-26
    4    B  F  A DISK        01-JUN-26
    5    B  A  A DISK        01-JUN-26
    6    B  F  A DISK        01-JUN-26
    7    B  F  A DISK        16-JUN-26
    8    B  F  A DISK        16-JUN-26

→ Backup repository trên primary không thể hiện backup mới sau
**16-Jun-26**.

------------------------------------------------------------------------

# 8. Kiểm tra Data Guard standby

Trên standby:

    SELECT instance_name, status
    FROM v$instance;

Kết quả:

    INSTANCE_NAME   STATUS
    racdb_s         MOUNTED

Tiếp:

    SELECT database_role, open_mode
    FROM v$database;

    DATABASE_ROLE       OPEN_MODE
    PHYSICAL STANDBY    MOUNTED

→ Đúng Physical Standby.

------------------------------------------------------------------------

## 9. Kiểm tra Managed Recovery

    SELECT process, status, thread#, sequence#
    FROM v$managed_standby;

Output quan trọng:

    ARCH   CLOSING       2   100
    ARCH   CLOSING       1   145
    ARCH   CLOSING       1   146
    RFS    IDLE          1   147
    RFS    IDLE          2   101
    MRP0   APPLYING_LOG  2   101

→ MRP đang hoạt động và standby đang nhận/apply redo.

------------------------------------------------------------------------

## 10. Kiểm tra archive đã apply trên standby

    SELECT thread#, applied, COUNT(*)
    FROM v$archived_log
    GROUP BY thread#, applied
    ORDER BY thread#, applied;

Kết quả:

    THREAD#   APPLIED   COUNT(*)
    1         YES       77
    2         NO         1
    2         YES       34

Sau đó:

    SELECT thread#, MAX(sequence#) last_applied
    FROM v$archived_log
    WHERE applied='YES'
    GROUP BY thread#
    ORDER BY thread#;

Kết quả tại thời điểm query:

    THREAD#   LAST_APPLIED
    1         146
    2          99

------------------------------------------------------------------------

## 11. Điều tra thread 2 sequence 99--101

    SELECT thread#, sequence#, applied, name
    FROM v$archived_log
    WHERE thread#=2
      AND sequence# BETWEEN 99 AND 101
    ORDER BY sequence#;

Kết quả:

    THREAD# SEQUENCE# APPLIED NAME
    2       99        YES     /u01/app/oracle/oradata/RACDB_S/arch/2_99_1234363305.dbf
    2       100       YES     /u01/app/oracle/oradata/RACDB_S/arch/2_100_1234363305.dbf

Trong khi MRP đã báo đang xử lý sequence 101.

→ Không có evidence rằng standby bị kẹt ở seq 99.

------------------------------------------------------------------------

## 12. So sánh với primary

Trên RAC1:

    SELECT thread#, MAX(sequence#) last_archived
    FROM v$archived_log
    WHERE archived='YES'
    GROUP BY thread#
    ORDER BY thread#;

Kết quả:

    THREAD#   LAST_ARCHIVED
    1         146
    2         100

→ Tại thời điểm kiểm tra, standby đã apply đến **T1/146 và T2/100**,
khớp với archive hoàn chỉnh phía primary; đồng thời standby đang
nhận/apply redo mới hơn.

------------------------------------------------------------------------

# 13. Quay lại RMAN kiểm tra obsolete

    REPORT OBSOLETE;

Kết quả:

    RMAN retention policy is set to redundancy 1

    Report of obsolete backups and copies

    Type          Key   Completion Time   Filename/Handle
    ------------- ----- ----------------- --------------------
    Backup Set    6     01-JUN-26
     Backup Piece 6     01-JUN-26         +FRA/RACDB/AUTOBACKUP/2026_06_01/...

    Backup Set    7     16-JUN-26
     Backup Piece 7     16-JUN-26         +FRA/RACDB/AUTOBACKUP/2026_06_16/...

→ Chỉ có hai backup sets được report obsolete.

------------------------------------------------------------------------

## 14. List toàn bộ archived logs RMAN biết

    LIST ARCHIVELOG ALL;

Output rất dài. Thread 1 bắt đầu từ sequence 12:

    Key   Thrd Seq  S Low Time
    6     1    12   A 01-JUN-26
    Name: +FRA/RACDB/ARCHIVELOG/2026_06_04/thread_1_seq_12...

và kéo tới:

    396   1    146  A 18-SEP-26
    Name: +FRA/RACDB/ARCHIVELOG/2026_09_18/thread_1_seq_146...

Thread 2 bắt đầu từ seq 6 và kéo tới seq 100.

`A` = available.

------------------------------------------------------------------------

## 15. Hỏi RMAN archive nào đã backup ít nhất 1 lần

    LIST ARCHIVELOG ALL BACKED UP 1 TIMES TO DEVICE TYPE DISK;

Kết quả:

    RMAN>

**Không có record nào trả về.**

→ Khớp với `BACKUP_COUNT = 0`.

------------------------------------------------------------------------

# 16. Quay lại SQL kiểm tra archive FRA lần nữa

    SELECT file_type,
           percent_space_used,
           percent_space_reclaimable,
           number_of_files
    FROM v$recovery_area_usage
    WHERE file_type='ARCHIVED LOG';

Kết quả:

    FILE_TYPE      PERCENT_SPACE_USED  PERCENT_SPACE_RECLAIMABLE  NUMBER_OF_FILES
    ARCHIVED LOG   47.5                0                          230

→ Trong lúc điều tra, archive tăng từ **228 → 230 files**.

------------------------------------------------------------------------

## 17. FRA hiện tại

    SELECT name,
           space_limit,
           space_used,
           space_reclaimable,
           number_of_files
    FROM v$recovery_file_dest;

    NAME  SPACE_LIMIT    SPACE_USED    SPACE_RECLAIMABLE  NUMBER_OF_FILES
    +FRA  14687404032    12490637312   210763776          252

------------------------------------------------------------------------

# 18. Kiểm tra FRA parameters

    SELECT name, value
    FROM v$parameter
    WHERE name IN (
        'db_recovery_file_dest',
        'db_recovery_file_dest_size'
    );

Kết quả:

    NAME                         VALUE
    db_recovery_file_dest        +FRA
    db_recovery_file_dest_size   14687404032

------------------------------------------------------------------------

# 19. Kiểm tra Flashback Database

    SELECT flashback_on
    FROM v$database;

    FLASHBACK_ON
    YES

Sau đó:

    SELECT name, value
    FROM v$parameter
    WHERE name='db_flashback_retention_target';

    NAME                            VALUE
    db_flashback_retention_target   1440

→ Retention target = **1440 phút = 24 giờ**.

------------------------------------------------------------------------

## 20. Xem Flashback window thực tế

    SELECT oldest_flashback_time,
           retention_target,
           flashback_size,
           estimated_flashback_size
    FROM v$flashback_database_log;

Kết quả:

    OLDEST_FLASHBACK_TIME  RETENTION_TARGET  FLASHBACK_SIZE  ESTIMATED_FLASHBACK_SIZE
    18-SEP-26              1440              838860800       1474682880

→ Flashback hiện chỉ giữ window quanh 18-Sep, không giải thích archive
tồn từ tháng 6.

------------------------------------------------------------------------

# 21. Checkpoint / current SCN

    SELECT checkpoint_change#, current_scn
    FROM v$database;

    CHECKPOINT_CHANGE#   CURRENT_SCN
    8174736              8178209

→ Delta = 3473 SCN; bản thân chênh lệch này chưa chứng minh archive cũ
đang cần cho recovery.

------------------------------------------------------------------------

# 22. Kiểm tra Guaranteed Restore Point

    SELECT name,
           guarantee_flashback_database,
           time
    FROM v$restore_point;

Kết quả:

    no rows selected

→ Không có restore point.

------------------------------------------------------------------------

# 23. Kiểm tra archive destinations

    SELECT dest_id,
           status,
           target,
           destination
    FROM v$archive_dest
    WHERE status <> 'INACTIVE';

Kết quả:

    DEST_ID STATUS TARGET   DESTINATION
    1       VALID  PRIMARY  USE_DB_RECOVERY_FILE_DEST
    2       VALID  STANDBY  racdb_s

Kiến trúc hiện tại:

    RACDB
     ├── DEST_1 → +FRA
     └── DEST_2 → racdb_s

------------------------------------------------------------------------

# 24. Xem cấu hình Data Guard destination

    SELECT dest_id,
           db_unique_name,
           valid_type,
           valid_role,
           transmit_mode
    FROM v$archive_dest
    WHERE dest_id=2;

Kết quả:

    DEST_ID DB_UNIQUE_NAME VALID_TYPE       VALID_ROLE TRANSMIT_MODE
    2       racdb_s        ONLINE_LOGFILE   ALL_ROLES  ASYNCHRONOUS

------------------------------------------------------------------------

# 25. Kiểm tra trạng thái Data Guard destination

    SELECT dest_id,
           status,
           error,
           archived_thread#,
           archived_seq#
    FROM v$archive_dest_status
    WHERE dest_id=2;

Kết quả:

    DEST_ID STATUS ERROR ARCHIVED_THREAD# ARCHIVED_SEQ#
    2       VALID             1             100

→ `STATUS=VALID`, `ERROR` rỗng.

------------------------------------------------------------------------

# 26. FRA breakdown mới nhất

    SELECT file_type,
           percent_space_used,
           percent_space_reclaimable
    FROM v$recovery_area_usage
    ORDER BY percent_space_used DESC;

Kết quả:

    FILE_TYPE                   USED %    RECLAIMABLE %
    ARCHIVED LOG                 47.5          0
    BACKUP PIECE                 17.3          0
    REDO LOG                    14.35          0
    FLASHBACK LOG                5.74          1.43
    CONTROL FILE                 0.14          0
    AUXILIARY DATAFILE COPY         0          0
    IMAGE COPY                      0          0
    FOREIGN ARCHIVED LOG            0          0

→ Khoảng **201 MiB reclaimable** của FRA gần như đến từ Flashback Log;
**Archived Log vẫn 0% reclaimable**.

------------------------------------------------------------------------

## Trạng thái investigation hiện tại

Giai đoạn này **chưa thực hiện DELETE, chưa CROSSCHECK, chưa BACKUP, chưa thay đổi parameter**.
Tới đây toàn bộ gần như là read-only investigation.

Evidence hiện tại đang chỉ về:

    ORA-19815
       ↓
    FRA ~85%
       ↓
    ARCHIVED LOG = 47.5% FRA
       ↓
    230 archived logs
       ↓
    0% reclaimable
       ↓
    RMAN: archive hiện tại chưa backup
       ↓
    DG: không thấy transport/apply backlog lớn
    Flashback: không giữ window từ tháng 6
    Restore point: không có
       ↓
    → nghi mạnh archive backup/cleanup lifecycle chưa được vận hành

------------------------------------------------------------------------

# 27. Tiếp tục trace archive log ở primary

Từ checkpoint trước, kiểm tra các archived log lâu đời nhất vẫn còn
trong FRA:

``` sql
SELECT thread#, sequence#, applied, deleted, backup_count
FROM v$archived_log
WHERE is_recovery_dest_file='YES'
  AND deleted='NO'
ORDER BY first_time
FETCH FIRST 10 ROWS ONLY;
```

Kết quả cho thấy các log cũ từ tháng 6 vẫn:

``` text
APPLIED = NO
DELETED = NO
BACKUP_COUNT = 0
```

**Giải thích:** `APPLIED` ở `V$ARCHIVED_LOG` trên primary không nên dùng
một mình để kết luận standby chưa apply. Trạng thái apply cần được kiểm
tra trên standby. Trường quan trọng ở đây là `DELETED=NO` và
`BACKUP_COUNT=0`: physical archived log vẫn còn trong FRA và RMAN
repository của primary chưa ghi nhận nó đã được backup.

Tiếp tục kiểm tra thời gian của các log cũ cho thấy chúng bắt đầu từ đầu
tháng 6/2026.

------------------------------------------------------------------------

# 28. Đối chiếu archive cũ với standby

Trên standby, các sequence rất cũ như T1/12-15 và T2/6-11 không còn
record trong `V$ARCHIVED_LOG`.

Kiểm tra phạm vi metadata còn được giữ:

``` sql
SELECT thread#, MIN(sequence#) min_seq, MAX(sequence#) max_seq
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;
```

Kết quả:

``` text
THREAD 1: MIN_SEQ = 74
THREAD 2: MIN_SEQ = 66
```

Các sequence ở đầu phạm vi này được kiểm tra và đều có `APPLIED=YES`.

**Giải thích:** control file không nhất thiết giữ metadata archived-log
vô hạn. Việc sequence cũ không còn record trên standby không đồng nghĩa
nó chưa từng được apply. Bằng chứng hữu ích hơn là các sequence cũ nhất
còn nằm trong metadata standby đã được apply, trong khi Data Guard hiện
tại vẫn chạy và bắt kịp primary.

------------------------------------------------------------------------

# 29. Bằng chứng archive đã apply nhưng primary vẫn giữ

Một số log được đối chiếu trực tiếp:

``` text
T1: 74, 75, 76
T2: 66, 67, 68
```

Standby báo các log này đã `APPLIED=YES`.

Trong khi trên primary:

``` text
DELETED = NO
BACKUP_COUNT = 0
```

và completion time của chúng nằm vào 23-24 Jun 2026.

**Ý nghĩa:** Data Guard đã sử dụng xong các archived log này, nhưng
primary vẫn giữ physical copy trong FRA và chúng chưa được backup theo
metadata RMAN của primary. Đây là bằng chứng mạnh loại trừ giả thuyết
"archive tồn vì standby chưa apply".

------------------------------------------------------------------------

# 30. Pattern kéo dài tới archive mới nhất

Kiểm tra các archived log mới nhất trên primary cho thấy cùng pattern:

``` text
DELETED = NO
BACKUP_COUNT = 0
```

Aggregate cuối cùng trước remediation:

``` text
BACKUP_COUNT  FILES  OLDEST      NEWEST
0             234    01-JUN-26   18-SEP-26
```

Như vậy vấn đề không chỉ xảy ra với vài file cũ mà là một lifecycle kéo
dài từ tháng 6 tới tháng 9.

------------------------------------------------------------------------

# 31. Quyết định remediation: backup archive trước khi cleanup

Sau khi đã loại trừ các nguyên nhân chính:

-   Data Guard apply lag lớn
-   Guaranteed Restore Point
-   Flashback window giữ archive từ tháng 6
-   Archive destination lỗi

quyết định remediation là **backup archived logs trước**, không xóa trực
tiếp.

Vào RMAN primary:

``` rman
BACKUP ARCHIVELOG ALL NOT BACKED UP 1 TIMES;
```

**Tại sao không DELETE trước?** Vì archive chưa có backup theo RMAN
repository. Xóa ngay sẽ làm mất một lớp recovery evidence. Nguyên tắc an
toàn là tạo bản backup trước, kiểm tra khả năng restore, rồi mới cleanup
physical archived logs.

------------------------------------------------------------------------

# 32. RMAN archived-log backup ngày 18-Sep-2026

Backup hoàn tất thành công:

``` text
Finished backup at 18-SEP-26
```

RMAN tạo 5 archived-log backup sets với tag:

``` text
TAG20260918T094916
```

Sau đó Control File và SPFILE autobackup cũng hoàn tất.

Các backup piece được tạo dưới:

``` text
+FRA/RACDB/BACKUPSET/2026_09_18/...
```

và autobackup:

``` text
+FRA/RACDB/AUTOBACKUP/2026_09_18/...
```

## Bài học quan trọng

Backup dùng `DEVICE TYPE DISK` nhưng không chỉ định `FORMAT` ra
filesystem ngoài FRA. Vì FRA đang được cấu hình, các backup piece mới
lại được ghi vào chính `+FRA`.

Đây là lý do backup thành công nhưng FRA tạm thời trở nên nguy hiểm hơn.

------------------------------------------------------------------------

# 33. FRA tăng lên 99.06% trong lúc remediation

Sau backup:

``` text
USED_GB          13.55
RECLAIMABLE_GB    2.29
USED_PCT         99.06
```

Breakdown:

``` text
BACKUP PIECE     63.65% used
ARCHIVED LOG     15.16% used / 15.16% reclaimable
REDO LOG         14.35%
FLASHBACK LOG     5.74%
```

## Giải thích

Trước backup, archived logs chiếm nhiều dung lượng nhưng
`0% reclaimable`.

Sau backup:

``` text
ARCHIVED LOG used = 15.16%
ARCHIVED LOG reclaimable = 15.16%
```

Điều này cho thấy các archived log còn lại đã trở thành ứng viên reclaim
sau khi có backup phù hợp. Đồng thời, backup pieces mới chiếm một lượng
lớn FRA nên tổng `SPACE_USED` tăng tới 99.06%.

**Operational lesson:** khi FRA đang gần đầy, backup archive vào chính
FRA có thể làm incident tệ hơn trước khi nó tốt hơn. Trong production
nên cân nhắc backup destination nằm ngoài FRA hoặc bảo đảm FRA có đủ
headroom.

------------------------------------------------------------------------

# 34. Xác nhận archive đã được backup

Sau backup:

``` rman
LIST ARCHIVELOG ALL BACKED UP 1 TIMES TO DEVICE TYPE DISK;
```

RMAN đã liệt kê các archived logs từ tháng 6 tới các sequence mới nhất.

Điều này khác hoàn toàn trạng thái trước remediation, khi cùng lệnh
không trả về record nào.

------------------------------------------------------------------------

# 35. Kiểm tra Data Guard lần cuối trước cleanup

Trên standby:

``` sql
SELECT thread#, MAX(sequence#) last_applied
FROM v$archived_log
WHERE applied='YES'
GROUP BY thread#
ORDER BY thread#;
```

Kết quả:

``` text
THREAD#  LAST_APPLIED
1        150
2        102
```

Đây cũng là các sequence mới nhất được quan sát trong backup/archive
inventory tại thời điểm đó.

**Kết luận:** standby đã apply tới T1/150 và T2/102. Cleanup archive ở
primary không được thực hiện trong trạng thái standby đang lag phía sau
các archive cần thiết.

------------------------------------------------------------------------

# 36. Validate khả năng restore của backup

Trước khi xóa archive gốc, thực hiện restore validation.

Đầu tiên:

``` rman
RESTORE ARCHIVELOG ALL VALIDATE;
```

RMAN báo:

``` text
RMAN-06025: no backup of archived log for thread 2 with sequence 4 ...
RMAN-06025: no backup of archived log for thread 1 with sequence 10 ...
```

## Tại sao `ALL VALIDATE` thất bại?

RMAN cố validate toàn bộ archive history mà repository còn biết. Hai
sequence T1/10 và T2/4 nằm trước archived-log backup đầu tiên đã biết
của lab:

``` text
T1 sequence 11
T2 sequence 5
```

Do lab/database đã từng được rebuild/reset nhiều lần, historical
metadata và physical backup coverage không nhất thiết liên tục.

Lỗi này **không chứng minh backup 18-Sep bị corrupt**. Nó chứng minh
RMAN không có backup cho hai historical archived logs đó.

Do đó validation được thu hẹp về các archived logs mới nhất vừa backup.

Thread 1:

``` rman
RESTORE ARCHIVELOG SEQUENCE 150 THREAD 1 VALIDATE;
```

Kết quả:

``` text
channel ORA_DISK_1: scanning archived log ...thread_1_seq_150...
Finished restore at 18-SEP-26
```

Thread 2:

``` rman
RESTORE ARCHIVELOG SEQUENCE 102 THREAD 2 VALIDATE;
```

Kết quả:

``` text
channel ORA_DISK_1: scanning archived log ...thread_2_seq_102...
Finished restore at 18-SEP-26
```

**Kết luận:** latest archived log của cả hai RAC redo threads đều qua
RMAN validation.

------------------------------------------------------------------------

# 37. Giải thích `THREAD#` và `SEQUENCE#` trong Oracle RAC

Đây là khái niệm rất quan trọng khi vận hành RAC và Data Guard.

## THREAD# là gì?

Trong RAC, mỗi instance thông thường có redo thread riêng.

Ví dụ lab hai node:

``` text
RAC instance 1  ---> Redo Thread 1
RAC instance 2  ---> Redo Thread 2
```

Mỗi instance có thể generate redo đồng thời. Oracle không ép hai
instance dùng chung một sequence counter duy nhất.

## SEQUENCE# là gì?

`SEQUENCE#` là số thứ tự của redo log generation **bên trong một redo
thread**. Khi instance thực hiện log switch, sequence của thread đó
tăng.

Ví dụ:

``` text
Thread 1 Sequence 149
Thread 1 Sequence 150

Thread 2 Sequence 101
Thread 2 Sequence 102
```

T1=150 và T2=102 hoàn toàn bình thường. Hai thread không cần có sequence
giống nhau vì lượng workload và tốc độ log switch của hai instance có
thể khác nhau.

Do đó identity thực tế của một archived redo log là:

``` text
(THREAD#, SEQUENCE#)
```

chứ không phải chỉ `SEQUENCE#`.

## Tại sao Data Guard phải check theo thread?

Query kiểu:

``` sql
SELECT MAX(sequence#)
FROM v$archived_log
WHERE applied='YES';
```

có thể gây hiểu nhầm trong RAC vì nó trộn nhiều redo stream độc lập
thành một con số.

Nên dùng:

``` sql
SELECT thread#, MAX(sequence#) last_applied
FROM v$archived_log
WHERE applied='YES'
GROUP BY thread#
ORDER BY thread#;
```

Nhờ vậy có thể so riêng:

``` text
Primary Thread 1 <-> Standby Thread 1
Primary Thread 2 <-> Standby Thread 2
```

Trong incident này, standby cuối cùng đạt:

``` text
T1 = 150
T2 = 102
```

------------------------------------------------------------------------

# 38. Cleanup archived logs bằng RMAN

Sau khi:

1.  archived logs đã được backup,
2.  latest backup của T1/T2 đã validate,
3.  standby đã apply tới T1/150 và T2/102,

RMAN cleanup archived logs đã backup được thực hiện.

RMAN output:

``` text
Deleted 118 objects
```

Physical archived logs được xóa bằng RMAN, không dùng `rm` trực tiếp
trên ASM/FRA.

## Lưu ý

Predicate cleanup có thể xóa cả archived log rất mới nếu nó thỏa điều
kiện backup. Trong lần này output cho thấy cleanup đi tới T2 sequence
101.

Nếu policy vận hành muốn giữ local archive của 24 giờ hoặc N ngày gần
nhất, lệnh cleanup production nên có thêm cutoff time/sequence phù hợp
thay vì xóa toàn bộ archive đủ điều kiện.

------------------------------------------------------------------------

# 39. FRA sau cleanup

Sau khi xóa 118 archived logs:

``` text
USED_GB          11.48
RECLAIMABLE_GB    0.22
USED_PCT         83.92
```

So với trước cleanup:

``` text
99.06% -> 83.92%
13.55 GB -> 11.48 GB
```

Breakdown:

``` text
BACKUP PIECE      63.65%   reclaimable 0.14%   11 files
REDO LOG          14.35%   reclaimable 0%      10 files
FLASHBACK LOG      5.74%   reclaimable 1.43%    4 files
CONTROL FILE       0.14%   reclaimable 0%       1 file
ARCHIVED LOG       0.02%   reclaimable 0.02%    1 file
```

**Kết luận:** archived-log backlog đã được xử lý. `ARCHIVED LOG` từ
thành phần lớn nhất (\~47.5%) xuống còn \~0.02%.

FRA vẫn trên 80% vì thành phần lớn nhất lúc này là `BACKUP PIECE`, không
còn là archived logs.

------------------------------------------------------------------------

# 40. Backup inventory sau remediation

``` rman
LIST BACKUP SUMMARY;
```

Kết quả:

``` text
Key  TY  Completion   Tag
2    F   01-JUN-26    TAG20260601T160229
3    F   01-JUN-26    TAG20260601T160229
4    F   01-JUN-26    TAG20260601T160229
5    A   01-JUN-26    RACDB_FIRST_RMAN_BACKUP
8    F   16-JUN-26    TAG20260616T195016
9    A   18-SEP-26    TAG20260918T094916
10   A   18-SEP-26    TAG20260918T094916
11   A   18-SEP-26    TAG20260918T094916
12   A   18-SEP-26    TAG20260918T094916
13   A   18-SEP-26    TAG20260918T094916
14   F   18-SEP-26    TAG20260918T095121
```

Trong RMAN summary:

-   `TY=A` ở đây là archived-log backup.
-   Keys 9-13 là 5 archived-log backup sets mới.
-   Key 14 là full/controlfile-SPFILE autobackup được tạo sau backup.
-   Các backup cũ từ June vẫn cần được đánh giá bằng retention policy
    trước khi cleanup.

Không nên nhìn ngày cũ rồi xóa thủ công.

------------------------------------------------------------------------

# 41. Checkpoint hiện tại

FRA incident đã được giảm từ vùng cực kỳ nguy hiểm:

``` text
99.06%
```

xuống:

``` text
83.92%
```

Archived-log backlog:

``` text
~47.5% FRA / hơn 230 files
```

đã giảm còn:

``` text
0.02% FRA / 1 file
```

Data Guard trước cleanup:

``` text
T1 applied = 150
T2 applied = 102
```

Latest archived-log restore validation:

``` text
T1/150 = PASS
T2/102 = PASS
```

Thành phần FRA lớn nhất hiện tại:

``` text
BACKUP PIECE = 63.65%
```

## Lệnh tiếp theo

``` rman
REPORT OBSOLETE;
```

Mục tiêu: để RMAN áp dụng:

``` text
CONFIGURE RETENTION POLICY TO REDUNDANCY 1;
```

và xác định backup/copy nào hiện đã obsolete trước khi quyết định
cleanup backup pieces.

------------------------------------------------------------------------

# 42. Root Cause Analysis (RCA) tạm thời

## Symptom

``` text
ORA-19815
FRA usage > 85%
```

## Technical chain

``` text
FRA pressure
    |
    +--> ARCHIVED LOG ~47.5%
            |
            +--> >230 files retained
            |
            +--> June -> September
            |
            +--> BACKUP_COUNT = 0
            |
            +--> 0% reclaimable
```

Các giả thuyết khác được kiểm tra:

``` text
Data Guard lag?            -> Không thấy backlog đáng kể; standby caught up.
Guaranteed restore point? -> Không có.
Flashback giữ từ June?     -> Không; window thực tế quanh 18-Sep.
Archive destination error?-> DEST_2 VALID, ERROR NULL.
```

Sau archived-log backup:

``` text
ARCHIVED LOG reclaimable: 0% -> 15.16%
```

Sau RMAN cleanup:

``` text
ARCHIVED LOG: ~47.5% -> 0.02%
FRA: 99.06% -> 83.92%
```

**RCA hiện tại:** archived-log backup/cleanup lifecycle không được vận
hành đều đặn, khiến archived redo tích tụ trong FRA trong nhiều tháng.
FRA size là giới hạn làm symptom xuất hiện, nhưng chỉ tăng
`DB_RECOVERY_FILE_DEST_SIZE` sẽ không sửa nguyên nhân lifecycle.

------------------------------------------------------------------------

# 43. Operational lessons

1.  Không xóa ASM/FRA file trực tiếp bằng OS command.
2.  Khi gặp ORA-19815, phải xem `V$RECOVERY_FILE_DEST` và
    `V$RECOVERY_AREA_USAGE` trước khi quyết định tăng FRA.
3.  FRA `% used` và `% reclaimable` là hai tín hiệu khác nhau.
4.  Trong RAC, archive phải được theo dõi theo `(THREAD#, SEQUENCE#)`.
5.  Data Guard apply phải kiểm tra theo từng thread.
6.  `BACKUP_COUNT=0` trên primary là evidence của RMAN repository
    primary; nếu có backup workflow ở standby/recovery catalog thì phải
    đối chiếu thêm.
7.  Backup thành công chưa đủ; phải có restore/validate testing phù hợp
    với recovery objective.
8.  `RESTORE ARCHIVELOG ALL VALIDATE` có thể fail vì historical gaps dù
    backup mới vẫn tốt.
9.  Backup vào chính FRA đang gần đầy có thể đẩy FRA tới 100%.
10. Cleanup archive bằng RMAN, không `rm` physical file.
11. Nếu cần giữ local archive gần nhất, cleanup command phải có cutoff.
12. Permanent fix phải là scheduled backup + retention + cleanup + FRA
    monitoring, không phải emergency delete định kỳ. ---

# 44. Inspect toàn bộ RMAN backup pieces sau cleanup archive

Thực hiện:

``` rman
LIST BACKUP;
```

Output đầy đủ:

``` text
7
  Control File Included: Ckp SCN: 4515348      Ckp time: 16-JUN-26
  SPFILE Included: Modification time: 16-JUN-26
  SPFILE db_unique_name: RACDB

RMAN> LIST BACKUP;


List of Backup Sets
===================


BS Key  Type LV Size       Device Type Elapsed Time Completion Time
------- ---- -- ---------- ----------- ------------ ---------------
2       Full    1.26G      DISK        00:00:03     01-JUN-26
        BP Key: 2   Status: AVAILABLE  Compressed: NO  Tag: TAG20260601T160229
        Piece Name: +FRA/RACDB/BACKUPSET/2026_06_01/nnndf0_tag20260601t160229_0.264.1234800149
  List of Datafiles in backup set 2
  File LV Type Ckp SCN    Ckp Time  Abs Fuz SCN Sparse Name
  ---- -- ---- ---------- --------- ----------- ------ ----
  1       Full 3063994    01-JUN-26              NO    +DATA/RACDB/DATAFILE/system.257.1234363199
  3       Full 3063994    01-JUN-26              NO    +DATA/RACDB/DATAFILE/sysaux.258.1234363223
  4       Full 3063994    01-JUN-26              NO    +DATA/RACDB/DATAFILE/undotbs1.259.1234363239
  7       Full 3063994    01-JUN-26              NO    +DATA/RACDB/DATAFILE/users.260.1234363239
  9       Full 3063994    01-JUN-26              NO    +DATA/RACDB/DATAFILE/undotbs2.269.1234363639

BS Key  Type LV Size       Device Type Elapsed Time Completion Time
------- ---- -- ---------- ----------- ------------ ---------------
3       Full    518.47M    DISK        00:00:01     01-JUN-26
        BP Key: 3   Status: AVAILABLE  Compressed: NO  Tag: TAG20260601T160229
        Piece Name: +FRA/RACDB/52E332D7790517EFE063CD7AA8C057C1/BACKUPSET/2026_06_01/nnndf0_tag20260601t160229_0.265.1234800153
  List of Datafiles in backup set 3
  Container ID: 4, PDB Name: PDB1
  File LV Type Ckp SCN    Ckp Time  Abs Fuz SCN Sparse Name
  ---- -- ---- ---------- --------- ----------- ------ ----
  10      Full 3064048    01-JUN-26              NO    +DATA/RACDB/52E332D7790517EFE063CD7AA8C057C1/DATAFILE/system.274.1234476991
  11      Full 3064048    01-JUN-26              NO    +DATA/RACDB/52E332D7790517EFE063CD7AA8C057C1/DATAFILE/sysaux.275.1234476991
  12      Full 3064048    01-JUN-26              NO    +DATA/RACDB/52E332D7790517EFE063CD7AA8C057C1/DATAFILE/undotbs1.273.1234476991
  13      Full 3064048    01-JUN-26              NO    +DATA/RACDB/52E332D7790517EFE063CD7AA8C057C1/DATAFILE/undo_2.277.1234477023
  14      Full 3064048    01-JUN-26              NO    +DATA/RACDB/52E332D7790517EFE063CD7AA8C057C1/DATAFILE/users.278.1234478713

BS Key  Type LV Size       Device Type Elapsed Time Completion Time
------- ---- -- ---------- ----------- ------------ ---------------
4       Full    552.19M    DISK        00:00:01     01-JUN-26
        BP Key: 4   Status: AVAILABLE  Compressed: NO  Tag: TAG20260601T160229
        Piece Name: +FRA/RACDB/52C8C4571D6A49AAE063CD7AA8C04F40/BACKUPSET/2026_06_01/nnndf0_tag20260601t160229_0.266.1234800155
  List of Datafiles in backup set 4
  Container ID: 2, PDB Name: PDB$SEED
  File LV Type Ckp SCN    Ckp Time  Abs Fuz SCN Sparse Name
  ---- -- ---- ---------- --------- ----------- ------ ----
  5       Full 2159776    27-MAY-26              NO    +DATA/RACDB/86B637B62FE07A65E053F706E80A27CA/DATAFILE/system.265.1234363409
  6       Full 2159776    27-MAY-26              NO    +DATA/RACDB/86B637B62FE07A65E053F706E80A27CA/DATAFILE/sysaux.266.1234363409
  8       Full 2159776    27-MAY-26              NO    +DATA/RACDB/86B637B62FE07A65E053F706E80A27CA/DATAFILE/undotbs1.267.1234363409

BS Key  Size       Device Type Elapsed Time Completion Time
------- ---------- ----------- ------------ ---------------
5       20.50K     DISK        00:00:00     01-JUN-26
        BP Key: 5   Status: AVAILABLE  Compressed: NO  Tag: RACDB_FIRST_RMAN_BACKUP
        Piece Name: +FRA/RACDB/BACKUPSET/2026_06_01/annnf0_racdb_first_rman_backup_0.269.1234800161

  List of Archived Logs in backup set 5
  Thrd Seq     Low SCN    Low Time  Next SCN   Next Time
  ---- ------- ---------- --------- ---------- ---------
  1    11      3063966    01-JUN-26 3064058    01-JUN-26
  2    5       3063970    01-JUN-26 3064061    01-JUN-26

BS Key  Type LV Size       Device Type Elapsed Time Completion Time
------- ---- -- ---------- ----------- ------------ ---------------
8       Full    18.98M     DISK        00:00:01     16-JUN-26
        BP Key: 8   Status: AVAILABLE  Compressed: NO  Tag: TAG20260616T195016
        Piece Name: +FRA/RACDB/AUTOBACKUP/2026_06_16/s_1236109816.361.1236109817
  SPFILE Included: Modification time: 16-JUN-26
  SPFILE db_unique_name: RACDB
  Control File Included: Ckp SCN: 4515348      Ckp time: 16-JUN-26

BS Key  Size       Device Type Elapsed Time Completion Time
------- ---------- ----------- ------------ ---------------
9       1.77G      DISK        00:00:18     18-SEP-26
        BP Key: 9   Status: AVAILABLE  Compressed: NO  Tag: TAG20260918T094916
        Piece Name: +FRA/RACDB/BACKUPSET/2026_09_18/annnf0_tag20260918t094916_0.515.1244281759

  List of Archived Logs in backup set 9
  Thrd Seq     Low SCN    Low Time  Next SCN   Next Time
  ---- ------- ---------- --------- ---------- ---------
  1    88      5513871    26-JUN-26 5536816    26-JUN-26
  1    89      5536816    26-JUN-26 5549505    26-JUN-26
  1    90      5549505    26-JUN-26 5673004    27-JUN-26
  1    91      5673004    27-JUN-26 5774590    27-JUN-26
  1    92      5774590    27-JUN-26 5795597    27-JUN-26
  1    93      5795597    27-JUN-26 5820032    28-JUN-26
  1    94      5820032    28-JUN-26 5830831    28-JUN-26
  1    95      5830831    28-JUN-26 5843428    04-JUL-26
  1    96      5843428    04-JUL-26 5884627    04-JUL-26
  1    97      5884627    04-JUL-26 5986515    04-JUL-26
  1    98      5986515    04-JUL-26 6086527    05-JUL-26
  1    99      6086527    05-JUL-26 6186832    06-JUL-26
  1    100     6186832    06-JUL-26 6300029    11-JUL-26
  1    101     6300029    11-JUL-26 6423222    11-JUL-26
  1    102     6423222    11-JUL-26 6435619    20-JUL-26
  1    103     6435619    20-JUL-26 6448246    20-JUL-26
  1    104     6448246    20-JUL-26 6561312    20-JUL-26
  1    105     6561312    20-JUL-26 6672393    20-JUL-26
  1    106     6672393    20-JUL-26 6788889    20-JUL-26
  1    107     6788889    20-JUL-26 6930643    21-JUL-26
  1    108     6930643    21-JUL-26 7054921    22-JUL-26
  1    109     7054921    22-JUL-26 7074038    22-JUL-26
  1    110     7074038    22-JUL-26 7077408    23-JUL-26
  1    111     7077408    23-JUL-26 7116864    26-AUG-26
  1    112     7116864    26-AUG-26 7124065    04-SEP-26
  1    113     7124065    04-SEP-26 7128286    07-SEP-26
  1    114     7128286    07-SEP-26 7165051    08-SEP-26
  1    115     7165051    08-SEP-26 7180418    08-SEP-26
  1    116     7180418    08-SEP-26 7182232    08-SEP-26
  1    117     7182232    08-SEP-26 7184208    08-SEP-26
  1    118     7184208    08-SEP-26 7185368    08-SEP-26
  2    69      5868824    04-JUL-26 5868830    04-JUL-26
  2    70      5868830    04-JUL-26 5884630    04-JUL-26
  2    71      5884630    04-JUL-26 5986451    04-JUL-26
  2    72      5986451    04-JUL-26 5986455    04-JUL-26
  2    73      6425178    11-JUL-26 6425184    11-JUL-26
  2    74      6425184    11-JUL-26 6435706    20-JUL-26
  2    75      6435706    20-JUL-26 6438576    20-JUL-26
  2    76      7089148    23-JUL-26 7089153    23-JUL-26
  2    77      7089153    23-JUL-26 7116868    26-AUG-26
  2    78      7116868    26-AUG-26 7120661    26-AUG-26
  2    79      7146644    08-SEP-26 7146650    08-SEP-26
  2    80      7146650    08-SEP-26 7165140    08-SEP-26
  2    81      7165140    08-SEP-26 7166945    08-SEP-26

BS Key  Size       Device Type Elapsed Time Completion Time
------- ---------- ----------- ------------ ---------------
10      1.64G      DISK        00:00:31     18-SEP-26
        BP Key: 10   Status: AVAILABLE  Compressed: NO  Tag: TAG20260918T094916
        Piece Name: +FRA/RACDB/BACKUPSET/2026_09_18/annnf0_tag20260918t094916_0.461.1244281789

  List of Archived Logs in backup set 10
  Thrd Seq     Low SCN    Low Time  Next SCN   Next Time
  ---- ------- ---------- --------- ---------- ---------
  1    77      5385550    24-JUN-26 5390868    24-JUN-26
  1    78      5390868    24-JUN-26 5397582    24-JUN-26
  1    79      5397582    24-JUN-26 5402877    24-JUN-26
  1    80      5402877    24-JUN-26 5408291    24-JUN-26
  1    81      5408291    24-JUN-26 5412844    24-JUN-26
  1    82      5412844    24-JUN-26 5415003    24-JUN-26
  1    83      5415003    24-JUN-26 5444205    24-JUN-26
  1    84      5444205    24-JUN-26 5459824    24-JUN-26
  1    85      5459824    24-JUN-26 5475614    24-JUN-26
  1    86      5475614    24-JUN-26 5479192    25-JUN-26
  1    87      5479192    25-JUN-26 5513871    26-JUN-26

BS Key  Size       Device Type Elapsed Time Completion Time
------- ---------- ----------- ------------ ---------------
11      1.34G      DISK        00:00:24     18-SEP-26
        BP Key: 11   Status: AVAILABLE  Compressed: NO  Tag: TAG20260918T094916
        Piece Name: +FRA/RACDB/BACKUPSET/2026_09_18/annnf0_tag20260918t094916_0.420.1244281825

  List of Archived Logs in backup set 11
  Thrd Seq     Low SCN    Low Time  Next SCN   Next Time
  ---- ------- ---------- --------- ---------- ---------
  1    42      4377656    16-JUN-26 4378372    16-JUN-26
  1    43      4378372    16-JUN-26 4379662    16-JUN-26
  1    44      4379662    16-JUN-26 4380282    16-JUN-26
  1    45      4380282    16-JUN-26 4381051    16-JUN-26
  1    46      4381051    16-JUN-26 4382889    16-JUN-26
  1    47      4382889    16-JUN-26 4384960    16-JUN-26
  1    48      4384960    16-JUN-26 4494103    16-JUN-26
  1    49      4494103    16-JUN-26 4513372    16-JUN-26
  1    50      4513372    16-JUN-26 4516352    16-JUN-26
  1    51      4516352    16-JUN-26 4523068    16-JUN-26
  1    52      4523068    16-JUN-26 4523227    16-JUN-26
  1    53      4523227    16-JUN-26 4525582    16-JUN-26
  1    54      4525582    16-JUN-26 4533767    16-JUN-26
  1    55      4533767    16-JUN-26 4641776    16-JUN-26
  1    56      4641776    16-JUN-26 4783862    16-JUN-26
  1    57      4783862    16-JUN-26 4809438    17-JUN-26
  1    58      4809438    17-JUN-26 4809495    17-JUN-26
  1    59      4809495    17-JUN-26 4817993    17-JUN-26
  1    60      4817993    17-JUN-26 4819880    17-JUN-26
  1    61      4819880    17-JUN-26 4820339    17-JUN-26
  1    62      4820339    17-JUN-26 4820379    17-JUN-26
  1    63      4820379    17-JUN-26 4821510    17-JUN-26
  1    64      4821510    17-JUN-26 4841654    18-JUN-26
  1    65      4841654    18-JUN-26 4864015    18-JUN-26
  1    66      4864015    18-JUN-26 5033694    19-JUN-26
  1    67      5033694    19-JUN-26 5142572    19-JUN-26
  1    68      5142572    19-JUN-26 5184456    22-JUN-26
  1    69      5184456    22-JUN-26 5188029    22-JUN-26
  1    70      5188029    22-JUN-26 5276335    22-JUN-26
  1    71      5276335    22-JUN-26 5315561    23-JUN-26
  1    72      5315561    23-JUN-26 5318635    23-JUN-26
  1    73      5318635    23-JUN-26 5339960    23-JUN-26
  1    74      5339960    23-JUN-26 5353849    24-JUN-26
  1    75      5353849    24-JUN-26 5379013    24-JUN-26
  1    76      5379013    24-JUN-26 5385550    24-JUN-26
  2    40      4377294    16-JUN-26 4377659    16-JUN-26
  2    41      4377659    16-JUN-26 4378375    16-JUN-26
  2    42      4378375    16-JUN-26 4379665    16-JUN-26
  2    43      4379665    16-JUN-26 4380279    16-JUN-26
  2    44      4380279    16-JUN-26 4381048    16-JUN-26
  2    45      4381048    16-JUN-26 4382896    16-JUN-26
  2    46      4382896    16-JUN-26 4384963    16-JUN-26
  2    47      4384963    16-JUN-26 4494102    16-JUN-26
  2    48      4494102    16-JUN-26 4494282    16-JUN-26
  2    49      4495984    16-JUN-26 4495990    16-JUN-26
  2    50      4495990    16-JUN-26 4513369    16-JUN-26
  2    51      4513369    16-JUN-26 4516356    16-JUN-26
  2    52      4516356    16-JUN-26 4523075    16-JUN-26
  2    53      4523075    16-JUN-26 4523222    16-JUN-26
  2    54      4523222    16-JUN-26 4525593    16-JUN-26
  2    55      4525593    16-JUN-26 4533758    16-JUN-26
  2    56      4533758    16-JUN-26 4641775    16-JUN-26
  2    57      4641775    16-JUN-26 4642169    16-JUN-26
  2    58      4662352    16-JUN-26 4662358    16-JUN-26
  2    59      4662358    16-JUN-26 4783861    16-JUN-26
  2    60      4783861    16-JUN-26 4784034    16-JUN-26
  2    61      4785635    16-JUN-26 4785641    16-JUN-26
  2    62      4785641    16-JUN-26 4809435    17-JUN-26
  2    63      4809435    17-JUN-26 4809509    17-JUN-26
  2    64      4809509    17-JUN-26 4818102    17-JUN-26
  2    65      4818102    17-JUN-26 4819769    17-JUN-26
  2    66      5304358    23-JUN-26 5315568    23-JUN-26
  2    67      5315568    23-JUN-26 5318636    23-JUN-26
  2    68      5318636    23-JUN-26 5329251    23-JUN-26

BS Key  Size       Device Type Elapsed Time Completion Time
------- ---------- ----------- ------------ ---------------
12      1.03G      DISK        00:00:25     18-SEP-26
        BP Key: 12   Status: AVAILABLE  Compressed: NO  Tag: TAG20260918T094916
        Piece Name: +FRA/RACDB/BACKUPSET/2026_09_18/annnf0_tag20260918t094916_0.399.1244281855

  List of Archived Logs in backup set 12
  Thrd Seq     Low SCN    Low Time  Next SCN   Next Time
  ---- ------- ---------- --------- ---------- ---------
  1    12      3064058    01-JUN-26 3090600    04-JUN-26
  1    13      3090609    04-JUN-26 3090854    04-JUN-26
  1    14      3090854    04-JUN-26 3104353    04-JUN-26
  1    15      3104353    04-JUN-26 3104355    04-JUN-26
  1    16      3104355    04-JUN-26 3256431    04-JUN-26
  1    17      3256431    04-JUN-26 3256533    04-JUN-26
  1    18      3358097    04-JUN-26 3358274    04-JUN-26
  1    19      3358274    04-JUN-26 3483938    05-JUN-26
  1    20      3483938    05-JUN-26 3500882    05-JUN-26
  1    21      3500895    09-JUN-26 3501054    09-JUN-26
  1    22      3501054    09-JUN-26 3563767    10-JUN-26
  1    23      3563776    10-JUN-26 3564027    10-JUN-26
  1    24      3564027    10-JUN-26 3632939    11-JUN-26
  1    25      3632951    11-JUN-26 3646766    11-JUN-26
  1    26      3646946    13-JUN-26 3647188    13-JUN-26
  1    27      3647188    13-JUN-26 3799042    13-JUN-26
  1    28      3799042    13-JUN-26 3918241    13-JUN-26
  1    29      3918241    13-JUN-26 4070364    14-JUN-26
  1    30      4070364    14-JUN-26 4090008    14-JUN-26
  1    31      4090024    15-JUN-26 4300403    15-JUN-26
  1    32      4300403    15-JUN-26 4300496    15-JUN-26
  1    33      4302383    15-JUN-26 4328651    15-JUN-26
  1    34      4328651    15-JUN-26 4351588    16-JUN-26
  1    35      4351588    16-JUN-26 4351590    16-JUN-26
  1    36      4351590    16-JUN-26 4364133    16-JUN-26
  1    37      4364133    16-JUN-26 4370830    16-JUN-26
  1    38      4370830    16-JUN-26 4374680    16-JUN-26
  1    39      4374680    16-JUN-26 4375539    16-JUN-26
  1    40      4375539    16-JUN-26 4377291    16-JUN-26
  1    41      4377291    16-JUN-26 4377656    16-JUN-26
  2    6       3064061    01-JUN-26 3069127    01-JUN-26
  2    7       3069149    04-JUN-26 3090611    04-JUN-26
  2    8       3090611    04-JUN-26 3090613    04-JUN-26
  2    9       3090613    04-JUN-26 3090706    04-JUN-26
  2    10      3092468    04-JUN-26 3103301    04-JUN-26
  2    11      3104351    04-JUN-26 3256432    04-JUN-26
  2    12      3256432    04-JUN-26 3358096    04-JUN-26
  2    13      3358096    04-JUN-26 3358100    04-JUN-26
  2    14      3358100    04-JUN-26 3358102    04-JUN-26
  2    15      3358102    04-JUN-26 3358166    04-JUN-26
  2    16      3485863    05-JUN-26 3500897    09-JUN-26
  2    17      3500897    09-JUN-26 3500899    09-JUN-26
  2    18      3500899    09-JUN-26 3500995    09-JUN-26
  2    19      3536040    10-JUN-26 3563778    10-JUN-26
  2    20      3563778    10-JUN-26 3563780    10-JUN-26
  2    21      3563780    10-JUN-26 3563870    10-JUN-26
  2    22      3578957    10-JUN-26 3608884    10-JUN-26
  2    23      3616618    11-JUN-26 3646948    13-JUN-26
  2    24      3646948    13-JUN-26 3646950    13-JUN-26
  2    25      3646950    13-JUN-26 3647028    13-JUN-26
  2    26      3679536    13-JUN-26 3799041    13-JUN-26
  2    27      3799041    13-JUN-26 3799166    13-JUN-26
  2    28      3800739    13-JUN-26 3918240    13-JUN-26
  2    29      3918240    13-JUN-26 3918375    13-JUN-26
  2    30      3920138    13-JUN-26 3929593    13-JUN-26
  2    31      3943245    14-JUN-26 4070363    14-JUN-26
  2    32      4070363    14-JUN-26 4070499    14-JUN-26
  2    33      4072258    14-JUN-26 4300404    15-JUN-26
  2    34      4300404    15-JUN-26 4351565    15-JUN-26
  2    35      4351586    16-JUN-26 4364136    16-JUN-26
  2    36      4364136    16-JUN-26 4370835    16-JUN-26
  2    37      4370835    16-JUN-26 4374685    16-JUN-26
  2    38      4374685    16-JUN-26 4375542    16-JUN-26
  2    39      4375542    16-JUN-26 4377294    16-JUN-26

BS Key  Size       Device Type Elapsed Time Completion Time
------- ---------- ----------- ------------ ---------------
13      593.46M    DISK        00:00:07     18-SEP-26
        BP Key: 13   Status: AVAILABLE  Compressed: NO  Tag: TAG20260918T094916
        Piece Name: +FRA/RACDB/BACKUPSET/2026_09_18/annnf0_tag20260918t094916_0.422.1244281875

  List of Archived Logs in backup set 13
  Thrd Seq     Low SCN    Low Time  Next SCN   Next Time
  ---- ------- ---------- --------- ---------- ---------
  1    119     7185368    08-SEP-26 7186952    08-SEP-26
  1    120     7186952    08-SEP-26 7204812    08-SEP-26
  1    121     7204812    08-SEP-26 7206083    10-SEP-26
  1    122     7206083    10-SEP-26 7221881    13-SEP-26
  1    123     7221881    13-SEP-26 7255787    14-SEP-26
  1    124     7255787    14-SEP-26 7365153    14-SEP-26
  1    125     7365153    14-SEP-26 7380527    14-SEP-26
  1    126     7380527    14-SEP-26 7381405    14-SEP-26
  1    127     7381405    14-SEP-26 7499606    14-SEP-26
  1    128     7499606    14-SEP-26 7602258    14-SEP-26
  1    129     7602258    14-SEP-26 7704059    14-SEP-26
  1    130     7704059    14-SEP-26 7704063    14-SEP-26
  1    131     7704063    14-SEP-26 7704065    14-SEP-26
  1    132     7704065    14-SEP-26 7704250    14-SEP-26
  1    133     7806048    14-SEP-26 7806054    14-SEP-26
  1    134     7806054    14-SEP-26 7929679    16-SEP-26
  1    135     7929679    16-SEP-26 7929829    16-SEP-26
  1    136     7940926    16-SEP-26 7940932    16-SEP-26
  1    137     7940932    16-SEP-26 7951676    16-SEP-26
  1    138     7951676    16-SEP-26 7963457    16-SEP-26
  1    139     7963457    16-SEP-26 8088926    16-SEP-26
  1    140     8088926    16-SEP-26 8089069    16-SEP-26
  1    141     8090708    16-SEP-26 8090714    16-SEP-26
  1    142     8090714    16-SEP-26 8109896    16-SEP-26
  1    143     8109896    16-SEP-26 8144553    17-SEP-26
  1    144     8144553    17-SEP-26 8146818    17-SEP-26
  1    145     8146818    17-SEP-26 8149071    18-SEP-26
  1    146     8149071    18-SEP-26 8174736    18-SEP-26
  1    147     8174736    18-SEP-26 8278828    18-SEP-26
  1    148     8278828    18-SEP-26 8278995    18-SEP-26
  1    149     8280585    18-SEP-26 8280591    18-SEP-26
  1    150     8280591    18-SEP-26 8291087    18-SEP-26
  2    82      7193523    08-SEP-26 7193529    08-SEP-26
  2    83      7193529    08-SEP-26 7204771    08-SEP-26
  2    84      7204771    08-SEP-26 7204865    08-SEP-26
  2    85      7369736    14-SEP-26 7369742    14-SEP-26
  2    86      7369742    14-SEP-26 7380520    14-SEP-26
  2    87      7380520    14-SEP-26 7380593    14-SEP-26
  2    88      7383149    14-SEP-26 7383155    14-SEP-26
  2    89      7383155    14-SEP-26 7499605    14-SEP-26
  2    90      7499605    14-SEP-26 7499612    14-SEP-26
  2    91      7704060    14-SEP-26 7704066    14-SEP-26
  2    92      7704066    14-SEP-26 7804429    14-SEP-26
  2    93      7804429    14-SEP-26 7929680    16-SEP-26
  2    94      7929680    16-SEP-26 7953658    16-SEP-26
  2    95      7953658    16-SEP-26 7965909    16-SEP-26
  2    96      7965909    16-SEP-26 8088927    16-SEP-26
  2    97      8088927    16-SEP-26 8111875    16-SEP-26
  2    98      8111875    16-SEP-26 8144556    17-SEP-26
  2    99      8144556    17-SEP-26 8144902    17-SEP-26
  2    100     8158987    18-SEP-26 8174743    18-SEP-26
  2    101     8174743    18-SEP-26 8278829    18-SEP-26
  2    102     8278829    18-SEP-26 8291092    18-SEP-26

BS Key  Type LV Size       Device Type Elapsed Time Completion Time
------- ---- -- ---------- ----------- ------------ ---------------
14      Full    19.36M     DISK        00:00:01     18-SEP-26
        BP Key: 14   Status: AVAILABLE  Compressed: NO  Tag: TAG20260918T095121
        Piece Name: +FRA/RACDB/AUTOBACKUP/2026_09_18/s_1244281881.424.1244281883
  SPFILE Included: Modification time: 18-SEP-26
  SPFILE db_unique_name: RACDB
  Control File Included: Ckp SCN: 8291864      Ckp time: 18-SEP-26

RMAN>
```

## Phân tích dung lượng

Các backup set đáng chú ý:

``` text
Key 2    1.26 GiB     Full database/datafiles      01-Jun-26
Key 3    518.47 MiB   Full PDB1 datafiles          01-Jun-26
Key 4    552.19 MiB   Full PDB$SEED datafiles      01-Jun-26
Key 5     20.50 KiB   Archived logs T1/11,T2/5     01-Jun-26
Key 8     18.98 MiB   Controlfile + SPFILE          16-Jun-26

Key 9      1.77 GiB   Archived-log backup           18-Sep-26
Key 10     1.64 GiB   Archived-log backup           18-Sep-26
Key 11     1.34 GiB   Archived-log backup           18-Sep-26
Key 12     1.03 GiB   Archived-log backup           18-Sep-26
Key 13   593.46 MiB   Archived-log backup           18-Sep-26

Key 14    19.36 MiB   Controlfile + SPFILE          18-Sep-26
```

Riêng Key 9--13 chiếm xấp xỉ:

``` text
1.77 + 1.64 + 1.34 + 1.03 + 0.58 ≈ 6.36 GiB
```

Đây chính là lý do `BACKUP PIECE` trở thành thành phần lớn nhất của FRA
sau remediation.

## Archive coverage của các backup set mới

RMAN không chia backup set theo thứ tự thời gian đơn giản. Các sequence
được phân bố giữa nhiều backup sets:

``` text
Key 12 -> các archive cũ từ đầu Jun
Key 11 -> chủ yếu giữa Jun
Key 10 -> khoảng cuối Jun
Key 9  -> cuối Jun trở đi, xen kẽ cả hai RAC threads
Key 13 -> archive mới nhất, Sep-2026
```

Key 13 đặc biệt chứa phần redo mới nhất:

``` text
Thread 1 -> tới Sequence 150
Thread 2 -> tới Sequence 102
```

Do đó không thể nhìn riêng ngày completion `18-SEP-26` rồi cho rằng cả 5
backup sets chỉ chứa redo của ngày 18-Sep. Chúng được tạo ngày 18-Sep
nhưng backup redo history kéo dài từ Jun tới Sep.

## Vì sao FRA vẫn khoảng 84%?

Trước backup, phần lớn FRA là physical archived logs. Sau khi chạy:

``` rman
BACKUP ARCHIVELOG ALL NOT BACKED UP 1 TIMES;
```

redo history đó được đóng gói thành các backup pieces Key 9--13 nằm
**trong chính FRA**.

Sau đó archived-log originals được cleanup, nhưng các backup pieces vẫn
được giữ để bảo toàn recovery history.

Vì vậy dung lượng về bản chất chuyển từ:

``` text
ARCHIVED LOG  --->  RMAN BACKUP PIECE
```

chứ chưa được đưa ra khỏi `+FRA`.

## Điểm cần quyết định tiếp theo

Nếu mục tiêu vận hành là chỉ giữ một recovery window ngắn, ví dụ 7 ngày,
thì cần thiết kế retention đồng bộ giữa:

1.  Full database backup.
2.  Archived-log backups cần thiết để roll-forward từ full backup.
3.  Controlfile/SPFILE autobackup.
4.  Data Guard requirements.

Không nên xóa Key 9--13 chỉ dựa vào kích thước. Trước tiên phải xác định
full database backup nào là recovery baseline hiện tại và recovery
window mong muốn.

------------------------------------------------------------------------

# 45. Cleanup archive backup history theo policy homelab và FRA final verification

Sau khi xác nhận full database backup gần nhất vẫn là ngày `01-JUN-26`,
quyết định vận hành cho homelab là ưu tiên tiết kiệm dung lượng FRA và
chỉ giữ archive backup gần nhất thay vì toàn bộ archive history từ Jun
đến Sep.

## Validate trực tiếp backup set được giữ lại

Backup set `Key 13` được validate trực tiếp:

``` rman
VALIDATE BACKUPSET 13;
```

Kết quả chính:

``` text
channel ORA_DISK_1: starting validation of archived log backup set
channel ORA_DISK_1: reading from backup piece +FRA/RACDB/BACKUPSET/2026_09_18/annnf0_tag20260918t094916_0.422.1244281875
channel ORA_DISK_1: restored backup piece 1
channel ORA_DISK_1: validation complete, elapsed time: 00:00:01
Finished validate at 18-SEP-26
```

Điểm quan trọng: lần validate này đọc trực tiếp `BACKUP PIECE` của Key
13, vì vậy đây là bằng chứng mạnh hơn lần
`RESTORE ARCHIVELOG ... VALIDATE` trước đó vốn có thể đọc archived-log
copy còn tồn tại.

## Cleanup các archived-log backup sets cũ

Giữ lại:

``` text
Key 13  Archived-log backup gần nhất, 593.46 MiB, 18-SEP-26
Key 14  Controlfile/SPFILE autobackup mới, 19.36 MiB, 18-SEP-26
```

Chủ động xóa các archived-log backup sets cũ hơn:

``` rman
DELETE BACKUPSET 12;
DELETE BACKUPSET 11;
DELETE BACKUPSET 10;
DELETE BACKUPSET 9;
```

Kích thước tương ứng:

``` text
Key 9   1.77 GiB
Key 10  1.64 GiB
Key 11  1.34 GiB
Key 12  1.03 GiB
-----------------
Total  ≈5.78 GiB
```

Đây là quyết định retention dành cho **homelab** nhằm tiết kiệm dung
lượng. Nó chủ động hy sinh archive recovery history cũ; không nên áp
dụng máy móc cho production nếu chưa xác định recovery window/RPO/RTO và
recovery baseline phù hợp.

## FRA sau cleanup

Kiểm tra:

``` sql
SELECT ROUND(space_used/1024/1024/1024,2) used_gb, ROUND(space_reclaimable/1024/1024/1024,2) reclaimable_gb, ROUND(space_used/space_limit*100,2) used_pct FROM v$recovery_file_dest;
```

Kết quả:

``` text
USED_GB  RECLAIMABLE_GB  USED_PCT
-------  --------------  --------
5.70     0.22            41.68
```

FRA đã giảm:

``` text
99.06%  ->  83.92%  ->  41.68%
```

## Final FRA breakdown

Kiểm tra:

``` sql
SELECT file_type, percent_space_used, percent_space_reclaimable, number_of_files FROM v$recovery_area_usage ORDER BY percent_space_used DESC;
```

Kết quả:

``` text
FILE_TYPE               PERCENT_SPACE_USED  PERCENT_SPACE_RECLAIMABLE  NUMBER_OF_FILES
----------------------  ------------------  -------------------------  ---------------
BACKUP PIECE                         21.41                        .14                7
REDO LOG                             14.35                          0               10
FLASHBACK LOG                         5.74                       1.43                4
CONTROL FILE                           .14                          0                1
ARCHIVED LOG                           .02                        .02                1
AUXILIARY DATAFILE COPY                  0                          0                0
IMAGE COPY                               0                          0                0
FOREIGN ARCHIVED LOG                     0                          0                0
```

## Final incident state

The original archived-log accumulation has been cleared:

``` text
ARCHIVED LOG = 0.02% / 1 file
```

The largest remaining FRA category is now:

``` text
BACKUP PIECE = 21.41% / 7 files
```

followed by:

``` text
REDO LOG      = 14.35%
FLASHBACK LOG = 5.74%
```

FRA usage at `41.68%` is no longer under the original ORA-19815 capacity
pressure.

### Recovery caveat

The current homelab state intentionally keeps only the recent
archived-log backup set (Key 13) plus the recent controlfile/SPFILE
autobackup (Key 14), while the database full backup remains from
`01-JUN-26`. Therefore this cleanup should **not** be interpreted as
preserving an uninterrupted point-in-time recovery chain from the June
full backup to the present. A future backup-policy exercise should
establish a new full recovery baseline and then align archived-log
retention with the chosen recovery window.

------------------------------------------------------------------------

# 46. Post-remediation verification trên RAC2

Sau khi cleanup FRA trên RAC1, tiếp tục kiểm tra từ node `rac2` để xác
nhận instance 2 hoạt động bình thường và cả hai RAC instances quan sát
cùng trạng thái FRA.

## RAC2 instance state

Kết nối `SYSDBA` trên `rac2` và kiểm tra:

``` sql
SELECT instance_name, host_name, status, database_status FROM v$instance;
```

Kết quả:

``` text
INSTANCE_NAME  HOST_NAME  STATUS  DATABASE_STATUS
-------------  ---------  ------  ---------------
racdb2         rac2       OPEN    ACTIVE
```

Kết luận: local instance `racdb2` đang `OPEN`, database status `ACTIVE`.

## FRA state nhìn từ RAC2

``` sql
SELECT name, ROUND(space_used/1024/1024/1024,2) used_gb, ROUND(space_reclaimable/1024/1024/1024,2) reclaimable_gb, ROUND(space_used/space_limit*100,2) used_pct FROM v$recovery_file_dest;
```

Kết quả:

``` text
NAME  USED_GB  RECLAIMABLE_GB  USED_PCT
----  -------  --------------  --------
+FRA  5.70     0.22            41.68
```

Giá trị này khớp với RAC1 sau remediation:

``` text
RAC1: +FRA = 5.70 GiB used, 41.68%
RAC2: +FRA = 5.70 GiB used, 41.68%
```

Điều này xác nhận hai instances đang quan sát cùng trạng thái recovery
destination của database RAC.

## FRA breakdown nhìn từ RAC2

``` sql
SELECT file_type, percent_space_used, percent_space_reclaimable, number_of_files FROM v$recovery_area_usage ORDER BY percent_space_used DESC;
```

Kết quả:

``` text
FILE_TYPE                USED %   RECLAIMABLE %   FILES
-----------------------  -------  --------------  -----
BACKUP PIECE              21.41          0.14        7
REDO LOG                  14.35          0           10
FLASHBACK LOG              5.74          1.43        4
CONTROL FILE               0.14          0            1
ARCHIVED LOG               0.02          0.02         1
AUXILIARY DATAFILE COPY    0             0            0
IMAGE COPY                 0             0            0
FOREIGN ARCHIVED LOG       0             0            0
```

Breakdown này cũng khớp với RAC1.

## Ý nghĩa đối với incident

Trước remediation, RAC1 từng ghi `ORA-19815` trong alert log trong khi
RAC2 không tìm thấy cùng warning trong text alert được kiểm tra.
Post-remediation verification cho thấy điều đó không có nghĩa RAC2 sử
dụng FRA khác: cả RAC1 và RAC2 hiện báo cùng tổng FRA usage và cùng
breakdown.

Vì vậy, việc một FRA warning xuất hiện ở alert của một instance không
nên được dùng một mình để suy luận rằng FRA pressure chỉ ảnh hưởng riêng
instance đó. Khi điều tra RAC, cần kiểm tra trạng thái recovery
destination/database và shared storage trực tiếp thay vì yêu cầu alert
của mọi instance phải có cùng message.
