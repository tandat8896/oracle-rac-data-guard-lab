# Step 09 - Install Oracle Grid Infrastructure and ASM

Muc tieu: cai Oracle Grid Infrastructure 19c de tao RAC cluster va ASM OCR/VOTE disk group.

Chay Step nay sau khi Step 08 xong:

```text
/u01/app/19.0.0/grid/gridSetup.sh ton tai tren rac1 va rac2
Grid home owner la grid:oinstall
/dev/asm-ocrvote /dev/asm-data /dev/asm-fra ton tai tren ca hai node
grid passwordless SSH hai chieu OK
```

Step nay chu yeu chay tu `rac1` bang user `grid`.

## 0. Stop condition

Dung lai neu chua dat du cac dieu kien:

```text
Step 08 chua copy Grid home vao /u01/app/19.0.0/grid
udev /dev/asm-* mat sau reboot
grid SSH rac1/rac2 hoi password
rac1/rac2 private ping fail
```

Khong chay `gridSetup.sh` neu precheck con loi ro rang.

## 1. Precheck tren rac1

Dang nhap `rac1` bang `tandat8896`:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.205
```

Verify OS/network/disk:

```bash
hostname
getent ahostsv4 rac1 rac2 rac1-priv rac2-priv rac1-vip rac2-vip rac-scan
ping -c 3 rac2
ping -c 3 rac2-priv
ls -l /dev/asm-*
ls -l /u01/app/19.0.0/grid/gridSetup.sh
```

Ket qua hien tai tren `rac1`:

```text
hostname = rac1
getent ahostsv4 resolve dung:
  rac1      -> 192.168.122.205
  rac2      -> 192.168.122.46
  rac1-priv -> 10.10.10.11
  rac2-priv -> 10.10.10.12
  rac1-vip  -> 192.168.122.211
  rac2-vip  -> 192.168.122.212
  rac-scan  -> 192.168.122.213
ping rac2      -> 3/3 received, 0% packet loss
ping rac2-priv -> 3/3 received, 0% packet loss
/dev/asm-data    -> vdc
/dev/asm-fra     -> vdd
/dev/asm-ocrvote -> vdb
/u01/app/19.0.0/grid/gridSetup.sh ton tai va executable, owner grid:oinstall
```

Verify grid SSH:

```bash
sudo su - grid
ssh -p 2222 grid@rac1 hostname
ssh -p 2222 grid@rac2 hostname
ssh rac1 hostname
ssh rac2 hostname
exit
```

Luu y:

```text
ssh -p 2222 ... chi chung minh manual SSH OK.
runcluvfy/Grid can `ssh rac1` va `ssh rac2` cung OK.
Neu `ssh rac2` bi port 22 refused, tao ~/.ssh/config cho grid tren ca hai node.
```

Chup hinh:

```text
oracle_rac/screenshots/11a-grid-install-precheck-rac1.png
```

## 2. Run Cluster Verification Utility precheck

### 2a. Cach doc trace log CVU (QUAN TRONG - doc truoc)

Khi CVU bao loi, KHONG chi doc output terminal.
Terminal chi hien tong hop, khong co chi tiet.

Trace log co toan bo chi tiet:

```bash
# Xem file trace moi nhat:
ls -lt /home/grid/cvutrace/

# Doc 60 dong cuoi trace moi nhat:
tail -n 60 /home/grid/cvutrace/cvutrace.log.0.X

# Tim loi cu the:
grep -n 'Exception\|ERROR\|FAILED\|Host key\|No such\|denied\|PRVF\|PRVG\|PRVE' /home/grid/cvutrace/cvutrace.log.0.X | tail -50
```

Nguyen tac doc trace:

```text
1. Tim dong co "Exception" hoac "NullPointer" -> bug CVU/OS
2. Tim dong co "Host key verification failed" -> SSH/known_hosts
3. Tim dong co "No ED25519 host key is known for" -> thieu known_hosts entry
4. Tim dong co "StrictHostKeyChecking=yes" va fail -> CVU dung strict check
5. Tim dong "CV_VAL" chua output lenh -> xem lenh thuc te CVU dang chay
6. Tim "PRVF-xxxx" de biet ma loi cu the
```

Quan trong:

```text
CVU chay: /usr/bin/ssh -o StrictHostKeyChecking=yes -o PasswordAuthentication=no
CVU KHONG doc ~/.ssh/config cho option StrictHostKeyChecking.
Nhung CVU co doc ~/.ssh/config cho Port va HostName.
Nen known_hosts PHAI co entry tuong ung voi port thuc te.
```

### 2b. Fix SSH equivalence truoc khi chay CVU

Cac van de SSH da gap va da fix:

**Van de 1: Port 22 bi chặn (sshd chi nghe port 2222)**

CVU mong doi port 22 mac dinh. Fix: them port 22 vao sshd.

Tren ca `rac1` va `rac2`:

```bash
sudo sed -i '/^Port 2222/a Port 22' /etc/ssh/sshd_config.d/99-hardening.conf
sudo systemctl restart sshd
ss -tlnp | grep sshd
```

Expected: sshd nghe ca port 22 va 2222.

**Van de 2: UserKnownHostsFile /dev/null trong grid SSH config**

Khi dung `UserKnownHostsFile /dev/null`, ssh khong luu host key.
CVU dung `StrictHostKeyChecking=yes` nen can known_hosts thuc su.

Fix: xoa dong `UserKnownHostsFile` khoi grid SSH config:

```bash
# Tren ca rac1 va rac2 user grid:
sed -i '/UserKnownHostsFile/d' /home/grid/.ssh/config
```

**Van de 3: known_hosts thieu entry cho port 2222**

CVU doc `~/.ssh/config`, thay `Port 2222` cho rac1/rac2, nen SSH toi `[192.168.122.205]:2222`.
Nhung known_hosts chi co port 22 entries.

Fix: tao lai known_hosts KHONG dung `-H` (QUAN TRONG):

```bash
# Tren ca rac1 va rac2 user grid:
rm -f /home/grid/.ssh/known_hosts
ssh-keyscan -p 22   rac1 rac2 192.168.122.205 192.168.122.46 2>/dev/null >> /home/grid/.ssh/known_hosts
ssh-keyscan -p 2222 rac1 rac2 192.168.122.205 192.168.122.46 2>/dev/null >> /home/grid/.ssh/known_hosts
chmod 600 /home/grid/.ssh/known_hosts
wc -l /home/grid/.ssh/known_hosts
```

Tai sao KHONG dung `-H`:

```text
ssh-keyscan -H tao hashed known_hosts: |1|xxx|yyy= ssh-rsa ...
JSch (Java SSH library cua Oracle installer) KHONG doc duoc hashed entries.
JSch chi doc plain text: rac2 ssh-rsa ...
Neu dung -H, JSch bao "invalid privatekey" hoac SSH check fail im lang.
```

Test SSH khong co config:

```bash
# Kiem tra CVU-style SSH (khong dung config, strict check):
ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes grid@rac2 hostname
ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes grid@rac1 hostname
```

Expected: tra ve `rac2` va `rac1` khong hoi password.

### 2c. Chay CVU

Tren `rac1`, vao user `grid`:

```bash
sudo su - grid
cd /u01/app/19.0.0/grid
```

Lenh chay CVU chinh xac (phai co `CV_ASSUME_DISTID=OEL8`):

```bash
CV_ASSUME_DISTID=OEL8 CV_DESTLOC=/home/grid/cvuwork CV_TRACELOC=/home/grid/cvutrace ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
```

Tai sao can `CV_ASSUME_DISTID=OEL8`:

```text
Oracle Grid 19.3 base duoc viet cho OL7/OL8, khong biet OL9.
XmlTaskFactory.getTasks() tra ve null voi OL9 -> NullPointerException -> CVU crash.
CV_ASSUME_DISTID=OEL8 ep CVU dung task definitions cua OL8 thay vi OL9.
```

Ghi lai ket qua CVU.

Chup hinh:

```text
oracle_rac/screenshots/11b-cluvfy-pre-crsinst.png
```

### 2d. Fix truoc khi chay CVU

**Fix 1: NOZEROCONF**

```bash
# Tren ca rac1 va rac2:
sudo bash -c 'echo NOZEROCONF=yes >> /etc/sysconfig/network'
```

**Fix 2: Swap them 1GB**

```bash
# Tren ca rac1 va rac2:
sudo bash -c '
  dd if=/dev/zero of=/swapfile2 bs=1M count=1024
  chmod 600 /swapfile2
  mkswap /swapfile2
  swapon /swapfile2
  echo /swapfile2 none swap sw 0 0 >> /etc/fstab
'
free -h | grep Swap
```

Expected: Swap tang len ~6GB.

**Fix 3: Tang RAM VM len 8GB (tren host NixOS)**

Shutdown VM truoc:

```bash
virsh --connect qemu:///system shutdown rac1
virsh --connect qemu:///system shutdown rac2
```

Tang RAM va start lai:

```bash
virsh --connect qemu:///system setmaxmem rac1 8388608 --config
virsh --connect qemu:///system setmem rac1 8388608 --config
virsh --connect qemu:///system setmaxmem rac2 8388608 --config
virsh --connect qemu:///system setmem rac2 8388608 --config
virsh --connect qemu:///system start rac1
virsh --connect qemu:///system start rac2
```

Verify:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.205 'free -h'
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.46 'free -h'
```

Ket qua da thuc hien:

```text
Swap: them /swapfile2 1GB -> tong swap 6GB (tren ca rac1 va rac2)
RAM:  tang len 8GB (tren ca rac1 va rac2)
```

**Fix 4: SCP wrapper - OpenSSH 9.x + Oracle literal single quotes**

Loi 1: `protocol error: filename does not match request`
Nguyen nhan: OpenSSH 9.x dung SFTP-based SCP mac dinh, CVU can old SCP protocol.

Loi 2: Oracle Grid installer Java code goi SCP bang `Runtime.exec(String[])` nen truyen
literal single quotes vao path: `rac2:'/path/to/file'`. Khi dung SCP `-O` (old protocol),
client tinh basename la `file'` (co trailing quote), server tra ve `file` (khong quote)
-> mismatch -> `protocol error: filename does not match request`.

Fix: wrapper `/usr/bin/scp` vua ep `-O` vua strip single quotes.

Buoc 1 - backup original (chi can lam 1 lan):

```bash
# Tren ca rac1 va rac2 (neu chua co):
sudo cp -a /usr/bin/scp /usr/bin/scp.openssh-original
```

Buoc 2 - tao wrapper moi (dung Python vi bash heredoc kho escape single quote):

```bash
# Tren ca rac1 va rac2:
sudo python3 - << PYEOF
q = chr(39)
d = chr(36)
content = (
    "#!/bin/bash\n"
    "q=" + d + chr(39) + chr(92) + chr(39) + chr(39) + "\n"
    "args=()\n"
    "for arg; do\n"
    "    args+=(\"" + d + "{arg//" + d + "q/}\")\n"
    "done\n"
    "exec /usr/bin/scp.openssh-original -O \"" + d + "{args[@]}\"\n"
)
with open("/usr/bin/scp", "w") as f:
    f.write(content)
import os; os.chmod("/usr/bin/scp", 0o755)
print("OK")
PYEOF
```

Kiem tra wrapper:

```bash
head -6 /usr/bin/scp
bash -n /usr/bin/scp && echo SYNTAX_OK
```

Expected content:

```text
#!/bin/bash
q=$'\''
args=()
for arg; do
    args+=("${arg//$q/}")
done
exec /usr/bin/scp.openssh-original -O "${args[@]}"
```

Test sau khi fix (tu grid@rac1):

```bash
# Test clean path:
sudo -u grid /usr/bin/scp -p rac2:/etc/hostname /tmp/scp_clean_test.txt 2>&1; echo "EXIT:$?"
# Test Oracle-style literal single quotes (dung Python de truyen dung):
sudo python3 -c "
import subprocess
arg = 'rac2:' + chr(39) + '/etc/hostname' + chr(39)
r = subprocess.run(['sudo','-u','grid','/usr/bin/scp','-p',arg,'/tmp/scp_quote_test.txt'], capture_output=True, text=True)
print('stderr:', r.stderr); print('exit:', r.returncode)
"
```

Expected: ca hai test exit 0.

**Fix 5: Thieu make va gcc**

Loi: `[FATAL] Unable to find make utility in location: /usr/bin/make`
Nguyen nhan: Oracle 19.3 link libraries bang make/gcc, nhung OL9 minimal install khong co.

Tren ca rac1 va rac2:

```bash
sudo dnf install -y make gcc
which make gcc
```

Expected: `/usr/bin/make`, `/usr/bin/gcc`.

**Fix 6: libpthread_nonshared.a missing tren OL9**



Loi:

```text
/usr/bin/ld: cannot find /usr/lib64/libpthread_nonshared.a
genclntsh: Failed to link libclntshcore.so.19.1
make: *** [ins_rdbms.mk:56: client_sharedlib] Error 1
[FATAL] Error in invoking target 'libasmclntsh19.ohso libasmperl19.ohso client_sharedlib'
        of makefile '/u01/app/19.0.0/grid/rdbms/lib/ins_rdbms.mk'
```

Nguyen nhan: OL9 dung glibc 2.34+ da merge libpthread vao libc.
`libpthread_nonshared.a` khong con ton tai nhu file rieng.
Oracle 19.3 `genclntsh` van link static vao file nay.

Fix: tao stub archive rong de linker thoa man:

```bash
# Tren ca rac1 va rac2:
sudo ar cr /usr/lib64/libpthread_nonshared.a
ls -la /usr/lib64/libpthread_nonshared.a
```

Expected: file 8 bytes ton tai.

Ghi chu:

```text
Stub rong la du vi pthread code da nam trong libc roi.
Linker chi can file ton tai de resolve -lpthread_nonshared reference.
Khong can content gi ben trong.
```

**Fix 7: glibc-static missing - "undefined reference to `stat'"**

Loi:

```text
/usr/bin/ld: libnnzst19.a(ccme_ck_rand_load_fileS1.o): undefined reference to `stat'
make: *** [ins_rdbms.mk:912: orion] Error 1
[FATAL] Error in invoking target 'all_no_orcl' of makefile '.../ins_rdbms.mk'
```

Nguyen nhan: OL9 glibc 2.34+ move `stat` vao static archive `libc.a`.
Oracle `libnnzst19.a` link static vao `stat`, can `libc.a` de resolve.
Neu `glibc-static` chua cai, linker khong tim duoc `stat` trong static context.

Fix tren ca rac1 va rac2:

```bash
sudo dnf install -y glibc-static
```

Verify:

```bash
rpm -q glibc-static
ls /usr/lib64/libc.a
```

**Fix 8: "undefined reference to `stat'" - glibc 2.34 khong co stat trong libc.a**

Loi:

```text
/usr/bin/ld: libnnzst19.a(...): undefined reference to `stat'
make: *** [ins_rdbms.mk:912: orion] Error 1
[FATAL] Error in invoking target 'all_no_orcl'
```

Nguyen nhan: glibc 2.34+ tren x86-64 khong export `stat` nhu standalone symbol trong `libc.a`.
Oracle `libnnzst19.a` (static) reference `stat` truc tiep. `glibc-static` van khong du.

Fix 2 buoc:

Buoc 1 - Tao stat stub (them vao libpthread_nonshared.a):

```bash
cat > /tmp/stat_stub.c << "EOF"
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
int stat(const char *path, struct stat *buf) __attribute__((weak));
int stat(const char *path, struct stat *buf) { return lstat(path, buf); }
EOF
gcc -c /tmp/stat_stub.c -o /tmp/stat_stub.o
sudo ar qf /usr/lib64/libpthread_nonshared.a /tmp/stat_stub.o
nm /usr/lib64/libpthread_nonshared.a | grep stat
```

Expected: `W stat` trong output.

Buoc 2 - Remove `iorion` khoi INSTALL_TARGS (`orion` la benchmark tool, khong can cho Grid/RAC):

```bash
sudo cp /u01/app/19.0.0/grid/rdbms/lib/env_rdbms.mk \
        /u01/app/19.0.0/grid/rdbms/lib/env_rdbms.mk.bak
sudo sed -i "s/ iorion//" /u01/app/19.0.0/grid/rdbms/lib/env_rdbms.mk
sudo grep "INSTALL_TARGS" /u01/app/19.0.0/grid/rdbms/lib/env_rdbms.mk | grep -v "^#" | head -3
```

Expected: dong `INSTALL_TARGS` khong con `iorion`.

**Fix 9: Cai tat ca packages can thiet 1 lan (chay tren ca rac1 va rac2)**

```bash
sudo dnf install -y \
  bc binutils \
  elfutils-libelf elfutils-libelf-devel fontconfig-devel \
  glibc glibc-devel glibc-static \
  gcc gcc-c++ ksh \
  libaio libaio-devel libgcc libnsl libnsl2 \
  libstdc++ libstdc++-devel \
  libX11 libXau libXi libXtst libXrender libXrender-devel \
  make net-tools nfs-utils smartmontools sysstat unixODBC pam psmisc
```

**Fix 10: stat_stub goi lstat cung undefined - rebuild dung syscall**

Loi:

```text
/usr/bin/ld: /usr/lib64/libpthread_nonshared.a(stat_stub.o): in function `stat':
stat_stub.c:(.text+0x1f): undefined reference to `lstat'
make: *** [/u01/app/19.0.0/grid/rdbms/lib/ins_rdbms.mk:840: /u01/app/19.0.0/grid/rdbms/lib/oracle] Error 1
[FATAL] Error in invoking target 'irman ioracle' of makefile '.../ins_rdbms.mk'
```

Nguyen nhan: stat_stub truoc dung `return lstat(path, buf)` nhung `lstat` cung khong ton tai
nhu standalone symbol trong `libc.a` tren glibc 2.34+ (OL9). Ca `stat` va `lstat` deu phai
dung syscall truc tiep.

Fix tren ca rac1 va rac2:

```bash
cat > /tmp/stat_stub2.c << 'EOF'
#include <sys/syscall.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

int stat(const char *path, struct stat *buf) __attribute__((weak));
int stat(const char *path, struct stat *buf) {
    return syscall(SYS_newfstatat, AT_FDCWD, path, buf, 0);
}

int lstat(const char *path, struct stat *buf) __attribute__((weak));
int lstat(const char *path, struct stat *buf) {
    return syscall(SYS_newfstatat, AT_FDCWD, path, buf, 0x100);
}
EOF
gcc -c /tmp/stat_stub2.c -o /tmp/stat_stub2.o
sudo ar d /usr/lib64/libpthread_nonshared.a stat_stub.o 2>/dev/null || true
sudo ar qf /usr/lib64/libpthread_nonshared.a /tmp/stat_stub2.o
nm /usr/lib64/libpthread_nonshared.a | grep -E " T | W " | grep -E "stat|lstat"
```

Expected: `W lstat` va `W stat` trong output.

Verify make OK (tu user tandat8896 tren rac1):

```bash
sudo -u grid make -f /u01/app/19.0.0/grid/rdbms/lib/ins_rdbms.mk irman ioracle ORACLE_HOME=/u01/app/19.0.0/grid 2>&1 | tail -5
ls -lh /u01/app/19.0.0/grid/bin/oracle
```

Expected: oracle binary ~400MB, setuid `rws`.

Note: dong cuoi `make: stat: ioracle: Permission denied` la make check file target, KHONG phai loi build.

### 2e. Ket qua CVU sau khi fix het

```text
Verifying Physical Memory     -> passed (8GB)
Verifying Swap Size           -> passed (6GB)
Verifying resolv.conf         -> failed (PRVG-2002, SCP copy van loi nhung khong block Grid install)
Verifying DNS/NIS             -> failed (PRVG-2002, ignore cho lab)
Verifying zeroconf            -> passed (sau fix NOZEROCONF)
Verifying User Equivalence    -> PASSED
Verifying Node Connectivity   -> PASSED
Verifying Multicast           -> PASSED
Verifying Package cvuqdisk    -> PASSED
```

Cac loi con lai (resolv.conf, DNS/NIS) la ignore duoc cho lab vi:

```text
- Khong lien quan Grid cluster formation
- Khong block root.sh / gridSetup.sh
- Chi la CVU copy file de kiem tra noi dung, khong phai copy de install
```

Chup hinh:

```text
oracle_rac/screenshots/11b-cluvfy-pre-crsinst.png
```

Ket qua/fix hien tai:

```text
runcluvfy gap loi:
  PRVG-10467 : The default Oracle Inventory group could not be determined.

Nguyen nhan:
  /etc/oraInst.loc chua ton tai.

Fix tren ca rac1 va rac2:
  Tao /etc/oraInst.loc voi:
    inventory_loc=/u01/app/oraInventory
    inst_group=oinstall
  Set owner/mode:
    root:oinstall
    664

rac1 verify:
  -rw-rw-r--. 1 root oinstall ... /etc/oraInst.loc
```

Ket qua tiep theo:

```text
runcluvfy gap loi:
  Verifying '/tmp/' ...FAILED (PRVF-9012)

Oracle message trong Grid home:
  PRVF-9012 = Path "{0}" is not a writeable directory on nodes:

Check thuc te:
  rac1 /tmp: 17G free, drwxrwxrwt
  rac2 /tmp: 17G free, drwxrwxrwt
  grid touch/rm trong /tmp tren rac2 OK
  grid scp tu rac1 sang rac2:/tmp OK

Ket luan tam thoi:
  /tmp khong hong theo OS permission/dung luong.
  Dung CV_DESTLOC rieng de ep CVU khong dung /tmp.
```

Test scp da chay tren `grid@rac1`:

```bash
ssh rac2 'which ssh scp'
echo CVU_COPY_TEST > /tmp/cvu_copy_test_rac1.txt
scp /tmp/cvu_copy_test_rac1.txt rac2:/tmp/cvu_copy_test_from_rac1.txt
ssh rac2 'ls -l /tmp/cvu_copy_test_from_rac1.txt; cat /tmp/cvu_copy_test_from_rac1.txt; rm -f /tmp/cvu_copy_test_from_rac1.txt'
rm -f /tmp/cvu_copy_test_rac1.txt
```

Output quan trong:

```text
/usr/bin/ssh
/usr/bin/scp
cvu_copy_test_rac1.txt 100%
-rw-r--r--. 1 grid oinstall ... /tmp/cvu_copy_test_from_rac1.txt
CVU_COPY_TEST
```

Tao CVU workdir rieng tren `rac1`, user `tandat8896`:

```bash
sudo mkdir -p /u01/cvuwork
sudo chown grid:oinstall /u01/cvuwork
sudo chmod 775 /u01/cvuwork
ls -ld /u01/cvuwork
```

Output hien tai tren `rac1`:

```text
drwxrwxr-x. 2 grid oinstall 6 May 27 08:53 /u01/cvuwork
```

Can lam tiep tren `rac2`, user `tandat8896`:

```bash
sudo mkdir -p /u01/cvuwork
sudo chown grid:oinstall /u01/cvuwork
sudo chmod 775 /u01/cvuwork
ls -ld /u01/cvuwork
```

Sau khi ca hai node co `/u01/cvuwork`, chay lai tren `grid@rac1`:

```bash
cd /u01/app/19.0.0/grid
CV_DESTLOC=/u01/cvuwork ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
```

Ket qua sau khi tao `/u01/cvuwork` tren ca hai node:

```text
rac1:
  /etc/oraInst.loc dung
  /u01/app/oraInventory owner grid:oinstall
  /u01/cvuwork owner grid:oinstall

rac2:
  /etc/oraInst.loc dung
  /u01/app/oraInventory owner grid:oinstall
  /u01/cvuwork owner grid:oinstall

Write test qua SSH tu grid@rac1:
  RAC1_CVUWORK_WRITE_OK
  RAC2_CVUWORK_WRITE_OK

Chay:
  ORACLE_HOME=/u01/app/19.0.0/grid ORACLE_BASE=/u01/app/grid CV_DESTLOC=/u01/cvuwork ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose

Van fail:
  Verifying '/u01/cvuwork/' ...FAILED (PRVF-9012)
```

Trang thai dieu tra:

```text
OS permission/write/scp deu OK.
Khong tiep tuc sua mo.
Buoc tiep theo la lay CVU trace/log de xem framework check fail tai command nao.
```

Trace da bat bang:

```bash
mkdir -p /u01/cvuwork/trace
rm -f /u01/cvuwork/trace/*
SRVM_TRACE=true SRVM_TRACE_LEVEL=2 CV_TRACELOC=/u01/cvuwork/trace CV_DESTLOC=/u01/cvuwork ORACLE_SRVM_REMOTESHELL=/usr/bin/ssh ORACLE_SRVM_REMOTECOPY=/usr/bin/scp ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
grep -nE 'PRVF-9012|UTIL_DEST|WORKDIR|not a writeable|cannot be used|Exception|ERROR|SEVERE|rac2|scp|ssh|Permission|denied|No such file' /u01/cvuwork/trace/cvutrace.log.0 | tail -120
```

Trace quan trong:

```text
1854: ERRORMSG(GLOBAL): PRVF-9012 : Path "/u01" is not a writeable directory on nodes:rac2
1855: Access denied for subdirectory "/u01"
1857: failed to upload file /u01/cvuwork/CVU_19.0.0.0.0_grid/cvuhelper to '/u01/cvuwork/CVU_19.0.0.0.0_grid//cvuhelper'
```

Ket luan:

```text
CV_DESTLOC la /u01/cvuwork, nhung CVU van kiem tra parent path /u01 tren rac2.
Trace bao ro /u01 khong writable voi grid tren rac2.
Do do upload framework file cvuhelper bi fail.
Trong lab, fix bang cach cho group oinstall ghi vao /u01 tren ca hai node.
```

Fix de thu tiep tren ca `rac1` va `rac2`, user `tandat8896`:

```bash
sudo chown root:oinstall /u01
sudo chmod 775 /u01
ls -ld /u01 /u01/cvuwork
```

Lan trace sau khi doi `CV_DESTLOC=/home/grid/cvuwork`:

Lenh chay trace tren `grid@rac1`:

```bash
mkdir -p /home/grid/cvuwork /home/grid/cvutrace
ssh rac2 'mkdir -p /home/grid/cvuwork /home/grid/cvutrace; chmod 775 /home/grid/cvuwork /home/grid/cvutrace'
cd /u01/app/19.0.0/grid
ORACLE_BASE=/u01/app/grid ORACLE_HOME=/u01/app/19.0.0/grid CV_DESTLOC=/home/grid/cvuwork CV_TRACELOC=/home/grid/cvutrace ./runcluvfy.sh stage -pre crsinst -n rac1,rac2 -verbose
grep -nE 'PRVF-9012|not a writeable|Access denied|failed to upload|dest open|No such file|scp|sftp|rac2|Exception|ksh' /home/grid/cvutrace/cvutrace.log.0 | tail -80
```

Output trace quan trong:

```text
9517: Exception occured:
9518: oracle.ops.mgmt.cluster.ClusterException: bash: line 1: /bin/ksh: No such file or directory
9536: PRVF-9012 : Path "/home" is not a writeable directory on nodes:rac2
9537: Access denied for subdirectory "/home"
9538: failed to upload file /home/grid/cvuwork/CVU_19.0.0.0.0_grid/cvuhelper ...
```

Ket luan cap nhat:

```text
Co dau hieu node remote thieu /bin/ksh, lam CVU framework check fail va bao lech thanh PRVF-9012.
Can verify ksh tren ca rac1/rac2 truoc khi tiep tuc sua permission.
```

Lenh verify:

```bash
ssh rac1 'hostname; ls -l /bin/ksh /usr/bin/ksh 2>&1; rpm -q ksh'
ssh rac2 'hostname; ls -l /bin/ksh /usr/bin/ksh 2>&1; rpm -q ksh'
```

Neu node nao thieu `ksh`, cai bang user `tandat8896` tren node do:

```bash
sudo dnf install -y ksh
ls -l /bin/ksh /usr/bin/ksh
```

Thu tao wrapper `/home/grid/bin/scp-legacy` de ep `scp -O`:

```text
#!/bin/sh
exec /usr/bin/scp -O "$@"
```

Manual test wrapper copy sang rac2 OK:

```text
LEGACY_SCP_TEST
```

Nhung CVU tu choi wrapper nam ngoai duong dan secure:

```text
The Remote Copy command /home/grid/bin/scp-legacy requested by client is not secure and therefore is no longer supported.
```

Ket luan cap nhat:

```text
Huong wrapper user-level khong dung duoc voi CVU.
Neu can ep legacy scp cho Oracle 19c tren OL9/OpenSSH moi, phai lam wrapper tai chinh /usr/bin/scp tren node invoke CVU, co backup/rollback ro rang.
```

### 2f. Cach doc log khi gridSetup.sh bao FATAL (QUAN TRONG)

Khi `gridSetup.sh` bao `[FATAL]`, KHONG chi doc output terminal.
Terminal chi hien ma loi va ten file log. Chi tiet thuc su nam trong cac file sau.

**Log file chinh:**

```bash
# Tim log moi nhat:
LOGDIR=$(ls -td /u01/app/oraInventory/logs/GridSetupActions* | head -1)
echo $LOGDIR

# Xem tong quan loi:
grep -E "FATAL|SEVERE|WARNING|Error|Failed" $LOGDIR/gridSetupActions*.log | tail -30

# Xem chi tiet NxN SSH check (loi INS-44000/INS-44002):
grep -E "NxN|passwordless|rac2|SSH|scp|upload|PRVF-5311|protocol error" $LOGDIR/gridSetupActions*.out | tail -40
```

**Make/linker log (loi INS-20009 / make error):**

```bash
# Day la noi ghi loi khi link shared libraries:
tail -60 /u01/app/19.0.0/grid/install/make.log

# Tim dong loi linker:
grep -E "Error|error:|cannot find|ld:|undefined|FAILED|make\[" /u01/app/19.0.0/grid/install/make.log | tail -20
```

**Map ma loi -> file can doc:**

```text
INS-44000 / INS-44002  SSH check fail
  -> $LOGDIR/gridSetupActions*.log  (xem dong "SSH", "NxN", "passwordless")
  -> $LOGDIR/gridSetupActions*.out  (xem dong "PRVF-5311", "protocol error", "scp")

INS-20009  make/link error
  -> /u01/app/19.0.0/grid/install/make.log
     Tim dong: "cannot find", "ld:", "Error 1"

INS-40109  Oracle Base not empty
  -> Warning, ignore duoc

INS-13013  Mandatory prereqs not met
  -> Warning voi -ignorePrereq, ignore duoc
```

**Ket qua loi gap va fix:**

```text
INS-44000 "invalid privatekey"
  -> id_rsa khong phai RSA PEM format
  -> Fix: ssh-keygen -p -m PEM -f /home/grid/.ssh/id_rsa -N "" -P ""

INS-44000 sau khi fix PEM
  -> known_hosts dung -H (hashed), JSch khong doc duoc
  -> Fix: tao lai known_hosts khong co -H (xem Fix 4 section 2b)

INS-44000 "NxN check fail" sau khi fix known_hosts
  -> Oracle Java truyen literal single quotes vao SCP path
     => "protocol error: filename does not match request"
  -> Fix: cap nhat SCP wrapper (xem Fix 4 section 2d)

INS-44002 "Oracle home contains files on remote nodes"
  -> Grid home tren rac2 khong rong (da stage tu truoc)
  -> Fix: xoa Grid home tren rac2 de Oracle tu copy sang
     sudo find /u01/app/19.0.0/grid -mindepth 1 -delete

make FATAL "Unable to find make utility"
  -> Fix 5: sudo dnf install -y make gcc

make FATAL "cannot find /usr/lib64/libpthread_nonshared.a"
  -> Fix 6: sudo ar cr /usr/lib64/libpthread_nonshared.a

make FATAL "irman ioracle" - "undefined reference to `lstat'"
  -> stat_stub cu goi lstat nhung lstat cung undefined tren glibc 2.34+
  -> Fix 10: rebuild stat_stub dung syscall(SYS_newfstatat) truc tiep (xem Fix 10 section 2d)
```

## 3. Tao Grid response file

Tren `rac1`, dang la user `grid`.

Tao file:

```text
/home/grid/gridsetup-rac.rsp
```

Mo file:

```bash
vi /home/grid/gridsetup-rac.rsp
```

Dan noi dung mau nay.

Can thay password placeholder truoc khi chay:

```text
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v19.0.0
INVENTORY_LOCATION=/u01/app/oraInventory
oracle.install.option=CRS_CONFIG
ORACLE_BASE=/u01/app/grid
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.install.crs.config.scanType=LOCAL_SCAN
oracle.install.crs.config.gpnp.scanName=rac-scan
oracle.install.crs.config.gpnp.scanPort=1521
oracle.install.crs.config.ClusterConfiguration=STANDALONE
oracle.install.crs.config.configureAsExtendedCluster=false
oracle.install.crs.config.clusterName=rac-cluster
oracle.install.crs.config.clusterNodes=rac1:rac1-vip,rac2:rac2-vip
oracle.install.crs.config.networkInterfaceList=enp1s0:192.168.122.0:1,enp2s0:10.10.10.0:5
oracle.install.crs.configureGIMR=false
oracle.install.crs.config.storageOption=FLEX_ASM_STORAGE
oracle.install.crs.config.useIPMI=false
oracle.install.asm.SYSASMPassword=CHANGE_ME_SYSASM_PASSWORD
oracle.install.asm.monitorPassword=CHANGE_ME_ASMSNMP_PASSWORD
oracle.install.asm.diskGroup.name=OCRVOTE
oracle.install.asm.diskGroup.redundancy=EXTERNAL
oracle.install.asm.diskGroup.AUSize=4
oracle.install.asm.diskGroup.disks=/dev/asm-ocrvote
oracle.install.asm.diskGroup.diskDiscoveryString=/dev/asm-*
oracle.install.asm.configureAFD=false
oracle.install.crs.rootconfig.executeRootScript=false
```

Set permission:

```bash
chmod 600 /home/grid/gridsetup-rac.rsp
```

Review:

```bash
grep -v Password /home/grid/gridsetup-rac.rsp
```

Chup hinh:

```text
oracle_rac/screenshots/11c-grid-response-file-created.png
```

## 4. Run Grid prerequisite check with response file

Tren `rac1`, user `grid`:

```bash
cd /u01/app/19.0.0/grid
./gridSetup.sh -silent -executePrereqs -responseFile /home/grid/gridsetup-rac.rsp
```

Neu co failed prereq:

```text
Dung lai.
Copy output loi vao lab log.
Khong chay install tiep.
```

Neu chi warning chap nhan duoc cho lab:

```text
Ghi lai warning.
Can nhac co dung -ignorePrereq khi install hay khong.
```

Chup hinh:

```text
oracle_rac/screenshots/11d-grid-execute-prereqs.png
```

## 5. Install Grid Infrastructure

Chi chay sau khi muc 4 da qua.

Tren `rac1`, user `grid`:

```bash
cd /u01/app/19.0.0/grid
./gridSetup.sh -silent -responseFile /home/grid/gridsetup-rac.rsp
```

Neu installer yeu cau root scripts, dung lai tai do.

Thuong can chay:

```text
/u01/app/oraInventory/orainstRoot.sh
/u01/app/19.0.0/grid/root.sh
```

Ket qua thuc te 2026-05-27:

```text
Lenh da chay:
  ./gridSetup.sh -ignorePrereq -responseFile /home/grid/gridsetup-rac.rsp

Output:
  [WARNING] [INS-40109] Oracle Base not empty       -> ignore OK
  [WARNING] [INS-13013] Mandatory prereqs not met   -> ignore OK
  [FATAL] Error in invoking target 'irman ioracle'  -> fix stat_stub (Fix 10)
  
Sau Fix 10 chay lai:
  Successfully Setup Software with warning(s).

  As a root user, execute the following script(s):
    1. /u01/app/19.0.0/grid/root.sh
  Execute on: [rac1, rac2] - rac1 truoc, rac2 sau.

  As install user, after root scripts:
    /u01/app/19.0.0/grid/gridSetup.sh -executeConfigTools -responseFile /home/grid/gridsetup-rac.rsp -silent

orainstRoot.sh KHONG duoc yeu cau lan nay (oraInventory da co tu truoc).
```

Chup hinh:

```text
oracle_rac/screenshots/11e-grid-install-before-root-scripts.png
```

## 6. Run root scripts

Chay bang user `root`/sudo.

Thu tu can than:

```text
1. rac1: /u01/app/oraInventory/orainstRoot.sh
2. rac2: /u01/app/oraInventory/orainstRoot.sh
3. rac1: /u01/app/19.0.0/grid/root.sh
4. rac2: /u01/app/19.0.0/grid/root.sh
```

Tren `rac1`, user `tandat8896`:

```bash
sudo /u01/app/oraInventory/orainstRoot.sh
sudo /u01/app/19.0.0/grid/root.sh
```

Tren `rac2`, user `tandat8896`:

```bash
sudo /u01/app/oraInventory/orainstRoot.sh
sudo /u01/app/19.0.0/grid/root.sh
```

Luu y:

```text
root.sh co the chay lau.
Khong Ctrl-C neu no dang configure CRS/ASM.
Neu fail, giu output va alert/log path.
```

Chup hinh:

```text
oracle_rac/screenshots/11f-grid-root-scripts.png
```

Ket qua thuc te 2026-05-27:

```text
rac1 root.sh:
  19/19 steps completed
  ASM created and started successfully
  Voting disk ONLINE: 5af5393ba43e4f1cbff0516f59d27159 (/dev/asm-ocrvote) [OCRVOTE]
  CLSRSC-343: Successfully started Oracle Clusterware stack
  CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded
  Thoi gian: ~6 phut (11:58 -> 12:04)

rac2 root.sh:
  19/19 steps completed
  CLSRSC-343: Successfully started Oracle Clusterware stack
  CLSRSC-325: Configure Oracle Grid Infrastructure for a Cluster ... succeeded
  Thoi gian: ~2 phut (12:50 -> 12:52)
```

## 7. executeConfigTools va fix ASM HAIP

### 7a. Chay executeConfigTools

Sau khi ca hai root.sh xong, chay tren `rac1` user `grid`:

```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
export PATH=$ORACLE_HOME/bin:$PATH
CV_ASSUME_DISTID=OEL8 ./gridSetup.sh -executeConfigTools -responseFile /home/grid/gridsetup-rac.rsp -silent
```

Tai sao `CV_ASSUME_DISTID=OEL8`:
```text
Tuong tu nhu CVU: Grid 19.3 khong biet OL9, can ep dung task definitions cua OL8.
Khong co bien nay se gap NullPointerException ngay khi khoi dong executeConfigTools.
```

Ket qua thuc te 2026-05-27:

```text
Oracle Net Configuration Assistant  -> PASSED
ASM Configuration Assistant         -> PASSED
Oracle Cluster Verification Utility -> FAILED (post-install CVU check)
  Loi:
    PRVG-6056: ASM instances expected 2, found 1 (rac2 ASM chua chay)
    PRVG-1024: ntpd not running on rac1, rac2
    PRVG-11368: SCAN chi resolve 1 IP (lab /etc/hosts, ignore)
```

Cach doc log khi executeConfigTools fail:

```bash
# Tim log moi nhat:
ls -lt /u01/app/oraInventory/logs/GridSetupActions*/

# Xem config tools nao passed/failed:
grep -E "Configuration Assistant|PASSED|FAILED|Completed|Starting" \
  /u01/app/oraInventory/logs/GridSetupActions<timestamp>/gridSetupActions<timestamp>.log

# Xem loi cu the cua CVU post-check:
grep -E "PRVG-|PRVF-|FATAL|SEVERE|NullPointer|Exception" \
  /u01/app/oraInventory/logs/GridSetupActions<timestamp>/gridSetupActions<timestamp>.log | tail -50
```

### 7b. Dieu tra ASM rac2 khong start (PRVG-6056)

Khi `srvctl start asm -n rac2` bao loi `ORA-03113: end-of-file on communication channel`,
nguy nhan la ASM instance crash ngay khi start. Can dieu tra theo trinh tu sau.

**Buoc 1 - Xem alert log ASM rac2:**

```bash
sudo tail -60 /u01/app/grid/diag/asm/+asm/+ASM2/trace/alert_+ASM2.log
```

Tai sao lenh nay:
```text
Alert log la file dau tien can doc khi bat ky Oracle process nao crash.
No ghi tat ca su kien lifecycle cua instance: start/stop/crash/loi background process.
Dung tail -60 vi loi thay o cuoi file, khong can doc tu dau.
Duong dan co dinh: /u01/app/grid/diag/asm/+asm/+ASM<N>/trace/alert_+ASM<N>.log
  +asm = ASM diagnostic directory
  +ASM2 = instance name (N = node number)
```

Output quan trong can tim:
```text
"terminating the instance due to fatal process death (pid: X, ospid: Y, LMON)"
  -> LMON (Lock Monitor) chet la dau hieu chinh cua van de cluster interconnect
  -> Neu la LGWR/DBWn chet: van de I/O disk
  -> Neu la PMON chet: van de memory/OOM
```

**Buoc 2 - Xem LMON trace:**

```bash
# Tim file trace LMON moi nhat (ls -lt sort theo time, grep lmon loc process):
sudo ls -lt /u01/app/grid/diag/asm/+asm/+ASM2/trace/ | grep lmon | head -3

# Doc 60 dong cuoi (loi thuong o cuoi trace):
sudo tail -60 /u01/app/grid/diag/asm/+asm/+ASM2/trace/+ASM2_lmon_<pid>.trc
```

Tai sao lenh nay:
```text
Moi background process Oracle (LMON, LGWR, DBWn...) co file trace rieng.
Ten file = <instance>_<process>_<ospid>.trc
LMON (Lock Monitor) quan ly cluster membership va GCS (Global Cache Services).
Khi LMON crash vi network, trace no chua IP nao dang duoc dung lam interconnect.
Day la cach duy nhat biet Oracle dang dung IP nao de communicate.
```

Output quan trong can tim va giai thich:
```text
"CSS cluster type is UNKNOWN (1)"
  -> LMON khong xac dinh duoc loai cluster (STANDARD/FLEX).
  -> Thuong xay ra khi CSS interconnect bi block.

"CSS recovery timeout = 31 sec (Total CSS waittime = 65)"
  -> LMON cho 65 giay, vuot qua timeout 31 giay.
  -> Co nghia la CSS khong phan hoi qua interconnect.

"inst 2 nifs 1 (our node)"
"    real IP 169.254.15.195"
  -> ASM instance 2 (rac2) dang dung IP 169.254.15.195 lam interconnect.
  -> Day la Oracle HAIP (Highly Available IP), tu dong assign khi cai Grid.

"inst 1 nifs 0 overall state (0x0:other)"
  -> Instance 1 (rac1) khong co interface nao duoc tim thay tu goc nhin rac2.
  -> Co nghia la rac2 khong the reach rac1 qua HAIP IP.
  -> Asymmetry nay (1 co IP, 1 khong co) = network khong hoat dong.
```

**Buoc 3 - Verify HAIP IP tren ca hai node:**

```bash
# Xem tat ca IP tren NIC private (enp2s0):
ip addr show enp2s0
```

Tai sao lenh nay:
```text
ip addr show <interface> hien thi tat ca IP duoc assign tren mot NIC.
Oracle HAIP tu dong them IP 169.254.x.x/19 vao enp2s0:1 (sub-interface).
Neu thay 2 dong inet: mot la 10.10.10.x (static, cua minh) + mot la 169.254.x.x (Oracle HAIP).
Phai kiem tra CA HAI node de xac nhan HAIP da duoc assign cho ca 2.
```

```text
rac1: inet 169.254.12.87/19 tren enp2s0:1   <- Oracle HAIP
rac2: inet 169.254.15.195/19 tren enp2s0:1  <- Oracle HAIP
Ca hai cung subnet 169.254.0.0/19 -> ve ly thuyet co the noi chuyen truc tiep.
```

**Buoc 4 - Test HAIP ping (xac nhan loi):**

```bash
# -c 3: gui 3 goi tin
# -I enp2s0: ep dung NIC nay (khong de OS tu chon interface khac)
ping -c 3 -I enp2s0 169.254.12.87
```

Tai sao lenh nay:
```text
ping don gian nhat de test L3 connectivity giua 2 IP.
Dung -I enp2s0 de ep traffic di qua dung NIC (private interconnect), 
  khong de OS route qua enp1s0 (public network).
Neu ping thanh cong: van de o Oracle config, khong phai network.
Neu ping that bai (100% loss): network level block -> HAIP khong hoat dong.
```

Expected output khi bi loi:
```text
ping: Warning: source address might be selected on device other than: enp2s0
  -> Warning nay xuat hien vi 169.254.x.x la link-local, OS khong chac chan dung interface nao.
  -> Nhung no VAN dung enp2s0 (thay trong dong "from 169.254.15.195 enp2s0").

3 packets transmitted, 0 received, 100% packet loss
  -> Xac nhan: HAIP IP khong reach duoc nhau qua bridge KVM.
```

Nguyen nhan ky thuat:
```text
169.254.x.x la link-local address (RFC 3927) - chi co y nghia tren local link.
KVM virtual bridge (virbr/vnet) hoat dong o L2 nhung co built-in filtering.
Mot so version KVM/libvirt co ebtables/nftables rules filter link-local unicast.
Tren bare-metal production: physical switch forward tat ca unicast L2 binh thuong.
Tren KVM: can config bridge de forward link-local, hoac don gian la bo qua HAIP.
```

### 7c. Fix ASM HAIP - ep dung cluster_interconnects

**Nguyen tac:**
```text
cluster_interconnects ep Oracle bo qua HAIP, dung thang NIC vat ly.
Phai set theo SID (+ASM1 cho rac1, +ASM2 cho rac2).
Restart ASM sau khi set.
```

**Buoc 1 - Set cluster_interconnects trong ASM spfile (tu rac1, user grid):**

```bash
export ORACLE_HOME=/u01/app/19.0.0/grid
export PATH=$ORACLE_HOME/bin:$PATH
sqlplus / as sysasm
```

```sql
-- Xac nhan spfile dang dung:
SHOW PARAMETER spfile;

-- Set interconnect cho tung SID:
ALTER SYSTEM SET cluster_interconnects='10.10.10.11' SCOPE=SPFILE SID='+ASM1';
ALTER SYSTEM SET cluster_interconnects='10.10.10.12' SCOPE=SPFILE SID='+ASM2';

-- Verify:
SELECT inst_id, name, value FROM gv$spparameter WHERE name='cluster_interconnects';
EXIT;
```

**Buoc 2 - Restart ASM rac1 de ap dung spfile moi:**

Luu y quan trong - KHONG the dung `srvctl stop asm -n rac1 -f` khi rac2 ASM chua chay:

```text
Loi gap:
  PRCR-1214: failed to stop resource group ora.asmgroup
  CRS-2893: Cannot stop ASM instance on server 'rac1' because it is the only instance running.

Nguyen nhan:
  CRS bao ve ASM instance cuoi cung de giu OCR/voting disk accessible.
  srvctl tuong tac voi CRS -> CRS tu choi.
```

Thu `SHUTDOWN IMMEDIATE` trong sqlplus:

```bash
export ORACLE_SID=+ASM1   # QUAN TRONG: phai set truoc khi vao sqlplus
export ORACLE_HOME=/u01/app/19.0.0/grid
export PATH=$ORACLE_HOME/bin:$PATH
sqlplus / as sysasm
```

```sql
SHUTDOWN IMMEDIATE;
```

```text
Loi gap:
  ORA-39512: Stop of CRS resource for instance '223' failed
  CRS-34927: cannot stop resource 'ora.asm' outside of its resource group 'ora.asmgroup'

Nguyen nhan:
  SHUTDOWN IMMEDIATE goi CRS API de coordinate shutdown.
  CRS nhan ra day la instance duy nhat -> tu choi.
```

Dung `SHUTDOWN ABORT` thay the - bypass CRS coordination:

```sql
SHUTDOWN ABORT;
-- Output: ASM instance shutdown
EXIT;
```

```text
Tai sao SHUTDOWN ABORT hoat dong:
  SHUTDOWN ABORT gui SIGKILL truc tiep den process, khong goi CRS API.
  CRS phat hien ASM process chet -> tu dong restart lai ASM voi spfile moi.
  Thoi gian CRS restart ASM: ~30 giay.

Tai sao KHONG dung SHUTDOWN ABORT thuong xuyen:
  SHUTDOWN ABORT khong flush dirty buffers -> co the gay inconsistency.
  Dung OK cho ASM vi ASM khong co user data buffer, chi quan ly disk metadata.
  Cho Oracle DB thong thuong: nen dung SHUTDOWN IMMEDIATE.
```

Sau khi exit sqlplus, CRS tu dong restart ASM tren ca hai node:

```bash
# Doi ~30 giay roi verify:
srvctl status asm
```

Expected:
```text
ASM is running on rac1,rac2
```

**Buoc 3 - Verify ASM dang dung dung interconnect:**

```bash
# Xem client connections:
asmcmd lsct

# Xem disk groups:
asmcmd lsdg

# Xem CRS resources day du:
crsctl stat res -t
```

Confirm rac2 ASM dang dung 10.10.10.x bang cach xem alert log:

```bash
# Tu rac2, sau khi ASM start thanh cong:
sudo tail -20 /u01/app/grid/diag/asm/+asm/+ASM2/trace/alert_+ASM2.log | grep -E "cluster_interconnects|interconnect|10.10.10"
```

Ket qua thuc te 2026-05-27:
```text
srvctl status asm -> ASM is running on rac1,rac2
crsctl stat res -t:
  ora.asm 1  ONLINE ONLINE rac1  STABLE
  ora.asm 2  ONLINE ONLINE rac2  Started,STABLE
  ora.OCRVOTE.dg 1  ONLINE ONLINE rac1  STABLE
  ora.OCRVOTE.dg 2  ONLINE ONLINE rac2  STABLE
  LISTENER ONLINE rac1, rac2
  VIP ONLINE rac1, rac2
```

**Production note:**
```text
Tren bare-metal production: HAIP hoat dong binh thuong, KHONG can buoc nay.
Trong KVM lab: fix nay la chuan - cluster_interconnects la supported parameter,
Oracle support cung khuyen dung khi HAIP co van de.
Behavior sau khi fix hoan toan giong production: Oracle dung 10.10.10.x truc tiep.
```

### 7d. Fix static IP tren ca hai node

**Van de:**
```text
enp1s0 dung DHCP -> IP co the thay doi sau khi reboot hoac lease het han.
Neu IP thay doi: /etc/hosts sai, VIP/SCAN config sai, SSH key sai -> downtime.
enp2s0 da static tu STEP-05 nhung chua dat never-default.
Nen lam buoc nay truoc khi cai Grid, ghi o day vi phat hien trong qua trinh install.
```

**Chay tren rac1, user tandat8896:**

```bash
# Set enp1s0 static:
sudo nmcli con mod enp1s0 \
  ipv4.method manual \
  ipv4.addresses 192.168.122.205/24 \
  ipv4.gateway 192.168.122.1 \
  ipv4.dns 192.168.122.1 \
  ipv4.never-default no \
  connection.autoconnect yes

# Set enp2s0: private, KHONG la default gateway:
sudo nmcli con mod enp2s0 \
  ipv4.method manual \
  ipv4.addresses 10.10.10.11/24 \
  ipv4.gateway "" \
  ipv4.dns "" \
  ipv4.never-default yes \
  connection.autoconnect yes

sudo nmcli con up enp1s0
sudo nmcli con up enp2s0
```

**Chay tren rac2, user tandat8896:**

```bash
sudo nmcli con mod enp1s0 \
  ipv4.method manual \
  ipv4.addresses 192.168.122.46/24 \
  ipv4.gateway 192.168.122.1 \
  ipv4.dns 192.168.122.1 \
  ipv4.never-default no \
  connection.autoconnect yes

sudo nmcli con mod enp2s0 \
  ipv4.method manual \
  ipv4.addresses 10.10.10.12/24 \
  ipv4.gateway "" \
  ipv4.dns "" \
  ipv4.never-default yes \
  connection.autoconnect yes

sudo nmcli con up enp2s0
sudo nmcli con up enp1s0
```

Tai sao tung option:
```text
ipv4.method manual       : tat DHCP, dung IP co dinh
ipv4.never-default yes   : enp2s0 KHONG bao gio la default route
                           -> tranh Oracle interconnect traffic di ra ngoai
                           -> tranh mat ket noi SSH khi có 2 default route
ipv4.gateway "" tren enp2s0 : private NIC khong can gateway
ipv4.dns "" tren enp2s0  : DNS chi qua public NIC
connection.autoconnect yes : tu dong ket noi khi boot
```

**Verify sau khi set:**

```bash
# Kiem tra IP va route:
ip addr show enp1s0 | grep "inet "
ip addr show enp2s0 | grep "inet "
ip route show
```

Expected routes:
```text
default via 192.168.122.1 dev enp1s0 proto static   <- chi 1 default route
10.10.10.0/24 dev enp2s0 proto kernel scope link    <- private via enp2s0
192.168.122.0/24 dev enp1s0 proto kernel scope link <- public via enp1s0
```

Ket qua thuc te 2026-05-27:
```text
rac1: 192.168.122.205/24 static, 10.10.10.11/24 static, default via 192.168.122.1
rac2: 192.168.122.46/24 static,  10.10.10.12/24 static, default via 192.168.122.1
169.254.x.x HAIP bi xoa sau khi nmcli reset enp2s0 -> OHASD se add lai sau reboot
```

**Luu y production:**
```text
Sau khi set static, Oracle HAIP (169.254.x.x) van co the bi OHASD add lai vao enp2s0:1.
Day la binh thuong - Oracle quan ly HAIP rieng, khong lien quan nmcli.
Dung cluster_interconnects (section 7c) de ep Oracle bo qua HAIP.
```

### 7e. Fix NTP (ntpd -> chronyd)

CVU bao `PRVG-1024: ntpd not running` vi OL9 dung `chronyd` thay vi `ntpd`.
Oracle 19.3 CVU check ten daemon `ntpd`, nhung chrony tuong duong ve chuc nang.

Tren ca rac1 va rac2, user tandat8896:

```bash
# Cai va enable chrony:
sudo dnf install -y chrony
sudo systemctl enable --now chronyd

# Verify:
chronyc tracking
timedatectl show | grep NTP
```

Sau do chay lai CVU post-check:

```bash
# Tren rac1, user grid:
CV_ASSUME_DISTID=OEL8 ./runcluvfy.sh stage -post crsinst -n rac1,rac2 -verbose
```

SCAN 1 IP (PRVG-11368) la lab limitation (dung /etc/hosts thay vi DNS), ignore duoc.

## 8. Verify Grid/Cluster

Chay tren `rac1`, user `tandat8896` (dung sudo su - grid de chay 1 lenh, khong can login):

```bash
sudo su - grid -c "
export ORACLE_HOME=/u01/app/19.0.0/grid
export PATH=\$ORACLE_HOME/bin:\$PATH
echo === crsctl check cluster ===
crsctl check cluster -all
echo === olsnodes ===
olsnodes -n
echo === asmcmd lsdg ===
asmcmd lsdg
"
```

Tai sao dung `sudo su - grid -c "..."` thay vi login vao grid:
```text
Chay 1 lenh nhanh ma khong can interactive session.
Dau \ truoc $ORACLE_HOME tranh bash cua tandat8896 expand bien truoc khi truyen vao grid shell.
-c "..." ep grid shell chay lenh roi thoat, khong can exit thu cong.
```

Xem toan bo resources:

```bash
sudo su - grid -c "
export ORACLE_HOME=/u01/app/19.0.0/grid
export PATH=\$ORACLE_HOME/bin:\$PATH
crsctl stat res -t
"
```

Expected output `crsctl check cluster -all`:
```text
rac1:
  CRS-4537: Cluster Ready Services is online
  CRS-4529: Cluster Synchronization Services is online
  CRS-4533: Event Manager is online
rac2:
  CRS-4537: Cluster Ready Services is online
  CRS-4529: Cluster Synchronization Services is online
  CRS-4533: Event Manager is online
```

Expected output `olsnodes -n`:
```text
rac1    1
rac2    2
```

Expected output `asmcmd lsdg`:
```text
State    Type   ... Voting_files  Name
MOUNTED  EXTERN ... Y             OCRVOTE/
```

Expected output `crsctl stat res -t`:
```text
ora.LISTENER.lsnr    ONLINE  ONLINE  rac1, rac2
ora.OCRVOTE.dg       ONLINE  ONLINE  rac1(1), rac2(2)
ora.asm              ONLINE  ONLINE  rac1(1), rac2(2) Started,STABLE
ora.rac1.vip         ONLINE  ONLINE  rac1
ora.rac2.vip         ONLINE  ONLINE  rac2
ora.scan1.vip        ONLINE  ONLINE  rac1 hoac rac2
```

Ket qua thuc te 2026-05-27:
```text
crsctl check cluster -all:
  rac1: CRS online, CSS online, EVM online
  rac2: CRS online, CSS online, EVM online

olsnodes -n:
  rac1  1
  rac2  2

asmcmd lsdg:
  OCRVOTE  MOUNTED  EXTERN  Voting_files=Y  Free=9904MB

crsctl stat res -t:
  ora.LISTENER.lsnr        ONLINE  ONLINE  rac1, rac2      STABLE
  ora.OCRVOTE.dg           ONLINE  ONLINE  rac1, rac2      STABLE
  ora.asm inst1            ONLINE  ONLINE  rac1            STABLE
  ora.asm inst2            ONLINE  ONLINE  rac2            Started,STABLE
  ora.rac1.vip             ONLINE  ONLINE  rac1            STABLE
  ora.rac2.vip             ONLINE  ONLINE  rac2            STABLE
  ora.scan1.vip            ONLINE  ONLINE  rac2            STABLE
```

Chup hinh:

```text
oracle_rac/screenshots/11g-grid-cluster-verify.png
```

## 9. Update shell profile cho grid + cai chrony

**Chay tren rac1 truoc (het buoc 9a + 9b), xong moi sang rac2 lap lai y chang.**

### 9a. Cai chrony (NTP)

```bash
# User tandat8896:
sudo dnf install -y chrony
sudo systemctl enable --now chronyd

# Verify:
systemctl status chronyd | grep -E "Active|running"
chronyc tracking | grep "System time"
```

Tai sao chrony thay vi ntpd:
```text
OL9 dung chronyd lam NTP daemon mac dinh, ntpd khong con duoc cai mac dinh.
Oracle 19.3 CVU check ten daemon 'ntpd' cu the nhung chrony cung duoc Oracle chap nhan.
Time sync quan trong voi RAC: cac node lech nhau > 1 giay co the gay cluster eviction.
```

### 9b. Set shell profile cho grid

```bash
# User tandat8896:
sudo su - grid

# Append vao bash_profile (khong overwrite):
cat >> ~/.bash_profile << 'EOF'

export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/19.0.0/grid
export PATH=$ORACLE_HOME/bin:$PATH
EOF

# Apply va verify:
source ~/.bash_profile
which crsctl
which asmcmd
echo $ORACLE_HOME
```

Expected:
```text
/u01/app/19.0.0/grid/bin/crsctl
/u01/app/19.0.0/grid/bin/asmcmd
/u01/app/19.0.0/grid
```

Tai sao cat >> thay vi vi:
```text
Dung cat >> tranh loi khi vi editor khong co (minimal install).
Dung 'EOF' (co quote) de bash khong expand $ORACLE_HOME khi ghi vao file.
Append (>>) thay vi overwrite (>) de giu cac setting cu neu co.
```

## 10. Stop conditions after install

Dung lai va khong qua Step 10 neu:

```text
crsctl check cluster fail
olsnodes khong thay rac1/rac2
ASM khong online
OCRVOTE disk group khong mount
```

## 11. Done criteria

Hoan thanh Step 09 khi:

```text
Grid Infrastructure installed tren rac1/rac2
root scripts da chay xong
crsctl check cluster OK
olsnodes thay rac1 va rac2
ASM online
OCRVOTE disk group mounted
Chua cai DB home trong Step nay
```
