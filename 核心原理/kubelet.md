# 1. kubelet简介

1. 在kubernetes集群中，每个Node节点都会启动kubelet进程，用来处理Master节点下发到本节点的任务，管理Pod和其中的容器。

2. kubelet会在API Server上注册节点信息，定期向Master汇报节点资源使用情况，并通过cAdvisor监控容器和节点资源。

> 可以把kubelet理解成【Server-Agent】架构中的agent，是Node上的pod管家。

# 2. 节点管理

节点通过设置kubelet的启动参数 `--register-node`，来决定是否向API Server注册自己，默认为`true`。

可以通过 `kubelet --help` 或者查看kubernetes源码　`cmd/kubelet/app/server.go` 中来查看该参数。

**kubelet的配置文件**

默认配置文件在下的`/etc/kubernetes/kubelet`中，其中

- `--api-servers`：用来配置Master节点的IP和端口。
- `--kubeconfig`：用来配置kubeconfig的路径，kubeconfig文件常用来指定证书。
- `--hostname-override`：用来配置该节点在集群中显示的主机名。
- `--node-status-update-frequency`：配置kubelet向Master心跳上报的频率，默认为`10s`。

# 3. Pod管理

kubelet有几种方式获取自身Node上所需要运行的Pod清单。

这里只研究通过`API Server`监听`etcd`目录，同步`Pod`列表的方式。

kubelet通过API Server Client使用WatchAndList的方式监听etcd中`/registry/nodes/${当前节点名称}`和`/registry/pods`的目录，将获取的信息同步到本地缓存中。

kubelet监听etcd，执行对Pod的操作，对容器的操作则是通过`Docker Client`执行，例如启动删除容器等。

**kubelet创建和修改Pod流程：**

1. 为该Pod创建一个数据目录。
2. 从API Server读取该Pod清单。
3. 为该Pod挂载外部卷（External Volume）
4. 下载Pod用到的Secret。
5. 检查运行的Pod，执行Pod中未完成的任务。
6. 先创建一个Pause容器，该容器接管Pod的网络，再创建其他容器。
7. Pod中容器的处理流程：
   1）比较容器hash值并做相应处理。
   2）如果容器被终止了且没有指定重启策略，则不做任何处理。
   3）调用`Docker Client`下载容器镜像，调用`Docker Client`运行容器。

# 4. 容器健康检查

Pod通过**探针**的方式来检查容器的健康状态

具体可参考[Pod详解#Pod健康检查](https://www.huweihuang.com/kubernetes-notes/concepts/pod/pod-probe.html)。

# 5. cAdvisor资源监控

kubelet通过cAdvisor获取本节点信息及容器的数据。

> cAdvisor为谷歌开源的容器资源分析工具，默认集成到kubernetes中。

cAdvisor自动采集CPU,内存，文件系统，网络使用情况，容器中运行的进程，默认端口为`4194`。可以通过`Node IP+Port`访问。

更多参考：[http://github.com/google/cadvisor](http://github.com/google/cadvisor)

 

> 参考《Kubernetes权威指南》

 