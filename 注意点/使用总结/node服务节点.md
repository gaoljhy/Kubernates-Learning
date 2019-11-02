# Node服务节点

## Kubelet[节点上的Pod管家]

> `kubelet`是`Master API Server`和`Node`之间的*桥梁*，

1. 负责`Node`节点上`pod`的**创建、修改、监控、删除**等全生命周期的管理

2. 定时上报本Node的状态信息给`API Server`。

3. 接收`Master API Server`分配给它的`commands`和`work`，通过`kube-apiserver`间接与`Etcd`集群交互，读取配置信息。

具体的工作如下：

1. 设置容器的环境变量、给容器绑定`Volume`、给容器绑定`Port`、根据指定的`Pod`运行一个单一容器、给指定的`Pod`创建`network`。

2. 同步`Pod`的状态、同步`Pod`的状态、从`cAdvisor`获取`container info`、 `pod info`、 `root info`、 `machine info`。

3. 在容器中运行命令、杀死容器、删除Pod的所有容器。

## Proxy[负载均衡、路由转发]

`Proxy`是为了解决外部网络能够访问跨机器集群中容器提供的应用服务而设计的，运行在每个`Node`上。

`Proxy`提供`TCP/UDP sockets`的`proxy`
1. 每创建一种`Service`，`Proxy`主要从`etcd`获取`Services`和`Endpoints`的配置信息（也可以从`file`获取）
2. 然后根据配置信息在`Node`上启动一个`Proxy`的进程并监听相应的服务端口
3. 当外部请求发生时，`Proxy`会根据`Load Balancer`将请求分发到后端正确的容器处理。

`Proxy`不但解决了同一主宿机相同服务端口冲突的问题，还提供了`Service`转发服务端口对外提供服务的能力，`Proxy`后端使用了随机、轮循负载均衡算法。

## kubectl [集群管理命令行工具集]

通过客户端的`kubectl`命令集操作，`API Server`响应对应的命令结果，从而达到对`kubernetes`集群的管理
