# Step 02 - Create shared ASM disks

Muc tieu: tao cac disk dung chung cho `rac1` va `rac2`.

RAC can shared storage vi 2 node se cung truy cap datafiles/controlfiles/redo thong qua ASM.

Trong lab nay tao 3 disk:

```text
rac-ocr-vote.qcow2  10G
rac-data.qcow2      30G
rac-fra.qcow2       30G
```

Y nghia:

```text
OCR/VOTE: dung cho Grid Infrastructure metadata/voting.
DATA:     dung cho database files.
FRA:      dung cho fast recovery area / archive / backup lab.
```

## 1. Precheck

Chay tu repo root:

```bash
cd /home/tandat/Desktop/tandat_homelab
```

Check disk host:

```bash
df -h /home/tandat/Desktop/tandat_homelab
```

Check VM hien co:

```bash
virsh --connect qemu:///system list --all
```

Check storage pools:

```bash
virsh --connect qemu:///system pool-list --all
```

Chup hinh:

```text
oracle_rac/screenshots/04a-before-shared-disks.png
```

## 2. Tao folder chua disk

Tao folder:

```text
/home/tandat/Desktop/tandat_homelab/oracle_rac/vm_disks
```

Lenh:

```bash
mkdir -p oracle_rac/vm_disks
```

Verify:

```bash
ls -ld oracle_rac/vm_disks
```

## 3. Tao shared ASM disk images

Tao 3 file qcow2:

```bash
qemu-img create -f qcow2 oracle_rac/vm_disks/rac-ocr-vote.qcow2 10G
qemu-img create -f qcow2 oracle_rac/vm_disks/rac-data.qcow2 30G
qemu-img create -f qcow2 oracle_rac/vm_disks/rac-fra.qcow2 30G
```

Neu `qemu-img` khong co trong shell, dung duong dan nay:

```bash
/run/current-system/sw/bin/qemu-img create -f qcow2 oracle_rac/vm_disks/rac-ocr-vote.qcow2 10G
/run/current-system/sw/bin/qemu-img create -f qcow2 oracle_rac/vm_disks/rac-data.qcow2 30G
/run/current-system/sw/bin/qemu-img create -f qcow2 oracle_rac/vm_disks/rac-fra.qcow2 30G
```

## 4. Verify disk images

```bash
ls -lh oracle_rac/vm_disks
qemu-img info oracle_rac/vm_disks/rac-ocr-vote.qcow2
qemu-img info oracle_rac/vm_disks/rac-data.qcow2
qemu-img info oracle_rac/vm_disks/rac-fra.qcow2
```

Expected:

```text
virtual size: 10 GiB
virtual size: 30 GiB
virtual size: 30 GiB
file format: qcow2
```

Chup hinh:

```text
oracle_rac/screenshots/04b-shared-disks-created.png
```

## 5. Important note before VM attach

Chua attach disk vao VM o buoc nay.

Luc tao VM `rac1` va `rac2`, 3 disk nay se duoc attach vao ca hai VM.

Can luu y:

```text
RAC shared disks phai duoc ca 2 VM nhin thay.
Khong format tren host NixOS.
Khong mount tren host NixOS.
Khong dung lam OS disk.
Sau nay Grid/ASM trong Oracle Linux guest se quan ly cac disk nay.
```

## 6. Rollback neu tao sai

Chi xoa neu chac chan chua attach vao VM nao:

```bash
rm oracle_rac/vm_disks/rac-ocr-vote.qcow2
rm oracle_rac/vm_disks/rac-data.qcow2
rm oracle_rac/vm_disks/rac-fra.qcow2
```

Verify rollback:

```bash
ls -lh oracle_rac/vm_disks
```

## 7. Done criteria

Hoan thanh Step 02 khi co:

```text
oracle_rac/vm_disks/rac-ocr-vote.qcow2
oracle_rac/vm_disks/rac-data.qcow2
oracle_rac/vm_disks/rac-fra.qcow2
```

Va `qemu-img info` dung virtual size:

```text
10G
30G
30G
```
