## kubernetes v1.14.0高可用master集群部署（使用kubeadm，离线安装）

本文基于[kubeadm HA master(v1.13.0)离线包 + 自动化脚本 + 常用插件 For Centos/Fedora](https://www.kubernetes.org.cn/4948.html)编写，修改了master之间的负载均衡方式为HAProxy+keeplived方式。

集群方案：

- 发行版：CentOS 7
- 容器运行时
- 内核： 4.18.12-1.el7.elrepo.x86_64
- 版本：Kubernetes: 1.14.0
- 网络方案: Calico
- kube-proxy mode: IPVS
- master高可用方案：HAProxy keepalived LVS
- DNS插件: CoreDNS
- metrics插件：metrics-server
- 界面：kubernetes-dashboard

### Kubernetes集群搭建

| Host Name | Role | IP |
| ------ | ------ | ------ |
| master1 | master1 | 192.168.56.103 |
| master2 | master2 | 192.168.56.104 |
| master3 | master3 | 192.168.56.105 |
| node1 | node1 | 192.168.56.106 |
| node2 | node2 | 192.168.56.107 |
| node3 | node3 | 192.168.56.108 |

1、离线安装包准备（基于能够访问外网的服务器下载相应安装包）

```
# 设置yum缓存路径，cachedir 缓存路径 keepcache=1保持安装包在软件安装之后不删除
cat /etc/yum.conf  
[main]
cachedir=/home/yum
keepcache=1
...

# 安装ifconfig
yum install net-tools -y

# 时间同步
yum install -y ntpdate

# 安装docker（建议19.8.06）
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager \
 --add-repo \
 https://download.docker.com/linux/centos/docker-ce.repo
yum makecache fast
## 列出Docker版本
yum list docker-ce --showduplicates | sort -r
## 安装指定版本
sudo yum install docker-ce-<VERSION_STRING>

# 安装文件管理器，XShell可通过rz sz命令上传或者下载服务器文件
yum intall lrzsz -y

# 安装keepalived、haproxy
yum install -y socat keepalived ipvsadm haproxy

# 安装kubernetes相关组件
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
yum install -y kubelet kubeadm kubectl ebtables

# 其他软件安装
yum install wget
...
```

2、节点系统配置

* 关闭SELinux、防火墙

	```
	systemctl stop firewalld
	systemctl disable firewalld
	setenforce 0
	sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
	```

* 关闭系统的Swap（Kubernetes 1.8开始要求）
	
	```
	swapoff -a
	yes | cp /etc/fstab /etc/fstab_bak
	cat /etc/fstab_bak |grep -v swap > /etc/fstab
	```
* 配置L2网桥在转发包时会被iptables的FORWARD规则所过滤，该配置被CNI插件需要，更多信息请参考[Network Plugin Requirements](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/#network-plugin-requirements)

	```
	echo """
	vm.swappiness = 0
	net.bridge.bridge-nf-call-ip6tables = 1
	net.bridge.bridge-nf-call-iptables = 1
	""" > /etc/sysctl.conf
	sysctl -p
	```
	[centos7添加bridge-nf-call-ip6tables出现No such file or directory](https://www.cnblogs.com/zejin2008/p/7102485.html),简单来说就是执行一下 modprobe br_netfilter

* 同步时间
	```
	ntpdate -u ntp.api.bz
	```

* 升级内核到最新（已准备内核离线安装包，可选）
	
	[centos7 升级内核](https://www.aliyun.com/jiaocheng/130885.html)

    [参考文章](https://www.kubernetes.org.cn/5163.html)
    ```
    grub2-set-default 0 && grub2-mkconfig -o /etc/grub2.cfg
    grubby --default-kernel
    grubby --args="user_namespace.enable=1" --update-kernel="$(grubby --default-kernel)"
    ```

* 重启系统，确认内核版本后，开启IPVS（如果未升级内核，去掉ip_vs_fo）

	```
	uname -a
	cat > /etc/sysconfig/modules/ipvs.modules <<EOF
	#!/bin/bash
	ipvs_modules="ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr 	ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_fo 	ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack"
	for kernel_module in \${ipvs_modules}; do
 	 	/sbin/modinfo -F filename \${kernel_module} > /dev/null 2>&1
 		if [ $? -eq 0 ]; then
	 		/sbin/modprobe \${kernel_module}
 		fi
	done
	EOF
	chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep ip_vs
	```
	
	执行sysctl -p报错可执行modprobe br_netfilter，请参考[centos7添加bridge-nf-call-ip6tables出现No such file or directory
](https://www.cnblogs.com/zejin2008/p/7102485.html)

* 所有机器需要设定/etc/sysctl.d/k8s.conf的系统参数
    ```
    # https://github.com/moby/moby/issues/31208 
    # ipvsadm -l --timout
    # 修复ipvs模式下长连接timeout问题 小于900即可
	cat <<EOF > /etc/sysctl.d/k8s.conf
	net.ipv4.tcp_keepalive_time = 600
	net.ipv4.tcp_keepalive_intvl = 30
	net.ipv4.tcp_keepalive_probes = 10
	net.ipv6.conf.all.disable_ipv6 = 1
	net.ipv6.conf.default.disable_ipv6 = 1
	net.ipv6.conf.lo.disable_ipv6 = 1
	net.ipv4.neigh.default.gc_stale_time = 120
	net.ipv4.conf.all.rp_filter = 0
	net.ipv4.conf.default.rp_filter = 0
	net.ipv4.conf.default.arp_announce = 2
	net.ipv4.conf.lo.arp_announce = 2
	net.ipv4.conf.all.arp_announce = 2
	net.ipv4.ip_forward = 1
	net.ipv4.tcp_max_tw_buckets = 5000
	net.ipv4.tcp_syncookies = 1
	net.ipv4.tcp_max_syn_backlog = 1024
	net.ipv4.tcp_synack_retries = 2
	net.bridge.bridge-nf-call-ip6tables = 1
	net.bridge.bridge-nf-call-iptables = 1
	net.netfilter.nf_conntrack_max = 2310720
	fs.inotify.max_user_watches=89100
	fs.may_detach_mounts = 1
	fs.file-max = 52706963
	fs.nr_open = 52706963
	net.bridge.bridge-nf-call-arptables = 1
	vm.swappiness = 0
	vm.overcommit_memory=1
	vm.panic_on_oom=0
	EOF
	sysctl --system
    ```

* 设置开机启动
    ```
    # 启动docker
	sed -i "13i ExecStartPost=/usr/sbin/iptables -P FORWARD ACCEPT" /usr/lib/systemd/system/docker.service
    systemctl daemon-reload
    systemctl enable docker
    systemctl start docker
    # 设置kubelet开机启动
    systemctl enable kubelet

    systemctl enable keepalived
    systemctl enable haproxy
    ```

* 设置免密登录
	```
	# 1、三次回车后，密钥生成完成
	ssh-keygen
	# 2、拷贝密钥到其他节点
	ssh-copy-id -i ~/.ssh/id_rsa.pub  用户名字@192.168.x.xxx
	```

**、 Kubernetes要求集群中所有机器具有不同的Mac地址、产品uuid、Hostname。

3、keepalived+haproxy配置

```
cd ~/
# 创建集群信息文件
echo """
CP0_IP=10.130.29.80
CP1_IP=10.130.29.81
CP2_IP=10.130.29.82
VIP=10.130.29.83
NET_IF=eth0
CIDR=10.244.0.0/16
""" > ./cluster-info
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hnbcao/kubeadm-ha-master/v1.14.0/keepalived-haproxy.sh)"
```


4、部署HA Master

HA Master的部署过程已经自动化，请在master-1上执行如下命令，并注意修改IP;

脚本主要执行三步：

1)、重置kubelet设置
```
kubeadm reset -f
rm -rf /etc/kubernetes/pki/
```

2)、编写节点配置文件并初始化master1的kubelet

```
echo """
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: v1.13.0
controlPlaneEndpoint: "${VIP}:8443"
maxPods: 100
networkPlugin: cni
imageRepository: registry.aliyuncs.com/google_containers
apiServer:
  certSANs:
  - ${CP0_IP}
  - ${CP1_IP}
  - ${CP2_IP}
  - ${VIP}
networking:
  # This CIDR is a Calico default. Substitute or remove for your CNI provider.
  podSubnet: ${CIDR}
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
""" > /etc/kubernetes/kubeadm-config.yaml
kubeadm init --config /etc/kubernetes/kubeadm-config.yaml
mkdir -p $HOME/.kube
cp -f /etc/kubernetes/admin.conf ${HOME}/.kube/config
```

* 关于默认网关问题，如果有多张网卡，需要先将默认网关切换到集群使用的那张网卡上，否则可能会出现etcd无法连接等问题。（应用我用的虚拟机，有一张网卡无法做到各个节点胡同；route查看当前网关信息，route del default删除默认网关，route add default enth0设置默认网关enth0为网卡名）

3)、拷贝相关证书到master2、master3
```
for index in 1 2; do
  ip=${IPS[${index}]}
  ssh $ip "mkdir -p /etc/kubernetes/pki/etcd; mkdir -p ~/.kube/"
  scp /etc/kubernetes/pki/ca.crt $ip:/etc/kubernetes/pki/ca.crt
  scp /etc/kubernetes/pki/ca.key $ip:/etc/kubernetes/pki/ca.key
  scp /etc/kubernetes/pki/sa.key $ip:/etc/kubernetes/pki/sa.key
  scp /etc/kubernetes/pki/sa.pub $ip:/etc/kubernetes/pki/sa.pub
  scp /etc/kubernetes/pki/front-proxy-ca.crt $ip:/etc/kubernetes/pki/front-proxy-ca.crt
  scp /etc/kubernetes/pki/front-proxy-ca.key $ip:/etc/kubernetes/pki/front-proxy-ca.key
  scp /etc/kubernetes/pki/etcd/ca.crt $ip:/etc/kubernetes/pki/etcd/ca.crt
  scp /etc/kubernetes/pki/etcd/ca.key $ip:/etc/kubernetes/pki/etcd/ca.key
  scp /etc/kubernetes/admin.conf $ip:/etc/kubernetes/admin.conf
  scp /etc/kubernetes/admin.conf $ip:~/.kube/config

  ssh ${ip} "${JOIN_CMD} --experimental-control-plane"
done
```

4)、master2、master3加入节点
```
JOIN_CMD=`kubeadm token create --print-join-command`
ssh ${ip} "${JOIN_CMD} --experimental-control-plane"
```

完整脚本：
```
# 部署HA master
 
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hnbcao/kubeadm-ha-master/v1.14.0/kube-ha.sh)"
```

5、加入节点

* 各个节点需要配置keepalived 和 haproxy

	```
	#/etc/haproxy/haproxy.cfg
	global
	    log         127.0.0.1 local2
	    chroot      /var/lib/haproxy
	    pidfile     /var/run/haproxy.pid
	    maxconn     4000
	    user        haproxy
	    group       haproxy
	    daemon
	    stats socket /var/lib/haproxy/stats
	
	defaults
	    mode                    tcp
	    log                     global
	    option                  tcplog
	    option                  dontlognull
	    option                  redispatch
	    retries                 3
	    timeout queue           1m
	    timeout connect         10s
	    timeout client          1m
	    timeout server          1m
	    timeout check           10s
	    maxconn                 3000
	
	listen stats
	    mode   http
	    bind :10086
	    stats   enable
	    stats   uri     /admin?stats
	    stats   auth    admin:admin
	    stats   admin   if TRUE
	    
	frontend  k8s_https *:8443
	    mode      tcp
	    maxconn      2000
	    default_backend     https_sri
	    
	backend https_sri
	    balance      roundrobin
	    server master1-api ${MASTER1_IP}:6443  check inter 10000 fall 2 rise 2 weight 1
	    server master2-api ${MASTER2_IP}:6443  check inter 10000 fall 2 rise 2 weight 1
	    server master3-api ${MASTER3_IP}:6443  check inter 10000 fall 2 rise 2 weight 1
	```
	
	```
	#/etc/keepalived/keepalived.conf 
	global_defs {
	   router_id LVS_DEVEL
	}
	
	vrrp_script check_haproxy {
	    script /etc/keepalived/check_haproxy.sh
	    interval 3
	}
	
	vrrp_instance VI_1 {
	    state MASTER
	    interface eth0
	    virtual_router_id 80
	    priority 100
	    advert_int 1
	    authentication {
	        auth_type PASS
	        auth_pass just0kk
	    }
	    virtual_ipaddress {
	        ${VIP}/24
	    }
	    track_script {   
	        check_haproxy
	    }
	}
	
	}
	```
注意两个配置中的${MASTER1 _ IP}, ${MASTER2 _ IP}, ${MASTER3 _ IP}、${VIP}需要替换为自己集群相应的IP地址

* 重启keepalived和haproxy

	```
	systemctl stop keepalived
    systemctl enable keepalived
    systemctl start keepalived
    systemctl stop haproxy
    systemctl enable haproxy
    systemctl start haproxy
	```
* 节点加入命令获取

	```
	#master节点执行该命令，再在节点执行获取到的命令
	kubeadm token create --print-join-command
	```
6、结束安装

文章只是在文章[kubeadm HA master(v1.13.0)离线包 + 自动化脚本 + 常用插件 For Centos/Fedora](https://www.kubernetes.org.cn/4948.html)的基础上，修改了master的HA方案。关于集群安装的详细步骤，建议访问[kubeadm HA master(v1.13.0)离线包 + 自动化脚本 + 常用插件 For Centos/Fedora](https://www.kubernetes.org.cn/4948.html)。
