-- =============================================================
-- Banking Schema — Drop + Create + Generate ~1 trieu rows
-- Chay voi user tandat8896 trong ORCLPDB1
-- =============================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

-- -------------------------------------------------------------
-- 0. Drop neu ton tai (bo qua neu chua co)
-- -------------------------------------------------------------
BEGIN EXECUTE IMMEDIATE 'DROP TABLE transactions PURGE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE cards PURGE';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE loans PURGE';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE accounts PURGE';     EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE customers PURGE';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE branches PURGE';     EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- -------------------------------------------------------------
-- 1. DDL
-- -------------------------------------------------------------

CREATE TABLE branches (
  id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR2(200) NOT NULL,
  city       VARCHAR2(100),
  province   VARCHAR2(10),
  phone      VARCHAR2(20),
  opened_at  DATE DEFAULT SYSDATE
);

CREATE TABLE customers (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        VARCHAR2(100) NOT NULL,
  email       VARCHAR2(200) UNIQUE NOT NULL,
  phone       VARCHAR2(20),
  id_number   VARCHAR2(20) UNIQUE,
  dob         DATE,
  gender      VARCHAR2(10),
  branch_id   NUMBER REFERENCES branches(id),
  created_at  TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE TABLE accounts (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id NUMBER       NOT NULL REFERENCES customers(id),
  branch_id   NUMBER       REFERENCES branches(id),
  type        VARCHAR2(20) NOT NULL,           -- savings / checking
  acct_no     VARCHAR2(20) UNIQUE NOT NULL,
  balance     NUMBER(18,2) DEFAULT 0,
  currency    VARCHAR2(3)  DEFAULT 'VND',
  status      VARCHAR2(20) DEFAULT 'active',   -- active / frozen / closed
  opened_at   TIMESTAMP    DEFAULT SYSTIMESTAMP
);

CREATE TABLE transactions (
  id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  account_id    NUMBER       NOT NULL REFERENCES accounts(id),
  type          VARCHAR2(20) NOT NULL,          -- debit / credit / transfer
  amount        NUMBER(18,2) NOT NULL,
  balance_after NUMBER(18,2),
  description   VARCHAR2(500),
  ref_no        VARCHAR2(50),
  channel       VARCHAR2(20),                   -- ATM / online / branch / mobile
  txn_at        TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE TABLE cards (
  id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  account_id   NUMBER       NOT NULL REFERENCES accounts(id),
  type         VARCHAR2(20) NOT NULL,           -- debit / credit
  card_no      VARCHAR2(20) UNIQUE NOT NULL,
  expiry       DATE         NOT NULL,
  status       VARCHAR2(20) DEFAULT 'active',   -- active / blocked / expired
  credit_limit NUMBER(18,2),
  issued_at    TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE TABLE loans (
  id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id   NUMBER       NOT NULL REFERENCES customers(id),
  branch_id     NUMBER       REFERENCES branches(id),
  type          VARCHAR2(30),                   -- personal / mortgage / car / business
  amount        NUMBER(18,2) NOT NULL,
  interest_rate NUMBER(5,2)  NOT NULL,
  term_months   NUMBER       NOT NULL,
  status        VARCHAR2(20) DEFAULT 'active',  -- active / paid / default
  disbursed_at  TIMESTAMP,
  due_date      DATE
);

-- -------------------------------------------------------------
-- 2. Seed: 20 branches
-- -------------------------------------------------------------
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Ho Chi Minh - Chi nhanh 1',    'Ho Chi Minh', 'HCM',  '02838001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Ho Chi Minh - Chi nhanh 2',    'Ho Chi Minh', 'HCM',  '02838005678');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Ha Noi - Chi nhanh 1',         'Ha Noi',      'HN',   '02432001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Ha Noi - Chi nhanh 2',         'Ha Noi',      'HN',   '02432005678');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Da Nang',                      'Da Nang',     'DN',   '02363001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Can Tho',                      'Can Tho',     'CT',   '02923001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Hai Phong',                    'Hai Phong',   'HP',   '02253001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Hue',                          'Hue',         'TTH',  '02343001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Nha Trang',                    'Nha Trang',   'KH',   '02583001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Bien Hoa',                     'Bien Hoa',    'DNA',  '02513001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Vung Tau',                     'Vung Tau',    'BRVT', '02543001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Quy Nhon',                     'Quy Nhon',    'BD',   '02563001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Buon Ma Thuot',                'Buon Ma Thuot','DL',  '02623001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Thai Nguyen',                  'Thai Nguyen', 'TN',   '02083001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Nam Dinh',                     'Nam Dinh',    'ND',   '02283001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Vinh',                         'Vinh',        'NA',   '02383001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Phan Thiet',                   'Phan Thiet',  'BT',   '02523001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Long Xuyen',                   'Long Xuyen',  'AG',   '02963001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB My Tho',                       'My Tho',      'TG',   '02733001234');
INSERT INTO branches (name, city, province, phone) VALUES ('VCB Pleiku',                       'Pleiku',      'GL',   '02693001234');
COMMIT;

-- -------------------------------------------------------------
-- 3. Generate 100,000 customers
-- -------------------------------------------------------------
DECLARE
  v_lastnames SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
    'Nguyen','Tran','Le','Pham','Hoang','Vu','Dang','Bui','Do','Ho',
    'Ngo','Duong','Ly','Dinh','Truong','Dao','Luu','Vo','Thi','Mac'
  );
  v_genders   SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('M','F');
  v_name      VARCHAR2(100);
  v_dob       DATE;
BEGIN
  FOR i IN 1..100000 LOOP
    v_name := v_lastnames(TRUNC(DBMS_RANDOM.VALUE(1, v_lastnames.COUNT+1))) || ' Van ' || i;
    v_dob  := DATE '1970-01-01' + TRUNC(DBMS_RANDOM.VALUE(0, 19000));

    INSERT INTO customers (name, email, phone, id_number, dob, gender, branch_id)
    VALUES (
      v_name,
      'cust' || i || '@vcb.com',
      '09' || LPAD(TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(0,100000000))), 8, '0'),
      LPAD(TO_CHAR(i), 12, '0'),
      v_dob,
      v_genders(TRUNC(DBMS_RANDOM.VALUE(1,3))),
      TRUNC(DBMS_RANDOM.VALUE(1, 21))
    );

    IF MOD(i, 5000) = 0 THEN
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('customers: ' || i);
    END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Done: 100000 customers');
END;
/

-- -------------------------------------------------------------
-- 4. Generate accounts (~150,000: moi customer 1-2 accounts)
-- -------------------------------------------------------------
DECLARE
  v_types   SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('savings','checking');
  v_cnt     NUMBER := 0;
  v_type    VARCHAR2(20);
  v_balance NUMBER;
BEGIN
  FOR c IN (SELECT id, branch_id FROM customers) LOOP
    -- Tat ca co 1 savings account
    v_balance := ROUND(DBMS_RANDOM.VALUE(100000, 500000000), 0);
    INSERT INTO accounts (customer_id, branch_id, type, acct_no, balance)
    VALUES (c.id, c.branch_id, 'savings',
            '1' || LPAD(TO_CHAR(c.id), 9, '0') || '0',
            v_balance);
    v_cnt := v_cnt + 1;

    -- 50% co them checking account
    IF DBMS_RANDOM.VALUE < 0.5 THEN
      v_balance := ROUND(DBMS_RANDOM.VALUE(0, 100000000), 0);
      INSERT INTO accounts (customer_id, branch_id, type, acct_no, balance)
      VALUES (c.id, c.branch_id, 'checking',
              '1' || LPAD(TO_CHAR(c.id), 9, '0') || '1',
              v_balance);
      v_cnt := v_cnt + 1;
    END IF;

    IF MOD(c.id, 10000) = 0 THEN
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('accounts: ' || v_cnt);
    END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Done: ' || v_cnt || ' accounts');
END;
/

-- -------------------------------------------------------------
-- 5. Generate transactions (~1,000,000 rows)
-- -------------------------------------------------------------
DECLARE
  v_channels SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('ATM','online','branch','mobile','mobile','online');
  v_descs    SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
    'Chuyen tien noi dia','Nap tien','Rut tien','Thanh toan hoa don',
    'Mua sam online','Tra luong','Thu phi dich vu','Hoan tien'
  );
  v_types    SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
    'debit','debit','credit','debit','credit','transfer','debit','credit'
  );
  v_amount   NUMBER;
  v_bal      NUMBER;
  v_cnt      NUMBER := 0;
  v_txn_type VARCHAR2(20);
BEGIN
  FOR a IN (SELECT id, balance FROM accounts) LOOP
    -- Moi account co 6-12 transactions
    FOR j IN 1..TRUNC(DBMS_RANDOM.VALUE(6, 13)) LOOP
      v_txn_type := v_types(TRUNC(DBMS_RANDOM.VALUE(1, v_types.COUNT+1)));
      v_amount   := ROUND(DBMS_RANDOM.VALUE(50000, 50000000), 0);
      v_bal      := ROUND(DBMS_RANDOM.VALUE(0, 500000000), 0);

      INSERT INTO transactions (account_id, type, amount, balance_after, description, ref_no, channel, txn_at)
      VALUES (
        a.id,
        v_txn_type,
        v_amount,
        v_bal,
        v_descs(TRUNC(DBMS_RANDOM.VALUE(1, v_descs.COUNT+1))),
        'REF' || LPAD(TO_CHAR(v_cnt+1), 10, '0'),
        v_channels(TRUNC(DBMS_RANDOM.VALUE(1, v_channels.COUNT+1))),
        SYSTIMESTAMP - TRUNC(DBMS_RANDOM.VALUE(0, 1095))
      );
      v_cnt := v_cnt + 1;
    END LOOP;

    IF MOD(a.id, 5000) = 0 THEN
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('transactions: ' || v_cnt);
    END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Done: ' || v_cnt || ' transactions');
END;
/

-- -------------------------------------------------------------
-- 6. Generate cards (~120,000)
-- -------------------------------------------------------------
DECLARE
  v_cnt  NUMBER := 0;
  v_type VARCHAR2(20);
BEGIN
  FOR a IN (SELECT id, type FROM accounts) LOOP
    v_type := CASE a.type WHEN 'checking' THEN 'debit' ELSE 'debit' END;

    INSERT INTO cards (account_id, type, card_no, expiry, status, credit_limit)
    VALUES (
      a.id,
      v_type,
      '4' || LPAD(TO_CHAR(a.id*7+13), 15, '0'),
      ADD_MONTHS(SYSDATE, TRUNC(DBMS_RANDOM.VALUE(6, 61))),
      CASE WHEN DBMS_RANDOM.VALUE < 0.05 THEN 'blocked' ELSE 'active' END,
      NULL
    );
    v_cnt := v_cnt + 1;

    -- 20% co them credit card
    IF DBMS_RANDOM.VALUE < 0.2 THEN
      INSERT INTO cards (account_id, type, card_no, expiry, status, credit_limit)
      VALUES (
        a.id,
        'credit',
        '5' || LPAD(TO_CHAR(a.id*11+7), 15, '0'),
        ADD_MONTHS(SYSDATE, TRUNC(DBMS_RANDOM.VALUE(12, 61))),
        CASE WHEN DBMS_RANDOM.VALUE < 0.03 THEN 'blocked' ELSE 'active' END,
        ROUND(DBMS_RANDOM.VALUE(10000000, 500000000), 0)
      );
      v_cnt := v_cnt + 1;
    END IF;

    IF MOD(a.id, 10000) = 0 THEN
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('cards: ' || v_cnt);
    END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Done: ' || v_cnt || ' cards');
END;
/

-- -------------------------------------------------------------
-- 7. Generate loans (~30,000)
-- -------------------------------------------------------------
DECLARE
  v_types SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST('personal','mortgage','car','business');
  v_cnt   NUMBER := 0;
  v_type  VARCHAR2(30);
  v_amt   NUMBER;
  v_rate  NUMBER;
  v_term  NUMBER;
BEGIN
  FOR c IN (SELECT id, branch_id FROM customers WHERE MOD(id, 4) = 0) LOOP
    v_type := v_types(TRUNC(DBMS_RANDOM.VALUE(1, v_types.COUNT+1)));
    v_amt  := CASE v_type
                WHEN 'personal'  THEN ROUND(DBMS_RANDOM.VALUE(10000000, 500000000), 0)
                WHEN 'mortgage'  THEN ROUND(DBMS_RANDOM.VALUE(500000000, 5000000000), 0)
                WHEN 'car'       THEN ROUND(DBMS_RANDOM.VALUE(200000000, 1500000000), 0)
                ELSE                  ROUND(DBMS_RANDOM.VALUE(100000000, 2000000000), 0)
              END;
    v_rate := ROUND(DBMS_RANDOM.VALUE(6.5, 15.5), 2);
    v_term := CASE v_type
                WHEN 'mortgage' THEN TRUNC(DBMS_RANDOM.VALUE(120, 301))
                WHEN 'car'      THEN TRUNC(DBMS_RANDOM.VALUE(24, 85))
                ELSE                 TRUNC(DBMS_RANDOM.VALUE(6, 61))
              END;

    INSERT INTO loans (customer_id, branch_id, type, amount, interest_rate, term_months, status, disbursed_at, due_date)
    VALUES (
      c.id,
      c.branch_id,
      v_type,
      v_amt,
      v_rate,
      v_term,
      CASE WHEN DBMS_RANDOM.VALUE < 0.05 THEN 'default'
           WHEN DBMS_RANDOM.VALUE < 0.15 THEN 'paid'
           ELSE 'active' END,
      SYSTIMESTAMP - TRUNC(DBMS_RANDOM.VALUE(0, 1095)),
      SYSDATE + TRUNC(DBMS_RANDOM.VALUE(30, 3600))
    );
    v_cnt := v_cnt + 1;

    IF MOD(v_cnt, 5000) = 0 THEN
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('loans: ' || v_cnt);
    END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Done: ' || v_cnt || ' loans');
END;
/

-- -------------------------------------------------------------
-- Verify
-- -------------------------------------------------------------
SELECT 'branches'     tbl, COUNT(*) cnt FROM branches     UNION ALL
SELECT 'customers',        COUNT(*)     FROM customers     UNION ALL
SELECT 'accounts',         COUNT(*)     FROM accounts      UNION ALL
SELECT 'transactions',     COUNT(*)     FROM transactions   UNION ALL
SELECT 'cards',            COUNT(*)     FROM cards         UNION ALL
SELECT 'loans',            COUNT(*)     FROM loans
ORDER BY 1;
