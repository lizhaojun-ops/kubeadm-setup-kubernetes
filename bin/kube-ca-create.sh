#!/bin/bash
#自动创建ca
cp -r ./work/cfssl* /usr/bin/
chmod +x /usr/bin/cfssl*

echo ">>>>>> 创建CA证书和秘钥 <<<<<<"
#创建配置文件
cd ./work

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "876000h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "876000h"
      }
    }
  }
}
EOF

#创建证书签名请求文件
cat > ca-csr.json <<EOF
{
  "CN": "kubernetes",
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
  ],
  "ca": {
    "expiry": "876000h"
 }
}
EOF

#生成CA证书和私钥
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
ls ca*

cd ..
source ./conf/environment.conf
for node in ${NODE_IPS[@]}
 do
    echo ">>> ${node}"
    ssh root@${node} "mkdir -p /etc/kubernetes/cert"
    scp ./work/ca*.pem root@${node}:/etc/kubernetes/cert/
    scp ./work/ca-config.json root@${node}:/etc/kubernetes/cert/
 done

source ./conf/environment.conf
scp ./work/ca-csr.json root@${K8S_M1}:/etc/kubernetes/cert/

echo ">>>>>> CA 证书分发完成 <<<<<<"

