hostnamectl set-hostname rac2
exit
usermod -aG wheel tandat8896
vi /etc/ssh/sshd_config
vi /etc/ssh/sshd_config/99-hardening.conf
vi /etc/ssh/sshd_config.d/99-hardening.conf
cat > /etc/ssh/sshd_config.d/99-hardening.conf << 'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
EOF

cat /etc/ssh/sshd_config.d/99-hardening.conf 
systemctl restart sshd
cp -r /root/.ssh /home/tandat8896/.ssh
chown -R tandat8896:tandat8896 /home/tandat8896/.ssh
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config.d/99-hardening.conf
systemctl restart sshd
vi /etc/ssh/sshd_config.d/99-hardening.conf 
vi /etc/ssh/sshd_config.d/01-permitrootlogin.conf 
systemctl restart sshd
vi /etc/ssh/sshd_config.d/99-hardening.conf 
systemctl restart sshd
dnf install -y policycoreutils-python-utils
semanage port -a -t ssh_port_t -p tcp 2222 || semanage port -m -t ssh_port_t -p tcp 2222
systemctl restart sshd
firewall-cmd --permanent --add-port=2222/tcp && firewall-cmd --reload
exit
