# RAC Commands - Kham Pha

---

## User grid

### crsctl - cluster control

```bash
crsctl check cluster -all
crsctl stat res -t
crsctl stat res -t -init
crsctl query css votedisk
crsctl query crs activeversion
crsctl query crs softwareversion
crsctl get css misscount
crsctl get css disktimeout
crsctl get css reboottime
```

### srvctl - resource control (cluster level)

```bash
srvctl status asm
srvctl config asm
srvctl status scan
srvctl config scan
srvctl status scan_listener
srvctl config scan_listener
srvctl status vip -n rac1
srvctl status vip -n rac2
srvctl config vip -n rac1
srvctl status listener
srvctl config listener
srvctl status nodeapps -n rac1
srvctl status nodeapps -n rac2
```

### asmcmd - ASM file browser

```bash
asmcmd lsdg
asmcmd lsdg --discovery
asmcmd lsdsk
asmcmd lsdsk --discovery
asmcmd ls +DATA
asmcmd ls +FRA
asmcmd ls +OCRVOTE
asmcmd ls -l +DATA/RACDB
asmcmd find +DATA RACDB '*'
asmcmd du +DATA
asmcmd du +FRA
asmcmd lsct
asmcmd lsod
asmcmd dsget
asmcmd spget
```

### olsnodes - node info

```bash
olsnodes
olsnodes -n
olsnodes -p
olsnodes -i
olsnodes -v
```

### oifcfg - network interface config

```bash
oifcfg getif
oifcfg iflist
oifcfg iflist -p -n
```

### cluvfy - cluster verification

```bash
cluvfy comp nodecon -n rac1,rac2
cluvfy comp nodereach -n rac1,rac2
cluvfy comp admprv -o user_equiv
cluvfy comp asm -n rac1,rac2
cluvfy stage -post crsinst -n rac1,rac2
```

### sqlplus as sysasm

```bash
sqlplus / as sysasm
```

```sql
select name, state, total_mb, free_mb from v$asm_diskgroup;
select group_number, name, path, state from v$asm_disk order by 1;
select inst_id, instance_name, status from gv$instance order by 1;
select * from v$asm_client;
select * from v$asm_operation;
show parameter cluster_interconnects;
show parameter asm_diskgroups;
show parameter asm_diskstring;
select * from v$asm_alias where group_number=1;
```

---

## User oracle

### srvctl - resource control (database level)

```bash
srvctl status database -d racdb
srvctl config database -d racdb
srvctl status instance -d racdb -i racdb1
srvctl status instance -d racdb -i racdb2
srvctl config instance -d racdb -i racdb1
srvctl status service -d racdb
srvctl config service -d racdb
srvctl getenv database -d racdb
```

### sqlplus as sysdba

```bash
sqlplus / as sysdba
```

```sql
-- RAC instances
select inst_id, instance_name, host_name, status, version from gv$instance order by 1;

-- Database info
select name, db_unique_name, open_mode, log_mode, created from v$database;

-- Parameters
show parameter cluster_interconnects;
show parameter db_name;
show parameter db_unique_name;
show parameter sga_target;
show parameter pga_aggregate_target;
show parameter processes;
show parameter sessions;
show parameter undo_tablespace;
show parameter log_archive_dest;

-- Tablespaces
select tablespace_name, status, contents, extent_management from dba_tablespaces;
select tablespace_name, bytes/1024/1024 MB_total, maxbytes/1024/1024 MB_max from dba_data_files;
select tablespace_name, bytes/1024/1024 MB_free from dba_free_space;

-- Datafiles va tempfiles
select file#, status, name from v$datafile;
select file#, status, name from v$tempfile;

-- Redo logs
select inst_id, group#, members, status, bytes/1024/1024 MB from gv$log order by 1,2;
select group#, member from v$logfile order by 1;

-- ASM tu DB
select group_number, name, state, total_mb, free_mb from v$asm_diskgroup;

-- Interconnect
select inst_id, name, ip_address from gv$cluster_interconnects order by 1;

-- Wait events hien tai
select inst_id, event, count(*) from gv$session_wait where wait_class != 'Idle' group by inst_id, event order by 3 desc;

-- Active sessions
select inst_id, username, status, sql_id, event from gv$session where type='USER' and status='ACTIVE';

-- Top SQL by elapsed time
select inst_id, sql_id, elapsed_time/1000000 sec, executions, substr(sql_text,1,60) from gv$sql order by elapsed_time desc fetch first 10 rows only;

-- PDBs (neu co)
show pdbs;
select con_id, name, open_mode from v$pdbs;

-- Undo
select inst_id, usn, status, rssize/1024/1024 MB from gv$rollstat order by 1,2;

-- Locks
select inst_id, sid, type, lmode, request from gv$lock where lmode > 0 order by 1;

-- Global cache (RAC specific)
select inst_id, gc_cr_blocks_received, gc_current_blocks_received from gv$sysstat where name like 'gc%' and inst_id=1;
select * from gv$gc_elements_with_collisions;
```

### RMAN

```bash
rman target /
```

```
show all;
report schema;
report need backup;
list backup summary;
list archivelog all;
crosscheck backup;
crosscheck archivelog all;
```

### Data Pump

```bash
# Export schema
expdp system/password schemas=SCOTT directory=DATA_PUMP_DIR dumpfile=scott.dmp logfile=scott_exp.log

# Import
impdp system/password schemas=SCOTT directory=DATA_PUMP_DIR dumpfile=scott.dmp logfile=scott_imp.log

# Xem jobs dang chay
select job_name, state, attached_sessions from dba_datapump_jobs;
```

### opatch - patch management

```bash
opatch lsinventory
opatch lsinventory -detail
opatch lspatches
```
