#!/bin/bash
clear
echo ""
echo "---------------------------------"
echo "k8s安装配置向导"
echo "此向导需要配置以下内容:"
echo "---------------------------------"
echo " * 集群信息,包括部门信息、环境信息、运行服务; 此项设置为自动生成主机名并配置为Kubernetes节点的名称; 请小心配置！ "
echo " * Kubernetes所需Master集群的IP地址信息,需要三个IP地址(仅支持3节点的Master集群,其他节点数量暂时不支持);"
echo " * Kubernetes所需Master集群Apiserver的VIP地址,不能是Master节点IP,需要地址不被占用;"
echo " * 默认将Master节点也作为工作节点,如无其他多余的节点,在输入Node节点IP时不用输入直接确定即可;"
echo " * 请确保master节点和node节点的root密码相同！"
echo "------------------------------------------------------------------------------------------------------------------"
read -p "确定执行安装请输入 y ,退出安装程序请输入 n : " re
if [ "${re}x" != "yx" ];then
exit 1
fi

NODEPOOLID=`cat /dev/urandom | head -n 20 | cksum | head -c 9`              
READPAR1 () {
read -p "请输入部门(如:tophc或cloud)、集群环境(如:dev或qa或uat或prod)、服务名称(集群用来干什么,默认default), 中间使用空格隔开,仅支持英文输入: " cluster
DEPARTMENT=`echo $cluster |cut -d " " -f 1`
ENVIRONMENT=`echo $cluster |cut -d " " -f 2`
SERVICE_NAME=`echo $cluster |cut -d " " -f 3`

if [ "${DEPARTMENT}x" == "x" ] || [ "${ENVIRONMENT}x" == "x" ] || [ "${SERVICE_NAME}x" == "x" ]
 then 
   echo "输入错误,请重新输入"
   READPAR1
fi

read -p "确定请输入 y ,错误重新输入 n : " re
if [ "${re}x" != "yx" ];then
READPAR1
fi
}

READPAR2 () {
read -p "请输入MASTER节点地址,三个IP之间以空格隔开: " masterip
K8S_M1=`echo $masterip |cut -d " " -f 1`
K8S_M2=`echo $masterip |cut -d " " -f 2`
K8S_M3=`echo $masterip |cut -d " " -f 3`
MASTER_IPS=( $masterip )

read -p "请输入apiserver的VIP地址: " vip
KUBE_APISERVER_VIP="$vip"

if [ "${K8S_M1}x" == "x" ] || [ "${K8S_M2}x" == "x" ] || [ "${K8S_M3}x" == "x" ] || [ "${KUBE_APISERVER_VIP}x" == "x" ]
 then
   echo "输入错误,请重新输入"
   READPAR2
fi

read -p "确定请输入 y ,错误重新输入 n : " re
if [ "${re}x" != "yx" ];then
READPAR2
fi
}

READPAR3 () {
read -p "请输入NODE节点地址,多个IP中间以空格隔开: " nodeip
NODE_IPS=( $masterip $nodeip )

if [ "${nodeip}x" == "x" ]
 then
   read -p "你未输入node节点的ip,是否继续安装？确定请输入 y ,错误输入 n :" re
   if [ "${re}x" != "yx" ];then
      READPAR3
   fi
 else
  read -p "确定请输入 y ,错误重新输入 n : " re
   if [ "${re}x" != "yx" ];then
      READPAR3
   fi
fi
}

READPAR4 () {
read -p "请输入节点的root密码(请确保master节点和node节点的root密码相同): " rootpwd
ROOT_PWD=$rootpwd
echo "你输入的密码为 $rootpwd"
read -p "确定请输入 y ,错误重新输入 n : " re
if [ "${re}x" != "yx" ];then
    READPAR4
fi
}

MASTERHOSTNAME () {
i=0
for ip in ${MASTER_IPS[@]}
do
let i++
  echo "tks-$DEPARTMENT-$ENVIRONMENT-$SERVICE_NAME-nodepool-$NODEPOOLID-$i"
done
}

CHECKMASTER () {
c=0
for line in `MASTERHOSTNAME`
do
    mastername[${c}]=$line
    let c=${c}+1
done

MASTER_NAMES=`echo ${mastername[@]}`
#export MASTER_NAMES=( $MASTER_NAMES )
echo "所有MASTER节点的IP"
echo ${MASTER_IPS[@]}
echo "所有MASTER节点的hostname"
#echo ${MASTER_NAMES[@]}
echo ${MASTER_NAMES}
}

NODEHOSTNAME () {
i=0
for ip in ${NODE_IPS[@]}
do
let i++
  echo "tks-$DEPARTMENT-$ENVIRONMENT-$SERVICE_NAME-nodepool-$NODEPOOLID-$i"
done
}

CHECKNODE () {
c=0
for line in `NODEHOSTNAME`
do
    k8sname[${c}]=$line
    let c=${c}+1
done

NODE_NAMES=`echo ${k8sname[@]}`
#export NODE_NAMES=( $NODE_NAMES )
echo "所有主机的IP"
echo ${NODE_IPS[@]}
echo "所有主机的hostname"
#echo ${NODE_NAMES[@]}
echo ${NODE_NAMES}
}

READPAR1
READPAR2
READPAR3
READPAR4

echo ""
echo "============================================================="
echo "* 以下为你输入的所有信息:"
echo "* 部门: $DEPARTMENT   环境: $ENVIRONMENT"
echo "* 节点运行服务: $SERVICE_NAME"
echo "* apiserver-VIP地址: $KUBE_APISERVER_VIP"
echo "* 主节点IP: $K8S_M1 $K8S_M2 $K8S_M3"
echo "* 从节点IP: $nodeip"
echo "* 节点 root 密码: $ROOT_PWD "
echo "============================================================="

read -p "确定请输入 y ,错误重新输入 n : " re
if [ "${re}x" != "yx" ];then
READPAR1
READPAR2
READPAR4
fi

CHECKMASTER
CHECKNODE

cat > ./conf/environment.conf <<EOF
#!/usr/bin/bash
#-------------------------------- global config -----------------------------------------
export ROOT_PWD="$ROOT_PWD"         #所有主机的root用户密码,建议设置为统一的密码
export Kernel_Version="4.18.9-1"    #需要升级的内核版本
export KUBE_VERSION="v1.14.8"       #安装k8s集群的版本
export ETCD_VERSION="v3.3.18"       #安装etcd集群的版本
export FLANNEL_VERSION="v0.11.0"    #安装flannel的版本
export HELM_VERSION="v2.16.6"       #安装helm的版本
export IFACE="eth0"                 #节点间互联网络接口名称

#-------------------------------- environment config -------------------------------------------
export DEPARTMENT="$DEPARTMENT"           #部门信息
export ENVIRONMENT="$ENVIRONMENT"         #环境信息
export SERVICE_NAME="$SERVICE_NAME"       #服务信息
export NODEPOOLID="$NODEPOOLID"           #k8s节点池nodepoolid

#-------------------------------- k8s cluster config ------------------------------------------

export K8S_M1=$K8S_M1
export K8S_M2=$K8S_M2
export K8S_M3=$K8S_M3
export KUBE_APISERVER_VIP=$KUBE_APISERVER_VIP

# 集群各机器 IP 数组
export NODE_IPS=( $masterip $nodeip )
# kube-apiserver 的VIP地址端口
export KUBE_APISERVER="https://$KUBE_APISERVER_VIP:8443"
# 集群各 IP 对应的主机名数组 
export NODE_NAMES=( $NODE_NAMES )
# 集群MASTER机器 IP 数组
export MASTER_IPS=( $masterip )
# 集群所有的master Ip对应的主机
export MASTER_NAMES=( $MASTER_NAMES )

#---------------------------------- etcd cluster config -----------------------------------
export ETCD_ENDPOINTS="https://$K8S_M1:2379,https://$K8S_M2:2379,https://$K8S_M3:2379"
# etcd 集群间通信的 IP 和端口
export ETCD_NODES="tks-$DEPARTMENT-$ENVIRONMENT-$SERVICE_NAME-nodepool-$NODEPOOLID-1=https://$K8S_M1:2380,tks-$DEPARTMENT-$ENVIRONMENT-$SERVICE_NAME-nodepool-$NODEPOOLID-2=https://$K8S_M2:2380,tks-$DEPARTMENT-$ENVIRONMENT-$SERVICE_NAME-nodepool-$NODEPOOLID-3=https://$K8S_M3:2380"
# etcd 数据目录
export ETCD_DATA_DIR="/srv/data/etcd/data"
# etcd WAL 目录，建议是 SSD 磁盘分区，或者和 ETCD_DATA_DIR 不同的磁盘分区
export ETCD_WAL_DIR="/srv/data/etcd/wal"
# k8s 各组件数据目录
export K8S_DIR="/srv/data/k8s"


#----------------------------------------kubernetes ingress config ------------------------------
export INGRESS_TYPE="nodeport"          #ingress安装类型,可选hostnetwork与nodeport,默认使用nodeport

# 以下配置不建议修改,除非你非常确定如何使用这些参数
#
# 最好使用 当前未用的网段 来定义服务网段和 Pod 网段
# 服务网段，部署前路由不可达，部署后集群内路由可达(kube-proxy 保证); 不建议修改
SERVICE_CIDR="10.254.0.0/16" 
# Pod 网段，建议 /16 段地址，部署前路由不可达，部署后集群内路由可达(flanneld 保证); 不建议修改
CLUSTER_CIDR="10.138.0.0/16"
# 服务端口范围限制 (NodePort Range); 不建议修改
export NODE_PORT_RANGE="1024-32767"
# flanneld 网络配置前缀; 不建议修改
export FLANNEL_ETCD_PREFIX="/kubernetes/network/tks-\$DEPARTMENT-\$ENVIRONMENT-\$SERVICE_NAME-nodepool-\$NODEPOOLID" 
# kubernetes 服务 IP (一般是 SERVICE_CIDR 中第一个IP); 不建议修改
export CLUSTER_KUBERNETES_SVC_IP="10.254.0.1" 
# 集群 DNS 服务 IP (从 SERVICE_CIDR 中预分配); 不建议修改
export CLUSTER_DNS_SVC_IP="10.254.0.10"
# 集群 DNS 域名（末尾不带点号）
export CLUSTER_DNS_DOMAIN="cluster.local"
# 将二进制目录 /opt/k8s/bin 加到 PATH 中
export PATH=/opt/k8s/bin:\$PATH
# 生成 EncryptionConfig 所需的加密 key
export ENCRYPTION_KEY=\$(head -c 32 /dev/urandom | base64)

EOF
