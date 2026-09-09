# Step 11 - Create RAC Database with DBCA

Muc tieu: tao database RAC 2 node bang DBCA, dung ASM disk groups `DATA` va `FRA`.

Dieu kien truoc khi chay Step nay:

```text
Step 09 Grid Infrastructure da xong
Step 10 DB software da xong tren ca rac1 va rac2
root.sh DB home da chay tren ca rac1 va rac2
SQL*Plus 19.3 OK tren ca rac1 va rac2
CRS/ASM online tren ca hai node
```

Ten database dung cho lab nay:

```text
DB name / SID prefix: racdb
Global DB name: racdb.localdomain
Instance tren rac1: racdb1
Instance tren rac2: racdb2
ASM data disk group: DATA
ASM recovery disk group: FRA
```

## 1. Verify cluster va ASM truoc khi DBCA

Chay tren `rac1`, user `grid`:

```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
export PATH=$ORACLE_HOME/bin:$PATH

crsctl check cluster -all
srvctl status asm
asmcmd lsdg
crsctl stat res -t
```

Expected:

```text
CRS/CSS/EVM online tren rac1 va rac2
ASM is running on rac1,rac2
OCRVOTE mounted
Neu DATA/FRA chua co thi tao o section 2
```

## 1b. Verify static IP va private interconnect

Day la precheck lay lai tu Step 09 section static IP / cluster interconnect.
Khong bo qua truoc DBCA vi RAC database can interconnect on dinh, khong de route sai qua public NIC.

Chay tren `rac1`, user `grid`:

```bash
echo === rac1 addr ===
ip addr show enp1s0 | grep "inet "
ip addr show enp2s0 | grep "inet "
ip route show

echo === rac2 addr ===
ssh rac2 'ip addr show enp1s0 | grep "inet "; ip addr show enp2s0 | grep "inet "; ip route show'

echo === private ping ===
ping -I enp2s0 -c 3 rac2-priv
ssh rac2 'ping -I enp2s0 -c 3 rac1-priv'
```

Expected:

```text
rac1 enp1s0: 192.168.122.205/24
rac1 enp2s0: 10.10.10.11/24
rac2 enp1s0: 192.168.122.46/24
rac2 enp2s0: 10.10.10.12/24
default route chi qua enp1s0
10.10.10.0/24 route qua enp2s0
private ping 0% packet loss ca hai chieu
```

Verify ASM cluster_interconnects da ep dung private IP.

Chay tren `rac1`, user `grid`:

```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
export ORACLE_SID=+ASM1
unset TWO_TASK
export PATH=$ORACLE_HOME/bin:$PATH
sqlplus / as sysasm
```

Trong SQL prompt:

```sql
set lines 200
col name format a25
col value format a40
select inst_id, name, value
from gv$spparameter
where name='cluster_interconnects'
order by inst_id;
exit
```

Expected:

```text
+ASM1 -> 10.10.10.11
+ASM2 -> 10.10.10.12
```

Ket qua thuc te 2026-05-27:

```text
Private ping rac1 -> rac2-priv: 0% packet loss
Private ping rac2 -> rac1-priv: 0% packet loss

rac1 public/VIP/private/HAIP:
  192.168.122.205, 192.168.122.211, 10.10.10.11, 169.254.12.87
rac2 public/VIP/SCAN/private/HAIP:
  192.168.122.46, 192.168.122.212, 192.168.122.213, 10.10.10.12, 169.254.15.195

Route OK:
  default route qua enp1s0 public
  10.10.10.0/24 qua enp2s0 private
```

ASM cluster_interconnects output:

```text
INST_ID NAME                    VALUE
------- ----------------------- ----------------
1       cluster_interconnects   10.10.10.11
1       cluster_interconnects   10.10.10.12
2       cluster_interconnects   10.10.10.11
2       cluster_interconnects   10.10.10.12
```

Note:

```text
Neu `sqlplus / as sysasm` bao ORA-12162, nghia la thieu ORACLE_SID.
Set `ORACLE_SID=+ASM1` tren rac1 roi login lai.
```

## 2. Tao ASM disk groups DATA va FRA neu chua co

Kiem tra disk groups hien co.

Chay tren `rac1`, user `grid`:

```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
export PATH=$ORACLE_HOME/bin:$PATH
asmcmd lsdg
```

Neu output chua co `DATA` va `FRA`, tao bang SQL*Plus SYSASM.

Chay tren `rac1`, user `grid`:

```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
export PATH=$ORACLE_HOME/bin:$PATH
sqlplus / as sysasm
```

Trong SQL prompt:

```sql
CREATE DISKGROUP DATA EXTERNAL REDUNDANCY
  DISK '/dev/asm-data'
  ATTRIBUTE 'compatible.asm'='19.0.0.0.0',
            'compatible.rdbms'='19.0.0.0.0';

CREATE DISKGROUP FRA EXTERNAL REDUNDANCY
  DISK '/dev/asm-fra'
  ATTRIBUTE 'compatible.asm'='19.0.0.0.0',
            'compatible.rdbms'='19.0.0.0.0';

exit
```

Neu bao `ORA-15018` hoac disk group already exists, dung lai va verify, khong tao lai.

Verify tren `rac1`, user `grid`:

```bash
asmcmd lsdg
crsctl stat res -t | grep -E 'ora.DATA.dg|ora.FRA.dg|ora.OCRVOTE.dg'
```

Expected:

```text
DATA mounted
FRA mounted
ora.DATA.dg ONLINE
ora.FRA.dg ONLINE
```

Ket qua thuc te 2026-05-27:

Lenh da chay tren `rac1`, user `grid`:

```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
export ORACLE_SID=+ASM1
unset TWO_TASK
export PATH=$ORACLE_HOME/bin:$PATH
sqlplus / as sysasm
```

Trong SQL*Plus da tao disk group. Lan dau `DATA` da duoc tao thanh cong nhung prompt/execute bi nham nen chay lai gap loi:

```sql
CREATE DISKGROUP DATA EXTERNAL REDUNDANCY DISK '/dev/asm-data' ATTRIBUTE 'compatible.asm'='19.0.0.0.0','compatible.rdbms'='19.0.0.0.0';
```

Ket qua khi chay lai:

```text
ORA-15018: diskgroup cannot be created
ORA-15030: diskgroup name "DATA" is in use by another diskgroup
```

Y nghia: `DATA` da ton tai, khong phai loi can fix.

Lenh tao `FRA` da chay trong SQL*Plus:

```sql
CREATE DISKGROUP FRA EXTERNAL REDUNDANCY DISK '/dev/asm-fra' ATTRIBUTE 'compatible.asm'='19.0.0.0.0','compatible.rdbms'='19.0.0.0.0';
exit
```

Verify da chay tren `rac1`, user `grid`:

```bash
asmcmd lsdg
crsctl stat res -t | grep -E 'ora.DATA.dg|ora.FRA.dg|ora.OCRVOTE.dg'
```

Output verify:

```text
DATA/     MOUNTED EXTERN Total_MB=30720 Free_MB=30666 Voting_files=N
FRA/      MOUNTED EXTERN Total_MB=30720 Free_MB=30666 Voting_files=N
OCRVOTE/  MOUNTED EXTERN Total_MB=10240 Free_MB=9904  Voting_files=Y

crsctl stat res -t co resource:
  ora.DATA.dg(ora.asmgroup)
  ora.FRA.dg(ora.asmgroup)
  ora.OCRVOTE.dg(ora.asmgroup)
```

## 3. Verify oracle SSH va DB home

Chay tren `rac1`, user `oracle`:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

sqlplus -version
ssh -o BatchMode=yes oracle@rac2 hostname
ssh -o BatchMode=yes oracle@rac2 "ssh -o BatchMode=yes oracle@rac1 hostname"
```

Expected:

```text
SQL*Plus 19.3.0.0.0
rac2
rac1
```

Ket qua thuc te 2026-05-27 tren `rac1`, user `oracle`:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

sqlplus -version
ssh -o BatchMode=yes oracle@rac2 hostname
ssh -o BatchMode=yes oracle@rac2 "ssh -o BatchMode=yes oracle@rac1 hostname"
```

Output:

```text
SQL*Plus: Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

rac2
rac1
```

Neu SSH nguoc rac2 -> rac1 bi host key:

```bash
ssh oracle@rac2 "ssh-keyscan -H rac1 2>/dev/null >> /home/oracle/.ssh/known_hosts"
ssh -o BatchMode=yes oracle@rac2 "ssh -o BatchMode=yes oracle@rac1 hostname"
```

## 4. Chuan bi password bien moi truong

Chay tren `rac1`, user `oracle`:

```bash
read -s -p 'SYS password: ' SYS_PASSWORD; echo
read -s -p 'SYSTEM password: ' SYSTEM_PASSWORD; echo
read -s -p 'PDB admin password: ' PDB_PASSWORD; echo
```

Ghi nho: password khong hien ra man hinh. Khong paste password vao file markdown.

## 5. Chay DBCA silent tao RAC database

Chay tren `rac1`, user `oracle`.

Source docs: Oracle DBCA silent RAC create database dung `-createDatabase`, `-templateName`, `-gdbName`, `-sid`, `-storageType ASM`, `-diskGroupName`, `-nodelist`.

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
export CV_ASSUME_DISTID=OEL8

dbca -silent -createDatabase \
  -templateName General_Purpose.dbc \
  -gdbName racdb.localdomain \
  -sid racdb \
  -databaseConfigType RAC \
  -nodelist rac1,rac2 \
  -storageType ASM \
  -diskGroupName +DATA \
  -recoveryAreaDestination +FRA \
  -characterSet AL32UTF8 \
  -nationalCharacterSet AL16UTF16 \
  -createAsContainerDatabase true \
  -numberOfPDBs 1 \
  -pdbName pdb1 \
  -pdbAdminPassword "$PDB_PASSWORD" \
  -sysPassword "$SYS_PASSWORD" \
  -systemPassword "$SYSTEM_PASSWORD" \
  -emConfiguration NONE \
  -totalMemory 2048 \
  -ignorePreReqs
```

Ghi chu:

```text
-totalMemory 2048 de hop voi lab VM RAM thap.
Neu DBCA fail vi memory, giam xuong 1536.
Neu DBCA fail vi prereq OL9/19.3, giu CV_ASSUME_DISTID=OEL8 va -ignorePreReqs.
DBCA chay lau. Khong Ctrl-C neu no dang tao datafiles hoac config instance.
```

Ket qua thuc te 2026-05-27: lan dau chay dung `-diskGroupName DATA -recoveryAreaDestination FRA` bi loi:

```text
[FATAL] [DBT-06007] The specified location (FRA Location) is invalid.
CAUSE: The specified location is not found on the system or is detected to be a file.
```

Nguyen nhan:

```text
Voi ASM, DBCA can ASM location co dau +.
Dung +DATA va +FRA, khong dung DATA/FRA tron.
```

Ket qua thuc te 2026-05-27 khi chay lai voi `+DATA/+FRA`:

```text
Prepare for db operation
7% complete
Copying database files
27% complete
Creating and starting Oracle instance
28% complete
31% complete
35% complete
37% complete
40% complete
Creating cluster database views
41% complete
53% complete
Completing Database Creation
57% complete
60% complete
100% complete
[FATAL] PRCR-1079 : Failed to start resource ora.racdb.db
CRS-5017: The resource action "ora.racdb.db start" encountered the following error:
ORA-03113: end-of-file on communication channel
Process ID: 152744
Session ID: 237 Serial number: 49870
CRS-2674: Start of 'ora.racdb.db' on 'rac1' failed
CRS-2632: There are no more servers to try to place resource 'ora.racdb.db' on that would satisfy its placement policy
```

Y nghia:

```text
DBCA da di toi 100%, nhung CRS khong start duoc database resource.
ORA-03113 chi la trieu chung ket noi bi cat. Nguyen nhan that nam trong alert log cua racdb1 hoac CRS oraagent trace.
Khong chay lai DBCA ngay. Phai inspect resource/log truoc.
```

Alert log thuc te tren `rac1`, user `oracle`:

```bash
tail -n 200 /u01/app/oracle/diag/rdbms/racdb/racdb1/trace/alert_racdb1.log
```

Doan quan trong:

```text
ALTER DATABASE MOUNT /* db agent */
SUCCESS: mounted group 2 (DATA)
SUCCESS: mounted group 3 (FRA)
IMR has experienced some problems during thread mount
No connectivity to other instances in the cluster during startup. Hence, LMON is terminating the instance.
LMON ... terminating the instance due to ORA error
Instance terminated by LMON
```

Ket luan:

```text
DB files/ASM access da OK: DATA va FRA mount thanh cong.
Loi nam o database RAC interconnect/LMON, khong phai ASM disk group.
Can ep database racdb dung private interconnect 10.10.10.11/10.10.10.12 bang cluster_interconnects, tuong tu fix ASM o Step 09.
```

Fix database interconnect tren `rac1`, user `oracle`:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=racdb1
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK

ls -l $ORACLE_HOME/dbs/initracdb1.ora $ORACLE_HOME/dbs/spfileracdb1.ora 2>&1
cat $ORACLE_HOME/dbs/initracdb1.ora 2>/dev/null
```

Mo instance toi NOMOUNT de sua SPFILE:

```bash
sqlplus / as sysdba
```

Trong SQL prompt:

```sql
startup nomount;
alter system set cluster_interconnects='10.10.10.11' scope=spfile sid='racdb1';
alter system set cluster_interconnects='10.10.10.12' scope=spfile sid='racdb2';
shutdown abort;
exit
```

Sau do thu start lai bang SQLPlus truoc khi dung CRS:

```bash
sqlplus / as sysdba
```

Trong SQL prompt:

```sql
startup;
select instance_name, status from v$instance;
show parameter cluster_interconnects
exit
```

Neu local `racdb1` start OK thi moi xu ly CRS resource/srvctl tiep.

Ket qua thuc te 2026-05-27: local DB home chua co `initracdb1.ora`, chi co health check file:

```text
$ORACLE_HOME/dbs/init.ora
$ORACLE_HOME/dbs/hc_racdb1.dat
```

Tim SPFILE trong ASM tren `rac1`, user `grid`:

```bash
asmcmd ls -l +DATA/RACDB
asmcmd ls -l +DATA/RACDB/PARAMETERFILE
asmcmd find +DATA/RACDB spfile*
```

Output:

```text
+DATA/RACDB/PARAMETERFILE/spfile.272.1234363849
```

Tao local pointer file tren `rac1`, user `oracle`:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=racdb1
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK

printf "%s\n" "SPFILE='+DATA/RACDB/PARAMETERFILE/spfile.272.1234363849'" > $ORACLE_HOME/dbs/initracdb1.ora
cat $ORACLE_HOME/dbs/initracdb1.ora
```

Verify startup NOMOUNT:

```bash
sqlplus / as sysdba
```

```sql
startup nomount;
show parameter spfile
```

Output:

```text
ORACLE instance started.
Total System Global Area 1610609888 bytes
spfile string +DATA/RACDB/PARAMETERFILE/spfile.272.1234363849
```

Set database interconnects trong SPFILE:

```sql
alter system set cluster_interconnects='10.10.10.11' scope=spfile sid='racdb1';
alter system set cluster_interconnects='10.10.10.12' scope=spfile sid='racdb2';
shutdown abort;
exit
```

Start lai local `racdb1` tren `rac1`, user `oracle`:

```bash
sqlplus / as sysdba
```

```sql
startup;
show parameter cluster_interconnects
select instance_name, status from v$instance;
```

Output:

```text
Database mounted.
Database opened.

cluster_interconnects string 10.10.10.11

INSTANCE_NAME STATUS
------------- ------------
racdb1        OPEN
```

Ket luan: `racdb1` da OPEN khi ep database interconnect dung private IP.

Tao local pointer file cho `racdb2` tren rac2:

```bash
# Tren rac1, user oracle:
scp $ORACLE_HOME/dbs/initracdb1.ora oracle@rac2:/tmp/initracdb2.ora

# Neu command dai bi xuong dong lam hong path, lam lai don gian:
ssh oracle@rac2 'mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1/dbs'
scp /tmp/initracdb2.ora oracle@rac2:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/initracdb2.ora
ssh oracle@rac2 'cat /u01/app/oracle/product/19.0.0/dbhome_1/dbs/initracdb2.ora'
```

Start `racdb2` tren `rac2`, user `oracle`:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=racdb2
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK
sqlplus / as sysdba
```

```sql
startup;
show parameter cluster_interconnects
select instance_name, status from v$instance;
```

Output thuc te:

```text
Database mounted.
Database opened.

cluster_interconnects string 10.10.10.12

INSTANCE_NAME STATUS
------------- ------------
racdb2        OPEN
```

Ket luan: ca `racdb1` va `racdb2` da OPEN thu cong sau khi set database interconnects.

Verify RAC instances tu SQL:

```sql
set lines 200
select inst_id, instance_name, host_name, status from gv$instance order by inst_id;
show pdbs
```

Output thuc te:

```text
INST_ID INSTANCE_NAME HOST_NAME STATUS
------- ------------- --------- ------------
1       racdb1        rac1      OPEN
2       racdb2        rac2      OPEN

PDB$SEED READ ONLY
```

Note: `PDB1` chua thay trong `show pdbs`; xu ly sau khi CRS resource on dinh.

### Register lai database resource voi srvctl

Vi DBCA fail o buoc CRS start va rollback resource, `srvctl status database -d racdb` bao:

```text
PRCD-1120 : The resource for database racdb could not be found.
PRCR-1001 : Resource ora.racdb.db does not exist
```

Can add lai resource bang `srvctl add database` va `srvctl add instance`.
Oracle docs: `srvctl add database` register database vao Oracle Clusterware voi `-oraclehome`, `-spfile`, `-pwfile`, `-dbtype RAC`; `srvctl add instance` map instance vao node.

Tim password file trong ASM tren `rac1`, user `grid`:

```bash
asmcmd ls -l +DATA/RACDB/PASSWORD
asmcmd find +DATA/RACDB/PASSWORD '*'
```

Register resource tren `rac1`, user `oracle`:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

srvctl add database \
  -db racdb \
  -dbname racdb \
  -oraclehome /u01/app/oracle/product/19.0.0/dbhome_1 \
  -spfile +DATA/RACDB/PARAMETERFILE/spfile.272.1234363849 \
  -pwfile <ASM_PASSWORD_FILE_PATH> \
  -dbtype RAC \
  -diskgroup "DATA,FRA" \
  -role PRIMARY \
  -startoption OPEN \
  -stopoption IMMEDIATE \
  -policy AUTOMATIC

srvctl add instance -db racdb -instance racdb1 -node rac1
srvctl add instance -db racdb -instance racdb2 -node rac2

srvctl config database -d racdb
srvctl status database -d racdb
```

Thay `<ASM_PASSWORD_FILE_PATH>` bang output thuc te tu `asmcmd find`, thuong la dang:

```text
+DATA/RACDB/PASSWORD/pwdracdb.xxx.xxxxxxxxxx
```

Ket qua thuc te 2026-05-27:

```text
Password file: +DATA/RACDB/PASSWORD/pwdracdb.256.1234363179
```

Lenh da chay tren `rac1`, user `oracle`:

```bash
srvctl add database -db racdb -dbname racdb -oraclehome /u01/app/oracle/product/19.0.0/dbhome_1 -spfile +DATA/RACDB/PARAMETERFILE/spfile.272.1234363849 -pwfile +DATA/RACDB/PASSWORD/pwdracdb.256.1234363179 -dbtype RAC -diskgroup "DATA,FRA" -role PRIMARY -startoption OPEN -stopoption IMMEDIATE -policy AUTOMATIC
srvctl add instance -db racdb -instance racdb1 -node rac1
srvctl add instance -db racdb -instance racdb2 -node rac2
srvctl config database -d racdb
```

Output `srvctl config database -d racdb`:

```text
Database unique name: racdb
Database name: racdb
Oracle home: /u01/app/oracle/product/19.0.0/dbhome_1
Oracle user: oracle
Spfile: +DATA/RACDB/PARAMETERFILE/spfile.272.1234363849
Password file: +DATA/RACDB/PASSWORD/pwdracdb.256.1234363179
Start options: open
Stop options: immediate
Database role: PRIMARY
Management policy: AUTOMATIC
Disk Groups: DATA,FRA
Type: RAC
OSDBA group: dba
OSOPER group: oper
Database instances: racdb1,racdb2
Configured nodes: rac1,rac2
Database is administrator managed
```

Theo doi log neu can:

```bash
ls -lt /u01/app/oracle/cfgtoollogs/dbca/racdb 2>/dev/null | head
find /u01/app/oracle/cfgtoollogs/dbca -type f -name '*.log' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -10
```

## 6. Verify database resource bang srvctl

Chay tren `rac1`, user `oracle`:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

srvctl config database -d racdb
srvctl status database -d racdb
srvctl status instance -d racdb -i racdb1
srvctl status instance -d racdb -i racdb2
```

Expected:

```text
Database unique name: racdb
Database is running.
Instance racdb1 is running on node rac1
Instance racdb2 is running on node rac2
```

Ket qua thuc te 2026-05-27 sau khi register lai resource:

```bash
srvctl start database -d racdb
srvctl status database -d racdb
```

Output:

```text
Instance racdb1 is running on node rac1
Instance racdb2 is running on node rac2
```

## 7. Verify SQL connect va instance names

Chay tren `rac1`, user `oracle`:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_SID=racdb1

sqlplus / as sysdba
```

Trong SQL prompt:

```sql
set lines 200
select inst_id, instance_name, host_name, status from gv$instance order by inst_id;
show pdbs
exit
```

Expected:

```text
racdb1 tren rac1 OPEN
racdb2 tren rac2 OPEN
PDB1 ton tai
```

Ket qua thuc te 2026-05-27:

```sql
select inst_id, instance_name, host_name, status from gv$instance order by inst_id;
select open_mode from v$database;
show pdbs
```

Output:

```text
INST_ID INSTANCE_NAME HOST_NAME STATUS
------- ------------- --------- ------------
1       racdb1        rac1      OPEN
2       racdb2        rac2      OPEN

OPEN_MODE
---------
READ WRITE

CON_ID CON_NAME  OPEN MODE  RESTRICTED
------ --------- ---------- ----------
2      PDB$SEED  READ ONLY  NO
```

Note: `PDB1` chua ton tai du command DBCA co `-pdbName pdb1`. Database RAC da READ WRITE tren ca 2 instances; co the tao PDB sau bang SQL neu can.

## 8. Verify cluster resources

Chay tren `rac1`, user `grid`:

```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
export PATH=$ORACLE_HOME/bin:$PATH

crsctl stat res -t | grep -E 'racdb|DATA|FRA|ora.asm|ora.LISTENER|ora.scan'
```

Expected:

```text
ora.racdb.db ONLINE
ora.DATA.dg ONLINE
ora.FRA.dg ONLINE
ASM/listener/SCAN resources online
```

Ket qua thuc te 2026-05-27:

```bash
crsctl stat res ora.racdb.db -t
crsctl stat res ora.DATA.dg -t
crsctl stat res ora.FRA.dg -t
```

Output:

```text
ora.racdb.db
  1 ONLINE ONLINE rac1 Open,HOME=/u01/app/oracle/product/19.0.0/dbhome_1,STABLE
  2 ONLINE ONLINE rac2 Open,HOME=/u01/app/oracle/product/19.0.0/dbhome_1,STABLE

ora.DATA.dg
  1 ONLINE ONLINE rac1 STABLE
  2 ONLINE ONLINE rac2 STABLE

ora.FRA.dg
  1 ONLINE ONLINE rac1 STABLE
  2 ONLINE ONLINE rac2 STABLE
```

## 9. Common DBCA fixes

### DATA/FRA not mounted

Kiem tra tren `rac1`, user `grid`:

```bash
asmcmd lsdg
crsctl stat res -t | grep -E 'DATA|FRA|OCRVOTE'
```

Neu DATA/FRA khong mounted, mount thu:

```bash
sqlplus / as sysasm
```

```sql
ALTER DISKGROUP DATA MOUNT;
ALTER DISKGROUP FRA MOUNT;
exit
```

### DBCA memory fail

Dung lai command DBCA, giam:

```text
-totalMemory 1536
```

### DBCA bao SSH/user equivalence fail

Chay lai verify tren `rac1`, user `oracle`:

```bash
ssh -o BatchMode=yes oracle@rac2 hostname
ssh -o BatchMode=yes oracle@rac2 "ssh -o BatchMode=yes oracle@rac1 hostname"
```

## 10. Done criteria

```text
DBCA createDatabase completed successfully
srvctl status database -d racdb: running on rac1/rac2
gv$instance thay racdb1 va racdb2 OPEN
Database READ WRITE
crsctl stat res -t co ora.racdb.db ONLINE
```

Step 11 status 2026-05-27: DONE.

```text
RAC database active-active da chay:
  racdb1 OPEN tren rac1
  racdb2 OPEN tren rac2
  database READ WRITE
  ora.racdb.db ONLINE tren ca hai node
  DATA/FRA ONLINE tren ca hai node

Known note:
  PDB1 chua ton tai; DBCA chi tao CDB root + PDB$SEED trong lan nay.
  Neu can PDB app, tao PDB rieng sau khi cluster on dinh.
```
