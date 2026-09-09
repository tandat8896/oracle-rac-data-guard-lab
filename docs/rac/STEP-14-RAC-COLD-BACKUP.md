# Step 14 - Cold Backup Oracle RAC Lab

Muc tieu: backup an toan toan bo Oracle RAC lab bang cach tat cluster/VM roi copy disk image + XML + runbook.

Day la backup muc VM/file, khong phai RMAN backup.

No luu duoc:

```text
rac1 OS disk
rac2 OS disk
shared ASM OCR/VOTE disk
shared ASM DATA disk
shared ASM FRA disk
libvirt VM XML
libvirt network XML
RAC runbooks/config
```

Neu restore dung cach, co the lay lai gan nhu nguyen trang:

```text
Oracle Linux OS
Grid Infrastructure
Oracle DB Home
ASM disk groups
RAC database racdb
CRS/srvctl resource config
```

## 1. Dieu kien truoc khi backup

Khuyen nghi chi backup khi VM da tat hoan toan.

Tren `rac1`, user `tandat8896`, stop cluster truoc:

```bash
sudo /u01/app/19.0.0/grid/bin/crsctl stop cluster -all
sudo /u01/app/19.0.0/grid/bin/crsctl check cluster -all
```

Expected sau khi stop:

```text
CRS-4535: Cannot communicate with Cluster Ready Services
CRS-4530: Communications failure contacting Cluster Synchronization Services daemon
CRS-4534: Cannot communicate with Event Manager
```

Shutdown OS tren ca `rac1` va `rac2`, user `tandat8896`:

```bash
sudo shutdown -h now
```

Tren host NixOS, user `tandat`, verify VM da tat:

```bash
virsh --connect qemu:///system list --all
```

Expected:

```text
rac1  shut off
rac2  shut off
```

## 2. Tao backup folder tren host

Chay tren host NixOS, user `tandat`:

```bash
BACKUP_DIR=/home/tandat/oracle-rac-backups/rac-$(date +%F-%H%M%S)
mkdir -p "$BACKUP_DIR/xml" "$BACKUP_DIR/runbooks" "$BACKUP_DIR/libvirt"
echo "$BACKUP_DIR"
```

Vi du folder:

```text
/home/tandat/oracle-rac-backups/rac-2026-05-27-212125
```

## 3. Backup libvirt XML va runbook

Chay tren host NixOS, user `tandat`, tu repo:

```bash
cd /home/tandat/Desktop/tandat_homelab

virsh --connect qemu:///system dumpxml rac1 > "$BACKUP_DIR/xml/rac1.xml"
virsh --connect qemu:///system dumpxml rac2 > "$BACKUP_DIR/xml/rac2.xml"
virsh --connect qemu:///system net-dumpxml default > "$BACKUP_DIR/xml/net-default.xml"
virsh --connect qemu:///system net-dumpxml rac-priv > "$BACKUP_DIR/xml/net-rac-priv.xml"

cp README.md "$BACKUP_DIR/README.md"
cp ORACLE_HOMELAB_BLUEPRINT_CV.tex "$BACKUP_DIR/" 2>/dev/null || true
cp oracle_rac/*.md "$BACKUP_DIR/runbooks/"
cp -a oracle_rac/libvirt/. "$BACKUP_DIR/libvirt/"
```

## 4. Backup VM disks

Dung `--sparse` vi cac disk image co the la raw/sparse file.

Chay tren host NixOS, user `tandat`, tu repo:

```bash
cd /home/tandat/Desktop/tandat_homelab

sudo rsync -aH --sparse --info=progress2 \
  oracle_rac/vm_disks/ \
  "$BACKUP_DIR/vm_disks/"

sudo chown -R tandat:users "$BACKUP_DIR" 2>/dev/null || true
```

Neu dang copy bi dung giua chung, chay lai y chang lenh `sudo rsync` tren.
`rsync` se tiep tuc dong bo va bo qua file da copy dung.

Khong dung `cp` thuong cho backup nay neu muon tiet kiem dung luong voi sparse image.

## 5. Tao checksum

Chay tren host NixOS, user `tandat`:

```bash
cd "$BACKUP_DIR"
find . -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS.txt
```

Verify checksum sau khi tao:

```bash
sha256sum -c SHA256SUMS.txt
```

## 6. Verify backup local

Chay tren host NixOS, user `tandat`:

```bash
du -sh "$BACKUP_DIR"
find "$BACKUP_DIR" -maxdepth 3 -type f | sort | head -80
find "$BACKUP_DIR/vm_disks" -maxdepth 1 -type f -ls
```

Can thay it nhat:

```text
xml/rac1.xml
xml/rac2.xml
xml/net-default.xml
xml/net-rac-priv.xml
runbooks/*.md
vm_disks/rac1-os.qcow2
vm_disks/rac2-os.qcow2
vm_disks/rac-ocr-vote.img
vm_disks/rac-data.img
vm_disks/rac-fra.img
SHA256SUMS.txt
```

## 7. Copy backup sang USB

USB nen dung filesystem ho tro file lon:

```text
ext4
exFAT
NTFS
```

Khong dung FAT32 vi file lon hon 4GB se loi.

Tim mount point cua USB:

```bash
lsblk -f
```

Vi du USB mount tai:

```text
/run/media/tandat/MYUSB
```

Copy sang USB:

```bash
USB_DIR=/run/media/tandat/MYUSB/oracle-rac-backups/rac-2026-05-27-212125
mkdir -p "$USB_DIR"

rsync -aH --sparse --info=progress2 \
  /home/tandat/oracle-rac-backups/rac-2026-05-27-212125/ \
  "$USB_DIR/"
```

Verify tren USB:

```bash
cd "$USB_DIR"
sha256sum -c SHA256SUMS.txt
du -sh "$USB_DIR"
find "$USB_DIR/vm_disks" -maxdepth 1 -type f -ls
```

Neu `sha256sum -c` ra `OK` het thi USB backup dung.

## 8. Ghi chu restore

Restore co the can:

```text
1. Copy vm_disks ve dung path hoac sua path trong XML.
2. Define lai network tu XML neu mat:
   virsh --connect qemu:///system net-define net-rac-priv.xml
   virsh --connect qemu:///system net-start rac-priv
   virsh --connect qemu:///system net-autostart rac-priv
3. Define lai VM:
   virsh --connect qemu:///system define rac1.xml
   virsh --connect qemu:///system define rac2.xml
4. Start rac1/rac2.
5. Verify CRS/ASM/DB bang Step 13.
```

Khong restore de len VM dang chay.

## 9. Trang thai backup hien tai

Backup folder dang dung trong lan nay:

```text
/home/tandat/oracle-rac-backups/rac-2026-05-27-212125
```

Trang thai ghi nhan luc tao note:

```text
XML/runbooks da backup.
Shared ASM disks da backup.
rac1-os.qcow2 da backup.
rac2-os.qcow2 can confirm lai neu copy bi interrupt.
```

Hoan tat bang cach chay lai:

```bash
cd /home/tandat/Desktop/tandat_homelab

BACKUP_DIR=/home/tandat/oracle-rac-backups/rac-2026-05-27-212125
sudo rsync -aH --sparse --info=progress2 oracle_rac/vm_disks/ "$BACKUP_DIR/vm_disks/"
sudo chown -R tandat:users "$BACKUP_DIR" 2>/dev/null || true

cd "$BACKUP_DIR"
find . -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt
```
