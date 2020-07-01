#!/bin/bash
echo "下载和解压所需文件"
cd ./work/
source ../conf/environment.conf
tar -zxf kubernetes-client-linux-amd64.tar.gz
cp -r kubernetes/client/bin/kubectl /usr/bin/kubectl
chmod 755 /usr/bin/kubectl

source ../conf/environment.conf
for node in ${NODE_IPS[@]}
  do
    echo ">>> ${node}"
    scp kubernetes/client/bin/kubectl root@${node}:/opt/k8s/bin/
    scp kubernetes/client/bin/kubectl root@${node}:/usr/bin/
    ssh root@${node} "chmod +x /opt/k8s/bin/*"
    ssh root@${node} "chmod +x /usr/bin/kubectl"
  done

#创建admin证书和私钥
cat > admin-csr.json <<EOF
{
  "CN": "admin",
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
      "O": "system:masters",
      "OU": "devops"
    }
  ]
}
EOF

#生成证书和私钥
#选择生成在本地,远程分发到k8s节点
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin
ls admin*

#创建kubeconfig文件,创建在本地,远程分发
source ../conf/environment.conf
# 设置集群参数
#/usr/bin/kubectl config set-cluster kubernetes --certificate-authority=ca.pem --embed-certs=true --server=${KUBE_APISERVER} --kubeconfig=kubectl.kubeconfig
/usr/bin/kubectl config set-cluster tks-$DEPARTMENT-$ENVIRONMENT-$SERVICE_NAME-nodepool-$NODEPOOLID --certificate-authority=ca.pem --embed-certs=true --server=${KUBE_APISERVER} --kubeconfig=kubectl.kubeconfig
# 设置客户端认证参数
#/usr/bin/kubectl config set-credentials admin --client-certificate=admin.pem --client-key=admin-key.pem --embed-certs=true --kubeconfig=kubectl.kubeconfig
/usr/bin/kubectl config set-credentials clusterAdmin_tks-$DEPARTMENT-$ENVIRONMENT-$SERVICE_NAME-nodepool-$NODEPOOLID --client-certificate=admin.pem --client-key=admin-key.pem --embed-certs=true --kubeconfig=kubectl.kubeconfig
# 设置上下文参数
#/usr/bin/kubectl config set-context kubernetes --cluster=kubernetes --user=admin --kubeconfig=kubectl.kubeconfig
/usr/bin/kubectl config set-context tks-$DEPARTMENT-$ENVIRONMENT-$SERVICE_NAME-nodepool-$NODEPOOLID --cluster=tks-$DEPARTMENT-$ENVIRONMENT-$SERVICE_NAME-nodepool-$NODEPOOLID --user=clusterAdmin_tks-$DEPARTMENT-$ENVIRONMENT-$SERVICE_NAME-nodepool-$NODEPOOLID --kubeconfig=kubectl.kubeconfig
# 设置默认上下文
#/usr/bin/kubectl config use-context kubernetes --kubeconfig=kubectl.kubeconfig
/usr/bin/kubectl config use-context tks-$DEPARTMENT-$ENVIRONMENT-$SERVICE_NAME-nodepool-$NODEPOOLID --kubeconfig=kubectl.kubeconfig

#分发kubeconfig文件 
source ../conf/environment.conf
for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ~/.kube"
    scp kubectl.kubeconfig root@${node_ip}:~/.kube/config
  done

cd ..
sleep 10s
echo ">>>>>> kubectl ok <<<<<<"

