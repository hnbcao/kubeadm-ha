#/bin/bash
if [ -z "`yum list installed | grep docker`" ] ;then
    echo "============This System Have Not Install Docker !!!============"
else
    echo "============This System Have Install Docker !!!============"
    exit 10
fi
echo "============Prepare Docker Install !!!============"
yum install -y yum-utils device-mapper-persistent-data lvm2
echo "============Add Docker Yum Repo !!!============"
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
echo "============Install Docker !!!============"
yum install -y docker-ce-18.06.3.ce
echo "============Set Up Docker !!!============"
if [ -z "`grep "ExecStartPost=/usr/sbin/iptables -P FORWARD ACCEPT" /usr/lib/systemd/system/docker.service`" ] ;then
    echo "============Skip Set Up Docker !!!============"
    cat /usr/lib/systemd/system/docker.service
else
    sed -i "13i ExecStartPost=/usr/sbin/iptables -P FORWARD ACCEPT" /usr/lib/systemd/system/docker.service
    cat /usr/lib/systemd/system/docker.service
fi
systemctl daemon-reload
echo "============Start Docker !!!============"
systemctl start docker
echo "============Set Docker Auto Start !!!============"
systemctl enable docker