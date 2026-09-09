ssh-keygen -t rsa -b 4096
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
  chmod 700 ~/.ssh
  chmod 600 ~/.ssh/authorized_keys
  ssh -p 2222 oracle@rac1 hostname
ssh -p 2222oracle@rac1hostname
ssh -p 2222 oracle@rac1hostname
  ssh -p 2222 oracle@rac1 hostname
exit
  ssh -p 2222 oracle@rac2 hostname
  ssh -p 2222 oracle@rac1 hostname
exit
cat > /home/oracle/db_install.rsp << 'EOF'
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/u01/app/oraInventory
ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
ORACLE_BASE=/u01/app/oracle
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=backupdba
oracle.install.db.OSDGDBA_GROUP=dgdba
oracle.install.db.OSKMDBA_GROUP=kmdba
oracle.install.db.OSRACDBA_GROUP=racdba
oracle.install.db.isRACOneInstall=false
oracle.install.db.rac.nodeList=rac1,rac2
EOF

chmod 600 /home/oracle/db_install.rsp
cd /u01/app/oracle/product/19.0.0/dbhome_1 && ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  cp /u01/app/oracle/product/19.0.0/dbhome_1/install/response/db_install.rsp /home/oracle/db_install.rsp
  grep -n "CLUSTER_NODES\|INSTALL_OPTION\|InstallEdition\|OSDBA\|OSOPER\|OSBACKUP\|OSDG\|OSKM\|OSRAC\|DECLINE_SECURITY\|ORACLE_BASE\|ORA
  CLE_HOME\|UNIX_GROUP\|INVENTORY" /home/oracle/db_install.rsp | head -30
sed -i -e 's|^UNIX_GROUP_NAME=.*|UNIX_GROUP_NAME=oinstall|' -e 's|^INVENTORY_LOCATION=.*|INVENTORY_LOCATION=/u01/app/oraInventory|' -e 's|^ORACLE_HOME=.*|ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1|' -e 's|^ORACLE_BASE=.*|ORACLE_BASE=/u01/app/oracle|' -e 's|^oracle.install.db.InstallEdition=.*|oracle.install.db.InstallEdition=EE|' -e 's|^oracle.install.db.OSDBA_GROUP=.*|oracle.install.db.OSDBA_GROUP=dba|' -e 's|^oracle.install.db.OSOPER_GROUP=.*|oracle.install.db.OSOPER_GROUP=oper|' -e 's|^oracle.install.db.OSBACKUPDBA_GROUP=.*|oracle.install.db.OSBACKUPDBA_GROUP=backupdba|' -e 's|^oracle.install.db.OSDGDBA_GROUP=.*|oracle.install.db.OSDGDBA_GROUP=dgdba|' -e 's|^oracle.install.db.OSKMDBA_GROUP=.*|oracle.install.db.OSKMDBA_GROUP=kmdba|' -e 's|^oracle.install.db.OSRACDBA_GROUP=.*|oracle.install.db.OSRACDBA_GROUP=racdba|' -e 's|^oracle.install.db.CLUSTER_NODES=.*|oracle.install.db.CLUSTER_NODES=rac1,rac2|' -e 's|^DECLINE_SECURITY_UPDATES=.*|DECLINE_SECURITY_UPDATES=true|' /home/oracle/db_install.rsp
grep -E "^UNIX_GROUP|^INVENTORY|^ORACLE_|^oracle.install.db\.(Install|OS|CLUSTER)|^DECLINE" /home/oracle/db_install.rsp
cd /u01/app/oracle/product/19.0.0/dbhome_1
./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  cd /u01/app/oracle/product/19.0.0/dbhome_1
  ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  grep -n "oracle.install.option" /home/oracle/db_install.rsp
  sed -i 's|^oracle.install.option=.*|oracle.install.option=INSTALL_DB_SWONLY|' /home/oracle/db_install.rsp
  grep "oracle.install.option" /home/oracle/db_install.rsp
  CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  ls -la /home/oracle/.ssh/
  ssh oracle@rac2 hostname
  CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  ssh -o BatchMode=yes oracle@rac2 hostname
  ssh -o BatchMode=yes oracle@rac2 "ssh -o BatchMode=yes oracle@rac1 hostname"
  ssh oracle@rac2 "ssh-keyscan -H rac1 2>/dev/null >> /home/oracle/.ssh/known_hosts"
  ssh -o BatchMode=yes oracle@rac2 "ssh -o BatchMode=yes oracle@rac1 hostname"
  CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  grep -i home /u01/app/oraInventory/ContentsXML/inventory.xml
  cd /u01/app/oracle/product/19.0.0/dbhome_1
  CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  grep '^oracle.install.db.OSRACDBA_GROUP' /home/oracle/db_install.rsp
  sed -i 's|^oracle.install.db.OSRACDBA_GROUP=.*|oracle.install.db.OSRACDBA_GROUP=dba|' /home/oracle/db_install.rsp
  grep '^oracle.install.db.OSRACDBA_GROUP' /home/oracle/db_install.rsp
  CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  grep -nE "Error in invoking target|undefined reference|cannot find|No such file|fatal error|ld:|collect2|make:" /u01/app/oraInventory/
  logs/InstallActions2026-05-27_01-56-05PM/installActions2026-05-27_01-56-05PM.log | tail -80
grep -nE "Error in invoking target|undefined reference|cannot find|No such file|fatal error|ld:|collect2|make:" /u01/app/oraInventory/logs/InstallActions2026-05-27_01-56-05PM/installActions2026-05-27_01-56-05PM.log | tail -80
  ls -l /usr/lib64/libc_nonshared.a /usr/lib64/libpthread_nonshared.a 2>&1
  ls -l /u01/app/oracle/product/19.0.0/dbhome_1/lib/stubs | grep nonshared
cd /tmp/
  vi /tmp/ora19_fstat_stub.c
sudo vi /tmp/oracle_fstat_stub.c
cat > /tmp/ora19_fstat_stub.c << 'EOF'
#include <sys/syscall.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

int fstat(int fd, struct stat *buf) __attribute__((weak));

int fstat(int fd, struct stat *buf) {
    return syscall(SYS_newfstatat, fd, "", buf, AT_EMPTY_PATH);
}
EOF

  gcc -c /tmp/ora19_fstat_stub.c -o /tmp/ora19_fstat_stub.o
cat > /tmp/ora19_fstat_stub.c << 'EOF'
#define _GNU_SOURCE

#include <sys/syscall.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

int fstat(int fd, struct stat *buf) __attribute__((weak));

int fstat(int fd, struct stat *buf) {
    return syscall(SYS_newfstatat, fd, "", buf, AT_EMPTY_PATH);
}
EOF

  gcc -c /tmp/ora19_fstat_stub.c -o /tmp/ora19_fstat_stub.o
  sudo cp -a /usr/lib64/libpthread_nonshared.a /usr/lib64/libpthread_nonshared.a.bak.step10-fstat
exit
  make -f rdbms/lib/ins_rdbms.mk irman ioracle idrdactl idrdalsnr idrdaproc ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  cd /u01/app/oracle/product/19.0.0/dbhome_1
  ls -l rdbms/lib/ins_rdbms.mk
  make -f rdbms/lib/ins_rdbms.mk irman ioracle idrdactl idrdalsnr idrdaproc ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
exit
  export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  export ORACLE_BASE=/u01/app/oracle
  export PATH=$ORACLE_HOME/bin:$PATH
sqlplus -version
  
  grep -i OraDB /u01/app/oraInventory/ContentsXML/inventory.xml
exit
  sqlplus / as sysasm
exit
  tail -n 200 /u01/app/oracle/cfgtoollogs/dbca/racdb/racdb.log
  grep -nE 'ORA-|PRCR-|CRS-|FATAL|ERROR|Exception|failed|Failed' /u01/app/oracle/cfgtoollogs/dbca/racdb/racdb.log | tail -80
  find /u01/app/oracle/diag -name 'alert_racdb*.log' -print
  tail -n 200 /u01/app/oracle/diag/rdbms/racdb/racdb1/trace/alert_racdb1.log
  export ORACLE_BASE=/u01/app/oracle
  export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  export ORACLE_SID=racdb1
  export PATH=$ORACLE_HOME/bin:$PATH
  unset TWO_TASK
  ls -l $ORACLE_HOME/dbs/initracdb1.ora $ORACLE_HOME/dbs/spfileracdb1.ora 2>&1
  cat $ORACLE_HOME/dbs/initracdb1.ora 2>/dev/null
  ls -la $ORACLE_HOME/dbs
  find $ORACLE_HOME/dbs -maxdepth 1 -type f -name '*racdb*' -o -name 'init*.ora' -o -name 'spfile*.ora'
  grep -nEi 'spfile|pfile|initracdb|racdb1|racdb2|create spfile|server parameter' /u01/app/oracle/cfgtoollogs/dbca/racdb/racdb.log | tail -120
  export ORACLE_BASE=/u01/app/oracle
  export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  export ORACLE_SID=racdb1
  export PATH=$ORACLE_HOME/bin:$PATH
  unset TWO_TASK
  printf "%s\n" "SPFILE='+DATA/RACDB/PARAMETERFILE/spfile.272.1234363849'" > $ORACLE_HOME/dbs/initracdb1.ora
  cat $ORACLE_HOME/dbs/initracdb1.ora
  sqlplus / as sysdba
  scp $ORACLE_HOME/dbs/initracdb1.ora oracle@rac2:/tmp/initracdb2.ora
  ssh oracle@rac2 "sed -i 's/initracdb1/initracdb2/g' /tmp/initracdb2.ora; mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1/dbs; cp /tmp/initracdb2.ora /u01/app/oracle/product/19.0.0/
  dbhome_1/dbs/initracdb2.ora; cat /u01/app/oracle/product/19.0.0/dbhome_1/dbs/initracdb2.ora"
  ssh oracle@rac2 "sed -i 's/initracdb1/initracdb2/g' /tmp/initracdb2.ora; mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1/dbs; cp /tmp/initracdb2.ora /u01/app/oracle/product/19.0.0/dbhome_1/dbs/initracdb2.ora; cat /u01/app/oracle/product/19.0.0/dbhome_1/dbs/initracdb2.ora"
exit
  tail -f /u01/app/oracle/cfgtoollogs/dbca/racdb/racdb.log
  find /u01/app/oracle/cfgtoollogs/dbca -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -20
  tail -f /u01/app/oracle/cfgtoollogs/dbca/silent.log_2026-05-27_02-38-07PM
exit
  export ORACLE_BASE=/u01/app/oracle
  export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  export PATH=$ORACLE_HOME/bin:$PATH
  sqlplus -version
  ssh -o BatchMode=yes oracle@rac2 hostname
  ssh -o BatchMode=yes oracle@rac2 "ssh -o BatchMode=yes oracle@rac1 hostname"
  read -s -p 'SYS password: ' SYS_PASSWORD; echo
  read -s -p 'SYSTEM password: ' SYSTEM_PASSWORD; echo
  read -s -p 'PDB admin password: ' PDB_PASSWORD; echo
  export ORACLE_BASE=/u01/app/oracle
  export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  export PATH=$ORACLE_HOME/bin:$PATH
  export CV_ASSUME_DISTID=OEL8
dbca -silent -createDatabase -templateName General_Purpose.dbc -gdbName racdb.localdomain -sid racdb -databaseConfigType RAC -nodelist rac1,rac2 -storageType ASM -diskGroupName DATA -recoveryAreaDestination FRA -characterSet AL32UTF8 -nationalCharacterSet AL16UTF16 -createAsContainerDatabase true -numberOfPDBs 1 -pdbName pdb1 -pdbAdminPassword REDACTED -sysPassword REDACTED -systemPassword REDACTED -emConfiguration NONE -totalMemory 2048 -ignorePreReqs
dbca -silent -createDatabase -templateName General_Purpose.dbc -gdbName racdb.localdomain -sid racdb -databaseConfigType RAC -nodelist rac1,rac2 -storageType ASM -diskGroupName +DATA -recoveryAreaDestination +FRA -characterSet AL32UTF8 -nationalCharacterSet AL16UTF16 -createAsContainerDatabase true -numberOfPDBs 1 -pdbName pdb1 -pdbAdminPassword REDACTED -sysPassword REDACTED -systemPassword REDACTED -emConfiguration NONE -totalMemory 2048 -ignorePreReqs 2>&1 | tee /tmp/dbca-racdb-create.log
  srvctl status database -d racdb
  export ORACLE_BASE=/u01/app/oracle
  export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  export ORACLE_SID=racdb1
  export PATH=$ORACLE_HOME/bin:$PATH
  unset TWO_TASK
srvctl add database -db racdb -dbname racdb -oraclehome /u01/app/oracle/product/19.0.0/dbhome_1 -spfile +DATA/RACDB/PARAMETERFILE/spfile.272.1234363849 -pwfile +DATA/RACDB/PASSWORD/pwdracdb.256.1234363179 -dbtype RAC -diskgroup "DATA,FRA" -role PRIMARY -startoption OPEN -stopoption IMMEDIATE -policy AUTOMATIC
srvctl add instance -db racdb -instance racdb1 -node rac1
srvctl add instance -db racdb -instance racdb2 -node rac2
srvctl config database -d racdb
  srvctl start database -d racdb
  srvctl status database -d racdb
  export ORACLE_SID=racdb1
  sqlplus / as sysdba
  srvctl status database -d racdb
  srvctl config database -d racdb | head -30
exit
sql / as sysdba
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
sql / as sysdba
unset TWO_TASK
sql / as sysdba
export ORACLE_HOME=/u01/app/19.0.0/grid
export ORACLE_SID=+ASM1
unset TWO_TASK
export PATH=$ORACLE_HOME/bin:$PATH
sqlplus / as sysasm
  echo $ORACLE_HOME
  echo $ORACLE_SID
  echo $TWO_TASK
  export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  export ORACLE_SID=racdb1
sql / as sysdba
export ORACLE_HOME=/u01/app/19.0.0/grid
sql / as sysdba
exit
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
sql / as sysdba
sql '/ as sysdba'
sqlplus --version
  export ORACLE_SID=racdb1
  sqlplus / as sysdba
srvctl status database -d racdb
  sqlplus / as sysdba
srvctl status asm
asmcmd lsdg
srvctl status database -d racdb
sqlplus / as sysdba
srvctl status database -d racdb
exit
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
srvctl stop database -d racdb -stopoption immediate
srvctl status database -d racdb
exit
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
srvctl stop database -d racdb -stopoption immediate
srvctl status database -d racdb
exit
sql / as sysdba
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
sql / as sysdba
  echo "export ORACLE_SID=racdb1" >> ~/.bash_profile
  source ~/.bash_profile
  echo $ORACLE_SID
sql / as sysdba
cat >> ~/.bash_profile << 'EOF'
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK
EOF

source ~/.bash_profile 
sql as sysdba
sql / as sysdba
srvctl status database -d racdb
  srvctl start database -d racdb
srvctl status database -d racdb
sql / as sysdba
echo 'set sqlprompt "_user'\''@'\''_connect_identifier> "' >> $ORACLE_HOME/sqlplus/admin/glogin.sql
sql / as sysdba
cat >> $ORACLE_HOME/sqlplus/admin/glogin.sql << 'EOF'
set termout off
column instance_name new_value inst
select instance_name from v\$instance;
set termout on
set sqlprompt "&inst> "
EOF

sql / as sysdba
  tail -5 $ORACLE_HOME/sqlplus/admin/glogin.sql
  sed -i 's|v\\$instance|v$instance|'
sed -i 's|v\\$instance|v$instance|' $ORACLE_HOME/sqlplus/admin/glogin.sql
tail -3 $ORACLE_HOME/sqlplus/admin/glogin.sql
sql / as sysdba
  sed -i 's|set sqlprompt "&inst> "|set sqlprompt"_user@\&inst> "|'$ORACLE_HOME/sqlplus/admin/glogin.sql
sql / as sysdba
exit
cat >> ~/.bashrc << 'EOF'

export TERM=xterm-256color
PS1='\[\e[32m\]\u\[\e[0m\]@\[\e[36m\]\h\[\e[0m\]:\[\e[33m\]\w\[\e[0m\]\$ '

EOF

source ~/.bashrc
exit
ls $ORACLE_HOME/demo/schema/
ls -la
ls 
cd $ORACLE_HOME/demo/schema/human_resources/
cat hr_main.sql | head -30
cd ..
ls 
ls -la
  ls /tmp/*.log
cat /tmp/hr_main.log 
sed -i 's/set termout off/whenever sqlerror continue\nset termout off/' $ORACLE_HOME/sqlplus/admin/glogin.sql
  $ORACLE_HOME/sqlplus/admin/glogin.sql
exit
sql / as sysdba
clear
sql sys/REDACTED@localhost:1521/pdb1 as sysdba
lsnrctl status
sql sys/REDACTED@rac1:1521/pdb1.localdomain as sysdba

sql sys/REDACTED@rac1:1521/pdb1.localdomain as sysdba
sql hr/REDACTED@rac1/pdb1.localdomain
sql sys/REDACTED@rac1:1521/pdb1.localdomain as sysdba
sql hr/REDACTED@rac1/pdb1.localdomain
exit
srvctl stop database -d racdb -stopoption immediate
srvctl status database -d racdb
exit
sql hr/REDACTED@rac1.localdomain
srvctl start database -d rac1
srvctl start database -d racdb
sql hr/REDACTED@rac1.localdomain
  crsctl stat res ora.racdb.db -t
  sql hr@rac1:1521/pdb1.localdomain
  sql / as sysdba
  sql hr@rac1:1521/pdb1.localdomain
  sql pdbadmin@rac1:1521/pdb1.localdomain
exit
    vi $ORACLE_HOME/sqlplus/admin/glogin.sql
  tee $ORACLE_HOME/sqlplus/admin/glogin.sql << 'EOF'
  define inst = ' '
  define con = ' '
  whenever sqlerror continue
  set termout off
  column instance_name new_value inst
  select instance_name from v$instance;
  column con_name new_value con
  select sys_context('USERENV','CON_NAME') con_name from dual;
  set termout on
  set sqlprompt "_user@&inst[&con]> "
  EOF






EOF

    vi $ORACLE_HOME/sqlplus/admin/glogin.sql
  sql hr@rac1:1521/pdb1.localdomain
  sql / as sysdba
  sql hr@rac1:1521/pdb1.localdomain
  sql / as sysdba
  sql hr@rac1:1521/pdb1.localdomain
  echo "set sqlformat ansiconsole" >> $ORACLE_HOME/sqlplus/admin/glogin.sql
  sql hr@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
exit
sql hr@rac1:1521/pdb1.localdomain
sql hr/REDACTED@rac1:1521/pdb1.localdomain
srvctl start database -d racdb
sql / as sysdba
srvctl stop database -d racdb
srvctl status database
srvctl start database -d racdb
sql sys/REDACTED@rac1:1521/racdb.localdomain as sysdba
sql hr/REDACTED@rac1:1521/pdb1.localdomain
  sql hr/REDACTED@rac1:1521/pdb1.localdomain
sql hr@rac1:1521/pdb1.localdomain
sql sys@rac1:1521/pdb1.localdomain
  sql sys@rac1:1521/pdb1.localdomain as sysdba
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database
srvctl stop database -db racdb
srvctl stop database -d racdb -stopoption immediate
V
srvctl status database -d racdb
exit
sql query_tuning@rac1:1521/pdb1.localdomain
exit
  srvctl status database -d racdb
  srvctl start instance -d racdb -i racdb1
sql query_tuning@rac1:1521/pdb1.localdomain
 exit
srvctl status database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
exit
srvctl start database -d racdb
exit
srvctl start database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
sql sys@rac1:1521/pdb1.localdomain
sql sys/REDACTED@rac1:1521/pdb1.localdomain as sysdba
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
exit
srvctl start database -d racdb
exit
srvctl start database -d racdb
srvctl status database -d racdb
srvctl status instance -d racdb -i racdb1
srvctl status instance -d racdb -i racdb2
set autotrace on explain
echo $1
exit
sql query_tunning@rac1:1521/pdb1.localdomain
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
exit
srvctl start database -d racdb
exit
srvctl start database -d racdb
srvctl status database -d racdb
sql query_tunning@rac1:1521/pdb1.localdomain
sql query_tuning@rac1:1521/pdb1.localdomain
ping rac2
exit
sql query_tuning@rac1:1521/pdb1.localdomain
exit
srvctl stop database -d racdb
exit
srvctl start database -d racdbb
srvctl start database -d racdb
exit
srvctl status database -d racdb
srvctl start database -d racdb
srvctl status database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
sqlplus / as sysdba
exit
srvctl start database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
exit
srvctl status database -d racdb
exit
srvctl status database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
  srvctl stop database -d racdb -stopoption immediate
exit
srvctl status database -d racdb
exit
srvctl status database 
srvctl status database - d racdb
srvctl status database -d racdb
  srvctl stop instance -d racdb -i racdb2 -o immediate
srvctl status database -d racdb
archive log list
exit
srvctl start database -d racdb
srvctl status database -d racdb
sql / as sysdba
rman target /
sql / as sysdba
srvctl stop database -db racdb -stopoption immediate
srvctl status database -d racdb
srvctl start database -db racdb -startoption mount
sql / as sysdba
  srvctl stop instance -d racdb -i racdb1 -o immediate
srvctl start database -d racdb
srvctl status database -d racdb
sql / as sysdba
rman target /
  srvctl stop database -d racdb -stopoption immediate
  srvctl status database -d racdb
exit
sql / as sysdba
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl status database -d racdb
exit
srvctl config service -d racdb
srvctl status service -d racdb
exit
show parameter cluster_interconnects;
sql / as sysdba
srvctl config database -d racdb
exit
srvctl start database -d racdb
srvctl status database -d racdb
sudo su - oracle
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
srvctl status database -d racdb
exit
srvctl start database -d racdb
srvctl status database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
exit
sql / as sysdba
exit
sql query_tuning@rac1:1521/pdb1.localdomain
exit
srvctl stop database -d racdb
exit
srvctl status database -d racdb
svrctl status database -d racdb
srvctl status database -d racdb
srvctl start database -d racdb
crsctl status resource ora.racdb.db -t
exit
srvctl status database -d racdb
sql query_tuning@racdb:1521/pdb1.localdomain
sql query_tuning@rac1:1521/pdb1.localdomain
exit
sql query_tuning@rac1:1521/pdb1.localdomain
exit
sql query_tuning@rac1:1521/pdb1.localdomain
sql / as sysdba
sql / as sysasm
sql / as sysdba
srvctl config database -d racdb
sql / as sysdba
sql query_tuning@rac1:1521/pb1.localdomain
sql query_tuning@rac1:1521/pdb1.localdomain
sql / as sysdba
exit
srvctl stop database -d racdb
srvctl status database -d racdb
exit
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl status database -d racdb
srvctl start database -d racdb1
srvctl start database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
sql / as sydba
sql / as sysdba
sql query_tuning@rac1:1521/pdb1.localdomain
exit
srvctl stop database -d racdb
exit
sql / as sysdba
exit
srvctl stop database -d racdb
exit
srvctl start database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
sql sys@rac1 as sysdba
sql sys@rac1:1521/pdb1.localdomain
sql sys/
sql sys/REDACTED@racdb1 as sysdba
     cat $ORACLE_HOME/dbs/orapw$(echo $ORACLE_SID)
sql sys/REDACTED@rac1:1521/pdb1 as sysdba
sql sys/REDACTED@rac1:1521/pdb1.localdomain as sysdba
sql / as sysdba
srvctl start database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
sql sys@rac1:1521/pdb1.localdomain as sys 
sql sys@rac1:1521/pdb1.localdomain as sysdba
srvctl stop database -d racdb
srvctl status database -d racdb
exit
sql / as sysdba
sql sys@rac1:1521/pdb1.localdomain as sysdba
exit
srvctl start database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
sql / as sysdba
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
exit
srvctl start database -d racdb
srvctl status database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
exit
srvctl start database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
exit
srvctl stop database -d racdb
exit
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl start database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
exit
mkdir -p ~/.oracle_wallet/query_tuning
chmod 700 ~/.oracle_wallet/query_tuning
sql query_tuning@rac1:1521/pdb1.localdomain
mkstore -wrl ~/.oracle_wallet/query_tuning -createCredential PDB1 query_tuning 'REDACTED'
mkstore -wrl ~/.oracle_wallet/query_tuning -create
rm -rf ~/.oracle_wallet/query_tuning
mkdir -p ~/.oracle_wallet/query_tuning
chmod 700 ~/.oracle_wallet/query_tuning
mkstore -wrl ~/.oracle_wallet/query_tuning -create
mkstore -wrl ~/.oracle_wallet/query_tuning -createCredential PDB1 query_tuning 'REDACTED'
mkstore -wrl ~/.oracle_wallet/query_tuning -createCredential PDB1 query_tuning 'REDACTED'
mkstore -wrl ~/.oracle_wallet/query_tuning -listCredential
export TNS_ADMIN=/home/oracle/.oracle_wallet/query_tuning
sqlplus /pdb1
sqlplus /@pdb1
sudo iptables -A INPUT -i enp2s0 -m statistic --mode random --probability 0.05 -j DROP
exit
whoami
exit
srvctl start database -d racdb
srvctl start database -d racdb1
srvctl start database -d oracle
srvctl start database -d racdb
exit
crsctl check crs
srvctl status database -d racdb
exit
srvctl status database -d racdb
srvctl stop instance -d racdb -i racdb2
srvctl stop instance -d racdb -i racdb1
srvctl status database -d racdb
sudo shutdown -h now
exit
rman target /
srvctl start database -d racdb
rman target /
srvctl stop database -d racdb
exit
sql /@pdb1
exit
srvctl stop database -d racdb
srvctl status database -d racdb
exit
srvctl status database -d racdb
srvctl stop database -d racdb
exit
    scp -P 2222 tandat8896@192.168.122.205:/tmp/orapwracdb_primary /tmp/orapwracdb_primary
    cp /tmp/orapwracdb_primary /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwracdb_s
    asmcmd cp +DATA/RACDB/PASSWORD/pwdracdb.256.1234363179 /tmp/orapwracdb_primary
    scp /tmp/orapwracdb_primary oracle@192.168.122.220:/tmp/orapwracdb_primary
exit
    scp /tmp/orapwracdb_s oracle@192.168.122.220:/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwracdb_s
exit
srvctl stop database -d racdb
exit
srvctl start database -d racdb
exit
srvctl status database -d racdb
srvctl start database -d racdb
srvctl status database -d racdb
srvctl stop database -d racdb
exit
srvctl start database -d racdb
srvctl stop database -d racdb
exit
sudo su - oracle
exit
sql query_tunin@rac1:1521/pdb1.localdomain
srvctl start database -d racdb
srvctl status database -d racdb
ls -la
sql query_tunin@rac1:1521/pdb1.localdomain
sql query_tuning@rac1:1521/pdb1.localdomain
sql sys/REDACTED@rac1:1521/pdb1.localdomain as sysdba
sql query_tuning@rac1:1521/pdb1.localdomanin
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl status database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
srvctl status database -d racdb
exit
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl start database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
exit
exit
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl status database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
exit
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
exit
srvctl start database -d racdb
srvctl status database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl status database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl shutdown database -d racdb
srvctl stop database -d racdb
exit
srvctl start database -d racdb
srvctl status database -d racdb
sql query_tuning@racdb1:1521/pdb1.localdomain
sql query_tuning@rac1:1521/pdb1.localdomain
exit
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl start database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl start database -d racdb
srvctl stop database -d racdb
exit
srvctl start database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl status database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
exit
srvctl status database -d racdb
exit
srvctl stop database -d racdb
srvctl database -d racdb
srvctl start database -d racdb
exit
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
exit
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
exit
srvctl start database -d racdb 
srvctl status database -d racdb
exit
srvctl stop database -d racdb
exit
srvctl start database -d racdb
srvctl status database -d racdb
srvctl start database -d racdb
srvctl status database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
exit
srvctl start database -d racdb
srvctl stop database -d racdb
exit
srvctl start database -d racdb
srvctl status database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
exit
exit
srvctl stop database -d racdb
srvctl status database -d racdb
exit
srvctl start database -d racdb
srvctl status database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
exit
srvctl status database -d racdb
srvctl start database -d racdb
sql query_tuning@rac1:1521/pdb1.localdomain
exit
sql query_tuning@rac1:pdb1.localdomain
sql query_tuning@rac1:1521/pdb1.localdomain
srvctl stop database -d racdb
srvctl status database -d racdb
exot
exit
srvctl status database -d racdb
srvctl status database -d 
srvctl status database -d racdb
vi /home/tandat8896/
cd /home/tandat8896/
srvctl status database -d racdb
srvctl start database -d racdb
srvctl status database -d racdb
history
sql / @pdb1
sql /@pdb1
exit
srvctl stop database -d racdb
exit
sql /@pdb1
srvctl start database -d racdb
srvctl status database -d racdb
srvctl start database -d racdb
sql /@pdb1
srvctl stop database -d racdb
exit
srvctl start database -d racdb
srvctl status database -d racdb
srvctl start database -d racdb
sql /@pdb1
exit
srvctl status database -d racdb
sql / @pdb1
sql query_tuning@rac1:1521/pdb1.localdomain
exit
srvctl status database -d racdb
srvctl start instance -d racdb -i racdb2
srvctl stop database -d racdb 
srvctl status database -d racdb 
exit
sql query_tuning@rac1:1521/pdb1.localdomain
sql /@pdb1
srvctl stop database -d racdb
exit
sql /@pdb1
srvctl start database -d racdb
exit
crsctl status
srvctl status database -d racdb
srvctl start database -d racdb
sql  / @pdb1
sql /@pdb1
sql / as sysdba
exit
sql / as sysdba
exit
srvctl status database -d racdb
srvctl status database -d racdb 
srvctl start database -d racdb 
srvctl status -d racdb
srvctl status database -d racdb
exit
srvctl status database -d racdb
srvctl start database -d racdb
srvctl start databse -d racdb
srvctl start database -d racdb
srvctl status database -d racdb
exit
srvctl start database -d racdb
srvctl status database -d racdb
exit
srvctl status database -d racdb
exit
srvctl stop database -d racdb
exit
srvctl start database -d racdb
srvctl status database -d racdb
srvctl start database -d racdb
exit
srvctl stop database -d racdb
exit
srvctl status database -d racdb
srvctl start database -d racdb
srvctl status database -d racdb
exit
sql /@pdb1
spool off
exit
srvctl stop database -d racdb
srvctl status database -d racdb
sudo shutdown -h now
exit
srvctl status database -d racdb
srvctl start database -d racdb -i rac1
sql 
srvctl start database -d racdb
srvctl status database -d racdb
history
ip addr show
sql query_tuning@rac1:1521/pdb1.localdomain
exit
srvctl stop database -d racdb
exit
srvctl start database -d racdb
crsctl check status
crsctl status
srvctl status database -d racdb
crsctl --help
exit
history
srvctl status
srvctl status database -d racdb
srvctl start database -d racdb
srvctl stop database -d racdb
crsctl stop cluster
crsctl 
exit
srvctl status database -d racdb
srvctl start database -d racdb
exit
sql as sysdba
sql sys / as dba;
srvctl stop database -d racdb
srvctl status database -d racdb
exit
srvctl start database -d racdb
srvctl status database -d racdb
exit
