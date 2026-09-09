# STEP 16: Troubleshooting Data Guard Broker & Fast-Start Failover (FSFO)

Tài liệu này ghi chú lại các lỗi cấu hình trong quá trình cài đặt Oracle Data Guard Broker và Fast-Start Failover (FSFO), cùng với raw output và từng dòng lệnh CLI để khắc phục triệt để.

---

## Issue 1: OS User Missing Oracle Group Permissions

**Tình trạng (Raw Output):**
User `tandat` có quyền sudo nhưng không thuộc các group của Oracle (`oinstall`, `dba`), dẫn đến không chạy được file `oracle` có setuid/setgid hoặc bị hạn chế khi quản trị.
```text
$ ls -la $ORACLE_HOME/bin/orapwd
-rwxr-x--x. 1 oracle oinstall 152208 Jun 16 16:09 /u01/app/oracle/product/19.0.0/dbhome_1/bin/orapwd

$ ls -la $ORACLE_HOME/bin/oracle
-rwsr-s--x. 1 oracle oinstall 441159432 Jun 16 16:10 /u01/app/oracle/product/19.0.0/dbhome_1/bin/oracle

$ id
uid=1000(tandat) gid=1000(tandat) groups=1000(tandat),10(wheel) context=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
```

**Cách khắc phục:**
Add user `tandat` vào group `oinstall` và `dba` để có toàn quyền quản trị bằng OS Authentication.
```bash
sudo usermod -aG oinstall,dba tandat
```
*(Cần logout và login lại SSH để group mới có hiệu lực).*

---

## Issue 2: Data Guard Broker báo lỗi ORA-1017, ORA-1033 và ORA-16664

**Tình trạng (Raw Output):**
Trạng thái Configuration của Data Guard Broker báo lỗi (ERROR). Primary không thể giao tiếp và đồng bộ trạng thái với Standby.
```text
DGMGRL> show configuration

Configuration - dgconfig

  Protection Mode: MaxPerformance
  Members:
  racdb   - Primary database
    Error: ORA-16810: multiple errors or warnings detected for the member

    racdb_s - Physical standby database 
      Error: ORA-1033: ORACLE initialization or shutdown in progress
      # Hoặc đôi khi hiển thị: Error: ORA-1017: invalid username/password; logon denied

Fast-Start Failover:  Disabled

Configuration Status:
ERROR   (status updated 9 seconds ago)
```

**Nguyên nhân gốc rễ (Root Cause):**
1. **Thiếu Static Listener (`_DGMGRL`):** Broker không thể kết nối tới Standby khi instance đang ở trạng thái NOMOUNT/MOUNT hoặc trong quá trình restart (Failover/Switchover), trả về lỗi `ORA-1033`.
2. **Password File không được copy dạng Binary:** Kể cả khi hai máy tự chạy lệnh `orapwd` với chung một mật khẩu `<REDACTED_PASSWORD>`, mã hash sinh ra (salt) vẫn khác nhau. Primary sẽ báo sai mật khẩu (`ORA-1017`) khi cố kết nối tới Standby dưới quyền SYS/SYSDG.

### Khắc phục Bước 1: Cấu hình Static Listener cho Standby
Chỉnh sửa file `listener.ora` trên máy Standby (`stdby1`):
```bash
sudo su - oracle
vi $ORACLE_HOME/network/admin/listener.ora
```

Thêm khối cấu hình `SID_LIST` dành riêng cho `_DGMGRL`:
```text
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = racdb_s_DGMGRL)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = racdb_s)
    )
  )
```

Reload lại Listener:
```bash
lsnrctl reload
```

### Khắc phục Bước 2: Copy Password file từ ASM (Primary) qua Standby
Trên máy Primary (`rac1`), trích xuất password file từ ổ đĩa chung ASM và chép qua Standby bằng SCP.

```bash
# 1. Tại máy Primary (rac1), dùng user grid:
sudo su - grid
asmcmd ls -l +DATA/RACDB/PASSWORD/
# Ghi nhận tên file, ví dụ: pwdracdb.256.1234363179

# Chép ra phân vùng thường /tmp
asmcmd pwcopy +DATA/RACDB/PASSWORD/pwdracdb.256.1234363179 /tmp/orapwracdb_s
exit

# 2. Dùng user oracle bắn file sang máy Standby (stdby1 - IP 192.168.122.220):
sudo su - oracle
scp /tmp/orapwracdb_s oracle@192.168.122.220:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwracdb_s
```

### Khắc phục Bước 3: Áp dụng cấu hình và Enable Data Guard Broker
Trên máy Standby (`stdby1`), khởi động lại database để nhận password file mới.
```bash
sudo su - oracle
sqlplus / as sysdba
SQL> shutdown immediate;
SQL> startup mount;
SQL> exit;
```

Dùng `dgmgrl` (từ Primary hoặc Standby đều được) để enable database và check trạng thái.
```bash
dgmgrl sys/<REDACTED_PASSWORD>@racdb

DGMGRL> enable database racdb_s;
DGMGRL> show configuration;
```

**Kết quả thành công (Raw Output):**
```text
Configuration - dgconfig

  Protection Mode: MaxPerformance
  Members:
  racdb   - Primary database
    racdb_s - Physical standby database 

Fast-Start Failover:  Disabled

Configuration Status:
SUCCESS   (status updated 27 seconds ago)
```

*(Sau khi status chuyển thành `SUCCESS`, bạn đã có thể bật Fast-Start Failover bằng lệnh `enable fast_start failover;` và khởi chạy Observer).*
