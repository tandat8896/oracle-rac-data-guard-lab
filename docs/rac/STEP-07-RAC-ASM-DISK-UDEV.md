# Step 07 - ASM disk prep with udev rules

Muc tieu: tao device name on dinh va permission dung cho ASM disks tren ca `rac1` va `rac2`.

Shared disks hien tai:

```text
vdb 10G  OCR/VOTE
vdc 30G  DATA
vdd 30G  FRA
```

ASM target names:

```text
/dev/asm-ocrvote
/dev/asm-data
/dev/asm-fra
```

Owner/permission:

```text
owner: grid
group: asmadmin
mode: 0660
```

Luu y:

```text
Khong format bang mkfs.
Khong mount.
Khong tao partition neu khong can.
Grid/ASM se dung cac raw block devices qua udev symlink.
```

## 1. Precheck tren ca hai node

Chay tren `rac1` va `rac2`:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
ls -l /dev/vdb /dev/vdc /dev/vdd
id grid
getent group asmadmin
```

Expected:

```text
vdb 10G disk, no FSTYPE
vdc 30G disk, no FSTYPE
vdd 30G disk, no FSTYPE
grid user ton tai
asmadmin group ton tai
```

Ket qua hien tai:

```text
rac1:
  vdb 10G disk, no FSTYPE, /dev/vdb root:disk
  vdc 30G disk, no FSTYPE, /dev/vdc root:disk
  vdd 30G disk, no FSTYPE, /dev/vdd root:disk
  grid uid=54331, groups include asmadmin
  asmadmin gid=54329, member grid

rac2:
  vdb 10G disk, no FSTYPE, /dev/vdb root:disk
  vdc 30G disk, no FSTYPE, /dev/vdc root:disk
  vdd 30G disk, no FSTYPE, /dev/vdd root:disk
  grid uid=54331, groups include asmadmin
  asmadmin gid=54329, member grid
```

Chup hinh:

```text
oracle_rac/screenshots/09a-asm-disk-precheck.png
```

## 2. Lay ID_SERIAL cua disks

Tren `rac1`, chay:

```bash
sudo udevadm info --query=property --name=/dev/vdb | grep -E 'ID_SERIAL=|ID_WWN=|DEVNAME='
sudo udevadm info --query=property --name=/dev/vdc | grep -E 'ID_SERIAL=|ID_WWN=|DEVNAME='
sudo udevadm info --query=property --name=/dev/vdd | grep -E 'ID_SERIAL=|ID_WWN=|DEVNAME='
```

Tren `rac2`, chay cung lenh:

```bash
sudo udevadm info --query=property --name=/dev/vdb | grep -E 'ID_SERIAL=|ID_WWN=|DEVNAME='
sudo udevadm info --query=property --name=/dev/vdc | grep -E 'ID_SERIAL=|ID_WWN=|DEVNAME='
sudo udevadm info --query=property --name=/dev/vdd | grep -E 'ID_SERIAL=|ID_WWN=|DEVNAME='
```

Can ghi lai serial cua tung disk.

Expected:

```text
vdb serial tren rac1 == vdb serial tren rac2
vdc serial tren rac1 == vdc serial tren rac2
vdd serial tren rac1 == vdd serial tren rac2
```

Neu khong co `ID_SERIAL`, dung fallback theo `KERNEL=="vdb"` trong lab nay, nhung serial tot hon.

Ket qua hien tai:

```text
rac1 udevadm chi co DEVNAME=/dev/vdb, /dev/vdc, /dev/vdd.
Khong co ID_SERIAL/ID_WWN.
Do do lab dung fallback rule theo KERNEL vdb/vdc/vdd.
```

Chup hinh:

```text
oracle_rac/screenshots/09b-asm-disk-serials.png
```

## 3. Tao udev rules neu co ID_SERIAL

Tao file tren ca `rac1` va `rac2`:

```text
/etc/udev/rules.d/99-oracle-asmdevices.rules
```

Mau noi dung neu co serial:

```text
KERNEL=="vd*", ENV{ID_SERIAL}=="<OCRVOTE_SERIAL>", SYMLINK+="asm-ocrvote", OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="vd*", ENV{ID_SERIAL}=="<DATA_SERIAL>",    SYMLINK+="asm-data",    OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="vd*", ENV{ID_SERIAL}=="<FRA_SERIAL>",     SYMLINK+="asm-fra",     OWNER="grid", GROUP="asmadmin", MODE="0660"
```

Thay:

```text
<OCRVOTE_SERIAL> bang ID_SERIAL cua /dev/vdb
<DATA_SERIAL>    bang ID_SERIAL cua /dev/vdc
<FRA_SERIAL>     bang ID_SERIAL cua /dev/vdd
```

## 4. Fallback udev rules theo device name

Chi dung fallback neu `udevadm info` khong co `ID_SERIAL`.

Trong lab hien tai, VM attach disks co target co dinh:

```text
vdb = OCR/VOTE
vdc = DATA
vdd = FRA
```

Tao file tren ca `rac1` va `rac2`:

```text
/etc/udev/rules.d/99-oracle-asmdevices.rules
```

Noi dung fallback:

```text
KERNEL=="vdb", SYMLINK+="asm-ocrvote", OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="vdc", SYMLINK+="asm-data",    OWNER="grid", GROUP="asmadmin", MODE="0660"
KERNEL=="vdd", SYMLINK+="asm-fra",     OWNER="grid", GROUP="asmadmin", MODE="0660"
```

Lenh tao bang `printf`:

```bash
sudo sh -c "printf '%s\n' \
'KERNEL==\"vdb\", SYMLINK+=\"asm-ocrvote\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"' \
'KERNEL==\"vdc\", SYMLINK+=\"asm-data\",    OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"' \
'KERNEL==\"vdd\", SYMLINK+=\"asm-fra\",     OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"' \
> /etc/udev/rules.d/99-oracle-asmdevices.rules"
```

## 5. Reload udev

Chay tren ca `rac1` va `rac2`:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --type=devices --action=change
sudo udevadm settle
```

Verify:

```bash
ls -l /dev/asm-*
ls -l /dev/vdb /dev/vdc /dev/vdd
```

Expected:

```text
/dev/asm-ocrvote -> vdb
/dev/asm-data    -> vdc
/dev/asm-fra     -> vdd

/dev/vdb owner/group grid asmadmin mode brw-rw----
/dev/vdc owner/group grid asmadmin mode brw-rw----
/dev/vdd owner/group grid asmadmin mode brw-rw----
```

Ket qua hien tai tren ca `rac1` va `rac2`:

```text
/dev/asm-data    -> vdc
/dev/asm-fra     -> vdd
/dev/asm-ocrvote -> vdb

/dev/vdb grid:asmadmin brw-rw----
/dev/vdc grid:asmadmin brw-rw----
/dev/vdd grid:asmadmin brw-rw----
```

Chup hinh:

```text
oracle_rac/screenshots/09c-asm-udev-rules-applied.png
```

## 6. Test grid access

Chay tren ca `rac1` va `rac2`:

```bash
sudo su - grid
ls -l /dev/asm-*
dd if=/dev/asm-ocrvote of=/dev/null bs=1M count=1
dd if=/dev/asm-data of=/dev/null bs=1M count=1
dd if=/dev/asm-fra of=/dev/null bs=1M count=1
exit
```

Expected:

```text
dd read 1 MiB thanh cong
Khong co Permission denied
```

Ket qua hien tai:

```text
grid read test OK tren ca rac1 va rac2.
rac2 output da verify:
  dd if=/dev/asm-ocrvote -> 1+0 records in/out
  dd if=/dev/asm-data    -> 1+0 records in/out
  dd if=/dev/asm-fra     -> 1+0 records in/out
Khong co Permission denied.
```

Khong chay `of=/dev/asm-*`.
Chi read test, khong write.

Chup hinh:

```text
oracle_rac/screenshots/09d-grid-can-read-asm-disks.png
```

## 7. Reboot persistence test

Optional nhung nen lam truoc Grid installer.

Reboot tung node mot:

```bash
sudo reboot
```

Sau khi node len lai:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
ls -l /dev/asm-*
getent ahostsv4 rac1 rac2 rac1-priv rac2-priv rac-scan
```

Expected:

```text
/dev/asm-* van ton tai
owner/group/mode van dung
network hosts van dung
```

Ket qua hien tai:

```text
Reboot persistence test OK.
rac2 sau reboot:
  /dev/asm-data    -> vdc
  /dev/asm-fra     -> vdd
  /dev/asm-ocrvote -> vdb
  /dev/vdb/vdc/vdd = grid:asmadmin brw-rw----
  enp1s0 = 192.168.122.46/24
  enp2s0 = 10.10.10.12/24
rac1 da reboot/verify OK theo cung tieu chi.
```

Chup hinh:

```text
oracle_rac/screenshots/09e-asm-udev-after-reboot.png
```

## 8. Done criteria

Hoan thanh Step 07 khi:

```text
rac1 co /dev/asm-ocrvote /dev/asm-data /dev/asm-fra
rac2 co /dev/asm-ocrvote /dev/asm-data /dev/asm-fra
Owner/group la grid:asmadmin
Mode la 0660
grid read duoc ca 3 devices tren ca hai node
Khong format/mount ASM disks
```
