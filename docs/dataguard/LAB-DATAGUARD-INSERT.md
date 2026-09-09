# Lab: Insert Data và Verify Data Guard Replication

Muc tieu: insert data tren primary, quan sat replication sang standby theo thoi gian thuc.

Infra san co:
```
oraee-dg-primary   PRIMARY        ORCLPDB1   port 1522
oraee-dg-standby   PHYSICAL STANDBY  ORCLPDB1   port 1523
```

---

## 0. Startup checklist (sau moi lan container restart)

**Khong duoc `podman container update --health-cmd` — gay restart container, MRP0 bi dung.**  
`unhealthy` trong `podman ps` la cosmetic, khong anh huong Data Guard — bo qua.

Sau moi lan `podman restart oraee-dg-standby`, phai chay 2 lenh nay tren standby:

```bash
podman exec -it oraee-dg-standby bash
sqlplus / as sysdba
```

```sql
-- 1. open PDB (neu chua open)
ALTER PLUGGABLE DATABASE ORCLPDB1 OPEN READ ONLY;

-- 2. restart managed recovery
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;

-- 3. verify MRP0 dang chay
SELECT process, status, sequence# FROM v$managed_standby;
-- phai thay: MRP0  APPLYING_LOG
```

---

## 1. Tao user va schema tren primary

```bash
podman exec -it oraee-dg-primary bash
sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER = ORCLPDB1;

CREATE USER tandat8896 IDENTIFIED BY "<REDACTED_PASSWORD>";
GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE,
      CREATE PROCEDURE, UNLIMITED TABLESPACE TO tandat8896;

EXIT
```

---

## 2. Tao tables (dataset ban hang nho)

```sql
CONNECT tandat8897/"<REDACTED_PASSWORD>"@localhost:1521/ORCLPDB1

-- Khach hang
CREATE TABLE customers (
  id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR2(100) NOT NULL,
  email      VARCHAR2(200) UNIQUE NOT NULL,
  city       VARCHAR2(100),
  created_at TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- San pham
CREATE TABLE products (
  id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR2(200) NOT NULL,
  price      NUMBER(10,2) NOT NULL,
  stock      NUMBER DEFAULT 0,
  category   VARCHAR2(100)
);

-- Don hang
CREATE TABLE orders (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id NUMBER REFERENCES customers(id),
  product_id  NUMBER REFERENCES products(id),
  qty         NUMBER NOT NULL,
  total       NUMBER(10,2) NOT NULL,
  ordered_at  TIMESTAMP DEFAULT SYSTIMESTAMP,
  status      VARCHAR2(20) DEFAULT 'pending'
);
```

---

## 3. Insert data mau

```sql
-- Khach hang
INSERT INTO customers (name, email, city) VALUES ('Nguyen Van A', 'vana@example.com', 'Ho Chi Minh');
INSERT INTO customers (name, email, city) VALUES ('Tran Thi B',  'thib@example.com', 'Ha Noi');
INSERT INTO customers (name, email, city) VALUES ('Le Van C',    'vanc@example.com', 'Da Nang');

-- San pham
INSERT INTO products (name, price, stock, category) VALUES ('Laptop Dell XPS 15', 35000000, 10, 'Electronics');
INSERT INTO products (name, price, stock, category) VALUES ('iPhone 16 Pro',      30000000, 25, 'Electronics');
INSERT INTO products (name, price, stock, category) VALUES ('Mechanical Keyboard', 2500000,  50, 'Accessories');
INSERT INTO products (name, price, stock, category) VALUES ('USB-C Hub',           800000,  100, 'Accessories');

-- Don hang
INSERT INTO orders (customer_id, product_id, qty, total) VALUES (1, 1, 1, 35000000);
INSERT INTO orders (customer_id, product_id, qty, total) VALUES (1, 3, 2,  5000000);
INSERT INTO orders (customer_id, product_id, qty, total) VALUES (2, 2, 1, 30000000);
INSERT INTO orders (customer_id, product_id, qty, total) VALUES (3, 4, 3,  2400000);

COMMIT;

-- Verify
SELECT c.name, p.name product, o.qty, o.total, o.status
FROM orders o
JOIN customers c ON c.id = o.customer_id
JOIN products p  ON p.id = o.product_id
ORDER BY o.id;
```

---

## 4. Ep flush redo sang standby

Tren primary (van trong SQLPlus sysdba):

```sql
CONNECT / AS SYSDBA
ALTER SYSTEM ARCHIVE LOG CURRENT;
```

---

## 5. Verify tren standby

```bash
podman exec -it oraee-dg-standby bash -c "sqlplus -s tandat8896/\"<pwd>\"@localhost:1521/ORCLPDB1 <<'SQL'
SELECT c.name, p.name product, o.qty, o.total
FROM orders o
JOIN customers c ON c.id = o.customer_id
JOIN products p  ON p.id = o.product_id
ORDER BY o.id;
EXIT
SQL"
```

Thay du lieu giong primary → Data Guard dang hoat dong dung.

---

## 6. Quan sat apply lag theo thoi gian thuc

Mo 2 terminal song song:

**Terminal 1 — watch standby lag:**
```bash
watch -n2 'podman exec oraee-dg-standby bash -c "sqlplus -s / as sysdba <<< \"select name, value from v\\\$dataguard_stats where name in (\\x27transport lag\\x27, \\x27apply lag\\x27);\""'
```

**Terminal 2 — insert lien tuc tren primary:**
```bash
for i in $(seq 5 20); do
  podman exec oraee-dg-primary bash -c "sqlplus -s / as sysdba <<< \"
    ALTER SESSION SET CONTAINER=ORCLPDB1;
    INSERT INTO tandat8896.orders (customer_id, product_id, qty, total)
    VALUES ($(( (i % 3) + 1 )), $(( (i % 4) + 1 )), 1, 1000000);
    COMMIT;\""
  sleep 1
done
```

Quan sat lag giam ve `+00 00:00:00` sau moi insert.

---

## 7. Switchover (tuy chon — thu primary/standby doi vai)

```sql
-- Tren primary
ALTER DATABASE COMMIT TO SWITCHOVER TO PHYSICAL STANDBY WITH SESSION SHUTDOWN;

-- Tren standby (gio la primary moi)
ALTER DATABASE COMMIT TO SWITCHOVER TO PRIMARY WITH SESSION SHUTDOWN;
ALTER DATABASE OPEN;
```

Sau switchover:
- `oraee-dg-standby` tro thanh PRIMARY
- `oraee-dg-primary` tro thanh PHYSICAL STANDBY

Switchover back de ve trang thai ban dau.

---

## Checklist truoc khi lam lab

```bash
# containers dang chay
podman ps --filter name=oraee-dg

# MRP0 dang apply
podman exec -it oraee-dg-standby bash -c "sqlplus -s / as sysdba <<< 'select process, status, sequence# from v\$managed_standby where process=\x27MRP0\x27;'"

# neu MRP0 khong thay — restart managed recovery
podman exec -it oraee-dg-standby bash -c "sqlplus -s / as sysdba <<< 'alter database recover managed standby database using current logfile disconnect from session;'"
```
