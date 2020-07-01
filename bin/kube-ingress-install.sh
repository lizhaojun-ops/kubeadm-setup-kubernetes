#!/bin/bash
echo ""
source ./conf/environment.conf
echo "为maser节点设置标签,自动将ingress部署到master节点上"
for node_name in ${MASTER_NAMES[@]}
  do
     ssh root@${K8S_M1} "source /etc/profile; kubectl label node ${node_name} ingresscontroller=true"
done

echo "标签设置完成,开始部署服务"
echo "将yaml文件拷贝到master节点上发布ingress-nginx服务"
ssh root@${K8S_M1} "mkdir -p /opt/k8s/yaml/ingress-nginx/{hostnetwork,nodeport}"
scp -r ./yaml/ingress-nginx/hostnetwork/nginx-ingress-controller.yaml root@${K8S_M1}:/opt/k8s/yaml/ingress-nginx/hostnetwork/nginx-ingress-controller.yaml
scp -r ./yaml/ingress-nginx/nodeport/nginx-ingress-controller.yaml root@${K8S_M1}:/opt/k8s/yaml/ingress-nginx/nodeport/nginx-ingress-controller.yaml
ssh root@${K8S_M1} "source /etc/profile; kubectl apply -f /opt/k8s/yaml/ingress-nginx/${INGRESS_TYPE}/nginx-ingress-controller.yaml"
sleep 10s
echo "部署中..."
sleep 10s
echo "部署中..."
sleep 10s
echo "部署中..."
sleep 10s
echo ">>>>>> kube-ingress-nginx服务部署完成 <<<<<<"
