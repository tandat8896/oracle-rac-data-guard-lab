# STEP 17: Quy trình Khởi động & Tắt hệ thống Oracle RAC có Fast-Start Failover (FSFO)

Khi hệ thống đã được cấu hình Data Guard Broker và bật tính năng tự động chuyển đổi (Fast-Start Failover), trình tự tắt/bật các máy là cực kỳ quan trọng để tránh việc Data Guard hiểu lầm là có sự cố và tự động Failover ngoài ý muốn.

Dưới đây là cẩm nang Startup/Shutdown an toàn dành cho homelab.

---

## 🔴 QUY TRÌNH SHUTDOWN (TẮT HỆ THỐNG)

**Nguyên tắc vàng:** Phải vô hiệu hóa "mắt thần" giám sát (Observer) trước khi tắt database chính (Primary). Vì Observer đang chạy ngầm trên máy Standby, cách lười nhất và an toàn nhất là tắt cụm Standby trước.

### Bước 1: Tắt máy Standby (`stdby1`) TRƯỚC
Việc này sẽ đóng luôn tiến trình Observer, khiến hệ thống không thể tự động failover (đảo chính) được nữa.
1. SSH vào máy Standby.
2. Tắt database:
   ```bash
   sudo su - oracle
   sqlplus / as sysdba
   SQL> shutdown immediate;
   SQL> exit;
   ```
3. Tắt máy ảo (VM) Standby trên máy host (ví dụ: `virsh shutdown stdby1`).

### Bước 2: Tắt cụm RAC Primary (`rac1`, `rac2`) SAU
Lúc này Standby và Observer đã tắt, hệ thống Primary chạy độc lập nên tắt rất an toàn.
1. SSH vào máy `rac1` (hoặc `rac2`).
2. Dùng lệnh srvctl để tắt toàn bộ database trên các node:
   ```bash
   sudo su - oracle
   srvctl stop database -d racdb
   ```
   *(Hoặc bạn có thể dùng `shutdown immediate` trong SQL*Plus trên từng node).*
3. Tắt các máy ảo `rac1`, `rac2`.

---

## 🟢 QUY TRÌNH STARTUP (BẬT HỆ THỐNG)

**Nguyên tắc vàng:** Bật máy chính (Primary) lên cho nó phục vụ trước, sau đó mới bật máy dự phòng (Standby) lên để nó tự động chắp vá/đồng bộ dữ liệu bị thiếu trong lúc ngủ.

### Bước 1: Bật cụm RAC Primary (`rac1`, `rac2`) LÊN TRƯỚC
1. Bật máy ảo `rac1` (và `rac2` nếu muốn chạy đầy đủ 2 node).
2. Oracle Grid Infrastructure (Clusterware) thường được cấu hình tự động chạy khi OS khởi động.
3. Chờ khoảng 3-5 phút, sau đó kiểm tra xem database đã Open chưa:
   ```bash
   sudo su - grid
   crsctl stat res -t
   ```
   Nếu thấy database `ora.racdb.db` có trạng thái `ONLINE` trên node tương ứng, tức là đã thành công. (Hoặc bạn có thể tự `srvctl start database -d racdb`).

### Bước 2: Bật máy Standby (`stdby1`) LÊN SAU
1. Bật máy ảo `stdby1`.
2. SSH vào `stdby1` và khởi động Database lên trạng thái **MOUNT**:
   ```bash
   sudo su - oracle
   sqlplus / as sysdba
   SQL> startup mount;
   SQL> exit;
   ```
3. **CỰC KỲ QUAN TRỌNG:** Phải đảm bảo dịch vụ Listener đang chạy để Standby có thể nhận log từ Primary. Nếu bị lỗi `ORA-12541: TNS:no listener`, hãy bật Listener lên:
   ```bash
   lsnrctl start
   ```
4. Bật lại tiến trình Observer chạy nền (để nó tiếp tục làm vệ sĩ canh gác hệ thống):
   ```bash
   nohup dgmgrl sys/<REDACTED_PASSWORD>@racdb "start observer" > /home/oracle/observer.log 2>&1 &
   ```

### Bước 3: Kiểm tra tổng thể sức khỏe
Tại máy `stdby1` (hoặc `rac1`), dùng công cụ DGMGRL để khám bệnh tổng quát:
```bash
dgmgrl sys/<REDACTED_PASSWORD>@racdb
```

Bên trong DGMGRL, gõ lần lượt các lệnh sau:
1. **Xem tổng quát cụm:** 
   `DGMGRL> show configuration;` 
   *(Cần thấy `SUCCESS` dưới cùng)*
2. **Xem tiến trình tự động Failover đã cắm rễ chưa:** 
   `DGMGRL> show fast_start failover;` 
   *(Cần thấy `Enabled` và `Observer: stdby1`)*
3. **Xem chi tiết độ trễ đồng bộ của Standby:** 
   `DGMGRL> show database racdb_s;` 
   *(Cần thấy `Transport Lag: 0 seconds` và `Apply Lag: 0 seconds`)*

Nếu tất cả đều xanh, xin chúc mừng, hệ thống đã trở lại vòng quay hoàn hảo!

---

## ⚡ TỰ ĐỘNG HOÁ BẰNG SCRIPT TRÊN HOST NIXOS

Nếu không muốn thao tác thủ công từng bước qua SSH, trên Host NixOS đã có sẵn 2 script quản trị tự động theo đúng tiêu chuẩn an toàn:

1. **Tắt an toàn toàn bộ cụm (Oracle RAC + Standby + BigData):**
   ```bash
   /home/tandat/Desktop/de_lab/stop_an_toan.sh all
   ```
   *Script tự động:* Dừng Observer -> Shutdown database Standby -> Dừng cluster database `racdb` qua `srvctl` -> Tắt VM an toàn và kiểm tra `shut off` qua `virsh list`.

2. **Khởi động an toàn:**
   ```bash
   /home/tandat/Desktop/de_lab/start_oracle.sh
   ```
   *Script tự động:* Khởi động Primary RAC nodes -> Chờ Clusterware & ASM online -> Khởi động Standby VM & MOUNT instance -> Kiểm tra Listener & Data Guard Broker.
