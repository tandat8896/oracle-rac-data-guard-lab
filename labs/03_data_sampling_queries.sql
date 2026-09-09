set pages 500 lines 240 trimspool on

prompt ============================================================
prompt WARNING
prompt ============================================================
prompt This file can scan real table data.
prompt Prefer standby / read replica / reporting clone / off-peak window.
prompt Edit table and column names before running.

prompt ============================================================
prompt 01. SAMPLE CARDINALITY TEMPLATE
prompt Replace <table_name> and <fk_column>.
prompt ============================================================

prompt Example:
prompt select <fk_column>, count(*) as child_rows
prompt from <table_name> sample block (0.1)
prompt group by <fk_column>
prompt order by child_rows desc
prompt fetch first 20 rows only;

prompt ============================================================
prompt 02. BANKING LAB: TRANSACTIONS PER ACCOUNT SAMPLE
prompt ============================================================

select account_id,
       count(*) as sampled_transaction_rows
from transactions sample block (1)
group by account_id
order by sampled_transaction_rows desc
fetch first 20 rows only;

prompt ============================================================
prompt 03. BANKING LAB: ACCOUNTS PER CUSTOMER SAMPLE
prompt ============================================================

select customer_id,
       count(*) as sampled_account_rows
from accounts sample block (1)
group by customer_id
order by sampled_account_rows desc
fetch first 20 rows only;

prompt ============================================================
prompt 04. BANKING LAB: CARDS PER ACCOUNT SAMPLE
prompt ============================================================

select account_id,
       count(*) as sampled_card_rows
from cards sample block (1)
group by account_id
order by sampled_card_rows desc
fetch first 20 rows only;

prompt ============================================================
prompt 05. BANKING LAB: LOANS PER CUSTOMER SAMPLE
prompt ============================================================

select customer_id,
       count(*) as sampled_loan_rows
from loans sample block (1)
group by customer_id
order by sampled_loan_rows desc
fetch first 20 rows only;

prompt ============================================================
prompt 06. DISTINCT DOMAIN VALUES ON SMALL / LOW-CARDINALITY COLUMNS
prompt Use only if table size is acceptable or on standby.
prompt ============================================================

select 'ACCOUNTS.TYPE' as column_name, type as value, count(*) as rows_count
from accounts
group by type
union all
select 'ACCOUNTS.STATUS', status, count(*)
from accounts
group by status
union all
select 'CARDS.TYPE', type, count(*)
from cards
group by type
union all
select 'CARDS.STATUS', status, count(*)
from cards
group by status
union all
select 'LOANS.TYPE', type, count(*)
from loans
group by type
union all
select 'LOANS.STATUS', status, count(*)
from loans
group by status
order by column_name, rows_count desc;

prompt ============================================================
prompt 07. ORPHAN CHECK TEMPLATE
prompt Can be expensive on huge tables. Prefer standby/off-peak.
prompt Replace names before running.
prompt ============================================================

prompt select count(*) as orphan_rows
prompt from <child_table> c
prompt where c.<fk_column> is not null
prompt   and not exists (
prompt     select 1
prompt     from <parent_table> p
prompt     where p.<parent_pk_column> = c.<fk_column>
prompt   );

prompt ============================================================
prompt 08. BANKING LAB ORPHAN CHECKS
prompt These scan real data. Use standby/off-peak for large tables.
prompt ============================================================

select count(*) as orphan_cards
from cards c
where c.account_id is not null
  and not exists (select 1 from accounts a where a.id = c.account_id);

select count(*) as orphan_transactions
from transactions t
where t.account_id is not null
  and not exists (select 1 from accounts a where a.id = t.account_id);

select count(*) as orphan_account_customers_account
from account_customers ac
where ac.account_id is not null
  and not exists (select 1 from accounts a where a.id = ac.account_id);

select count(*) as orphan_account_customers_customer
from account_customers ac
where ac.customer_id is not null
  and not exists (select 1 from customers c where c.id = ac.customer_id);
