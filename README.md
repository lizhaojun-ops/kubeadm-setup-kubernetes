# kubernetes自动部署工具(内网版本)

## 如何使用
* 找个虚拟机,能够远程ssh你的k8s节点地址的作为部署机器,远程进行部署


### 方式一

从git服务器获取最新的部署脚本

```
git clone http://git.tophc.top/kubernetes/kunernetes-setup-tools.git 
cd kunernetes-setup-tools
git checkout intranet        #切换到内网版本分支
```


### 方式二

从FTP服务器获取安装脚本, CICD平台会自动上传部署脚本到FTP服务器

```
wget http://download.tophc.top/Kubernetes/auto-setup-tools/kubernetes-setup-tools-intranet.tar.gz
tar -zxf kubernetes-setup-tools-intranet.tar.gz
cd kubernetes-setup-tools-intranet
```

## 节点规划

* 修改 `conf`下的`environment.conf`; 里面指定节点的信息,如下为举例说明

总共有5个节点,三个master高可用,master也参与到node的工作中,这样就有了5个可用的节点

| IP | role | other |
| :-: | :-: | :-: |
| 10.100.4.20 | VIP | keepalive VIP (面向apiserver的负载) |
| $K8S_M1 | master+node | etcd,kube-apiserver,kube-schedule,kube-controller-manager,kube-kubelet,kube-proxy |
| $K8S_M2 | master+node | etcd,kube-apiserver,kube-schedule,kube-controller-manager,kube-kubelet,kube-proxy |
| $K8S_M3 | master+node | etcd,kube-apiserver,kube-schedule,kube-controller-manager,kube-kubelet,kube-proxy |
| 10.100.4.24 | node | kube-kubelet,kube-proxy |
| 10.100.4.25 | node | kube-kubelet,kube-proxy |


* **安装过程会从`172.19.2.252`的FTP上下载文件,请保持所有节点和`172.19.2.252`能够正常通信**
* 三个master高可用,部署keepalive产生VIP用做kube-apiserver的地址, 三台master部署nginx做kube-apiserver的tcp负载均衡, 这样kube-apiserver的地址就是`https://10.100.4.20:8443`;
* master节点部署etcd集群、kube-apiserver、kube-schedule、kube-controller-manager; kube-schedule和kube-controller-manager自带高可用功能;
* master也参与到工作中,这样就有5台节点, 其中三台为master;
* coredns暂时部署两个pod,不固定节点;
* ingress部署在master节点上,脚本会自动打标签进去;
* dashboard自主选择节点部署，不再固定节点. dashboard支持用户名和密码登录,默认生成了`kubeadmin`账号,密码为随机密码,密码存放在master节点的`/etc/kubernetes/basic_auth_file`文件中;支持修改密码,但是需要将密码同步到所有master并重启`kube-apiserver`服务.

## 安装

```
./install  #输入y确认安装即可,安装过程根据机器配置与网速而定,大概需20分钟左右
```
