# Step 10 - Install Oracle Database 19c Software on RAC

Muc tieu: cai Oracle Database 19c software tren ca rac1 va rac2.
Chi cai software, CHUA tao database. Database tao o Step tiep theo.

Dieu kien truoc khi chay Step nay:

```text
Grid Infrastructure da cai xong (Step 09 done)
crsctl check cluster -all: CRS/CSS/EVM online tren ca hai node
ASM online tren ca hai node
/u01/app/oracle/product/19.0.0/dbhome_1 da co files tren rac1 de chay runInstaller
/u01/app/oracle/product/19.0.0/dbhome_1 tren rac2 phai rong de installer tu copy remote DB home
oracle user ton tai tren ca hai node, owner dbhome_1
```

Important correction:

```text
Grid home can be staged tren ca hai node.
Database home software-only RAC install thi runInstaller chay tu rac1 va tu copy sang rac2.
Neu rac2 dbhome_1 da co files tu Step 08, runInstaller se fail:
  INS-35100 The Oracle home location contains directories or files on following remote nodes:[rac2].
```

## 1. Precheck DB home

Chay tren rac1, user oracle:

```bash
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/runInstaller
ls -ld /u01/app/oracle/product/19.0.0/dbhome_1
id oracle
```

Expected:
```text
runInstaller ton tai va executable
Owner: oracle:oinstall
```

## 2. Tao response file

Dung template co san trong installer thay vi tu viet.

Tai sao dung template:
```text
Oracle installer validate response file theo XML schema nghiem ngat.
Tu viet de bi sai ten parameter hoac sai thu tu.
Template dam bao dung schema, chi can dien gia tri vao.
Vi du sai gap: oracle.install.db.rac.nodeList (sai) vs oracle.install.db.CLUSTER_NODES (dung)
```

Chay tren rac1, user oracle:

```bash
# Copy template ra thu muc home:
cp /u01/app/oracle/product/19.0.0/dbhome_1/install/response/db_install.rsp /home/oracle/db_install.rsp

# Xem cac dong can dien (verify ten parameter truoc khi sed):
grep -n "CLUSTER_NODES\|InstallEdition\|OSDBA\|OSOPER\|OSBACKUP\|OSDG\|OSKM\|OSRAC\|DECLINE_SECURITY\|ORACLE_BASE\|ORACLE_HOME\|UNIX_GROUP\|INVENTORY" \
  /home/oracle/db_install.rsp | head -30
```

Tai sao xem truoc khi sed:
```text
Ten parameter co the thay doi theo version Oracle.
Xem truoc de confirm ten parameter khop voi sed expression.
Tranh sed khong thay gi (silent fail) vi ten bi khac.
```

Dien gia tri bang sed:

```bash
sed -i \
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
  -e 's|^oracle.install.db.CLUSTER_NODES=.*|oracle.install.db.CLUSTER_NODES=rac1,rac2|' \
  -e 's|^DECLINE_SECURITY_UPDATES=.*|DECLINE_SECURITY_UPDATES=true|' \
  /home/oracle/db_install.rsp
```

Verify sau khi sed:

```bash
grep -E "^UNIX_GROUP|^INVENTORY|^ORACLE_|^oracle.install.db\.(Install|OS|CLUSTER)|^DECLINE" /home/oracle/db_install.rsp
```

Expected:
```text
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
oracle.install.db.CLUSTER_NODES=rac1,rac2
DECLINE_SECURITY_UPDATES=true
```

Ket qua thuc te 2026-05-27: tat ca parameters da dien dung.

## 3. Setup SSH user equivalence cho oracle user

Installer DB can SSH passwordless tu oracle@rac1 sang oracle@rac2 (va nguoc lai) de copy files va chay remote commands.

Tai sao can buoc nay:
```text
Grid installer dung user grid da co SSH setup rieng.
DB installer dung user oracle - phai setup SSH rieng cho oracle.
Neu khong co: INS-30132 "User equivalence unavailable on all the specified nodes".
```

Kiem tra key da ton tai tren rac1 (user oracle):
```bash
ls -la /home/oracle/.ssh/
```

Test SSH tu rac1 sang rac2:
```bash
ssh oracle@rac2 hostname
```

Neu prompt "Are you sure you want to continue connecting (yes/no)": nhap `yes` de add vao known_hosts.

Neu SSH thanh cong (tra ve "rac2"): user equivalence da OK, chay tiep Section 4.

Neu SSH bi password prompt: can add public key cua oracle@rac1 vao authorized_keys cua oracle@rac2:
```bash
# Tren rac1, user oracle:
cat /home/oracle/.ssh/id_rsa.pub

# Tren rac2, user tandat8896 - them key vao oracle authorized_keys:
sudo bash -c 'cat >> /home/oracle/.ssh/authorized_keys' << 'EOF'
<paste id_rsa.pub content here>
EOF
sudo chown oracle:oinstall /home/oracle/.ssh/authorized_keys
sudo chmod 600 /home/oracle/.ssh/authorized_keys
```

Ket qua thuc te 2026-05-27: oracle@rac1 da co id_rsa va id_rsa.pub tu Step truoc.
SSH oracle@rac2 chi can accept host key (yes), khong bi password prompt.

Tuy nhien installer kiem tra ca 2 chieu: rac1→rac2 VA rac2→rac1.
Rac2→rac1 bi "Host key verification failed" vi oracle@rac2 chua co rac1 trong known_hosts.

Fix: them rac1 host key vao known_hosts cua oracle@rac2:
```bash
ssh oracle@rac2 "ssh-keyscan -H rac1 2>/dev/null >> /home/oracle/.ssh/known_hosts"
```

Verify ca 2 chieu:
```bash
ssh -o BatchMode=yes oracle@rac2 hostname
ssh -o BatchMode=yes oracle@rac2 "ssh -o BatchMode=yes oracle@rac1 hostname"
```

Expected: ca 2 lenh tra ve hostname khong prompt gi.

## 4. Chay runInstaller

Chi chay tren rac1. Installer tu copy sang rac2 qua SSH dua vao CLUSTER_NODES.

Tai sao phai them `INSTALL_DB_SWONLY` vao response file:
```text
Oracle 19c: khi set CLUSTER_NODES, bat buoc phai set oracle.install.option=INSTALL_DB_SWONLY.
Neu khong: INS-35971 "Specifying a list of cluster nodes is only applicable for software only installation option."
Software-only install = chi cai binary, CHUA tao database. Database tao o Step tiep theo bang DBCA.
```

Add option vao response file:
```bash
sed -i 's|^oracle.install.option=.*|oracle.install.option=INSTALL_DB_SWONLY|' /home/oracle/db_install.rsp
grep "oracle.install.option" /home/oracle/db_install.rsp
```

Expected: `oracle.install.option=INSTALL_DB_SWONLY`

Tai sao phai them `CV_ASSUME_DISTID=OEL8`:
```text
Oracle 19.3 installer khong nhan dien OL9 tai state 'supportedOSCheck'.
Throw NullPointerException: INS-08101.
CV_ASSUME_DISTID=OEL8 bao cho CVU (Cluster Verification Utility) gia lap la dang chay OEL8.
Giong het Grid installer - cung root cause.
```

Chay installer:
```bash
cd /u01/app/oracle/product/19.0.0/dbhome_1
CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
```

Tai sao -ignorePrereqFailure:
```text
OL9 khong duoc certify cho Oracle 19.3 base.
CVU prereq check bao fail cho OS version.
-ignorePrereqFailure cho phep install tiep tuc du prereq warn/fail.
Dung OK cho lab, production nen fix prereq truoc.
```

Installer chay lau (~10-15 phut). Theo doi log:

```bash
# Tim log moi nhat:
ls -lt /u01/app/oraInventory/logs/installActions*.log | head -3

# Theo doi real-time:
tail -f /u01/app/oraInventory/logs/installActions<timestamp>.log
```

### Fix INS-35100 remote DB home not empty

Neu gap:

```text
[FATAL] [INS-35100] The Oracle home location contains directories or files on following remote nodes:[rac2].
```

Nguyen nhan:

```text
rac2:/u01/app/oracle/product/19.0.0/dbhome_1 khong rong.
DB installer can remote ORACLE_HOME rong de copy software tu rac1 sang rac2.
Inventory tren rac1 chi co Grid home khong chung minh remote dbhome_1 rong.
```

Fix tren `rac2`, user `tandat8896`:

```bash
sudo mv /u01/app/oracle/product/19.0.0/dbhome_1 /u01/app/oracle/product/19.0.0/dbhome_1.staged.backup
sudo mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1
sudo chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1
sudo chmod 775 /u01/app/oracle/product/19.0.0/dbhome_1
sudo -u oracle find /u01/app/oracle/product/19.0.0/dbhome_1 -mindepth 1 -maxdepth 1 -print
```

Expected:

```text
Lenh find khong in gi, nghia la remote DB home tren rac2 rong.
```

Sau do chay lai installer tren `rac1`, user `oracle`:

```bash
cd /u01/app/oracle/product/19.0.0/dbhome_1
CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
```

### Fix relink: undefined reference to `fstat`

Neu installer fail tai link target:

```text
[FATAL] Error in invoking target 'irman ioracle idrdactl idrdalsnr idrdaproc'
of makefile '/u01/app/oracle/product/19.0.0/dbhome_1/rdbms/lib/ins_rdbms.mk'
```

Va log co:

```text
/usr/bin/ld: .../lib/libjavavm19.a(eobtl.o): undefined reference to `fstat'
make: *** [.../rdbms/lib/ins_rdbms.mk:840: .../rdbms/lib/oracle] Error 1
```

Nguyen nhan:

```text
OL9 dung glibc moi. Oracle 19.3 base link static vao mot so symbol cu nhu stat/lstat/fstat.
Grid home da gap nhom loi nay o Step 09. DB home gap tiep voi symbol fstat trong libjavavm19.a.
Chinh thong: apply DB RU 19.19+ tu MOS. Lab workaround: them weak symbol fstat vao libpthread_nonshared.a roi relink lai DB home.
```

Fix tren `rac1`, user `tandat8896`:

```bash
cd /tmp
vi /tmp/ora19_fstat_stub.c
```

Noi dung file:

```c
#include <sys/syscall.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

int fstat(int fd, struct stat *buf) __attribute__((weak));
int fstat(int fd, struct stat *buf) {
    return syscall(SYS_newfstatat, fd, "", buf, AT_EMPTY_PATH);
}
```

Compile va add vao system archive:

```bash
gcc -c /tmp/ora19_fstat_stub.c -o /tmp/ora19_fstat_stub.o
sudo cp -a /usr/lib64/libpthread_nonshared.a /usr/lib64/libpthread_nonshared.a.bak.step10-fstat
sudo ar qf /usr/lib64/libpthread_nonshared.a /tmp/ora19_fstat_stub.o
nm /usr/lib64/libpthread_nonshared.a | grep ' fstat\| W fstat'
```

Expected:

```text
W fstat
```

Relink lai DB home tren `rac1`, user `oracle`:

```bash
cd /u01/app/oracle/product/19.0.0/dbhome_1
make -f rdbms/lib/ins_rdbms.mk irman ioracle idrdactl idrdalsnr idrdaproc ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
```

Ket qua thuc te 2026-05-27:

```text
Sau khi add fstat stub, make da qua duoc loi libjavavm19.a(eobtl.o) undefined reference to `fstat`.
Output da toi doan:
  - Linking RMAN
  - Linking Oracle
Day la doan relink binary oracle chinh, chay lau la binh thuong. Khong Ctrl-C khi dang link.
```

Khi make tra prompt, verify tren `rac1`, user `oracle`:

```bash
echo $?
ls -lh /u01/app/oracle/product/19.0.0/dbhome_1/rdbms/lib/oracle
ls -lh /u01/app/oracle/product/19.0.0/dbhome_1/bin/rman
```

Expected:

```text
echo $? = 0
rdbms/lib/oracle ton tai, size lon
bin/rman ton tai
```

Neu make OK, chay lai installer tren `rac1`, user `oracle`:

```bash
cd /u01/app/oracle/product/19.0.0/dbhome_1
CV_ASSUME_DISTID=OEL8 ./runInstaller -silent -ignorePrereqFailure -responseFile /home/oracle/db_install.rsp
```

Ket qua thuc te 2026-05-27 sau khi fix `fstat`:

```text
Launching Oracle Database Setup Wizard...

[WARNING] [INS-13013] Target environment does not meet some mandatory requirements.
...
As a root user, execute the following script(s):
    1. /u01/app/oracle/product/19.0.0/dbhome_1/root.sh

Execute /u01/app/oracle/product/19.0.0/dbhome_1/root.sh on the following nodes:
[rac1, rac2]

Successfully Setup Software with warning(s).
```

Y nghia:

```text
DB software da cai thanh cong tren RAC nodes, chi con root.sh tren rac1 va rac2.
Warning INS-13013 chap nhan trong lab nay vi OL9 + Oracle 19.3 base co prereq fail/warning da ignore.
```

Nen lam tuong tu tren `rac2`, user `tandat8896`, de sau nay relink DB home tren rac2 khong gap lai loi fstat:

```bash
cd /tmp
vi /tmp/ora19_fstat_stub.c
gcc -c /tmp/ora19_fstat_stub.c -o /tmp/ora19_fstat_stub.o
sudo cp -a /usr/lib64/libpthread_nonshared.a /usr/lib64/libpthread_nonshared.a.bak.step10-fstat
sudo ar qf /usr/lib64/libpthread_nonshared.a /tmp/ora19_fstat_stub.o
nm /usr/lib64/libpthread_nonshared.a | grep ' fstat\| W fstat'
```

## 5. Chay root scripts

Sau khi installer bao "Execute as root", chay tren ca hai node.

Tren rac1, user tandat8896:

```bash
sudo /u01/app/oracle/product/19.0.0/dbhome_1/root.sh
```

Ket qua thuc te 2026-05-27:

```text
Check /u01/app/oracle/product/19.0.0/dbhome_1/install/root_rac1_2026-05-27_14-13-58-290116789.log for the output of root script
```

Tren rac2, user tandat8896:

```bash
sudo /u01/app/oracle/product/19.0.0/dbhome_1/root.sh
```

Ket qua thuc te 2026-05-27:

```text
Check /u01/app/oracle/product/19.0.0/dbhome_1/install/root_rac2_2026-05-27_14-16-47-078634713.log for the output of root script
```

## 6. Verify DB home

```bash
# Kiem tra inventory:
cat /u01/app/oraInventory/ContentsXML/inventory.xml | grep -i home

# Kiem tra binary:
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/bin/oracle
/u01/app/oracle/product/19.0.0/dbhome_1/bin/sqlplus -version
```

Expected:
```text
inventory.xml: co ca OraGI19Home1 va OraDB19Home1
oracle binary: ~400MB, setuid
sqlplus: Release 19.0.0.0.0
```

Ket qua thuc te 2026-05-27 tren rac1, user oracle:

```text
SQL*Plus: Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

<HOME NAME="OraDB19Home1" LOC="/u01/app/oracle/product/19.0.0/dbhome_1" TYPE="O" IDX="2"/>
```

Ket qua thuc te 2026-05-27 tren rac2, user oracle:

```text
SQL*Plus: Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

<HOME NAME="OraDB19Home1" LOC="/u01/app/oracle/product/19.0.0/dbhome_1" TYPE="O" IDX="2"/>
```

## 7. Update shell profile cho oracle

Tren ca hai node, user oracle:

```bash
cat >> ~/.bash_profile << 'EOF'

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH
EOF
source ~/.bash_profile
which sqlplus
```

## 8. Done criteria

```text
runInstaller completed successfully
root.sh chay xong tren ca hai node
inventory.xml co OraDB19Home1
sqlplus -version tra ve 19.0.0.0.0
oracle binary ton tai va executable
Chua tao database trong Step nay
```
