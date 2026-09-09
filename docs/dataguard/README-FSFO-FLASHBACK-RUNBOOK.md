# FSFO + Flashback runbook

Muc tieu: chuan bi Fast-Start Failover (FSFO) cho Data Guard lab.

Trang thai an toan hien tai:

```text
Primary:  ORCLCDB_PRIMARY
Standby:  orclcdb_standby
Broker:   lab_dg SUCCESS
Observer: oraee-dg-observer da connect duoc DGMGRL
FSFO:     Disabled
```

Khong enable FSFO neu `FLASHBACK_ON = NO`.

## 1. Trang thai vua check tren primary

Da chay tren primary:

```sql
archive log list;
```

Ket qua:

```text
Database log mode                       Archive log Mode
Automatic archival                      Enabled
Archive destination                     USE_DB_RECOVERY_FILE_DEST
Oldest online log sequence              28
Next log sequence to archive            30
Current log sequence                    30
```

Phan tich:

| Dong | Y nghia |
|---|---|
| `Archive log Mode` | Primary da bat ARCHIVELOG, day la dieu kien can cho Data Guard va Flashback. |
| `Automatic archival Enabled` | Oracle tu archive redo log. |
| `Archive destination USE_DB_RECOVERY_FILE_DEST` | Archive log dang dung FRA/db_recovery_file_dest. |
| `Current log sequence 30` | Primary dang o redo sequence 30 tai thoi diem check. |

Can check tiep FRA vi archive destination dang dung `USE_DB_RECOVERY_FILE_DEST`.

## 2. Check FRA tren primary

Vao primary:

```bash
podman exec -it oraee-dg-primary bash
sql / as sysdba
```

Chay:

```sql
show parameter db_recovery_file_dest;
show parameter db_recovery_file_dest_size;

select name,
       space_limit/1024/1024/1024 as limit_gb,
       space_used/1024/1024/1024 as used_gb,
       space_reclaimable/1024/1024/1024 as reclaimable_gb,
       number_of_files
from v$recovery_file_dest;
```

### Ket qua da check tren primary

```text
SYS@PRIMARY> select name, flashback_on, database_role, open_mode
from v$database;

NAME       FLASHBACK_ON    DATABASE_ROLE    OPEN_MODE
__________ _______________ ________________ _____________
ORCLCDB    NO              PRIMARY          READ WRITE

SYS@PRIMARY> show parameter db_recovery_file_dest;

NAME                       TYPE        VALUE
-------------------------- ----------- -----
db_recovery_file_dest      string
db_recovery_file_dest_size big integer 0

SYS@PRIMARY> show parameter db_recovery_file_dest_size;

NAME                       TYPE        VALUE
-------------------------- ----------- -----
db_recovery_file_dest_size big integer 0

SYS@PRIMARY> select name,
  2         space_limit/1024/1024/1024 as limit_gb,
  3         space_used/1024/1024/1024 as used_gb,
  4         space_reclaimable/1024/1024/1024 as reclaimable_gb,
  5         number_of_files
  6  from v$recovery_file_dest;

no rows selected
```

### Phan tich ket qua primary

| Ket qua | Y nghia |
|---|---|
| `FLASHBACK_ON = NO` | Flashback chua bat tren primary. |
| `db_recovery_file_dest` rong | FRA chua duoc cau hinh ro rang. |
| `db_recovery_file_dest_size = 0` | FRA size dang bang 0, chua dung duoc cho flashback logs. |
| `v$recovery_file_dest no rows selected` | Oracle chua co FRA destination active. |

Ket luan:

```text
Chua bat duoc Flashback ngay.
Can cau hinh FRA tren primary truoc.
```

### Check OS folder tren primary

Da vao primary container:

```bash
podman exec -it oraee-dg-primary bash
```

Tim folder recovery/FRA/flashback:

```bash
find /opt/oracle -maxdepth 5 -type d \( -iname '*recovery*' -o -iname '*fra*' -o -iname '*flash*' \) 2>/dev/null
```

Ket qua:

```text
khong co output
```

List folder duoi data volume:

```bash
find /opt/oracle/oradata -maxdepth 4 -type d 2>/dev/null
```

Ket qua:

```text
/opt/oracle/oradata
/opt/oracle/oradata/ORCLCDB
/opt/oracle/oradata/ORCLCDB/onlinelog
/opt/oracle/oradata/ORCLCDB/48945B67D122C623E063399B5E6478E6
/opt/oracle/oradata/ORCLCDB/48945B67D122C623E063399B5E6478E6/datafile
/opt/oracle/oradata/ORCLCDB/52035EA21D710DD7E0630301590AF726
/opt/oracle/oradata/ORCLCDB/52035EA21D710DD7E0630301590AF726/datafile
/opt/oracle/oradata/ORCLCDB/archive_logs
/opt/oracle/oradata/ORCLCDB/datafile
/opt/oracle/oradata/ORCLCDB/datafile/ahub_cln_3573548017
/opt/oracle/oradata/ORCLCDB/datafile/ahub_svr_3573548017
/opt/oracle/oradata/ORCLCDB/datafile/ahub_cln_3978517281
/opt/oracle/oradata/ORCLCDB/datafile/ahub_svr_3978517281
/opt/oracle/oradata/ORCLCDB/controlfile
/opt/oracle/oradata/dbconfig
/opt/oracle/oradata/dbconfig/ORCLCDB
/opt/oracle/oradata/dbconfig/ORCLCDB/dbs
```

Tim archive folder:

```bash
find /opt/oracle/oradata -maxdepth 5 -type d -iname '*archive*' 2>/dev/null
```

Ket qua:

```text
/opt/oracle/oradata/ORCLCDB/archive_logs
```

Phan tich:

| Folder | Y nghia |
|---|---|
| `/opt/oracle/oradata/ORCLCDB/archive_logs` | Archive log folder hien co. |
| Khong co `fast_recovery_area` | FRA folder chua ton tai. |
| Khong co folder `recovery/fra/flash` | Image/container chua tao san FRA rieng. |

Ket luan:

```text
Can tao folder FRA rieng truoc khi set db_recovery_file_dest.
Nen tao duoi /opt/oracle/oradata vi day la data volume cua container.
```

Lenh tao FRA folder tren primary:

```bash
mkdir -p /opt/oracle/oradata/fast_recovery_area
ls -ld /opt/oracle/oradata/fast_recovery_area
```

Ket qua da tao:

```text
drwxr-xr-x 2 oracle oinstall 4096 May 25 16:10 /opt/oracle/oradata/fast_recovery_area
```

Set FRA tren primary da thanh cong:

```sql
alter system set db_recovery_file_dest='/opt/oracle/oradata/fast_recovery_area' scope=both;
```

Ket qua:

```text
System altered.
```

Verify parameter:

```sql
show parameter db_recovery_file_dest;
show parameter db_recovery_file_dest_size;
```

Ket qua:

```text
NAME                       TYPE        VALUE
-------------------------- ----------- --------------------------------------
db_recovery_file_dest      string      /opt/oracle/oradata/fast_recovery_area
db_recovery_file_dest_size big integer 20G

NAME                       TYPE        VALUE
-------------------------- ----------- -----
db_recovery_file_dest_size big integer 20G
```

Verify `v$recovery_file_dest`:

```sql
select name,
       space_limit/1024/1024/1024 as limit_gb,
       space_used/1024/1024/1024 as used_gb,
       space_reclaimable/1024/1024/1024 as reclaimable_gb,
       number_of_files
from v$recovery_file_dest;
```

Ket qua:

```text
NAME                                         LIMIT_GB    USED_GB    RECLAIMABLE_GB    NUMBER_OF_FILES
_________________________________________ ___________ __________ _________________ __________________
/opt/oracle/oradata/fast_recovery_area             20          0                 0                  0
```

Ket luan:

```text
Primary FRA da OK.
Co the bat Flashback tren primary.
```

Neu `db_recovery_file_dest` rong hoac size qua nho, set cho lab:

```sql
alter system set db_recovery_file_dest_size=20G scope=both;
alter system set db_recovery_file_dest='/opt/oracle/oradata/fast_recovery_area' scope=both;
```

Verify lai:

```sql
show parameter db_recovery_file_dest;
show parameter db_recovery_file_dest_size;
```

Verify bang view:

```sql
select name,
       space_limit/1024/1024/1024 as limit_gb,
       space_used/1024/1024/1024 as used_gb,
       space_reclaimable/1024/1024/1024 as reclaimable_gb,
       number_of_files
from v$recovery_file_dest;
```

Ky vong sau khi set:

```text
NAME co duong dan /opt/oracle/oradata/fast_recovery_area
LIMIT_GB khoang 20
```

## 3. Bat Flashback tren primary

Chi chay sau khi FRA OK.

```sql
alter database flashback on;

select name, flashback_on, database_role, open_mode
from v$database;
```

Ky vong:

```text
FLASHBACK_ON = YES
DATABASE_ROLE = PRIMARY
OPEN_MODE = READ WRITE
```

### Ket qua da chay tren primary

Chay:

```sql
alter database flashback on;
```

Ket qua:

```text
Error starting at line : 1 in command -
  alter database flashback on
Error report -
ORA-38706: Cannot turn on FLASHBACK DATABASE logging.
ORA-38713: Flashback Database logging is already turned on.
```

Phan tich:

```text
ORA-38713 noi rang Flashback Database logging da duoc bat roi.
Day khong phai loi can rollback trong lab nay.
Can verify bang v$database.
```

Verify:

```sql
select name, flashback_on, database_role, open_mode
from v$database;
```

Ket qua:

```text
NAME       FLASHBACK_ON    DATABASE_ROLE    OPEN_MODE
__________ _______________ ________________ _____________
ORCLCDB    YES             PRIMARY          READ WRITE
```

Ket luan:

```text
Primary Flashback da ON.
Tiep theo lam FRA + Flashback tren standby.
```

## 4. Check FRA tren standby

Vao standby:

```bash
podman exec -it oraee-dg-standby bash
sql / as sysdba
```

Chay:

```sql
show parameter db_recovery_file_dest;
show parameter db_recovery_file_dest_size;

select name,
       space_limit/1024/1024/1024 as limit_gb,
       space_used/1024/1024/1024 as used_gb,
       space_reclaimable/1024/1024/1024 as reclaimable_gb,
       number_of_files
from v$recovery_file_dest;
```

### Ket qua da tao FRA folder tren standby

Tren host:

```bash
podman exec -it oraee-dg-standby bash
```

Trong standby container:

```bash
mkdir -p /opt/oracle/oradata/fast_recovery_area
ls -ld /opt/oracle/oradata/fast_recovery_area
```

Ket qua:

```text
drwxr-xr-x 2 oracle oinstall 4096 May 25 16:15 /opt/oracle/oradata/fast_recovery_area
```

### Ket qua check ban dau tren standby

```sql
select name, flashback_on, database_role, open_mode
from v$database;
```

Ket qua:

```text
NAME       FLASHBACK_ON    DATABASE_ROLE       OPEN_MODE
__________ _______________ ___________________ _______________________
ORCLCDB    NO              PHYSICAL STANDBY    READ ONLY WITH APPLY
```

Check FRA parameter:

```sql
show parameter db_recovery_file_dest;
show parameter db_recovery_file_dest_size;
```

Ket qua:

```text
NAME                       TYPE        VALUE
-------------------------- ----------- -----
db_recovery_file_dest      string
db_recovery_file_dest_size big integer 0

NAME                       TYPE        VALUE
-------------------------- ----------- -----
db_recovery_file_dest_size big integer 0
```

Check `v$recovery_file_dest`:

```sql
select name,
       space_limit/1024/1024/1024 as limit_gb,
       space_used/1024/1024/1024 as used_gb,
       space_reclaimable/1024/1024/1024 as reclaimable_gb,
       number_of_files
from v$recovery_file_dest;
```

Ket qua:

```text
NAME       LIMIT_GB    USED_GB    RECLAIMABLE_GB    NUMBER_OF_FILES
_______ ___________ __________ _________________ __________________
                  0          0                 0                  0
```

Phan tich:

```text
Standby luc dau chua co FRA active va Flashback dang NO.
Folder FRA da tao san san sang cho db_recovery_file_dest.
```

Neu can set cho lab:

```sql
alter system set db_recovery_file_dest_size=20G scope=both;
alter system set db_recovery_file_dest='/opt/oracle/oradata/fast_recovery_area' scope=both;
```

### Ket qua set FRA tren standby

```sql
alter system set db_recovery_file_dest_size=20G scope=both;
alter system set db_recovery_file_dest='/opt/oracle/oradata/fast_recovery_area' scope=both;
```

Ket qua:

```text
System altered.
System altered.
```

## 5. Bat Flashback tren standby

Standby hien dang `READ ONLY WITH APPLY`, nen dung cach an toan:

```sql
alter database recover managed standby database cancel;

alter database flashback on;

alter database recover managed standby database using current logfile disconnect from session;
```

Verify:

```sql
select name, flashback_on, database_role, open_mode
from v$database;

select name, value, time_computed
from v$dataguard_stats
where name in ('transport lag','apply lag');

select process, status, sequence#, thread#
from v$managed_standby
order by process;
```

Ky vong:

```text
FLASHBACK_ON = YES
DATABASE_ROLE = PHYSICAL STANDBY
MRP0 = APPLYING_LOG
transport lag = 0
apply lag = 0
```

### Ket qua da bat Flashback tren standby

Tat apply tam:

```sql
alter database recover managed standby database cancel;
```

Ket qua:

```text
Database altered.
```

Bat Flashback:

```sql
alter database flashback on;
```

Ket qua:

```text
Database altered.
```

Bat apply lai:

```sql
alter database recover managed standby database using current logfile disconnect from session;
```

Ket qua:

```text
Database altered.
```

Verify Flashback:

```sql
select name, flashback_on, database_role, open_mode
from v$database;
```

Ket qua:

```text
NAME       FLASHBACK_ON    DATABASE_ROLE       OPEN_MODE
__________ _______________ ___________________ _______________________
ORCLCDB    YES             PHYSICAL STANDBY    READ ONLY WITH APPLY
```

Verify lag:

```sql
select name, value, time_computed
from v$dataguard_stats
where name in ('transport lag','apply lag');
```

Ket qua:

```text
NAME             VALUE           TIME_COMPUTED
________________ _______________ ______________________
transport lag    +00 00:00:00    05/25/2026 16:18:35
apply lag        +00 00:00:00    05/25/2026 16:18:35
```

Verify managed recovery:

```sql
select process, status, sequence#, thread#
from v$managed_standby
order by process;
```

Ket qua:

```text
PROCESS    STATUS             SEQUENCE#    THREAD#
__________ _______________ ____________ __________
ARCH       CONNECTED                  0          0
ARCH       CONNECTED                  0          0
ARCH       CONNECTED                  0          0
ARCH       CLOSING                   29          1
DGRD       ALLOCATED                  0          0
DGRD       ALLOCATED                  0          0
MRP0       APPLYING_LOG              30          1
RFS        IDLE                       0          0
RFS        IDLE                       0          1
RFS        IDLE                      30          1
```

Ket luan:

```text
Standby Flashback da ON.
Managed recovery da bat lai.
Transport lag = 0.
Apply lag = 0.
```

Neu `alter database flashback on` tren standby bi loi do open mode, dung cach mount:

```sql
alter database recover managed standby database cancel;
shutdown immediate;
startup mount;
alter database flashback on;
alter database open read only;
alter database recover managed standby database using current logfile disconnect from session;
```

## 6. Check Broker sau khi bat Flashback

Vao observer:

```bash
podman exec -it oraee-dg-observer bash
dgmgrl sys@PRIMARY_DG
```

Trong DGMGRL:

```text
show configuration;
show database ORCLCDB_PRIMARY;
show database orclcdb_standby;
show fast_start failover;
```

Can thay:

```text
Configuration Status: SUCCESS
Primary Database Status: SUCCESS
Standby Database Status: SUCCESS
FSFO: Disabled
```

### Ket qua da check sau khi bat Flashback hai ben

Luu y thao tac:

```text
Khong go `dgmgrl sys@PRIMARY_DG` ben trong prompt DGMGRL.
Neu dang o `DGMGRL>`, go `exit` truoc de ve bash.
Sau do moi chay `dgmgrl sys@PRIMARY_DG`.
```

Da connect tu observer:

```text
bash-4.4$ dgmgrl sys@PRIMARY_DG
Password:
Connected to "ORCLCDB_PRIMARY"
Connected as SYSDBA.
```

Check configuration:

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

Check primary:

```text
DGMGRL> show database ORCLCDB_PRIMARY;

Database - ORCLCDB_PRIMARY

  Role:                PRIMARY
  Intended State:      TRANSPORT-ON
  Redo Rate:           104 Byte/s  in 15 seconds (computed 4 seconds ago)
  Instance(s):
    ORCLCDB

Database Status:
SUCCESS
```

Check standby:

```text
DGMGRL> show database orclcdb_standby;

Database - orclcdb_standby

  Role:                PHYSICAL STANDBY
  Intended State:      APPLY-ON
  Transport Lag:       0 seconds (computed 1 second ago)
  Apply Lag:           0 seconds (computed 1 second ago)
  Average Apply Rate:  1.00 KByte/s
  Real Time Query:     ON
  Instance(s):
    ORCLCDB

Database Status:
SUCCESS
```

Check FSFO:

```text
DGMGRL> show fast_start failover;

Fast-Start Failover:  Disabled

  Protection Mode:    MaxPerformance
  Lag Limit:          30 seconds
  Lag Type:           APPLY

  Threshold:          30 seconds
  Ping Interval:      3000 milliseconds
  Ping Retry:         0
  Active Target:      (none)
  Potential Targets:  "orclcdb_standby"
    orclcdb_standby valid
  Observer:           (none)
  Shutdown Primary:   TRUE
  Auto-reinstate:     TRUE
  Observer Reconnect: (none)
  Observer Override:  FALSE
  Lag Grace Time:     0 seconds

Configurable Failover Conditions
  Health Conditions:
    Corrupted Controlfile          YES
    Corrupted Dictionary           YES
    Inaccessible Logfile            NO
    Stuck Archiver                  NO
    Datafile Write Errors          YES

  Oracle Error Conditions:
    (none)
```

Phan tich:

| Dong | Y nghia |
|---|---|
| `Configuration Status: SUCCESS` | Broker config dang on. |
| Primary `TRANSPORT-ON` | Primary dang ship redo. |
| Standby `APPLY-ON` | Standby dang apply redo. |
| `Transport Lag: 0 seconds` | Khong tre transport. |
| `Apply Lag: 0 seconds` | Khong tre apply. |
| `Fast-Start Failover: Disabled` | Chua bat auto failover, van an toan. |
| `Potential Targets: "orclcdb_standby" valid` | Standby da du dieu kien lam target FSFO. |
| `Observer: (none)` | Chua start observer process that. |

Ket luan:

```text
Primary/standby/Broker/Flashback da san sang hon cho FSFO.
FSFO van chua bat.
Standby da la potential target hop le.
Buoc tiep theo la start observer process, roi sau do moi can nhac enable FSFO.
```

## 7. Set FSFO target, chua enable

Chi chay sau khi:

```text
Primary FLASHBACK_ON = YES
Standby FLASHBACK_ON = YES
Broker SUCCESS
Lag = 0
```

Trong DGMGRL:

```text
edit database ORCLCDB_PRIMARY set property FastStartFailoverTarget='orclcdb_standby';
edit database orclcdb_standby set property FastStartFailoverTarget='ORCLCDB_PRIMARY';
```

Check:

```text
show database verbose ORCLCDB_PRIMARY;
show database verbose orclcdb_standby;
show fast_start failover;
```

Luc nay `Potential Targets` nen hien standby.

## 8. Start observer process, chua enable FSFO

Observer process nen chay trong `oraee-dg-observer`.

Vao observer:

```bash
podman exec -it oraee-dg-observer bash
```

Test DGMGRL:

```bash
dgmgrl sys@PRIMARY_DG
```

Neu OK, thoat ra roi chay observer foreground de test:

```bash
dgmgrl sys@PRIMARY_DG "start observer"
```

Ghi chu:

```text
Observer process la thanh phan can thiet cho FSFO.
Neu observer chet, FSFO khong the tu dong quyet dinh failover.
```

### Ket qua start observer

Trong DGMGRL:

```text
DGMGRL> start observer;
Observer file "/home/oracle/fsfo.dat" is created.
Succeeded in opening the observer file "/home/oracle/fsfo.dat".
[W000 2026-05-25T16:23:33.135+00:00] FSFO target standby is
Observer 'c31c2f05e111' started
The observer log file is '/home/oracle/observer_c31c2f05e111.log'.
```

Check log trong observer container:

```bash
tail -n 80 /home/oracle/observer_c31c2f05e111.log
```

Ket qua:

```text
Observer 'c31c2f05e111' started
[W000 2026-05-25T16:23:33.184+00:00] Observer trace level is set to USER
[W000 2026-05-25T16:23:33.188+00:00] Fast-Start Failover is disabled.
[W000 2026-05-25T16:23:33.188+00:00] Fast-Start Failover is not enabled or can't be checked. Retry after 15 seconds.
```

Phan tich:

```text
Observer da chay.
Canh bao nay binh thuong vi luc do FSFO chua enable.
```

Check DGMGRL sau khi observer chay:

```text
DGMGRL> show fast_start failover;
```

Ket qua quan trong:

```text
Fast-Start Failover:  Disabled
Potential Targets:  "orclcdb_standby"
  orclcdb_standby valid
Observer:           c31c2f05e111
Auto-reinstate:     TRUE
```

Ket luan:

```text
Observer process da duoc Broker nhan.
FSFO luc nay van Disabled, chua tu dong failover.
```

## 9. Enable FSFO - chua lam

Chi lam khi da san sang test failover.

Trong DGMGRL:

```text
enable fast_start failover;
show fast_start failover;
```

Khong chay lenh nay khi chua co checkpoint.

### Ket qua da enable FSFO

Luu y thao tac:

```text
Khong chay `dgmgrl sys@PRIMARY_DG` trong SQL prompt.
Neu dang o `SQL>`, go `exit` ve bash roi moi chay `dgmgrl`.
```

Da chay:

```text
DGMGRL> enable fast_start failover;
Enabled in Potential Data Loss Mode.
```

Check:

```text
DGMGRL> show fast_start failover;
```

Ket qua:

```text
Fast-Start Failover: Enabled in Potential Data Loss Mode

  Protection Mode:    MaxPerformance
  Lag Limit:          30 seconds
  Lag Type:           APPLY

  Threshold:          30 seconds
  Ping Interval:      3000 milliseconds
  Ping Retry:         0
  Active Target:      orclcdb_standby
  Potential Targets:  "orclcdb_standby"
    orclcdb_standby valid
  Observer:           c31c2f05e111
  Shutdown Primary:   TRUE
  Auto-reinstate:     TRUE
  Observer Reconnect: (none)
  Observer Override:  FALSE
  Lag Grace Time:     0 seconds

Configurable Failover Conditions
  Health Conditions:
    Corrupted Controlfile          YES
    Corrupted Dictionary           YES
    Inaccessible Logfile            NO
    Stuck Archiver                  NO
    Datafile Write Errors          YES

  Oracle Error Conditions:
    (none)
```

Check configuration:

```text
DGMGRL> show configuration;

Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  ORCLCDB_PRIMARY - Primary database
    orclcdb_standby - (*) Physical standby database

Fast-Start Failover: Enabled in Potential Data Loss Mode

Configuration Status:
SUCCESS   (status updated 24 seconds ago)
```

Phan tich:

| Dong | Y nghia |
|---|---|
| `Enabled in Potential Data Loss Mode` | FSFO da bat, nhung vi MaxPerformance/ASYNC nen co kha nang mat redo chua apply neu primary chet dung luc. |
| `Active Target: orclcdb_standby` | Standby hien la target ma observer se failover toi. |
| `(*) Physical standby database` | Dau `(*)` danh dau FSFO target. |
| `Observer: c31c2f05e111` | Observer process dang duoc Broker nhan. |
| `Auto-reinstate: TRUE` | Sau failover, Broker co the reinstate old primary neu dieu kien cho phep, Flashback da bat giup viec nay de hon. |
| `Configuration Status: SUCCESS` | Cau hinh dang OK sau khi enable FSFO. |

Checkpoint hien tai:

```text
FSFO da enable.
Mode la Potential Data Loss Mode vi MaxPerformance/ASYNC.
Khong stop/kill primary neu chua co ke hoach test va reinstate.
```

### Observer log sau khi enable FSFO

Check log trong observer container:

```bash
tail -n 80 /home/oracle/observer_c31c2f05e111.log
```

Ket qua moi:

```text
[W000 2026-05-25T16:29:03.285+00:00] Standby database has changed to orclcdb_standby.
[W000 2026-05-25T16:29:03.326+00:00] Entering PING state
[W000 2026-05-25T16:29:03.326+00:00] Observer Summary (Monitoring):
[W000 2026-05-25T16:29:03.326+00:00] Fast-Start Failover information:
	Primary database, Name: ORCLCDB_PRIMARY, Connect String: primary_dg
	Standby database, Name: orclcdb_standby, Connect String: standby_dg
	Auto Reinst: TRUE
[W000 2026-05-25T16:29:03.326+00:00] Observer State:
	Name: c31c2f05e111, Host: c31c2f05e111, OBID: 1537120977 (0x5b9e9ad1)
	svrflgs: 0x0, version: 0, ctlflgs: 0x60
	target: 2, fsfo_miv: 1
[W000 2026-05-25T16:29:03.326+00:00] Try to connect to the primary.
[W000 2026-05-25T16:29:03.326+00:00] Try to connect to the primary primary_dg.
[W000 2026-05-25T16:29:03.362+00:00] The standby orclcdb_standby is ready to be a FSFO target
[W000 2026-05-25T16:29:04.362+00:00] Connection to the primary restored!
[W000 2026-05-25T16:29:06.357+00:00] Disconnecting from database primary_dg.
```

Phan tich:

| Log | Y nghia |
|---|---|
| `Entering PING state` | Observer da vao trang thai monitor/ping primary. |
| `Primary database ... ORCLCDB_PRIMARY` | Observer nhan dung primary hien tai. |
| `Standby database ... orclcdb_standby` | Observer nhan dung standby/target. |
| `Auto Reinst: TRUE` | Auto-reinstate dang bat trong Broker config. |
| `The standby orclcdb_standby is ready to be a FSFO target` | Standby du dieu kien lam target FSFO. |
| `Connection to the primary restored!` | Observer ket noi primary thanh cong sau khi thu connect. |

Ket luan:

```text
Observer dang monitor.
Standby da ready lam FSFO target.
FSFO da vao trang thai co the hoat dong neu primary mat ket noi theo dieu kien Broker.
```

## 10. Rollback / tat FSFO neu can

Trong DGMGRL:

```text
disable fast_start failover;
show fast_start failover;
```

Dung observer:

```text
stop observer;
```

Hoac dung container observer:

```bash
podman stop oraee-dg-observer
```

### Ket qua tat FSFO cuoi buoi

Sau khi test switchover xong, observer foreground da bi `Ctrl+C` truoc khi disable FSFO.

Luu y:

```text
Ctrl+C observer process khong lam Data Guard banh.
Nhung FSFO config van co the dang Enabled trong Broker.
Can connect lai DGMGRL qua TNS va disable FSFO.
```

Sai cach da gap:

```bash
dgmgrl /
```

Trong observer container, lenh nay ket noi local idle instance va bao:

```text
Connected to an idle instance.
ORA-01034: The Oracle instance is not available for use. Start the instance.
```

Phan tich:

```text
Observer container khong phai DB server.
Khong dung OS auth `/` trong observer.
Phai dung remote connect qua TNS: dgmgrl sys@PRIMARY_DG
```

Dung cach:

```bash
dgmgrl sys@PRIMARY_DG
```

Ket qua connect:

```text
Connected to "ORCLCDB_PRIMARY"
Connected as SYSDBA.
```

Check truoc khi disable:

```text
DGMGRL> show configuration;

Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  ORCLCDB_PRIMARY - Primary database
    orclcdb_standby - (*) Physical standby database

Fast-Start Failover: Enabled in Potential Data Loss Mode

Configuration Status:
SUCCESS   (status updated 21 seconds ago)
```

```text
DGMGRL> show fast_start failover;

Fast-Start Failover: Enabled in Potential Data Loss Mode
Active Target:      orclcdb_standby
Potential Targets:  "orclcdb_standby"
  orclcdb_standby valid
Observer:           c31c2f05e111
Auto-reinstate:     TRUE
```

Disable:

```text
DGMGRL> disable fast_start failover;
Disabled.
```

Verify:

```text
DGMGRL> show fast_start failover;

Fast-Start Failover:  Disabled
Active Target:      (none)
Potential Targets:  "orclcdb_standby"
  orclcdb_standby valid
Observer:           c31c2f05e111
Auto-reinstate:     TRUE
```

Trang thai cuoi cung:

```text
Configuration Status: SUCCESS
Primary: ORCLCDB_PRIMARY
Standby: orclcdb_standby
FSFO: Disabled
Potential target: orclcdb_standby valid
Observer: c31c2f05e111 con duoc Broker ghi nhan
```

Ket luan:

```text
Ket thuc buoi test o trang thai an toan.
FSFO da tat, nen stop container se khong kich hoat auto failover.
```

Stop containers:

```bash
podman stop oraee-dg-observer oraee-dg-primary oraee-dg-standby
```

Mai bat lai:

```bash
podman start oraee-dg-primary oraee-dg-standby oraee-dg-observer
```

Check sau khi bat:

```bash
podman exec -it oraee-dg-observer bash
dgmgrl sys@PRIMARY_DG
```

```text
show configuration;
show fast_start failover;
```

## 11. Chuan bi test switchover - checkpoint

Muc tieu test:

```text
Cho standby len lam primary bang switchover.
Sau do switchover nguoc lai primary cu.
```

Khong dung `failover` cho bai test nay vi primary van con song. Dung `switchover`.

### Check configuration truoc switchover

Trong DGMGRL:

```text
DGMGRL> show configuration;
```

Ket qua:

```text
Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  ORCLCDB_PRIMARY - Primary database
    orclcdb_standby - (*) Physical standby database

Fast-Start Failover: Enabled in Potential Data Loss Mode

Configuration Status:
SUCCESS   (status updated 14 seconds ago)
```

Phan tich:

```text
Broker SUCCESS.
FSFO dang enabled.
orclcdb_standby dang la FSFO target, danh dau bang (*).
```

### Validate primary

```text
DGMGRL> validate database ORCLCDB_PRIMARY;
```

Ket qua:

```text
  Database Role:    Primary database

  Ready for Switchover:  Yes

  Managed by Clusterware:
    ORCLCDB_PRIMARY:  NO
    The static connect identifier did not allow for a connection to
    database "ORCLCDB_PRIMARY". Ensure the static connect identifier is configured
    correctly so that DGMGRL can start the primary database after switchover.
```

Phan tich:

| Dong | Y nghia |
|---|---|
| `Ready for Switchover: Yes` | Ve mat role/Data Guard, primary san sang switchover. |
| Static connect warning | Broker co the khong tu start duoc database nay sau switchover neu can restart. Can fix truoc khi test cho sach. |

### Validate standby

```text
DGMGRL> validate database orclcdb_standby;
```

Ket qua:

```text
  Database Role:     Physical standby database
  Primary Database:  ORCLCDB_PRIMARY

  Ready for Switchover:  Yes
  Ready for Failover:    Yes (Primary Running)

  Managed by Clusterware:
    ORCLCDB_PRIMARY:  NO
    orclcdb_standby:  NO
    The static connect identifier did not allow for a connection to
    database "ORCLCDB_PRIMARY". Ensure the static connect identifier is configured
    correctly so that DGMGRL can start the primary database after switchover.

  Current Log File Groups Configuration:
    Thread #  Online Redo Log Groups  Standby Redo Log Groups
              (ORCLCDB_PRIMARY)       (orclcdb_standby)
    1         3                       2

  Future Log File Groups Configuration:
    Thread #  Online Redo Log Groups  Standby Redo Log Groups
              (orclcdb_standby)       (ORCLCDB_PRIMARY)
    1         3                       0
    Warning: standby redo logs not configured for thread 1 on ORCLCDB_PRIMARY

  Parameter Settings:
    Parameter                       ORCLCDB_PRIMARY Value    orclcdb_standby Value
    DB_BLOCK_CHECKING               FALSE                    FALSE
    DB_BLOCK_CHECKSUM               TYPICAL                  TYPICAL
    DB_LOST_WRITE_PROTECT           AUTO                     AUTO
```

Phan tich:

| Dong | Y nghia |
|---|---|
| `Ready for Switchover: Yes` | Standby san sang doi role ve mat Broker. |
| `Ready for Failover: Yes (Primary Running)` | Neu primary chet, standby co the failover. |
| Static connect warning | Van can fix static connect identifier cua `ORCLCDB_PRIMARY`. |
| `Future ... ORCLCDB_PRIMARY ... Standby Redo Log Groups 0` | Broker dang thay primary cu se khong co SRL khi tro thanh standby sau switchover. Can doi chieu voi SQL view. |

### Doi chieu SQL: primary co SRL

Da check trong SQL tren primary:

```sql
select group#, bytes/1024/1024 as size_mb
from v$log
order by group#;

select group#, bytes/1024/1024 as size_mb, status
from v$standby_log
order by group#;
```

Ket qua:

```text
   GROUP#    SIZE_MB
_________ __________
        1        200
        2        200
        3        200

   GROUP#    SIZE_MB STATUS
_________ __________ _____________
        4        200 UNASSIGNED
        5        200 UNASSIGNED
        6        200 UNASSIGNED
        7        200 UNASSIGNED
```

Phan tich:

```text
Primary SQL thay co 4 standby redo logs, moi log 200M.
Broker validate van bao future SRL = 0.
Can tiep tuc check Broker metadata/static connect truoc khi switchover.
```

### Show verbose primary

```text
DGMGRL> show database verbose ORCLCDB_PRIMARY;
```

Ket qua quan trong:

```text
Database - ORCLCDB_PRIMARY

  Role:                PRIMARY
  Intended State:      TRANSPORT-ON
  Redo Rate:           97 Byte/s  in 15 seconds (computed 4 seconds ago)
  Instance(s):
    ORCLCDB

  Properties:
    DGConnectIdentifier             = 'primary_dg'
    FastStartFailoverTarget         = 'orclcdb_standby'
    LogShipping                     = 'ON'
    LogXptMode                      = 'ASYNC'
    StaticConnectIdentifier         = '(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=f8699589c6bf)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_PRIMARY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))'

Database Status:
SUCCESS
```

Phan tich:

| Property | Gia tri | Nhan xet |
|---|---|---|
| `DGConnectIdentifier` | `primary_dg` | Alias Broker dung de connect primary. |
| `FastStartFailoverTarget` | `orclcdb_standby` | FSFO target da set. |
| `LogShipping` | `ON` | Primary dang ship redo. |
| `LogXptMode` | `ASYNC` | Dung voi MaxPerformance/Potential Data Loss Mode. |
| `StaticConnectIdentifier` | Host `f8699589c6bf` | Dang la container ID/hostname runtime, khong phai stable name `oraee-dg-primary`. Day co the la ly do validate canh bao static connect. |

Checkpoint:

```text
Chua switchover voi trang thai nay neu muon test sach.
Can fix/confirm StaticConnectIdentifier cua ORCLCDB_PRIMARY truoc.
Can lam ro vi sao Broker validate van bao future SRL = 0 du SQL thay co 4 SRL.
```

### Show verbose standby

```text
DGMGRL> show database verbose orclcdb_standby;
```

Ket qua quan trong:

```text
Database - orclcdb_standby

  Role:                PHYSICAL STANDBY
  Intended State:      APPLY-ON
  Transport Lag:       0 seconds (computed 1 second ago)
  Apply Lag:           0 seconds (computed 1 second ago)
  Average Apply Rate:  2.00 KByte/s
  Active Apply Rate:   68.00 KByte/s
  Maximum Apply Rate:  68.00 KByte/s
  Real Time Query:     ON
  Instance(s):
    ORCLCDB

  Properties:
    DGConnectIdentifier             = 'standby_dg'
    FastStartFailoverTarget         = 'ORCLCDB_PRIMARY'
    LogShipping                     = 'ON'
    LogXptMode                      = 'ASYNC'
    StaticConnectIdentifier         = '(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=ec83fc6661e3)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_STANDBY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))'

Database Status:
SUCCESS
```

Phan tich:

| Property | Gia tri | Nhan xet |
|---|---|---|
| `DGConnectIdentifier` | `standby_dg` | Alias Broker dung de connect standby. |
| `FastStartFailoverTarget` | `ORCLCDB_PRIMARY` | Target nguoc da set. |
| `LogShipping` | `ON` | Cau hinh shipping OK. |
| `LogXptMode` | `ASYNC` | Dung voi MaxPerformance. |
| `StaticConnectIdentifier` | Host `ec83fc6661e3` | Cung la container ID/runtime hostname, khong on dinh bang `oraee-dg-standby`. |

Ket luan them:

```text
Ca primary va standby deu dang co StaticConnectIdentifier dung container ID.
Nen chinh ca hai sang container name on dinh tren network oraee-dg-net:
  ORCLCDB_PRIMARY -> oraee-dg-primary
  orclcdb_standby -> oraee-dg-standby
```

### Chinh StaticConnectIdentifier sang container name

Luu y: DGMGRL khong chap nhan quoted string bi cat dong. Phai paste moi lenh thanh mot dong day du.

Chay trong DGMGRL:

```text
EDIT DATABASE ORCLCDB_PRIMARY SET PROPERTY StaticConnectIdentifier='(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-primary)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_PRIMARY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))';

EDIT DATABASE orclcdb_standby SET PROPERTY StaticConnectIdentifier='(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-standby)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_STANDBY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))';
```

Ket qua:

```text
Property "staticconnectidentifier" updated for member "orclcdb_primary".
Property "staticconnectidentifier" updated for member "orclcdb_standby".
```

Verify primary:

```text
DGMGRL> SHOW DATABASE VERBOSE ORCLCDB_PRIMARY;
```

Ket qua quan trong:

```text
StaticConnectIdentifier = '(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-primary)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_PRIMARY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))'
Database Status:
SUCCESS
```

Verify standby:

```text
DGMGRL> SHOW DATABASE VERBOSE orclcdb_standby;
```

Ket qua quan trong:

```text
StaticConnectIdentifier = '(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-standby)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_STANDBY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))'
Database Status:
SUCCESS
```

Validate lai primary:

```text
DGMGRL> VALIDATE DATABASE ORCLCDB_PRIMARY;
```

Ket qua:

```text
  Database Role:    Primary database

  Ready for Switchover:  Yes

  Managed by Clusterware:
    ORCLCDB_PRIMARY:  NO
    The static connect identifier did not allow for a connection to
    database "ORCLCDB_PRIMARY". Ensure the static connect identifier is configured
    correctly so that DGMGRL can start the primary database after switchover.
```

Phan tich:

```text
StaticConnectIdentifier da doi tu container ID sang container name thanh cong.
Nhung validate van bao khong connect duoc static identifier.
Kha nang cao service ORCLCDB_PRIMARY_DGMGRL chua duoc listener expose/dang ky dung static GLOBAL_DBNAME.
Can check listener services tren primary va standby truoc khi switchover.
```

Buoc tiep theo de debug:

```bash
podman exec -it oraee-dg-primary bash
lsnrctl services
```

Va trong observer:

```bash
tnsping PRIMARY_DG
tnsping STANDBY_DG
```

Neu can test dung StaticConnectIdentifier service:

```bash
sqlplus -L sys@'(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-primary)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_PRIMARY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))' as sysdba
```

### Listener services hien tai

Check tren primary:

```bash
podman exec -it oraee-dg-primary bash
lsnrctl services
```

Ket qua quan trong:

```text
Services Summary...
Service "ORCLCDB" has 1 instance(s).
  Instance "ORCLCDB", status UNKNOWN, has 1 handler(s) for this service...

Service "ORCLCDBXDB" has 1 instance(s).
  Instance "ORCLCDB", status READY, has 1 handler(s) for this service...

Service "ORCLCDB_CFG" has 1 instance(s).
  Instance "ORCLCDB", status READY, has 1 handler(s) for this service...

Service "ORCLCDB_PRIMARY" has 1 instance(s).
  Instance "ORCLCDB", status READY, has 1 handler(s) for this service...

Service "orclpdb1" has 1 instance(s).
  Instance "ORCLCDB", status READY, has 1 handler(s) for this service...
```

Check tren standby:

```bash
podman exec -it oraee-dg-standby bash
lsnrctl services
```

Ket qua quan trong:

```text
Services Summary...
Service "ORCLCDB" has 1 instance(s).
  Instance "ORCLCDB", status UNKNOWN, has 1 handler(s) for this service...

Service "ORCLCDBXDB" has 1 instance(s).
  Instance "ORCLCDB", status READY, has 1 handler(s) for this service...

Service "ORCLCDB_CFG" has 1 instance(s).
  Instance "ORCLCDB", status READY, has 1 handler(s) for this service...

Service "ORCLCDB_STANDBY" has 1 instance(s).
  Instance "ORCLCDB", status READY, has 1 handler(s) for this service...

Service "orclpdb1" has 1 instance(s).
  Instance "ORCLCDB", status READY, has 1 handler(s) for this service...
```

Phan tich:

```text
Listener khong co service:
  ORCLCDB_PRIMARY_DGMGRL
  ORCLCDB_STANDBY_DGMGRL

Listener dang co service:
  ORCLCDB_PRIMARY
  ORCLCDB_STANDBY
  ORCLCDB
```

Vi vay `StaticConnectIdentifier` hien tai dang dung service `_DGMGRL` khong ton tai trong listener output, nen validate van warning la hop ly.

Huong fix tiep theo co 2 cach:

```text
Cach A: Doi StaticConnectIdentifier dung service hien co:
  ORCLCDB_PRIMARY
  ORCLCDB_STANDBY

Cach B: Them static GLOBAL_DBNAME *_DGMGRL vao listener.ora tren ca hai container.
```

Trong lab nay, cach A nhanh va it dung listener hon.

### Thu cach A: doi StaticConnectIdentifier sang service hien co

Chay trong DGMGRL:

```text
EDIT DATABASE ORCLCDB_PRIMARY SET PROPERTY StaticConnectIdentifier='(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-primary)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_PRIMARY)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))';

EDIT DATABASE orclcdb_standby SET PROPERTY StaticConnectIdentifier='(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-standby)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_STANDBY)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))';
```

Ket qua:

```text
Property "staticconnectidentifier" updated for member "orclcdb_primary".
Property "staticconnectidentifier" updated for member "orclcdb_standby".
```

Validate primary:

```text
DGMGRL> VALIDATE DATABASE ORCLCDB_PRIMARY;

  Database Role:    Primary database

  Ready for Switchover:  Yes

  Managed by Clusterware:
    ORCLCDB_PRIMARY:  NO
    The static connect identifier did not allow for a connection to
    database "ORCLCDB_PRIMARY". Ensure the static connect identifier is configured
    correctly so that DGMGRL can start the primary database after switchover.
```

Validate standby:

```text
DGMGRL> VALIDATE DATABASE orclcdb_standby;

  Database Role:     Physical standby database
  Primary Database:  ORCLCDB_PRIMARY

  Ready for Switchover:  Yes
  Ready for Failover:    Yes (Primary Running)

  Managed by Clusterware:
    ORCLCDB_PRIMARY:  NO
    orclcdb_standby:  NO
    The static connect identifier did not allow for a connection to
    database "ORCLCDB_PRIMARY". Ensure the static connect identifier is configured
    correctly so that DGMGRL can start the primary database after switchover.

  Current Log File Groups Configuration:
    Thread #  Online Redo Log Groups  Standby Redo Log Groups
              (ORCLCDB_PRIMARY)       (orclcdb_standby)
    1         3                       2

  Future Log File Groups Configuration:
    Thread #  Online Redo Log Groups  Standby Redo Log Groups
              (orclcdb_standby)       (ORCLCDB_PRIMARY)
    1         3                       0
    Warning: standby redo logs not configured for thread 1 on ORCLCDB_PRIMARY
```

Ket luan:

```text
Doi sang service ORCLCDB_PRIMARY / ORCLCDB_STANDBY van chua het warning.
Can test connect truc tiep tu observer bang dung StaticConnectIdentifier.
Neu sqlplus connect OK ma DGMGRL validate van warning, can xem tiep listener static/service startup behavior.
```

Lenh test tiep theo trong observer container:

```bash
sqlplus -L sys@'(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-primary)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_PRIMARY)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))' as sysdba
```

Va test standby:

```bash
sqlplus -L sys@'(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-standby)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_STANDBY)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))' as sysdba
```

### Ket qua test SQLPlus static connect

Test primary tu observer/container network:

```bash
sqlplus -L sys@'(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-primary)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_PRIMARY)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))' as sysdba
```

Ket qua:

```text
Enter password:

Connected to:
Oracle AI Database 26ai Enterprise Edition Release 23.26.1.0.0 - Production
Version 23.26.1.0.0
```

Test standby tu observer:

```bash
podman exec -it oraee-dg-observer bash

sqlplus -L sys@'(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-standby)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_STANDBY)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))' as sysdba
```

Ket qua:

```text
Enter password:

Connected to:
Oracle AI Database 26ai Enterprise Edition Release 23.26.1.0.0 - Production
Version 23.26.1.0.0
```

Phan tich:

```text
Oracle Net connect string toi primary OK.
Oracle Net connect string toi standby OK.
Viec phai nhap password la binh thuong vi day la remote SYSDBA qua Oracle Net, khong phai OS authentication local.
```

Ket luan:

```text
StaticConnectIdentifier moi connect duoc bang SQLPlus.
Neu DGMGRL validate van warning, van can xu ly Broker/static DGMGRL service rieng neu muon switchover that sach.
```

## 12. Test switchover lan 1: standby len primary

Luu y:

```text
Lenh dung la `show configuration`, khong co lenh `check` trong DGMGRL.
```

Da chay:

```text
DGMGRL> switchover to orclcdb_standby;
```

Output quan trong:

```text
Performing switchover NOW, please wait...
Operation requires a connection to database "orclcdb_standby"
Connecting ...
Connected to "ORCLCDB_STANDBY"
Connected as SYSDBA.

Continuing with the switchover...

New primary database "orclcdb_standby" is opening...

Operation requires start up of instance "ORCLCDB" on database "ORCLCDB_PRIMARY"
Starting instance "ORCLCDB"...
Unable to connect to database using (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-primary)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_PRIMARY)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))
ORA-12545: Connect failed because target host or object does not exist

Please complete the following steps to finish switchover:
	start up and mount instance "ORCLCDB" of database "ORCLCDB_PRIMARY"

Switchover processing complete, broker ready.
```

Phan tich:

```text
Switchover da dua orclcdb_standby len primary.
Broker khong tu start/mount duoc old primary do static connect/startup issue.
Can start container/instance old primary bang tay.
```

Tren host, `podman exec` vao old primary bi loi vi container khong running:

```text
Error: can only create exec sessions on running containers: container state improper
```

Da start container old primary bang tay, vao SQL, chay `startup mount` thi Oracle bao da chay:

```text
ORA-01081: cannot start already-running ORACLE - shut it down first
```

Check role tren old primary:

```sql
select name, database_role, open_mode, switchover_status
from v$database;
```

Ket qua:

```text
NAME       DATABASE_ROLE       OPEN_MODE               SWITCHOVER_STATUS
__________ ___________________ _______________________ ____________________
ORCLCDB    PHYSICAL STANDBY    READ ONLY WITH APPLY    NOT ALLOWED
```

Phan tich:

```text
Old primary da thanh physical standby.
Apply dang chay vi OPEN_MODE = READ ONLY WITH APPLY.
```

Check Broker sau switchover:

```text
DGMGRL> show configuration;
```

Ket qua:

```text
Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  orclcdb_standby - Primary database
    ORCLCDB_PRIMARY - (*) Physical standby database

Fast-Start Failover: Enabled in Potential Data Loss Mode

Configuration Status:
SUCCESS   (status updated 47 seconds ago)
```

Check old primary bay gio la standby:

```text
DGMGRL> show database ORCLCDB_PRIMARY;
```

Ket qua:

```text
Database - ORCLCDB_PRIMARY

  Role:                PHYSICAL STANDBY
  Intended State:      APPLY-ON
  Transport Lag:       0 seconds (computed 1 second ago)
  Apply Lag:           0 seconds (computed 1 second ago)
  Average Apply Rate:  12.00 KByte/s
  Real Time Query:     ON
  Instance(s):
    ORCLCDB

Database Status:
SUCCESS
```

Check new primary:

```text
DGMGRL> show database orclcdb_standby;
```

Ket qua:

```text
Database - orclcdb_standby

  Role:                PRIMARY
  Intended State:      TRANSPORT-ON
  Redo Rate:           1.22 KByte/s  in 15 seconds (computed 0 seconds ago)
  Instance(s):
    ORCLCDB

Database Status:
SUCCESS
```

Ket luan:

```text
Switchover lan 1 thanh cong.
orclcdb_standby hien la PRIMARY.
ORCLCDB_PRIMARY hien la PHYSICAL STANDBY va apply lag = 0.
Broker configuration SUCCESS.
```

Buoc neu muon quay ve trang thai ban dau:

```text
DGMGRL> switchover to ORCLCDB_PRIMARY;
```

## 13. Test switchover lan 2: quay ve ORCLCDB_PRIMARY

Da chay trong DGMGRL:

```text
DGMGRL> switchover to ORCLCDB_PRIMARY;
```

Output quan trong:

```text
Performing switchover NOW, please wait...

Operation requires a connection to database "ORCLCDB_PRIMARY"
Connecting ...
Connected to "ORCLCDB_PRIMARY"
Connected as SYSDBA.

Continuing with the switchover...

New primary database "ORCLCDB_PRIMARY" is opening...

Operation requires start up of instance "ORCLCDB" on database "orclcdb_standby"
Starting instance "ORCLCDB"...
Unable to connect to database using (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-standby)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_STANDBY)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))
ORA-12514: Cannot connect to database. Service ORCLCDB_STANDBY is not registered with the listener at host 10.89.1.3 port 1521.

Please complete the following steps to finish switchover:
	start up and mount instance "ORCLCDB" of database "orclcdb_standby"

Switchover processing complete, broker ready.
```

Phan tich:

```text
Switchover nguoc da dua ORCLCDB_PRIMARY len primary lai.
Broker khong tu start/mount duoc orclcdb_standby do van de static service/listener.
Can start/mount standby bang tay.
```

Vao `oraee-dg-standby`:

```bash
podman exec -it oraee-dg-standby bash
sql / as sysdba
```

Ban dau SQLcl bao idle instance:

```text
Connected to an Idle instance, startup command available.
```

Neu query ngay se loi:

```text
ORA-01034: The Oracle instance is not available for use. Start the instance.
```

Sau khi startup mount, check:

```sql
select name, database_role, open_mode, switchover_status
from v$database;
```

Ket qua:

```text
NAME       DATABASE_ROLE       OPEN_MODE    SWITCHOVER_STATUS
__________ ___________________ ____________ ____________________
ORCLCDB    PHYSICAL STANDBY    MOUNTED      RECOVERY NEEDED
```

Thu start managed recovery:

```sql
alter database recover managed standby database using current logfile disconnect from session;
```

Ket qua:

```text
ORA-01153: An incompatible media recovery is active.
```

Phan tich:

```text
Standby da mount dung role PHYSICAL STANDBY.
ORA-01153 thuong nghia la dang co recovery/media recovery session khac active.
Khong nen start MRP lap lai khi chua xem v$managed_standby.
```

Buoc tiep theo:

```sql
select process, status, sequence#, thread#
from v$managed_standby
order by process;
```

Neu thay `MRP0` dang `APPLYING_LOG` thi recovery da chay, khong can start lai.

Neu can reset recovery session:

```sql
alter database recover managed standby database cancel;
alter database recover managed standby database using current logfile disconnect from session;
```

Sau do check Broker:

```text
DGMGRL> show configuration;
DGMGRL> show database ORCLCDB_PRIMARY;
DGMGRL> show database orclcdb_standby;
```

### Ket qua recovery da on va mo standby read only lai

Check lag tren standby:

```sql
select name, value, time_computed
from v$dataguard_stats
where name in ('transport lag','apply lag');
```

Ket qua:

```text
NAME             VALUE           TIME_COMPUTED
________________ _______________ ______________________
transport lag    +00 00:00:00    05/25/2026 16:58:08
apply lag        +00 00:00:00    05/25/2026 16:58:08
```

MRP da chay, nhung standby dang `MOUNTED`. De mo lai `READ ONLY WITH APPLY`, da chay:

```sql
alter database recover managed standby database cancel;
alter database open read only;
alter database recover managed standby database using current logfile disconnect from session;
```

Ket qua:

```text
Database altered.
Database altered.
Database altered.
```

Verify:

```sql
select name, database_role, open_mode
from v$database;
```

Ket qua:

```text
NAME       DATABASE_ROLE       OPEN_MODE
__________ ___________________ _______________________
ORCLCDB    PHYSICAL STANDBY    READ ONLY WITH APPLY
```

Ket luan:

```text
Sau switchover nguoc, standby da duoc dua ve READ ONLY WITH APPLY.
transport lag = 0
apply lag = 0
```

Ghi chu:

```text
Flow nay van con thu cong.
Nguyen nhan chinh: Broker khong tu start/mount duoc database sau switchover do StaticConnectIdentifier/listener static service chua chuan.
Mai can fix listener static *_DGMGRL service hoac static connect identifier dung service co the startup khi DB down.
```

## 14. Fix listener static *_DGMGRL service

Muc tieu:

```text
Tao static listener service rieng cho Broker:
  ORCLCDB_PRIMARY_DGMGRL
  ORCLCDB_STANDBY_DGMGRL

De Broker co the connect/start/mount database khi instance down hoac dang trong role transition.
```

### Trang thai truoc khi fix

Truoc do `lsnrctl services` chi co:

```text
Primary:
  ORCLCDB
  ORCLCDBXDB
  ORCLCDB_CFG
  ORCLCDB_PRIMARY
  orclpdb1

Standby:
  ORCLCDB
  ORCLCDBXDB
  ORCLCDB_CFG
  ORCLCDB_STANDBY
  orclpdb1
```

Khong co:

```text
ORCLCDB_PRIMARY_DGMGRL
ORCLCDB_STANDBY_DGMGRL
```

Vi vay Broker validate canh bao:

```text
The static connect identifier did not allow for a connection...
```

### Fix primary listener.ora

Trong primary container:

```bash
podman exec -it oraee-dg-primary bash
```

Backup va ghi lai `listener.ora` bang `printf` de tranh loi paste heredoc:

```bash
cp /opt/oracle/oradata/dbconfig/ORCLCDB/listener.ora \
   /opt/oracle/oradata/dbconfig/ORCLCDB/listener.ora.bak.$(date +%Y%m%d_%H%M%S)

printf '%s\n' \
'LISTENER =' \
'  (DESCRIPTION_LIST =' \
'    (DESCRIPTION =' \
'      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))' \
'      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))' \
'    )' \
'  )' \
'' \
'SID_LIST_LISTENER =' \
'  (SID_LIST =' \
'    (SID_DESC =' \
'      (GLOBAL_DBNAME = ORCLCDB)' \
'      (ORACLE_HOME = /opt/oracle/product/26ai/dbhome_1)' \
'      (SID_NAME = ORCLCDB)' \
'    )' \
'    (SID_DESC =' \
'      (GLOBAL_DBNAME = ORCLCDB_PRIMARY_DGMGRL)' \
'      (ORACLE_HOME = /opt/oracle/product/26ai/dbhome_1)' \
'      (SID_NAME = ORCLCDB)' \
'    )' \
'  )' \
'' \
'DEDICATED_THROUGH_BROKER_LISTENER=ON' \
'DIAG_ADR_ENABLED = off' \
> /opt/oracle/oradata/dbconfig/ORCLCDB/listener.ora

lsnrctl reload
lsnrctl services
```

Ket qua primary sau fix:

```text
Service "ORCLCDB_PRIMARY_DGMGRL" has 1 instance(s).
  Instance "ORCLCDB", status UNKNOWN, has 1 handler(s) for this service...
    Handler(s):
      "DEDICATED" established:0 refused:0
         LOCAL SERVER
```

### Fix standby listener.ora

Trong standby container:

```bash
podman exec -it oraee-dg-standby bash
```

Backup va ghi lai `listener.ora`:

```bash
cp /opt/oracle/oradata/dbconfig/ORCLCDB/listener.ora \
   /opt/oracle/oradata/dbconfig/ORCLCDB/listener.ora.bak.$(date +%Y%m%d_%H%M%S)

printf '%s\n' \
'LISTENER =' \
'  (DESCRIPTION_LIST =' \
'    (DESCRIPTION =' \
'      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))' \
'      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))' \
'    )' \
'  )' \
'' \
'SID_LIST_LISTENER =' \
'  (SID_LIST =' \
'    (SID_DESC =' \
'      (GLOBAL_DBNAME = ORCLCDB)' \
'      (ORACLE_HOME = /opt/oracle/product/26ai/dbhome_1)' \
'      (SID_NAME = ORCLCDB)' \
'    )' \
'    (SID_DESC =' \
'      (GLOBAL_DBNAME = ORCLCDB_STANDBY_DGMGRL)' \
'      (ORACLE_HOME = /opt/oracle/product/26ai/dbhome_1)' \
'      (SID_NAME = ORCLCDB)' \
'    )' \
'  )' \
'' \
'DEDICATED_THROUGH_BROKER_LISTENER=ON' \
'DIAG_ADR_ENABLED = off' \
> /opt/oracle/oradata/dbconfig/ORCLCDB/listener.ora

lsnrctl reload
lsnrctl services
```

Ket qua standby sau fix:

```text
Service "ORCLCDB_STANDBY_DGMGRL" has 1 instance(s).
  Instance "ORCLCDB", status UNKNOWN, has 1 handler(s) for this service...
    Handler(s):
      "DEDICATED" established:0 refused:0
         LOCAL SERVER
```

### Khac truoc dong nao?

Truoc fix:

```text
Khong co service *_DGMGRL trong listener.
StaticConnectIdentifier tro toi *_DGMGRL thi listener khong biet service do.
```

Sau fix:

```text
Primary co them:
  Service "ORCLCDB_PRIMARY_DGMGRL"

Standby co them:
  Service "ORCLCDB_STANDBY_DGMGRL"
```

`status UNKNOWN` la binh thuong cho static listener entry. Diem quan trong la listener da biet service name de Broker co the attach vao instance khi database chua dynamic-register service.

Buoc tiep theo:

```text
1. Set StaticConnectIdentifier ve *_DGMGRL service.
2. Validate database lai.
3. Neu warning het, test switchover lai.
```

## 15. Current checkpoint va buoc tiep theo

Trang thai moi nhat sau khi fix listener:

```text
Broker config truoc fix listener: SUCCESS
FSFO: Disabled
Primary: ORCLCDB_PRIMARY
Standby: orclcdb_standby
Transport lag: 0
Apply lag: 0
```

Da them static listener service:

```text
Primary listener:
  Service "ORCLCDB_PRIMARY_DGMGRL"
  Instance "ORCLCDB", status UNKNOWN

Standby listener:
  Service "ORCLCDB_STANDBY_DGMGRL"
  Instance "ORCLCDB", status UNKNOWN
```

Khac biet code trong `listener.ora`:

```text
Truoc chi co:
  GLOBAL_DBNAME = ORCLCDB

Sau primary co them:
  GLOBAL_DBNAME = ORCLCDB_PRIMARY_DGMGRL

Sau standby co them:
  GLOBAL_DBNAME = ORCLCDB_STANDBY_DGMGRL
```

Ly do ten `_DGMGRL`:

```text
Khong tu dat.
DGMGRL `show database verbose` truoc do da hien StaticConnectIdentifier dung:
  SERVICE_NAME=ORCLCDB_PRIMARY_DGMGRL
  SERVICE_NAME=ORCLCDB_STANDBY_DGMGRL

Nen listener phai co GLOBAL_DBNAME khop voi service name do.
```

### Buoc tiep theo 1: set lai StaticConnectIdentifier ve *_DGMGRL

Vao DGMGRL tu observer:

```bash
podman exec -it oraee-dg-observer bash
dgmgrl sys@PRIMARY_DG
```

Trong DGMGRL:

```text
EDIT DATABASE ORCLCDB_PRIMARY SET PROPERTY StaticConnectIdentifier='(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-primary)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_PRIMARY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))';
```

```text
EDIT DATABASE orclcdb_standby SET PROPERTY StaticConnectIdentifier='(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-standby)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_STANDBY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))';
```

Verify property:

```text
SHOW DATABASE VERBOSE ORCLCDB_PRIMARY;
SHOW DATABASE VERBOSE orclcdb_standby;
```

Can thay:

```text
HOST=oraee-dg-primary
SERVICE_NAME=ORCLCDB_PRIMARY_DGMGRL

HOST=oraee-dg-standby
SERVICE_NAME=ORCLCDB_STANDBY_DGMGRL
```

### Ket qua set lai StaticConnectIdentifier ve *_DGMGRL

Luu y loi paste:

```text
Neu paste bi xuong dong trong quoted string, DGMGRL bao:
quoted string not properly terminated
```

Fix bang cach paste moi lenh thanh mot dong duy nhat.

Da chay:

```text
EDIT DATABASE ORCLCDB_PRIMARY SET PROPERTY StaticConnectIdentifier='(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-primary)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_PRIMARY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))';

EDIT DATABASE orclcdb_standby SET PROPERTY StaticConnectIdentifier='(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-standby)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_STANDBY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))';
```

Ket qua:

```text
Property "staticconnectidentifier" updated for member "orclcdb_primary".
Property "staticconnectidentifier" updated for member "orclcdb_standby".
```

Verify primary:

```text
DGMGRL> SHOW DATABASE VERBOSE ORCLCDB_PRIMARY;
```

Ket qua quan trong:

```text
StaticConnectIdentifier = '(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-primary)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_PRIMARY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))'
Database Status:
SUCCESS
```

Verify standby:

```text
DGMGRL> SHOW DATABASE VERBOSE orclcdb_standby;
```

Ket qua quan trong:

```text
StaticConnectIdentifier = '(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-standby)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_STANDBY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))'
Transport Lag:       0 seconds
Apply Lag:           0 seconds
Database Status:
SUCCESS
```

### Buoc tiep theo 2: validate lai

Trong DGMGRL:

```text
VALIDATE DATABASE ORCLCDB_PRIMARY;
VALIDATE DATABASE orclcdb_standby;
SHOW CONFIGURATION;
```

Muc tieu:

```text
Khong con warning:
The static connect identifier did not allow for a connection...
```

### Ket qua validate sau khi fix *_DGMGRL

Validate primary:

```text
DGMGRL> VALIDATE DATABASE ORCLCDB_PRIMARY;

  Database Role:    Primary database

  Ready for Switchover:  Yes

  Managed by Clusterware:
    ORCLCDB_PRIMARY:  NO
    The static connect identifier allows for a connection to database "ORCLCDB_PRIMARY".
```

Validate standby:

```text
DGMGRL> VALIDATE DATABASE orclcdb_standby;

  Database Role:     Physical standby database
  Primary Database:  ORCLCDB_PRIMARY

  Ready for Switchover:  Yes
  Ready for Failover:    Yes (Primary Running)

  Managed by Clusterware:
    ORCLCDB_PRIMARY:  NO
    orclcdb_standby:  NO
    The static connect identifier allows for a connection to database "ORCLCDB_PRIMARY".

  Current Log File Groups Configuration:
    Thread #  Online Redo Log Groups  Standby Redo Log Groups
              (ORCLCDB_PRIMARY)       (orclcdb_standby)
    1         3                       2

  Future Log File Groups Configuration:
    Thread #  Online Redo Log Groups  Standby Redo Log Groups
              (orclcdb_standby)       (ORCLCDB_PRIMARY)
    1         3                       1

  Parameter Settings:
    Parameter                       ORCLCDB_PRIMARY Value    orclcdb_standby Value
    DB_BLOCK_CHECKING               FALSE                    FALSE
    DB_BLOCK_CHECKSUM               TYPICAL                  TYPICAL
    DB_LOST_WRITE_PROTECT           AUTO                     AUTO
```

Show configuration:

```text
DGMGRL> SHOW CONFIGURATION;

Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  ORCLCDB_PRIMARY - Primary database
    orclcdb_standby - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS   (status updated 25 seconds ago)
```

Ket luan:

```text
Static connect warning da het.
Broker validate noi static connect identifier allows for a connection.
Configuration SUCCESS.
FSFO van Disabled, dung cho test switchover sach.
```

Neu warning static connect het nhung van con warning standby redo log, tiep tuc check:

```sql
select group#, bytes/1024/1024 as size_mb, status
from v$standby_log
order by group#;
```

tren ca hai database sau khi role hien tai da on dinh.

### Buoc tiep theo 3: test switchover lai khi validate sach hon

Chi lam khi:

```text
SHOW CONFIGURATION = SUCCESS
VALIDATE khong con static connect warning
FSFO van Disabled
```

Switchover test:

```text
SWITCHOVER TO orclcdb_standby;
SHOW CONFIGURATION;
SHOW DATABASE ORCLCDB_PRIMARY;
SHOW DATABASE orclcdb_standby;
```

Neu Broker tu start/mount/open duoc ca hai ben, khong can can thiep SQL tay nua.

Quay ve ban dau:

```text
SWITCHOVER TO ORCLCDB_PRIMARY;
SHOW CONFIGURATION;
SHOW DATABASE ORCLCDB_PRIMARY;
SHOW DATABASE orclcdb_standby;
```

### Buoc tiep theo 4: chi enable FSFO sau khi switchover sach

Khong enable FSFO trong luc dang sua listener/static connect.

Chi enable lai khi:

```text
Switchover qua/lai sach
Broker SUCCESS
Flashback YES ca hai ben
Lag = 0
Observer connect OK
```

Lenh enable luc do:

```text
ENABLE FAST_START FAILOVER;
SHOW FAST_START FAILOVER;
```

### Ket qua test switchover sau khi fix *_DGMGRL

Sau khi validate static connect het warning, test switchover sang `orclcdb_standby`.

Ket qua van con fail o buoc start/attach `ORCLCDB_PRIMARY`:

```text
Operation requires start up of instance "ORCLCDB" on database "ORCLCDB_PRIMARY"
Starting instance "ORCLCDB"...
Connected to an idle instance.
Unable to connect to database using (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-primary)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_PRIMARY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))
ORA-12545: Connect failed because target host or object does not exist
```

DGMGRL sau do bao:

```text
orclcdb_standby - Primary database
ORCLCDB_PRIMARY - Physical standby database
Configuration Status: ERROR
```

Sau khi start container `oraee-dg-primary` bang tay, Broker tu bat lai va ve SUCCESS:

```text
Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  orclcdb_standby - Primary database
    ORCLCDB_PRIMARY - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS
```

Check member:

```text
ORCLCDB_PRIMARY:
  Role: PHYSICAL STANDBY
  Intended State: APPLY-ON
  Transport Lag: 0 seconds
  Apply Lag: 0 seconds
  Database Status: SUCCESS

orclcdb_standby:
  Role: PRIMARY
  Intended State: TRANSPORT-ON
  Database Status: SUCCESS
```

Phan tich:

```text
Static *_DGMGRL service da giup Broker attach/start Oracle instance tot hon.
Nhung neu Podman container bi exit/stop, Broker khong tu `podman start` container.
```

Check restart policy:

```bash
podman inspect oraee-dg-primary --format '{{.HostConfig.RestartPolicy.Name}}'
podman inspect oraee-dg-standby --format '{{.HostConfig.RestartPolicy.Name}}'
podman inspect oraee-dg-observer --format '{{.HostConfig.RestartPolicy.Name}}'
```

Ket qua luc dau:

```text
oraee-dg-primary: chua check trong output nay
oraee-dg-standby: no
oraee-dg-observer: unless-stopped
```

Ket luan:

```text
Primary/standby container chua co restart policy.
Observer co restart policy.
Neu DB shutdown lam container exit, Podman khong tu start primary/standby lai.
```

### Cap nhat restart policy cho primary/standby

Da chay sau buoi test switchover:

```bash
podman update --restart=unless-stopped oraee-dg-primary
podman update --restart=unless-stopped oraee-dg-standby

podman inspect oraee-dg-primary --format '{{.HostConfig.RestartPolicy.Name}}'
podman inspect oraee-dg-standby --format '{{.HostConfig.RestartPolicy.Name}}'
```

Ket qua:

```text
oraee-dg-primary: unless-stopped
oraee-dg-standby: unless-stopped
```

Y nghia:

```text
Neu host reboot hoac Podman service restart, primary/standby co co hoi tu len lai.
Nhung Data Guard Broker van khong phai cong cu quan ly container.
Broker chi start/mount/open Oracle instance ben trong container khi listener/container con reachable.
```

### Note LGWR/VKTM priority warning neu recreate container

Warning da thay trong `attention_ORCLCDB.log`:

```text
The priority of process LGWR cannot be elevated.
The priority of process VKTM cannot be elevated.
ErrMsg(Operation not permitted)
```

Y nghia:

```text
Oracle muon nang priority cho tien trinh nen quan trong nhu LGWR va VKTM.
Rootless Podman/container co the khong co du Linux scheduling capability.
Day la warning ve OS/container capability, khong tu dong co nghia Data Guard hong.
```

Khi nao tam bo qua:

```text
Data Guard role dung.
Transport/apply lag = 0.
MRP0 dang APPLYING_LOG.
Broker configuration SUCCESS.
```

Neu sau nay tao container moi de test sach hon, them vao lenh `podman run`:

```bash
--cap-add=SYS_NICE \
--cap-add=SYS_RESOURCE \
--ulimit rtprio=99 \
--restart=unless-stopped \
```

Can nho:

```text
May option nay chi ap dung luc create container.
`podman update` sua duoc restart policy, nhung khong bien container cu thanh container co capability moi.
Rootless Podman van co the khong cho day du realtime scheduling tuy host config.
Khong recreate lab chi de xoa warning neu Data Guard dang SUCCESS.
```

### Da kiem tra: co update LGWR/VKTM capability nong duoc khong?

Da check docs/current CLI:

```bash
podman update --help
podman run --help | rg -n "cap-add|ulimit|sysctl|security-opt|restart"
```

Ket qua rut ra:

```text
podman run co:
  --cap-add
  --ulimit
  --security-opt
  --sysctl
  --restart

podman update khong co:
  --cap-add
  --ulimit
  --security-opt
  --sysctl
```

`podman update` co mot so resource option lien quan CPU realtime:

```text
--cpu-rt-period
--cpu-rt-runtime
```

Nhung day khong phai la capability grant.
No khong thay the duoc `--cap-add=SYS_NICE` / `--cap-add=SYS_RESOURCE`.

Ket luan hien tai:

```text
Khong co cach chuan de them --cap-add/--ulimit vao container dang ton tai bang podman update.
Muon doi capability/ulimit sach thi phai recreate container voi cung volume/network.
Hien tai chi nen giu lab, vi restart policy da update duoc va Data Guard dang hoat dong.
```

### Switchover nguoc ve ORCLCDB_PRIMARY sau khi fix *_DGMGRL

Da chay:

```text
DGMGRL> switchover to ORCLCDB_PRIMARY;
```

Ket qua:

```text
Operation requires a connection to database "ORCLCDB_PRIMARY"
Connecting ...
Connected to "ORCLCDB_PRIMARY"
Connected as SYSDBA.

Continuing with the switchover...

New primary database "ORCLCDB_PRIMARY" is opening...

Operation requires start up of instance "ORCLCDB" on database "orclcdb_standby"
Starting instance "ORCLCDB"...
Connected to an idle instance.
ORACLE instance started.
Connected to "ORCLCDB_STANDBY"
Database mounted.

Switchover succeeded, new primary is "orclcdb_primary"
Switchover processing complete, broker ready.
```

Phan tich:

```text
Chieu switchover nguoc thanh cong sach hon:
Broker connect idle instance, start Oracle instance, mount database, va complete switchover.
Day la dau hieu listener static *_DGMGRL da co tac dung.
```

Buoc tiep theo de tu dong hon:

```text
Recreate primary/standby containers giu nguyen volumes nhung them:
  --restart=unless-stopped

Hoac dung systemd/quadlet de quan ly container.
```

Khong xoa volumes:

```text
oraee-dg-primary-data
oraee-dg-standby-data
```

### Switchover lai sang orclcdb_standby sau restart policy + *_DGMGRL

Da chay tiep sau khi:

```text
Primary/standby restart policy da la unless-stopped.
StaticConnectIdentifier da tro ve service *_DGMGRL.
Listener da co static service ORCLCDB_PRIMARY_DGMGRL / ORCLCDB_STANDBY_DGMGRL.
FSFO van Disabled.
```

Lenh:

```text
DGMGRL> SWITCHOVER TO orclcdb_standby;
```

Ket qua:

```text
2026-05-26T02:12:23.388+00:00
Performing switchover NOW, please wait...

2026-05-26T02:12:23.411+00:00
Operation requires a connection to database "orclcdb_standby"
Connecting ...
Connected to "ORCLCDB_STANDBY"
Connected as SYSDBA.

2026-05-26T02:12:23.494+00:00
Continuing with the switchover...

2026-05-26T02:12:24.694+00:00
New primary database "orclcdb_standby" is opening...

2026-05-26T02:12:24.694+00:00
Operation requires start up of instance "ORCLCDB" on database "ORCLCDB_PRIMARY"
Starting instance "ORCLCDB"...
Connected to an idle instance.
ORACLE instance started.
Connected to "ORCLCDB_PRIMARY"
Database mounted.

2026-05-26T02:12:32.644+00:00
Switchover succeeded, new primary is "orclcdb_standby"

2026-05-26T02:12:32.654+00:00
Switchover processing complete, broker ready.
```

Phan tich:

```text
Lan nay switchover sang orclcdb_standby sach.
Broker tu connect toi standby cu, open thanh primary moi.
Broker tu start idle instance cua ORCLCDB_PRIMARY va mount thanh physical standby.
Khong can podman start / sqlplus startup mount bang tay.
```

Trang thai sau lenh nay:

```text
orclcdb_standby: PRIMARY
ORCLCDB_PRIMARY: PHYSICAL STANDBY
FSFO: van Disabled
```

Buoc tiep theo:

```text
SHOW CONFIGURATION;
SHOW DATABASE ORCLCDB_PRIMARY;
SHOW DATABASE orclcdb_standby;

Neu SUCCESS het thi SWITCHOVER TO ORCLCDB_PRIMARY de quay ve trang thai ban dau.
```

### Enable FSFO sau khi switchover sang orclcdb_standby

Trang thai truoc khi enable:

```text
Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  orclcdb_standby - Primary database
    ORCLCDB_PRIMARY - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS
```

Member status:

```text
ORCLCDB_PRIMARY:
  Role: PHYSICAL STANDBY
  Intended State: APPLY-ON
  Transport Lag: 0 seconds
  Apply Lag: 0 seconds
  Real Time Query: OFF
  Database Status: SUCCESS

orclcdb_standby:
  Role: PRIMARY
  Intended State: TRANSPORT-ON
  Database Status: SUCCESS
```

Check FSFO truoc khi bat:

```text
Fast-Start Failover:  Disabled
Potential Targets:  "ORCLCDB_PRIMARY"
  ORCLCDB_PRIMARY valid
Observer: c31c2f05e111
Auto-reinstate: TRUE
```

Da enable:

```text
DGMGRL> ENABLE FAST_START FAILOVER;
Enabled in Potential Data Loss Mode.
```

Ket qua sau enable:

```text
Fast-Start Failover: Enabled in Potential Data Loss Mode

Protection Mode:    MaxPerformance
Lag Limit:          30 seconds
Lag Type:           APPLY
Threshold:          30 seconds
Active Target:      ORCLCDB_PRIMARY
Potential Targets:  "ORCLCDB_PRIMARY"
  ORCLCDB_PRIMARY valid
Observer:           c31c2f05e111
Shutdown Primary:   TRUE
Auto-reinstate:     TRUE
```

Show configuration sau enable:

```text
Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  orclcdb_standby - Primary database
    ORCLCDB_PRIMARY - (*) Physical standby database

Fast-Start Failover: Enabled in Potential Data Loss Mode

Configuration Status:
SUCCESS
```

Phan tich:

```text
FSFO da bat thanh cong.
Current primary: orclcdb_standby / container oraee-dg-standby.
FSFO target: ORCLCDB_PRIMARY / container oraee-dg-primary.
Dau (*) nam tren ORCLCDB_PRIMARY nghia la day la target standby duoc FSFO chon.
Vi dang MaxPerformance nen mode la Potential Data Loss Mode.
```

### Buoc test crash current primary

Chi chay khi output FSFO van SUCCESS nhu tren.

Tu host, kill current primary container:

```bash
podman kill oraee-dg-standby
```

Ly do:

```text
Hien tai orclcdb_standby dang la PRIMARY.
Container tuong ung la oraee-dg-standby.
Khong kill oraee-dg-primary luc nay, vi no dang la physical standby/FSFO target.
```

Sau khi kill, doi 30-60 giay roi trong DGMGRL check:

```text
SHOW CONFIGURATION;
SHOW FAST_START FAILOVER;
SHOW DATABASE ORCLCDB_PRIMARY;
SHOW DATABASE orclcdb_standby;
```

Ky vong:

```text
ORCLCDB_PRIMARY duoc promote len PRIMARY.
orclcdb_standby tro thanh old failed primary, co the bi disabled / needs reinstatement / cannot reach.
Configuration co the bao WARNING/ERROR cho den khi old primary duoc start va reinstate.
```

### Output ngay sau khi kill current primary

Sau khi FSFO da enabled va current primary la `orclcdb_standby`, session DGMGRL dang noi vao primary bi rot:

```text
DGMGRL> SHOW FAST_START FAILOVER;
ORA-03113: end-of-file on communication channel
Process ID: 1982
Session ID: 10 Serial number: 38112

Configuration details cannot be determined by DGMGRL

DGMGRL> SHOW CONFIGURATION;
ORA-03114: not connected to ORACLE

Configuration details cannot be determined by DGMGRL
```

Phan tich:

```text
Day la expected behavior khi DGMGRL session dang connect vao database/container vua bi kill.
Khong ket luan failover hong tu ORA-03113/ORA-03114 nay.
Can thoat DGMGRL cu va connect lai qua target con song.
```

Reconnect dung huong sau kill:

```text
EXIT
```

Tu observer/container con song:

```bash
dgmgrl sys@PRIMARY_DG
```

Neu `PRIMARY_DG` dang tro toi old primary da chet, connect qua standby target truc tiep:

```bash
dgmgrl sys@'(DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=oraee-dg-primary)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ORCLCDB_PRIMARY_DGMGRL)(INSTANCE_NAME=ORCLCDB)(SERVER=DEDICATED)))'
```

Sau khi reconnect, check:

```text
SHOW CONFIGURATION;
SHOW FAST_START FAILOVER;
SHOW DATABASE ORCLCDB_PRIMARY;
SHOW DATABASE orclcdb_standby;
```

### Ket qua reconnect sau crash: FSFO chua promote

Sau khi reconnect vao `ORCLCDB_PRIMARY`, chay:

```text
SHOW CONFIGURATION;
SHOW FAST_START FAILOVER;
SHOW DATABASE ORCLCDB_PRIMARY;
SHOW DATABASE orclcdb_standby;
```

Output:

```text
Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  orclcdb_standby - Primary database
    Error: ORA-12545: Connect failed because target host or object does not exist

    ORCLCDB_PRIMARY - (*) Physical standby database

Fast-Start Failover: Enabled in Potential Data Loss Mode

Configuration Status:
ERROR
```

FSFO detail:

```text
Active Target:      ORCLCDB_PRIMARY
Potential Targets:  "ORCLCDB_PRIMARY"
  ORCLCDB_PRIMARY valid
Observer:
  DGM-17623: Failed to connect to primary database "orclcdb_standby" with connect string "standby_dg" to fetch observer information.
```

Target database status:

```text
Database - ORCLCDB_PRIMARY

Role:                PHYSICAL STANDBY
Intended State:      APPLY-ON

Database Error(s):
  ORA-16820: fast-start failover observer is no longer observing this database

Database Warning(s):
  ORA-16857: member disconnected from redo source for longer than specified threshold

Database Status:
ERROR
```

Old primary status:

```text
Database - orclcdb_standby

Role:                PRIMARY
Intended State:      TRANSPORT-ON

Database Status:
DGM-17016: failed to retrieve status for database "orclcdb_standby"
ORA-12545: Connect failed because target host or object does not exist
ORA-16625: cannot reach member "orclcdb_standby"
```

Phan tich:

```text
FSFO da enabled nhung failover chua xay ra.
Broker van xem orclcdb_standby la PRIMARY.
ORCLCDB_PRIMARY van la PHYSICAL STANDBY, chua duoc promote.
Observer dang khong quan sat duoc database target/primary dung cach, co ORA-16820.
Chua duoc REINSTATE luc nay, vi chua co failover thanh cong.
```

Buoc debug tiep theo:

```bash
podman ps -a --filter name=oraee-dg
podman logs --tail 80 oraee-dg-observer
podman exec -it oraee-dg-observer bash
```

Trong observer container:

```bash
ls -lt /home/oracle/*observer*.log /opt/oracle/observer/logs/* 2>/dev/null
tail -n 120 /home/oracle/observer_*.log 2>/dev/null
tail -n 120 /opt/oracle/observer/logs/* 2>/dev/null
```

Trong DGMGRL:

```text
SHOW OBSERVER;
SHOW FAST_START FAILOVER;
SHOW CONFIGURATION;
```

### Tim dung log sau FSFO test fail

Kiem tra trong observer container:

```bash
date
echo "ORACLE_HOME=$ORACLE_HOME"
echo "TNS_ADMIN=$TNS_ADMIN"
pwd
ps -ef | grep -i '[d]gmgrl\|[o]bserver'
find /home/oracle /opt/oracle -type f \( -iname '*observer*.log' -o -iname '*.log' \) \
  -printf '%TY-%Tm-%Td %TH:%TM:%TS %p\n' 2>/dev/null | sort | tail -30
```

Ket qua hien tai:

```text
Tue May 26 02:25:44 UTC 2026
ORACLE_HOME=/opt/oracle/product/26ai/dbhome_1
TNS_ADMIN=/opt/oracle/network/admin
/home/oracle

oracle 225 ... dgmgrl

2026-05-25 17:07:44.0205848310 /home/oracle/observer_c31c2f05e111.log
2026-05-26 02:24:31.3952166790 /opt/oracle/diag/clients/user_oracle/host_2174771150_116/trace/sqlnet.log
```

Phan tich file log:

```text
/home/oracle/observer_c31c2f05e111.log
  La observer log cu.
  Mtime dung o 2026-05-25 17:07:44 UTC.
  Khong co log moi cua lan test kill ngay 2026-05-26.

/opt/oracle/diag/clients/user_oracle/host_2174771150_116/trace/sqlnet.log
  La SQL*Net client trace/log moi.
  Mtime 2026-05-26 02:24:31 UTC.
  Day la log cua DGMGRL/client connect fail moi nhat.
```

Can nho timezone:

```text
Oracle/container log dang ghi UTC.
Gio Viet Nam = UTC + 7.

2026-05-26T02:24:31+00:00
= 2026-05-26 09:24:31 +07
```

Output moi trong `sqlnet.log`:

```text
2026-05-26T02:24:31.395579+00:00
Fatal NI connect error 12545
TNS-12545: Connect failed because target host or object does not exist

Connecting to:
(DESCRIPTION=
  (ADDRESS=(PROTOCOL=TCP)(HOST=oraee-dg-standby)(PORT=1521))
  (CONNECT_DATA=
    (SERVER=DEDICATED)
    (SID=ORCLCDB)
    (CID=(PROGRAM=dgmgrl)(HOST=c31c2f05e111)(USER=oracle))
  )
)
```

Doc output nay:

```text
PROGRAM=dgmgrl
  Loi sinh ra tu DGMGRL/client trong observer container.

HOST=c31c2f05e111
  Client dang chay trong observer container.

HOST=oraee-dg-standby
  Dich can connect la current primary cu bi kill.

ORA-12545 / TNS-12545
  Khong resolve/reach duoc target host.
  Hop ly vi oraee-dg-standby luc do dang Exited (137).
```

Trang thai container luc debug:

```text
oraee-dg-primary   Up ... unhealthy
oraee-dg-standby   Exited (137) ... unhealthy
oraee-dg-observer  Up ... unhealthy
```

Ket luan:

```text
Observer log rieng khong co log moi vi observer process khong chay/khong monitor that luc test.
Log moi nhat nam o SQL*Net client log.
FSFO khong promote vi observer khong observing dung luc kill.
Can start lai oraee-dg-standby, disable FSFO, sau do start observer lai dung cach roi test lai.
```

### Da start lai old primary va disable FSFO

Sau khi start lai `oraee-dg-standby`, connect duoc vao `ORCLCDB_STANDBY`:

```text
Connected to "ORCLCDB_STANDBY"
Connected as SYSDBA.
```

Truoc khi disable FSFO:

```text
Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  orclcdb_standby - Primary database
    Error: ORA-16820: fast-start failover observer is no longer observing this database

    ORCLCDB_PRIMARY - (*) Physical standby database
      Error: ORA-16820: fast-start failover observer is no longer observing this database

Fast-Start Failover: Enabled in Potential Data Loss Mode

Configuration Status:
ERROR
```

Tat FSFO:

```text
DGMGRL> DISABLE FAST_START FAILOVER;
Disabled.
```

Sau khi disable:

```text
Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  orclcdb_standby - Primary database
    Error: ORA-16820: fast-start failover observer is no longer observing this database

    ORCLCDB_PRIMARY - Physical standby database
      Error: ORA-16820: fast-start failover observer is no longer observing this database

Fast-Start Failover:  Disabled

Configuration Status:
ERROR
```

Nhung tung database da ve SUCCESS:

```text
Database - ORCLCDB_PRIMARY

Role:                PHYSICAL STANDBY
Intended State:      APPLY-ON
Transport Lag:       0 seconds
Apply Lag:           0 seconds
Database Status:
SUCCESS
```

```text
Database - orclcdb_standby

Role:                PRIMARY
Intended State:      TRANSPORT-ON
Database Status:
SUCCESS
```

Phan tich:

```text
Data Guard role/apply da sach lai.
FSFO da disable.
Configuration van ERROR vi Broker con bao ORA-16820 observer stale/not observing tren summary.
Can clear/start observer lai dung cach va refresh Broker status.
Khong can reinstate, vi failover chua tung thanh cong; role hien tai van orclcdb_standby PRIMARY va ORCLCDB_PRIMARY STANDBY.
```

Buoc tiep theo:

```text
SHOW FAST_START FAILOVER;
SHOW OBSERVER;
```

Neu co observer stale, stop/remove observer theo DGMGRL help neu duoc, roi start observer moi va verify log timestamp moi.

### Clear stale observer thanh cong

Trang thai truoc khi clear:

```text
SHOW FAST_START FAILOVER;

Fast-Start Failover:  Disabled
Potential Targets:  "ORCLCDB_PRIMARY"
  ORCLCDB_PRIMARY valid
Observer:           c31c2f05e111
```

```text
SHOW OBSERVER;

Configuration - lab_dg

  Fast-Start Failover:     DISABLED

Observer "c31c2f05e111"

  Host Name:                    c31c2f05e111
  Last Ping to Primary:         (unknown)
  Log File:
  State File:
```

Lenh clear:

```text
STOP OBSERVER c31c2f05e111;
```

Ket qua:

```text
Observer stopped.
```

Check lai:

```text
SHOW OBSERVER;

Configuration - lab_dg

  Fast-Start Failover:     DISABLED

No observers.
```

```text
SHOW FAST_START FAILOVER;

Fast-Start Failover:  Disabled
Active Target:      (none)
Potential Targets:  "ORCLCDB_PRIMARY"
  ORCLCDB_PRIMARY valid
Observer:           (none)
```

Final clean state:

```text
SHOW CONFIGURATION;

Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  orclcdb_standby - Primary database
    ORCLCDB_PRIMARY - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS
```

Ket luan:

```text
Da recover sach sau lan FSFO test fail.
Khong can reinstate vi failover chua xay ra.
Stale observer da duoc remove.
Hien tai co the start observer moi tu dau, nhung phai verify process/log moi truoc khi ENABLE FAST_START FAILOVER lan nua.
```

### Start observer moi voi state/log file ro rang

Thu tao folder trong `/opt/oracle/observer` bi loi permission:

```bash
mkdir -p /opt/oracle/observer/logs /opt/oracle/observer/state
```

Output:

```text
mkdir: cannot create directory '/opt/oracle/observer/state': Permission denied
```

Dung `/home/oracle` thay the:

```bash
mkdir -p /home/oracle/observer/logs /home/oracle/observer/state
ls -ld /home/oracle/observer /home/oracle/observer/logs /home/oracle/observer/state
```

Output:

```text
drwxr-xr-x 4 oracle oinstall 4096 May 26 02:32 /home/oracle/observer
drwxr-xr-x 2 oracle oinstall 4096 May 26 02:32 /home/oracle/observer/logs
drwxr-xr-x 2 oracle oinstall 4096 May 26 02:32 /home/oracle/observer/state
```

Connect DGMGRL vao current primary:

```bash
dgmgrl sys@STANDBY_DG
```

Output:

```text
Connected to "ORCLCDB_STANDBY"
Connected as SYSDBA.
```

Start observer moi:

```text
START OBSERVER FILE IS '/home/oracle/observer/state/fsfo_orclcdb.dat' LOGFILE IS '/home/oracle/observer/logs/fsfo_observer.log';
```

Ket qua:

```text
Observer file "/home/oracle/observer/state/fsfo_orclcdb.dat" is created.
Succeeded in opening the observer file "/home/oracle/observer/state/fsfo_orclcdb.dat".
[W000 2026-05-26T02:33:22.381+00:00] FSFO target standby is
Observer 'c31c2f05e111' started
The observer log file is '/home/oracle/observer/logs/fsfo_observer.log'.
```

Phan tich:

```text
Observer moi da start foreground.
State file va log file lan nay ro rang trong /home/oracle/observer.
Timestamp 2026-05-26T02:33:22 UTC = 2026-05-26 09:33:22 +07.
Chua enable FSFO lai cho den khi check process/log moi that su dang chay.
```

Check tu terminal khac:

```bash
podman exec oraee-dg-observer bash -lc 'date; ps -ef | grep -i "[d]gmgrl\|[o]bserver"; ls -l --full-time /home/oracle/observer/logs /home/oracle/observer/state; tail -n 80 /home/oracle/observer/logs/fsfo_observer.log 2>/dev/null'
```

Observer log moi:

```text
Observer 'c31c2f05e111' started
[W000 2026-05-26T02:33:22.462+00:00] Observer trace level is set to USER
[W000 2026-05-26T02:33:22.468+00:00] Fast-Start Failover is disabled.
[W000 2026-05-26T02:33:22.468+00:00] Fast-Start Failover is not enabled or can't be checked. Retry after 15 seconds.
[W000 2026-05-26T02:33:37.475+00:00] Fast-Start Failover is not enabled or can't be checked. Retry after 15 seconds.
[W000 2026-05-26T02:33:52.482+00:00] Fast-Start Failover is not enabled or can't be checked. Retry after 15 seconds.
[W000 2026-05-26T02:34:07.488+00:00] Fast-Start Failover is not enabled or can't be checked. Retry after 15 seconds.
[W000 2026-05-26T02:34:22.496+00:00] Fast-Start Failover is not enabled or can't be checked. Retry after 15 seconds.
[W000 2026-05-26T02:34:37.505+00:00] Fast-Start Failover is not enabled or can't be checked. Retry after 15 seconds.
```

Ket luan:

```text
Observer moi dang chay that va ghi log moi deu.
Thong bao "Fast-Start Failover is disabled" la binh thuong vi luc nay chua enable lai FSFO.
```

Check DGMGRL tu session khac:

```text
SHOW OBSERVER;
SHOW FAST_START FAILOVER;
SHOW CONFIGURATION;
```

Output:

```text
SHOW OBSERVER;

Configuration - lab_dg

  Fast-Start Failover:     DISABLED

Observer "c31c2f05e111"

  Host Name:                    c31c2f05e111
  Last Ping to Primary:         5 seconds ago
  Log File:
  State File:
```

```text
SHOW FAST_START FAILOVER;

Fast-Start Failover:  Disabled
Active Target:      (none)
Potential Targets:  "ORCLCDB_PRIMARY"
  ORCLCDB_PRIMARY valid
Observer:           c31c2f05e111
```

```text
SHOW CONFIGURATION;

Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  orclcdb_standby - Primary database
    ORCLCDB_PRIMARY - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS
```

Phan tich:

```text
Day la checkpoint sach truoc khi enable FSFO lan 2.
Observer da ping primary gan nhat 5 seconds ago.
Broker SUCCESS.
FSFO van Disabled.
Co the enable lai FSFO, sau do verify observer log co vao Monitoring/PING state.
```

### Enable FSFO lan 2 thanh cong voi observer moi

Lenh:

```text
ENABLE FAST_START FAILOVER;
SHOW FAST_START FAILOVER;
SHOW CONFIGURATION;
```

Output:

```text
DGMGRL> ENABLE FAST_START FAILOVER;
Enabled in Potential Data Loss Mode.
```

```text
Fast-Start Failover: Enabled in Potential Data Loss Mode

Protection Mode:    MaxPerformance
Lag Limit:          30 seconds
Lag Type:           APPLY
Threshold:          30 seconds
Active Target:      ORCLCDB_PRIMARY
Potential Targets:  "ORCLCDB_PRIMARY"
  ORCLCDB_PRIMARY valid
Observer:           c31c2f05e111
Shutdown Primary:   TRUE
Auto-reinstate:     TRUE
```

```text
Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  orclcdb_standby - Primary database
    ORCLCDB_PRIMARY - (*) Physical standby database

Fast-Start Failover: Enabled in Potential Data Loss Mode

Configuration Status:
SUCCESS
```

Observer log sau khi enable:

```text
[W000 2026-05-26T02:37:37.319+00:00] Standby database has changed to ORCLCDB_PRIMARY.
[W000 2026-05-26T02:37:37.368+00:00] Entering PING state
[W000 2026-05-26T02:37:37.368+00:00] Observer Summary (Monitoring):
[W000 2026-05-26T02:37:37.368+00:00] Fast-Start Failover information:
	Primary database, Name: orclcdb_standby, Connect String: standby_dg
	Standby database, Name: ORCLCDB_PRIMARY, Connect String: primary_dg
	Auto Reinst: TRUE
[W000 2026-05-26T02:37:37.368+00:00] Observer State:
	Name: c31c2f05e111, Host: c31c2f05e111, OBID: 1537120981 (0x5b9e9ad5)
	svrflgs: 0x0, version: 0, ctlflgs: 0x60
	target: 1, fsfo_miv: 8
[W000 2026-05-26T02:37:37.368+00:00] Try to connect to the primary.
[W000 2026-05-26T02:37:37.368+00:00] Try to connect to the primary standby_dg.
[W000 2026-05-26T02:37:37.438+00:00] The standby ORCLCDB_PRIMARY is ready to be a FSFO target
[W000 2026-05-26T02:37:38.438+00:00] Connection to the primary restored!
[W000 2026-05-26T02:37:40.430+00:00] Disconnecting from database standby_dg.
```

Phan tich:

```text
Observer moi da vao PING state.
Observer Summary dang Monitoring.
Primary hien tai: orclcdb_standby / standby_dg / container oraee-dg-standby.
FSFO target: ORCLCDB_PRIMARY / primary_dg / container oraee-dg-primary.
Dong "The standby ORCLCDB_PRIMARY is ready to be a FSFO target" la dieu kien quan trong truoc khi test kill.
```

Buoc test crash lan 2:

```bash
podman kill oraee-dg-standby
```

Sau khi kill, doi it nhat 30-60 giay va tail observer log:

```bash
podman exec oraee-dg-observer bash -lc 'tail -n 160 /home/oracle/observer/logs/fsfo_observer.log'
```

Ky vong observer log:

```text
Primary database cannot be reached.
Fast-Start Failover threshold has not exceeded...
Fast-Start Failover threshold has exceeded...
Initiating Fast-Start Failover...
New primary database is ORCLCDB_PRIMARY...
```

### Observer log ngay sau kill lan 2

Sau khi kill current primary `oraee-dg-standby`, observer log bat dau retry:

```text
Unable to connect to database using standby_dg
[W000 2026-05-26T02:38:51.504+00:00] Primary database cannot be reached.
[W000 2026-05-26T02:38:51.504+00:00] Fast-Start Failover threshold has not exceeded. Retry for the next 30 seconds
[W000 2026-05-26T02:38:52.505+00:00] Try to connect to the primary.
[P006 2026-05-26T02:38:52.515+00:00] Failed to attach to standby_dg.
ORA-12545: Connect failed because target host or object does not exist

Unable to connect to database using standby_dg
[W000 2026-05-26T02:38:52.515+00:00] Primary database cannot be reached.
[W000 2026-05-26T02:38:52.515+00:00] Fast-Start Failover threshold has not exceeded. Retry for the next 30 seconds
[W000 2026-05-26T02:38:53.515+00:00] Try to connect to the primary.
[P006 2026-05-26T02:38:53.530+00:00] Failed to attach to standby_dg.
ORA-12545: Connect failed because target host or object does not exist

Unable to connect to database using standby_dg
[W000 2026-05-26T02:38:53.530+00:00] Primary database cannot be reached.
[W000 2026-05-26T02:38:54.530+00:00] Try to connect to the primary.
[P006 2026-05-26T02:38:54.541+00:00] Failed to attach to standby_dg.
ORA-12545: Connect failed because target host or object does not exist
```

Phan tich:

```text
Day la log dung sau khi kill current primary.
Observer dang nhan ra primary standby_dg khong connect duoc.
Threshold FSFO la 30 seconds, nen trong 30 giay dau no chua failover ngay.
Can tiep tuc tail log sau moc 30-60 giay de xem co "threshold exceeded" va "Initiating Fast-Start Failover" khong.
```

Lenh tail tiep:

```bash
podman exec oraee-dg-observer bash -lc 'tail -n 220 /home/oracle/observer/logs/fsfo_observer.log'
```

### FSFO failover lan 2 thanh cong

Observer log sau khi qua threshold:

```text
2026-05-26T02:39:22.384+00:00
Initiating Fast-Start Failover to database "ORCLCDB_PRIMARY"...
[S007 2026-05-26T02:39:22.384+00:00] Initiating Fast-start Failover.
2026-05-26T02:39:22.384+00:00
Performing failover NOW, please wait...

2026-05-26T02:39:25.480+00:00
Failover succeeded, new primary is "ORCLCDB_PRIMARY".

2026-05-26T02:39:25.480+00:00
Failover processing complete, broker ready.
2026-05-26T02:39:25.480+00:00
[S007 2026-05-26T02:39:25.480+00:00] Fast-Start Failover finished...
[W000 2026-05-26T02:39:25.480+00:00] Failover succeeded. Restart pinging.
[W000 2026-05-26T02:39:25.493+00:00] Primary database has changed to ORCLCDB_PRIMARY.
[W000 2026-05-26T02:39:25.495+00:00] Entering PING state
[W000 2026-05-26T02:39:25.495+00:00] Observer Summary (Monitoring):
[W000 2026-05-26T02:39:25.495+00:00] Fast-Start Failover information:
	Primary database, Name: ORCLCDB_PRIMARY, Connect String: primary_dg
	Standby database, Name: orclcdb_standby, Connect String: standby_dg
	Auto Reinst: TRUE
[W000 2026-05-26T02:39:25.495+00:00] Observer State:
	Name: c31c2f05e111, Host: c31c2f05e111, OBID: 1537120981 (0x5b9e9ad5)
	svrflgs: 0x400, version: 19, ctlflgs: 0x60
	target: 2, fsfo_miv: 9
[W000 2026-05-26T02:39:25.495+00:00] Try to connect to the primary.
[W000 2026-05-26T02:39:25.495+00:00] Try to connect to the primary primary_dg.
[W000 2026-05-26T02:39:25.633+00:00] Connection to the primary restored!
[W000 2026-05-26T02:39:25.642+00:00] The standby orclcdb_standby needs to be reinstated
[W000 2026-05-26T02:39:25.642+00:00] Entering REINSTATE state
[W000 2026-05-26T02:39:25.642+00:00] Try to connect to the new standby orclcdb_standby.
[S011 2026-05-26T02:39:25.654+00:00] Failed to attach to standby_dg.
ORA-12545: Connect failed because target host or object does not exist
```

Phan tich:

```text
FSFO da thanh cong.
ORCLCDB_PRIMARY da duoc promote thanh new primary.
Observer da quay lai PING state voi primary_dg.
Old primary orclcdb_standby can reinstate.
Reinstate chua chay duoc vi container oraee-dg-standby dang bi kill/exited, nen standby_dg khong connect duoc.
```

Trang thai logic sau failover:

```text
ORCLCDB_PRIMARY: PRIMARY
orclcdb_standby: old failed primary, needs reinstatement
```

Buoc tiep theo:

```bash
podman start oraee-dg-standby
```

Sau do doi 30-60 giay va check observer log / DGMGRL.
Neu Auto-reinstate khong tu chay, dung:

```text
REINSTATE DATABASE orclcdb_standby;
SHOW CONFIGURATION;
SHOW DATABASE orclcdb_standby;
```

### Auto-reinstate thanh cong sau khi start lai old primary

Observer/Broker log:

```text
2026-05-26T02:41:12.652+00:00
Reinstate processing complete, broker ready.
2026-05-26T02:41:12.652+00:00
[W000 2026-05-26T02:41:13.632+00:00] Entering REINSTATE state
[W000 2026-05-26T02:41:13.632+00:00] Successfully reinstated database orclcdb_standby.
```

Connect DGMGRL:

```text
Connected to "ORCLCDB_STANDBY"
Connected as SYSDBA.
```

Show configuration:

```text
Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  ORCLCDB_PRIMARY - Primary database
    orclcdb_standby - (*) Physical standby database
      Warning: ORA-16809: Multiple warnings detected for the member.

Fast-Start Failover: Enabled in Potential Data Loss Mode

Configuration Status:
WARNING
```

Primary status:

```text
Database - ORCLCDB_PRIMARY

Role:                PRIMARY
Intended State:      TRANSPORT-ON
Redo Rate:           104 Byte/s
Database Status:
SUCCESS
```

Reinstated standby status:

```text
Database - orclcdb_standby

Role:                PHYSICAL STANDBY
Intended State:      APPLY-ON
Transport Lag:       0 seconds
Apply Lag:           0 seconds
Average Apply Rate:  163.00 KByte/s
Real Time Query:     ON
Database Status:
SUCCESS
```

Phan tich:

```text
FSFO test lan 2 thanh cong day du:
1. Kill current primary orclcdb_standby.
2. Observer promote ORCLCDB_PRIMARY len PRIMARY.
3. Start lai old primary container.
4. Auto-reinstate dua orclcdb_standby ve PHYSICAL STANDBY.

Configuration con WARNING do ORA-16809 tren member orclcdb_standby.
Tung database dang SUCCESS va lag = 0.
Can check verbose/warnings sau, nhung Data Guard role/apply da dung.
```

Lenh check warning tiep:

```text
SHOW DATABASE VERBOSE orclcdb_standby;
VALIDATE DATABASE orclcdb_standby;
SHOW CONFIGURATION;
```

### Tat FSFO va observer truoc khi stop lab

Sau khi test FSFO/reinstate xong, da connect vao current primary:

```bash
dgmgrl sys@PRIMARY_DG
```

Output:

```text
Connected to "ORCLCDB_PRIMARY"
Connected as SYSDBA.
```

FSFO truoc khi tat:

```text
SHOW FAST_START FAILOVER;

Fast-Start Failover: Enabled in Potential Data Loss Mode
Active Target:      orclcdb_standby
Potential Targets:  "orclcdb_standby"
  orclcdb_standby valid
Observer:           c31c2f05e111
Auto-reinstate:     TRUE
```

Tat FSFO va stop stale/running observer record:

```text
DISABLE FAST_START FAILOVER;
STOP OBSERVER c31c2f05e111;
SHOW OBSERVER;
SHOW CONFIGURATION;
```

Output:

```text
DGMGRL> DISABLE FAST_START FAILOVER;
Disabled.

DGMGRL> STOP OBSERVER c31c2f05e111;
Observer stopped.

DGMGRL> SHOW OBSERVER;

Configuration - lab_dg

  Fast-Start Failover:     DISABLED

No observers.
```

Final state:

```text
SHOW CONFIGURATION;

Configuration - lab_dg

  Protection Mode: MaxPerformance
  Members:
  ORCLCDB_PRIMARY - Primary database
    orclcdb_standby - Physical standby database

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS
```

Day la trang thai sach de stop lab.

Stop containers:

```bash
podman stop oraee-dg-observer
podman stop oraee-dg-standby
podman stop oraee-dg-primary
```

### Lan sau mo lai de test FSFO

Start containers:

```bash
podman start oraee-dg-primary
podman start oraee-dg-standby
podman start oraee-dg-observer
podman ps -a --filter name=oraee-dg
```

Check database/Broker truoc:

```bash
podman exec -it oraee-dg-observer bash
dgmgrl sys@PRIMARY_DG
```

Trong DGMGRL:

```text
SHOW CONFIGURATION;
SHOW DATABASE ORCLCDB_PRIMARY;
SHOW DATABASE orclcdb_standby;
SHOW FAST_START FAILOVER;
SHOW OBSERVER;
```

Muc tieu truoc khi start observer:

```text
ORCLCDB_PRIMARY - Primary database
orclcdb_standby - Physical standby database
Fast-Start Failover: Disabled
No observers
Configuration Status: SUCCESS
```

Thoat DGMGRL:

```text
EXIT
```

Start observer foreground:

```bash
dgmgrl sys@PRIMARY_DG
```

Trong DGMGRL:

```text
START OBSERVER FILE IS '/home/oracle/observer/state/fsfo_orclcdb.dat' LOGFILE IS '/home/oracle/observer/logs/fsfo_observer.log';
```

Khong dong terminal observer nay.

Mo terminal host khac, verify observer:

```bash
podman exec oraee-dg-observer bash -lc 'date; ps -ef | grep -i "[d]gmgrl\|[o]bserver"; tail -n 80 /home/oracle/observer/logs/fsfo_observer.log'
```

Mo DGMGRL session khac:

```bash
podman exec -it oraee-dg-observer bash
dgmgrl sys@PRIMARY_DG
```

Trong DGMGRL:

```text
SHOW OBSERVER;
SHOW FAST_START FAILOVER;
SHOW CONFIGURATION;
```

Chi enable FSFO khi thay:

```text
Last Ping to Primary: vai giay truoc
Configuration Status: SUCCESS
Fast-Start Failover: Disabled
```

Enable:

```text
ENABLE FAST_START FAILOVER;
SHOW FAST_START FAILOVER;
SHOW CONFIGURATION;
```

Verify observer log co monitoring:

```bash
podman exec oraee-dg-observer bash -lc 'tail -n 120 /home/oracle/observer/logs/fsfo_observer.log'
```

Can thay:

```text
Entering PING state
Observer Summary (Monitoring)
The standby ... is ready to be a FSFO target
Connection to the primary restored
```

Luc do moi test kill current primary.

Neu current primary la `ORCLCDB_PRIMARY`:

```bash
podman kill oraee-dg-primary
```

Neu current primary la `orclcdb_standby`:

```bash
podman kill oraee-dg-standby
```

Sau kill:

```bash
podman exec oraee-dg-observer bash -lc 'tail -n 220 /home/oracle/observer/logs/fsfo_observer.log'
```

Tim:

```text
Initiating Fast-Start Failover
Failover succeeded, new primary is ...
... needs to be reinstated
Successfully reinstated database ...
```

Sau test, luon tat lai:

```text
DISABLE FAST_START FAILOVER;
STOP OBSERVER c31c2f05e111;
SHOW OBSERVER;
SHOW CONFIGURATION;
```

Sau do connect DGMGRL vao primary target:

```bash
dgmgrl sys@PRIMARY_DG
```

Check:

```text
SHOW CONFIGURATION;
SHOW FAST_START FAILOVER;
SHOW DATABASE ORCLCDB_PRIMARY;
SHOW DATABASE orclcdb_standby;
```

Sau failover, bat lai old primary container:

```bash
podman start oraee-dg-standby
```

Roi trong DGMGRL:

```text
SHOW CONFIGURATION;
REINSTATE DATABASE orclcdb_standby;
SHOW CONFIGURATION;
SHOW DATABASE orclcdb_standby;
```

Neu reinstate thanh cong:

```text
ORCLCDB_PRIMARY: PRIMARY
orclcdb_standby: PHYSICAL STANDBY
Configuration Status: SUCCESS
```
