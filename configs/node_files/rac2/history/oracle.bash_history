  ssh-keygen -t rsa -b 4096
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
  chmod 700 ~/.ssh
  chmod 600 ~/.ssh/authorized_keys
  ssh -p 2222 oracle@rac2 hostname
exit
  ssh -p 2222 oracle@rac1 hostname
  ssh -p 2222 oracle@rac2 hostname
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
ls -l /dev/vdb /dev/vdc /dev/vdd
id grid
getent group asmadmin
exit
  export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  export ORACLE_BASE=/u01/app/oracle
  export PATH=$ORACLE_HOME/bin:$PATH
  sqlplus -version
  grep -i OraDB /u01/app/oraInventory/ContentsXML/inventory.xml
exit
  export ORACLE_BASE=/u01/app/oracle
  export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
  export ORACLE_SID=racdb2
  export PATH=$ORACLE_HOME/bin:$PATH
  unset TWO_TASK
  sqlplus / as sysdba
exit
srvctl start database -d racdb
echo $ORACLE_HOME
echo $PATH
exit
sudo /u01/app/19.0.0/grid/bin/crsctl check cluster -all
exit
ping rac1
exit
sql query_tuning@rac1:1521/pdb1.localdomain
exit
sql query_tuning@rac1:1521/pdb1.localdomain
sudo su - oracle
sql query_tuning@rac2:1521/pdb1.localdomain
exit
sql query_tuning@rac2:1521/pdb1.localdomain
     lsnrctl services rac2 | grep -i pdb
sql query_tuning@rac2:1521/pdb1.localdomain
exit
sql query_tuning@rac2:1521/pdb1.localdomain
sql / as sysdba
[200~SELECT username, program, machine, module, status, COUNT(*) AS sessions
~SELECT username, program, machine, module, status, COUNT(*) AS sessions FROM v$session WHERE type = 'USER' GROUP BY username, program, machine, module, status ORDER BY sessions DESC;
SELECT username, program, machine, module, status, COUNT(*) AS sessions FROM v$session WHERE type = 'USER' GROUP BY username, program, machine, module, status ORDER BY sessions DESC;
SELECT name, db_unique_name, database_role, open_mode, cdb FROM v$database;
sql query_tuning@rac2:1521/pdb1.localdomain
exit
sql query_tuning@rac2:1521/pdb1.localdomain
srvctl status database -d racdb
sql query_tuning@rac2:1521/pdb1.localdomain
exit
mkdir -p ~/.oracle_wallet/query_tuning
chmod 700 ~/.oracle_wallet/query_tuning
mkstore -wrl ~/.oracle_wallet/query_tuning -create
mkstore -wrl ~/.oracle_wallet/query_tuning -createCredential PDB1 query_tuning 'REDACTED'
exit
srvctl status database -d racdb
exit
srvctl status database -d racdb
sudo shutdown -h now
exit
srvctl status database -d racdb
sql / @pdb1
sql query_tuning@rac2:1521/pdb1.localdomain
exit
srvctl status database -d racdb
exit
srvctl status databse -d racdb
exit
srvctl status database -d racdb 
srvctl start database -d racdb
srvctl 
exit
srvctl stop database -d racdb -i rac2
exit
srvctl status database -d racdb
srvctl start database -d rac2 
srvctl status database -d racdb
ip link show
exit
srvctl stop database -d racdb -i rac2
exit
