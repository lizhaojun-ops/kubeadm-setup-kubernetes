#!/bin/bash
echo ">>>>>> 开始部署flanneld网络 <<<<<<"
echo "下载和解压所需文件..."
cd ./work/
rm -rf ./flannel
mkdir flannel
source ../conf/environment.conf
tar -zxf flannel-${FLANNEL_VERSION}-linux-amd64.tar.gz -C flannel

echo "分发flannel二进制文件到所有集群的节点"
source ../conf/environment.conf
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp flannel/{flanneld,mk-docker-opts.sh} root@${node_ip}:/opt/k8s/bin/
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done

echo "创建Flannel证书和私钥"

cat > flanneld-csr.json <<EOF
{
  "CN": "flanneld",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "devops"
    }
  ]
}
EOF

#生在本地进行远程分发
echo "生成证书和私钥"
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes flanneld-csr.json | cfssljson -bare flanneld
ls flanneld*pem

echo "将生成的证书和私钥分发到所有节点"
source ../conf/environment.conf
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /etc/flanneld/cert"
    scp flanneld*.pem root@${node_ip}:/etc/flanneld/cert
  done

cat > upload-flanneld-network.sh << EOF
#!/bin/bash
source /etc/profile
source /opt/k8s/bin/environment.sh
etcdctl \
  --endpoints=\${ETCD_ENDPOINTS} \
  --ca-file=/etc/kubernetes/cert/ca.pem \
  --cert-file=/etc/flanneld/cert/flanneld.pem \
  --key-file=/etc/flanneld/cert/flanneld-key.pem \
  mk \${FLANNEL_ETCD_PREFIX}/config '{"Network":"'\${CLUSTER_CIDR}'", "SubnetLen": 24, "Backend": {"Type": "vxlan"}}'
EOF

echo "向etcd写入Pod网段信息"
scp upload-flanneld-network.sh root@${K8S_M1}:/opt/k8s/bin/upload-flanneld-network.sh
ssh root@${K8S_M1} "chmod +x /opt/k8s/bin/upload-flanneld-network.sh"
ssh root@${K8S_M1} "source /etc/profile; bash /opt/k8s/bin/upload-flanneld-network.sh"

sleep 10s
echo "创建flanneld的启动文件"
source ../conf/environment.conf
cat > flanneld.service << EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service
[Service]
Type=notify
ExecStart=/opt/k8s/bin/flanneld \\
  -etcd-cafile=/etc/kubernetes/cert/ca.pem \\
  -etcd-certfile=/etc/flanneld/cert/flanneld.pem \\
  -etcd-keyfile=/etc/flanneld/cert/flanneld-key.pem \\
  -etcd-endpoints=${ETCD_ENDPOINTS} \\
  -etcd-prefix=${FLANNEL_ETCD_PREFIX} \\
  -iface=${IFACE} \\
  -ip-masq
ExecStartPost=/opt/k8s/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker
Restart=always
RestartSec=5
StartLimitInterval=0
[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOF

echo "分发启动文件到所有节点"
source ../conf/environment.conf
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp flanneld.service root@${node_ip}:/etc/systemd/system/
  done

echo "启动flanneld服务"
source ../conf/environment.conf
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable flanneld && systemctl restart flanneld"
  done

sleep 5s
echo "检查启动结果"
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status flanneld|grep Active"
  done

sleep 10s
echo "检查分配给flanneld的Pod网段信息"
source ../conf/environment.conf
ssh root@${K8S_M1} "source /etc/profile; etcdctl --endpoints=${ETCD_ENDPOINTS} --ca-file=/etc/kubernetes/cert/ca.pem --cert-file=/etc/flanneld/cert/flanneld.pem --key-file=/etc/flanneld/cert/flanneld-key.pem get ${FLANNEL_ETCD_PREFIX}/config"

echo "检查是否创建了 flannel 接口"
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh ${node_ip} "/usr/sbin/ip addr show flannel.1|grep -w inet"
  done

cd ..
echo "======================"
echo "flannel网络安装完成"
echo "======================"
