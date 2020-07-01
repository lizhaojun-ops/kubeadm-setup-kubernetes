#!/bin/bash
echo "开始部署metrics-server"
echo "将yaml文件拷贝到master节点上发布metrics-server服务"
source ./conf/environment.conf
ssh root@${K8S_M1} "mkdir -p /opt/k8s/yaml/metrics-server/"
scp -r ./yaml/metrics-server/metrics-server.yaml root@${K8S_M1}:/opt/k8s/yaml/metrics-server/metrics-server.yaml
ssh root@${K8S_M1} "source /etc/profile; kubectl apply -f /opt/k8s/yaml/metrics-server/metrics-server.yaml"
sleep 10s
echo ">>>>>> metrics-server 部署完成 <<<<<<"
