exit
whoami
sudo whoami
ls -la
exit
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
ip -br addr
nmcli connection show
sudo nmcli connection modify enp2s0 ipv4.method manual ipv4.addresses 10.10.10.12/24 ipv6.method disabled
sudo nmcli connection up enp2s0
ip -br addr
ping -c 3 10.10.10.1
ping -c 3 10.10.10.11
sudo vi /etc/hosts 
sudo cp /etc/hosts /etc/hosts.bak.step05
sudo cp /tmp/hosts.rac /etc/hosts
getent ahostsv4 rac1 rac1.localdomain rac2 rac2.localdomain rac1-priv rac2-priv rac1-vip rac2-vip rac-scan
ping -c 3 rac1
ping -c 3 rac1-priv
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
sudo useradd -u54332 -g oracle
sudo useradd -u 54331 -g oinstall -G asmadmin,asmdba,asmoper,dba grid oracle
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
vi /etc/security/limits.d/99-oracle-rac.conf 
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
vi /etc/sysctl.d/99-oracle-rac.conf 
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
sudo mkdir -p /home/grid/.ssh
sudo cp /tmp/grid_id_rsa.pub /home/grid/.ssh/authorized_keys
sudo chown -R grid:oinstall /home/grid/.ssh
sudo chmod 700 /home/grid/.ssh
sudo chmod 600 /home/grid/.ssh/authorized_keys
sudo su - grid
  sudo cp /home/grid/.ssh/id_rsa.pub /tmp/grid_rac2_id_rsa.pub
sudo su - grid
  sudo mkdir -p /home/oracle/.ssh
  sudo sh -c 'cat /tmp/oracle_rac1_id_rsa.pub >> /home/oracle/.ssh/authorized_keys'
  sudo chown -R oracle:oinstall /home/oracle/.ssh
  sudo chmod 700 /home/oracle/.ssh
  sudo chmod 600 /home/oracle/.ssh/authorized_keys
  sudo su - oracle
  sudo cp /home/oracle/.ssh/id_rsa.pub /tmp/oracle_rac2_id_rsa.pub
  sudo chown tandat8896:tandat8896 /tmp/oracle_rac2_id_rsa.pub
  sudo su - oracle
  ssh -p 2222 oracle@rac1 hostname
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
vi /etc/udev/rules.d/99-oracle-asmdevices.rules
  ls -l /dev/asm-*
  ls -l /dev/vdb /dev/vdc /dev/vdd
sudo su - grid
sudo reboot
sudo cp /home/grid/.ssh/id_rsa.pub /tmp/grid_rac2_id_rsa.pub
sudo chown tandat8896:tandat8896 /tmp/grid_rac2_id_rsa.pub
  ls -l /dev/asm-*
  ls -l /dev/vdb /dev/vdc /dev/vdd
  ip -br addr
exit
sudo dnf install -y rsync
exit
sudo rsync -a /tmp/oracle_stage/grid_home/ /u01/app/19.0.0/grid/
sudo chown -R grid:oinstall /u01/app/19.0.0/grid
sudo chmod -R 775 /u01/app/19.0.0/grid
sudo rsync -a /tmp/oracle_stage/db_home/ /u01/app/oracle/product/19.0.0/dbhome_1/
sudo chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1
sudo chmod -R 775 /u01/app/oracle/product/19.0.0/dbhome_1
ls -l /u01/app/19.0.0/grid/gridSetup.sh
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/runInstaller
sudo -u grid test -x /u01/app/19.0.0/grid/gridSetup.sh && echo GRID_SETUP_EXEC_OK
sudo -u oracle test -x /u01/app/oracle/product/19.0.0/dbhome_1/runInstaller && echo DB_INSTALLER_EXEC_OK
du -sh /u01/app/19.0.0/grid
du -sh /u01/app/oracle/product/19.0.0/dbhome_1
ls -ld /u01/app/19.0.0/grid /u01/app/oracle/product/19.0.0/dbhome_1
ls -l /u01/app/19.0.0/grid/gridSetup.sh
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/runInstaller
exit
sudo su - grid
sudo dnf install -y libnsl
rpm -q libnsl
sudo su - grid
vi /etc/oraInst.loc
sudo vi /etc/oraInst.loc
sudo chown root:oinstall /etc/oraInst.loc
sudo chmod 664 /etc/oraInst.loc
sudo su - grid
sudo mkdir -p /u01/cvuwork
  sudo chown grid:oinstall /u01/cvuwork
sudo chmod 775 /u01/cvuwork
ls -ld /u01/cvuwork
  sudo chown root:oinstall /u01
  sudo chmod 775 /u01
  ls -ld /u01 /u01/cvuwork
  sudo su - grid
  cd /u01/app/19.0.0/grid
  sudo cp /etc/oraInst.loc /var/opt/oracle/oraInst.loc
  sudo chown root:oinstall /var/opt/oracle/oraInst.loc
  sudo chmod 664 /var/opt/oracle/oraInst.loc
  ls -l /etc/oraInst.loc /var/opt/oracle/oraInst.loc
  sudo cp /etc/oraInst.loc /var/opt/oracle/oraInst.loc
  sudo chown root:oinstall /var/opt/oracle/oraInst.loc
  sudo chmod 664 /var/opt/oracle/oraInst.loc
  ls -l /etc/oraInst.loc /var/opt/oracle/oraInst.loc
  sudo mkdir -p /var/opt/oracle
  sudo cp /etc/oraInst.loc /var/opt/oracle/oraInst.loc
  sudo chown root:oinstall /var/opt/oracle/oraInst.loc
  sudo chmod 664 /var/opt/oracle/oraInst.loc
  ls -l /etc/oraInst.loc /var/opt/oracle/oraInst.loc
sudo su - grid
  sudo dnf install -y ksh
  ls -l /bin/ksh /usr/bin/ksh
  sudo dnf install -y smartmontools ksh
  rpm -q smartmontools ksh
  sudo CVUQDISK_GRP=oinstall rpm -ivh /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm
  rpm -q cvuqdisk
  ssh rac1 'rpm -q smartmontools ksh cvuqdisk'
  ssh rac2 'rpm -q smartmontools ksh cvuqdisk'
  rpm -q smartmontools ksh cvuqdisk
ssh -o BatchMode=yes rac1 hostname
  ssh -o BatchMode=yes rac1 hostname
sudo su -grid
  ssh rac1 hostname
  ssh -o BatchMode=yes rac1 hostname
  sudo su - grid
exit
sudo su -grid
sudo su - grid
  sudo /u01/app/19.0.0/grid/root.sh
sudo dnf install -y chrony
sudo systemctl enable --now chronyd
systemctl status chronyd | grep -E "Active|running" chronyc tracking | grep "System time"
systemctl status chronyd | grep -E "Active|running"
chronyc tracking | grep "System time"
sudo su - grid
  sudo mv /u01/app/oracle/product/19.0.0/dbhome_1 /u01/app/oracle/product/19.0.0/dbhome_1.staged.backup
  sudo mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1
  sudo chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1
  sudo chmod 775 /u01/app/oracle/product/19.0.0/dbhome_1
  sudo -u oracle find /u01/app/oracle/product/19.0.0/dbhome_1 -mindepth 1 -maxdepth 1 -print
  cd /tmp
  sudo -u oracle find /u01/app/oracle/product/19.0.0/dbhome_1 -mindepth 1 -maxdepth 1 -print
  ls -ld /u01/app/oracle/product/19.0.0/dbhome_1 /u01/app/oracle/product/19.0.0/dbhome_1.staged.backup
exit
  sudo /u01/app/oracle/product/19.0.0/dbhome_1/root.sh
  sudo su - oracle
sudo su - grid
sudo su - oracle
exitg
exit
  sudo shutdown -h now
exit
clear
exit
sudo su - sh
exit
sudo su - oracle
exit
sudo su - oracle
sudo /u01/app/19.0.0/grid/bin/crsctl check cluster -all
sudo su - oracle
exot
exit
sudo tee /home/oracle/.bash_profile >/dev/null <<'EOF'
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=racdb2
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK

export PS1='[oracle@rac2:${ORACLE_SID} \W]$ '
EOF

sudo chown oracle:oinstall /home/oracle/.bash_profile
su - oracle
exit
sudo shutdown -h now
exit
sudo shutdown -h now
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
sudo shutdown -h now
sudo shutdown -h now 
sudo shutdown -h now
sudo su - oracle
sudo shutdown -h now
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
ip link show
exit
exit
sudo su - oracle
shutdown -h now 
sudo shutdown -h now
