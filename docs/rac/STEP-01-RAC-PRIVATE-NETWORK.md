# Step 01 - Create RAC private network

Muc tieu: tao libvirt network rieng cho RAC private interconnect.

Network nay chi dung cho `rac1` va `rac2` noi chuyen private/interconnect.
Khong dung network nay cho internet/client traffic.

## 1. Chuan bi folder

Chay tu repo root:

```bash
cd /home/tandat/Desktop/tandat_homelab
mkdir -p oracle_rac/libvirt
mkdir -p oracle_rac/screenshots
```

## 2. Tao file XML bang tay

Tao file:

```text
/home/tandat/Desktop/tandat_homelab/oracle_rac/libvirt/rac-priv.xml
```

Dan noi dung nay vao file:

```xml
<network>
  <name>rac-priv</name>
  <bridge name='virbr-racpriv' stp='on' delay='0'/>
  <ip address='10.10.10.1' netmask='255.255.255.0'/>
</network>
```

Y nghia:

```text
name: rac-priv
bridge: virbr-racpriv
IP host bridge: 10.10.10.1/24
Khong co <forward>, nen day la isolated private network.
Khong co DHCP, vi RAC private IP se set static trong guest.
```

IP du kien trong guest:

```text
rac1-priv 10.10.10.11
rac2-priv 10.10.10.12
```

## 3. Review file truoc khi apply

```bash
cat oracle_rac/libvirt/rac-priv.xml
```

Chup hinh:

```text
oracle_rac/screenshots/03a-rac-private-network-xml.png
```

## 4. Precheck libvirt networks

```bash
virsh --connect qemu:///system net-list --all
```

Chup hinh:

```text
oracle_rac/screenshots/03b-before-net-define.png
```

## 5. Define/start/autostart network

```bash
sudo virsh --connect qemu:///system net-define oracle_rac/libvirt/rac-priv.xml
sudo virsh --connect qemu:///system net-start rac-priv
sudo virsh --connect qemu:///system net-autostart rac-priv
```

## 6. Verify

```bash
virsh --connect qemu:///system net-list --all
virsh --connect qemu:///system net-dumpxml rac-priv
ip addr show virbr-racpriv
```

Expected:

```text
rac-priv active yes yes
bridge name='virbr-racpriv'
ip address='10.10.10.1'
```

Chup hinh:

```text
oracle_rac/screenshots/03c-rac-private-network-created.png
```

## 7. Rollback neu tao sai

Chi chay rollback neu can xoa network `rac-priv`:

```bash
sudo virsh --connect qemu:///system net-destroy rac-priv
sudo virsh --connect qemu:///system net-undefine rac-priv
```

Verify rollback:

```bash
virsh --connect qemu:///system net-list --all
```
