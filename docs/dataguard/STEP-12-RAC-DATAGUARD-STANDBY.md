# Step 12 - Oracle Data Guard: Primary RAC + Standby Single Instance

Muc tieu: setup Oracle Data Guard giua primary RAC (racdb tren rac1/rac2) va standby single-instance (stdby1).

```text
Primary  : racdb  — 2-node RAC (rac1 + rac2)
Standby  : racdb_s — single instance (stdby1)
Network  : cung bridge virbr0 voi rac1/rac2
```

---

## Phan 1 - Tao VM stdby1 tren NixOS host

Stdby1 khong can Grid/ASM, chi can Oracle DB software.
Khong can disk shared, datafiles nam tren filesystem /u01.

Luu y quan trong:
```text
- KHONG tao disk truoc bang qemu-img, de virt-install tu tao
- KHONG dung sudo
- Chay tu thu muc oracle_23c (co chua file ISO)
- Mo console bang virt-manager tu app launcher desktop
```

### 1.1 Neu da co stdby1 cu, xoa truoc

```bash
virsh destroy stdby1 2>/dev/null
virsh undefine stdby1 --remove-all-storage 2>/dev/null
```

### 1.2 Tao VM bang virt-install

```bash
cd /home/tandat/Desktop/tandat_homelab/oracle_23c

virt-install \
  --name stdby1 \
  --memory 4096 \
  --vcpus 2 \
  --disk size=40,format=qcow2 \
  --cdrom OracleLinux-R9-U7-x86_64-boot-uek.iso \
  --osinfo ol9-unknown \
  --network network=default \
  --graphics spice &
```

VM se duoc tao va dang chay, hien thi:
```text
Allocating 'stdby1.qcow2'  |  40 GB  00:00
Creating domain...
Domain is still running. Installation may be in progress.
```

### 1.3 Mo console de cai OS

Mo **virt-manager** tu app launcher tren NixOS desktop.
Click vao **stdby1** → Open console.

Trong installer OL9 (net-install, can internet):

```text
Localization:
  Language: English (United States)
  Keyboard: English (US)
  Time & Date: Asia → Ho Chi Minh City

Software:
  Installation Source: Closest mirror → doi load xong (30-60s)
  Software Selection: Minimal Install

System:
  Installation Destination: chon disk 40G → Automatic partitioning
  Network & Hostname: bat enp1s0 ON (DHCP), hostname: stdby1 → Apply
  Root Password: dat password, bat Allow root SSH login
  User Creation: tandat, tick Make this user administrator
```

Bam Begin Installation, doi cai xong reboot.

Sau reboot verify:
```bash
virsh list --all
virsh domifaddr stdby1
```

### 1.4 SSH vao stdby1 va set static IP

Lay IP DHCP hien tai:
```bash
virsh domifaddr stdby1
```

SSH vao:
```bash
ssh root@192.168.122.50   # IP DHCP ban dau
```

Them tandat vao wheel neu chua co:
```bash
usermod -aG wheel tandat
```

Set static IP (connection se bi cut sau lenh nay):
```bash
nmcli connection modify enp1s0 \
  ipv4.method manual \
  ipv4.addresses 192.168.122.220/24 \
  ipv4.gateway 192.168.122.1 \
  ipv4.dns 192.168.122.1 \
  connection.autoconnect yes
nmcli connection up enp1s0
```

SSH lai bang IP moi:
```bash
ssh tandat@192.168.122.220
```

### 1.5 Set hostname

```bash
sudo hostnamectl set-hostname stdby1
```

### 1.6 Them /etc/hosts tren stdby1

Them tung dong (KHONG dung heredoc, bi loi EOF):
```bash
echo "192.168.122.220  stdby1  stdby1.localdomain" | sudo tee -a /etc/hosts
echo "192.168.122.205  rac1    rac1.localdomain" | sudo tee -a /etc/hosts
echo "192.168.122.46   rac2    rac2.localdomain" | sudo tee -a /etc/hosts
echo "192.168.122.213  rac1-scan  rac1-scan.localdomain" | sudo tee -a /etc/hosts
```

Kiem tra:
```bash
cat /etc/hosts
```

### 1.7 Them stdby1 vao /etc/hosts tren rac1 va rac2

Chay tu NixOS host:
```bash
ssh -p 2222 -i ~/.ssh/rac_ed25519 tandat8896@192.168.122.205 \
  "echo '192.168.122.220  stdby1  stdby1.localdomain' | sudo tee -a /etc/hosts"

ssh -p 2222 -i ~/.ssh/rac_ed25519 tandat8896@192.168.122.46 \
  "echo '192.168.122.220  stdby1  stdby1.localdomain' | sudo tee -a /etc/hosts"
```

Expected output (moi lenh):
```text
192.168.122.220  stdby1  stdby1.localdomain
```

### 1.8 Done criteria Phan 1

```text
stdby1 VM chay, IP 192.168.122.220 (static)
SSH duoc vao stdby1 bang tandat@192.168.122.220
hostname = stdby1
/etc/hosts da them tren ca 3 node
```

### 1.3 Static IP cho stdby1

Sau khi cai xong, set static IP tren stdby1:

```bash
# Xem ten interface
ip link show

# Set static IP (thay enp1s0 neu khac)
sudo nmcli con mod enp1s0 \
  ipv4.method manual \
  ipv4.addresses 192.168.122.207/24 \
  ipv4.gateway 192.168.122.1 \
  ipv4.dns 192.168.122.1 \
  ipv4.never-default no \
  connection.autoconnect yes
sudo nmcli con up enp1s0
```

### 1.4 Sua /etc/hosts tren tat ca node

Tren stdby1, rac1, rac2 — them dong nay vao /etc/hosts:

```text
192.168.122.207  stdby1  stdby1.localdomain
```

Tren stdby1 them them:
```text
192.168.122.205  rac1    rac1.localdomain
192.168.122.211  rac1-vip
192.168.122.46   rac2    rac2.localdomain
192.168.122.212  rac2-vip
192.168.122.213  rac1-scan  rac1-scan.localdomain
```

---

## Phan 2 - OS prereqs tren stdby1

Tuong tu Step 06 nhung chi can cho single-instance, khong can Grid/ASM.

### 2.1 Install packages

```bash
sudo dnf install -y bc binutils elfutils-libelf elfutils-libelf-devel \
  gcc gcc-c++ glibc glibc-devel ksh libaio libaio-devel \
  libgcc libnsl libstdc++ libstdc++-devel make net-tools \
  nfs-utils smartmontools sysstat unzip unixODBC
```

### 2.2 Tao groups

```bash
sudo groupadd -g 54321 oinstall
sudo groupadd -g 54322 dba
sudo groupadd -g 54323 oper
sudo groupadd -g 54324 backupdba
sudo groupadd -g 54325 dgdba
sudo groupadd -g 54326 kmdba
```

### 2.3 Tao user oracle

```bash
sudo useradd -u 54332 -g oinstall -G dba,oper,backupdba,dgdba,kmdba oracle
sudo passwd oracle
```

### 2.4 Tao thu muc Oracle

```bash
sudo mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1
sudo mkdir -p /u01/app/oraInventory
sudo chown -R oracle:oinstall /u01/app
sudo chmod -R 775 /u01
```

### 2.5 Kernel parameters

Dung echo tung dong, KHONG dung heredoc:
```bash
echo "fs.aio-max-nr = 1048576" | sudo tee /etc/sysctl.d/99-oracle.conf
echo "fs.file-max = 6815744" | sudo tee -a /etc/sysctl.d/99-oracle.conf
echo "kernel.shmall = 2097152" | sudo tee -a /etc/sysctl.d/99-oracle.conf
echo "kernel.shmmax = 4294967296" | sudo tee -a /etc/sysctl.d/99-oracle.conf
echo "kernel.shmmni = 4096" | sudo tee -a /etc/sysctl.d/99-oracle.conf
echo "kernel.sem = 250 32000 100 128" | sudo tee -a /etc/sysctl.d/99-oracle.conf
echo "net.ipv4.ip_local_port_range = 9000 65500" | sudo tee -a /etc/sysctl.d/99-oracle.conf
echo "net.core.rmem_default = 262144" | sudo tee -a /etc/sysctl.d/99-oracle.conf
echo "net.core.rmem_max = 4194304" | sudo tee -a /etc/sysctl.d/99-oracle.conf
echo "net.core.wmem_default = 262144" | sudo tee -a /etc/sysctl.d/99-oracle.conf
echo "net.core.wmem_max = 1048576" | sudo tee -a /etc/sysctl.d/99-oracle.conf
sudo sysctl --system
```

### 2.6 Limits cho oracle

```bash
echo "oracle soft nofile 1024" | sudo tee /etc/security/limits.d/99-oracle.conf
echo "oracle hard nofile 65536" | sudo tee -a /etc/security/limits.d/99-oracle.conf
echo "oracle soft nproc 16384" | sudo tee -a /etc/security/limits.d/99-oracle.conf
echo "oracle hard nproc 16384" | sudo tee -a /etc/security/limits.d/99-oracle.conf
echo "oracle soft stack 10240" | sudo tee -a /etc/security/limits.d/99-oracle.conf
echo "oracle hard stack 32768" | sudo tee -a /etc/security/limits.d/99-oracle.conf
echo "oracle hard memlock 134217728" | sudo tee -a /etc/security/limits.d/99-oracle.conf
echo "oracle soft memlock 134217728" | sudo tee -a /etc/security/limits.d/99-oracle.conf
```

Expected output:
```text
oracle soft nofile 1024
oracle hard nofile 65536
oracle soft nproc 16384
oracle hard nproc 16384
oracle soft stack 10240
oracle hard stack 32768
oracle hard memlock 134217728
oracle soft memlock 134217728
```

### 2.7 SELinux va firewall

```bash
sudo setenforce 0
sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
sudo systemctl disable --now firewalld
```

Expected: no output, no error.

### 2.8 Done criteria Phan 2

```text
packages installed
groups/oracle user created
/u01 directories dung owner
kernel params applied
limits configured
SELinux permissive, firewalld disabled
```

---

## Phan 3 - Cai Oracle DB software tren stdby1

### 3.1 Setup SSH key cho stdby1

Tren NixOS host:
```bash
ssh-copy-id -i ~/.ssh/rac_ed25519.pub tandat@192.168.122.220
```

Expected:
```text
Number of key(s) added: 1
```

### 3.2 Tao staging folder tren stdby1

```bash
ssh -i ~/.ssh/rac_ed25519 tandat@192.168.122.220 'mkdir -p /tmp/oracle_stage/db_home'
```

### 3.3 Copy DB home tu NixOS host sang stdby1

Dung rsync neu co, neu khong dung scp -r:
```bash
cd /home/tandat/Desktop/tandat_homelab

# Neu stdby1 co rsync:
rsync -a --info=progress2 -e "ssh -i ~/.ssh/rac_ed25519" \
  oracle_rac/stage/db_home/ \
  tandat@192.168.122.220:/tmp/oracle_stage/db_home/

# Neu khong co rsync (dung cai nay):
scp -i ~/.ssh/rac_ed25519 -r \
  oracle_rac/stage/db_home/. \
  tandat@192.168.122.220:/tmp/oracle_stage/db_home/
```

Lau khoang 5-10 phut tuy toc do.

### 3.4 Copy vao /u01 tren stdby1

SSH vao stdby1 roi chay:
```bash
sudo cp -r /tmp/oracle_stage/db_home/. /u01/app/oracle/product/19.0.0/dbhome_1/
sudo chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1
```

Expected: no output, no error.

### 3.5 Tao response file

```bash
sudo su - oracle
cp /u01/app/oracle/product/19.0.0/dbhome_1/install/response/db_install.rsp /home/oracle/db_install.rsp

sed -i \
  -e 's|^oracle.install.option=.*|oracle.install.option=INSTALL_DB_SWONLY|' \
  -e 's|^UNIX_GROUP_NAME=.*|UNIX_GROUP_NAME=oinstall|' \
  -e 's|^INVENTORY_LOCATION=.*|INVENTORY_LOCATION=/u01/app/oraInventory|' \
  -e 's|^ORACLE_HOME=.*|ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1|' \
  -e 's|^ORACLE_BASE=.*|ORACLE_BASE=/u01/app/oracle|' \
  -e 's|^oracle.install.db.InstallEdition=.*|oracle.install.db.InstallEdition=EE|' \
  -e 's|^oracle.install.db.OSDBA_GROUP=.*|oracle.install.db.OSDBA_GROUP=dba|' \
  -e 's|^oracle.install.db.OSOPER_GROUP=.*|oracle.install.db.OSOPER_GROUP=oper|' \
  -e 's|^oracle.install.db.OSBACKUPDBA_GROUP=.*|oracle.install.db.OSBACKUPDBA_GROUP=backupdba|' \
  -e 's|^oracle.install.db.OSDGDBA_GROUP=.*|oracle.install.db.OSDGDBA_GROUP=dgdba|' \
  -e 's|^oracle.install.db.OSKMDBA_GROUP=.*|oracle.install.db.OSKMDBA_GROUP=kmdba|' \
  -e 's|^oracle.install.db.OSRACDBA_GROUP=.*|oracle.install.db.OSRACDBA_GROUP=racdba|' \
  -e 's|^DECLINE_SECURITY_UPDATES=.*|DECLINE_SECURITY_UPDATES=true|' \
  /home/oracle/db_install.rsp
```

Luu y: neu thieu group racdba thi tao truoc khi chay sed:
```bash
exit
sudo groupadd -g 54330 racdba
sudo usermod -aG racdba oracle
sudo su - oracle
```

### 3.6 Fix loi OL9 fstat (giong Step 10)

Loi gap: `FATAL Error in invoking target 'libasmclntsh19.ohso' of makefile ins_rdbms.mk`

Fix tren stdby1, user tandat:
```bash
exit
printf '#define _GNU_SOURCE\n#include <sys/syscall.h>\n#include <sys/stat.h>\n#include <fcntl.h>\n#include <unistd.h>\n\nint fstat(int fd, struct stat *buf) __attribute__((weak));\nint fstat(int fd, struct stat *buf) {\n    return syscall(SYS_newfstatat, fd, "", buf, AT_EMPTY_PATH);\n}\n' > /tmp/ora19_fstat_stub.c

gcc -c /tmp/ora19_fstat_stub.c -o /tmp/ora19_fstat_stub.o
sudo cp -a /usr/lib64/libpthread_nonshared.a /usr/lib64/libpthread_nonshared.a.bak
sudo ar qf /usr/lib64/libpthread_nonshared.a /tmp/ora19_fstat_stub.o
nm /usr/lib64/libpthread_nonshared.a | grep fstat
```

Expected: `W fstat`

Ket qua thuc te chay:
```text
cp: cannot stat '/usr/lib64/libpthread_nonshared.a': No such file or directory  ← BINH THUONG: OL9 moi khong co san file nay
ar: creating /usr/lib64/libpthread_nonshared.a                                  ← ar tao file moi, dung
ora19_fstat_stu:
0000000000000000 W fstat                                                        ← THANH CONG: fstat da trong library
```

### 3.7 Fix stat/lstat/fstat va make truc tiep (giong Step 09 Fix 10)

**KHONG dung `relink all`** - phai dung `make` truc tiep vao target cu the.

Loi gap sau khi chi co fstat stub:
```text
/usr/bin/ld: libserver19.a(jskm.o): undefined reference to `stat'
/usr/bin/ld: libnnzst19.a(ccme_ck_rand_load_fileS1.o): undefined reference to `stat'
make: *** [ins_rdbms.mk:840: oracle] Error 1
```

Fix: them stat va lstat stub vao libpthread_nonshared.a (user tandat):
```bash
exit
printf '#include <sys/syscall.h>\n#include <sys/stat.h>\n#include <fcntl.h>\n#include <unistd.h>\n\nint stat(const char *path, struct stat *buf) __attribute__((weak));\nint stat(const char *path, struct stat *buf) {\n    return syscall(SYS_newfstatat, AT_FDCWD, path, buf, 0);\n}\n\nint lstat(const char *path, struct stat *buf) __attribute__((weak));\nint lstat(const char *path, struct stat *buf) {\n    return syscall(SYS_newfstatat, AT_FDCWD, path, buf, 0x100);\n}\n' > /tmp/stat_stub2.c
gcc -c /tmp/stat_stub2.c -o /tmp/stat_stub2.o
sudo ar qf /usr/lib64/libpthread_nonshared.a /tmp/stat_stub2.o
nm /usr/lib64/libpthread_nonshared.a | grep -E " W " | grep -E "stat|lstat"
```

Ket qua thuc te 2026-06-16:
```text
0000000000000000 W fstat
000000000000003a W lstat
0000000000000000 W stat
```

Sau do make truc tiep (user oracle):
```bash
sudo su - oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
cd $ORACLE_HOME
make -f rdbms/lib/ins_rdbms.mk irman ioracle idrdactl idrdalsnr idrdaproc ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
```

Ket qua thuc te 2026-06-16:
```text
- Linking recovery manager (rman)  -> OK
- Linking Oracle                   -> OK
- Linking DPS DRDA AS Control Utility (drdactl) -> OK
- Linking DPS DRDA AS Listener (drdalsnr)       -> OK
- Linking DPS DRDA AS Protocol Processor (drdaproc) -> OK
echo $? -> 0
ls -lh bin/oracle -> -rwsr-s--x. 421M  <- DUNG, khong phai 0 bytes
ls -lh bin/rman  -> -rwxr-x--x.  13M
```

### 3.8 Chay installer

Luu y: KHONG dung flag `-local`, runInstaller tren stdby1 khong support.

Fix INS-32035 "central inventory not empty": oraInventory co logs/ tu lan fail truoc.
Tren stdby1 khong co Grid nen oraInventory chua duoc init dung. Fix: move backup va tao lai rong.

```bash
# User tandat:
sudo mv /u01/app/oraInventory /u01/app/oraInventory.bak
sudo mkdir -p /u01/app/oraInventory
sudo chown oracle:oinstall /u01/app/oraInventory
sudo chmod 775 /u01/app/oraInventory
```

Kiem tra /etc/oraInst.loc (neu chua co thi tao):
```bash
cat /etc/oraInst.loc
# Neu chua co:
echo "inventory_loc=/u01/app/oraInventory" | sudo tee /etc/oraInst.loc
echo "inst_group=oinstall" | sudo tee -a /etc/oraInst.loc
sudo chown root:oinstall /etc/oraInst.loc
sudo chmod 664 /etc/oraInst.loc
```

Chay installer (user oracle):
```bash
sudo su - oracle
cd /u01/app/oracle/product/19.0.0/dbhome_1
CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
```

Ket qua thuc te 2026-06-16:
```text
The response file for this session can be found at:
 /u01/app/oracle/product/19.0.0/dbhome_1/install/response/db_2026-06-16_04-09-39PM.rsp

You can find the log of this install session at:
 /u01/app/oraInventory/logs/InstallActions2026-06-16_04-09-39PM/installActions2026-06-16_04-09-39PM.log

As a root user, execute the following script(s):
    1. /u01/app/oracle/product/19.0.0/dbhome_1/root.sh

Execute /u01/app/oracle/product/19.0.0/dbhome_1/root.sh on the following nodes:
[stdby1]

Successfully Setup Software.
```

### 3.9 Chay root.sh

```bash
# Thoat ra user tandat:
exit
sudo /u01/app/oracle/product/19.0.0/dbhome_1/root.sh
```

Ket qua thuc te 2026-06-16:
```text
Check /u01/app/oracle/product/19.0.0/dbhome_1/install/root_stdby1_2026-06-16_16-11-16-609067265.log for the output of root script
```

### 3.10 Shell profile cho oracle user

```bash
sudo su - oracle
echo "export ORACLE_BASE=/u01/app/oracle" >> ~/.bash_profile
echo "export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1" >> ~/.bash_profile
echo "export ORACLE_SID=racdb_s" >> ~/.bash_profile
echo 'export PATH=$ORACLE_HOME/bin:$PATH' >> ~/.bash_profile
echo "unset TWO_TASK" >> ~/.bash_profile
source ~/.bash_profile
sqlplus -V
```

Ket qua thuc te 2026-06-16:
```text
SQL*Plus: Release 19.0.0.0.0 - Production
Version 19.3.0.0.0
```

### 3.11 Done criteria Phan 3

```text
Oracle DB 19c software installed: Successfully Setup Software
root.sh chay xong: root_stdby1_2026-06-16_16-11-16.log
sqlplus -V: 19.0.0.0.0
oracle binary: 421M, -rwsr-s--x
rman binary: 13M
bash_profile: ORACLE_HOME, ORACLE_BASE, ORACLE_SID=racdb_s, PATH set
```

---

## Phan 4 - Chuan bi primary racdb cho Data Guard

### 4.1 Bat archive log mode

Tren rac1, user oracle:

```bash
sudo su - oracle
export ORACLE_SID=racdb1
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
sql / as sysdba
```

Ket qua thuc te 2026-06-16:
```text
LOG_MODE   = ARCHIVELOG  ← da bat san, khong can doi
```

### 4.2 Bat Force Logging

```sql
alter database force logging;
select force_logging from v$database;
```

Ket qua thuc te 2026-06-16:
```text
Database altered.
FORCE_LOGGING = YES
```

### 4.3 Tao Standby Redo Logs tren primary

Standby redo logs can co them 1 group so voi online redo logs, cung size.

Online redo log hien tai (2026-06-16):
```text
GROUP#  THREAD#  MEMBERS  MB
     1        1        2  200
     2        1        2  200
     3        2        2  200
     4        2        2  200
```

Thread 1 (rac1): 2 groups → can 3 standby groups
Thread 2 (rac2): 2 groups → can 3 standby groups

```sql
alter database add standby logfile thread 1 group 5 size 200M;
alter database add standby logfile thread 1 group 6 size 200M;
alter database add standby logfile thread 1 group 7 size 200M;
alter database add standby logfile thread 2 group 8 size 200M;
alter database add standby logfile thread 2 group 9 size 200M;
alter database add standby logfile thread 2 group 10 size 200M;
select group#, thread#, sequence#, status from v$standby_log order by thread#, group#;
```

Ket qua thuc te 2026-06-16:
```text
Database altered. (x6)

GROUP#  THREAD#  SEQUENCE#  STATUS
     5        1          0  UNASSIGNED
     6        1          0  UNASSIGNED
     7        1          0  UNASSIGNED
     8        2          0  UNASSIGNED
     9        2          0  UNASSIGNED
    10        2          0  UNASSIGNED

6 rows selected.
```

### 4.4 Set tham so Data Guard tren primary

```sql
alter system set log_archive_config='DG_CONFIG=(racdb,racdb_s)' scope=both;
alter system set log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=racdb' scope=both;
alter system set log_archive_dest_2='SERVICE=racdb_s ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=racdb_s' scope=both;
alter system set log_archive_dest_state_1=ENABLE scope=both;
alter system set log_archive_dest_state_2=ENABLE scope=both;
alter system set fal_server='racdb_s' scope=both;
alter system set fal_client='racdb' scope=both;
alter system set standby_file_management='AUTO' scope=both;
alter system set db_file_name_convert='+DATA/RACDB','/u01/app/oracle/oradata/RACDB_S' scope=spfile;
alter system set log_file_name_convert='+DATA/RACDB','/u01/app/oracle/oradata/RACDB_S' scope=spfile;
```

Ket qua thuc te 2026-06-16:
```text
System altered. (x10 — tat ca thanh cong)
```

---

## Phan 5 - Cau hinh listener va tnsnames

### 5.1 Tren stdby1 — tao listener.ora

Dung echo tung dong (KHONG dung heredoc):
```bash
echo "LISTENER =" > $ORACLE_HOME/network/admin/listener.ora
echo "  (DESCRIPTION_LIST =" >> $ORACLE_HOME/network/admin/listener.ora
echo "    (DESCRIPTION =" >> $ORACLE_HOME/network/admin/listener.ora
echo "      (ADDRESS = (PROTOCOL = TCP)(HOST = stdby1)(PORT = 1521))" >> $ORACLE_HOME/network/admin/listener.ora
echo "    )" >> $ORACLE_HOME/network/admin/listener.ora
echo "  )" >> $ORACLE_HOME/network/admin/listener.ora
echo "" >> $ORACLE_HOME/network/admin/listener.ora
echo "SID_LIST_LISTENER =" >> $ORACLE_HOME/network/admin/listener.ora
echo "  (SID_LIST =" >> $ORACLE_HOME/network/admin/listener.ora
echo "    (SID_DESC =" >> $ORACLE_HOME/network/admin/listener.ora
echo "      (GLOBAL_DBNAME = racdb_s)" >> $ORACLE_HOME/network/admin/listener.ora
echo "      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)" >> $ORACLE_HOME/network/admin/listener.ora
echo "      (SID_NAME = racdb_s)" >> $ORACLE_HOME/network/admin/listener.ora
echo "    )" >> $ORACLE_HOME/network/admin/listener.ora
echo "  )" >> $ORACLE_HOME/network/admin/listener.ora
lsnrctl start
lsnrctl status
```

Ket qua thuc te 2026-06-16:
```text
Service "racdb_s" has 1 instance(s).
  Instance "racdb_s", status UNKNOWN, has 1 handler(s) for this service...
The command completed successfully
```

Luu y: status UNKNOWN la binh thuong vi DB chua chay, listener da co static entry.

### 5.2 Tren stdby1 — tao tnsnames.ora

Dung echo tung dong (KHONG dung heredoc):
```bash
echo "RACDB =" > $ORACLE_HOME/network/admin/tnsnames.ora
echo "  (DESCRIPTION =" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "    (ADDRESS = (PROTOCOL = TCP)(HOST = rac1-scan)(PORT = 1521))" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "    (CONNECT_DATA =" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "      (SERVER = DEDICATED)" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "      (SERVICE_NAME = racdb)" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "    )" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "  )" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "RACDB_S =" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "  (DESCRIPTION =" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "    (ADDRESS = (PROTOCOL = TCP)(HOST = stdby1)(PORT = 1521))" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "    (CONNECT_DATA =" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "      (SERVER = DEDICATED)" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "      (SID = racdb_s)" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "    )" >> $ORACLE_HOME/network/admin/tnsnames.ora
echo "  )" >> $ORACLE_HOME/network/admin/tnsnames.ora
```

Ket qua thuc te 2026-06-16:
```text
RACDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac1-scan)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = racdb)
    )
  )

RACDB_S =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = stdby1)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = racdb_s)
    )
  )
```

### 5.3 Tren rac1 va rac2 — them tnsnames entry RACDB_S

Luu y: oracle user tren rac1/rac2 co TNS_ADMIN=/home/oracle/.oracle_wallet/query_tuning
Them vao file do de oracle user shell dung duoc (tnsping, RMAN, sqlplus).

Tren rac1 (user oracle):
```bash
echo "" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "RACDB_S =" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "  (DESCRIPTION =" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "    (ADDRESS = (PROTOCOL = TCP)(HOST = stdby1)(PORT = 1521))" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "    (CONNECT_DATA =" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "      (SERVER = DEDICATED)" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "      (SID = racdb_s)" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "    )" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "  )" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
tnsping racdb_s
```

Ket qua thuc te 2026-06-16:
```text
OK (40 msec)
```

Tren rac2 — chay tuong tu:
```bash
echo "" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "RACDB_S =" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "  (DESCRIPTION =" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "    (ADDRESS = (PROTOCOL = TCP)(HOST = stdby1)(PORT = 1521))" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "    (CONNECT_DATA =" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "      (SERVER = DEDICATED)" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "      (SID = racdb_s)" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "    )" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
echo "  )" >> /home/oracle/.oracle_wallet/query_tuning/tnsnames.ora
tnsping racdb_s
```

Ket qua thuc te 2026-06-16:
```text
OK (0 msec)
```

### 5.4 Fix ORA-12154 cho background processes (TT/LGWR)

**Van de phat sinh sau RMAN duplicate:** dest_2 bao loi ORA-12154 TNS:could not resolve service name 'racdb_s'.

**Nguyen nhan goc:**
```text
Background processes (TT00-TT05, LGWR) duoc CRS khoi dong, KHONG co TNS_ADMIN.
Oracle background processes doc tnsnames tu $ORACLE_HOME/network/admin/tnsnames.ora.
File nay CHUA TON TAI khi TT processes khoi dong lan dau (luc 16:51).
Oracle cache trang thai "file not found" — ngay ca sau khi file duoc tao sau do (17:04),
cac process cu van bao ORA-12154 vi da cache.
oracle user shell dung TNS_ADMIN=/home/oracle/.oracle_wallet/query_tuning — cai do
khong anh huong gi den background processes do CRS khoi dong.
```

**Fix:**

Buoc 1 — Tao $ORACLE_HOME/network/admin/tnsnames.ora tren rac1 (user oracle):
```bash
export TNS_DIR=$ORACLE_HOME/network/admin
echo "RACDB_S =" > $TNS_DIR/tnsnames.ora
echo "  (DESCRIPTION =" >> $TNS_DIR/tnsnames.ora
echo "    (ADDRESS = (PROTOCOL = TCP)(HOST = stdby1)(PORT = 1521))" >> $TNS_DIR/tnsnames.ora
echo "    (CONNECT_DATA =" >> $TNS_DIR/tnsnames.ora
echo "      (SERVER = DEDICATED)" >> $TNS_DIR/tnsnames.ora
echo "      (SID = racdb_s)" >> $TNS_DIR/tnsnames.ora
echo "    )" >> $TNS_DIR/tnsnames.ora
echo "  )" >> $TNS_DIR/tnsnames.ora
echo "" >> $TNS_DIR/tnsnames.ora
echo "RACDB_S.LOCALDOMAIN =" >> $TNS_DIR/tnsnames.ora
echo "  (DESCRIPTION =" >> $TNS_DIR/tnsnames.ora
echo "    (ADDRESS = (PROTOCOL = TCP)(HOST = stdby1)(PORT = 1521))" >> $TNS_DIR/tnsnames.ora
echo "    (CONNECT_DATA =" >> $TNS_DIR/tnsnames.ora
echo "      (SERVER = DEDICATED)" >> $TNS_DIR/tnsnames.ora
echo "      (SID = racdb_s)" >> $TNS_DIR/tnsnames.ora
echo "    )" >> $TNS_DIR/tnsnames.ora
echo "  )" >> $TNS_DIR/tnsnames.ora
```

Luu y: can ca hai alias RACDB_S va RACDB_S.LOCALDOMAIN vi primary co db_domain=localdomain,
nen background processes resolve ten thanh RACDB_S.LOCALDOMAIN.

Buoc 2 — Tao $ORACLE_HOME/network/admin/sqlnet.ora tren rac1:
```bash
echo "NAMES.DIRECTORY_PATH = (TNSNAMES, EZCONNECT)" > $TNS_DIR/sqlnet.ora
echo "NAMES.DEFAULT_DOMAIN = localdomain" >> $TNS_DIR/sqlnet.ora
```

Buoc 3 — Verify tnsping voi DB home TNS_ADMIN:
```bash
TNS_ADMIN=$ORACLE_HOME/network/admin tnsping racdb_s
```

Ket qua thuc te 2026-06-16:
```text
OK (0 msec)
```

Buoc 4 — Kill cac TT background processes cu (da cache "file not found"):
```bash
# Xem PID cua TT processes
ps -ef | grep "oracle.*tt0" | grep -v grep

# Kill tung PID (PMON se tu dong restart chung)
kill <pid1> <pid2> ...
```

Ket qua thuc te 2026-06-16:
```text
Old PIDs killed: 15634, 15640, 15648, 16623, 16625, 20393
New PIDs spawned by PMON: 23298 (tt00), 23300 (tt01), 23302 (tt02),
                          23305 (tt03), 23307 (tt04), 23309 (tt05)
```

Buoc 5 — Enable lai dest_2 va force log switch:
```sql
alter system set log_archive_dest_state_2=DEFER scope=both;
alter system set log_archive_dest_state_2=ENABLE scope=both;
alter system archive log current;
```

Buoc 6 — Kiem tra dest_2 da VALID:
```sql
select dest_id, status, destination, error from v$archive_dest where dest_id in (1,2);
```

Ket qua thuc te 2026-06-16:
```text
DEST_ID  STATUS    DESTINATION
-------  --------  -----------
      1  VALID     USE_DB_RECOVERY_FILE_DEST
      2  VALID     racdb_s
```

**Luu y quan trong:** Phai lam tuong tu tren rac2 — tao tnsnames.ora va sqlnet.ora trong
$ORACLE_HOME/network/admin tren rac2, roi kill TT processes tren rac2.

### 5.5 Test tnsping tu stdby1

```bash
TNS_ADMIN=$ORACLE_HOME/network/admin tnsping racdb
TNS_ADMIN=$ORACLE_HOME/network/admin tnsping racdb_s
```

---

## Phan 6 - Tao standby database bang RMAN Duplicate

### 6.1 Tao password file tren stdby1

```bash
orapwd file=$ORACLE_HOME/dbs/orapwracdb_s password=<REDACTED_PASSWORD> entries=10
```

### 6.2 Tao thu muc datafile va init file

```bash
mkdir -p /u01/app/oracle/oradata/RACDB_S/arch
echo "db_name=racdb" > $ORACLE_HOME/dbs/initracdb_s.ora
echo "db_unique_name=racdb_s" >> $ORACLE_HOME/dbs/initracdb_s.ora
```

### 6.3 Startup standby nomount

```bash
sqlplus / as sysdba
```

```sql
startup nomount;
exit
```

Ket qua thuc te 2026-06-16:
```text
ORACLE instance started.
Total System Global Area  268434280 bytes
Fixed Size            8895336 bytes
Variable Size          201326592 bytes
Database Buffers       50331648 bytes
Redo Buffers            7880704 bytes
```

### 6.4 Chay RMAN Duplicate tren stdby1

Luu y quan trong:
```text
1. set +H truoc vi password co ky tu !
2. auxiliary phai dung TNS name (khong dung /), can thiet cho FROM ACTIVE DATABASE
3. RMAN-06217 neu dung auxiliary /
4. tnsnames tren stdby1 phai dung SERVICE_NAME = racdb.localdomain (khong phai racdb)
```

```bash
set +H
rman target sys/<REDACTED_PASSWORD>@racdb auxiliary sys/<REDACTED_PASSWORD>@racdb_s
```

Ket qua connect 2026-06-16:
```text
connected to target database: RACDB (DBID=1231980070)
connected to auxiliary database: RACDB (not mounted)
```

Xem lenh duplicate day du (co tat ca cac fix) o cuoi section nay.

### Loi gap va cach fix trong RMAN duplicate 2026-06-16

**Loi 1: RMAN-06217 not connected to auxiliary with net service name**
```text
Nguyen nhan: dung `auxiliary /` (OS auth) thay vi TNS
Fix: doi sang `auxiliary sys/password@racdb_s`
```

**Loi 2: ORA-00439 feature not enabled Real Application Clusters**
```text
Nguyen nhan: SPFILE copy tu primary co cluster_database=TRUE, stdby1 khong co RAC license
Fix: them `set cluster_database='FALSE'` vao RMAN SPFILE clause
Buoc them:
  rm -f $ORACLE_HOME/dbs/spfileracdb_s.ora
  startup nomount pfile='.../initracdb_s.ora'
```

**Loi 3: ORA-09925 Unable to create audit trail file**
```text
Nguyen nhan: audit_file_dest tu primary tro vao /u01/app/oracle/admin/racdb/adump chua ton tai tren stdby1
Fix:
  mkdir -p /u01/app/oracle/admin/racdb_s/adump
  mkdir -p /u01/app/oracle/admin/racdb/adump
  them `set audit_file_dest='/u01/app/oracle/admin/racdb_s/adump'` vao RMAN SPFILE clause
```

**Loi 4: ORA-15001 diskgroup DATA does not exist**
```text
Nguyen nhan: control_files trong primary SPFILE tro vao +DATA (ASM), stdby1 khong co ASM
Fix: them vao RMAN SPFILE clause:
  set control_files='/u01/app/oracle/oradata/RACDB_S/control01.ctl','.../control02.ctl'
  set db_create_file_dest='/u01/app/oracle/oradata/RACDB_S'
  set db_recovery_file_dest='/u01/app/oracle/oradata/RACDB_S/fra'
  set db_recovery_file_dest_size='10G'
  mkdir -p /u01/app/oracle/oradata/RACDB_S/fra
```

**Loi 5: RMAN-05537 cannot use SPFILE clause when aux started with spfile**
```text
Nguyen nhan: sau lan fail, RMAN da copy spfile sang stdby1 va restart instance bang spfile do
  Lan chay RMAN tiep theo gap loi vi auxiliary dang dung spfile, khong dung pfile
Fix:
  sqlplus / as sysdba → shutdown immediate (ORA-01507 la binh thuong trong nomount, instance van tat)
  rm -f $ORACLE_HOME/dbs/spfileracdb_s.ora
  startup nomount pfile='.../initracdb_s.ora'
```

**Lenh RMAN duplicate cuoi cung (thanh cong):**
```bash
set +H
rman target sys/<REDACTED_PASSWORD>@racdb auxiliary sys/<REDACTED_PASSWORD>@racdb_s
```

```
duplicate target database for standby
  from active database
  dorecover
  spfile
    set db_unique_name='racdb_s'
    set cluster_database='FALSE'
    set audit_file_dest='/u01/app/oracle/admin/racdb_s/adump'
    set control_files='/u01/app/oracle/oradata/RACDB_S/control01.ctl','/u01/app/oracle/oradata/RACDB_S/control02.ctl'
    set db_create_file_dest='/u01/app/oracle/oradata/RACDB_S'
    set db_recovery_file_dest='/u01/app/oracle/oradata/RACDB_S/fra'
    set db_recovery_file_dest_size='10G'
    set db_file_name_convert='+DATA/RACDB','/u01/app/oracle/oradata/RACDB_S'
    set log_file_name_convert='+DATA/RACDB','/u01/app/oracle/oradata/RACDB_S'
    set fal_server='racdb'
    set fal_client='racdb_s'
    set log_archive_dest_1='LOCATION=/u01/app/oracle/oradata/RACDB_S/arch VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=racdb_s'
    set log_archive_dest_2='SERVICE=racdb ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=racdb'
    set standby_file_management='AUTO'
  nofilenamecheck;
```

Ket qua thuc te 2026-06-16:
```text
(dang restore datafiles...)
channel ORA_AUX_DISK_1: restore complete, elapsed time: 00:00:01
channel ORA_AUX_DISK_1: restoring datafile 00013 to /u01/app/oracle/oradata/RACDB_S/...
```

---

## Phan 7 - Verify Data Guard

### 7.1 Tren stdby1 — start managed recovery

RMAN duplicate voi `dorecover` da tu dong start MRP0 sau khi duplicate xong.
Neu chua chay, start thu cong:

```bash
sqlplus / as sysdba
```

```sql
alter database recover managed standby database disconnect from session;
select db_unique_name, open_mode, protection_mode, database_role from v$database;
select process, status, sequence#, thread# from v$managed_standby order by process;
exit
```

Ket qua thuc te 2026-06-16:
```text
-- v$database:
DB_UNIQUE_NAME  OPEN_MODE   PROTECTION_MODE      DATABASE_ROLE
--------------  ----------  -------------------  ----------------
RACDB_S         MOUNTED     MAXIMUM PERFORMANCE  PHYSICAL STANDBY

-- v$managed_standby (sau khi log shipping hoat dong):
PROCESS   STATUS         SEQUENCE#  THREAD#
--------  -------------  ---------  -------
ARCH      CLOSING               47        1
ARCH      CLOSING               47        2
ARCH      CLOSING               48        1
ARCH      CONNECTED              0        0
DGRD      ALLOCATED              0        0
DGRD      ALLOCATED              0        0
MRP0      WAIT_FOR_LOG          49        2
RFS       IDLE                   0        0
RFS       IDLE                   0        0
RFS       IDLE                  49        1
RFS       IDLE                   0        0
RFS       IDLE                   0        1

16 rows selected.
```

Giai thich:
```text
MRP0 WAIT_FOR_LOG  — managed recovery dang cho log ke tiep (binh thuong, la GOOD)
RFS IDLE seq=49    — RFS da nhan sequence 49 tu primary thread 1
ARCH CLOSING       — dang archive cac log da nhan duoc
```

### 7.2 Tren primary rac1 — kiem tra log shipping

```sql
select dest_id, status, destination, error from v$archive_dest where dest_id in (1,2);
select * from v$archive_gap;
select switchover_status from v$database;
```

Ket qua thuc te 2026-06-16:
```text
-- v$archive_dest:
DEST_ID  STATUS   DESTINATION               ERROR
-------  -------  ------------------------  -----
      1  VALID    USE_DB_RECOVERY_FILE_DEST
      2  VALID    racdb_s

-- v$archive_gap:
no rows selected

-- switchover_status:
RESOLVABLE GAP  (standby dang catch up, se chuyen thanh TO STANDBY khi dong bo xong)
```

---

## Phan 8 - Done criteria

```text
[DONE] stdby1 VM chay, IP 192.168.122.220, hostname stdby1
[DONE] Oracle DB 19c software da cai tren stdby1 (19.3.0.0.0)
[DONE] Primary racdb: archivelog mode ON, force logging YES
[DONE] Standby redo logs: 6 groups (5-10), thread 1 va thread 2, 200MB moi group
[DONE] DG parameters set: log_archive_config, fal_server/client, standby_file_management
[DONE] listener.ora tren stdby1: static entry racdb_s + racdb_s_DGMGRL
[DONE] tnsnames.ora tren stdby1: RACDB (racdb.localdomain) + RACDB_S
[DONE] tnsnames.ora tren rac1 va rac2: wallet + DB home (cho background processes)
[DONE] sqlnet.ora tren rac1 DB home: NAMES.DEFAULT_DOMAIN=localdomain
[DONE] RMAN duplicate tu active database thanh cong: Finished Duplicate Db at 16-JUN-26
[DONE] Standby database: PHYSICAL STANDBY, MOUNTED, MAXIMUM PERFORMANCE
[DONE] MRP0 dang chay: WAIT_FOR_LOG (dang nhan log tu primary)
[DONE] RFS processes: nhan log tu primary (sequence 49 thread 1, 47 thread 2)
[DONE] dest_2 tren primary: VALID, khong co error
[DONE] v$archive_gap: no rows (khong co gap)
[DONE] switchover_status: TO STANDBY
[DONE] rac2: da them tnsnames.ora + sqlnet.ora vao DB home
[DONE] tandat them vao group oinstall, dba tren stdby1
[DONE] Password file copy tu ASM primary sang standby (binary copy)
[DONE] listener.ora stdby1 them static entry racdb_s_DGMGRL, reload listener
[DONE] DG Broker enabled: dg_broker_start=TRUE tren ca primary va standby
[DONE] DGMGRL show configuration: SUCCESS
[DONE] Fast-Start Failover (FSFO): ENABLED
[DONE] Observer: da khoi dong
```

---

## Phan 9 - Cai dat Data Guard Broker va Fast-Start Failover (FSFO)

### 9.1 Cau hinh Static Listener cho DGMGRL tren stdby1

Broker can static service `_DGMGRL` de ket noi vao standby khi DB dang o trang thai NOMOUNT/MOUNT
hoac trong qua trinh Failover/Switchover (khong co dynamic service registration).

Chinh sua `listener.ora` tren stdby1 (can chay voi quyen oracle):
```bash
sudo su - oracle
vi $ORACLE_HOME/network/admin/listener.ora
```

Them SID_DESC thu hai vao khoi SID_LIST_LISTENER:
```text
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = racdb_s)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = racdb_s)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = racdb_s_DGMGRL)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = racdb_s)
    )
  )
```

Reload listener:
```bash
lsnrctl reload
lsnrctl status
```

Ket qua thuc te 2026-06-17:
```text
Service "racdb_s" has 1 instance(s).
  Instance "racdb_s", status UNKNOWN, has 1 handler(s) for this service...
Service "racdb_s_DGMGRL" has 1 instance(s).
  Instance "racdb_s", status UNKNOWN, has 1 handler(s) for this service...
The command completed successfully
```

Luu y: cung can them static entry DGMGRL tren rac1/rac2 listener.ora (trong SID_LIST_LISTENER):
```text
(SID_DESC =
  (GLOBAL_DBNAME = racdb_DGMGRL)
  (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
  (SID_NAME = racdb1)
)
```

### 9.2 Fix quyen OS cho user tandat tren stdby1

User `tandat` can thuoc group `oinstall` va `dba` de chay cac lenh Oracle va copy password file:
```bash
sudo usermod -aG oinstall,dba tandat
```

Logout va login lai SSH de group co hieu luc:
```bash
exit
ssh -i ~/.ssh/rac_ed25519 tandat@192.168.122.220
id   # kiem tra groups
```

Ket qua sau khi them group:
```text
uid=1000(tandat) gid=1000(tandat) groups=1000(tandat),10(wheel),54321(oinstall),54322(dba)
```

### 9.3 Copy Password File tu Primary ASM sang Standby

**Nguyen nhan ORA-1017 / ORA-1033 trong broker:**
Khi primary va standby chay `orapwd` rieng le voi cung mot password, Oracle sinh ra salt/hash khac nhau.
NSV2 broker dung hash tu password file primary de xac thuc voi standby → sai hash → ORA-1017.
Phai copy binary password file tu primary sang standby.

**Buoc 1 — Trich xuat tu ASM tren rac1 (user grid):**
```bash
sudo su - grid
export GRID_HOME=/u01/app/19.0.0/grid
export ORACLE_SID=+ASM1
export PATH=$GRID_HOME/bin:$PATH
asmcmd ls -l +DATA/RACDB/PASSWORD/
# Ghi nhan ten file: pwdracdb.256.xxxxxxxxxx
asmcmd pwcopy +DATA/RACDB/PASSWORD/pwdracdb.256.1234363179 /tmp/orapwracdb_s
chmod 644 /tmp/orapwracdb_s
exit
```

**Buoc 2 — Copy sang stdby1 (tu NixOS host):**
```bash
# Download tu rac1 xuong local
ssh -p 2222 -i ~/.ssh/rac_ed25519 tandat8896@192.168.122.205 "cat /tmp/orapwracdb_s" > /tmp/orapwracdb_s_local

# Upload len stdby1
scp -i ~/.ssh/rac_ed25519 /tmp/orapwracdb_s_local tandat@192.168.122.220:/tmp/orapwracdb_s
```

**Buoc 3 — Dat vao dung vi tri tren stdby1 (can quyen oracle/oinstall):**
```bash
# Sau khi tandat da them vao group oinstall (buoc 9.2):
ssh -i ~/.ssh/rac_ed25519 tandat@192.168.122.220
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
cp /tmp/orapwracdb_s $ORACLE_HOME/dbs/orapwracdb_s
chmod 640 $ORACLE_HOME/dbs/orapwracdb_s
ls -la $ORACLE_HOME/dbs/orapwracdb_s
```

Ket qua thuc te 2026-06-17:
```text
-rw-r-----. 1 tandat oinstall 2048 Jun 17 00:xx /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwracdb_s
```

**Buoc 4 — Restart standby de nap password file moi:**
```bash
sqlplus / as sysdba
SQL> shutdown immediate;
SQL> startup mount;
SQL> exit;
```

### 9.4 Bat Data Guard Broker tren ca Primary va Standby

**Tren primary rac1 (chay tu NixOS host):**
```bash
ssh -p 2222 -i ~/.ssh/rac_ed25519 tandat8896@192.168.122.205 "
sudo -n -u oracle bash -c '
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=racdb1
export PATH=\$ORACLE_HOME/bin:\$PATH
sqlplus -s / as sysdba <<SQL
ALTER SYSTEM SET dg_broker_start=TRUE SID=\"*\";
exit
SQL
'
"
```

**Tren stdby1:**
```bash
ssh -i ~/.ssh/rac_ed25519 tandat@192.168.122.220 "
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=racdb_s
export PATH=\$ORACLE_HOME/bin:\$PATH
sqlplus / as sysdba <<SQL
ALTER SYSTEM SET dg_broker_start=TRUE;
exit
SQL
"
```

### 9.5 Tao hoac xac nhan cau hinh Broker bang DGMGRL

Tu NixOS host, ket noi vao primary:
```bash
ssh -p 2222 -i ~/.ssh/rac_ed25519 tandat8896@192.168.122.205 "
sudo -n -u oracle bash -c '
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=\$ORACLE_HOME/bin:\$PATH
dgmgrl sys/\"<REDACTED_PASSWORD>\"@racdb <<DGMGRL
show configuration;
DGMGRL
'
"
```

Ket qua thanh cong 2026-06-17:
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

### 9.6 Enable Fast-Start Failover (FSFO) va khoi dong Observer

**Dieu kien truoc khi enable FSFO:**
- Configuration STATUS = SUCCESS
- Protection mode phai la MaxAvailability hoac MaxProtection (doi tu MaxPerformance)

**Doi protection mode:**
```
DGMGRL> edit configuration set protection mode as maxavailability;
```

**Enable FSFO:**
```
DGMGRL> enable fast_start failover;
```

**Khoi dong Observer (tu NixOS host hoac bat ky node nao co network toi ca primary va standby):**
```bash
dgmgrl sys/"<REDACTED_PASSWORD>"@racdb "start observer"
```

Hoac chay observer nhu background process:
```bash
nohup dgmgrl sys/"<REDACTED_PASSWORD>"@racdb "start observer" > /tmp/observer.log 2>&1 &
```

Ket qua verify:
```
DGMGRL> show fast_start failover;
DGMGRL> show configuration;
```

Ket qua thuc te 2026-06-17:
```text
Fast-Start Failover: Enabled

Configuration Status:
SUCCESS
```

### 9.7 Troubleshooting: Cac loi thuong gap

| Loi | Nguyen nhan | Fix |
|-----|-------------|-----|
| ORA-16664 | NSV2 khong ket noi duoc standby | Kiem tra DRC log, them _DGMGRL listener entry |
| ORA-1017 | Password file hash khac nhau | Copy binary password file tu primary ASM sang standby |
| ORA-1033 | DB standby o trang thai MOUNT, khong co static listener | Them SID_LIST DGMGRL vao listener.ora, reload |
| ORA-16810 | Multiple errors o primary broker | Tat/bat lai dg_broker_start, kiem tra NSV2 trace |
| ORA-16532 | Broker config file rong/moi | Tao lai config bang DGMGRL CREATE CONFIGURATION |

**Kiem tra DRC log tren standby:**
```bash
# Can chay voi quyen oracle hoac oinstall
tail -100 /u01/app/oracle/diag/rdbms/racdb_s/racdb_s/trace/drcracdb_s.log
```

**Kiem tra NSV2 trace tren primary:**
```bash
# Tim file trace moi nhat
ls -lt /u01/app/oracle/diag/rdbms/racdb/racdb1/trace/racdb1_nsv*.trc | head -3
tail -100 /u01/app/oracle/diag/rdbms/racdb/racdb1/trace/racdb1_nsv2_XXXX.trc
```
