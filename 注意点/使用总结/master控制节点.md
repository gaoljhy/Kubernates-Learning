# master

## 工作流程

> 参考图工作流程

1. `Kubecfg`将特定的请求，比如创建`Pod`，发送给`Kubernetes Client`。

2. `Kubernetes Client`将请求发送给`API server`。

3. `API Server`根据请求的类型，比如创建`Pod`时`storage`类型是`pods`，然后依此选择何种`REST Storage API`对请求作出处理。

3. `REST Storage API`对的请求作相应的处理。

4. 将处理的结果存入高可用键值存储系统`Etcd`中。

5. 在`API Server`响应`Kubecfg`的请求后，`Scheduler`会根据`Kubernetes Client`获取集群中运行`Pod`及`Minion/Node`信息。

6. 依据从`Kubernetes Client`获取的信息，`Scheduler`将未分发的`Pod`分发到可用的`Minion/Node`节点上。


##　API Server[资源操作入口]

1. 提供了资源对象的唯一操作入口，其他所有组件都必须通过它提供的 `API` 来操作资源数据，只有 `API Server` 与**存储通信**，其他模块通过 `API Server` 访问集群状态。

    1. 第一，是为了保证集群状态访问的安全。

    2. 第二，是为了隔离集群状态访问的方式和后端存储实现的方式：API Server是状态访问的方式，不会因为后端存储技术etcd的改变而改变。

2. 作为`kubernetes`系统的入口，封装了核心对象的 **增删改查** 操作，以 `RESTFul` 接口方式提供给外部客户和内部组件调用。对相关的资源数据 `全量查询` + `变化监听`，实时完成相关的业务功能。


## Controller Manager[内部管理控制中心]

实现集群**故障检测**和**恢复**的自动化工作，负责执行各种控制器，主要有：

1. `endpoint-controller`：定期关联`service`和`pod`(关联信息由`endpoint`对象维护)，保证`service`到`pod`的映射总是最新的。

2. `replication-controller`：定期关联`replicationController`和`pod`，保证replicationController定义的复制数量与实际运行pod的数量总是一致的。


## Scheduler[集群分发调度器]

1. `Scheduler`收集和分析当前`Kubernetes`集群中所有`Minion/Node`节点的资源(内存、CPU)负载情况，然后依此分发新建的`Pod`到`Kubernetes`集群中可用的节点。

2. 实时监测`Kubernetes`集群中未分发和已分发的所有运行的`Pod`。

3. `Scheduler`也监测`Minion/Node`节点信息，由于会频繁查找`Minion/Node`节点，`Scheduler`会缓存一份最新的信息在本地。

4. 最后，`Scheduler`在分发`Pod`到指定的`Minion/Node`节点后，会把`Pod`相关的信息`Binding`写回`API Server`。
