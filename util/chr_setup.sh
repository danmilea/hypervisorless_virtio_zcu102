mknod -m 666 /dev/random c 1 8
mknod -m 666 /dev/urandom c 1 9
mkdir -p /var/volatile/log

echo "nameserver 8.8.8.8" > /etc/resolv.conf
#dnf cleanall
dnf repolist

dnf -y install tar less procps net-tools rsync

rm -rf /var/volatile/log
rm /etc/resolv.conf
