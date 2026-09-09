# Step 15 - Learn RMAN Basics on RAC

Muc tieu: hoc RMAN tren database RAC `racdb` dang chay, ghi backup vao ASM disk group `+FRA`.

Day la backup muc database:

```text
RMAN target database
-> backup set
-> Fast Recovery Area
-> ASM disk group +FRA
```

Khac voi Step 14:

```text
Step 14 = cold backup VM/file: OS disk, ASM disk image, libvirt XML
Step 15 = RMAN backup database: datafile, archivelog, control file, SPFILE
```

Khong can tao VM moi de hoc backup RMAN co ban.

Khong test `RESTORE DATABASE`, `RECOVER DATABASE`, `DELETE BACKUP`, `DELETE OBSOLETE`
tren RAC dang chay on dinh neu chua co restore lab rieng.

## 1. Backup ghi vao dau?

Dung `+FRA` hien tai:

```text
ASM disk group: +FRA
Logical capacity: 30GB
Host sparse file: oracle_rac/vm_disks/rac-fra.img
```

Khi `DB_RECOVERY_FILE_DEST=+FRA`, Oracle dung FRA cho:

```text
RMAN backup
archived redo log
control file autobackup
database copy
```

Truoc moi lan backup, phai kiem tra FRA con du cho.

## 2. Set environment

Chay tren `rac1`, user `oracle`:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=racdb1
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK
```

Verify:

```bash
echo "$ORACLE_HOME"
echo "$ORACLE_SID"
srvctl status database -d racdb
```

Expected:

```text
ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
ORACLE_SID=racdb1
racdb1 running on rac1
racdb2 running on rac2
```

## 3. Check database mode va FRA

Chay tren `rac1`, user `oracle`:

```bash
sqlplus / as sysdba
```

Trong SQL prompt:

```sql
set lines 200
col name format a25
col value format a50

archive log list;

show parameter db_recovery_file_dest
show parameter db_recovery_file_dest_size

select name,
       round(space_limit / 1024 / 1024 / 1024, 2) as limit_gb,
       round(space_used / 1024 / 1024 / 1024, 2) as used_gb,
       round(space_reclaimable / 1024 / 1024 / 1024, 2) as reclaimable_gb,
       number_of_files
from v$recovery_file_dest;

exit
```

Can verify:

```text
Database log mode = Archive Mode
db_recovery_file_dest = +FRA
FRA con du dung luong cho bai backup dau tien
```

Neu `db_recovery_file_dest` rong hoac FRA gan day, dung lai. Khong backup vo toi va.

## 4. Check ASM FRA tren Grid home

Chay tren `rac1`, user `grid`:

```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
export PATH=$ORACLE_HOME/bin:$PATH

asmcmd lsdg
```

Can thay:

```text
FRA/ MOUNTED
Total_MB khoang 30720
Free_MB du cho backup
```

## 5. Vao RMAN va chi doc trang thai

Chay tren `rac1`, user `oracle`, sau khi set lai DB home environment o section 2:

```bash
rman target /
```

Trong RMAN prompt:

```rman
SHOW ALL;
REPORT SCHEMA;
LIST BACKUP SUMMARY;
REPORT OBSOLETE;
```

Y nghia:

```text
SHOW ALL            xem persistent RMAN configuration
REPORT SCHEMA       xem datafile va tablespace
LIST BACKUP SUMMARY xem backup da co
REPORT OBSOLETE     chi report, khong xoa gi
```

`REPORT OBSOLETE` an toan vi chi doc. Khong chay `DELETE OBSOLETE` o bai dau.

## 6. Bat control file autobackup

Trong RMAN prompt:

```rman
CONFIGURE CONTROLFILE AUTOBACKUP ON;
SHOW ALL;
```

Control file autobackup giup backup control file va SPFILE tu dong sau backup.

Day la thay doi persistent RMAN configuration hop ly cho lab.

## 7. Bai backup dau tien

Truoc khi chay, verify FRA free space da du.

Trong RMAN prompt:

```rman
BACKUP DATABASE PLUS ARCHIVELOG TAG 'RACDB_FIRST_RMAN_BACKUP';
```

Lenh nay backup:

```text
archived redo log truoc backup
database datafiles
archived redo log sinh ra trong luc backup
control file/SPFILE autobackup
```

Khong them `DELETE INPUT` trong bai dau. Giu archivelog de de quan sat va tranh xoa nham.

## 8. Verify backup sau khi chay

Trong RMAN prompt:

```rman
LIST BACKUP SUMMARY;
LIST BACKUP TAG 'RACDB_FIRST_RMAN_BACKUP';
REPORT OBSOLETE;
```

Verify backup piece bang RMAN:

```rman
BACKUP VALIDATE DATABASE;
```

Ghi chu:

```text
BACKUP VALIDATE DATABASE doc block database de check corruption.
No khong tao them backup piece.
```

Sau do exit:

```rman
EXIT;
```

## 9. Check FRA sau backup

Chay tren `rac1`, user `oracle`:

```bash
sqlplus / as sysdba
```

Trong SQL prompt:

```sql
set lines 200

select name,
       round(space_limit / 1024 / 1024 / 1024, 2) as limit_gb,
       round(space_used / 1024 / 1024 / 1024, 2) as used_gb,
       round(space_reclaimable / 1024 / 1024 / 1024, 2) as reclaimable_gb,
       number_of_files
from v$recovery_file_dest;

exit
```

Tren host NixOS, user `tandat`, xem physical sparse file tang bao nhieu:

```bash
cd /home/tandat/Desktop/tandat_homelab

du -h oracle_rac/vm_disks/rac-fra.img
du -h --apparent-size oracle_rac/vm_disks/rac-fra.img
df -h /
```

Y nghia:

```text
du -h                 physical usage that tren host
du -h --apparent-size logical capacity 30GB
```

## 10. Chua lam trong bai nay

De hoc sau tren restore lab rieng:

```rman
RESTORE DATABASE;
RECOVER DATABASE;
DELETE BACKUP;
DELETE OBSOLETE;
BACKUP ARCHIVELOG ALL DELETE INPUT;
```

Ly do:

```text
Backup/list/report/validate an toan de hoc tren RAC hien tai.
Restore/recover/delete co blast radius lon hon.
Nen tao VM restore rieng hoac clone offline truoc khi thu.
```

## Done criteria

```text
FRA duoc verify truoc backup
RMAN connect target / thanh cong
SHOW ALL va REPORT SCHEMA chay duoc
CONFIGURE CONTROLFILE AUTOBACKUP ON da set
BACKUP DATABASE PLUS ARCHIVELOG chay thanh cong
LIST BACKUP SUMMARY thay backup piece
BACKUP VALIDATE DATABASE khong bao corruption
FRA usage sau backup da duoc ghi lai
```

## Session log 2026-06-01

Trang thai truoc khi hoc RMAN:

```text
Lan shutdown truoc da stop database va stop cluster co chu dich.
Sau khi boot lai, Clusterware online nhung racdb chua auto-start.
Da start lai racdb bang srvctl truoc khi vao RMAN.
```

Lenh verify/start database chay tren `rac1`, user `oracle`:

```bash
srvctl status database -d racdb
srvctl start database -db racdb
srvctl status database -db racdb
```

FRA parameter da verify trong SQL*Plus tren `rac1`, user `oracle`,
instance `racdb1`:

```sql
show parameter db_recovery_file_dest_size
show parameter db_recovery_file_dest
```

Ket qua:

```text
db_recovery_file_dest      = +FRA
db_recovery_file_dest_size = 14007M
```

FRA usage da verify:

```sql
SELECT name,
       ROUND(space_limit / 1024 / 1024 / 1024, 2) AS limit_gb,
       ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
       ROUND(space_reclaimable / 1024 / 1024 / 1024, 2) AS reclaimable_gb,
       number_of_files
FROM v$recovery_file_dest;
```

Ket qua:

```text
NAME  LIMIT_GB  USED_GB  RECLAIMABLE_GB  NUMBER_OF_FILES
+FRA     13.68     0.81               0                5
```

Phan tich:

```text
FRA quota:    13.68GB
Dang dung:     0.81GB
Con khoang:   12.87GB
```

Da connect RMAN thanh cong tren `rac1`, user `oracle`:

```bash
rman target /
```

Output:

```text
Recovery Manager: Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

connected to target database: RACDB (DBID=1231980070)
```

Trang thai hien tai:

```text
Da vao duoc RMAN prompt.
Da chay SHOW ALL, REPORT SCHEMA, LIST BACKUP SUMMARY, REPORT OBSOLETE.
Chua chay BACKUP DATABASE.
```

### RMAN repository va configuration

Da chay:

```rman
SHOW ALL;
```

Ket qua quan trong:

```text
using target database control file instead of recovery catalog

CONFIGURE RETENTION POLICY TO REDUNDANCY 1;
CONFIGURE DEFAULT DEVICE TYPE TO DISK;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE DEVICE TYPE DISK PARALLELISM 1 BACKUP TYPE TO BACKUPSET;
CONFIGURE ENCRYPTION FOR DATABASE OFF;
CONFIGURE COMPRESSION ALGORITHM 'BASIC';
CONFIGURE ARCHIVELOG DELETION POLICY TO NONE;
CONFIGURE SNAPSHOT CONTROLFILE NAME TO
  '/u01/app/oracle/product/19.0.0/dbhome_1/dbs/snapcf_racdb1.f';
```

Phan tich:

```text
Chua dung recovery catalog rieng.
RMAN metadata dang luu trong target database control file.

Retention REDUNDANCY 1:
  RMAN giu it nhat 1 backup hop le de recovery.
  Backup cu hon co the bi REPORT OBSOLETE danh dau sau khi co backup moi.

Device type DISK + BACKUPSET:
  Bai backup dau tien ghi backup set xuong disk/FRA.

CONTROLFILE AUTOBACKUP ON:
  Control file va SPFILE autobackup da bat san.
  Khong can chay CONFIGURE lai.

PARALLELISM 1:
  Mot channel backup.
  Tot cho lab nho, tranh day I/O.

ENCRYPTION OFF:
  Backup chua encrypt.
  Chap nhan duoc cho homelab, khong phai production recommendation.

ARCHIVELOG DELETION POLICY NONE:
  RMAN khong tu xoa archivelog.
  Bai dau cung khong dung DELETE INPUT de tranh xoa nham.
```

### Database schema report

Da chay:

```rman
REPORT SCHEMA;
```

Permanent datafiles:

```text
File  Size(MB) Tablespace
1     910      SYSTEM
3     640      SYSAUX
4     340      UNDOTBS1
5     270      PDB$SEED:SYSTEM
6     310      PDB$SEED:SYSAUX
7     5        USERS
8     100      PDB$SEED:UNDOTBS1
9     25       UNDOTBS2
10    280      PDB1:SYSTEM
11    340      PDB1:SYSAUX
12    100      PDB1:UNDOTBS1
13    100      PDB1:UNDO_2
14    100      PDB1:USERS
```

Tong permanent datafile:

```text
3520MB, khoang 3.44GB
```

Temporary files:

```text
TEMP          32MB
PDB$SEED:TEMP 36MB
PDB1:TEMP     36MB
```

Phan tich:

```text
RMAN backup database backup permanent datafile.
Temporary file khong can backup nhu permanent datafile vi co the tao lai.

FRA con khoang 12.87GB.
Database permanent datafile khoang 3.44GB.
Backup set thuong skip unused block, nen bai full backup dau tien du suc chua trong FRA.
Van phai kiem tra FRA usage lai sau backup.
```

### Backup repository hien tai

Da chay:

```rman
LIST BACKUP SUMMARY;
REPORT OBSOLETE;
```

Ket qua:

```text
LIST BACKUP SUMMARY:
  specification does not match any backup in the repository

REPORT OBSOLETE:
  RMAN retention policy is set to redundancy 1
  no obsolete backups found
```

Phan tich:

```text
Chua co RMAN backup nao trong repository.
Khong co backup cu de danh dau obsolete.
Day la baseline sach truoc bai backup RMAN dau tien.
```

### Next command

Truoc khi backup, verify ARCHIVELOG mode neu chua ghi output:

```sql
archive log list;
```

Neu database dang `Archive Mode`, chay trong RMAN:

```rman
BACKUP DATABASE PLUS ARCHIVELOG TAG 'RACDB_FIRST_RMAN_BACKUP';
```

### Lan backup dau tien bi dung do NOARCHIVELOG

Da chay trong RMAN:

```rman
BACKUP DATABASE PLUS ARCHIVELOG TAG 'RACDB_FIRST_RMAN_BACKUP';
```

Ket qua:

```text
ORA-00258: manual archiving in NOARCHIVELOG mode must identify log
specification does not match any archived log in the repository
backup cancelled because there are no files to backup

RMAN-03002: failure of backup plus archivelog command
RMAN-06149: cannot BACKUP DATABASE in NOARCHIVELOG mode
```

Phan tich:

```text
Database racdb dang o NOARCHIVELOG mode.
Khong co archived redo log de backup.
RMAN khong cho hot backup database dang OPEN trong NOARCHIVELOG mode.

Khong co backup database nao duoc tao trong lan chay nay.
Day la precondition fail, khong phai database corruption.
```

Co hai huong:

```text
Huong hoc backup online va Data Guard:
  Bat ARCHIVELOG mode.
  Day la huong dung cho lab nay.

Huong backup NOARCHIVELOG:
  Shutdown database sach.
  Startup mount.
  BACKUP DATABASE.
  Chi phu hop cold consistent backup, khong backup online.
```

## 11. Enable ARCHIVELOG mode cho RACDB

Muc tieu:

```text
Bat ARCHIVELOG de RMAN backup online va chuan bi cho Data Guard sau nay.
```

Khong doi ASM/Grid config. Chi restart database co chu dich.

### Hieu NOMOUNT, MOUNT va OPEN

Oracle Database startup qua ba trang thai chinh:

```text
NOMOUNT -> MOUNT -> OPEN
```

`NOMOUNT`:

```text
Instance da khoi dong.
SPFILE/PFILE da duoc doc.
SGA va background process da tao.
Control file chua mo.
Datafile chua mo.
```

Thuong dung khi:

```text
tao database
restore control file
thao tac maintenance cap thap
```

`MOUNT`:

```text
Instance da chay.
Control file da mo.
Oracle biet datafile va redo log nam o dau.
Datafile chua mo cho user su dung.
```

Thuong dung khi:

```text
bat/tat ARCHIVELOG mode
restore/recover database
rename datafile
maintenance can database chua OPEN
```

`OPEN`:

```text
Control file da mo.
Datafile da mo.
Redo log dang hoat dong.
User co the connect, query va insert.
```

Day la trang thai van hanh binh thuong.

Luong startup:

```text
STARTUP NOMOUNT
       |
       v
ALTER DATABASE MOUNT
       |
       v
ALTER DATABASE OPEN
```

Khi chay:

```bash
srvctl start database -db racdb
```

Clusterware thuong dua database di thang toi `OPEN`.

Nhung de bat `ARCHIVELOG`, Oracle yeu cau database o trang thai `MOUNT`.
Ly do: Oracle can thay doi cach redo log duoc archive truoc khi mo datafile
cho user tiep tuc ghi du lieu.

Voi RAC:

```text
Truoc:
  racdb1 OPEN
  racdb2 OPEN

Trong luc doi mode:
  racdb1 MOUNTED
  racdb2 STOPPED

Sau:
  racdb1 OPEN
  racdb2 OPEN
```

Day la downtime ngan mot lan de chuyen:

```text
NOARCHIVELOG -> ARCHIVELOG
```

Sau khi da bat ARCHIVELOG, RMAN `BACKUP DATABASE PLUS ARCHIVELOG` co the chay
online khi database dang `OPEN`. Khong can stop database moi lan backup.

Thoat RMAN neu dang o RMAN prompt:

```rman
EXIT;
```

Chay tren `rac1`, user `oracle`:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=racdb1
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK

srvctl stop database -db racdb -stopoption immediate
srvctl start instance -db racdb -instance racdb1 -startoption mount
```

Vao SQL*Plus tren `rac1`, user `oracle`:

```bash
sqlplus / as sysdba
```

Trong SQL prompt:

```sql
archive log list;

alter database archivelog;

archive log list;
exit
```

Expected sau khi alter:

```text
Database log mode              Archive Mode
Automatic archival             Enabled
Archive destination            USE_DB_RECOVERY_FILE_DEST
```

Sau do stop instance mount va start lai ca RAC database:

```bash
srvctl stop instance -db racdb -instance racdb1 -stopoption immediate
srvctl start database -db racdb
srvctl status database -db racdb
```

Expected:

```text
Instance racdb1 is running on node rac1
Instance racdb2 is running on node rac2
```

Verify ARCHIVELOG lan cuoi:

```bash
sqlplus / as sysdba
```

```sql
archive log list;
exit
```

## 12. Retry first RMAN backup after ARCHIVELOG

Chay tren `rac1`, user `oracle`:

```bash
rman target /
```

Trong RMAN prompt:

```rman
BACKUP DATABASE PLUS ARCHIVELOG TAG 'RACDB_FIRST_RMAN_BACKUP';

LIST BACKUP SUMMARY;
LIST BACKUP TAG 'RACDB_FIRST_RMAN_BACKUP';
EXIT;
```

## Session log 2026-06-01 - Enable ARCHIVELOG

Sau khi stop database va mount rieng instance `racdb1`, da verify:

```sql
select status from v$instance;
```

Ket qua:

```text
STATUS
MOUNTED
```

Truoc khi doi mode, da chay:

```sql
archive log list;
```

Ket qua:

```text
Database log mode                       No Archive Mode
Automatic archival                      Disabled
Archive destination                     USE_DB_RECOVERY_FILE_DEST
Oldest online log sequence              3
Current log sequence                    10
```

Da bat ARCHIVELOG:

```sql
alter database archivelog;
```

Trong luc verify co typo:

```sql
archieve log list;
```

SQL*Plus bao:

```text
SP2-0734: unknown command beginning "archieve l..." - rest of line ignored.
```

Lenh dung:

```sql
archive log list;
```

Ket qua sau khi bat:

```text
Database log mode                       Archive log Mode
Automatic archival                      Enabled
Archive destination                     USE_DB_RECOVERY_FILE_DEST
Oldest online log sequence              3
Next log sequence to archive            10
Current log sequence                    10
```

Phan tich:

```text
Database log mode = Archive log Mode:
  racdb da chuyen thanh cong tu NOARCHIVELOG sang ARCHIVELOG.

Automatic archival = Enabled:
  Oracle se tu archive online redo log khi log switch.

Archive destination = USE_DB_RECOVERY_FILE_DEST:
  Archived redo log se ghi vao Fast Recovery Area.
  FRA cua lab dang tro vao ASM disk group +FRA.

Current log sequence = 10:
  Online redo log hien tai la sequence 10.

Next log sequence to archive = 10:
  Sequence 10 la redo sequence tiep theo se duoc archive khi log switch.
```

Trang thai:

```text
ARCHIVELOG da bat thanh cong.
Can stop racdb1 mount va start lai toan bo RAC database.
Sau khi racdb1/racdb2 OPEN, retry RMAN online backup.
```

### Verify sau khi start lai RAC database

Sau khi start lai database, da chay tren `rac1`, user `oracle`:

```sql
select inst_id, instance_name, host_name, status
from gv$instance;
```

Ket qua:

```text
INST_ID  INSTANCE_NAME  HOST_NAME  STATUS
1        racdb1         rac1       OPEN
2        racdb2         rac2       OPEN
```

Da verify lai:

```sql
archive log list;
```

Ket qua:

```text
Database log mode                       Archive log Mode
Automatic archival                      Enabled
Archive destination                     USE_DB_RECOVERY_FILE_DEST
Oldest online log sequence              3
Next log sequence to archive            10
Current log sequence                    10
```

Ket luan:

```text
racdb1 va racdb2 da OPEN lai tren ca hai node.
ARCHIVELOG mode van enabled sau khi restart.
Database san sang cho RMAN online backup.
```

## Session log 2026-06-01 - First online RMAN backup successful

Da connect RMAN tren `rac1`, user `oracle`:

```bash
rman target /
```

Output connect:

```text
connected to target database: RACDB (DBID=1231980070)
```

Da chay:

```rman
BACKUP DATABASE PLUS ARCHIVELOG TAG 'RACDB_FIRST_RMAN_BACKUP';
```

Ket qua:

```text
RMAN online backup thanh cong.
Khong can stop racdb1/racdb2.
Backup piece duoc ghi vao ASM disk group +FRA.
Control File va SPFILE Autobackup thanh cong.
```

### Phase 1 - Archive redo truoc database backup

RMAN archive current log va backup archived redo:

```text
input archived log thread=2 sequence=4
input archived log thread=1 sequence=10

piece handle:
+FRA/RACDB/BACKUPSET/2026_06_01/annnf0_racdb_first_rman_backup_0.263.1234800149
```

Phan tich:

```text
RAC co nhieu redo thread.
Thread 1 thuoc activity cua instance racdb1.
Thread 2 thuoc activity cua instance racdb2.
RMAN da backup archived redo cua ca hai thread.
```

### Phase 2 - Full database datafile backup

RMAN backup permanent datafiles cua:

```text
CDB root:
  SYSTEM, SYSAUX, UNDOTBS1, UNDOTBS2, USERS

PDB1:
  SYSTEM, SYSAUX, UNDOTBS1, UNDO_2, USERS

PDB$SEED:
  SYSTEM, SYSAUX, UNDOTBS1
```

Backup pieces:

```text
+FRA/RACDB/BACKUPSET/2026_06_01/nnndf0_tag20260601t160229_0.264.1234800149

+FRA/RACDB/52E332D7790517EFE063CD7AA8C057C1/BACKUPSET/2026_06_01/nnndf0_tag20260601t160229_0.265.1234800153

+FRA/RACDB/52C8C4571D6A49AAE063CD7AA8C04F40/BACKUPSET/2026_06_01/nnndf0_tag20260601t160229_0.266.1234800155
```

Phan tich:

```text
RMAN tach backup set theo container/datafile group.
Backup set luu block database can thiet, khong phai copy nguyen raw ASM image.
Temporary file khong nam trong danh sach backup permanent datafile.
```

### Phase 3 - Archive redo sinh ra trong luc backup

Sau datafile backup, RMAN archive current log lan nua va backup:

```text
input archived log thread=1 sequence=11
input archived log thread=2 sequence=5

piece handle:
+FRA/RACDB/BACKUPSET/2026_06_01/annnf0_racdb_first_rman_backup_0.269.1234800161
```

Phan tich:

```text
PLUS ARCHIVELOG backup redo truoc va sau database backup.
Redo nay can thiet de recover datafiles ve trang thai consistent.
```

### Phase 4 - Control file va SPFILE autobackup

Do `CONFIGURE CONTROLFILE AUTOBACKUP ON`, RMAN da tu tao:

```text
+FRA/RACDB/AUTOBACKUP/2026_06_01/s_1234800161.270.1234800161
```

Phan tich:

```text
Autobackup giup restore control file va SPFILE khi can disaster recovery.
```

### Next verify commands

Trong RMAN prompt:

```rman
LIST BACKUP SUMMARY;
LIST BACKUP TAG 'RACDB_FIRST_RMAN_BACKUP';
REPORT OBSOLETE;
```

Sau do:

```rman
EXIT;
```

Trong SQL*Plus:

```sql
select name,
       round(space_limit / 1024 / 1024 / 1024, 2) as limit_gb,
       round(space_used / 1024 / 1024 / 1024, 2) as used_gb,
       round(space_reclaimable / 1024 / 1024 / 1024, 2) as reclaimable_gb,
       number_of_files
from v$recovery_file_dest;
```

Tren host NixOS, user `tandat`:

```bash
cd /home/tandat/Desktop/tandat_homelab
du -h oracle_rac/vm_disks/rac-fra.img
du -h --apparent-size oracle_rac/vm_disks/rac-fra.img
df -h /
```

### FRA usage sau first online backup

Da chay trong SQL*Plus tren `rac1`, user `oracle`:

```sql
SELECT name,
       ROUND(space_limit / 1024 / 1024 / 1024, 2) AS limit_gb,
       ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
       ROUND(space_reclaimable / 1024 / 1024 / 1024, 2) AS reclaimable_gb,
       number_of_files
FROM v$recovery_file_dest;
```

Ket qua:

```text
NAME  LIMIT_GB  USED_GB  RECLAIMABLE_GB  NUMBER_OF_FILES
+FRA     13.68     3.22            0.08               15
```

So voi truoc backup:

```text
Truoc backup:
  used_gb         = 0.81
  number_of_files = 5

Sau backup:
  used_gb         = 3.22
  number_of_files = 15

Tang:
  used_gb         = 2.41GB
  number_of_files = 10

Con lai theo FRA quota:
  13.68 - 3.22 = khoang 10.46GB
```

Phan tich:

```text
First online RMAN backup chiem them khoang 2.41GB trong FRA.
Backup set nho hon tong permanent datafile 3.44GB vi RMAN chi backup block can thiet.
FRA van con du dung luong de hoc them, nhung can check usage truoc moi backup.
Khong chay backup lap vo toi neu chua hoc retention va delete obsolete.
```

## Session log 2026-06-01 - Verify first RMAN backup

Da chay:

```rman
LIST BACKUP SUMMARY;
```

Ket qua summary:

```text
Key  TY  LV  S  Device  Completion  Pieces  Copies  Compressed  Tag
1    B   A   A  DISK    01-JUN-26   1       1       NO          RACDB_FIRST_RMAN_BACKUP
2    B   F   A  DISK    01-JUN-26   1       1       NO          TAG20260601T160229
3    B   F   A  DISK    01-JUN-26   1       1       NO          TAG20260601T160229
4    B   F   A  DISK    01-JUN-26   1       1       NO          TAG20260601T160229
5    B   A   A  DISK    01-JUN-26   1       1       NO          RACDB_FIRST_RMAN_BACKUP
6    B   F   A  DISK    01-JUN-26   1       1       NO          TAG20260601T160241
```

Y nghia:

```text
B = backup set
A trong cot TY/LV = archived log backup
F = full backup
S = AVAILABLE
Device = DISK, thuc te pieces nam trong ASM +FRA
Compressed = NO, backup dau tien chua bat compression
```

Da chay:

```rman
LIST BACKUP TAG 'RACDB_FIRST_RMAN_BACKUP';
```

Ket qua archived redo backup:

```text
Backup set 1: 40.26M
  thread 1 sequence 10
  thread 2 sequence 4

Backup set 5: 20.50K
  thread 1 sequence 11
  thread 2 sequence 5
```

Y nghia:

```text
PLUS ARCHIVELOG da backup archived redo cua ca hai RAC threads.
Backup set 1 la redo truoc datafile backup.
Backup set 5 la redo sau datafile backup.
```

Da chay:

```rman
REPORT OBSOLETE;
```

Ket qua:

```text
RMAN retention policy is set to redundancy 1

Obsolete:
  Archive Log thread 1 sequence 10
  Archive Log thread 2 sequence 4
  Backup Set 1 archived log backup
```

Y nghia:

```text
REPORT OBSOLETE chi report, khong xoa file.
Retention REDUNDANCY 1 da nhan dien mot so archived log/backup set cu co the reclaim.
Khong chay DELETE OBSOLETE trong bai dau.
```

Da chay integrity check:

```rman
BACKUP VALIDATE DATABASE;
```

Ket qua:

```text
Tat ca permanent datafiles co Status = OK.
Tat ca datafile co Marked Corrupt = 0.
Tat ca block type co Blocks Failing = 0.
SPFILE       OK, Blocks Failing = 0.
Control File OK, Blocks Failing = 0.
```

Y nghia:

```text
RMAN da doc va validate database blocks.
Khong phat hien corruption trong datafiles, SPFILE hoac control file.
BACKUP VALIDATE khong tao them backup piece.
```

Da thu:

```rman
LIST FAILURE;
```

RMAN bao:

```text
RMAN-05533: Command LIST FAILURE is not supported on RAC database
```

Phan tich:

```text
Day khong phai loi backup.
LIST FAILURE khong duoc support tren RAC database.
Dung BACKUP VALIDATE DATABASE va output Blocks Failing = 0 de verify bai nay.
```

### Step 15 done criteria thuc te

```text
PASS: racdb ARCHIVELOG enabled
PASS: racdb1/racdb2 OPEN sau restart
PASS: online BACKUP DATABASE PLUS ARCHIVELOG thanh cong
PASS: archived redo cua thread 1 va thread 2 da backup
PASS: control file va SPFILE autobackup thanh cong
PASS: LIST BACKUP SUMMARY thay backup AVAILABLE
PASS: BACKUP VALIDATE DATABASE: datafiles/SPFILE/control file OK, Blocks Failing = 0
PASS: FRA usage sau backup da ghi lai, con khoang 10.46GB quota

INFO: LIST FAILURE khong supported tren RAC, bo qua.
TODO: restore/recover test chi lam tren restore lab rieng.
```

## RMAN roadmap sau Step 15

Khong can tao VM moi ngay.

Lam tiep tren RAC hien tai, an toan:

```text
Step 16:
  RESTORE DATABASE PREVIEW SUMMARY
  RESTORE DATABASE VALIDATE
  CROSSCHECK BACKUP
  LIST BACKUP SUMMARY

Step 17:
  hoc incremental level 0
  hoc incremental level 1
  hoc retention policy
  REPORT OBSOLETE
  cleanup FRA co kiem soat
```

Hoan lai den khi co restore lab rieng:

```text
Step 18:
  RESTORE SPFILE
  RESTORE CONTROLFILE
  RESTORE DATABASE
  RECOVER DATABASE
  point-in-time recovery
  OPEN RESETLOGS
```

Ly do:

```text
Preview/validate/crosscheck/incremental co the hoc tren RAC hien tai.
Restore/recover that la destructive workflow, khong test tren racdb dang chay on dinh.
VM restore hoac standby moi se ton them disk cho OS, Oracle Home va database files.
```

## Tai lieu Oracle

```text
Oracle Database 19c Backup and Recovery User's Guide:
https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/

RMAN BACKUP command:
https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/BACKUP.html

Fast Recovery Area:
https://docs.oracle.com/en/database/oracle/oracle-database/19/cwaix/about-the-fast-recovery-area-and-the-fast-recovery-area-disk-group.html
```
