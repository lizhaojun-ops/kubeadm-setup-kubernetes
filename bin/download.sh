#!/bin/bash
clear
echo -e "\033[36m开始下载k8s组件的安装包...\033[0m"
sh -c "$(curl -fsSL http://mirror.tophc.top/mirror/.help/centos_install.sh)"
sh -c "$(curl -fsSL http://mirror.tophc.top/mirror/.help/epel_install.sh)"
yum install wget ftp sshpass openssh -y >/dev/null 2>&1
mkdir ./work
rm -rf ./work/*
cd ./work
source ../conf/environment.conf
echo " "
#echo "下载kubernetes-server kubernetes-client包"
#wget -c http://download.tophc.top/Kubernetes/kubernetes-binary-amd64/${KUBE_VERSION}/kubernetes-server-linux-amd64.tar.gz
#wget -c http://download.tophc.top/Kubernetes/kubernetes-binary-amd64/${KUBE_VERSION}/kubernetes-client-linux-amd64.tar.gz
#echo "下载etcd安装包"
#wget -c http://download.tophc.top/Kubernetes/etcd/etcd-${ETCD_VERSION}-linux-amd64.tar.gz
#echo "下载flannel"
#wget -c http://download.tophc.top/Kubernetes/flannel/flannel-${FLANNEL_VERSION}-linux-amd64.tar.gz
#echo "下载cfssl"
#wget -c http://download.tophc.top/Kubernetes/cfssl/cfssl-certinfo_linux-amd64 -O cfssl-certinfo
#wget -c http://download.tophc.top/Kubernetes/cfssl/cfssl_linux-amd64 -O cfssl
#wget -c http://download.tophc.top/Kubernetes/cfssl/cfssljson_linux-amd64 -O cfssljson
echo "下载centos kernel"
wget -c http://download.tophc.top/Kubernetes/kernel/kernel-ml-${Kernel_Version}.el7.elrepo.x86_64.rpm
wget -c http://download.tophc.top/Kubernetes/kernel/kernel-ml-devel-${Kernel_Version}.el7.elrepo.x86_64.rpm
echo "下载helm"
wget -c http://download.tophc.top/Kubernetes/helm/${HELM_VERSION}/helm-${HELM_VERSION}-linux-amd64.tar.gz
echo ""
echo "download ok！"
echo ""
cd ..

