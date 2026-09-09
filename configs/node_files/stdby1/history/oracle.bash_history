  cp /u01/app/oracle/product/19.0.0/dbhome_1/install/response/db_install.rsp /home/oracle/db_install.rsp
  sed -i     -e 's|^oracle.install.option=.*|oracle.install.option=INSTALL_DB_SWONLY|'     -e 's|^UNIX_GROUP_NAME=.*|UNIX_GROUP_NAME=oinstall|'     -e 's|^INVENTORY_LOCATION=.*|INVENTORY_LOCATION=/u01/app/oraInventory|'     -e 's|^ORACLE_HOME=.*|ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1|'     -e 's|^ORACLE_BASE=.*|ORACLE_BASE=/u01/app/oracle|'     -e 's|^oracle.install.db.InstallEdition=.*|oracle.install.db.InstallEdition=EE|'     -e 's|^oracle.install.db.OSDBA_GROUP=.*|oracle.install.db.OSDBA_GROUP=dba|'     -e 's|^oracle.install.db.OSOPER_GROUP=.*|oracle.install.db.OSOPER_GROUP=oper|'     -e 's|^oracle.install.db.OSBACKUPDBA_GROUP=.*|oracle.install.db.OSBACKUPDBA_GROUP=backupdba|'     -e 's|^oracle.install.db.OSDGDBA_GROUP=.*|oracle.install.db.OSDGDBA_GROUP=dgdba|'     -e 's|^oracle.install.db.OSKMDBA_GROUP=.*|oracle.install.db.OSKMDBA_GROUP=kmdba|'     -e 's|^DECLINE_SECURITY_UPDATES=.*|DECLINE_SECURITY_UPDATES=true|'     /home/oracle/db_install.rsp
  cd /u01/app/oracle/product/19.0.0/dbhome_1
  CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  exit
  CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  cd /u01/app/oracle/product/19.0.0/dbhome_1
  CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  sed -i 's|^oracle.install.db.OSRACDBA_GROUP=.*|oracle.install.db.OSRACDBA_GROUP=racdba|' /home/oracle/db_install.rsp
  grep OSRACDBA /home/oracle/db_install.rsp
  CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
exit
  export ORACLE_BASE=/u01/app/oracle
  export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  export PATH=$ORACLE_HOME/bin:$PATH
  cd $ORACLE_HOME
  ./bin/relink all 2>&1 | tail -30
  grep -i 'error\|FAIL' /u01/app/oracle/product/19.0.0/dbhome_1/install/relinkActions2026-06-16_03-45-04PM.log | tail -20
sqlplus -V
  grep -E 'undefined reference|cannot find|ld:|error:' /u01/app/oracle/product/19.0.0/dbhome_1/install/relinkActions2026-06-16_03-45-04PM.log | head -30
  ls -la $ORACLE_HOME/bin/oracle
  cd /u01/app/oracle/product/19.0.0/dbhome_1
  make -f rdbms/lib/ins_rdbms.mk irman ioracle idrdactl idrdalsnr idrdaproc ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
exit
  export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  cd $ORACLE_HOME
  make -f rdbms/lib/ins_rdbms.mk irman ioracle idrdactl idrdalsnr idrdaproc ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  echo $?
  ls -lh $ORACLE_HOME/bin/oracle
  ls -lh $ORACLE_HOME/bin/rman
cd $ORACLE_HOME && CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -local -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  cat /u01/app/oraInventory/ContentsXML/inventory.xml
  exit
  cd /u01/app/oracle/product/19.0.0/dbhome_1
  CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
  exit
echo "export ORACLE_BASE=/u01/app/oracle" >> ~/.bash_profile && echo "export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1" >> ~/.bash_profile && echo "export ORACLE_SID=racdb_s" >> ~/.bash_profile && echo 'export PATH=$ORACLE_HOME/bin:$PATH' >> ~/.bash_profile && echo "unset TWO_TASK" >> ~/.bash_profile && source ~/.bash_profile && sqlplus -V
srvctl status database -d racdb
srvctl start database -d racdb
srvctl status database -d racdb
  sqlplus / as sysdba
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
  cat $ORACLE_HOME/network/admin/listener.ora
  lsnrctl start
  lsnrctl status
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
  cat $ORACLE_HOME/network/admin/tnsnames.ora
  orapwd file=$ORACLE_HOME/dbs/orapwracdb_s password=REDACTED entries=10
  mkdir -p /u01/app/oracle/oradata/RACDB_S/arch
  echo "db_name=racdb" > $ORACLE_HOME/dbs/initracdb_s.ora
  echo "db_unique_name=racdb_s" >> $ORACLE_HOME/dbs/initracdb_s.ora
  sqlplus / as sysdba
  tnsping racdb
  set +H
  rman target sys/REDACTED@racdb auxiliary /
  echo "RACDB =" > $ORACLE_HOME/network/admin/tnsnames.ora
  echo "  (DESCRIPTION =" >> $ORACLE_HOME/network/admin/tnsnames.ora
  echo "    (ADDRESS = (PROTOCOL = TCP)(HOST = rac1-scan)(PORT = 1521))" >> $ORACLE_HOME/network/admin/tnsnames.ora
  echo "    (CONNECT_DATA =" >> $ORACLE_HOME/network/admin/tnsnames.ora
  echo "      (SERVER = DEDICATED)" >> $ORACLE_HOME/network/admin/tnsnames.ora
  echo "      (SERVICE_NAME = racdb.localdomain)" >> $ORACLE_HOME/network/admin/tnsnames.ora
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
  tnsping racdb
  rman target sys/REDACTED@racdb auxiliary /
  rman target sys/REDACTED@racdb auxiliary sys/REDACTED@racdb_s
  rm -f $ORACLE_HOME/dbs/spfileracdb_s.ora
  sqlplus / as sysdba
  rman target sys/REDACTED@racdb auxiliary sys/REDACTED@racdb_s
  mkdir -p /u01/app/oracle/admin/racdb_s/adump
  mkdir -p /u01/app/oracle/admin/racdb/adump
  chown -R oracle:oinstall /u01/app/oracle/admin
  sqlplus / as sysdba
  rman target sys/REDACTED@racdb auxiliary sys/REDACTED@racdb_s
  sqlplus / as sysdba
  rman target sys/REDACTED@racdb auxiliary sys/REDACTED@racdb_s
  shutdown auxiliary immediate;
  sqlplus / as sysdba
  rm -f $ORACLE_HOME/dbs/spfileracdb_s.ora
  mkdir -p /u01/app/oracle/oradata/RACDB_S/fra
  sqlplus / as sysdba
  rman target sys/REDACTED@racdb auxiliary sys/REDACTED@racdb_s
  mkdir -p /u01/app/oracle/oradata/RACDB_S/onlinelog
  sqlplus / as sysdba
  sql / as sysdba
exit
orapwd file=/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwracdb_s password='REDACTED' force=y
orapwd file=/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwracdb_s password='REDACTED' force=y format=12.2
orapwd describe file=/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwracdb_s
orapwd file=/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwracdb_s password='REDACTED' force=y format=12.2 dbuniquename=racdb_s
sqlplus / as sysdba
  orapwd file=/u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwracdb_s password='REDACTED' force=y format=12.2 sysdg=y
sql / as sysdba
exit
sql query_tuninng@rac1:1521/pdb1.localdomain
exit
    cp /tmp/orapwracdb_primary /u01/app/oracle/product/19.0.0/dbhome_1/dbs/orapwracdb_s
      export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
      ls -la \$ORACLE_HOME/bin/orapwd
      getent group oinstall
    sudo su - oracle
    dgmgrl /
exit
sql / as sysdba
exit
   sqlplus / as sysdba
   nohup dgmgrl sys/REDACTED@racdb "start observer" > /home/oracle/observer.log 2>&1 &
    dgmgrl sys/REDACTED@racdb
sql / as sysdba
exit
  mkdir -p /home/oracle/.oracle_wallet/stdby1
  orapki wallet create -wallet /home/oracle/.oracle_wallet/stdby1 -auto_login
  mkstore -wrl /home/oracle/.oracle_wallet/stdby1 -createCredential racdb_s sys 'REDACTED'
  mkstore -wrl /home/oracle/.oracle_wallet/stdby1 -createCredential racdb sys 'REDACTED'
  export TNS_DIR=/u01/app/oracle/product/19.0.0/dbhome_1/network/admin
  echo "WALLET_LOCATION = (SOURCE = (METHOD = FILE)(METHOD_DATA = (DIRECTORY = /home/oracle/.oracle_wallet/stdby1)))" >> $TNS_DIR/sqlnet.ora
  echo "SQLNET.WALLET_OVERRIDE = TRUE" >> $TNS_DIR/sqlnet.ora
sql /racdb_s as sysdba
  sqlplus /@racdb_s as sysdba
lsnrctl start
sql /@racdb_s as sysdba
   nohup dgmgrl sys/REDACTED@racdb "start observer" > /home/oracle/observer.log 2>&1 &
sql /@racdb_s as sysdba
   nohup dgmgrl sys/REDACTED@racdb "start observer" > /home/oracle/observer.log 2>&1 &
  kill 1762
ps aux
  kill %1 %2 2>/dev/null; jobs
   nohup dgmgrl sys/REDACTED@racdb "start observer" > /home/oracle/observer.log 2>&1 &
sql /@racdb_s as sysdba
kill 1970
sql / as sydba
sql /@racdb_s as sysdba
exit
lsnrctl status
lsnrctl start
sql /@racdb_s as sysdba
   nohup dgmgrl sys/REDACTED@racdb "start observer" > /home/oracle/observer.log 2>&1 &
tnsping racdb
shutdown immediate;
sql / @racdb_s as sysdba
   sqlplus / as sysdba
exit
sql query_tuning@stdby1:1521/pdb1.localdomain
lsnrctl status
lsnrctl start
sql query_tuning@racdb_s:1521/pdb1.localdomain
sql / as sysdba
lsnrctl status
sql / as sysdba
lsnrctl status
sql /@racdb_s as sysdba
exit
