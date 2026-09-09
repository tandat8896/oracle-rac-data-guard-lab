# Step 03 - Create RAC VMs and start Oracle Linux install

Muc tieu: tao 2 VM `rac1` va `rac2` tren libvirt/KVM.

Moi VM co:

```text
OS:      Oracle Linux 9
RAM:     6G
vCPU:    2
OS disk: 50G
NIC 1:   default NAT network, dung public/client/SSH
NIC 2:   rac-priv isolated network, dung RAC private interconnect
```

Luu y quan trong:

```text
Step nay chi tao OS disk va VM.
Chua attach 3 shared ASM disks vao VM.
Shared ASM disks se attach o step sau voi cau hinh shareable/cache phu hop.
Step 01 va Step 02 da lam roi thi khong lam lai.
```

## 1. Precheck

Chay tu repo root:

```bash
cd /home/tandat/Desktop/tandat_homelab
```

Check file ISO Oracle Linux 9:

```bash
ls -lh oracle_23c/OracleLinux-R9-U7-x86_64-boot-uek.iso
```

Check libvirt networks:

```bash
virsh --connect qemu:///system net-list --all
```

Expected:

```text
default    active   yes   yes
rac-priv   active   yes   yes
```

Neu `rac-priv` inactive thi start lai:

```bash
sudo virsh --connect qemu:///system net-start rac-priv
sudo virsh --connect qemu:///system net-autostart rac-priv
```

Check VM hien co:

```bash
virsh --connect qemu:///system list --all
```

Expected:

```text
Chua co VM ten rac1
Chua co VM ten rac2
```

Check shared ASM disks da tao tu Step 02:

```bash
ls -lh oracle_rac/vm_disks
```

Check host disk con du:

```bash
df -h /home/tandat/Desktop/tandat_homelab
```

Chup hinh:

```text
oracle_rac/screenshots/05a-before-create-rac-vms.png
```

## 2. Check virt-install

Check command:

```bash
command -v virt-install
virt-install --version
```

Neu `virt-install` khong co trong shell NixOS, thu chay qua nix shell:

```bash
nix shell nixpkgs#virt-manager
```

Sau do check lai:

```bash
command -v virt-install
virt-install --version
```

Check OS info neu can doi variant:

```bash
osinfo-query os | grep -Ei 'oracle|ol9'
```

Lenh tao VM trong file nay dung:

```text
--osinfo ol9-unknown
```

Day la cach da map theo lab Oracle VM/K8s cu trong repo.

## 3. OS disk se do virt-install tao

Theo cach cu da chay duoc trong `oracle_23c/justfile`, de `virt-install` tao OS disk:

```text
--disk size=50,format=qcow2
```

Ly do:

```text
Lan truoc lenh tu tao path OS disk + graphics listen rieng bi lech voi cach cu cua homelab.
De libvirt/virt-install tao disk theo storage mac dinh giong lab Oracle VM/K8s cu se it loi hon.
```

## 4. Neu da tao sai/no bootable device thi xoa truoc

Neu da tao `rac1`/`rac2` bang lenh cu va gap loi:

```text
No bootable device
No boot login
Khong vao duoc installer
Console khong dung duoc
```

Thi xoa 2 VM loi truoc khi tao lai.

Chay tu host:

```bash
sudo virsh --connect qemu:///system destroy rac1 2>/dev/null || true
sudo virsh --connect qemu:///system undefine rac1 --nvram --remove-all-storage 2>/dev/null || true
sudo virsh --connect qemu:///system destroy rac2 2>/dev/null || true
sudo virsh --connect qemu:///system undefine rac2 --nvram --remove-all-storage 2>/dev/null || true
```

Neu OS disk nam ngoai storage pool va van con file, chi xoa 2 OS disk nay:

```bash
rm -f /home/tandat/Desktop/tandat_homelab/oracle_rac/vm_os/rac1-os.qcow2
rm -f /home/tandat/Desktop/tandat_homelab/oracle_rac/vm_os/rac2-os.qcow2
```

Khong xoa 3 shared ASM disks:

```text
oracle_rac/vm_disks/rac-ocr-vote.qcow2
oracle_rac/vm_disks/rac-data.qcow2
oracle_rac/vm_disks/rac-fra.qcow2
```

Verify:

```bash
virsh --connect qemu:///system list --all
ls -lh oracle_rac/vm_disks
```

Chup hinh:

```text
oracle_rac/screenshots/05b-before-create-vm-clean-state.png
```

## 5. Tao VM rac1

Lenh nay map theo cach cu da dung trong:

```text
oracle_23c/justfile
k8s/readme-kvm-virtmanager.md
k8s/README-ROCKY-LINUX-SSH.md
```

Khac voi lenh loi truoc:

```text
Dung --osinfo ol9-unknown thay vi --os-variant generic.
Dung --graphics spice, khong ep listen=127.0.0.1.
Dung --disk size=50,format=qcow2 de libvirt tao OS disk theo cach cu da chay duoc.
Mo console bang virt-viewer --connect qemu:///system rac1.
```

Chay tu folder oracle_23c (khong dung sudo - DISPLAY se mat):

```bash
cd /home/tandat/Desktop/tandat_homelab/oracle_23c

virt-install \
  --name rac1 \
  --memory 6144 \
  --vcpus 2 \
  --disk path=/home/tandat/Desktop/tandat_homelab/oracle_rac/vm_disks/rac1-os.qcow2,size=50 \
  --cdrom OracleLinux-R9-U7-x86_64-boot-uek.iso \
  --osinfo ol9-unknown \
  --network network=default \
  --network network=rac-priv \
  --graphics spice &
```

Mo console ngay sau do:

```bash
virt-viewer --connect qemu:///system rac1
```

Neu can mo virt-manager thi mo dung connection:

```bash
virt-manager --connect qemu:///system
```

Neu thay output nhu nay:

```text
WARNING  No display detected. Not running virt-viewer.
WARNING  No console to launch for the guest, defaulting to --wait -1
Domain is still running. Installation may be in progress.
Waiting for the installation to complete.
```

Thi khong phai bi treo.
`virt-install` da tao VM xong, nhung terminal dang doi minh cai OS trong console.

Luc nay co the bam `Ctrl-C` de thoat lenh `virt-install`.
VM `rac1` van dang chay.

Verify tu terminal:

```bash
virsh --connect qemu:///system list --all
virsh --connect qemu:///system domdisplay rac1
```

Chup hinh khi thay installer Oracle Linux:

```text
oracle_rac/screenshots/05c-rac1-oracle-linux-installer.png
```

## 6. Cai Oracle Linux tren rac1

Trong installer Oracle Linux (OL9 net-install):

```text
Network & Hostname:
  enp1s0 (NIC 1 - default NAT) → bat ON, tu lay DHCP/internet.
  enp2s0 (NIC 2 - rac-priv)   → de OFF, set static sau.
  Hostname: rac1

Installation Source:
  Chon "Closest mirror" → Oracle tu tim repo gan nhat.
  Khong can nhap URL tay.

Software Selection:
  Minimal Install.

Installation Destination:
  Chon disk 50G cua rac1.
  Automatic partitioning.
  Khong thay 3 shared ASM disks la dung - chua attach o buoc nay.

Root Password:
  Dat password, bat "Allow root SSH login".

User Creation:
  Tao user tandat, tick "Make this user administrator".
  UID/GID de mac dinh (1000/1000).

Security Policy:
  Bo qua, khong can cho lab.
```

Sau khi install xong, reboot `rac1`.

Verify tu host:

```bash
virsh --connect qemu:///system list --all
```

Expected:

```text
rac1 running
```

Chup hinh:

```text
oracle_rac/screenshots/05d-rac1-installed-running.png
```

## 7. Tao VM rac2

Lenh nay cung map theo cach cu da chay duoc.

Chay tu folder oracle_23c:

```bash
cd /home/tandat/Desktop/tandat_homelab/oracle_23c

virt-install \
  --name rac2 \
  --memory 6144 \
  --vcpus 2 \
  --disk path=/home/tandat/Desktop/tandat_homelab/oracle_rac/vm_disks/rac2-os.qcow2,size=50 \
  --cdrom OracleLinux-R9-U7-x86_64-boot-uek.iso \
  --osinfo ol9-unknown \
  --network network=default \
  --network network=rac-priv \
  --graphics spice &
```

Mo console:

```bash
virt-viewer --connect qemu:///system rac2
```

Neu terminal hien `Waiting for the installation to complete`, bam `Ctrl-C`, roi mo console bang lenh tren.

Trong installer Oracle Linux, lam tuong tu `rac1` nhung hostname la:

```text
rac2
```

Chup hinh:

```text
oracle_rac/screenshots/05e-rac2-oracle-linux-installer.png
oracle_rac/screenshots/05f-rac2-installed-running.png
```

## 8. Verify sau khi co 2 VM

Tren host:

```bash
virsh --connect qemu:///system list --all
virsh --connect qemu:///system domiflist rac1
virsh --connect qemu:///system domiflist rac2
```

Expected:

```text
rac1 running
rac2 running

Moi VM co 2 interface:
  network default
  network rac-priv
```

Chup hinh:

```text
oracle_rac/screenshots/05g-rac1-rac2-created.png
```

## 9. Khong lam gi voi shared disks trong Step nay

Chua attach cac file nay vao VM:

```text
oracle_rac/vm_disks/rac-ocr-vote.qcow2
oracle_rac/vm_disks/rac-data.qcow2
oracle_rac/vm_disks/rac-fra.qcow2
```

Ly do:

```text
OS install phai sach, chi thay OS disk 50G.
Shared disks danh cho ASM/Grid Infrastructure.
Attach shared disks sai option co the lam RAC/Grid gap loi sau nay.
```

Step tiep theo moi lam:

```text
Attach shared ASM disks vao ca rac1 va rac2.
Set static IP public/private trong guest.
Chuan bi /etc/hosts cho RAC.
```

## 10. Done criteria

Hoan thanh Step 03 khi:

```text
rac1 ton tai va boot duoc Oracle Linux 9
rac2 ton tai va boot duoc Oracle Linux 9
Moi VM co 2 NIC: default va rac-priv
Chua attach shared ASM disks
Co screenshot 05a den 05g
```
