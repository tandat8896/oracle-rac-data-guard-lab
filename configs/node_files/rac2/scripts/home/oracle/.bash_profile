export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_SID=racdb2
export PATH=$ORACLE_HOME/bin:$PATH
unset TWO_TASK

export PS1='[oracle@rac2:${ORACLE_SID} \W]$ '
export TNS_ADMIN=/home/oracle/.oracle_wallet/query_tuning
