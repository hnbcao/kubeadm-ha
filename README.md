## kubernetes v1.13.0高可用master集群部署（使用kubeadm）

本文基于[kubeadm HA master(v1.13.0)离线包 + 自动化脚本 + 常用插件 For Centos/Fedora](https://www.kubernetes.org.cn/4948.html)编写，修改了master之间的负载均衡方式为HAProxy+keeplived方式。

集群方案：

- 发行版：CentOS 7
- 容器运行时
- 内核： 4.19.6-300.fc29.x86_64
- 版本：Kubernetes: 1.13.0
- 网络方案: Calico
- kube-proxy mode: IPVS
- master高可用方案：HAProxy keepalived LVS
- DNS插件: CoreDNS
- metrics插件：metrics-server
- 界面：kubernetes-dashboard

### Kubernetes集群搭建

| Host Name | Role | IP |
| ------ | ------ | ------ |
| master1 | master1 | 192.168.0.148 |
| master2 | master2 | 192.168.0.147 |
| master3 | master3 | 192.168.0.146 |
| node1 | node1 | 192.168.0.151 |
| node2 | node2 | 192.168.0.150 |
| node3 | node3 | 192.168.0.149 |

1、安装前系统配置

* 关闭SELinux、防火墙

	```
	systemctl stop firewalld
	systemctl disable firewalld
	setenforce 0
	sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/	selinux/config
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
* 升级内核到最新
	
	[centos7 升级内核](https://www.aliyun.com/jiaocheng/130885.html)

* 重启系统，确认内核版本后，开启IPVS

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

**、 Kubernetes要求集群中所有机器具有不同的Mac地址、产品uuid、Hostname。

2、安装Docker
	
* 访问官网[Install Docker CE](https://docs.docker.com/install/linux/docker-ce/centos/#uninstall-old-versions),或者百度“安装Docker CE”。
* 导入Kubernetes镜像
	
	| REPOSITORY                              | TAG                 |
	| --------------------------------------- | ------------------- |
	| gcr.io/kubernetes-helm/tiller           | v2.12.0             |
	| k8s.gcr.io/kube-proxy                   | v1.13.0             |
	| k8s.gcr.io/kube-scheduler               | v1.13.0             |
	| k8s.gcr.io/kube-apiserver               | v1.13.0             |
	| k8s.gcr.io/kube-controller-manager      | v1.13.0             |
	| k8s.gcr.io/cloud-controller-manager     | v1.13.0             |
	| quay.io/calico/node                     | v3.3.2              |
	| quay.io/calico/cni                      | v3.3.2              |
	| quay.io/calico/typha                    | v3.3.2              |
	| k8s.gcr.io/addon-resizer                | 1.8.4               |
	| k8s.gcr.io/coredns                      | 1.2.6               |
	| k8s.gcr.io/etcd                         | 3.2.24              |
	| k8s.gcr.io/metrics-server-amd64         | v0.3.1              |
	| k8s.gcr.io/kubernetes-dashboard-amd64   | v1.10.0             |
	| k8s.gcr.io/pause                        | 3.1                 |
		
3、基本安装

* 首先下载链接：链接：https://pan.baidu.com/s/1t3EWAt4AET7JaIVIbz-zHQ 提取码：djnf ，并放置在k8s各个master和worker主机上
	
	```
	# 相比原文，此处多安装了一个haproxy，因为原文的HA方式我这边走不通，所以采用了HAProxy keepalived的解决方案
	yum install -y socat keepalived ipvsadm haproxy
	cd /path/to/downloaded/file
	tar -xzvf k8s-v1.13.0-rpms.tgz
	cd k8s-v1.13.0
	rpm -Uvh * --force
	systemctl enable kubelet
	kubeadm version -o short
	```
	
* 配置免密码登陆

	具体可查看原文，或者百度。

4、部署HA Master

HA Master的部署过程已经自动化，请在master-1上执行如下命令，并注意修改IP

```
# 部署HA master

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
 
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Lentil1016/kubeadm-ha/1.13.0/kubeha-gen.sh)"
# 该步骤将可能持续2到10分钟，在该脚本进行安装部署前，将有一次对安装信息进行检查确认的机会
```
部署完成之后Dashboard的端口为30000。

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
  
6、结束安装

文章只是在文章[kubeadm HA master(v1.13.0)离线包 + 自动化脚本 + 常用插件 For Centos/Fedora](https://www.kubernetes.org.cn/4948.html)的基础上，修改了master的HA方案。关于集群安装的详细步骤，建议访问[kubeadm HA master(v1.13.0)离线包 + 自动化脚本 + 常用插件 For Centos/Fedora](https://www.kubernetes.org.cn/4948.html)。
