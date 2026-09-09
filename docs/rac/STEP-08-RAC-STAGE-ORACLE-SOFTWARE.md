# Step 08 - Stage Oracle Grid and Database software

Muc tieu: dua Oracle Grid Infrastructure 19c va Oracle Database 19c software vao 2 VM `rac1` va `rac2`.

Host NixOS hien co:

```text
oracle_rac/downloads/V982063-01.zip  Oracle Database 19.3
oracle_rac/downloads/V982068-01.zip  Oracle Grid Infrastructure 19.3

oracle_rac/stage/db_home             da unzip DB home
oracle_rac/stage/grid_home           da unzip Grid home
```

Trong VM:

```text
Grid home: /u01/app/19.0.0/grid
DB home:   /u01/app/oracle/product/19.0.0/dbhome_1
```

User ownership:

```text
Grid home -> grid:oinstall
DB home   -> oracle:oinstall
```

## Important: dang o user nao thi co can exit khong?

Co. Neu dang o `grid` hoac `oracle` ma buoc tiep theo yeu cau `sudo`, hay copy file bang user `tandat8896`, thi thoat ra:

```bash
exit
```

`exit` khong pha gi het.

No chi thoat khoi shell user hien tai:

```text
grid/oracle -> tandat8896
tandat8896 -> dong SSH session
```

Quy tac trong Step nay:

```text
Host NixOS: chay scp/rsync tu may that.
rac1/rac2 user tandat8896: tao staging folder, sudo chown/copy vao /u01.
grid: chi verify Grid home sau khi owner da set.
oracle: chi verify DB home sau khi owner da set.
```

## 1. Precheck tren host NixOS

Chay tren host NixOS, repo root:

```bash
cd /home/tandat/Desktop/tandat_homelab
```

Check stage software:

```bash
ls -lh oracle_rac/downloads
ls -ld oracle_rac/stage/grid_home oracle_rac/stage/db_home
ls -l oracle_rac/stage/grid_home/gridSetup.sh
ls -l oracle_rac/stage/db_home/runInstaller
```

Expected:

```text
V982063-01.zip ton tai
V982068-01.zip ton tai
grid_home/gridSetup.sh ton tai
db_home/runInstaller ton tai
```

Chup hinh:

```text
oracle_rac/screenshots/10a-host-oracle-software-stage-ready.png
```

## 2. Tao temporary stage folder tren rac1/rac2

Chay tren host NixOS:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.205 'mkdir -p /tmp/oracle_stage/grid_home /tmp/oracle_stage/db_home'
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.46 'mkdir -p /tmp/oracle_stage/grid_home /tmp/oracle_stage/db_home'
```

Verify:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.205 'ls -ld /tmp/oracle_stage /tmp/oracle_stage/grid_home /tmp/oracle_stage/db_home'
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.46 'ls -ld /tmp/oracle_stage /tmp/oracle_stage/grid_home /tmp/oracle_stage/db_home'
```

## 3. Copy Grid home sang rac1/rac2

Dung `rsync` neu host co `rsync`:

```bash
rsync -a --info=progress2 -e "ssh -i ~/.ssh/rac_ed25519 -p 2222" \
  oracle_rac/stage/grid_home/ \
  tandat8896@192.168.122.205:/tmp/oracle_stage/grid_home/

rsync -a --info=progress2 -e "ssh -i ~/.ssh/rac_ed25519 -p 2222" \
  oracle_rac/stage/grid_home/ \
  tandat8896@192.168.122.46:/tmp/oracle_stage/grid_home/
```

Neu `rsync` khong co, dung `scp -r`:

```bash
scp -i ~/.ssh/rac_ed25519 -P 2222 -r oracle_rac/stage/grid_home/. tandat8896@192.168.122.205:/tmp/oracle_stage/grid_home/
scp -i ~/.ssh/rac_ed25519 -P 2222 -r oracle_rac/stage/grid_home/. tandat8896@192.168.122.46:/tmp/oracle_stage/grid_home/
```

Chup hinh:

```text
oracle_rac/screenshots/10b-grid-home-copied-to-vms.png
```

## 4. Copy DB home sang rac1/rac2

Dung `rsync` neu host co `rsync`:

```bash
rsync -a --info=progress2 -e "ssh -i ~/.ssh/rac_ed25519 -p 2222" \
  oracle_rac/stage/db_home/ \
  tandat8896@192.168.122.205:/tmp/oracle_stage/db_home/

rsync -a --info=progress2 -e "ssh -i ~/.ssh/rac_ed25519 -p 2222" \
  oracle_rac/stage/db_home/ \
  tandat8896@192.168.122.46:/tmp/oracle_stage/db_home/
```

Neu `rsync` khong co, dung `scp -r`:

```bash
scp -i ~/.ssh/rac_ed25519 -P 2222 -r oracle_rac/stage/db_home/. tandat8896@192.168.122.205:/tmp/oracle_stage/db_home/
scp -i ~/.ssh/rac_ed25519 -P 2222 -r oracle_rac/stage/db_home/. tandat8896@192.168.122.46:/tmp/oracle_stage/db_home/
```

Chup hinh:

```text
oracle_rac/screenshots/10c-db-home-copied-to-vms.png
```

## 5. Move Grid home vao /u01 tren rac1

Dang nhap `rac1` bang `tandat8896`:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.205
```

Neu dang o `grid`/`oracle`, chay:

```bash
exit
```

Chay tren `rac1` user `tandat8896`:

```bash
sudo rsync -a /tmp/oracle_stage/grid_home/ /u01/app/19.0.0/grid/
sudo chown -R grid:oinstall /u01/app/19.0.0/grid
sudo chmod -R 775 /u01/app/19.0.0/grid
```

Neu VM khong co `rsync`, dung `cp -a`:

```bash
sudo cp -a /tmp/oracle_stage/grid_home/. /u01/app/19.0.0/grid/
sudo chown -R grid:oinstall /u01/app/19.0.0/grid
sudo chmod -R 775 /u01/app/19.0.0/grid
```

Verify:

```bash
ls -l /u01/app/19.0.0/grid/gridSetup.sh
sudo -u grid test -x /u01/app/19.0.0/grid/gridSetup.sh && echo GRID_SETUP_EXEC_OK
```

## 6. Move DB home vao /u01 tren rac1

Chay tren `rac1` user `tandat8896`:

```bash
sudo rsync -a /tmp/oracle_stage/db_home/ /u01/app/oracle/product/19.0.0/dbhome_1/
sudo chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1
sudo chmod -R 775 /u01/app/oracle/product/19.0.0/dbhome_1
```

Neu VM khong co `rsync`, dung `cp -a`:

```bash
sudo cp -a /tmp/oracle_stage/db_home/. /u01/app/oracle/product/19.0.0/dbhome_1/
sudo chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1
sudo chmod -R 775 /u01/app/oracle/product/19.0.0/dbhome_1
```

Verify:

```bash
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/runInstaller
sudo -u oracle test -x /u01/app/oracle/product/19.0.0/dbhome_1/runInstaller && echo DB_INSTALLER_EXEC_OK
```

Chup hinh:

```text
oracle_rac/screenshots/10d-rac1-oracle-homes-ready.png
```

## 7. Move Grid/DB home vao /u01 tren rac2

Dang nhap `rac2` bang `tandat8896`:

```bash
ssh -i ~/.ssh/rac_ed25519 -p 2222 tandat8896@192.168.122.46
```

Neu dang o `grid`/`oracle`, chay:

```bash
exit
```

Chay tren `rac2` user `tandat8896`:

```bash
sudo rsync -a /tmp/oracle_stage/grid_home/ /u01/app/19.0.0/grid/
sudo chown -R grid:oinstall /u01/app/19.0.0/grid
sudo chmod -R 775 /u01/app/19.0.0/grid

sudo rsync -a /tmp/oracle_stage/db_home/ /u01/app/oracle/product/19.0.0/dbhome_1/
sudo chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1
sudo chmod -R 775 /u01/app/oracle/product/19.0.0/dbhome_1
```

Neu VM khong co `rsync`, dung:

```bash
sudo cp -a /tmp/oracle_stage/grid_home/. /u01/app/19.0.0/grid/
sudo chown -R grid:oinstall /u01/app/19.0.0/grid
sudo chmod -R 775 /u01/app/19.0.0/grid

sudo cp -a /tmp/oracle_stage/db_home/. /u01/app/oracle/product/19.0.0/dbhome_1/
sudo chown -R oracle:oinstall /u01/app/oracle/product/19.0.0/dbhome_1
sudo chmod -R 775 /u01/app/oracle/product/19.0.0/dbhome_1
```

Verify:

```bash
ls -l /u01/app/19.0.0/grid/gridSetup.sh
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/runInstaller
sudo -u grid test -x /u01/app/19.0.0/grid/gridSetup.sh && echo GRID_SETUP_EXEC_OK
sudo -u oracle test -x /u01/app/oracle/product/19.0.0/dbhome_1/runInstaller && echo DB_INSTALLER_EXEC_OK
```

Chup hinh:

```text
oracle_rac/screenshots/10e-rac2-oracle-homes-ready.png
```

## 8. Final verify tren ca hai node

Chay tren `rac1` va `rac2`:

```bash
du -sh /u01/app/19.0.0/grid
du -sh /u01/app/oracle/product/19.0.0/dbhome_1
ls -ld /u01/app/19.0.0/grid /u01/app/oracle/product/19.0.0/dbhome_1
ls -l /u01/app/19.0.0/grid/gridSetup.sh
ls -l /u01/app/oracle/product/19.0.0/dbhome_1/runInstaller
```

Expected:

```text
Grid home owner grid:oinstall
DB home owner oracle:oinstall
gridSetup.sh executable
runInstaller executable
```

## 9. Cleanup optional

Chi cleanup sau khi verify `/u01` OK.

Co the giu `/tmp/oracle_stage` cho den khi Grid installer xong.

Neu can reclaim disk sau nay:

```bash
rm -rf /tmp/oracle_stage
```

Khong xoa tren host:

```text
oracle_rac/downloads
oracle_rac/stage
```

## 10. Done criteria

Hoan thanh Step 08 khi:

```text
rac1 co Grid home tai /u01/app/19.0.0/grid
rac1 co DB home tai /u01/app/oracle/product/19.0.0/dbhome_1
rac2 co Grid home tai /u01/app/19.0.0/grid
rac2 co DB home tai /u01/app/oracle/product/19.0.0/dbhome_1
Owner dung: grid:oinstall va oracle:oinstall
Installer executable OK
Chua chay Grid installer
```

