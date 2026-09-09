# Step 04 - Attach shared ASM disks to rac1 and rac2

Muc tieu: attach 3 shared ASM disks vao ca hai VM `rac1` va `rac2`.

Step 01/02/03 khong lam lai. Anh da chup truoc do giu nguyen.

## 0. Current state cua lab

Step 02 ban dau tao shared disks dang `qcow2`.

Khi attach `qcow2` voi `--shareable`, libvirt bao loi:

```text
unsupported configuration: shared access for disk 'vdb' requires use of supported storage format
```

Da fix-forward bang cach convert sang raw `.img`:

```bash
qemu-img convert -f qcow2 -O raw rac-ocr-vote.qcow2 rac-ocr-vote.img
qemu-img convert -f qcow2 -O raw rac-data.qcow2 rac-data.img
qemu-img convert -f qcow2 -O raw rac-fra.qcow2 rac-fra.img
```

Folder hien tai can giu:

```text
oracle_rac/vm_disks/rac-ocr-vote.img
oracle_rac/vm_disks/rac-data.img
oracle_rac/vm_disks/rac-fra.img
oracle_rac/vm_disks/rac1-os.qcow2
oracle_rac/vm_disks/rac2-os.qcow2
```

Y nghia:

```text
rac-ocr-vote.img  shared OCR/VOTE raw disk
rac-data.img      shared DATA raw disk
rac-fra.img       shared FRA raw disk
rac1-os.qcow2     OS disk cua rac1, khong xoa
rac2-os.qcow2     OS disk cua rac2, khong xoa
```

## 1. Precheck

Chay tu repo root:

```bash
cd /home/tandat/Desktop/tandat_homelab
```

Check VM:

```bash
virsh --connect qemu:///system list --all
```

Check files:

```bash
ls -lh oracle_rac/vm_disks
```

Check raw disk info:

```bash
qemu-img info oracle_rac/vm_disks/rac-ocr-vote.img
qemu-img info oracle_rac/vm_disks/rac-data.img
qemu-img info oracle_rac/vm_disks/rac-fra.img
```

Expected:

```text
file format: raw
virtual size: 10 GiB
virtual size: 30 GiB
virtual size: 30 GiB
```

Chup hinh:

```text
oracle_rac/screenshots/06a-raw-shared-disks-ready.png
```

## 2. Shutdown rac1 va rac2

Nen shutdown 2 VM truoc khi attach disk.

```bash
sudo virsh --connect qemu:///system shutdown rac1
sudo virsh --connect qemu:///system shutdown rac2
```

Theo doi den khi ca hai la `shut off`:

```bash
watch -n 2 'virsh --connect qemu:///system list --all'
```

Khi xong, bam:

```text
Ctrl-C
```

Chup hinh:

```text
oracle_rac/screenshots/06b-rac-vms-shutoff-before-attach.png
```

## 3. Attach shared raw disks vao rac1

Attach 3 raw disk vao `rac1`:

```bash
sudo virsh --connect qemu:///system attach-disk rac1 \
  /home/tandat/Desktop/tandat_homelab/oracle_rac/vm_disks/rac-ocr-vote.img \
  vdb \
  --targetbus virtio \
  --driver qemu \
  --subdriver raw \
  --cache none \
  --shareable \
  --config

sudo virsh --connect qemu:///system attach-disk rac1 \
  /home/tandat/Desktop/tandat_homelab/oracle_rac/vm_disks/rac-data.img \
  vdc \
  --targetbus virtio \
  --driver qemu \
  --subdriver raw \
  --cache none \
  --shareable \
  --config

sudo virsh --connect qemu:///system attach-disk rac1 \
  /home/tandat/Desktop/tandat_homelab/oracle_rac/vm_disks/rac-fra.img \
  vdd \
  --targetbus virtio \
  --driver qemu \
  --subdriver raw \
  --cache none \
  --shareable \
  --config
```

Verify `rac1`:

```bash
virsh --connect qemu:///system domblklist rac1
```

Expected:

```text
vda  rac1-os.qcow2
vdb  rac-ocr-vote.img
vdc  rac-data.img
vdd  rac-fra.img
```

Chup hinh:

```text
oracle_rac/screenshots/06c-rac1-raw-shared-disks-attached.png
```

## 4. Attach shared raw disks vao rac2

Attach cung 3 raw disk vao `rac2`:

```bash
sudo virsh --connect qemu:///system attach-disk rac2 \
  /home/tandat/Desktop/tandat_homelab/oracle_rac/vm_disks/rac-ocr-vote.img \
  vdb \
  --targetbus virtio \
  --driver qemu \
  --subdriver raw \
  --cache none \
  --shareable \
  --config

sudo virsh --connect qemu:///system attach-disk rac2 \
  /home/tandat/Desktop/tandat_homelab/oracle_rac/vm_disks/rac-data.img \
  vdc \
  --targetbus virtio \
  --driver qemu \
  --subdriver raw \
  --cache none \
  --shareable \
  --config

sudo virsh --connect qemu:///system attach-disk rac2 \
  /home/tandat/Desktop/tandat_homelab/oracle_rac/vm_disks/rac-fra.img \
  vdd \
  --targetbus virtio \
  --driver qemu \
  --subdriver raw \
  --cache none \
  --shareable \
  --config
```

Verify `rac2`:

```bash
virsh --connect qemu:///system domblklist rac2
```

Expected:

```text
vda  rac2-os.qcow2
vdb  rac-ocr-vote.img
vdc  rac-data.img
vdd  rac-fra.img
```

Chup hinh:

```text
oracle_rac/screenshots/06d-rac2-raw-shared-disks-attached.png
```

## 5. Start rac1 va rac2

```bash
sudo virsh --connect qemu:///system start rac1
sudo virsh --connect qemu:///system start rac2
```

Verify host:

```bash
virsh --connect qemu:///system list --all
virsh --connect qemu:///system domblklist rac1
virsh --connect qemu:///system domblklist rac2
```

Chup hinh:

```text
oracle_rac/screenshots/06e-rac-vms-started-with-shared-disks.png
```

## 6. Verify trong rac1

Login vao `rac1`.

Lenh SSH da dung trong lab RAC nay:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.205
```

Neu IP cua `rac1` doi, lay IP moi:

```bash
virsh --connect qemu:///system domifaddr rac1
```

Roi SSH theo mau:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@<rac1-public-ip>
```

Neu can console:

```bash
virt-viewer --connect qemu:///system rac1
```

Trong `rac1`, check block devices:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
```

Expected:

```text
vda  50G   disk   OS disk
vdb  10G   disk   shared OCR/VOTE
vdc  30G   disk   shared DATA
vdd  30G   disk   shared FRA
```

Khong format cac disk `vdb/vdc/vdd`.

Chup hinh:

```text
oracle_rac/screenshots/06f-rac1-lsblk-shared-disks.png
```

## 7. Verify trong rac2

Login vao `rac2`.

Lenh SSH da dung trong lab RAC nay:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.46
```

Neu IP cua `rac2` doi, lay IP moi:

```bash
virsh --connect qemu:///system domifaddr rac2
```

Roi SSH theo mau:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@<rac2-public-ip>
```

Neu can console:

```bash
virt-viewer --connect qemu:///system rac2
```

Trong `rac2`, check block devices:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
```

Expected:

```text
vda  50G   disk   OS disk
vdb  10G   disk   shared OCR/VOTE
vdc  30G   disk   shared DATA
vdd  30G   disk   shared FRA
```

Khong format cac disk `vdb/vdc/vdd`.

Chup hinh:

```text
oracle_rac/screenshots/06g-rac2-lsblk-shared-disks.png
```

## 8. Rollback neu attach sai

Chi chay rollback neu attach sai target hoac can lam lai Step 04.

VM nen shutdown truoc:

```bash
sudo virsh --connect qemu:///system shutdown rac1
sudo virsh --connect qemu:///system shutdown rac2
```

Detach tren `rac1`:

```bash
sudo virsh --connect qemu:///system detach-disk rac1 vdb --config
sudo virsh --connect qemu:///system detach-disk rac1 vdc --config
sudo virsh --connect qemu:///system detach-disk rac1 vdd --config
```

Detach tren `rac2`:

```bash
sudo virsh --connect qemu:///system detach-disk rac2 vdb --config
sudo virsh --connect qemu:///system detach-disk rac2 vdc --config
sudo virsh --connect qemu:///system detach-disk rac2 vdd --config
```

Verify rollback:

```bash
virsh --connect qemu:///system domblklist rac1
virsh --connect qemu:///system domblklist rac2
```

Khong xoa disk files neu chi rollback attach:

```text
oracle_rac/vm_disks/rac-ocr-vote.img
oracle_rac/vm_disks/rac-data.img
oracle_rac/vm_disks/rac-fra.img
oracle_rac/vm_disks/rac1-os.qcow2
oracle_rac/vm_disks/rac2-os.qcow2
```

## 9. Done criteria

Hoan thanh Step 04 khi:

```text
rac1 co vdb/vdc/vdd shared raw disks
rac2 co vdb/vdc/vdd shared raw disks
Ca hai VM start duoc
Trong ca hai guest, lsblk thay them 10G/30G/30G
Chua format/mount shared disks
Co screenshot 06a den 06g
```
