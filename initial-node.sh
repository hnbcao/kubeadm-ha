#/bin/bash
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/hnbcao/kubeadm-ha/master/initial-node.sh)"
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
        http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

yum install -y yum-utils device-mapper-persistent-data lvm2

if [ -z "`yum list installed | grep docker`" ] ;then
    echo "============This System Have Being Install Docker !!!============"
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && 
    yum install -y docker-ce-18.06.3.ce
else
    echo "============This System Have Install Docker !!!============"
    if [ -z "`docker version | grep 18.06.3`" ] ;then
        yum remove docker  docker-common docker-selinux docker-engine && 
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && 
        yum install -y docker-ce-18.06.3.ce
    fi
fi

yum install -y socat ipvsadm kubelet-1.16.2 kubeadm-1.16.2 kubectl-1.16.2

systemctl stop firewalld
systemctl disable firewalld
setenforce 0
sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config

swapoff -a
yes | cp /etc/fstab /etc/fstab_bak
cat /etc/fstab_bak |grep -v swap > /etc/fstab

echo """
vm.swappiness = 0
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
""" > /etc/sysctl.conf
modprobe br_netfilter
sysctl -p

uname -a
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
ipvs_modules="ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack"
for kernel_module in \${ipvs_modules}; do
 /sbin/modinfo -F filename \${kernel_module} > /dev/null 2>&1
 if [ $? -eq 0 ]; then
 /sbin/modprobe \${kernel_module}
 fi
done
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep ip_vs

sed -i "13i ExecStartPost=/usr/sbin/iptables -P FORWARD ACCEPT" /usr/lib/systemd/system/docker.service
systemctl daemon-reload
systemctl enable docker
systemctl start docker
# 设置kubelet开机启动
systemctl enable kubelet