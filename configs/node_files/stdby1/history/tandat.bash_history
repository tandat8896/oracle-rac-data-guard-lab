  sudo hostnamectl set-hostname stdby1
  sudo tee -a /etc/hosts << 'EOF'
  192.168.122.220  stdby1  stdby1.localdomain
  192.168.122.205  rac1    rac1.localdomain
  192.168.122.46   rac2    rac2.localdomain
  192.168.122.213  rac1-scan  rac1-scan.localdomain
  EOF

EOF

  sudo sed -i '/^  EOF$/d' /etc/hosts
  cat /etc/hosts
  sudo sed -i 's/^  192\./192./g' /etc/hosts
  cat /etc/hosts
  sudo dnf install -y bc binutils elfutils-libelf elfutils-libelf-devel     gcc gcc-c++ glibc glibc-devel ksh libaio libaio-devel     libgcc libnsl libstdc++ libstdc++-devel make net-tools     nfs-utils smartmontools sysstat unzip unixODBC
  sudo groupadd -g 54321 oinstall
  sudo groupadd -g 54322 dba
  sudo groupadd -g 54323 oper
  sudo groupadd -g 54324 backupdba
  sudo groupadd -g 54325 dgdba
  sudo groupadd -g 54326 kmdba
  sudo mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1
  sudo mkdir -p /u01/app/oraInventory
  sudo chown -R oracle:oinstall /u01/app
  sudo chmod -R 775 /u01
  sudo useradd -u 54332 -g oinstall -G dba,oper,backupdba,dgdba,kmdba oracle
  sudo passwd oracle
  sudo chown -R oracle:oinstall /u01/app
  sudo chmod -R 775 /u01
  sudo mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1
  sudo mkdir -p /u01/app/oraInventory
  sudo chown -R oracle:oinstall /u01/app
  sudo chmod -R 775 /u01
  sudo setenforce 0
  sudo systemctl disable --now firewalld
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
  echo "oracle soft nofile 1024" | sudo tee /etc/security/limits.d/99-oracle.conf
  echo "oracle hard nofile 65536" | sudo tee -a /etc/security/limits.d/99-oracle.conf
  echo "oracle soft nproc 16384" | sudo tee -a /etc/security/limits.d/99-oracle.conf
  echo "oracle hard nproc 16384" | sudo tee -a /etc/security/limits.d/99-oracle.conf
  echo "oracle soft stack 10240" | sudo tee -a /etc/security/limits.d/99-oracle.conf
  echo "oracle hard stack 32768" | sudo tee -a /etc/security/limits.d/99-oracle.conf
  echo "oracle hard memlock 134217728" | sudo tee -a /etc/security/limits.d/99-oracle.conf
  echo "oracle soft memlock 134217728" | sudo tee -a /etc/security/limits.d/99-oracle.conf
  sudo setenforce 0
  sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
  sudo systemctl disable --now firewalld
exit
whoami
sudo whoami
  sudo nmcli connection modify enp1s0     ipv4.method manual     ipv4.addresses 192.168.122.220/24     ipv4.gateway 192.168.122.1     ipv4.dns 192.168.122.1     connection.autoconnect yes
  sudo nmcli connection up enp1s0
  sudo cp -r /tmp/oracle_stage/db_home/. /u01/app/oracle/product/19.0.0/dbhome_1/
  sudo chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1
  sudo su - oracle
  sudo groupadd -g 54330 racdba
  sudo usermod -aG racdba oracle
  sudo su - oracle
printf '#include <sys/syscall.h>\n#include <sys/stat.h>\n#include <fcntl.h>\n#include <unistd.h>\n\nint fstat(int fd, struct stat *buf) __attribute__((weak));\nint fstat(int fd, struct stat *buf) {\n    return syscall(SYS_newfstatat, fd, "", buf, AT_EMPTY_PATH);\n}\n' > /tmp/ora19_fstat_stub.c
  gcc -c /tmp/ora19_fstat_stub.c -o /tmp/ora19_fstat_stub.o
printf '#define _GNU_SOURCE\n#include <sys/syscall.h>\n#include <sys/stat.h>\n#include <fcntl.h>\n#include <unistd.h>\n\nint fstat(int fd, struct stat *buf) __attribute__((weak));\nint fstat(int fd, struct stat *buf) {\n    return syscall(SYS_newfstatat, fd, "", buf, AT_EMPTY_PATH);\n}\n' > /tmp/ora19_fstat_stub.c
  gcc -c /tmp/ora19_fstat_stub.c -o /tmp/ora19_fstat_stub.o
sudo cp -a /usr/lib64/libpthread_nonshared.a /usr/lib64/libpthread_nonshared.a.bak
sudo ar qf /usr/lib64/libpthread_nonshared.a /tmp/ora19_fstat_stub.o
nm /usr/lib64/libpthread_nonshared.a | grep fstat
sudo su - oracle
ls -la
printf '#include <sys/syscall.h>\n#include <sys/stat.h>\n#include <fcntl.h>\n#include <unistd.h>\n\nint stat(const char *path, struct stat *buf) __attribute__((weak));\nint stat(const char *path, struct stat *buf) {\n    return syscall(SYS_newfstatat, AT_FDCWD, path, buf, 0);\n}\n\nint lstat(const char *path, struct stat *buf) __attribute__((weak));\nint lstat(const char *path, struct stat *buf) {\n    return syscall(SYS_newfstatat, AT_FDCWD, path, buf, 0x100);\n}\n' > /tmp/stat_stub2.c
  gcc -c /tmp/stat_stub2.c -o /tmp/stat_stub2.o
  sudo ar qf /usr/lib64/libpthread_nonshared.a /tmp/stat_stub2.o
  nm /usr/lib64/libpthread_nonshared.a | grep -E " W " | grep -E "stat|lstat"
sudo su - oracle
  cat /etc/oraInst.loc
echo "inventory_loc=/u01/app/oraInventory" | sudo tee /etc/oraInst.loc && echo "inst_group=oinstall" | sudo tee -a /etc/oraInst.loc && sudo chown root:oinstall /etc/oraInst.loc && sudo chmod 664 /etc/oraInst.loc && cat /etc/oraInst.loc
  sudo mv /u01/app/oraInventory /u01/app/oraInventory.bak
  sudo mkdir -p /u01/app/oraInventory
  sudo chown oracle:oinstall /u01/app/oraInventory
  sudo chmod 775 /u01/app/oraInventory
  sudo su - oracle
  sudo /u01/app/oracle/product/19.0.0/dbhome_1/root.sh
  sudo su - oracle
exit
sudo su - oracle
exit
sql query_tuning@rac1:1521/pdb1.localdomain
sudo su - oracle
exit
    su - oracle
exit
sudo su - oracle
sudo shutdown -h now
   sqlplus / as sysdba
sudo su - oracle
sudo shutdown -h now
  sudo usermod -aG oinstall,dba tandat
  echo "tandat ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/tandat-nopasswd
  sudo chmod 440 /etc/sudoers.d/tandat-nopasswd
exit
sudo su - oracle
sudo shutdown -h now 
lsnrctl start
sudo su - oracle
sudo shutdown -h now
sudo systemctl enable --now sshd
sudo systemctl status sshd
exit
poweroff
Poweroff
sudo shutdown
sudo shutdown -h now
sudo su - oracle
sudo shutdown -h now
sudo su - oracle
exit
sudo shutdown -h now 
exit
