#!/bin/bash
echo ">>>>>> 开始系统初始化安装,这需要一些时间,请稍后... <<<<<<"
source ./conf/environment.conf
echo ">>>>>> 正在创建所需要的文件目录 <<<<<<"
rm -rf ./work/hosts
touch ./work/hosts
echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" > ./work/hosts
echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> ./work/hosts
echo ">>>>>> 根据配置生成最新的hosts文件 <<<<<<"

i=0
for ip in ${NODE_IPS[@]}
do
let i++
  echo "${ip} `echo ${NODE_NAMES[@]} | cut -d " " -f $i`" >> ./work/hosts
done

cp /etc/hosts /etc/hosts-default-backup 
cp -r ./work/hosts /etc/hosts
echo ">>>>>> 设置ssh免密登陆 <<<<<<"
ssh-keygen -t rsa -P "" -f /root/.ssh/id_rsa
source ./conf/environment.conf
for node in ${NODE_NAMES[@]};
do
  echo ">>>>>>>>${node}>>>>>>>";
  sshpass -p ${ROOT_PWD} ssh-copy-id -o stricthostkeychecking=no root@${node}
done

echo ">>>>>>正在配置k8s节点的hosts"
source ./conf/environment.conf
for node in ${NODE_NAMES[@]};
do
  echo ">>>>>>>>${node}>>>>>>>";
  ssh -o stricthostkeychecking=no root@${node} "cp /etc/hosts /etc/hosts.back"
  scp ./work/hosts root@${node}:/etc/
done

echo ">>>>>> 正在为所有节点安装基础的依赖包并修改配置,这需要较长的一段时间 <<<<<<"
source ./conf/environment.conf
i=0
for node in ${NODE_NAMES[@]};
do
  let i++
  echo ">>>>>>>> ${node} 节点环境准备中 <<<<<<";
  ssh root@${node} "hostnamectl set-hostname `echo ${NODE_NAMES[@]} | cut -d " " -f $i`"
  ssh root@${node} "systemctl stop firewalld; systemctl disable firewalld; useradd -u 101 ingress-nginx"
  ssh root@${node} "iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat && iptables -P FORWARD ACCEPT"
  ssh root@${node} "swapoff -a;sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab;setenforce 0"
  ssh root@${node} "sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config"
  ssh root@${node} "service dnsmasq stop;systemctl disable dnsmasq;systemctl stop dnsmasq"
  ssh root@${node} "curl http://mirror.tophc.top/mirror/.help/centos_install.sh | bash" 
  ssh root@${node} "curl http://mirror.tophc.top/mirror/.help/epel_install.sh | bash" 
  ssh root@${node} "yum -y install yum-cron ntpdate chrony jq curl sysstat wget openssl openssh sshpass vim htop iotop iftop nload lsof socat"
  ssh root@${node} "timedatectl set-timezone Asia/Shanghai; timedatectl set-local-rtc 0; systemctl restart chronyd; systemctl enable chronyd"
  ssh root@${node} "ntpdate -u 172.19.30.116; clock -w; systemctl disable ntpd; systemctl stop ntpd;"
  ssh root@${node} "systemctl restart rsyslog; systemctl restart crond"
  ssh root@${node} "cp /etc/sysctl.conf /etc/sysctl.conf.back; echo > /etc/sysctl.conf; sysctl -p"
  ssh root@${node} "mkdir -p  /opt/k8s/{bin,work,yaml}"
  scp ./conf/kubernetes.conf root@${node}:/etc/sysctl.d/kubernetes.conf
  scp -r ./work/hosts  root@${node}:/etc/hosts
  scp -r ./conf/environment.conf  root@${node}:/opt/k8s/bin/environment.sh
done

source ./conf/environment.conf
echo ">>>>>> 升级系统内核,内核版本为${Kernel_Version} <<<<<<"
for node in ${NODE_NAMES[@]};
do 
   echo ">>> ${node} 升级内核中 <<<"
   ssh root@${node} "mkdir /tmp/kernel-update/"
   scp -r ./work/kernel-ml* root@${node}:/tmp/kernel-update/
   ssh root@${node} "cd /tmp/kernel-update/; yum install kernel-ml-*.rpm -y"
   sleep 3s
   ssh root@${node} "rm -rf /tmp/kernel-update/kernel*"
   ssh root@${node} "grub2-set-default  0 && grub2-mkconfig -o /etc/grub2.cfg"
   ssh root@${node} "grubby --default-kernel" 
   sleep 5s
   ssh root@${node} "reboot" 
done

source ./conf/environment.conf
for node in ${NODE_NAMES[@]};
 do               
   while true
   do 
     ping -c 4 -w 100  ${node} > /dev/null 
       if [[ $? = 0 ]];then  
          echo " ${node} 主机 ping ok,开始下一步安装"
          echo ">>>>>> ${node} 节点安装基础依赖包并配置内核模块 <<<<<<";
          ssh root@${node} "yum install -y conntrack ipvsadm ipset iptables sysstat libseccomp"
          scp ./conf/ipvs.conf root@${node}:/tmp/
          ssh root@${node} "cat /tmp/ipvs.conf > /etc/modules-load.d/ipvs.conf;"
          ssh root@${node} "systemctl enable --now systemd-modules-load.service;"
          ssh root@${node} "for m in ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack_ipv4 br_netfilter; do modprobe -- \$m; done"
          ssh root@${node} "lsmod |egrep 'ip_vs*|nf_conntrack_ipv4|br_netfilter';"
          ssh root@${node} "sysctl -p /etc/sysctl.d/kubernetes.conf"
          ssh root@${node} "chmod +x /opt/k8s/bin/*"
          sleep 3s
          ssh root@${node} "reboot"
          echo ">>>>>>>>>> ${node} install ok <<<<<<<<<"
          break
        else                   
          echo " ${node} 主机还未reboot成功,请稍后... "
          sleep 5s
        fi
   done 
done

source ./conf/environment.conf
for node in ${NODE_NAMES[@]};
 do
   while true
   do
     ping -c 4 -w 100  ${node} > /dev/null
       if [[ $? = 0 ]];then
          echo " ${node} 节点 ping ok,开始apiserver负载均衡模块安装"
          break
        else
          echo " ${node} 节点还未reboot成功,请稍后... "
          sleep 5s
        fi
   done
done


