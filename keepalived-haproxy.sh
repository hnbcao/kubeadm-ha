#/bin/bash

function check_parm()
{
  if [ "${2}" == "" ]; then
    echo -n "${1}"
    return 1
  else
    return 0
  fi
}

if [ -f ./cluster-info ]; then
	source ./cluster-info 
fi

check_parm "Enter the IP address of master-01: " ${CP0_IP} 
if [ $? -eq 1 ]; then
	read CP0_IP
fi
check_parm "Enter the IP address of master-02: " ${CP1_IP}
if [ $? -eq 1 ]; then
	read CP1_IP
fi
check_parm "Enter the IP address of master-03: " ${CP2_IP}
if [ $? -eq 1 ]; then
	read CP2_IP
fi
check_parm "Enter the VIP: " ${VIP}
if [ $? -eq 1 ]; then
	read VIP
fi
check_parm "Enter the Net Interface: " ${NET_IF}
if [ $? -eq 1 ]; then
	read NET_IF
fi
check_parm "Enter the cluster CIDR: " ${CIDR}
if [ $? -eq 1 ]; then
	read CIDR
fi

echo """
cluster-info:
  master-01:        ${CP0_IP}
  master-02:        ${CP1_IP}
  master-02:        ${CP2_IP}
  VIP:              ${VIP}
  Net Interface:    ${NET_IF}
  CIDR:             ${CIDR}
"""
echo -n 'Please print "yes" to continue or "no" to cancel: '
read AGREE
while [ "${AGREE}" != "yes" ]; do
	if [ "${AGREE}" == "no" ]; then
		exit 0;
	else
		echo -n 'Please print "yes" to continue or "no" to cancel: '
		read AGREE
	fi
done

mkdir -p ~/ikube/tls

echo "============Keepalived+Haproxy Configuration Begin============"

IPS=(${CP0_IP} ${CP1_IP} ${CP2_IP})

echo ">>>>>>>>>Haproxy Configuration>>>>>>>>>"
echo """
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
    server master1-api ${CP0_IP}:6443  check inter 10000 fall 2 rise 2 weight 1
    server master2-api ${CP1_IP}:6443  check inter 10000 fall 2 rise 2 weight 1
    server master3-api ${CP2_IP}:6443  check inter 10000 fall 2 rise 2 weight 1
""" > ~/ikube/haproxy.cfg

PRIORITY=(100 50 30)
STATE=("MASTER" "BACKUP" "BACKUP")
# HEALTH_CHECK=""
# for index in 0 1 2; do
#   HEALTH_CHECK=${HEALTH_CHECK}"""
#     real_server ${IPS[$index]} 6443 {
#         weight 1
#         SSL_GET {
#             url {
#               path /healthz
#               status_code 200
#             }
#             connect_timeout 3
#             nb_get_retry 3
#             delay_before_retry 3
#         }
#     }
#   """
# done

echo ">>>>>>>>>Keepalived Configuration>>>>>>>>>"

for index in 0 1 2; do
  ip=${IPS[${index}]}
  echo """
global_defs {
   router_id LVS_DEVEL
}

vrrp_script check_haproxy {
    script "/etc/keepalived/check_haproxy.sh"
    interval 3000
}

vrrp_instance VI_1 {
    state ${STATE[${index}]}
    interface ${NET_IF}
    virtual_router_id 80
    priority ${PRIORITY[${index}]}
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass just0kk
    }
    virtual_ipaddress {
        ${VIP}/24
    }
    track_script {   

    }
}

}
""" > ~/ikube/keepalived-${index}.conf
  scp ~/ikube/keepalived-${index}.conf ${ip}:/etc/keepalived/keepalived.conf
  scp ~/ikube/haproxy.cfg ${ip}:/etc/haproxy/haproxy.cfg
  ssh ${ip} "
    systemctl enable keepalived
    systemctl enable haproxy
    systemctl stop keepalived
    systemctl start keepalived
    systemctl stop haproxy
    systemctl start haproxy"
done
echo "============Keepalived+Haproxy Configuration End============"