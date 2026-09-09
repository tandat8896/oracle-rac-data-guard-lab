# Step 06 - OS prerequisites for Oracle RAC/Grid

Muc tieu: chuan bi OS tren `rac1` va `rac2` truoc khi cai Oracle Grid Infrastructure.

Step nay lam:

```text
Check OS/kernel
Install packages
Tao groups/users oracle/grid
Set limits/kernel params
Check time sync
Chuan bi SSH giua 2 node
```

Luu y:

```text
Lab hien tai dang dung Oracle Linux 9.
Oracle Grid/Database software dang la 19c base.
Neu installer/cvufy bao prerequisite/certification warning ve OS version, ghi lai warning vao lab log roi minh xu ly tiep.
```

## 1. Precheck OS tren ca hai node

Tren `rac1`:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.205
```

Tren `rac2`:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.46
```

Chay tren ca hai node:

```bash
hostname
cat /etc/os-release
uname -r
free -h
df -h
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
ip -br addr
```

Expected:

```text
rac1 hostname = rac1
rac2 hostname = rac2
OS = Oracle Linux
vdb/vdc/vdd ton tai va chua co FSTYPE
private IP rac1 = 10.10.10.11
private IP rac2 = 10.10.10.12
```

Chup hinh:

```text
oracle_rac/screenshots/08a-os-precheck-rac1-rac2.png
```

## 2. Install packages

Chay tren ca `rac1` va `rac2`.

Update metadata:

```bash
sudo dnf makecache
```

Install packages co ban cho Grid/Database install:

```bash
sudo dnf install -y \
  bc \
  binutils \
  elfutils-libelf \
  elfutils-libelf-devel \
  fontconfig-devel \
  gcc \
  gcc-c++ \
  glibc \
  glibc-devel \
  ksh \
  libaio \
  libaio-devel \
  libX11 \
  libXau \
  libXi \
  libXtst \
  libXrender \
  libXrender-devel \
  libgcc \
  libnsl \
  libstdc++ \
  libstdc++-devel \
  libxcb \
  make \
  net-tools \
  nfs-utils \
  policycoreutils-python-utils \
  smartmontools \
  sysstat \
  unzip \
  unixODBC \
  unixODBC-devel
```

Verify:

```bash
rpm -q bc binutils gcc gcc-c++ ksh libaio libaio-devel libnsl make net-tools smartmontools sysstat unzip
```

Neu gap loi tren OL9:

```text
No match for argument: unixODBC-devel
Error: Unable to find a match: unixODBC-devel
```

Thi khong phai go sai. Package `unixODBC-devel` nam trong repo devel/CodeReady Builder.

Check repo:

```bash
sudo dnf repolist --all | grep -Ei 'codeready|builder|devel|appstream'
```

Thu enable CodeReady Builder repo:

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --set-enabled ol9_codeready_builder
sudo dnf makecache
sudo dnf install -y unixODBC-devel
```

Neu repo name khac, xem output `dnf repolist --all` roi enable repo tuong ung.

Sau do verify:

```bash
rpm -q unixODBC unixODBC-devel
```

Ket qua hien tai:

```text
ol9_codeready_builder da duoc enable.
unixODBC-2.3.9-4.el9.x86_64 installed.
unixODBC-devel-2.3.9-4.el9.x86_64 installed.
Dependencies installed: libpkgconf, pkgconf, pkgconf-m4, pkgconf-pkg-config.
```

Chup hinh:

```text
oracle_rac/screenshots/08b-rac-packages-installed.png
```

## 3. Tao Oracle groups

Chay tren ca `rac1` va `rac2`.

Tao groups:

```bash
sudo groupadd -g 54321 oinstall
sudo groupadd -g 54322 dba
sudo groupadd -g 54323 oper
sudo groupadd -g 54324 backupdba
sudo groupadd -g 54325 dgdba
sudo groupadd -g 54326 kmdba
sudo groupadd -g 54327 asmdba
sudo groupadd -g 54328 asmoper
sudo groupadd -g 54329 asmadmin
```

Neu group da ton tai, lenh co the bao:

```text
groupadd: group '...' already exists
```

Khong sao, verify bang:

```bash
getent group oinstall dba oper backupdba dgdba kmdba asmdba asmoper asmadmin
```

## 4. Tao users grid va oracle

Chay tren ca `rac1` va `rac2`.

Tao user `grid`:

```bash
sudo useradd -u 54331 -g oinstall -G asmadmin,asmdba,asmoper,dba grid
```

Tao user `oracle`:

```bash
sudo useradd -u 54332 -g oinstall -G dba,oper,backupdba,dgdba,kmdba,asmdba oracle
```

Dat password lab cho 2 user:

```bash
sudo passwd grid
sudo passwd oracle
```

Verify:

```bash
id grid
id oracle
```

Ket qua verify hien tai:

```text
grid:
  uid=54331(grid)
  gid=54321(oinstall)
  groups=oinstall,dba,asmdba,asmoper,asmadmin

oracle:
  uid=54332(oracle)
  gid=54321(oinstall)
  groups=oinstall,dba,oper,backupdba,dgdba,kmdba,asmdba
```

Chup hinh:

```text
oracle_rac/screenshots/08c-grid-oracle-users-created.png
```

## 5. Tao Oracle directories

Chay tren ca `rac1` va `rac2`.

```bash
sudo mkdir -p /u01/app/19.0.0/grid
sudo mkdir -p /u01/app/grid
sudo mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1
sudo mkdir -p /u01/app/oraInventory
```

Set ownership:

```bash
sudo chown -R grid:oinstall /u01/app/19.0.0/grid
sudo chown -R grid:oinstall /u01/app/grid
sudo chown -R oracle:oinstall /u01/app/oracle
sudo chown -R grid:oinstall /u01/app/oraInventory
sudo chmod -R 775 /u01
```

Verify:

```bash
ls -ld /u01 /u01/app /u01/app/19.0.0/grid /u01/app/grid /u01/app/oracle /u01/app/oraInventory
```

## 6. Set limits

Chay tren ca `rac1` va `rac2`.

Tao file:

```text
/etc/security/limits.d/99-oracle-rac.conf
```

Dan noi dung:

```text
grid   soft   nofile    1024
grid   hard   nofile    65536
grid   soft   nproc     16384
grid   hard   nproc     16384
grid   soft   stack     10240
grid   hard   stack     32768
grid   hard   memlock   134217728
grid   soft   memlock   134217728

oracle soft   nofile    1024
oracle hard   nofile    65536
oracle soft   nproc     16384
oracle hard   nproc     16384
oracle soft   stack     10240
oracle hard   stack     32768
oracle hard   memlock   134217728
oracle soft   memlock   134217728
```

Verify:

```bash
cat /etc/security/limits.d/99-oracle-rac.conf
```

Neu khong dan file bang `vi` duoc, co the tao bang `printf`:

```bash
sudo sh -c "printf '%s\n' \
'grid   soft   nofile    1024' \
'grid   hard   nofile    65536' \
'grid   soft   nproc     16384' \
'grid   hard   nproc     16384' \
'grid   soft   stack     10240' \
'grid   hard   stack     32768' \
'grid   hard   memlock   134217728' \
'grid   soft   memlock   134217728' \
'' \
'oracle soft   nofile    1024' \
'oracle hard   nofile    65536' \
'oracle soft   nproc     16384' \
'oracle hard   nproc     16384' \
'oracle soft   stack     10240' \
'oracle hard   stack     32768' \
'oracle hard   memlock   134217728' \
'oracle soft   memlock   134217728' \
> /etc/security/limits.d/99-oracle-rac.conf"
```

Trang thai hien tai:

```text
limits file da tao xong.
```

## 7. Set kernel params

Chay tren ca `rac1` va `rac2`.

Tao file:

```text
/etc/sysctl.d/99-oracle-rac.conf
```

Dan noi dung:

```text
fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = 2097152
kernel.shmmax = 4294967296
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
```

Apply:

```bash
sudo sysctl --system
```

Verify:

```bash
sysctl fs.aio-max-nr fs.file-max kernel.shmall kernel.shmmax kernel.shmmni kernel.sem net.ipv4.ip_local_port_range
```

Ket qua hien tai:

```text
rac2: sudo sysctl --system da apply /etc/sysctl.d/99-oracle-rac.conf thanh cong.
rac1: sysctl verify OK:
  fs.aio-max-nr = 1048576
  fs.file-max = 6815744
  kernel.shmall = 2097152
  kernel.shmmax = 4294967296
  kernel.shmmni = 4096
  kernel.sem = 250 32000 100 128
  net.ipv4.ip_local_port_range = 9000 65500
```

Chup hinh:

```text
oracle_rac/screenshots/08d-limits-sysctl-configured.png
```

## 8. SELinux va firewall lab setting

Trong production khong tat tuy tien.

Trong lab nay, de giam loi installer/Grid, co the set permissive:

```bash
sudo setenforce 0
getenforce
```

Neu muon persist sau reboot, sua file:

```text
/etc/selinux/config
```

Dat:

```text
SELINUX=permissive
```

Firewall: tam thoi disable trong lab RAC de tranh chan private/VIP/SCAN traffic:

```bash
sudo systemctl disable --now firewalld
sudo systemctl status firewalld
```

Chay tren ca `rac1` va `rac2`.

Chup hinh:

```text
oracle_rac/screenshots/08e-selinux-firewall-lab-setting.png
```

Trang thai hien tai:

```text
SELinux da set permissive trong lab.
firewalld da disable/stop tren rac1 va rac2.
rac1 verify firewalld:
  systemctl is-active firewalld  -> inactive
  systemctl is-enabled firewalld -> disabled
rac2 disable firewalld thanh cong.
```

## 9. Time sync

Chay tren ca `rac1` va `rac2`:

```bash
timedatectl
systemctl status chronyd --no-pager
```

Neu `chronyd` chua chay:

```bash
sudo systemctl enable --now chronyd
```

Verify:

```bash
chronyc tracking
```

Ket qua hien tai:

```text
rac1 chronyd.service active (running), enabled.
rac2 chronyd.service active (running), enabled.
Ca hai node da select NTP source tu pool.ntp.org.
```

## 10. Passwordless SSH giua grid/oracle users

Can passwordless SSH hai chieu cho `grid` va `oracle`.

Lam sau khi user `grid` va `oracle` da tao tren ca 2 node.

Tren `rac1`, chuyen sang `grid`:

```bash
sudo su - grid
ssh-keygen -t rsa -b 4096
```

Vi SSH da hardening key-only va port 2222, `ssh-copy-id` bang password khong dung duoc nua.

Neu chay sai tu user `tandat8896` se gap:

```text
Permission denied (publickey,gssapi-keyex,gssapi-with-mic)
```

Dung dung user context:

```text
Test key cua grid thi phai sudo su - grid truoc.
Test key cua oracle thi phai sudo su - oracle truoc.
```

Setup local authorized_keys cho `grid` tren rac1:

```bash
sudo mkdir -p /home/grid/.ssh
sudo cp /home/grid/.ssh/id_rsa.pub /home/grid/.ssh/authorized_keys
sudo chown -R grid:oinstall /home/grid/.ssh
sudo chmod 700 /home/grid/.ssh
sudo chmod 600 /home/grid/.ssh/authorized_keys
```

Copy public key cua `grid@rac1` sang `rac2` qua host NixOS:

```bash
sudo cp /home/grid/.ssh/id_rsa.pub /tmp/grid_id_rsa.pub
sudo chown tandat8896:tandat8896 /tmp/grid_id_rsa.pub
```

Tren host NixOS:

```bash
scp -i ~/.ssh/rac_ed25519 -P 2222 tandat8896@192.168.122.205:/tmp/grid_id_rsa.pub /tmp/grid_id_rsa.pub
scp -i ~/.ssh/rac_ed25519 -P 2222 /tmp/grid_id_rsa.pub tandat8896@192.168.122.46:/tmp/grid_id_rsa.pub
```

Tren `rac2`:

```bash
sudo mkdir -p /home/grid/.ssh
sudo cp /tmp/grid_id_rsa.pub /home/grid/.ssh/authorized_keys
sudo chown -R grid:oinstall /home/grid/.ssh
sudo chmod 700 /home/grid/.ssh
sudo chmod 600 /home/grid/.ssh/authorized_keys
```

Test tu `grid@rac1`:

```bash
sudo su - grid
ssh -p 2222 grid@rac1 hostname
ssh -p 2222 grid@rac2 hostname
```

Ket qua hien tai:

```text
grid@rac1 -> grid@rac1 hostname = rac1
grid@rac1 -> grid@rac2 hostname = rac2
grid@rac2 -> grid@rac1 hostname = rac1
grid@rac2 -> grid@rac2 hostname = rac2
```

Ghi chu su co da gap:

```text
ssh-copy-id khong dung duoc vi PasswordAuthentication=no.
Can copy public key thu cong qua /tmp bang user tandat8896 va append vao /home/grid/.ssh/authorized_keys.
Neu local self-login fail, append chinh ~/.ssh/id_rsa.pub vao ~/.ssh/authorized_keys.
```

Lap lai cho user `oracle`:

### Oracle user passwordless SSH

Lam tuong tu `grid`, nhung ghi ro tung noi chay.

#### 10.1 Tao key cho oracle tren rac1

Tren `rac1`:

```bash
sudo su - oracle
ssh-keygen -t rsa -b 4096
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
ssh -p 2222 oracle@rac1 hostname
exit
```

Expected:

```text
rac1
```

Copy public key cua `oracle@rac1` ra `/tmp`:

```bash
sudo cp /home/oracle/.ssh/id_rsa.pub /tmp/oracle_rac1_id_rsa.pub
sudo chown tandat8896:tandat8896 /tmp/oracle_rac1_id_rsa.pub
```

#### 10.2 Copy key oracle rac1 sang rac2

Tren host NixOS:

```bash
scp -i ~/.ssh/rac_ed25519 -P 2222 tandat8896@192.168.122.205:/tmp/oracle_rac1_id_rsa.pub /tmp/oracle_rac1_id_rsa.pub
scp -i ~/.ssh/rac_ed25519 -P 2222 /tmp/oracle_rac1_id_rsa.pub tandat8896@192.168.122.46:/tmp/oracle_rac1_id_rsa.pub
```

Tren `rac2`, bang user `tandat8896`:

```bash
sudo mkdir -p /home/oracle/.ssh
sudo sh -c 'cat /tmp/oracle_rac1_id_rsa.pub >> /home/oracle/.ssh/authorized_keys'
sudo chown -R oracle:oinstall /home/oracle/.ssh
sudo chmod 700 /home/oracle/.ssh
sudo chmod 600 /home/oracle/.ssh/authorized_keys
```

Test tu `oracle@rac1`:

```bash
sudo su - oracle
ssh -p 2222 oracle@rac1 hostname
ssh -p 2222 oracle@rac2 hostname
exit
```

Expected:

```text
rac1
rac2
```

Ket qua hien tai:

```text
oracle@rac1 -> oracle@rac2 hostname = rac2
oracle@rac1 -> oracle@rac1 hostname = rac1
```

#### 10.3 Tao key cho oracle tren rac2

Tren `rac2`:

```bash
sudo su - oracle
ssh-keygen -t rsa -b 4096
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
ssh -p 2222 oracle@rac2 hostname
exit
```

Expected:

```text
rac2
```

Copy public key cua `oracle@rac2` ra `/tmp`:

```bash
sudo cp /home/oracle/.ssh/id_rsa.pub /tmp/oracle_rac2_id_rsa.pub
sudo chown tandat8896:tandat8896 /tmp/oracle_rac2_id_rsa.pub
```

#### 10.4 Copy key oracle rac2 sang rac1

Tren host NixOS:

```bash
scp -i ~/.ssh/rac_ed25519 -P 2222 tandat8896@192.168.122.46:/tmp/oracle_rac2_id_rsa.pub /tmp/oracle_rac2_id_rsa.pub
scp -i ~/.ssh/rac_ed25519 -P 2222 /tmp/oracle_rac2_id_rsa.pub tandat8896@192.168.122.205:/tmp/oracle_rac2_id_rsa.pub
```

Tren `rac1`, bang user `tandat8896`:

```bash
sudo sh -c 'cat /tmp/oracle_rac2_id_rsa.pub >> /home/oracle/.ssh/authorized_keys'
sudo chown -R oracle:oinstall /home/oracle/.ssh
sudo chmod 700 /home/oracle/.ssh
sudo chmod 600 /home/oracle/.ssh/authorized_keys
```

Final test tu `oracle@rac2`:

```bash
sudo su - oracle
ssh -p 2222 oracle@rac1 hostname
ssh -p 2222 oracle@rac2 hostname
exit
```

Expected:

```text
rac1
rac2
```

Ket qua hien tai:

```text
oracle@rac2 -> oracle@rac1 hostname = rac1
oracle@rac2 -> oracle@rac2 hostname = rac2
```

Tong ket passwordless SSH hien tai:

```text
grid@rac1   -> grid@rac1   OK
grid@rac1   -> grid@rac2   OK
grid@rac2   -> grid@rac1   OK
grid@rac2   -> grid@rac2   OK
oracle@rac1 -> oracle@rac1 OK
oracle@rac1 -> oracle@rac2 OK
oracle@rac2 -> oracle@rac1 OK
oracle@rac2 -> oracle@rac2 OK
```

### SSH config for Oracle tools

Lab da hardening SSH sang port `2222`.

Manual test co dung:

```bash
ssh -p 2222 grid@rac2 hostname
```

Nhung Oracle CVU/Grid co the goi:

```bash
ssh rac2 hostname
```

Neu khong co `~/.ssh/config`, lenh tren se dung port 22 va fail:

```text
ssh: connect to host rac2 port 22: Connection refused
PRVF-4009 : User equivalence is not set for nodes: rac2
```

Viec can lam them cho user `grid` tren ca `rac1` va `rac2`:

```bash
printf '%s\n' \
'Host rac1' \
'  HostName rac1' \
'  Port 2222' \
'  User grid' \
'' \
'Host rac2' \
'  HostName rac2' \
'  Port 2222' \
'  User grid' \
> ~/.ssh/config

chmod 600 ~/.ssh/config
```

Test bat buoc cho CVU:

```bash
ssh rac1 hostname
ssh rac2 hostname
```

Expected:

```text
rac1
rac2
```

Chup hinh:

```text
oracle_rac/screenshots/08f-passwordless-ssh-grid-oracle.png
```

## 11. Final verify

Chay tren ca hai node:

```bash
hostname
id grid
id oracle
getenforce
systemctl is-active firewalld
timedatectl
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
getent ahostsv4 rac1 rac2 rac1-priv rac2-priv rac1-vip rac2-vip rac-scan
```

Expected:

```text
grid/oracle user ton tai
/u01 directories dung owner
private/public name resolve OK
shared disks vdb/vdc/vdd chua format
chronyd active
firewalld inactive trong lab
SELinux permissive trong lab
```

## 12. Done criteria

Hoan thanh Step 06 khi:

```text
Packages installed tren rac1/rac2
Groups/users grid/oracle created tren rac1/rac2
/u01 directory tree ready
limits/sysctl configured
SELinux/firewall lab setting done
chronyd OK
passwordless SSH grid/oracle OK
Chua chay Grid installer
```
