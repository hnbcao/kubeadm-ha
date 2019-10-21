#/bin/bash

echo "============Prepare Docker Install !!!============"
yum install -y yum-utils device-mapper-persistent-data lvm2
echo "============Add Docker Yum Repo !!!============"
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
echo "============Install Docker !!!============"
yum install -y docker-ce-18.06.3.ce
echo "============Set Up Docker !!!============"
sed -i "13i ExecStartPost=/usr/sbin/iptables -P FORWARD ACCEPT" /usr/lib/systemd/system/docker.service
systemctl daemon-reload
echo "============Start Docker !!!============"
systemctl start docker
echo "============Set Docker Auto Start !!!============"
systemctl enable docker