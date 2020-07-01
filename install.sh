#!/bin/bash
#kubeadm版本
clear
[ $UID = 0 ] || { echo "请使用root用户执行该脚本"; exit 1; }
echo `date +"%Y-%m-%d %H:%M:%S "`
echo "*******************************************************"
echo "          欢迎使用 Kubernetes自动安装工具" 
echo "*******************************************************"

K8SCONFIG (){
   ./bin/config.sh
}

K8SINSTALL() {
    ./bin/download.sh
    sleep 3s
    ./bin/kube-system-init.sh
    sleep 3s
    ./bin/kube-ca-create.sh
    sleep 10s
    ./bin/kube-kubectl-install.sh
    sleep 10s
    ./bin/kube-etcd-install.sh
    sleep 10s
    ./bin/kube-flanneld-install.sh
    sleep 10s
    ./bin/kube-keepalived-install.sh
    sleep 10s
    ./bin/kube-apiserver-install.sh
    sleep 10s
    ./bin/kube-controller-manager-install.sh
    sleep 10s
    ./bin/kube-scheduler-install.sh
    sleep 10s
    ./bin/kube-docker-install.sh
    sleep 10s
    ./bin/kube-kubelet-install.sh
    sleep 10s
    ./bin/kube-proxy-install.sh
    sleep 10s
    ./bin/kube-coredns-install.sh
    sleep 10s
    ./bin/kube-ingress-install.sh
    sleep 10s
    ./bin/kube-metrics-server-install.sh
    sleep 10s
    ./bin/kube-helm-install.sh
    sleep 10s
    ./bin/kube-dashboard-install.sh
    sleep 10s
}

K8S_INSTALL_CHECK() {
while :; do
  read -p "是否执行k8s安装? [y/n]: " Install_yn
  if [[ ! $Install_yn =~ ^[y,n]$ ]]; then
    echo -e "\033[33m"input error! Please only input 'y' or 'n'"\033[0m"
  else
    if [[ $Install_yn == 'y' ]]; then
       K8SCONFIG
       K8SINSTALL
       tar -zcf k8s-install-`date +"%Y%m%d%H%M"`.tar.gz conf yaml work
       mkdir ./tmp/
       mv k8s-install* ./tmp/
       echo "已将此次安装产生的文件打包存入tmp目录下"
       break
      else
        break
    fi
  fi
done
}

K8S_INSTALL_CHECK

source ./conf/environment.conf
echo " "
echo `date +"%Y-%m-%d %H:%M:%S "`
echo "*********************************************************************************************"
echo " Kuberbetes: ${KUBENAME} 部署完成"
echo " 集群已自动部署coredns、ingress、dashboard服务: 相关的yaml文件目录: /opt/k8s/yaml "
echo " dashboard访问地址: https://${KUBE_APISERVER_VIP}:30000 ; 账户密码请查看/etc/kubernetes/basic_auth_file"
echo "*********************************************************************************************"
