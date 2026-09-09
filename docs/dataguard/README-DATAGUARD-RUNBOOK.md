# Oracle EE Data Guard runbook

Muc tieu: tao physical standby cho lab 2 container:

```text
Primary container:  oraee-dg-primary
Standby container:  oraee-dg-standby
Image:              oraee-dg:23.26.1.0
CDB/SID:            ORCLCDB
PDB:                ORCLPDB1
Primary unique:     ORCLCDB_PRIMARY
Standby unique:     ORCLCDB_STANDBY
Network:            oraee-dg-net
```

File nay viet theo kieu thao tac tay:
- Tren host thi chay `podman ...`.
- Vao container roi thi go lenh ben trong container.
- Vao SQLPlus/RMAN roi thi paste lenh SQL/RMAN rieng.

Khong ghi password that vao file.

## 1. Check container hien co

Chay tren host:

```bash
podman ps --filter name=oraee-dg
podman volume ls | grep oraee-dg
podman network ls | grep oraee-dg
```

Can co:

```text
oraee-dg-primary
oraee-dg-standby
oraee-dg-primary-data
oraee-dg-standby-data
oraee-dg-net
```

Check TCP hai chieu:

```bash
podman exec -it oraee-dg-primary bash
```

Trong primary container:

```bash
timeout 5 bash -c "</dev/tcp/oraee-dg-standby/1521" && echo standby-1521-ok
exit
```

Chay tren host:

```bash
podman exec -it oraee-dg-standby bash
```

Trong standby container:

```bash
timeout 5 bash -c "</dev/tcp/oraee-dg-primary/1521" && echo primary-1521-ok
exit
```

## 2. Tao TNS aliases va static listener

Lam tren primary truoc.

Chay tren host:

```bash
podman exec -it oraee-dg-primary bash
```

Trong primary container:

```bash
cat > /opt/oracle/oradata/dbconfig/ORCLCDB/tnsnames.ora <<'EOF'
PRIMARY_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oraee-dg-primary)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = ORCLCDB)
    )
  )

STANDBY_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oraee-dg-standby)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = ORCLCDB)
    )
  )
EOF
```

```bash
cat > /opt/oracle/oradata/dbconfig/ORCLCDB/listener.ora <<'EOF'
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ORCLCDB)
      (ORACLE_HOME = /opt/oracle/product/26ai/dbhome_1)
      (SID_NAME = ORCLCDB)
    )
  )

DEDICATED_THROUGH_BROKER_LISTENER=ON
DIAG_ADR_ENABLED = off
EOF
```

```bash
lsnrctl reload
tnsping PRIMARY_DG
tnsping STANDBY_DG
exit
```

Lam lai y chang tren standby.

Chay tren host:

```bash
podman exec -it oraee-dg-standby bash
```

Trong standby container, paste lai 3 block tren:

```bash
cat > /opt/oracle/oradata/dbconfig/ORCLCDB/tnsnames.ora <<'EOF'
PRIMARY_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oraee-dg-primary)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = ORCLCDB)
    )
  )

STANDBY_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = oraee-dg-standby)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = ORCLCDB)
    )
  )
EOF
```

```bash
cat > /opt/oracle/oradata/dbconfig/ORCLCDB/listener.ora <<'EOF'
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = 0.0.0.0)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ORCLCDB)
      (ORACLE_HOME = /opt/oracle/product/26ai/dbhome_1)
      (SID_NAME = ORCLCDB)
    )
  )

DEDICATED_THROUGH_BROKER_LISTENER=ON
DIAG_ADR_ENABLED = off
EOF
```

```bash
lsnrctl reload
tnsping PRIMARY_DG
tnsping STANDBY_DG
exit
```

## 3. Chuan bi primary

Chay tren host:

```bash
podman exec -it oraee-dg-primary bash
```

Trong primary container:

```bash
sqlplus / as sysdba
```

Trong SQLPlus:

```sql
alter system set db_unique_name='ORCLCDB_PRIMARY' scope=spfile;
alter system set log_archive_config='DG_CONFIG=(ORCLCDB_PRIMARY,ORCLCDB_STANDBY)' scope=both;
alter database force logging;

select name, db_unique_name, database_role, open_mode, log_mode, force_logging
from v$database;

exit
```

Thoat container:

```bash
exit
```

Restart primary de `db_unique_name` co hieu luc.

Chay tren host:

```bash
podman restart oraee-dg-primary
podman logs -f oraee-dg-primary
```

Khi thay ready thi `Ctrl+C`:

```text
DATABASE IS READY TO USE!
DB is in good health on startup
```

## 4. Them standby redo logs tren primary

Chay tren host:

```bash
podman exec -it oraee-dg-primary bash
```

Trong primary container:

```bash
sqlplus / as sysdba
```

Trong SQLPlus:

```sql
select group#, bytes/1024/1024 size_mb
from v$log
order by group#;

select group#, bytes/1024/1024 size_mb, status
from v$standby_log
order by group#;
```

Neu chua co standby redo logs, them:

```sql
alter database add standby logfile size 200M;
alter database add standby logfile size 200M;
alter database add standby logfile size 200M;
alter database add standby logfile size 200M;

select group#, bytes/1024/1024 size_mb, status
from v$standby_log
order by group#;

exit
```

Thoat container:

```bash
exit
```

## 5. Chuan bi standby NOMOUNT

Canh bao: buoc nay xoa database doc lap trong volume standby. Chi lam tren `oraee-dg-standby`.

Chay tren host:

```bash
podman exec -it oraee-dg-standby bash
```

Trong standby container:

```bash
sqlplus / as sysdba
```

Trong SQLPlus:

```sql
alter system set db_unique_name='ORCLCDB_STANDBY' scope=spfile;
alter system set log_archive_config='DG_CONFIG=(ORCLCDB_PRIMARY,ORCLCDB_STANDBY)' scope=both;
alter system set fal_server='PRIMARY_DG' scope=both;
shutdown immediate;
exit
```

Van trong standby container, xoa data cu va tao folder rong:

```bash
find /opt/oracle/oradata/ORCLCDB -mindepth 1 -maxdepth 1 -exec rm -rf {} +
mkdir -p \
  /opt/oracle/oradata/ORCLCDB/controlfile \
  /opt/oracle/oradata/ORCLCDB/datafile \
  /opt/oracle/oradata/ORCLCDB/onlinelog \
  /opt/oracle/oradata/ORCLCDB/archive_logs
```

Startup NOMOUNT:

```bash
sqlplus / as sysdba
```

Trong SQLPlus:

```sql
startup nomount;

select status, instance_name
from v$instance;

show parameter db_unique_name;
show parameter fal_server;

exit
```

De nguyen shell standby hoac thoat:

```bash
exit
```

## 6. Test remote SYSDBA toi standby NOMOUNT

Chay tren host:

```bash
podman exec -it oraee-dg-primary bash
```

Trong primary container:

```bash
echo "exit" | sqlplus -L sys/"$ORACLE_PWD"@STANDBY_DG as sysdba
```

Neu connect OK thi tiep tuc.

Thoat container:

```bash
exit
```

## 7. RMAN duplicate

Chay tren host:

```bash
podman exec -it oraee-dg-primary bash
```

Trong primary container:

```bash
rman target sys/"$ORACLE_PWD"@PRIMARY_DG auxiliary sys/"$ORACLE_PWD"@STANDBY_DG
```

Trong RMAN:

```rman
DUPLICATE TARGET DATABASE
  FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  NOFILENAMECHECK;
```

Thanh cong thi thay:

```text
Finished Duplicate Db
```

Thoat RMAN:

```rman
exit
```

Thoat container:

```bash
exit
```

## 8. Cau hinh redo transport

### 8.1. Primary

Chay tren host:

```bash
podman exec -it oraee-dg-primary bash
```

Trong primary container:

```bash
sqlplus / as sysdba
```

Trong SQLPlus:

```sql
alter system set log_archive_dest_1='LOCATION=/opt/oracle/oradata/ORCLCDB/archive_logs VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=ORCLCDB_PRIMARY' scope=both;
alter system set log_archive_dest_2='SERVICE=STANDBY_DG ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=ORCLCDB_STANDBY' scope=both;
alter system set log_archive_dest_state_2=enable scope=both;
alter system set fal_server='STANDBY_DG' scope=both;

exit
```

Thoat container:

```bash
exit
```

### 8.2. Standby

Chay tren host:

```bash
podman exec -it oraee-dg-standby bash
```

Trong standby container:

```bash
sqlplus / as sysdba
```

Trong SQLPlus:

```sql
alter system set log_archive_dest_1='LOCATION=/opt/oracle/oradata/ORCLCDB/archive_logs VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=ORCLCDB_STANDBY' scope=both;
alter system set log_archive_dest_2='SERVICE=PRIMARY_DG ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=ORCLCDB_PRIMARY' scope=both;
alter system set log_archive_dest_state_2=enable scope=both;
alter system set fal_server='PRIMARY_DG' scope=both;

alter database recover managed standby database using current logfile disconnect from session;

exit
```

Thoat container:

```bash
exit
```

## 9. Test standby co apply that khong

Ep primary tao redo moi.

Chay tren host:

```bash
podman exec -it oraee-dg-primary bash
```

Trong primary container:

```bash
sqlplus / as sysdba
```

Trong SQLPlus:

```sql
alter system archive log current;

select dest_id, status, type, database_mode, recovery_mode, destination, error
from v$archive_dest_status
where dest_id in (1,2);

exit
```

Thoat container:

```bash
exit
```

Check standby.

Chay tren host:

```bash
podman exec -it oraee-dg-standby bash
```

Trong standby container:

```bash
sqlplus / as sysdba
```

Trong SQLPlus:

```sql
set pages 100 lines 200

select name, db_unique_name, database_role, open_mode, log_mode
from v$database;

select process, status, sequence#, thread#
from v$managed_standby
order by process;

select name, value, time_computed
from v$dataguard_stats
where name in ('transport lag','apply lag');

select thread#, sequence#, applied
from v$archived_log
order by sequence# desc fetch first 10 rows only;

exit
```

Dung thi thay:

```text
DATABASE_ROLE  PHYSICAL STANDBY
OPEN_MODE      MOUNTED
MRP0           APPLYING_LOG
transport lag  +00 00:00:00
apply lag      +00 00:00:00
```

Thoat container:

```bash
exit
```

### 9.1. Bug da fix: standby_file_management

Bug nay minh da gap khi check tren standby:

```sql
show parameter standby_file_management;
```

Co luc no hien:

```text
standby_file_management string MANUAL
```

Trong khi primary da set:

```sql
alter system set standby_file_management=auto scope=both;
```

Fix tren standby:

```sql
alter system set standby_file_management=auto scope=both;
show parameter standby_file_management;
```

Ket qua dung:

```text
standby_file_management string AUTO
```

Luu y:
- `standby_file_management` can duoc set rieng tren standby.
- Neu standby van o `MANUAL`, file/them tablespace/co the khong tu dong dong bo nhu mong doi.

## 10. Healthcheck Podman

`oraee-dg-standby` co the hien `unhealthy` trong `podman ps`. Neu database-level check o muc 9 dung thi standby van dang on.

Ly do: healthcheck mac dinh cua image thuong mong database open/read-write. Physical standby thi binh thuong la `MOUNTED`.

Check health raw:

```bash
podman inspect oraee-dg-standby --format '{{json .Config.Healthcheck}}'
podman inspect oraee-dg-standby --format '{{json .State.Health}}'
```

Neu muon sua dep healthcheck, tao lai standby container voi healthcheck rieng cho standby. Chua lam trong runbook nay de tranh pha container dang chay tot.

## 11. Bug da gap

### Query heredoc bi loi ORA-00911

Sai ngu canh quote co the lam SQLPlus nhan `v\$database`, dan toi:

```text
ORA-00911: invalid character
```

Khi da vao SQLPlus truc tiep, dung:

```sql
select * from v$database;
```

Khong dung:

```sql
select * from v\$database;
```

### `v$archive_dest_status` khong co cot TARGET

Loi:

```text
ORA-00904: "TARGET": invalid identifier
```

Dung query nay:

```sql
select dest_id, status, type, database_mode, recovery_mode, destination, error
from v$archive_dest_status
where dest_id in (1,2);
```

### `ping` fail trong rootless Podman

Loi:

```text
ping: socket: Operation not permitted
```

Dung TCP check thay the:

```bash
timeout 5 bash -c "</dev/tcp/oraee-dg-standby/1521" && echo standby-1521-ok
timeout 5 bash -c "</dev/tcp/oraee-dg-primary/1521" && echo primary-1521-ok
```

### LGWR/VKTM priority warning trong attention log

Warning da gap:

```text
The priority of process LGWR cannot be elevated.
The priority of process VKTM cannot be elevated.
ErrMsg(Operation not permitted)
```

Nguyen nhan trong lab nay:
- Oracle muon nang priority cho background process nhu `LGWR` va `VKTM`.
- Rootless Podman/container khong co du quyen scheduling/capability de lam viec nay.
- Day la gioi han container permission, khong phai bang chung Data Guard hong.

Kiem tra database-level truoc khi quyet dinh fix:

```sql
select name, database_role, open_mode, log_mode
from v$database;

select process, status, sequence#, thread#
from v$managed_standby
order by process;

select name, value
from v$dataguard_stats
where name in ('transport lag','apply lag');
```

Neu role/apply/lag dung thi co the de warning nay nhu known warning cho homelab.

Muon fix that thi phai tao lai container voi capability/ulimit phu hop. Huong Oracle RAC on Podman co dung cac option kieu:

```bash
--cap-add=SYS_NICE
--cap-add=SYS_RESOURCE
--ulimit rtprio=99
```

Nhung khong ap dung nong vao container dang chay duoc. Neu muon thu, tao lab moi rieng, vi rootless Podman co the van khong cho realtime scheduling day du.

So sanh voi VM Oracle Linux:
- VM/RPM/preinstall da xu ly OS-level setup tot hon: user/group, limits, root-owned/setuid binaries nhu `oradism`, service wrapper.
- Vi vay VM Oracle Linux la huong sach hon neu muon gan voi cai dat Oracle server truyen thong.
- Container EE Data Guard hien tai giu de hoc Data Guard/RMAN/redo, khong nen recreate chi de xoa warning nay.

---

## DataGuard Broker — DGMGRL

### Setup broker (chay 1 lan)

Tren ca primary va standby:
```sql
ALTER SYSTEM SET DG_BROKER_START=TRUE;
```

Vao container primary, chay dgmgrl:
```bash
podman exec -it oraee-dg-primary bash
dgmgrl /
```

Tao configuration:
```
CREATE CONFIGURATION lab_dg AS
  PRIMARY DATABASE IS ORCLCDB_PRIMARY
  CONNECT IDENTIFIER IS PRIMARY_DG;

ADD DATABASE ORCLCDB_STANDBY AS
  CONNECT IDENTIFIER IS STANDBY_DG;

ENABLE DATABASE ORCLCDB_PRIMARY;
ENABLE DATABASE ORCLCDB_STANDBY;
ENABLE CONFIGURATION;
```

Verify:
```
SHOW CONFIGURATION;
-- Configuration Status: SUCCESS
```

### Cac lenh DGMGRL thuong dung

```
-- Xem trang thai tong quan
SHOW CONFIGURATION;

-- Xem chi tiet tung database
SHOW DATABASE VERBOSE ORCLCDB_PRIMARY;
SHOW DATABASE VERBOSE ORCLCDB_STANDBY;

-- Xem lag
SHOW DATABASE ORCLCDB_STANDBY;

-- Switchover (primary -> standby, standby -> primary)
SWITCHOVER TO ORCLCDB_STANDBY;

-- Failover (khi primary chet, khong the switchover)
FAILOVER TO ORCLCDB_STANDBY;

-- Tat/bat MRP tren standby
EDIT DATABASE ORCLCDB_STANDBY SET STATE='APPLY-OFF';
EDIT DATABASE ORCLCDB_STANDBY SET STATE='ONLINE';
```

### Protection Mode

```
-- Xem mode hien tai
SHOW CONFIGURATION;
-- MaxPerformance (default): async redo transport, best performance

-- Doi sang MaxAvailability: sync redo, zero data loss (can LGWR SYNC)
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;

-- Doi sang MaxProtection: primary dung neu standby mat lien lac
EDIT CONFIGURATION SET PROTECTION MODE AS MAXPROTECTION;
```
