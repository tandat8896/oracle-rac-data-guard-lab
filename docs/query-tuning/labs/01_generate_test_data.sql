-- =====================================================================
-- KỊCH BẢN TẠO DỮ LIỆU LỚN CHO ORACLE RAC QUERY TUNING (DỄ GÕ TAY)
-- =====================================================================
-- File này bao gồm toàn bộ cấu trúc chuẩn xác mà bạn đã tạo, 
-- kèm theo lệnh INSERT rút gọn để dễ dàng nhập tay trên Terminal.

-- 1. Xóa bảng cũ (nếu muốn làm lại từ đầu)
-- DROP TABLE orders_demo PURGE;

-- 2. Tạo bảng Orders Demo (Khớp 100% với cấu trúc bạn đã gõ)
CREATE TABLE orders_demo (
    order_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id   NUMBER NOT NULL,
    order_date    DATE NOT NULL,
    order_status  VARCHAR2(20),
    total_amount  NUMBER(10,2),
    region_code   VARCHAR2(5)
) 
-- CÁC THAM SỐ TỐI ƯU CHO ORACLE RAC
INITRANS 10       
PCTFREE 20        
NOLOGGING         
;

-- 3. Chèn 100.000 dòng dữ liệu giả lập (Phiên bản siêu ngắn gọn, dễ gõ)
INSERT /*+ APPEND */ INTO orders_demo (
    customer_id, order_date, order_status, total_amount, region_code
)
SELECT 
    MOD(level, 5000) + 1,                          -- customer_id (1 đến 5000)
    SYSDATE - MOD(level, 365),                     -- order_date (random trong 1 năm)
    CASE WHEN MOD(level, 10) = 0 
         THEN 'CANCELLED' ELSE 'COMPLETED' END,    -- order_status (10% CANCELLED)
    MOD(level, 1000),                              -- total_amount
    'VN'                                           -- region_code
FROM dual
CONNECT BY level <= 100000;

COMMIT;

-- 4. Thu thập Statistics (Rất quan trọng trong Tuning)
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'ORDERS_DEMO');

-- =====================================================================
-- KIỂM TRA LẠI DỮ LIỆU
-- =====================================================================
-- SELECT COUNT(*) FROM orders_demo;
-- SELECT order_status, COUNT(*) FROM orders_demo GROUP BY order_status;
