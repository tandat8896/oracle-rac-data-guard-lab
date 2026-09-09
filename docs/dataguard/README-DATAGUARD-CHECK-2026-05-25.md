# Data Guard check - 2026-05-25

File nay ghi lai cac cau query da chay tren Oracle Data Guard lab va cach doc ket qua.

Moi truong:

```text
Primary service/user prompt: SYS@PRIMARY
Standby service/user prompt: TANDAT8896@STANDBY
Database: Oracle AI Database 26ai Enterprise Edition 23.26.1.0.0
```

## 1. Check metric tren primary

### Query

```sql
SELECT
    metric_name,
    value AS gia_tri_thuc_te,
    metric_unit AS don_vi_do
FROM v$sysmetric
WHERE metric_name IN (
    'Host CPU Utilization (%)',
    'Current Logons Count',
    'Database Wait Time Ratio'
);
```

### Ket qua

```text
METRIC_NAME                     GIA_TRI_THUC_TE DON_VI_DO
___________________________ ___________________ _____________________
Host CPU Utilization (%)       9.19978301086337 % Busy/(Idle+Busy)
Current Logons Count                        101 Logons
Database Wait Time Ratio       21.6725233940064 % Wait/DB_Time
Host CPU Utilization (%)        10.470568764826 % Busy/(Idle+Busy)
```

### Phan tich

| Metric | Ket qua | Cach doc |
|---|---:|---|
| `Host CPU Utilization (%)` | khoang 9-10% | CPU dang nhe, chua co dau hieu bi CPU bound. |
| `Current Logons Count` | 101 | So session/login hien tai. Voi homelab nhin hoi cao, nhung Oracle co background/internal sessions. Nen check them theo user neu can. |
| `Database Wait Time Ratio` | 21.67% | Co thoi gian cho trong DB time. Chua ket luan xau neu lab dang idle/Data Guard. Muon phan tich sau hon phai xem wait event. |

Luu y: `v$sysmetric` co the tra nhieu dong cho cung mot metric vi Oracle co cac cua so metric khac nhau. Vi vay thay 2 dong CPU la binh thuong.

## 2. Check archive destination tren primary

### Query

```sql
SELECT
    dest_id,
    status,
    target,
    delay_mins AS do_tre_dong_bo_phut
FROM v$archive_dest
WHERE target = 'STANDBY'
  AND status = 'VALID';
```

### Ket qua

```text
   DEST_ID STATUS    TARGET        DO_TRE_DONG_BO_PHUT
__________ _________ __________ ______________________
         2 VALID     STANDBY                         0
```

### Phan tich

| Cot | Ket qua | Y nghia |
|---|---|---|
| `DEST_ID` | 2 | Archive destination so 2 la duong gui redo/archive sang standby. |
| `STATUS` | `VALID` | Cau hinh destination hop le, khong bi loi cau hinh ngay tai thoi diem check. |
| `TARGET` | `STANDBY` | Day la destination cho standby database. |
| `DELAY_MINS` | 0 | Khong cau hinh delay apply/transport. |

Ket luan: primary co destination sang standby va trang thai dang hop le.

## 3. Check role/open mode tren standby

### Query

```sql
select name, database_role, open_mode, log_mode
from v$database;
```

### Ket qua

```text
NAME       DATABASE_ROLE       OPEN_MODE               LOG_MODE
__________ ___________________ _______________________ _____________
ORCLCDB    PHYSICAL STANDBY    READ ONLY WITH APPLY    ARCHIVELOG
```

### Phan tich

| Cot | Ket qua | Y nghia |
|---|---|---|
| `NAME` | `ORCLCDB` | Ten database. |
| `DATABASE_ROLE` | `PHYSICAL STANDBY` | Day la standby vat ly, khong phai primary. |
| `OPEN_MODE` | `READ ONLY WITH APPLY` | Standby dang mo doc duoc va van apply redo. |
| `LOG_MODE` | `ARCHIVELOG` | Bat archivelog, dieu kien can cho Data Guard. |

Ket luan: standby dang o trang thai rat tot cho lab: vua query read-only duoc, vua apply redo.

## 4. Check managed recovery tren standby

### Query

```sql
select process, status, sequence#, thread#
from v$managed_standby
order by process;
```

### Ket qua

```text
PROCESS    STATUS             SEQUENCE#    THREAD#
__________ _______________ ____________ __________
ARCH       CONNECTED                  0          0
ARCH       CLOSING                   28          1
ARCH       CLOSING                   27          1
ARCH       CLOSING                   26          1
DGRD       ALLOCATED                  0          0
DGRD       ALLOCATED                  0          0
MRP0       APPLYING_LOG              29          1
RFS        IDLE                       0          0
RFS        IDLE                       0          1
RFS        IDLE                      29          1
```

### Phan tich

| Process | Ket qua can nhin | Y nghia |
|---|---|---|
| `MRP0` | `APPLYING_LOG`, sequence 29 | Managed Recovery Process dang apply redo. Day la dau hieu quan trong nhat tren standby. |
| `RFS` | co dong sequence 29 | Remote File Server dang nhan redo tu primary. |
| `ARCH` | `CONNECTED`/`CLOSING` | Archive process dang xu ly archive logs. |
| `DGRD` | `ALLOCATED` | Data Guard process duoc cap phat. |

Ket luan: standby dang nhan va apply redo. Dong quan trong nhat la:

```text
MRP0 APPLYING_LOG 29
```

## 5. Check transport/apply lag tren standby

### Query

```sql
select name, value, time_computed
from v$dataguard_stats
where name in ('transport lag','apply lag');
```

### Ket qua

```text
NAME             VALUE           TIME_COMPUTED
________________ _______________ ______________________
transport lag    +00 00:00:00    05/25/2026 07:35:53
apply lag        +00 00:00:00    05/25/2026 07:35:53
```

### Phan tich

| Metric | Ket qua | Y nghia |
|---|---|---|
| `transport lag` | 0 | Redo tu primary sang standby khong bi tre tai thoi diem check. |
| `apply lag` | 0 | Standby apply redo kip primary tai thoi diem check. |

Ket luan: Data Guard dang dong bo tot, lag = 0.

## 6. Check role/protection tren primary

### Query

```sql
select name,
       database_role,
       open_mode,
       log_mode,
       protection_mode,
       protection_level
from v$database;
```

### Ket qua

```text
NAME       DATABASE_ROLE    OPEN_MODE     LOG_MODE      PROTECTION_MODE        PROTECTION_LEVEL
__________ ________________ _____________ _____________ ______________________ ______________________
ORCLCDB    PRIMARY          READ WRITE    ARCHIVELOG    MAXIMUM PERFORMANCE    MAXIMUM PERFORMANCE
```

### Phan tich

| Cot | Ket qua | Y nghia |
|---|---|---|
| `DATABASE_ROLE` | `PRIMARY` | Day la primary database. |
| `OPEN_MODE` | `READ WRITE` | Primary dang mo ghi/doc binh thuong. |
| `LOG_MODE` | `ARCHIVELOG` | Bat archivelog, dung cho Data Guard. |
| `PROTECTION_MODE` | `MAXIMUM PERFORMANCE` | Che do Data Guard uu tien performance, thuong dung cho lab va nhieu he thong async. |
| `PROTECTION_LEVEL` | `MAXIMUM PERFORMANCE` | Trang thai thuc te dang khop voi mode. |

Ket luan: primary dang chay dung vai tro va dung che do Data Guard hien tai.

## 7. Check standby destination chi tiet tren primary

### Query

```sql
select dest_id, status, error, destination, target
from v$archive_dest
where target = 'STANDBY';
```

### Ket qua

```text
   DEST_ID STATUS    ERROR    DESTINATION    TARGET
__________ _________ ________ ______________ __________
         2 VALID              STANDBY_DG     STANDBY
```

### Phan tich

| Cot | Ket qua | Y nghia |
|---|---|---|
| `DEST_ID` | 2 | Destination gui redo sang standby. |
| `STATUS` | `VALID` | Destination hop le. |
| `ERROR` | rong | Khong co loi hien tai. |
| `DESTINATION` | `STANDBY_DG` | TNS alias/service dung de gui redo sang standby. |
| `TARGET` | `STANDBY` | Day la standby destination. |

Ket luan: duong gui redo tu primary sang standby khong bao loi.

## 8. Check sequence primary thay tren archive dest status

### Query

```sql
select dest_id, archived_seq#, applied_seq#
from v$archive_dest_status
where dest_id = 2;
```

### Ket qua

```text
   DEST_ID    ARCHIVED_SEQ#    APPLIED_SEQ#
__________ ________________ _______________
         2               28              27
```

### Phan tich

Cot nay de xem primary thay standby da archive/apply den sequence nao.

| Cot | Ket qua | Cach doc |
|---|---:|---|
| `ARCHIVED_SEQ#` | 28 | Primary thay destination da archive den sequence 28. |
| `APPLIED_SEQ#` | 27 | Primary thay standby apply den sequence 27. |

Nhin rieng dong nay co ve lech 1 sequence. Nhung cung thoi diem tren standby co:

```text
MRP0 APPLYING_LOG 29
transport lag = 0
apply lag = 0
```

Nen khong ket luan loi. `v$archive_dest_status` tren primary co the nhin theo archive status va cap nhat cham hon trang thai recovery realtime tren standby.

Neu muon test ro hon, tren primary chay:

```sql
alter system switch logfile;
```

Sau do doi vai giay va check tren standby:

```sql
select process, status, sequence#, thread#
from v$managed_standby
order by process;

select name, value, time_computed
from v$dataguard_stats
where name in ('transport lag','apply lag');
```

## 9. Ket luan tai thoi diem check

Trang thai hien tai:

| Thanh phan | Ket qua |
|---|---|
| Primary | `PRIMARY`, `READ WRITE`, `ARCHIVELOG` |
| Standby | `PHYSICAL STANDBY`, `READ ONLY WITH APPLY`, `ARCHIVELOG` |
| Recovery process | `MRP0 APPLYING_LOG` |
| Transport lag | 0 |
| Apply lag | 0 |
| Archive destination | `VALID`, khong co error |
| Protection | `MAXIMUM PERFORMANCE` |

Ket luan:

```text
Data Guard lab dang hoat dong dung.
Standby dang doc duoc va apply redo.
Lag tai thoi diem check = 0.
```

## 10. Broker/DGMGRL check

Sau khi dung dung binary `dgmgrl` trong container primary:

```bash
podman exec -it oraee-dg-primary bash
dgmgrl /
```

DGMGRL ket noi duoc:

```text
DGMGRL for Linux: Release 23.26.1.0.0 - Production
Connected to "ORCLCDB_PRIMARY"
Connected as SYSDG.
```

### Show configuration

```text
DGMGRL> show configuration;

Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  ORCLCDB_PRIMARY - Primary database
    orclcdb_standby - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS   (status updated 30 seconds ago)
```

### Phan tich

| Dong | Y nghia |
|---|---|
| `Configuration - lab_dg` | Broker configuration da ton tai va co ten `lab_dg`. |
| `Protection Mode: MaxPerformance` | Che do uu tien performance, thuong la ASYNC. |
| `ORCLCDB_PRIMARY - Primary database` | Broker nhan dung primary. |
| `orclcdb_standby - Physical standby database` | Broker nhan dung physical standby. |
| `Fast-Start Failover: Disabled` | Chua bat tu dong failover. Chua co "leader election" tu dong. |
| `Configuration Status: SUCCESS` | Broker thay cau hinh Data Guard dang OK. |

## 11. Broker standby status

### Query DGMGRL

```text
DGMGRL> show database orclcdb_standby;
```

### Ket qua

```text
Database - orclcdb_standby

  Role:                PHYSICAL STANDBY
  Intended State:      APPLY-ON
  Transport Lag:       0 seconds (computed 1 second ago)
  Apply Lag:           0 seconds (computed 1 second ago)
  Average Apply Rate:  34.00 KByte/s
  Real Time Query:     ON
  Instance(s):
    ORCLCDB

Database Status:
SUCCESS
```

### Phan tich

| Dong | Y nghia |
|---|---|
| `Role: PHYSICAL STANDBY` | Node nay la standby vat ly. |
| `Intended State: APPLY-ON` | Broker muon standby tiep tuc apply redo. |
| `Transport Lag: 0 seconds` | Redo transport tu primary sang standby khong tre tai luc check. |
| `Apply Lag: 0 seconds` | Standby apply kip primary tai luc check. |
| `Average Apply Rate: 34.00 KByte/s` | Toc do apply trung binh broker do duoc. |
| `Real Time Query: ON` | Standby dang doc duoc trong khi apply redo. |
| `Database Status: SUCCESS` | Standby dang OK theo Broker. |

## 12. Broker verbose standby status

### Query DGMGRL

```text
DGMGRL> show database verbose orclcdb_standby;
```

### Ket qua quan trong

```text
Role:                PHYSICAL STANDBY
Intended State:      APPLY-ON
Transport Lag:       0 seconds (computed 1 second ago)
Apply Lag:           0 seconds (computed 1 second ago)
Average Apply Rate:  34.00 KByte/s
Active Apply Rate:   1.46 MByte/s
Maximum Apply Rate:  34.85 MByte/s
Real Time Query:     ON

Properties:
  ApplyLagThreshold               = '30'
  DGConnectIdentifier             = 'standby_dg'
  DelayMins                       = '0'
  LogShipping                     = 'ON'
  LogXptMode                      = 'ASYNC'
  TransportDisconnectedThreshold  = '30'
  TransportLagThreshold           = '30'

Database Status:
SUCCESS
```

### Phan tich

| Property | Gia tri | Y nghia |
|---|---|---|
| `ApplyLagThreshold` | `30` | Broker threshold mac dinh/cau hinh cho apply lag. |
| `TransportLagThreshold` | `30` | Broker threshold cho transport lag. |
| `TransportDisconnectedThreshold` | `30` | Neu transport disconnect qua nguong nay se can canh bao. |
| `DGConnectIdentifier` | `standby_dg` | Service/alias Broker dung de noi toi standby. |
| `DelayMins` | `0` | Khong co apply delay co y. |
| `LogShipping` | `ON` | Primary/standby dang cau hinh ship redo. |
| `LogXptMode` | `ASYNC` | Redo transport dang bat dong bo, dung voi MaxPerformance. |

Ket luan: Broker monitor doc duoc standby, standby dang APPLY-ON, lag = 0.

## 13. Leader election / automatic failover status

Trong Oracle Data Guard khong goi la `leader election` nhu Kafka/Raft/Kubernetes.

Oracle dung cac khai niem:

```text
Primary role
Standby role
Switchover
Failover
Fast-Start Failover (FSFO)
Observer
```

Trang thai hien tai:

```text
Fast-Start Failover: Disabled
```

Nghia la:

```text
Chua co tu dong failover.
Chua co observer quyet dinh failover.
Chua co "leader election" tu dong.
```

Neu primary chet tai trang thai hien tai, can thao tac thu cong bang DGMGRL:

```text
DGMGRL> failover to orclcdb_standby;
```

Neu hai node con song va muon doi vai tro co kiem soat:

```text
DGMGRL> switchover to orclcdb_standby;
```

Muon co hanh vi gan voi "leader election" hon thi can phase sau:

```text
1. Bat Fast-Start Failover.
2. Chay Observer tren may/host thu ba.
3. Dat threshold/health condition ro rang.
4. Test failover trong lab truoc.
```

Khong nen bat FSFO ngay khi moi hoc vi no co kha nang tu dong doi vai tro database neu cau hinh/test sai.

