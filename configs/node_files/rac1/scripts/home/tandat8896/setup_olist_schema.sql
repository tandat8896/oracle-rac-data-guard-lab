SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

PROMPT === 1. Drop old tables ===
BEGIN
  FOR c IN (SELECT table_name FROM user_tables) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || c.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('All tables dropped');
END;
/

PROMPT === 2. Create tables ===
CREATE TABLE sellers_demo (
  seller_id    NUMBER PRIMARY KEY,
  seller_city  VARCHAR2(50),
  seller_state CHAR(2),
  seller_zip   VARCHAR2(10)
);
CREATE TABLE customers_demo (
  customer_id      NUMBER PRIMARY KEY,
  customer_city    VARCHAR2(50),
  customer_state   CHAR(2),
  customer_zip     VARCHAR2(10),
  customer_segment VARCHAR2(20)
);
CREATE TABLE products_demo (
  product_id        NUMBER PRIMARY KEY,
  product_category  VARCHAR2(50),
  product_name      VARCHAR2(100),
  product_weight_g  NUMBER,
  product_length_cm NUMBER,
  product_height_cm NUMBER,
  product_width_cm  NUMBER,
  freight_value     NUMBER(10,2)
);
CREATE TABLE orders_demo (
  order_id                 NUMBER PRIMARY KEY,
  customer_id              NUMBER NOT NULL,
  order_status             VARCHAR2(20),
  order_date               DATE,
  order_approved_at        DATE,
  order_delivered_date     DATE,
  order_estimated_delivery DATE,
  freight_value            NUMBER(10,2) DEFAULT 0,
  total_amount             NUMBER(10,2) DEFAULT 0
);
CREATE TABLE order_items_demo (
  order_id   NUMBER NOT NULL,
  item_no    NUMBER NOT NULL,
  product_id NUMBER NOT NULL,
  seller_id  NUMBER NOT NULL,
  quantity   NUMBER DEFAULT 1,
  unit_price NUMBER(10,2),
  PRIMARY KEY (order_id, item_no)
);
CREATE TABLE payments_demo (
  payment_id           NUMBER PRIMARY KEY,
  order_id             NUMBER NOT NULL,
  payment_type         VARCHAR2(20),
  payment_installments NUMBER DEFAULT 1,
  payment_value        NUMBER(10,2)
);
CREATE TABLE reviews_demo (
  review_id      NUMBER PRIMARY KEY,
  order_id       NUMBER NOT NULL,
  review_score   NUMBER(1),
  review_comment VARCHAR2(400),
  review_created DATE,
  review_answered DATE
);
PROMPT Tables created

PROMPT === 3. Insert data (PL/SQL blocks) ===
BEGIN
  INSERT INTO sellers_demo (seller_id, seller_city, seller_state, seller_zip)
  SELECT LEVEL,
    CASE MOD(LEVEL,10) WHEN 0 THEN 'Sao Paulo' WHEN 1 THEN 'Rio de Janeiro' WHEN 2 THEN 'Belo Horizonte' WHEN 3 THEN 'Curitiba' WHEN 4 THEN 'Porto Alegre' WHEN 5 THEN 'Salvador' WHEN 6 THEN 'Brasilia' WHEN 7 THEN 'Fortaleza' WHEN 8 THEN 'Manaus' ELSE 'Recife' END,
    CASE MOD(LEVEL,7) WHEN 0 THEN 'SP' WHEN 1 THEN 'RJ' WHEN 2 THEN 'MG' WHEN 3 THEN 'PR' WHEN 4 THEN 'RS' WHEN 5 THEN 'BA' ELSE 'DF' END,
    LPAD(MOD(LEVEL*1234567,9000000)+1000000,7,'0')
  FROM dual CONNECT BY LEVEL <= 5000;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Sellers done: 5000 rows');
END;
/

BEGIN
  INSERT INTO customers_demo (customer_id, customer_city, customer_state, customer_zip, customer_segment)
  SELECT LEVEL,
    CASE MOD(LEVEL,10) WHEN 0 THEN 'Sao Paulo' WHEN 1 THEN 'Rio de Janeiro' WHEN 2 THEN 'Belo Horizonte' WHEN 3 THEN 'Curitiba' WHEN 4 THEN 'Porto Alegre' WHEN 5 THEN 'Salvador' WHEN 6 THEN 'Brasilia' WHEN 7 THEN 'Fortaleza' WHEN 8 THEN 'Manaus' ELSE 'Recife' END,
    CASE MOD(LEVEL,7) WHEN 0 THEN 'SP' WHEN 1 THEN 'RJ' WHEN 2 THEN 'MG' WHEN 3 THEN 'PR' WHEN 4 THEN 'RS' WHEN 5 THEN 'BA' ELSE 'DF' END,
    LPAD(MOD(LEVEL*7654321,9000000)+1000000,7,'0'),
    CASE WHEN LEVEL<=500 THEN 'PLATINUM' WHEN LEVEL<=5000 THEN 'GOLD' WHEN LEVEL<=20000 THEN 'SILVER' ELSE 'REGULAR' END
  FROM dual CONNECT BY LEVEL <= 100000;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Customers done: 100000 rows');
END;
/

BEGIN
  INSERT INTO products_demo (product_id, product_category, product_name, product_weight_g, product_length_cm, product_height_cm, product_width_cm, freight_value)
  SELECT LEVEL,
    CASE MOD(LEVEL,12) WHEN 0 THEN 'electronics' WHEN 1 THEN 'furniture' WHEN 2 THEN 'clothing' WHEN 3 THEN 'books' WHEN 4 THEN 'sports' WHEN 5 THEN 'beauty' WHEN 6 THEN 'food' WHEN 7 THEN 'toys' WHEN 8 THEN 'tools' WHEN 9 THEN 'garden' WHEN 10 THEN 'office' ELSE 'automotive' END,
    'Product_'||LEVEL,
    MOD(LEVEL*137,4950)+50, MOD(LEVEL*97,90)+10, MOD(LEVEL*53,45)+5, MOD(LEVEL*71,45)+5,
    ROUND(MOD(LEVEL*13,95)+5,2)
  FROM dual CONNECT BY LEVEL <= 50000;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Products done: 50000 rows');
END;
/

BEGIN
  INSERT INTO orders_demo (order_id, customer_id, order_status, order_date, order_approved_at, order_delivered_date, order_estimated_delivery, freight_value, total_amount)
  SELECT LEVEL,
    MOD(LEVEL,100000)+1,
    CASE WHEN LEVEL<=425000 THEN 'delivered' WHEN LEVEL<=450000 THEN 'shipped' WHEN LEVEL<=475000 THEN 'processing' WHEN LEVEL<=485000 THEN 'cancelled' WHEN LEVEL<=490000 THEN 'unavailable' WHEN LEVEL<=495000 THEN 'invoiced' ELSE 'created' END,
    DATE '2024-01-01'+MOD(LEVEL,600),
    DATE '2024-01-01'+MOD(LEVEL,600)+1,
    DATE '2024-01-01'+MOD(LEVEL,600)+MOD(LEVEL*3,17)+3,
    DATE '2024-01-01'+MOD(LEVEL,600)+10,
    ROUND(MOD(LEVEL*17,140)+10,2),
    ROUND(MOD(LEVEL*43,7000)+50,2)
  FROM dual CONNECT BY LEVEL <= 500000;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Orders done: 500000 rows');
END;
/

BEGIN
  INSERT INTO order_items_demo (order_id, item_no, product_id, seller_id, quantity, unit_price)
  SELECT order_id, item_no,
    MOD(order_id*item_no*37,50000)+1,
    MOD(order_id*item_no*13,5000)+1,
    MOD(order_id,5)+1,
    ROUND(MOD(order_id*item_no*97,2990)+10,2)
  FROM (SELECT LEVEL AS order_id FROM dual CONNECT BY LEVEL <= 500000)
  CROSS JOIN (SELECT 1 AS item_no FROM dual UNION ALL SELECT 2 FROM dual);
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Order items done: 1000000 rows');
END;
/

BEGIN
  INSERT INTO payments_demo (payment_id, order_id, payment_type, payment_installments, payment_value)
  SELECT LEVEL, LEVEL,
    CASE WHEN LEVEL<=300000 THEN 'credit_card' WHEN LEVEL<=375000 THEN 'debit_card' WHEN LEVEL<=450000 THEN 'boleto' ELSE 'voucher' END,
    CASE WHEN LEVEL<=300000 THEN MOD(LEVEL,12)+1 ELSE 1 END,
    ROUND(MOD(LEVEL*61,7980)+20,2)
  FROM dual CONNECT BY LEVEL <= 500000;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Payments done: 500000 rows');
END;
/

BEGIN
  INSERT INTO reviews_demo (review_id, order_id, review_score, review_comment, review_created, review_answered)
  SELECT LEVEL, LEVEL,
    CASE MOD(LEVEL,10) WHEN 0 THEN 1 WHEN 1 THEN 2 WHEN 2 THEN 3 WHEN 3 THEN 4 WHEN 4 THEN 4 ELSE 5 END,
    CASE MOD(LEVEL,5) WHEN 0 THEN NULL WHEN 1 THEN 'Great product!' WHEN 2 THEN 'Good quality' WHEN 3 THEN 'Expected better' ELSE 'Not satisfied' END,
    DATE '2024-01-01'+MOD(LEVEL,600)+MOD(LEVEL*3,17)+5,
    DATE '2024-01-01'+MOD(LEVEL,600)+MOD(LEVEL*3,17)+8
  FROM dual CONNECT BY LEVEL <= 400000;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Reviews done: 400000 rows');
END;
/

PROMPT === 4. Add Foreign Keys ===
ALTER TABLE orders_demo      ADD CONSTRAINT fk_ord_cust  FOREIGN KEY (customer_id) REFERENCES customers_demo(customer_id);
ALTER TABLE order_items_demo ADD CONSTRAINT fk_item_ord  FOREIGN KEY (order_id)    REFERENCES orders_demo(order_id);
ALTER TABLE order_items_demo ADD CONSTRAINT fk_item_prod FOREIGN KEY (product_id)  REFERENCES products_demo(product_id);
ALTER TABLE order_items_demo ADD CONSTRAINT fk_item_sell FOREIGN KEY (seller_id)   REFERENCES sellers_demo(seller_id);
ALTER TABLE payments_demo    ADD CONSTRAINT fk_pay_ord   FOREIGN KEY (order_id)    REFERENCES orders_demo(order_id);
ALTER TABLE reviews_demo     ADD CONSTRAINT fk_rev_ord   FOREIGN KEY (order_id)    REFERENCES orders_demo(order_id);
PROMPT FK added

PROMPT === 5. Create Indexes ===
CREATE INDEX idx_orders_customer ON orders_demo(customer_id);
CREATE INDEX idx_orders_status   ON orders_demo(order_status);
CREATE INDEX idx_orders_date     ON orders_demo(order_date);
CREATE INDEX idx_items_product   ON order_items_demo(product_id);
CREATE INDEX idx_items_seller    ON order_items_demo(seller_id);
CREATE INDEX idx_payments_order  ON payments_demo(order_id);
CREATE INDEX idx_payments_type   ON payments_demo(payment_type);
CREATE INDEX idx_reviews_order   ON reviews_demo(order_id);
CREATE INDEX idx_reviews_score   ON reviews_demo(review_score);
CREATE INDEX idx_customers_seg   ON customers_demo(customer_segment);
CREATE INDEX idx_products_cat    ON products_demo(product_category);
PROMPT Indexes created

PROMPT === 6. Gather Statistics ===
BEGIN
  FOR t IN (SELECT table_name FROM user_tables ORDER BY table_name) LOOP
    DBMS_STATS.GATHER_TABLE_STATS(USER, t.table_name, cascade=>TRUE, method_opt=>'FOR ALL COLUMNS SIZE AUTO');
    DBMS_OUTPUT.PUT_LINE('Stats: '||t.table_name||' done');
  END LOOP;
END;
/

PROMPT === 7. Verification ===
SELECT 'SELLERS_DEMO'     AS table_name, COUNT(*) AS row_count FROM sellers_demo     UNION ALL
SELECT 'CUSTOMERS_DEMO',                 COUNT(*)              FROM customers_demo    UNION ALL
SELECT 'PRODUCTS_DEMO',                  COUNT(*)              FROM products_demo     UNION ALL
SELECT 'ORDERS_DEMO',                    COUNT(*)              FROM orders_demo       UNION ALL
SELECT 'ORDER_ITEMS_DEMO',               COUNT(*)              FROM order_items_demo  UNION ALL
SELECT 'PAYMENTS_DEMO',                  COUNT(*)              FROM payments_demo     UNION ALL
SELECT 'REVIEWS_DEMO',                   COUNT(*)              FROM reviews_demo;

PROMPT Setup complete!
