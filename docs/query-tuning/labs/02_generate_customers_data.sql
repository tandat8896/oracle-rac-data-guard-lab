-- =====================================================================
-- KỊCH BẢN TẠO BẢNG CUSTOMERS CHO BÀI TẬP JOIN TUNING (DỄ GÕ TAY)
-- =====================================================================

-- 1. Tạo bảng (Ngắn gọn & Tối ưu cho RAC)
CREATE TABLE customers_demo (
    customer_id    NUMBER PRIMARY KEY,
    customer_name  VARCHAR2(50),
    membership_lvl VARCHAR2(20)
) INITRANS 10 NOLOGGING;

-- 2. Chèn 5000 khách hàng (Trùng khớp với số customer_id trong bảng orders)
INSERT /*+ APPEND */ INTO customers_demo
SELECT level,
       'Customer_' || level,
       CASE WHEN MOD(level, 100) = 0 THEN 'PLATINUM' 
            WHEN MOD(level, 10) = 0 THEN 'GOLD' 
            ELSE 'STANDARD' END
FROM dual
CONNECT BY level <= 5000;

COMMIT;

-- 3. Cạm bẫy "Sát thủ": Khóa ngoại không có Index
ALTER TABLE orders_demo 
ADD CONSTRAINT fk_orders_cust 
FOREIGN KEY (customer_id) REFERENCES customers_demo(customer_id);

-- 4. Bắt buộc: Cập nhật thống kê
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'CUSTOMERS_DEMO');
