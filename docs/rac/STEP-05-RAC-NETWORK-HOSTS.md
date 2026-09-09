# Step 05 - Configure RAC network identity and /etc/hosts

Muc tieu: dat network identity co dinh cho 2 node RAC truoc khi cai Grid Infrastructure.

Step nay lam tren:

```text
rac1
rac2
```

RAC can cac loai IP/name:

```text
public IP:  client/SSH/listener traffic
private IP: interconnect giua 2 node
VIP:        Virtual IP cho client failover
SCAN:       Single Client Access Name
```

Trong lab nay dung `/etc/hosts`, khong dung DNS rieng.

## 1. IP plan

Public network dung libvirt `default`:

```text
Network: 192.168.122.0/24
Gateway: 192.168.122.1
```

Private network dung libvirt `rac-priv`:

```text
Network: 10.10.10.0/24
Host bridge: 10.10.10.1
```

Plan cho lab:

```text
rac1 public      192.168.122.205   rac1
rac2 public      192.168.122.46    rac2

rac1 private     10.10.10.11       rac1-priv
rac2 private     10.10.10.12       rac2-priv

rac1 VIP         192.168.122.211   rac1-vip
rac2 VIP         192.168.122.212   rac2-vip

SCAN             192.168.122.213   rac-scan
```

Luu y:

```text
Public IP hien tai dang lay DHCP tu libvirt.
Trong lab co the tiep tuc dung IP hien tai neu khong reboot/lease doi.
Neu muon chac hon, step sau co the pin static public IP.
Private IP bat buoc set static vi RAC interconnect khong nen doi.
```

## 2. Precheck tren host

Chay tren host:

```bash
virsh --connect qemu:///system domifaddr rac1
virsh --connect qemu:///system domifaddr rac2
virsh --connect qemu:///system domiflist rac1
virsh --connect qemu:///system domiflist rac2
```

Expected public IP hien tai:

```text
rac1 192.168.122.205
rac2 192.168.122.46
```

Ket qua hien tai da ghi nhan:

```text
rac1 public:
  IP  192.168.122.205/24
  MAC 52:54:00:21:ae:93
  host iface vnet62
  libvirt source default

rac1 private:
  MAC 52:54:00:e0:66:5f
  host iface vnet63
  libvirt source rac-priv

rac2 public:
  IP  192.168.122.46/24
  MAC 52:54:00:d6:14:04
  host iface vnet64
  libvirt source default

rac2 private:
  MAC 52:54:00:8e:b1:f3
  host iface vnet65
  libvirt source rac-priv
```

Dung MAC de map interface trong guest:

```text
rac1:
  52:54:00:21:ae:93 = public
  52:54:00:e0:66:5f = private

rac2:
  52:54:00:d6:14:04 = public
  52:54:00:8e:b1:f3 = private
```

Chup hinh:

```text
oracle_rac/screenshots/07a-host-rac-public-ip-check.png
```

## 3. Login rac1 va rac2

Tu host:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.205
```

Tab khac:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.46
```

Cac lenh con lai chay trong tung VM.

## 4. Check interface names

Tren ca `rac1` va `rac2`:

```bash
ip -br addr
nmcli device status
nmcli connection show
```

Can xac dinh:

```text
NIC public  -> interface co IP 192.168.122.x
NIC private -> interface chua co IP hoac nam tren network rac-priv
```

Thuong co the la:

```text
enp1s0 public
enp2s0 private
```

Ket qua hien tai trong guest:

```text
rac1:
  enp1s0 UP 192.168.122.205/24
  enp2s0 UP IPv6 link-local only

rac2:
  enp1s0 UP 192.168.122.46/24
  enp2s0 UP IPv6 link-local only
```

Ket luan:

```text
rac1 enp1s0 = public
rac1 enp2s0 = private

rac2 enp1s0 = public
rac2 enp2s0 = private
```

`nmcli connection show` hien co connection cung ten interface:

```text
rac1: enp1s0, enp2s0
rac2: enp1s0, enp2s0
```

Chup hinh:

```text
oracle_rac/screenshots/07b-rac-interface-names.png
```

## 5. Set private IP tren rac1

Tren `rac1`, private interface hien tai la `enp2s0`.

Vi `nmcli connection show` da co connection `enp2s0`, dung `modify`, khong dung `connection add`.

```bash
sudo nmcli connection modify enp2s0 ipv4.method manual ipv4.addresses 10.10.10.11/24 ipv6.method disabled
sudo nmcli connection up enp2s0
```

Verify:

```bash
ip -br addr
ping -c 3 10.10.10.1
```

Expected:

```text
enp2s0 co 10.10.10.11/24
ping 10.10.10.1 OK
```

Ket qua hien tai tren `rac1`:

```text
enp1s0 UP 192.168.122.205/24
enp2s0 UP 10.10.10.11/24
ping 10.10.10.1: 3/3 received, 0% packet loss
```

## 6. Set private IP tren rac2

Tren `rac2`, private interface hien tai la `enp2s0`.

Vi `nmcli connection show` da co connection `enp2s0`, dung `modify`, khong dung `connection add`.

```bash
sudo nmcli connection modify enp2s0 ipv4.method manual ipv4.addresses 10.10.10.12/24 ipv6.method disabled
sudo nmcli connection up enp2s0
```

Verify:

```bash
ip -br addr
ping -c 3 10.10.10.1
ping -c 3 10.10.10.11
```

Expected:

```text
enp2s0 co 10.10.10.12/24
rac2 ping rac1 private OK
```

Ket qua hien tai tren `rac2`:

```text
enp1s0 UP 192.168.122.46/24
enp2s0 UP 10.10.10.12/24
ping 10.10.10.1: 3/3 received, 0% packet loss
ping 10.10.10.11: 3/3 received, 0% packet loss
```

Chup hinh:

```text
oracle_rac/screenshots/07c-private-ip-configured.png
```

## 7. Update /etc/hosts tren rac1

Backup truoc:

```bash
sudo cp /etc/hosts /etc/hosts.bak.step05
```

Mo file:

```bash
sudo vi /etc/hosts
```

Dam bao co noi dung RAC nay:

```text
# RAC public
192.168.122.205 rac1.localdomain rac1
192.168.122.46  rac2.localdomain rac2

# RAC private interconnect
10.10.10.11 rac1-priv.localdomain rac1-priv
10.10.10.12 rac2-priv.localdomain rac2-priv

# RAC VIP
192.168.122.211 rac1-vip.localdomain rac1-vip
192.168.122.212 rac2-vip.localdomain rac2-vip

# RAC SCAN
192.168.122.213 rac-scan.localdomain rac-scan
```

Khong xoa dong localhost mac dinh:

```text
127.0.0.1 localhost ...
::1       localhost ...
```

Verify tren `rac1`:

```bash
cat /etc/hosts
getent hosts rac1 rac2 rac1-priv rac2-priv rac1-vip rac2-vip rac-scan
getent ahostsv4 rac1 rac2 rac1-priv rac2-priv rac1-vip rac2-vip rac-scan
```

Ket qua hien tai tren `rac1`:

```text
hostname: rac1
hostname -f: rac1
getent ahostsv4 rac1 -> 192.168.122.205
```

Sau khi them FQDN alias, `getent ahostsv4` tren `rac1` da resolve dung IPv4:

```text
rac1 / rac1.localdomain        -> 192.168.122.205
rac2 / rac2.localdomain        -> 192.168.122.46
rac1-priv                      -> 10.10.10.11
rac2-priv                      -> 10.10.10.12
rac1-vip                       -> 192.168.122.211
rac2-vip                       -> 192.168.122.212
rac-scan                       -> 192.168.122.213
```

Ghi chu:

```text
getent hosts rac1 co the uu tien IPv6/link-local tren node hien tai.
Voi RAC/Grid, check IPv4 bang getent ahostsv4 la quan trong hon.
Nen them FQDN alias .localdomain de Oracle installer nhin sach hon.
```

## 8. Copy /etc/hosts sang rac2

Tu `rac1`, copy sang `rac2`:

```bash
scp -i ~/.ssh/rac_ed25519 -P 2222 /etc/hosts tandat8896@192.168.122.46:/tmp/hosts.rac
```

Tren `rac2`:

```bash
sudo cp /etc/hosts /etc/hosts.bak.step05
sudo cp /tmp/hosts.rac /etc/hosts
```

Verify tren `rac2`:

```bash
cat /etc/hosts
getent hosts rac1 rac2 rac1-priv rac2-priv rac1-vip rac2-vip rac-scan
getent ahostsv4 rac1 rac1.localdomain rac2 rac2.localdomain rac1-priv rac2-priv rac1-vip rac2-vip rac-scan
```

Ket qua hien tai tren `rac2` sau khi copy `/tmp/hosts.rac` vao `/etc/hosts`:

```text
rac1 / rac1.localdomain        -> 192.168.122.205
rac2 / rac2.localdomain        -> 192.168.122.46
rac1-priv                      -> 10.10.10.11
rac2-priv                      -> 10.10.10.12
rac1-vip                       -> 192.168.122.211
rac2-vip                       -> 192.168.122.212
rac-scan                       -> 192.168.122.213
```

Chup hinh:

```text
oracle_rac/screenshots/07d-hosts-file-configured.png
```

## 9. Connectivity test

Tren `rac1`:

```bash
ping -c 3 rac2
ping -c 3 rac2-priv
getent hosts rac-scan
```

Tren `rac2`:

```bash
ping -c 3 rac1
ping -c 3 rac1-priv
getent hosts rac-scan
```

Expected:

```text
public ping OK
private ping OK
rac-scan resolve ra 192.168.122.213
```

Ket qua hien tai:

```text
Tren rac1:
  ping rac2      -> 3/3 received, 0% packet loss
  ping rac2-priv -> 3/3 received, 0% packet loss
  rac-scan       -> 192.168.122.213

Tren rac2:
  ping rac1      -> 3/3 received, 0% packet loss
  ping rac1-priv -> 3/3 received, 0% packet loss
  rac-scan       -> 192.168.122.213
```

Luu y:

```text
VIP va SCAN IP chua ping duoc la binh thuong neu Grid chua start VIP/SCAN resource.
Luc nay chi can name resolve duoc.
```

Chup hinh:

```text
oracle_rac/screenshots/07e-rac-name-connectivity-test.png
```

## 10. Done criteria

Hoan thanh Step 05 khi:

```text
rac1 co private IP 10.10.10.11
rac2 co private IP 10.10.10.12
/etc/hosts tren ca hai node co public/private/VIP/SCAN
rac1 ping duoc rac2 va rac2-priv
rac2 ping duoc rac1 va rac1-priv
rac-scan resolve duoc tren ca hai node
Chua cai Grid Infrastructure
```
