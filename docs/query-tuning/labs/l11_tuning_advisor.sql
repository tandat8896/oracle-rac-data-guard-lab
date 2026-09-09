-- Lesson 11 runnable script: SQL Tuning Advisor lab
-- Run inside SQLcl/SQL*Plus as QUERY_TUNING in PDB1:
-- @labs/l11_tuning_advisor.sql

SET SERVEROUTPUT ON
SET LONG 100000
SET LONGCHUNKSIZE 100000
SET PAGESIZE 500
SET LINESIZE 200

PROMPT === 1. Run lab SQL with marker and plan statistics ===
SELECT /*+ GATHER_PLAN_STATISTICS L11_PLAN_TEST_COUNT */ COUNT(*) FROM orders_demo WHERE order_status = 'CANCELLED';

PROMPT === 2. Find SQL_ID for marker ===
SELECT sql_id, executions, plan_hash_value, ROUND(elapsed_time / 1e6, 3) AS total_elapsed_sec, buffer_gets, disk_reads, SUBSTR(sql_text, 1, 120) AS sql_preview FROM v$sql WHERE sql_text LIKE '%L11_PLAN_TEST_COUNT%' AND sql_text NOT LIKE '%v$sql%' ORDER BY last_active_time DESC;

PROMPT === 3. Check child cursor and plan hash for current lab SQL_ID ===
SELECT sql_id, child_number, plan_hash_value, executions, is_bind_sensitive, is_bind_aware, last_active_time FROM v$sql WHERE sql_id = '18h6ufv1ttwvw' ORDER BY child_number;

PROMPT === 4. Display actual plan with A-Rows and Buffers ===
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(sql_id => '18h6ufv1ttwvw', cursor_child_no => NULL, format => 'ALLSTATS LAST +PEEKED_BINDS +PREDICATE'));

PROMPT === 5. Drop old tuning task if it exists ===
BEGIN
  DBMS_SQLTUNE.DROP_TUNING_TASK('L11_TUNE_TASK');
  DBMS_OUTPUT.PUT_LINE('Dropped old task L11_TUNE_TASK');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -13605 THEN
      DBMS_OUTPUT.PUT_LINE('No old task to drop');
    ELSE
      RAISE;
    END IF;
END;
/

PROMPT === 6. Create and execute SQL Tuning Advisor task ===
DECLARE
  l_task_name VARCHAR2(128);
BEGIN
  l_task_name := DBMS_SQLTUNE.CREATE_TUNING_TASK(
    sql_id     => '18h6ufv1ttwvw',
    scope      => DBMS_SQLTUNE.SCOPE_COMPREHENSIVE,
    time_limit => 60,
    task_name  => 'L11_TUNE_TASK'
  );

  DBMS_SQLTUNE.EXECUTE_TUNING_TASK(task_name => l_task_name);
  DBMS_OUTPUT.PUT_LINE('Executed task: ' || l_task_name);
END;
/

PROMPT === 7. Check advisor task status ===
SELECT task_name, status, execution_start, execution_end FROM user_advisor_tasks WHERE task_name = 'L11_TUNE_TASK';
SELECT task_name, status, execution_start, execution_end FROM user_advisor_log WHERE task_name = 'L11_TUNE_TASK';

PROMPT === 8. Show SQL Tuning Advisor report ===
SELECT DBMS_SQLTUNE.REPORT_TUNING_TASK('L11_TUNE_TASK', 'TEXT', 'ALL', 'ALL') AS report FROM dual;

PROMPT === 9. Optional: load SQL Plan Baseline from cursor cache ===
PROMPT Skip this if you only want advisor report. Uncomment manually if needed.
-- DECLARE
--   l_count PLS_INTEGER;
-- BEGIN
--   l_count := DBMS_SPM.LOAD_PLANS_FROM_CURSOR_CACHE(sql_id => '18h6ufv1ttwvw', plan_hash_value => 2428763047);
--   DBMS_OUTPUT.PUT_LINE('Baselines loaded: ' || l_count);
-- END;
-- /

PROMPT === Done ===
