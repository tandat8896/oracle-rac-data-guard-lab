# RAC Quick Reference - Env Vars va Startup Checklist

## Danh sach tai khoan Oracle

| User | Container | Password | Dung cho |
|------|-----------|----------|----------|
| SYS | CDB$ROOT / PDB1 | <REDACTED_PASSWORD> | DBA, admin |
| PDBADMIN | PDB1 | <REDACTED_PASSWORD> | PDB admin |
| HR | PDB1 | <REDACTED_PASSWORD> | Sample schema HR |
| QUERY_TUNING | PDB1 | Tuning123 | Hoc query tuning |

---

## SSH toi VMs tu NixOS host

```bash
# rac1
ssh -p 2222 -i ~/.ssh/rac_ed25519 tandat8896@192.168.122.205

# rac2
ssh -p 2222 -i ~/.ssh/rac_ed25519 tandat8896@192.168.122.46

# stdby1 (Data Guard standby, port 22, chua setup SSH key)
ssh tandat@192.168.122.50
```

| VM | IP | Vai tro |
|----|-----|---------|
| rac1 | 192.168.122.205 | RAC node 1, primary |
| rac2 | 192.168.122.46 | RAC node 2, primary |
| stdby1 | 192.168.122.50 | Data Guard standby (single instance) |

Switch user:
```bash
sudo su - grid
sudo su - oracle
```

---

## User grid

Dung cho: CRS, ASM, cluster management.
Tools: crsctl, asmcmd, srvctl (cluster-level), sqlplus as sysasm.

Env vars tren rac1:
```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
export ORACLE_SID=+ASM1
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK
```

Env vars tren rac2:
```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
export ORACLE_SID=+ASM2
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK
```

### Kiem tra grid (chay tren rac1)

```bash
# Cluster status ca 2 node
crsctl check cluster -all

# ASM running tren node nao
srvctl status asm

# Disk groups mounted chua
asmcmd lsdg

# Tat ca cluster resources - xem kien truc toan bo
crsctl stat res -t

# Connect ASM de kiem tra ben trong
sqlplus / as sysasm
```

Giai thich output `crsctl stat res -t`:

Local Resources — chay rieng tren tung node, khong failover:
```text
ora.LISTENER.lsnr       TNS listener nhan ket noi tu client
ora.chad                Cluster Health Advisor, monitor node health
ora.net1.network        public network interface
ora.ons                 Oracle Notification Service — bao client khi instance die (Fast Application Notification)
```

Cluster Resources — CRS quan ly, co the failover qua node khac:
```text
ora.ASMNET1LSNR_ASM.lsnr   listener rieng cho ASM-to-ASM internal communication
ora.DATA.dg / ora.FRA.dg   ASM disk groups, CRS dam bao luon MOUNTED
ora.OCRVOTE.dg             disk group chua OCR va Voting disk
ora.asm                    ASM instances (1=rac1, 2=rac2)
ora.asmnet1.asmnetwork     private network dung cho ASM
ora.LISTENER_SCAN1.lsnr    SCAN listener, diem vao duy nhat cho client
ora.scan1.vip              SCAN VIP address (192.168.122.213)
ora.rac1.vip               VIP cua rac1 (192.168.122.211) — failover sang rac2 neu rac1 die
ora.rac2.vip               VIP cua rac2 (192.168.122.212) — failover sang rac1 neu rac2 die
ora.racdb.db               RAC database resource, 2 instances
ora.cvu                    Cluster Verification Utility daemon
ora.qosmserver             Quality of Service Management
```

Luong ket noi client vao RAC:
```text
Client
  → SCAN listener (ora.LISTENER_SCAN1.lsnr) tren SCAN VIP
  → CRS redirect toi rac1 hoac rac2 tuy load balancing
  → VIP cua node duoc chon (ora.rac1.vip hoac ora.rac2.vip)
  → instance racdb1 hoac racdb2

Tai sao dung SCAN thay vi IP truc tiep:
  Client chi can biet 1 SCAN name, khong can biet IP cua tung node.
  Khi them/bot node, client khong can doi config.
```

Tai sao co hang "3 OFFLINE OFFLINE":
```text
Grid cai voi toi da 3 nodes nhung lab chi co 2.
Slot thu 3 ton tai trong config nhung khong co node vat ly.
Binh thuong, khong can xu ly.
```

SQL trong sysasm:
```sql
-- Disk groups: name, state, free space
select name, state, total_mb, free_mb from v$asm_diskgroup order by 1;

-- ASM parameters
show parameter cluster_interconnects

-- ASM instances ca 2 node
select inst_id, instance_name, status from gv$instance order by 1;

exit
```

---

## User oracle

Dung cho: database management, sqlplus sysdba, DBCA, srvctl (database-level).
Tools: sqlplus as sysdba, srvctl, dbca.
KHONG dung: asmcmd (cua grid), crsctl (cua grid).

Env vars tren rac1:
```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=racdb1
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK
```

Env vars tren rac2:
```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=racdb2
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK
```

Tai sao `unset TWO_TASK`:
```text
TWO_TASK force sqlplus ket noi qua listener thay vi local IPC.
Neu con set: ORA-12162 hoac ORA-12154.
```

### Cach dang nhap SQLcl / SQL*Plus

OS authentication (khong can listener, nhanh nhat):
```bash
sql / as sysdba
sqlplus / as sysdba
```

Connect den CDB hoac PDB cu the qua listener:
```bash
# CDB root (SYS)
sql sys/"<REDACTED_PASSWORD>"@rac1:1521/racdb.localdomain as sysdba

# PDB1 (SYS)
sql sys/"<REDACTED_PASSWORD>"@rac1:1521/pdb1.localdomain as sysdba

# PDB1 (HR user)
sql hr/<REDACTED_PASSWORD>@rac1:1521/pdb1.localdomain
```

Tai sao dung `rac1` khong phai `localhost`:
```text
Listener RAC chi listen tren node IP (192.168.122.205) va VIP (192.168.122.211).
Dung localhost bi: IO Error: The Network Adapter could not establish the connection.
```

Xem cac services listener dang serve:
```bash
lsnrctl status | grep Service
```

Switch container sau khi da connect (khong tao connection moi):
```sql
alter session set container=pdb1;
show con_name

-- Quay lai CDB:
alter session set container=CDB$ROOT;
```

### Kiem tra database (chay tren rac1)

```bash
# Database resource status (khong can sqlplus)
srvctl status database -d racdb
srvctl status instance -d racdb -i racdb1
srvctl status instance -d racdb -i racdb2
srvctl config database -d racdb

# Connect database
sqlplus / as sysdba
```

SQL trong sysdba:
```sql
-- Instances ca 2 node
select inst_id, instance_name, host_name, status from gv$instance order by 1;

-- Database open mode va archive log mode
select name, open_mode, log_mode from v$database;

-- Tablespace status
select tablespace_name, status from dba_tablespaces order by 1;

-- Datafile status
select file#, status, name from v$datafile order by 1;

-- Redo log status ca 2 node
select inst_id, group#, status, bytes/1024/1024 MB from gv$log order by 1,2;

-- ASM disk groups (nhin tu DB, khong can sysasm)
select group_number, name, state, total_mb, free_mb from v$asm_diskgroup order by 1;

-- Active user sessions ca 2 node
select inst_id, count(*) sessions from gv$session where type='USER' group by inst_id;

exit
```

Alert log khi co loi:
```bash
# rac1
tail -50 /u01/app/oracle/diag/rdbms/racdb/racdb1/trace/alert_racdb1.log

# rac2
tail -50 /u01/app/oracle/diag/rdbms/racdb/racdb2/trace/alert_racdb2.log
```

---

## Oracle Wallet — dang nhap khong can nhap password

Lam 1 lan tren tung node (rac1 va rac2). Thay `mkcuaban` bang password thuc.

### Buoc 1: Tao wallet directory

```bash
mkdir -p ~/.oracle_wallet/query_tuning
chmod 700 ~/.oracle_wallet/query_tuning
```

### Buoc 2: Tao wallet (se hoi dat password cho wallet)

```bash
mkstore -wrl ~/.oracle_wallet/query_tuning -create
```

### Buoc 3: Them credential vao wallet

```bash
mkstore -wrl ~/.oracle_wallet/query_tuning -createCredential PDB1 query_tuning 'mkcuaban'
```

Kiem tra credential da luu:
```bash
mkstore -wrl ~/.oracle_wallet/query_tuning -listCredential
```

### Buoc 4: Tao sqlnet.ora

```bash
cat > ~/.oracle_wallet/query_tuning/sqlnet.ora << 'EOF'
WALLET_LOCATION =
  (SOURCE =
    (METHOD = FILE)
    (METHOD_DATA =
      (DIRECTORY = /home/oracle/.oracle_wallet/query_tuning)
    )
  )
SQLNET.WALLET_OVERRIDE = TRUE
EOF
```

### Buoc 5: Tao tnsnames.ora

Tren rac1 (HOST = rac1):
```bash
cat > ~/.oracle_wallet/query_tuning/tnsnames.ora << 'EOF'
PDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac1)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = pdb1.localdomain)
    )
  )
EOF
```

Tren rac2 (HOST = rac2):
```bash
cat > ~/.oracle_wallet/query_tuning/tnsnames.ora << 'EOF'
PDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac2)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = pdb1.localdomain)
    )
  )
EOF
```

### Buoc 6: Them TNS_ADMIN vao bash_profile

```bash
echo "export TNS_ADMIN=/home/oracle/.oracle_wallet/query_tuning" >> ~/.bash_profile
source ~/.bash_profile
```

### Dang nhap sau khi setup xong

```bash
sqlplus /@PDB1
# hoac
sql /@PDB1
```

---

## Startup checklist sau khi boot VM

CRS tu dong khoi dong moi thu sau boot. Cho 2-3 phut roi kiem tra theo thu tu.

| Buoc | User | Lenh | Expected |
|------|------|------|----------|
| 1 | grid | `crsctl check cluster -all` | CRS/CSS/EVM online tren ca 2 node |
| 2 | grid | `srvctl status asm` | ASM running on rac1,rac2 |
| 3 | grid | `asmcmd lsdg` | DATA/FRA/OCRVOTE MOUNTED |
| 4 | oracle | `srvctl status database -d racdb` | racdb1/racdb2 running |
| 5 | oracle | `sqlplus / as sysdba` → `select ... from gv$instance` | racdb1/racdb2 OPEN |
