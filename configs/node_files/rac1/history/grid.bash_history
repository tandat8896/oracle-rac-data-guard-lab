ssh-keygen -t rsa -b 4096
ssh-copy-id grid@rac1
ssh-copy-id -p 2222 grid@rac1
cat ~/.ssh/id_rsa.pub
cat /home/grid/.ssh/id_rsa.pub
  sudo mkdir -p /home/grid/.ssh
sudo mkdir -p /home/grid/.ssh
sudo cp /home/grid/.ssh/id_rsa.pub /home/grid/.ssh/authorized_keys
exit
ssh -p 2222 grid@rac1 hostname
exit
ssh -p 2222 grid@rac1 hostname
ssh -p 2222 grid@rac2 hostname
ssh -p 2222 grid@rac1 hostname
ssh -p 2222 grid@rac2 hostname
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.205
exit
ls -l /dev/asm-*
dd if=/dev/asm-ocrvote of=/dev/null bs=1M count=1
dd if=/dev/asm-data of=/dev/null bs=1M count=1
dd if=/dev/asm-fra of=/dev/null bs=1M count=1
exit
cd /u01/app/19.0.0/grid
./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
sudo dnf install -y libnsl
exit
cd /u01/app/19.0.0/grid
 ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
cd /etc/
ls
vi /etc/oraInst.loc
exit
cat ~
cat ~
cat ~/.ssh/config
  ssh rac1 hostname
ssh rac2 hostname
exit
ssh -p 2222 grid@rac1 hostname
printf '%s\n' 'Host rac1' '  HostName rac1' '  Port 2222' '  User grid' '' 'Host rac2' '  HostName rac2' '  Port 2222' '  User grid' > ~/.ssh/config
chmod 600 ~/.ssh/config
ssh rac1 hostname
cd /u01/app/19.0.0/grid
./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
chmod 600 ~/.ssh/config
./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
df -h /tmp
ls -ld /tmp
ssh rac2 'df -h /tmp; ls -ld /tmp; touch /tmp/cvu_test_grid_rac2 && rm -f /tmp/cvu_test_grid_rac2 && echo TMP_RAC2_OK'
./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose | tee /tmp/cluvfy-pre-crsinst.log
ssh rac2 'which ssh scp'
echo CVU_COPY_TEST > /tmp/cvu_copy_test_rac1.txt
scp /tmp/cvu_copy_test_rac1.txt rac2:/tmp/cvu_copy_test_from_rac1.txt
ssh rac2 'ls -l /tmp/cvu_copy_test_from_rac1.txt; cat /tmp/cvu_copy_test_from_rac1.txt; rm -f /tmp/cvu_copy_test_from_rac1.txt'
exit
~cd /u01/app/19.0.0/grid
cd /u01/app/19.0.0/grid
CV_DESTLOC=/u01/cvuwork ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
  ssh rac1 'hostname; id; ls -l /etc/oraInst.loc; cat /etc/oraInst.loc; ls -ld /u01/app/oraInventory /u01/cvuwork; touch /u01/cvuwork/grid_write_test && rm -f /u01/cvuwork/grid_write_test
  && echo CVUWORK_WRITE_OK'
  ssh rac2 'hostname; id; ls -l /etc/oraInst.loc; cat /etc/oraInst.loc; ls -ld /u01/app/oraInventory /u01/cvuwork; touch /u01/cvuwork/grid_write_test && rm -f /u01/cvuwork/grid_write_test
  && echo CVUWORK_WRITE_OK'
  ssh rac1 'touch /u01/cvuwork/grid_write_test; rm -f /u01/cvuwork/grid_write_test; echo RAC1_CVUWORK_WRITE_OK'
  ssh rac2 'touch /u01/cvuwork/grid_write_test; rm -f /u01/cvuwork/grid_write_test; echo RAC2_CVUWORK_WRITE_OK'
cd /u01/app/19.0.0/grid
ORACLE_HOME=/u01/app/19.0.0/grid ORACLE_BASE=/u01/app/grid CV_DESTLOC=/u01/cvuwork ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
find /u01/cvuwork /tmp -maxdepth 4 -type f 2>/dev/null | sort | tail -50
ls -la /u01/cvuwork
  find /u01/cvuwork -maxdepth 4 -type f -exec ls -l {} \; 2>/dev/null
ssh rac2 'ls -la /u01/cvuwork; find /u01/cvuwork -maxdepth 2 -type f | sort | tail -20'
ssh rac1 '/u01/cvuwork/CVU_19.0.0.0.0_grid/exectask -help >/tmp/exectask_rac1.out 2>&1; echo RAC1_EXECTASK_RC=$?; tail -5 /tmp/exectask_rac1.out'
ssh rac2 'ls -l /u01/cvuwork/CVU_19.0.0.0.0_grid/exectask; /u01/cvuwork/CVU_19.0.0.0.0_grid/exectask -help >/tmp/exectask_rac2.out 2>&1; echo RAC2_EXECTASK_RC=$?; tail -f /tmp/exectask_rac2.out'
scp -r /u01/cvuwork/CVU_19.0.0.0.0_grid/. rac2:/u01/cvuwork/CVU_19.0.0.0.0_grid/
ssh rac2 'ls -l /u01/cvuwork/CVU_19.0.0.0.0_grid/exectask'
ssh rac2 '/u01/cvuwork/CVU_19.0.0.0.0_grid/exectask -help >/tmp/exectask_rac2.out 2>&1; echo RAC2_EXECTASK_RC=$?; tail -5 /tmp/exectask_rac2.out'
cd /u01/app/19.0.0/grid
CV_DESTLOC=/u01/cvuwork ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
mkdir -p /u01/cvuwork/trace
rm -f /u01/cvuwork/trace/*
SRVM_TRACE=true SRVM_TRACE_LEVEL=2 CV_TRACELOC=/u01/cvuwork/trace CV_DESTLOC=/u01/cvuwork ORACLE_SRVM_REMOTESHELL=/usr/bin/ssh ORACLE_SRVM_REMOTECOPY=/usr/bin/scp ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
find /u01/cvuwork/trace /u01/cvuwork /tmp -maxdepth 5 -type f 2>/dev/null | sort | tail -80
  find /u01/cvuwork/trace /u01/cvuwork /tmp -maxdepth 5 -type f 2>/dev/null -printf '%T@ %p\n' | sort -n | tail -10
grep -nE 'PRVF-9012|UTIL_DEST|WORKDIR|not a writeable|cannot be used|Exception|ERROR|SEVERE|rac2|scp|ssh|Permission|denied|No such file' /u01/cvuwork/trace/cvutrace.log.0 | tail -120
exit
  cd /u01/app/19.0.0/grid
  CV_DESTLOC=/u01/cvuwork ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
  mkdir -p /home/grid/cvuwork /home/grid/cvutrace
  chmod 775 /home/grid/cvuwork /home/grid/cvutrace
  ssh rac2 'mkdir -p /home/grid/cvuwork /home/grid/cvutrace; chmod 775 /home/grid/cvuwork /home/grid/cvutrace; ls -ld /home/grid /home/grid/cvuwork /home/grid/cvutrace'
  ssh rac1 'touch /home/grid/cvuwork/test && rm -f /home/grid/cvuwork/test && echo RAC1_HOME_CVUWORK_OK'
  ssh rac2 'touch /home/grid/cvuwork/test && rm -f /home/grid/cvuwork/test && echo RAC2_HOME_CVUWORK_OK'
  cd /u01/app/19.0.0/grid
  CV_DESTLOC=/home/grid/cvuwork CV_TRACELOC=/home/grid/cvutrace ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
  ssh rac1 'ls -l /etc/oraInst.loc /var/opt/oracle/oraInst.loc 2>&1; cat /etc/oraInst.loc 2>/dev/null; cat /var/opt/oracle/oraInst.loc 2>/dev/null'
  ssh rac2 'ls -l /etc/oraInst.loc /var/opt/oracle/oraInst.loc 2>&1; cat /etc/oraInst.loc 2>/dev/null; cat /var/opt/oracle/oraInst.loc 2>/dev/null'
exit
  cd /u01/app/19.0.0/grid
  ORACLE_BASE=/u01/app/grid ORACLE_HOME=/u01/app/19.0.0/grid CV_DESTLOC=/home/grid/cvuwork CV_TRACELOC=/home/grid/cvutrace ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
  grep -nE 'PRVF-9012|not a writeable|Access denied|failed to upload|dest open|No such file|scp|sftp|rac2|Exception' /home/grid/cvutrace/cvutrace.log.0 | tail -80
  ssh rac1 'hostname; ls -l /bin/ksh /usr/bin/ksh 2>&1; rpm -q ksh'
CV_DESTLOC=/home/grid/cvuwork CV_TRACELOC=/home/grid/cvutrace ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
grep -nE 'PRVF-7546|PRVF-9012|PRVG-|PRKC-|PRCZ-|not a writeable|cannot be used|Access denied|failed to upload|dest open|No such file|Permission denied|ksh|Exception|rac2' /home/grid/cvutrace/cvutrace.log.0 | tail -120
  mkdir -p /home/grid/bin
  vi /home/grid/bin/scp-legacy
  chmod 755 /home/grid/bin/scp-legacy
  /home/grid/bin/scp-legacy -V 2>&1 | head -1
  cat /home/grid/bin/scp-legacy
  vi /home/grid/bin/scp-legacy
  cat /home/grid/bin/scp-legacy
  /home/grid/bin/scp-legacy -V 2>&1 | head -1
  echo LEGACY_SCP_TEST > /tmp/legacy_scp_test.txt
  /home/grid/bin/scp-legacy /tmp/legacy_scp_test.txt rac2:/home/grid/cvuwork/legacy_scp_test.txt
  ssh rac2 'cat /home/grid/cvuwork/legacy_scp_test.txt; rm -f /home/grid/cvuwork/legacy_scp_test.txt'
  sed -n l /home/grid/bin/scp-legacy
  vi /home/grid/bin/scp-legacy
  echo LEGACY_SCP_TEST > /tmp/legacy_scp_test.txt
  vi /home/grid/bin/scp-legacy
  echo LEGACY_SCP_TEST > /tmp/legacy_scp_test.txt
  /home/grid/bin/scp-legacy /tmp/legacy_scp_test.txt rac2:/home/grid/cvuwork/legacy_scp_test.txt
  ssh rac2 'cat /home/grid/cvuwork/legacy_scp_test.txt; rm -f /home/grid/cvuwork/legacy_scp_test.txt'
  rm -f /tmp/legacy_scp_test.txt
  sed -n l /home/grid/bin/scp-legacy
  vi /home/grid/bin/scp-legacy
  ssh rac2 'cat /home/grid/cvuwork/legacy_scp_test.txt; rm -f /home/grid/cvuwork/legacy_scp_test.txt'
  sed -n l /home/grid/bin/scp-legacy
  ssh rac2 'ls -l /home/grid/cvuwork | grep legacy; rm -f /home/grid/cvuwork/legacy_scp_test.txt /home/grid/cvuwork/legacy_scp_test.txt\$'
  echo LEGACY_SCP_TEST > /tmp/legacy_scp_test.txt
/home/grid/bin/scp-legacy /tmp/legacy_scp_test.txt rac2:/home/grid/cvuwork/legacy_scp_test.txt
ssh rac2 'cat /home/grid/cvuwork/legacy_scp_test.txt; rm -f /home/grid/cvuwork/legacy_scp_test.txt'
rm -f /tmp/legacy_scp_test.txt
cd /u01/app/19.0.0/grid
CV_DESTLOC=/home/grid/cvuwork CV_TRACELOC=/home/grid/cvutrace ORACLE_SRVM_REMOTECOPY=/home/grid/bin/scp-legacy ORACLE_SRVM_REMOTESHELL=/usr/bin/ssh ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
 echo $?
tail -n 80 /home/grid/cvutrace/cvutrace.log.0
  find /home/grid/cvutrace /u01/app/19.0.0/grid/cv/log /tmp -maxdepth 3 -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -20
exit
  cd /u01/app/19.0.0/grid
  CV_DESTLOC=/home/grid/cvuwork CV_TRACELOC=/home/grid/cvutrace ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
exit
  ssh -o BatchMode=yes rac2 hostname
  cd /u01/app/19.0.0/grid
  CV_DESTLOC=/home/grid/cvuwork CV_TRACELOC=/home/grid/cvutrace ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
  CV_ASSUME_DISTID=OEL8 CV_DESTLOC=/home/grid/cvuwork CV_TRACELOC=/home/grid/cvutrace ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
exit
  ps -ef | grep -E 'cluvfy|exectask|ssh|scp' | grep -v grep
  tail -n 80 /home/grid/cvutrace/cvutrace.log.0
  ps -ef | grep -E 'cluvfy|exectask|ssh|scp' | grep -v grep
  tail -n 80 /home/grid/cvutrace/cvutrace.log.0
  grep -nE 'FAILED|PRVF-|PRVG-|PRKC-|PRCZ-|INS-|ERROR|Exception|Host key|Permission denied|No such file|failed to upload|dest open|rac1|rac2' /home/grid/cvutrace/cvutrace.log.0 | tail -160
  CV_ASSUME_DISTID=OEL8 CV_DESTLOC=/home/grid/cvuwork CV_TRACELOC=/home/grid/cvutrace ./runcluvfy.sh stage -pre crsinst -n rac1,rac2
  cd /u01/app/19.0.0/grid
  CV_ASSUME_DISTID=OEL8 CV_DESTLOC=/home/grid/cvuwork CV_TRACELOC=/home/grid/cvutrace ./runcluvfy.sh stage -pre crsinst -n rac1,rac2
  ./gridSetup.sh -silent -ignorePrereq -responseFile /home/grid/gridsetup-rac.rsp
  CV_ASSUME_DISTID=OEL8 ./gridSetup.sh -silent -ignorePrereq -responseFile /home/grid/gridsetup-rac.rsp
  sudo /u01/app/19.0.0/grid/root.sh
exit
/u01/app/19.0.0/grid/gridSetup.sh -executeConfigTools -responseFile /home/grid/gridsetup-rac.rsp -silent
exit
  CV_ASSUME_DISTID=OEL8 /u01/app/19.0.0/grid/gridSetup.sh -executeConfigTools -responseFile /home/grid/gridsetup-rac.rsp -silent
srvctl start asm -n rac2
  export ORACLE_HOME=/u01/app/19.0.0/grid
  export PATH=$ORACLE_HOME/bin:$PATH
  srvctl start asm -n rac2
  sqlplus / as sysasm
  export ORACLE_SID=+ASM1
  export ORACLE_HOME=/u01/app/19.0.0/grid
  export PATH=$ORACLE_HOME/bin:$PATH
  sqlplus / as sysasm
  srvctl stop asm -n rac1 -f
  sqlplus / as sysasm
  srvctl status asm
exit
cat >> ~/.bash_profile << 'EOF'; export ORACLE_BASE=/u01/app/grid; export ORACLE_HOME=/u01/app/19.0.0/grid; export PATH=$ORACLE_HOME/bin:$PATH; EOF
echo 'export ORACLE_BASE=/u01/app/grid' >> ~/.bash_profile && echo 'export ORACLE_HOME=/u01/app/19.0.0/grid' >> ~/.bash_profile && echo 'export PATH=$ORACLE_HOME/bin:$PATH' >> ~/.bash_profile
source ~/.bash_profile
which crsctl
which asmcmd
echo $ORACLE_HOME
sudo su - oracle
exit
export ORACLE_HOME=/u01/app/19.0.0/grid
export PATH=$ORACLE_HOME/bin:$PATH
crsctl check cluster -all
srvctl status asm
asmcmd lsdg
crsctl stat res -t
ip addr show enp1s0 | grep "inet "
ip addr show enp2s0 | grep "inet "
ip route show
ping -I enp2s0 -c 3 rac2-priv
ssh rac2 'ping -I enp2s0 -c 3 rac1-priv'
  sqlplus / as sysasm
sudo su - oracle
exit
  export ORACLE_HOME=/u01/app/19.0.0/grid
  export PATH=$ORACLE_HOME/bin:$PATH
  sqlplus / as sysasm
  unset TWO_TASK
  export PATH=$ORACLE_HOME/bin:$PATH
  export ORACLE_HOME=/u01/app/19.0.0/grid
  export ORACLE_SID=+ASM1
  unset TWO_TASK
  export PATH=$ORACLE_HOME/bin:$PATH
  sqlplus / as sysasm
asmcmd lsdg
  export ORACLE_HOME=/u01/app/19.0.0/grid
  export ORACLE_SID=+ASM1
  unset TWO_TASK
  export PATH=$ORACLE_HOME/bin:$PATH
  sqlplus / as sysasm
  asmcmd lsdg
  crsctl stat res -t | grep -E 'ora.DATA.dg|ora.FRA.dg|ora.OCRVOTE.dg'
exit
  asmcmd find +DATA racdb
  asmcmd find +FRA racdb
  asmcmd ls -l +DATA/RACDB
  asmcmd ls -l +DATA/RACDB/PARAMETERFILE
  asmcmd find +DATA/RACDB spfile*
  asmcmd find +DATA/RACDB '*PARAMETER*'
  asmcmd find +DATA/RACDB '*CONTROL*'
  grep -nEi 'spfile|pfile|parameterfile|controlfile|datafile|CREATE DATABASE|CREATE SPFILE|startup|racdb1|racdb2' /u01/app/oracle/cfgtoollogs/dbca/trace.log_2026-05-27_02-38-07PM | tail -160
  asmcmd ls -l +DATA/RACDB/PASSWORD
  asmcmd find +DATA/RACDB/PASSWORD '*'
  crsctl stat res -t | grep -E 'racdb|DATA|FRA|ora.asm|ora.LISTENER|ora.scan'
  crsctl stat res ora.racdb.db -t
  crsctl stat res ora.DATA.dg -t
  crsctl stat res ora.FRA.dg -t
  crsctl stat res -t
exit
export ORACLE_HOME=/u01/app/19.0.0/grid
export ORACLE_SID=+ASM1
unset TWO_TASK
export PATH=$ORACLE_HOME/bin:$PATH
sqlplus / as sysasm
sql / as sysasm
sqlplus / as sysasm
exit
crsctl check cluster -all
crsctl stat res -t
srvctl status instance -d racdb -i racdb1
export ORACLE_HOME=/u01/app/19.0.0/grid
export ORACLE_SID=+ASM1
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK
crsctl check cluster -all
srvctl status asm
asmcmd lsdg
EXIT
exit
export ORACLE_HOME=/u01/app/19.0.0/grid
export ORACLE_SID=+ASM1
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK
crsctl check cluster -all
asmcmd lsdg
asmcmd --help
asmcmd help
ls
vi cvuwork/
cd cvuwork/
ls 
vi CVU_19.0.0.0.0_grid/
cd CVU_19.0.0.0.0_grid/
ls
ls 
vi check_network_bonding.sh 
cd ~
which asmcmd
cd /u01/app/19.0.0/grid/bin/asmcmd
cd /u01/app/19.0.0/grid/bin/
ls 
exit
export ORACLE_HOME=/u01/app/19.0.0/grid
export ORACLE_SID=+ASM1
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK
crsctl check cluster -all
srvctl status asm
ls
crsctl stat res -t
ls -l /dev/oracleasm/disks/
exit
ls -l /dev/oracleasm/disks/
cd /dev/
ls
ls -la
nv asm-data 
vi asm-data 
which vdc
ls -la
exit
cat >> ~/.bashrc << 'EOF'

export TERM=xterm-256color
PS1='\[\e[32m\]\u\[\e[0m\]@\[\e[36m\]\h\[\e[0m\]:\[\e[33m\]\w\[\e[0m\]\$ '

EOF

source ~/.bashrc
exit
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
exit
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
exit
crsctl check crs
crsctl stat res -t
exit
crsctl check cluster -all
exit
crsctl check cluster -all
crsctl stat res -t
crsctl stat res -t -init
crsctl query css votedisk
crsctl query crs activeversion
srvctl status asm
srvctl config asm
srvctl status scan
srvctl status scan listener
srvctl status scan_listener
srvctl config listener
srvctl status nodeapps -n rac2
asmcmd lsgd
asmcmd lsgd --discovery
asmcmd lsdg
asmcmd lsdg --discovery
asmcmd ls -l +DATA/RACDB
asmcmd lsct
asmcmd dsget
asmcmd spget
oldnodes
olsnodes
olsnodes -n 
olsnodes -p
olsnodes -i
olsnodes -p
oifcfg getif
oifcfg iflist
oifcfg iflist -p -n
cluvfy comp nodecon -n rac1, rac2
cluvfy comp nodecon -n rac1,rac2
cluvfy comp nodereach -n rac1,rac2
ping rac2
cluvfy comp nodereach -n rac1,rac2
ssh rac2 date
cluvfy comp nodereach -n rac1,rac2 -verbose
olsnodes -n
grid@rac1:~$ ^C
grid@rac1:~$ cluvfy comp nodereach -n rac1,rac2
crsctl check cluster -all
oifcfg getif
ping rac2-priv
exit
sudo /u01/app/19.0.0/grid/bin/crsctl start cluster -all
exit
crsctl status resource ora.racdb.db -t
exit
crsctl check cluster -all
exit
crsctl check cluster -all
crsctl stat res -t
crsctl get css reboottime
srvctl status asm
srctl status scan
srvctl status scan
srvctl status listener
srvctl status vip -n rac1
srvctl status nodeapps -n rac1
srvctl status nodeapps -n rac2
asncnd ksdg
asmcmd lsdg
asmcmd lsdsk
asmcmd ls +DATA
asmcmd ls +FRA
asmcmd +OCRVOTE
asmcmd ls +OCRVOTE
asmcmd lsct
asmcmd lsod
asmcmd dsget 
asmcmd spget
olsnodes
oifcfg getif
oifcfg iflist -p -n
cluvfy comp nodecon -n rac1,rac2
cluvfy comp admprv -o user_equiv
exit
whoami
sudo whoami
exit
sudo crsctl check crs
exit
    asmcmd ls -l +DATA/RACDB/PASSWORD/
    asmcmd pwcopy +DATA/RACDB/PASSWORD/pwdracdb.256.1234363179 /tmp/orapwracdb_s
    exit
   crsctl stat res -t
exit
crsctl stop cluster
exit
