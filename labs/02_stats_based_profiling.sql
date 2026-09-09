set pages 500 lines 240 trimspool on

prompt ============================================================
prompt 01. TABLE STATS, NO FULL DATA SCAN
prompt ============================================================

select table_name,
       num_rows,
       blocks,
       avg_row_len,
       sample_size,
       last_analyzed,
       stale_stats,
       partitioned
from user_tab_statistics
where object_type = 'TABLE'
order by num_rows desc nulls last, table_name;

prompt ============================================================
prompt 02. PARTITION STATS, IF TABLES ARE PARTITIONED
prompt ============================================================

select table_name,
       partition_name,
       num_rows,
       blocks,
       sample_size,
       last_analyzed
from user_tab_partitions
order by table_name, partition_position;

prompt ============================================================
prompt 03. COLUMN STATS FOR CARDINALITY HINTS
prompt ============================================================

select table_name,
       column_name,
       num_distinct,
       num_nulls,
       density,
       histogram,
       sample_size,
       last_analyzed
from user_tab_col_statistics
order by table_name, column_name;

prompt ============================================================
prompt 04. LOW-CARDINALITY CANDIDATES: TYPE / STATUS / CHANNEL / CODE
prompt ============================================================

select s.table_name,
       s.column_name,
       s.num_distinct,
       s.num_nulls,
       s.histogram,
       s.last_analyzed
from user_tab_col_statistics s
join user_tab_columns c
  on c.table_name = s.table_name
 and c.column_name = s.column_name
where regexp_like(s.column_name, '(TYPE|STATUS|CHANNEL|CODE|CURRENCY|GENDER)$', 'i')
order by s.table_name, s.column_name;

prompt ============================================================
prompt 05. HIGH-NUM-DISTINCT CANDIDATES: BUSINESS KEYS
prompt ============================================================

select table_name,
       column_name,
       num_distinct,
       num_nulls,
       histogram,
       last_analyzed
from user_tab_col_statistics
where num_distinct is not null
order by num_distinct desc nulls last
fetch first 100 rows only;

prompt ============================================================
prompt 06. TABLES WITH STALE OR MISSING STATS
prompt ============================================================

select table_name,
       num_rows,
       stale_stats,
       last_analyzed
from user_tab_statistics
where object_type = 'TABLE'
  and (stale_stats = 'YES' or last_analyzed is null)
order by table_name;

prompt ============================================================
prompt 07. NULLABILITY FROM METADATA
prompt ============================================================

select table_name,
       column_name,
       data_type,
       nullable,
       data_default
from user_tab_columns
order by table_name, column_id;

prompt ============================================================
prompt 08. NORMALIZATION WARNING CANDIDATES FROM METADATA
prompt ============================================================

select table_name,
       column_name,
       data_type
from user_tab_columns
where regexp_like(column_name, '(LIST|CSV|JSON|XML|IDS|TAGS|VALUES)$', 'i')
   or data_type in ('CLOB', 'BLOB', 'JSON')
order by table_name, column_id;

prompt ============================================================
prompt 09. COMPOSITE PRIMARY KEYS: 2NF REVIEW CANDIDATES
prompt ============================================================

select c.table_name,
       count(*) as pk_col_count,
       listagg(cc.column_name, ', ') within group (order by cc.position) as pk_columns
from user_constraints c
join user_cons_columns cc
  on c.constraint_name = cc.constraint_name
where c.constraint_type = 'P'
group by c.table_name
having count(*) > 1
order by c.table_name;
