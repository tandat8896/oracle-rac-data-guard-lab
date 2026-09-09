# Step 13 - Safe Shutdown RAC Lab

Muc tieu: tat RAC lab an toan, tranh cat dien VM khi database/ASM dang ghi.

Thu tu dung:

```text
1. Stop database racdb bang srvctl
2. Stop cluster/grid tren ca hai node
3. Shutdown OS tren rac1/rac2
4. Chi dung virsh shutdown tu host neu OS shutdown chua tat VM
```

Khong lam:

```text
Khong tat VM truc tiep bang virsh destroy khi DB/ASM con chay.
Khong shutdown host NixOS khi VM con running.
Khong stop ASM truoc database.
```

## 1. Stop RAC database

Chay tren `rac1`, user `oracle`:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

srvctl stop database -d racdb -stopoption immediate
srvctl status database -d racdb
```

Expected:

```text
Instance racdb1 is not running on node rac1
Instance racdb2 is not running on node rac2
```

Ghi chu:

```text
-stopoption immediate la shutdown database sach, rollback active transaction, disconnect sessions.
Tot cho lab shutdown.
```

## 2. Stop Grid/Cluster

Chay tren `rac1`, user `tandat8896`:

```bash
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
```

Verify:

```bash
sudo /u01/app/19.0.0/grid/bin/crsctl check cluster -all
```

Expected:

```text
CRS/CSS/EVM not running hoac offline tren rac1/rac2.
Day la OK sau khi stop cluster.
```

Neu command stop cluster bao resource busy, kiem tra database da stop chua:

```bash
sudo -u oracle /u01/app/oracle/product/19.0.0/dbhome_1/bin/srvctl status database -d racdb
```

## 3. Shutdown OS tren ca hai node

Chay tren `rac1`, user `tandat8896`:

```bash
sudo shutdown -h now
```

Chay tren `rac2`, user `tandat8896`:

```bash
sudo shutdown -h now
```

Sau lenh nay SSH se disconnect. Do la binh thuong.

## 4. Verify tu host NixOS

Chay tren host NixOS, user `tandat`:

```bash
virsh --connect qemu:///system list --all
```

Expected:

```text
rac1 shut off
rac2 shut off
```

Neu VM van running sau khi da shutdown OS, dung graceful shutdown tu host:

```bash
virsh --connect qemu:///system shutdown rac1
virsh --connect qemu:///system shutdown rac2
```

Cho vai giay roi verify lai:

```bash
virsh --connect qemu:///system list --all
```

## 5. Emergency only

Chi dung khi VM treo va `shutdown` khong co tac dung:

```bash
virsh --connect qemu:///system destroy rac1
virsh --connect qemu:///system destroy rac2
```

Can hieu ro:

```text
virsh destroy = cat dien VM.
Co nguy co dirty filesystem / ASM recovery lan boot sau.
Khong dung neu chi shutdown binh thuong.
```

## 6. Start lai lab sau khi shutdown

Chay tren host NixOS, user `tandat`:

```bash
virsh --connect qemu:///system start rac1
virsh --connect qemu:///system start rac2
```

Doi 1-3 phut, SSH vao `rac1`, user `grid` verify:

```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
export PATH=$ORACLE_HOME/bin:$PATH

crsctl check cluster -all
crsctl stat res -t
```

SSH vao `rac1`, user `oracle` verify DB:

```bash
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

srvctl status database -d racdb
```

Neu database khong tu start, start bang:

```bash
srvctl start database -d racdb
srvctl status database -d racdb
```

Verify SQL RAC active-active sau khi start:

```bash
export ORACLE_SID=racdb1
sqlplus / as sysdba
```

Trong SQL prompt:

```sql
set lines 200
select inst_id, instance_name, host_name, status from gv$instance order by inst_id;
select open_mode from v$database;
show pdbs
exit
```

Expected:

```text
racdb1 tren rac1 OPEN
racdb2 tren rac2 OPEN
v$database OPEN_MODE = READ WRITE
PDB$SEED READ ONLY
```

Note:

```text
Hien tai chua co PDB app rieng. Chi co CDB root va PDB$SEED.
Neu sau nay tao PDB1, can open/save state PDB1 rieng.
```

## Done criteria

```text
Database stopped before cluster stop
Cluster stopped before OS shutdown
rac1/rac2 show shut off tren host virsh
Khong dung virsh destroy trong shutdown binh thuong
```
