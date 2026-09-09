# node_files — file lấy từ các node RAC về host

Snapshot các file text đang dùng trên `rac1`, `rac2`, `stdby1`, kéo về bằng
`../tools/pull_from_nodes.sh` để lưu vào repo (làm tài liệu, không phải để chạy trực tiếp).

Môi trường: **Oracle Linux 9.7**, kernel UEK `6.12.0-202.76.4.3.el9uek`, Oracle 19c RAC.

## Cấu trúc

```
node_files/<node>/
  scripts/         # script tự viết (*.sql, *.sh, *.py, *.rman) + .bash_profile/.bashrc
                   # của root/oracle/grid/user — chỗ set ORACLE_HOME, ORACLE_SID, PATH
  config/          # listener.ora, tnsnames.ora, sqlnet.ora, init*.ora, oratab, hosts,
                   # fstab, oraInst.loc, sysctl.d, limits.d, udev rules ASM,
                   # systemd unit tự tạo (oracle-ohasd.service), sshd_config.d,
                   # NetworkManager (enp1s0 public / enp2s0 private interconnect)
  oracle_install/  # artifact của bộ cài: root.sh, orainstRoot.sh, rootcrs.sh, roothas.sh,
                   # gridSetup.sh, runInstaller, runcluvfy.sh, cvu_config, orabasetab,
                   # response file (gridsetup.rsp, db_install.rsp + bản .rsp thực tế đã dùng),
                   # ins_rdbms.mk / env_rdbms.mk (dùng khi relink)
  osinfo/          # os.txt (os-release + kernel + cpu/mem), rpm-qa.txt, lsblk.txt,
                   # ip-addr.txt, opatch-*.txt (patch level), crs-status.txt
  history/         # .bash_history của root/oracle/grid/user — bản ghi thật các lệnh đã chạy
```

Đường dẫn gốc trên node được giữ nguyên bên trong mỗi section, ví dụ
`rac1/oracle_install/u01/app/19.0.0/grid/root.sh` ⇒ `/u01/app/19.0.0/grid/root.sh` trên rac1.

## Cập nhật lại

```bash
./tools/pull_from_nodes.sh          # tất cả node đang bật
./tools/pull_from_nodes.sh rac2     # chỉ 1 node
```

Node đang tắt sẽ bị bỏ qua. Mỗi lần chạy sẽ **ghi đè** thư mục của node đó.

Collector chỉ đọc (`cp -p`), **không đổi quyền/owner file gốc trên VM**; phần
`chown/chmod` chỉ áp lên bản sao tạm trong `/tmp/rac_pull_<host>/`, xong thì xoá.

## Password

`tools/redact.sh` chạy tự động cuối mỗi lần pull:

- **mọi file**: thay chuỗi password lab đã biết bằng `REDACTED`
- **chỉ `history/` và `scripts/`**: thêm luật regex cho `user/pass@tns`,
  `IDENTIFIED BY`, `-sysPassword`, `mkstore -createCredential`, `PASSWORD=`
- **`oracle_install/` không bị regex đụng vào** — file gốc của Oracle phải giữ
  nguyên byte (ví dụ `ORAPWD=$(RDBMSBIN)orapwd` là tên binary, không phải password)

Đổi password lab thì thêm chuỗi mới vào mảng `KNOWN` trong `tools/redact.sh`.
Kiểm tra trước khi push:

```bash
grep -rniE "passw|identified by" node_files | grep -v REDACTED
```

## Lưu ý khi khôi phục

Git chỉ giữ nội dung + bit execute, **không giữ owner/group** (`grid:oinstall`,
`oracle:oinstall`, `root:oinstall`). Nếu copy ngược lên node phải tự `chown`/`chmod`
lại theo đúng quyền gốc — xem `ls -la` tương ứng trong `history/` hoặc STEP-*.md.
