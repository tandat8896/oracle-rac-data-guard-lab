ssh -p 2222 grid@rac1 hostname
ssh -p 2222 grid@rac2 hostname
ssh -p 2222 grid@rac1 hostname
exit
ls -la ~/.ssh
ssh-keygen -t rsa -b 4096
  sudo su - grid
exit
  ssh -p 2222 grid@rac1 hostname
  ssh -p 2222 grid@rac2 hostname
  cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
  chmod 700 ~/.ssh
  chmod 600 ~/.ssh/authorized_keys
  ssh -p 2222 grid@rac2 hostname
exit
ls -l /dev/asm-*
dd if=/dev/asm-ocrvote of=/dev/null bs=1M count=1
dd if=/dev/asm-data of=/dev/null bs=1M count=1
dd if=/dev/asm-fra of=/dev/null bs=1M count=1
exit
cd /u01/app/19.0.0/grid
sudo dnf install -y libnsl
exit
cd /u01/app/19.0.0/grid
exit
cd /u01/app/19.0.0/grid
ssh -p grid@rac2 hostname
ssh -p 2222 grid@rac2 hostname
exit
printf '%s\n' 'Host rac1' '  HostName rac1' '  Port 2222' '  User grid' '' 'Host rac2' '  HostName rac2' '  Port 2222' '  User grid' > ~/.ssh/config
chmod 600 ~/.ssh/config
ssh rac1 hostname
cd /u01/app/19.0.0/grid
chmod 600 ~/.ssh/config
exit
  cd /u01/app/19.0.0/grid
exit
  ssh rac1 hostname
  ssh -o BatchMode=yes rac1 hostname
exit
cd /u01/app/19.0.0/grid/
  CV_ASSUME_DISTID=OEL8 CV_DESTLOC=/home/grid/cvuwork CV_TRACELOC=/home/grid/cvutrace ./runcluvfy.sh stage -pre crsinst -n rac1,rac2
  sudo /u01/app/19.0.0/grid/root.sh
exit
echo 'export ORACLE_BASE=/u01/app/grid' >> ~/.bash_profile && echo 'export ORACLE_HOME=/u01/app/19.0.0/grid' >> ~/.bash_profile && echo 'export PATH=$ORACLE_HOME/bin:$PATH' >> ~/.bash_profile
source ~/.bash_profile
which crsctl
which asmcmd
echo $ORACLE_HOME
exit
ssh rac2 'ip addr show enp1s0 | grep "inet "; ip addr show enp2s0 | grep "inet "; ip route show'
df -h
exit
