exit
whoami
sudo whoami
ls -la
exit
sudo mkdir -p /home/grid/.ssh
sudo vi /home/grid/.ssh/authorized_keys
exit
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
ip -br addr
nmcli connection show
sudo nmcli connection modify enp2s0 ipv4.method manual ipv4.addresses 10.10.10.11/24 ipv6.method disabled
sudo nmcli connection up enp2s0
ip -br addr
ping -c 3 10.10.10.1
cd /etc/hosts 
sudo vi /etc/hosts 
sudo cp /etc/hosts /etc/hosts.bak.step05
sudo vi /etc/hosts
cat /etc/hosts
vi /etc/hosts
cat /etc/hosts
sudo vi /etc/hosts
cat /etc/hosts
getent hosts rac1 rac2 rac1-priv rac2-priv rac1-vip rac2-vip rac-scan
getent hosts localhost
hostname
hostname -f
grep -n rac1 /etc/hosts
getent ahostsv4 rac1
getent ahostsv6 rac1
sudo vi /etc/hosts
cat /etc/hosts
getent ahostsv4 rac1 rac1.localdomain rac2 rac2.localdomain rac1-priv rac2-priv rac1-vip rac2-vip rac-scan
ping -c 3 rac2
ping -c 3 rac2-priv
getent ahostsv4 rac-scan
sudo dnf makecache
sudo dnf install -y   bc   binutils   elfutils-libelf   elfutils-libelf-devel   fontconfig-devel   gcc   gcc-c++   glibc   glibc-devel   ksh   libaio   libaio-devel   libX11   libXau   libXi   libXtst   libXrender   libXrender-devel   libgcc   libnsl   libstdc++   libstdc++-devel   libxcb   make   net-tools   nfs-utils   policycoreutils-python-utils   smartmontools   sysstat   unzip   unixODBC   unixODBC-devel
sudo dnf repolist --all | grep -Ei 'codeready|builder|devel|appstream'
sudo dnf config-manager --set-enabled ol9_codeready_builder
sudo dnf makecache
sudo dnf install -y unixODBC-devel
rpm -q unixODBC unixODBC-devel
sudo groupadd -g 54321 oinstall && sudo groupadd -g 54322 dba && sudo groupadd -g 54323 oper && sudo groupadd -g 54324 backupdba && sudo groupadd -g 54325 dgdba && sudo groupadd -g 54326 kmdba && sudo groupadd -g 54327 asmdba && sudo groupadd -g 54328 asmoper && sudo groupadd -g 54329 asmadmin
getent group oinstall dba oper backupdba dgdba kmdba asmdba asmoper asmadmin
sudo useradd -u 54331 -g oinstall -G asmadmin,asmdba,asmoper,dba grid
sudo passwd grid
sudo passwd oracle
sudo useradd -u 54332 -g oinstall -G dba,oper,backupdba,dgdba,kmdba,asmdba oracle
sudo passwd oracle
id grid
id oracle
  sudo mkdir -p /u01/app/19.0.0/grid
  sudo mkdir -p /u01/app/grid
  sudo mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1
  sudo mkdir -p /u01/app/oraInventory
  sudo chown -R grid:oinstall /u01/app/19.0.0/grid
  sudo chown -R grid:oinstall /u01/app/grid
  sudo chown -R oracle:oinstall /u01/app/oracle
  sudo chown -R grid:oinstall /u01/app/oraInventory
  sudo chmod -R 775 /u01
ls -ld /u01 /u01/app /u01/app/19.0.0/grid /u01/app/grid /u01/app/oracle /u01/app/oraInventory
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
sudo sh -c "printf '%s\n' \
'fs.aio-max-nr = 1048576' \
'fs.file-max = 6815744' \
'kernel.shmall = 2097152' \
'kernel.shmmax = 4294967296' \
'kernel.shmmni = 4096' \
'kernel.sem = 250 32000 100 128' \
'net.ipv4.ip_local_port_range = 9000 65500' \
'net.core.rmem_default = 262144' \
'net.core.rmem_max = 4194304' \
'net.core.wmem_default = 262144' \
'net.core.wmem_max = 1048576' \
> /etc/sysctl.d/99-oracle-rac.conf"
sudo sysctl --system
sysctl fs.aio-max-nr fs.file-max kernel.shmall kernel.shmmax kernel.shmmni kernel.sem net.ipv4.ip_local_port_range
getenforce
sudo setenforce 0
getenforce
sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
vi /etc/selinux/config 
sudo systemctl disable --now firewalld
systemctl is-active firewalld
systemctl is-enabled firewalld
timedatectl
systemctl status chronyd --no-pager
sudo su - grid
sudo mkdir -p /home/grid/.ssh
sudo cp /home/grid/.ssh/id_rsa.pub /home/grid/.ssh/authorized_keys
sudo chown -R grid:oinstall /home/grid/.ssh
[200~  sudo chmod 700 /home/grid/.ssh
  sudo chmod 700 /home/grid/.ssh
sudo chmod 600 /home/grid/.ssh/authorized_keys
sudo su - grid
sudo cp /home/grid/.ssh/id_rsa.pub /tmp/grid_id_rsa.pub
sudo chown tandat8896:tandat8896 /tmp/grid_id_rsa.pub
scp -i ~/.ssh/rac_ed25519 -P 2222 /tmp/grid_id_rsa.pub tandat8896@rac2:/tmp/grid_id_rsa.pub
ssh -p 2222 grid@rac1
sudo su - grid
sudo sh -c 'cat /tmp/grid_rac2_id_rsa.pub >> /home/grid/.ssh/authorized_keys'
sudo chown -R grid:oinstall /home/grid/.ssh
sudo chmod 700 /home/grid/.ssh
sudo chmod 600 /home/grid/.ssh/authorized_keys
sudo su - oracle
  sudo cp /home/oracle/.ssh/id_rsa.pub /tmp/oracle_rac1_id_rsa.pub
  sudo chown tandat8896:tandat8896 /tmp/oracle_rac1_id_rsa.pub
  sudo su - oracle
  sudo sh -c 'cat /tmp/oracle_rac2_id_rsa.pub >> /home/oracle/.ssh/authorized_keys'
  sudo chown -R oracle:oinstall /home/oracle/.ssh
  sudo chmod 700 /home/oracle/.ssh
  sudo chmod 600 /home/oracle/.ssh/authorized_keys
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
ls -l /dev/vdb /dev/vdc /dev/vdd
id grid
getent group asmadmin
sudo udevadm info --query=property --name=/dev/vdb | grep -E 'ID_SERIAL=|ID_WWN=|DEVNAME='
sudo udevadm info --query=property --name=/dev/vdc | grep -E 'ID_SERIAL=|ID_WWN=|DEVNAME='
sudo udevadm info --query=property --name=/dev/vdd | grep -E 'ID_SERIAL=|ID_WWN=|DEVNAME='
sudo sh -c "printf '%s\n' \
'KERNEL==\"vdb\", SYMLINK+=\"asm-ocrvote\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"' \
'KERNEL==\"vdc\", SYMLINK+=\"asm-data\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"' \
'KERNEL==\"vdd\", SYMLINK+=\"asm-fra\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"' \
> /etc/udev/rules.d/99-oracle-asmdevices.rules"
  sudo udevadm control --reload-rules
  sudo udevadm trigger --type=devices --action=change
  sudo udevadm settle
  ls -l /dev/asm-*
  ls -l /dev/vdb /dev/vdc /dev/vdd
sudo su - grid
sudo reboot
  ls -l /dev/asm-*
  ls -l /dev/vdb /dev/vdc /dev/vdd
  ip -br addr
exit
sudo dnf install -y rsync
exit
sudo rsync -a /tmp/oracle_stage/grid_home/ /u01/app/19.0.0/grid/
sudo chown -R grid:oinstall /u01/app/19.0.0/grid
sudo chmod -R 775 /u01/app/19.0.0/grid
ls -l /u01/app/19.0.0/grid/gridSetup.sh
sudo -u grid test -x /u01/app/19.0.0/grid/gridSetup.sh && echo GRID_SETUP_EXEC_OK
sudo rsync -a /tmp/oracle_stage/db_home/ /u01/app/oracle/product/19.0.0/dbhome_1/
sudo chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1
sudo chmod -R 775 /u01/app/oracle/product/19.0.0/dbhome_1
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/runInstaller
sudo -u oracle test -x /u01/app/oracle/product/19.0.0/dbhome_1/runInstaller && echo DB_INSTALLER_EXEC_OK
du -sh /u01/app/19.0.0/grid
du -sh /u01/app/oracle/product/19.0.0/dbhome_1
ls -ld /u01/app/19.0.0/grid /u01/app/oracle/product/19.0.0/dbhome_1
ls -l /u01/app/19.0.0/grid/gridSetup.sh
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/runInstaller
exit
hostname
getent ahostsv4 rac1 rac2 rac1-priv rac2-priv rac1-vip rac2-vip rac-scan
ping -c 3 rac2
ping -c 3 rac2-priv
ls -l /dev/asm-*
ls -l /u01/app/19.0.0/grid/gridSetup.sh
ssh -p 2222 grid@rac1 hostname
sudo su - grid
sudo dnf install -y libnsl
rpm -q libnsl
sudo su - grid
vi /etc/oraInst.loc
sudo vi /etc/oraInst.loc
sudo chown root:oinstall /etc/oraInst.loc
sudo chmod 664 /etc/oraInst.loc
  cat /etc/oraInst.loc
ls -l /etc/oraInst.loc
sudo su - grid
sudo mkdir -p /u01/cvuwork
sudo chown grid:oinstall /u01/cvuwork
[200~  sudo chmod 775 /u01/cvuwork
~[200~sudo chmod 775 /u01/cvuwork
sudo chmod 775 /u01/cvuwork
ls -ld /u01/cvuwork
sudo su - grid
sudo chown root:oinstall /u01
  sudo chown root:oinstall /u01
  sudo chmod 775 /u01
  ls -ld /u01 /u01/cvuwork
  sudo su - grid
  cd /u01/app/19.0.0/grid
  sudo mkdir -p /var/opt/oracle
  sudo cp /etc/oraInst.loc /var/opt/oracle/oraInst.loc
  sudo chown root:oinstall /var/opt/oracle/oraInst.loc
  sudo chmod 664 /var/opt/oracle/oraInst.loc
  ls -l /etc/oraInst.loc /var/opt/oracle/oraInst.loc
sudo su - grid
  ls -l /u01/app/19.0.0/grid/OPatch/opatch
  /u01/app/19.0.0/grid/OPatch/opatch version
  exit
  ls -l /usr/bin/scp /usr/bin/scp.openssh-original 2>&1
  sudo cp -a /usr/bin/scp.openssh-original /usr/bin/scp
  sudo rm -f /home/grid/bin/scp-legacy
  sudo rmdir /home/grid/bin 2>/dev/null || true
  ls -l /home/grid/bin/scp-legacy 2>&1
  rpm -q ksh cvuqdisk
  sudo dnf install -y ksh
  sudo CVUQDISK_GRP=oinstall rpm -ivh /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm
  sudo dnf install -y smartmontools ksh
  rpm -q smartmontools ksh
  sudo CVUQDISK_GRP=oinstall rpm -ivh /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm
  rpm -q cvuqdisk
  ssh rac1 'rpm -q smartmontools ksh cvuqdisk'
  ssh rac2 'rpm -q smartmontools ksh cvuqdisk'
  rpm -q smartmontools ksh cvuqdisk
  sudo su - grid
exit
sudo su - grid
sudo su - oracle
exit
sudo su - oracle
exit
  sudo /u01/app/19.0.0/grid/root.sh
  sudo su - grid
  CV_ASSUME_DISTID=OEL8 /u01/app/19.0.0/grid/gridSetup.sh -executeConfigTools -responseFile /home/grid/gridsetup-rac.rsp -silent
sudo su - grid
sudo dnf install -y chrony
sudo systemctl enable --now chronyd
systemctl status chronyd | grep -E "Active|running"
chronyc tracking | grep "System time"
sudo su - grid
sudo su - oracle
  sudo cp -a /usr/lib64/libpthread_nonshared.a /usr/lib64/libpthread_nonshared.a.bak.step10-fstat
  sudo ar qf /usr/lib64/libpthread_nonshared.a /tmp/ora19_fstat_stub.o
  nm /usr/lib64/libpthread_nonshared.a | grep ' fstat\| W fstat'
  sudo su - oracle
  sudo /u01/app/oracle/product/19.0.0/dbhome_1/root.sh
  /u01/app/oracle/product/19.0.0/dbhome_1/bin/sqlplus -version
  sudo su - oracle
sudo su - grid
sudo su - oracle
sqlplus / as sysasm
sudo su - grid
sudo su - oracle
exit
exit
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
sudo /u01/app/19.0.0/grid/bin/crsctl check cluster -all
  sudo shutdown -h now
sudo /u01/app/19.0.0/grid/bin/crsctl check cluster -all
sudo su - oracle
sudo su - grid
sudo su - oracle
sudo su - grid
exit
sudo su - oracle
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
exit
sudo su - grid
ls -l /dev/oracleasm/disks/
sudo su - grid
sudo su - oracle
exit
ls -l /etc/udev/rules.d/
cat /etc/udev/rules.d/99-oracle-asmdevices.rules 
cd /etc/hosts
cd /etc/NetworkManager/system-connections/
ls 
cat enp1s0.nmconnection 
sudo cat enp1s0.nmconnection
sudo cat enp2s0.nmconnection
ls
cd ..
ls 
cat /etc/NetworkManager/NetworkManager.conf
sudo vi /etc/hosts
cd /etc/hosts
cd /etc/
ls 
which ocr
cd ~
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
exit
sudo su - oracle
exit
sudo su - oracle
cat >> ~/.bashrc << 'EOF'

export TERM=xterm-256color
PS1='\[\e[32m\]\u\[\e[0m\]@\[\e[36m\]\h\[\e[0m\]:\[\e[33m\]\w\[\e[0m\]\$ '

EOF

source ~/.bashrc
sudo su - oracle
sudo su - grid 
sudo su - oracle
srvctl stop database -d racdb -stopoption immediate
exit
sudo su - oracle
sudo su - grid
  sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
sudo shutdown -h now
sql hr/REDACTED@rac1.localdomain
sudo su - oracle
    vi $ORACLE_HOME/sqlplus/admin/glogin.sql
sudo su - oracle
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
exit
sudo shutdown -h now
sudo su - oracle
sudo su - grid
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
exit
sudo su - oracle
srvctl start database -d racdb
  srvctl status database -d racdb
sudo su - oracle
exit
srvctl status database -d racdb
sudo su - oracle
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
EXIT
exut
exit
sudo su - oracle
sudo su - grid
sudo su - oracle
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
exit
sudo su - grid 
sudo su - oracle
sudo su - grid
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
exit
sudo su - grid
sudo /u01/app/19.0.0/grid/bin/crsctl start cluster -all
sudo su - oracle
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
exit
sudo su - sh
sudo su - oracle
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
sudo /u01/app/19.0.0/grid/bin/crsctl start cluster -all
sudo su - oracle
exit
sudo su - oracle
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
exit
sudo su - oracle
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
sudo /u01/app/19.0.0/grid/bin/crsctl start cluster -all
sudo su - oracle
exit
sudo su - grid
sudo su - oracle
exit
  sudo /u01/app/19.0.0/grid/bin/crsctl check cluster -all
sudo su - oracle
  sudo /u01/app/19.0.0/grid/bin/crsctl check crs
  sudo /u01/app/19.0.0/grid/bin/crsctl stat res -t
  sudo /u01/app/19.0.0/grid/bin/crsctl check crs
  sudo /u01/app/19.0.0/grid/bin/crsctl stat res -t
sudo su - oracle
  sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
exit
  sudo shutdown -h now
sudo su - oracle
exit
sudo su - oracle
  sudo /u01/app/19.0.0/grid/bin/crsctl check cluster -all
sudo su - oracle
  sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
sudo shutdown -h now
sql / as sysdba
sudo su - oracle
srvctl status service -d racdb
sql / as sysdba
sudo su - oracle
exit
exit
sudo su - oracle
sql / as sysdba
sudo su - oracle
exit
sudo su - oracle;
exit
sudo su - oracle
exit
sudo su - oracle
crsctl status resource ora.racdb.db -t
sudo su - grid
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
sudo su - grid
sudo /u01/app/19.0.0/grid/bin/crsctl start cluster -all
sudo su - grid
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
sudo su - oracle
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
exit
exot
exit
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - grid
exit
sudo su - oracle
crsctl check crs
sudo su - oracle
sudo /u01/app/19.0.0/grid/crsctl check cluster -all
sudo /u01/app/19.0.0/grid/bin/crsctl check crs
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
sudo su - grid
exit
which grid
id grid
grep "^grid:" /etc/passwd
exit
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
exit
sudo shutdown -h now
exit
sudo su - oracle
exit
sudo su - grid
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
sudo su - grid
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
ping -c 3 192.168.122.205
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
sudo shutdown -h now
sudo su oracle
sudo su - oracle
exit
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
  cp ~/setup_olist_schema.sql /home/oracle/
  cp ~/setup_olist_schema.sql /tmp/
rm -f /tmp/setup_olist_schema.sql 
  cp ~/setup_olist_schema.sql /tmp/
exir
exi
exit
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
exit
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
exit
sudo su - oracle
sudo shutdown -h now 
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
cat /etc/os-release 
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
sudo shutdown -h now
exit
sudo su - oracle
exit
sudo shutdown -h now
sudo su - oracle
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
sudo shutdown -h now 
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
ip a
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
exit
sudo shutdown -h now
sudo su - oracle
exit
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
sudo shutdown -h now
exit
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
exit
sudo shutdown -h now
sudo su 
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
sudo su - oracel
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
crsctl status database -d racdb
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
exit
sudo shutdown -h now
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
exit
sudo su - oracle
exit
sudo su - oracle
srvctl stop database -d racdb
sudo su - oracle 
sudo shutdown -h now 
sudo su - oracle
exit
sudo su - oracle
sudo shutdown -h now 
sudo shutdown -h now
sudo su - oracle
crsctl --help
sudo su - oracle
crsctl stop cluster
sudo su - grid
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
sudo shutdown -h now
sudo su - oracle
exixt
exit
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
exit
