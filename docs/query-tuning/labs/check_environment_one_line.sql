-- Check whether this database looks like homelab/dev/staging/production.
-- Run as SYS or a DBA user inside SQLcl/SQL*Plus, not in the Linux shell.
-- Example: sql / as sysdba @labs/check_environment_one_line.sql

SET LINESIZE 220
SET PAGESIZE 100

PROMPT === 1. Database identity ===
SELECT name, db_unique_name, database_role, open_mode, cdb FROM v$database;

PROMPT === 2. Current instance ===
SELECT instance_name, host_name, status, database_status FROM v$instance;

PROMPT === 3. Current container and user ===
SHOW CON_NAME
SHOW USER

PROMPT === 4. PDB list ===
SELECT name, open_mode, restricted FROM v$pdbs;

PROMPT === 5. User sessions by program/machine/module ===
SELECT username, program, machine, module, status, COUNT(*) AS sessions FROM v$session WHERE type = 'USER' GROUP BY username, program, machine, module, status ORDER BY sessions DESC;

PROMPT === 6. Largest non-system tables across CDB ===
SELECT owner, table_name, num_rows, last_analyzed FROM cdb_tables WHERE owner NOT IN ('SYS','SYSTEM','XDB','MDSYS','CTXSYS','ORDSYS','DBSNMP','WMSYS') ORDER BY num_rows DESC NULLS LAST FETCH FIRST 20 ROWS ONLY;

PROMPT === 7. Management pack access parameter ===
SHOW PARAMETER control_management_pack_access

PROMPT === 8. RAC instances ===
SELECT inst_id, instance_name, host_name, status, database_status FROM gv$instance ORDER BY inst_id;

PROMPT === Done ===
