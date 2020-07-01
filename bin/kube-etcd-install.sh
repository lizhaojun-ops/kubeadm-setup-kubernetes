#!/bin/bash
echo ">>>>>> 开始安装ETCD集群 <<<<<<"
source ./conf/environment.conf
cd ./work/
#前面已经下载了安装包,这里解压进行安装就好了
tar -zxf etcd-${ETCD_VERSION}-linux-amd64.tar.gz
echo "分发etcd二进制文件到集群节点"
source ../conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp etcd-${ETCD_VERSION}-linux-amd64/etcd* root@${node_ip}:/opt/k8s/bin/
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done

echo "创建etcd证书和私钥"
cat > etcd-csr.json <<EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "$K8S_M1",
    "$K8S_M2",
    "$K8S_M3"
  ],
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

echo "生成etcd证书和私钥"
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes etcd-csr.json | cfssljson -bare etcd
ls etcd*pem

echo "分发证书和私钥到etcd各个节点"
source ../conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /etc/etcd/cert"
    scp etcd*.pem root@${node_ip}:/etc/etcd/cert/
  done

echo "创建etcd的启动文件"
source ../conf/environment.conf
cat > etcd.service.template <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos
[Service]
Type=notify
WorkingDirectory=${ETCD_DATA_DIR}
ExecStart=/opt/k8s/bin/etcd \\
  --data-dir=${ETCD_DATA_DIR} \\
  --wal-dir=${ETCD_WAL_DIR} \\
  --name=##NODE_NAME## \\
  --cert-file=/etc/etcd/cert/etcd.pem \\
  --key-file=/etc/etcd/cert/etcd-key.pem \\
  --trusted-ca-file=/etc/kubernetes/cert/ca.pem \\
  --peer-cert-file=/etc/etcd/cert/etcd.pem \\
  --peer-key-file=/etc/etcd/cert/etcd-key.pem \\
  --peer-trusted-ca-file=/etc/kubernetes/cert/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --listen-peer-urls=https://##NODE_IP##:2380 \\
  --initial-advertise-peer-urls=https://##NODE_IP##:2380 \\
  --listen-client-urls=https://##NODE_IP##:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls=https://##NODE_IP##:2379 \\
  --initial-cluster-token=etcd-cluster-0 \\
  --initial-cluster=${ETCD_NODES} \\
  --initial-cluster-state=new \\
  --auto-compaction-mode=periodic \\
  --auto-compaction-retention=1 \\
  --max-request-bytes=33554432 \\
  --quota-backend-bytes=6442450944 \\
  --heartbeat-interval=250 \\
  --election-timeout=2000
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

#分发会将配置文件中的#替换成ip
source ../conf/environment.conf
for (( i=0; i < 3; i++ ))
  do
    sed -e "s/##NODE_NAME##/${MASTER_NAMES[i]}/" -e "s/##NODE_IP##/${MASTER_IPS[i]}/" etcd.service.template > etcd-${MASTER_IPS[i]}.service 
  done
ls *.service
#NODE_NAMES 和 NODE_IPS 为相同长度的 bash 数组，分别为节点名称和对应的 IP；

#分发生成的etcd启动文件到对应的服务器
source ../conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp etcd-${node_ip}.service root@${node_ip}:/etc/systemd/system/etcd.service
  done

#重命名etcd启动文件并启动etcd服务
source ../conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ${ETCD_DATA_DIR} ${ETCD_WAL_DIR}"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable etcd && systemctl restart etcd " &
  done

#检查启动结果
source ../conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status etcd|grep Active"
  done

sleep 5s
echo "请稍后..."
sleep 5s
echo "请稍后..."

#验证ETCD集群状态
source ../conf/environment.conf
for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "ETCDCTL_API=3 /opt/k8s/bin/etcdctl --endpoints=https://${node_ip}:2379 --cacert=/etc/kubernetes/cert/ca.pem --cert=/etc/etcd/cert/etcd.pem --key=/etc/etcd/cert/etcd-key.pem endpoint health"
  done
#查看当前etcd集群的leader
source ../conf/environment.conf
ssh root@${K8S_M1} "ETCDCTL_API=3 /opt/k8s/bin/etcdctl -w table --cacert=/etc/kubernetes/cert/ca.pem --cert=/etc/etcd/cert/etcd.pem --key=/etc/etcd/cert/etcd-key.pem --endpoints=${ETCD_ENDPOINTS} endpoint status"
cd ..
echo ">>>>>> etcd部署完成 <<<<<<"
