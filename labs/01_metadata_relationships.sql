set pages 500 lines 240 trimspool on

prompt ============================================================
prompt 01. CONTEXT
prompt ============================================================

select sys_context('USERENV','SESSION_USER') as current_user,
       sys_context('USERENV','CON_NAME') as container_name,
       sys_context('USERENV','DB_NAME') as db_name,
       sys_context('USERENV','SERVER_HOST') as host
from dual;

prompt ============================================================
prompt 02. TABLE INVENTORY FROM METADATA
prompt ============================================================

select table_name,
       num_rows,
       blocks,
       last_analyzed,
       partitioned,
       temporary,
       iot_type
from user_tables
order by num_rows desc nulls last, table_name;

prompt ============================================================
prompt 03. PRIMARY KEYS
prompt ============================================================

select c.table_name,
       c.constraint_name,
       listagg(cc.column_name, ', ') within group (order by cc.position) as pk_columns
from user_constraints c
join user_cons_columns cc
  on c.constraint_name = cc.constraint_name
where c.constraint_type = 'P'
group by c.table_name, c.constraint_name
order by c.table_name;

prompt ============================================================
prompt 04. UNIQUE / BUSINESS KEYS
prompt ============================================================

select c.table_name,
       c.constraint_name,
       c.constraint_type,
       listagg(cc.column_name, ', ') within group (order by cc.position) as columns
from user_constraints c
join user_cons_columns cc
  on c.constraint_name = cc.constraint_name
where c.constraint_type in ('P','U')
group by c.table_name, c.constraint_name, c.constraint_type
order by c.table_name, c.constraint_type, c.constraint_name;

prompt ============================================================
prompt 05. FOREIGN KEYS
prompt ============================================================

select child.table_name as child_table,
       child_cols.column_name as fk_column,
       parent.table_name as parent_table,
       parent_cols.column_name as parent_column,
       child.constraint_name as fk_name,
       child.delete_rule,
       child.status
from user_constraints child
join user_cons_columns child_cols
  on child.constraint_name = child_cols.constraint_name
join user_constraints parent
  on child.r_constraint_name = parent.constraint_name
join user_cons_columns parent_cols
  on parent.constraint_name = parent_cols.constraint_name
 and child_cols.position = parent_cols.position
where child.constraint_type = 'R'
order by parent.table_name, child.table_name, child_cols.position;

prompt ============================================================
prompt 06. RELATIONSHIP CLASSIFICATION: 1-N / POSSIBLE 1-1
prompt ============================================================

with fk_cols as (
  select c.constraint_name,
         c.table_name,
         c.r_constraint_name,
         c.delete_rule,
         c.status,
         cc.column_name,
         cc.position
  from user_constraints c
  join user_cons_columns cc
    on c.constraint_name = cc.constraint_name
  where c.constraint_type = 'R'
),
fk_group as (
  select constraint_name,
         table_name,
         r_constraint_name,
         delete_rule,
         status,
         listagg(column_name, ', ') within group (order by position) as fk_columns
  from fk_cols
  group by constraint_name, table_name, r_constraint_name, delete_rule, status
),
parent_group as (
  select c.constraint_name,
         c.table_name as parent_table,
         listagg(cc.column_name, ', ') within group (order by cc.position) as parent_columns
  from user_constraints c
  join user_cons_columns cc
    on c.constraint_name = cc.constraint_name
  where c.constraint_type in ('P','U')
  group by c.constraint_name, c.table_name
),
unique_group as (
  select c.table_name,
         listagg(cc.column_name, ', ') within group (order by cc.position) as unique_columns
  from user_constraints c
  join user_cons_columns cc
    on c.constraint_name = cc.constraint_name
  where c.constraint_type in ('P','U')
  group by c.table_name, c.constraint_name
)
select fk.table_name as child_table,
       fk.fk_columns,
       p.parent_table,
       p.parent_columns,
       fk.constraint_name as fk_name,
       fk.delete_rule,
       fk.status,
       case
         when exists (
           select 1
           from unique_group uq
           where uq.table_name = fk.table_name
             and uq.unique_columns = fk.fk_columns
         )
         then 'POSSIBLE_1_TO_1'
         else 'ONE_TO_MANY'
       end as relationship_type
from fk_group fk
join parent_group p
  on p.constraint_name = fk.r_constraint_name
order by p.parent_table, fk.table_name, fk.fk_columns;

prompt ============================================================
prompt 07. MANY-TO-MANY BRIDGE CANDIDATES
prompt ============================================================

with fk_cols as (
  select c.table_name,
         c.constraint_name,
         cc.column_name,
         cc.position
  from user_constraints c
  join user_cons_columns cc
    on c.constraint_name = cc.constraint_name
  where c.constraint_type = 'R'
),
fk_summary as (
  select table_name,
         count(distinct constraint_name) as fk_count,
         count(*) as fk_col_count,
         listagg(column_name, ', ') within group (order by column_name) as fk_columns_sorted
  from fk_cols
  group by table_name
),
key_cols as (
  select c.table_name,
         c.constraint_type,
         c.constraint_name,
         cc.column_name,
         cc.position
  from user_constraints c
  join user_cons_columns cc
    on c.constraint_name = cc.constraint_name
  where c.constraint_type in ('P','U')
),
key_summary as (
  select table_name,
         constraint_type,
         constraint_name,
         count(*) as key_col_count,
         listagg(column_name, ', ') within group (order by column_name) as key_columns_sorted
  from key_cols
  group by table_name, constraint_type, constraint_name
),
col_summary as (
  select table_name,
         count(*) as total_columns
  from user_tab_columns
  group by table_name
)
select f.table_name,
       f.fk_count,
       f.fk_columns_sorted,
       k.constraint_type as matching_key_type,
       k.key_columns_sorted,
       col.total_columns,
       (col.total_columns - f.fk_col_count) as non_fk_columns,
       case
         when k.key_columns_sorted = f.fk_columns_sorted
              and (col.total_columns - f.fk_col_count) <= 3
         then 'LIKELY_MANY_TO_MANY_BRIDGE'
         when f.fk_count >= 2
         then 'POSSIBLE_BRIDGE_OR_BUSINESS_ENTITY'
       end as classification
from fk_summary f
join col_summary col
  on col.table_name = f.table_name
left join key_summary k
  on k.table_name = f.table_name
 and k.key_columns_sorted = f.fk_columns_sorted
where f.fk_count >= 2
order by classification, f.table_name;

prompt ============================================================
prompt 08. FK INDEX COVERAGE
prompt ============================================================

with fk_cols as (
  select c.constraint_name,
         c.table_name,
         cc.column_name,
         cc.position
  from user_constraints c
  join user_cons_columns cc
    on c.constraint_name = cc.constraint_name
  where c.constraint_type = 'R'
),
fk_group as (
  select table_name,
         constraint_name,
         listagg(column_name, ', ') within group (order by position) as fk_columns
  from fk_cols
  group by table_name, constraint_name
),
idx_group as (
  select i.table_name,
         i.index_name,
         listagg(ic.column_name, ', ') within group (order by ic.column_position) as index_columns
  from user_indexes i
  join user_ind_columns ic
    on i.index_name = ic.index_name
   and i.table_name = ic.table_name
  group by i.table_name, i.index_name
)
select fk.table_name,
       fk.constraint_name as fk_name,
       fk.fk_columns,
       case
         when exists (
           select 1
           from idx_group ix
           where ix.table_name = fk.table_name
             and (ix.index_columns = fk.fk_columns or ix.index_columns like fk.fk_columns || ',%')
         )
         then 'INDEXED'
         else 'MISSING_FK_INDEX'
       end as fk_index_status
from fk_group fk
order by fk_index_status desc, fk.table_name, fk.constraint_name;

prompt ============================================================
prompt 09. MERMAID ERD LINES
prompt ============================================================

select '    ' || parent.table_name || ' ||--o{ ' || child.table_name || ' : "' ||
       lower(child_cols.column_name) || '"' as mermaid_line
from user_constraints child
join user_cons_columns child_cols
  on child.constraint_name = child_cols.constraint_name
join user_constraints parent
  on child.r_constraint_name = parent.constraint_name
where child.constraint_type = 'R'
order by parent.table_name, child.table_name;
