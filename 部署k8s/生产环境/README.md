# 1 环境

至少3台centos 7虚机

| 虚机名称        | IP            |
| ------------- |:-------------:|
| node01        | 172.16.120.151|
| node02        | 172.16.120.152|
| node03        | 172.16.120.153|


# 2 安装etcd

etcd.sh实现关闭selinux和firewall，下载v3.2.4版本的etcd，并进行安装，同时将etcd添加到环境变量。

在node01节点执行：
```bash
sh etcd.sh "node01" "172.16.120.151" "node01=http://172.16.120.151:2380,node02=http://172.16.120.152:2380,node03=http://172.16.120.153:2380"
```

在node02节点执行：
```bash
sh etcd.sh "node02" "172.16.120.152" "node01=http://172.16.120.151:2380,node02=http://172.16.120.152:2380,node03=http://172.16.120.153:2380"
```

在node03节点执行：
```bash
sh etcd.sh "node03" "172.16.120.153" "node01=http://172.16.120.151:2380,node02=http://172.16.120.152:2380,node03=http://172.16.120.153:2380"
```

- 第1个参数是etcd当前节点名称ETCD_NAME
- 第2个参数是etcd当前节点IP地址ETCD_LISTEN_IP
- 第3个参数是etcd集群地址ETCD_INITIAL_CLUSTER

>注意：如果etcd下载较慢，可以将etcd事先下载好，放到etcd.sh所在目录下。etcd下载地址https://github.com/coreos/etcd/releases/download/v3.2.4/etcd-v3.2.4-linux-amd64.tar.gz


安装验证：
```bash
etcdctl member list
etcdctl cluster-health
```
如果etcdctl命令无法使用，执行下面的命令，使~/.bash_profile生效
```bash
source ~/.bash_profile
```

# 3 安装kubernetes master
master/kube-master.sh实现关闭selinux和firewall，下载v1.6.7版本的kubernetes，并进行安装，生成apiserver、controller manager、kube-scheduler服务证书，并使用kubernetes的TLS。

在node01节点执行：
```bash
sh kube-master.sh "172.16.120.151" "k8s-node01" "http://172.16.120.151:2379,http://172.16.120.152:2379,http://172.16.120.153:2379"
```

- 第1个参数MASTER_ADDRESS是master节点的地址
- 第2个参数MASTER_DNS是master的DNS名称
- 第3个参数ETCD_SERVERS是etcd集群地址
- 第4个参数SERVICE_CLUSTER_IP_RANGE是kubernetes分配的集群IP范围，默认值为10.0.0.0/24
- 第5个参数MASTER_CLUSTER_IP是kubernetes指定master的集群IP,默认值为10.0.0.1

安装验证：
```bash
# kubectl get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-0               Healthy   {"health": "true"}
etcd-2               Healthy   {"health": "true"}
etcd-1               Healthy   {"health": "true"}
```


>注意：如果kubernetes下载较慢，可以将kubernetes事先下载好，放到master/kube-master.sh所在目录下。kubernetes下载地址https://github.com/kubernetes/kubernetes/releases/download/v1.6.7/kubernetes.tar.gz

# 4 安装kubernetes node
node/kube-node.sh实现关闭selinux和firewall，下载v1.6.7版本的kubernetes，并进行安装，安装服务有flannel、docker、kubelet、kube-proxy，从master节点获取根证书，并生成kubelet、kube-proxy服务证书，使用kubernetes的TLS。

在node02节点执行：
```bash
sh kube-node.sh "172.16.120.152" "172.16.120.151" "root" "123456" "http://172.16.120.151:2379,http://172.16.120.152:2379,http://172.16.120.153:2379"
```

在node03节点执行：
```bash
sh kube-node.sh "172.16.120.153" "172.16.120.151" "root" "123456" "http://172.16.120.151:2379,http://172.16.120.152:2379,http://172.16.120.153:2379"
```

- 第1个参数NODE_ADDRESS是node节点IP
- 第2个参数MASTER_ADDRESS是master节点IP
- 第3个参数MASTER_USER是master节点用户名名
- 第4个参数MASTER_PASSWORD是master节点登录密码
- 第5个参数ETCD_SERVERS是etcd集群地址
- 第6个参数FLANNEL_NET是flannel地址段，默认为172.18.0.0/16
- 第7个参数DOCKER_OPTS是docker参数配置
- 第8个参数KUBELET_POD_INFRA_CONTAINER是kubelet pod的基础镜像名称，默认值为hub.c.163.com/k8s163/pause-amd64:3.0

安装验证：
```bash
# kubectl get nodes
NAME             STATUS    AGE       VERSION
172.16.120.152   Ready     8h        v1.6.7
172.16.120.153   Ready     5h        v1.6.7
```

>注意：如果kubernetes和flannel下载较慢，可以将kubernetes和flannel事先下载好,放到node/kube-node.sh所在目录下。flannel下载地址https://github.com/coreos/flannel/releases/download/v0.7.1/flannel-v0.7.1-linux-amd64.tar.gz

由于在kubernetes中是以Pod而不是docker容器作为管理单元，在kubelet创建Pod时，还通过启动一个名为google_containers/pause的镜像来实现Pod的概念。该镜像存在于谷歌的镜像库http://gcr.io中，需要将其下载并push到私有Docker Registry中去，在本脚步中使用下面配置 --pod_infra_container_image=hub.c.163.com/k8s163/pause-amd64:3.0。


参考：
http://tonybai.com/2017/07/20/fix-cannot-access-dashboard-in-k8s-1-6-4/

https://stackoverflow.com/questions/44469277/var-log-kube-apiserver-log-not-work-for-kubernetes1-6

https://github.com/opsnull/follow-me-install-kubernetes-cluster

http://www.cnblogs.com/breg/p/5923604.html

https://wiki.shileizcc.com/display/KUB/Kubernetes+HA+Cluster+Build#KubernetesHAClusterBuild-配置CA证书和私钥
