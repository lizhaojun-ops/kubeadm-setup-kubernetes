#!/bin/bash
echo ">>>>>> 开始部署高可用 kube-nginx <<<<<<"
echo "下载编译nginx"
cd ./work/
source ../conf/environment.conf
#先用稳定版本,新版本后续再升级
rm -rf nginx-${NGINX_VERSION}
tar -zxf nginx-${NGINX_VERSION}.tar.gz
cd nginx-${NGINX_VERSION}
rm -rf /etc/kube-nginx
mkdir -p /etc/kube-nginx
./configure --with-stream --without-http --prefix=/etc/kube-nginx --without-http_uwsgi_module
make && make install

echo "创建目录结构"
cd ..
source ../conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}
  done

echo "拷贝二进制程序到其他主机"
source ../conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}"
    scp /etc/kube-nginx/sbin/nginx  root@${node_ip}:/opt/k8s/kube-nginx/sbin/kube-nginx
    ssh root@${node_ip} "chmod a+x /opt/k8s/kube-nginx/sbin/*"
    ssh root@${node_ip} "mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}"
    sleep 3
  done


echo "配置Nginx文件，开启4层透明转发"
source ../conf/environment.conf
cat > kube-nginx.conf <<EOF
worker_processes 1;
events {
    worker_connections  1024;
}
stream {
    upstream backend {
        hash $remote_addr consistent;
        server $K8S_M1:6443        max_fails=3 fail_timeout=30s;
        server $K8S_M2:6443        max_fails=3 fail_timeout=30s;
        server $K8S_M3:6443        max_fails=3 fail_timeout=30s;
    }
    server {
        listen *:8443;
        proxy_connect_timeout 1s;
        proxy_pass backend;
    }
}
EOF


echo "分发配置文件"
source ../conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-nginx.conf  root@${node_ip}:/opt/k8s/kube-nginx/conf/kube-nginx.conf
  done

echo "配置Nginx启动文件"
cat > kube-nginx.service <<EOF
[Unit]
Description=kube-apiserver nginx proxy
After=network.target
After=network-online.target
Wants=network-online.target
[Service]
Type=forking
ExecStartPre=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx -t
ExecStart=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx
ExecReload=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx -s reload
PrivateTmp=true
Restart=always
RestartSec=5
StartLimitInterval=0
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

echo "分发nginx启动文件"
source ../conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-nginx.service  root@${node_ip}:/etc/systemd/system/
  done

echo "启动 kube-nginx 服务"
source ../conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kube-nginx && systemctl start kube-nginx"
  done

echo "检查 kube-nginx 服务运行状态"
source ../conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status kube-nginx |grep 'Active:'"
  done

sleep 10s

cd ..
echo "=================="
echo "kube-nginx安装完成"
echo "=================="



