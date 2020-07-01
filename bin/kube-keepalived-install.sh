#!/bin/bash
echo ">>>>>> 正在部署KeepLived + Haproxy <<<<<<"
source ./conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "yum install -y keepalived* haproxy*"
  done

source ./conf/environment.conf
cat > ./work/keepalived.conf <<EOF
! Configuration File for keepalived
global_defs {
   router_id 192.168.0.50
}
vrrp_script check_haproxy {
    script "/etc/keepalived/check_haproxy.sh"
    interval 3
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 251
    priority 100
    advert_int 1
    mcast_src_ip 192.168.0.50
    nopreempt
    authentication {
        auth_type PASS
        auth_pass 11111111
    }
    track_script {
         check_haproxy
    }
    virtual_ipaddress {
        $KUBE_APISERVER_VIP
    }
}
EOF


source ./conf/environment.conf
echo "正在修改haproxy的配置"
cat > ./work/haproxy.cfg << EOF
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     6000
    user        haproxy
    group       haproxy
    daemon
    stats socket /var/lib/haproxy/stats
#---------------------------------------------------------------------
defaults
    mode                    tcp
    log                     global
    option                  tcplog
    option                  dontlognull
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000
#---------------------------------------------------------------------
frontend  k8s-api
   bind *:8443
   mode tcp
   default_backend             apiserver
#---------------------------------------------------------------------
backend apiserver
    balance     roundrobin
    mode tcp
    server  k8s-master1 $K8S_M1:6443 check weight 1 maxconn 2000 check inter 2000 rise 2 fall 3
    server  k8s-master2 $K8S_M2:6443 check weight 1 maxconn 2000 check inter 2000 rise 2 fall 3
    server  k8s-master3 $K8S_M3:6443 check weight 1 maxconn 2000 check inter 2000 rise 2 fall 3
EOF

echo "正在修改keepalived + Haproxy配置"
source ./conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp -r ./work/keepalived.conf root@${node_ip}:/etc/keepalived/keepalived.conf
    scp -r ./work/haproxy.cfg root@${node_ip}:/etc/haproxy/haproxy.cfg
    scp -r ./bin/check_haproxy.sh  root@${node_ip}:/etc/keepalived/
    ssh root@${node_ip} "chmod +x /etc/keepalived/check_haproxy.sh"
    ssh root@${node_ip} "sed -i 's#192.168.0.50#${node_ip}#g'  /etc/keepalived/keepalived.conf"
  done


echo "正在启动keepalived + Haproxy"
source ./conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl enable --now haproxy"
    sleep 5s
    ssh root@${node_ip} "systemctl enable --now keepalived"
  done
  
sleep 10s


echo "=================================="
echo "keepalived + Haproxy服务安装完成"
echo "=================================="

