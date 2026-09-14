# Oracle RAC lab index

Muc tieu: theo doi chinh xac lab RAC dang o dau, con viec gi.

## Current status

```text
Step 01 done: rac-priv libvirt network
Step 02 done: shared ASM disk images, sau do convert sang raw .img
Step 03 done: tao/cai rac1 va rac2
Step 04 done: attach shared ASM disks vao ca hai VM
Step 05 done: public/private/VIP/SCAN names va /etc/hosts
Step 06 done: OS prerequisites, users, groups, SSH, time sync
Step 07 done: udev ASM disk rules va reboot persistence
Step 08 done: stage Grid/DB software vao /u01
Step 09 done: Grid Infrastructure + ASM OCRVOTE online
Step 10 done: Oracle Database home installed on rac1/rac2
Step 11 done: RAC database racdb active-active tren rac1/rac2
Step 12 done: Data Guard physical standby stdby1 (racdb_s) + Broker + FSFO
Step 13 done: Safe shutdown/startup procedure (stop_an_toan.sh)
Step 14 done: Cold backup VM/file (sparse disk image + XML)
Step 15 done: RMAN online backup + validate tren racdb, ghi vao +FRA
Step 16 done: Khac phuc su co FSFO (ORA-1017 do salt password file, ORA-1033 thieu _DGMGRL)
Step 17 done: Chuyen doi phan tang mang RFC 1918 (10.10.50.0/24 virbr-rac-pub, SCAN 10.10.50.30:1521, VIPs .21/.22)
Step 18 done: Thiet lap L4 Zero-Trust Firewall tren Host NixOS (chi mo TCP 1521 vao SCAN & VIPs cho Spark Compute)
```

## Session 2026-05-28

```text
[DB Install - Step 10]
- Fix INS-08101: them CV_ASSUME_DISTID=OEL8
- Fix INS-35971: them oracle.install.option=INSTALL_DB_SWONLY
- Fix INS-06006: setup bidirectional SSH oracle user (ssh-keyscan -H rac1 tu rac2)
- Fix INS-35100: dung -local flag vi oracle home da staged tren ca 2 node
- Them ORACLE_SID=racdb1 vao bash_profile oracle user

[SQLcl setup]
- Fix prompt: them instance_name tu v$instance vao glogin.sql
- Fix prompt: them container name (con_name) tu sys_context
- Prompt hien tai: SYS@racdb1[CDB$ROOT]>
- Luu y: listener khong listen tren localhost, phai dung rac1:1521

[PDB va HR schema]
- Tao USERS tablespace trong PDB1
- Tao PDB1 (create_file_dest='+DATA' vi PDBSEED dung GUID path)
- Cai HR schema vao PDB1
- Fix: password co '!' bi ORA-00922, dung password khong co ky tu dac biet
- Fix: HR tables bi tao nham vao SYS, phai drop va chay lai
- Grant select on v_$instance to HR (cho glogin.sql prompt)

[Files moi tao]
- STEP-00-RAC-QUICK-REFERENCE.md: env vars, dang nhap, startup checklist
- STEP-00-RAC-COMMANDS-EXPLORE.md: lenh kham pha cho grid va oracle user
- STEP-12-RAC-DATAGUARD-STANDBY.md: huong dan setup Data Guard
```

## Session 2026-09-14: Network Segregation & BigData L4 Hardening

```text
[Network Migration RFC 1918]
- Tach khoi bridge default virbr0 (192.168.122.0/24)
- Tao bridge virbr-rac-pub (10.10.50.1/24) cho Database Public
- Gan IP moi cho RAC nodes:
  * rac1: 10.10.50.11 · VIP: 10.10.50.21 (virbr-rac-pub)
  * rac2: 10.10.50.12 · VIP: 10.10.50.22 (virbr-rac-pub)
  * SCAN: 10.10.50.30:1521 (rac-scan.localdomain)
  * stdby1: 10.10.50.40 (Data Guard Standby)
- Giu nguyen bridge virbr-racpriv (10.10.10.0/24) MTU 9000 cho Cache Fusion interconnect

[L4 Zero-Trust Firewall (iptables on Host NixOS)]
- Hook vao systemd.services.libvirtd.postStart tren host NixOS
- Chuyen tiep stateful ESTABLISHED, RELATED
- Chi mo duy nhat TCP port 1521 tu BigData Compute (10.10.20.0/24) sang SCAN (10.10.50.30)
- Mo TCP port 1521 sang RAC VIPs (10.10.50.21, 10.10.50.22) do co che TNS REDIRECT cua Oracle RAC
- DROP toan bo luu luong con lai tu BigData sang Database Tier (chan tuyet doi SSH port 22 va node IP vat ly)
- DROP toan bo luu luong tu HDFS Private Storage (10.10.30.0/24) sang Database Tier
```

## Remaining route

```text
- RMAN Step 16: preview + validate backup pieces + crosscheck, lam ngay tren RAC hien tai, khong can VM moi
- RMAN Step 17: incremental backup + retention + cleanup co kiem soat, khong can VM moi
- RMAN Step 18: restore/recover that, hoan lai den khi co restore lab rieng va du disk
- Data Guard: tao VM stdby1, setup primary/standby (Step 12), hoan lai neu host disk chua du
- Load data lon: download Oracle sample schemas (SH) hoac generate bang script
```

## RMAN learning route

```text
Step 15 DONE:
  ARCHIVELOG
  online full backup plus archivelog vao +FRA
  control file/SPFILE autobackup
  list/report
  validate current database blocks

Step 16 NEXT, safe tren RAC hien tai:
  RESTORE DATABASE PREVIEW SUMMARY
  RESTORE DATABASE VALIDATE
  CROSSCHECK BACKUP
  LIST BACKUP SUMMARY

Step 17 NEXT, safe neu lam co kiem soat:
  incremental level 0
  incremental level 1
  retention policy
  report obsolete
  cleanup FRA co verify truoc/sau

Step 18 LATER, can restore lab rieng:
  restore SPFILE
  restore control file
  restore database
  recover database
  point-in-time recovery
  open resetlogs
```

Khong can tao VM moi cho Step 16 va Step 17.

Chi tao VM restore/standby khi da:

```text
kiem tra host disk con du
backup/copy RMAN pieces ra storage phu
chap nhan them OS disk va Oracle Home
```

Neu chi tinh toi Grid/ASM chay duoc:

```text
Step 08
Step 09
```

## Step list

```text
Step 01: STEP-01-RAC-PRIVATE-NETWORK.md
Step 02: STEP-02-RAC-SHARED-DISKS.md
Step 03: STEP-03-RAC-CREATE-VMS.md
Step 04: STEP-04-RAC-ATTACH-SHARED-ASM-DISKS.md
Step 05: STEP-05-RAC-NETWORK-HOSTS.md
Step 06: STEP-06-RAC-OS-PREREQS.md
Step 07: STEP-07-RAC-ASM-DISK-UDEV.md
Step 08: STEP-08-RAC-STAGE-ORACLE-SOFTWARE.md
Step 09: STEP-09-RAC-GRID-INSTALL.md
Step 10: STEP-10-RAC-DB-INSTALL.md
Step 11: STEP-11-RAC-DBCA-CREATE-DATABASE.md
Step 12: STEP-12-RAC-DATAGUARD-STANDBY.md
Step 13: STEP-13-RAC-SAFE-SHUTDOWN.md
Step 14: STEP-14-RAC-COLD-BACKUP.md
Step 15: STEP-15-RAC-RMAN-BASICS.md
STEP-00-RAC-QUICK-REFERENCE.md
STEP-00-RAC-COMMANDS-EXPLORE.md
```

## What each remaining step does

Step 08:

```text
Copy Grid home vao /u01/app/19.0.0/grid tren rac1/rac2.
Copy DB home vao /u01/app/oracle/product/19.0.0/dbhome_1 tren rac1/rac2.
Set owner grid/oracle.
Verify installer executable.
```

Step 09:

```text
Run Grid Infrastructure precheck.
Create Grid response file.
Install Grid Infrastructure.
Run root scripts.
Verify CRS, cluster nodes, ASM disk group.
```

Step 10:

```text
Install Oracle Database software home.
Run root.sh.
Verify DB home with runInstaller inventory.
```

Step 11:

```text
Use DBCA to create RAC database on ASM DATA/FRA.
Register with srvctl.
Verify sqlplus/srvctl/cluster resource status.
```

Step 12:

```text
Final smoke tests.
Start/stop notes.
Snapshot/backup notes.
Known limitations: OL9 + 19c base, no RU/MOS, trial license.
```

Step 13:

```text
Safe shutdown order: stop database -> stop cluster -> shutdown OS -> verify virsh shut off.
Safe startup notes after shutdown.
Emergency-only virsh destroy warning.
```

Step 14:

```text
Cold backup muc VM/file.
Stop cluster va VM truoc khi rsync sparse disk image + XML + runbook.
Khong phai RMAN backup.
```

Step 15:

```text
Hoc RMAN an toan tren racdb hien tai.
Verify ARCHIVELOG va +FRA truoc.
Backup database plus archivelog vao +FRA.
Chi inspect/list/report/validate; chua restore/recover/delete tren RAC dang chay.
```
