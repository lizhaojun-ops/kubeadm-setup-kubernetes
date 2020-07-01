#!/bin/bash
echo "解压helm组件并安装"
source ./conf/environment.conf
tar -zxf ./work/helm-${HELM_VERSION}-linux-amd64.tar.gz -C ./work/

for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp -r ./work/linux-amd64/helm root@${node_ip}:/usr/bin/
    ssh root@${node_ip} "chmod +x /usr/bin/helm"
  done

echo "开始部署tiller-deploy"
echo "将yaml文件拷贝到master节点上发布tiller-deploy服务"
source ./conf/environment.conf
ssh root@${K8S_M1} "mkdir -p /opt/k8s/yaml/tiller-deploy/"
scp -r ./yaml/tiller-deploy/tiller-deploy.yaml root@${K8S_M1}:/opt/k8s/yaml/tiller-deploy/tiller-deploy.yaml
ssh root@${K8S_M1} "source /etc/profile; kubectl apply -f /opt/k8s/yaml/tiller-deploy/tiller-deploy.yaml"
sleep 10s
echo ">>>>>> tiller-deploy 部署完成 <<<<<<"

