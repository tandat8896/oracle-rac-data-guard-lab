# Oracle RAC lab on NixOS host

Muc tieu: dung NixOS lam hypervisor, tao 2 VM Oracle Linux de hoc Oracle RAC 19c.

Khong cai Oracle RAC/Grid truc tiep len NixOS host.

## Important branch: VM RAC vs Podman RAC

Sau khi doc skill `db/containers/rac.md` va `db/containers/rac_ru.md`, co them mot duong khac:

```text
Oracle Container Registry co repo rieng cho RAC:
  container-registry.oracle.com/database/rac
  container-registry.oracle.com/database/rac_ru
```

Note tu skill:

```text
database/rac = Oracle Real Application Clusters image.
database/rac_ru = RAC Release Update image stream.
Oracle docs/OCR noi RAC containers supported on Podman starting with:
  19c 19.16
  21c 21.7
  23.26ai / 26ai
```

Dieu nay khac voi image dang dung cho Data Guard:

```text
container-registry.oracle.com/database/enterprise:23.26.1.0
```

Da query trong image Data Guard hien tai:

```sql
select parameter, value
from v$option
where lower(parameter) like '%real application clusters%'
   or lower(parameter) like '%rac%';
```

Ket qua:

```text
Real Application Clusters    FALSE
Oracle Data Guard            TRUE
```

Ket luan:

```text
Image enterprise hien tai khong dung de hoc RAC.
Neu muon RAC tren Podman, phai dung repo rieng database/rac hoac database/rac_ru.
VM RAC 19c van la duong hoc sau, nhung khong phai lua chon duy nhat.
```

Quyet dinh truoc khi tao VM:

```text
Option A: RAC Podman official image
  Can accept license cho repo database/rac hoac database/rac_ru tren Oracle Container Registry.
  Can doc dung Oracle RAC Podman guide.
  Co the hop voi mong muon "dang dung Podman 26ai".

Option B: RAC VM 19c trial
  Da tai DB/Grid 19.3 zip.
  Dung 2 Oracle Linux VM, shared disks, Grid Infrastructure.
  Bi gioi han trial/license theo eDelivery neu khong co license khac.
```

Guardrail moi:

```text
Khong tao VM rac1/rac2 truoc khi chot Option A hay Option B.
Neu chon Podman RAC, khong dung database/enterprise image cu.
Neu chon VM RAC, dung DB/Grid zip da tai.
```

## 0. License / trial note

Neu tai tu Oracle Software Delivery Cloud:

```text
Oracle Trial License: 30 days
Dung cho evaluation/testing.
Khong dung production.
Tu quan ly ngay het han va xoa/stop lab neu khong co license hop le khac.
```

Can tai dung 2 goi:

```text
Oracle Database 19.3.0.0.0 - Long Term Release
Oracle Database Grid Infrastructure 19.3.0.0.0
```

Platform:

```text
Linux x86-64
```

File ky vong:

```text
LINUX.X64_193000_db_home.zip
LINUX.X64_193000_grid_home.zip
```

Oracle portal note can nho:

```text
Included as part of the Oracle Database are certain options and packs which may result in additional costs when enabled and used.
Confirm you maintain the appropriate licenses, or you may incur additional costs based on your usage.
```

Doc theo lab:

```text
Chi dung cho evaluation/testing theo trial.
Khong bat/dung option/pack khong can thiet cho lab.
Khong dung production/commercial/internal business data.
```

Portal cung bao:

```text
This is the base release of Oracle Database 19c.
After installing this software, download and install the latest Release Update (RU) to get the most current security and functionality.
For the latest RU, go to My Oracle Support Doc ID 2118136.2.
```

Doc theo lab:

```text
File 19.3 la base release.
RU/patch moi thuong can My Oracle Support.
Neu khong co MOS/support, lab co the phai dung base 19.3 va chap nhan co the gap loi da duoc fix o RU moi.
```

Download UI note:

```text
You may download files individually by clicking the file name.
```

## 1. Host checkpoint

Da check tren NixOS host:

```text
Disk:
/dev/nvme1n1p2  439G  128G  289G  31% /

RAM:
Mem: 27Gi total, 18Gi available
Swap: 43Gi

CPU:
12 cores
```

Libvirt:

```text
virsh --connect qemu:///system list --all

 Id   Name        State
----------------------------
 -    oracle-db   shut off
```

Networks:

```text
virsh --connect qemu:///system net-list --all

 Name      State    Autostart   Persistent
--------------------------------------------
 default   active   yes         yes
```

Pools:

```text
default          active   yes
oracle_23c       active   yes
Rocky_Linux      active   yes
tandat_homelab   active   yes
```

Ket luan:

```text
May du de lam 2-node RAC lab nho.
Khong dung lai VM oracle-db de tranh pha lab cu.
Tao VM moi: rac1, rac2.
```

## 2. Proposed topology

VMs:

```text
rac1
rac2
```

Suggested size moi VM:

```text
RAM: 6G
vCPU: 2
OS disk: 50G
```

Shared disks cho ASM:

```text
asm-ocr-vote-01.qcow2  10G
asm-data-01.qcow2      30G
asm-fra-01.qcow2       30G
```

Neu muon nhe hon:

```text
OCR/VOTE: 10G
DATA: 20G
FRA: 20G
```

Networks:

```text
public:  libvirt default NAT, dung SSH/client/listener
private: isolated libvirt network cho interconnect
```

## 3. Runbook steps

Index tong:

```text
oracle_rac/INDEX.md
```

Lam theo thu tu:

```text
Step 01: oracle_rac/STEP-01-RAC-PRIVATE-NETWORK.md
Step 02: oracle_rac/STEP-02-RAC-SHARED-DISKS.md
Step 03: oracle_rac/STEP-03-RAC-CREATE-VMS.md
Step 04: oracle_rac/STEP-04-RAC-ATTACH-SHARED-ASM-DISKS.md
Step 05: oracle_rac/STEP-05-RAC-NETWORK-HOSTS.md
Step 06: oracle_rac/STEP-06-RAC-OS-PREREQS.md
Step 07: oracle_rac/STEP-07-RAC-ASM-DISK-UDEV.md
Step 08: oracle_rac/STEP-08-RAC-STAGE-ORACLE-SOFTWARE.md
Step 09: oracle_rac/STEP-09-RAC-GRID-INSTALL.md
```

Trang thai hien tai:

```text
Step 01 done: rac-priv network da tao.
Step 02 done: shared ASM disk images da tao.
Step 03 done/current: tao VM rac1/rac2 va cai Oracle Linux.
Step 04 done/current: attach shared ASM disks vao ca hai VM.
Step 05 done/current: cau hinh private IP va /etc/hosts cho RAC.
Step 06 done/current: OS prerequisites cho Grid/RAC.
Step 07 done/current: ASM disk udev rules.
Step 08 current/next: stage Oracle Grid/DB software vao VM.
Step 09 next: Grid Infrastructure install, chi chay sau khi Step 08 xong.
```

Khong dung Podman network cho RAC.

### Libvirt private network decision

Da check libvirt docs:

```text
Isolated private network = omit <forward>.
Guests can communicate with each other and host.
No external LAN routing.
DHCP is optional.
```

Quyet dinh cho RAC:

```text
rac-priv se la isolated network.
Khong co <forward>.
Khong bat DHCP.
Dung static IP trong Oracle Linux guest:
  rac1-priv 10.10.10.11
  rac2-priv 10.10.10.12
```

Ly do:

```text
RAC private interconnect can on dinh, khong doi IP.
Khong can route ra internet tren private interconnect.
Public/client/install traffic dung libvirt default network rieng.
```

XML:

```xml
<network>
  <name>rac-priv</name>
  <bridge name='virbr-racpriv' stp='on' delay='0'/>
  <ip address='10.10.10.1' netmask='255.255.255.0'/>
</network>
```

Rollback neu can:

```bash
sudo virsh --connect qemu:///system net-destroy rac-priv
sudo virsh --connect qemu:///system net-undefine rac-priv
```

### Commands: create `rac-priv` network

Tao folder neu chua co:

```bash
mkdir -p oracle_rac/libvirt
```

Chay tu repo root:

```bash
pwd
```

Expected:

```text
/home/tandat/Desktop/tandat_homelab
```

Precheck:

```bash
virsh --connect qemu:///system net-list --all
```

Tao file:

```text
oracle_rac/libvirt/rac-priv.xml
```

Noi dung file:

```xml
<network>
  <name>rac-priv</name>
  <bridge name='virbr-racpriv' stp='on' delay='0'/>
  <ip address='10.10.10.1' netmask='255.255.255.0'/>
</network>
```

Review XML truoc khi define:

```bash
cat oracle_rac/libvirt/rac-priv.xml
```

Define/start/autostart:

```bash
sudo virsh --connect qemu:///system net-define oracle_rac/libvirt/rac-priv.xml
sudo virsh --connect qemu:///system net-start rac-priv
sudo virsh --connect qemu:///system net-autostart rac-priv
```

Verify:

```bash
virsh --connect qemu:///system net-list --all
virsh --connect qemu:///system net-dumpxml rac-priv
ip addr show virbr-racpriv
```

Screenshot:

```text
oracle_rac/screenshots/03-rac-private-network.png
```

Expected verify:

```text
rac-priv active yes yes
bridge name='virbr-racpriv'
ip address='10.10.10.1'
```

## 3. IP plan draft

Can chot lai sau khi tao libvirt network.

Public:

```text
rac1-public   192.168.122.171
rac2-public   192.168.122.172
rac1-vip      192.168.122.181
rac2-vip      192.168.122.182
scan1         192.168.122.191
scan2         192.168.122.192
scan3         192.168.122.193
```

Private interconnect:

```text
rac1-priv     10.10.10.11
rac2-priv     10.10.10.12
```

Trong homelab co the dung `/etc/hosts` truoc.
Production dung DNS cho SCAN.

## 4. Download staging

Dat file tai ve vao:

```text
oracle_rac/downloads/
```

Expected:

```text
oracle_rac/downloads/LINUX.X64_193000_grid_home.zip
oracle_rac/downloads/LINUX.X64_193000_db_home.zip
```

Check:

```bash
ls -lh oracle_rac/downloads
sha256sum oracle_rac/downloads/*.zip
```

Da tai va move vao:

```text
oracle_rac/downloads/V982063-01.zip  2.9G
oracle_rac/downloads/V982068-01.zip  2.7G
```

Phan loai:

```text
V982063-01.zip = Oracle Database 19.3 DB home
V982068-01.zip = Oracle Grid Infrastructure 19.3 Grid home
```

Giai nen tren host NixOS bang `nix shell nixpkgs#unzip`:

```bash
mkdir -p oracle_rac/stage/db_home oracle_rac/stage/grid_home

nix shell nixpkgs#unzip -c unzip -q oracle_rac/downloads/V982063-01.zip -d oracle_rac/stage/db_home
nix shell nixpkgs#unzip -c unzip -q oracle_rac/downloads/V982068-01.zip -d oracle_rac/stage/grid_home
```

Dung luong sau giai nen:

```text
downloads: 5.6G
stage:     13G
```

Verify DB home:

```text
oracle_rac/stage/db_home/runInstaller
oracle_rac/stage/db_home/bin/dbca
```

Verify Grid home:

```text
oracle_rac/stage/grid_home/gridSetup.sh
oracle_rac/stage/grid_home/root.sh
oracle_rac/stage/grid_home/crs/install/rootcrs.sh
oracle_rac/stage/grid_home/crs/install/roothas.sh
oracle_rac/stage/grid_home/bin/asmcmd
oracle_rac/stage/grid_home/bin/srvctl
oracle_rac/stage/grid_home/bin/crsctl.bin
```

Note:

```text
Trong stage thay crsctl.bin, chua thay wrapper crsctl.
Khi install Grid tren guest, installer/root scripts co the tao wrapper/link phu hop.
```

Disk sau giai nen:

```text
/dev/nvme1n1p2  439G  146G  271G  35%
```

## 5. High-level install path

Ngay 1:

```text
1. Tao libvirt private network.
2. Tao 2 VM Oracle Linux: rac1/rac2.
3. Gan shared disks vao ca 2 VM.
4. Cai packages/preinstall.
5. Tao users/groups: grid/oracle.
6. Setup hostname, /etc/hosts, SSH equivalence.
7. Run cluvfy.
8. Install Grid Infrastructure.
9. Tao ASM disk groups.
```

Ngay 2:

```text
1. Install Database home.
2. Tao RAC database bang DBCA.
3. Check crsctl/srvctl.
4. Tao service.
5. Stop/start instance.
6. Test node/instance/service failover.
7. Ghi log loi va rollback.
```

## 6. Guardrails

Khong lam:

```text
Khong dung VM oracle-db hien co.
Khong mount nham disk cua oracle_23c/Data Guard lab.
Khong dung production data.
Khong de qua trial window neu khong co license hop le.
```

Truoc moi buoc destructive:

```bash
virsh --connect qemu:///system list --all
virsh --connect qemu:///system vol-list <pool>
```

Ten VM/disk phai co prefix:

```text
rac-
```

## 7. Current status

```text
Status: waiting for downloads.
Next: dat grid/db zip vao oracle_rac/downloads, sau do tao private network va VM plan chi tiet.
```
