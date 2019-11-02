# Node

`Node`是`Pod`真正运行的主机，可以物理机，也可以是虚拟机。

为了管理`Pod`，每个`Node`节点上至少要运行`container runtime`（比如`docker`或者`rkt`）、`kubelet`和`kube-proxy`服务。

## Node管理

> 不像其他的资源（如`Pod`和`Namespace`）

`Node`本质上不是`Kubernetes`来创建的，`Kubernetes`只是管理Node上的资源。

虽然可以通过`Manifest`创建一个Node对象（如下`json`所示），但`Kubernetes`也只是去检查是否真的是有这么一个`Node`，如果检查失败，也不会往上调度`Pod`。

```json
{
  "kind": "Node",
  "apiVersion": "v1",
  "metadata": {
    "name": "10.240.79.157",
    "labels": {
      "name": "my-first-k8s-node"
    }
  }
}
```

这个检查是由`Node Controller`来完成的。

## `Node Controller`负责

1. 维护Node状态
2. 与`Cloud Provider`同步Node
3. 给`Node`分配容器CIDR
4. 删除带有`NoExecute taint`的`Node`上的`Pods`

默认情况下，`kubelet`在启动时会向`master`注册自己，并创建`Node`资源。

## Node的状态

每个`Node`都包括以下状态信息

1. 地址：包括`hostname`、外网`IP`和内网`IP`
2. 条件（Condition）：包括OutOfDisk、Ready、MemoryPressure和DiskPressure
3. 容量（Capacity）：Node上的可用资源，包括CPU、内存和Pod总数
4. 基本信息（Info）：包括内核版本、容器引擎版本、OS类型等

## Taints和tolerations

`Taints`和`tolerations`用于保证`Pod`不被调度到不合适的`Node`上

> `Taint`应用于Node上，而`toleration`则应用于Pod上（`Toleration`是可选的）。

比如，可以使用`taint`命令给`node1`添加`taints`：

`kubectl taint nodes node1 key1=value1:NoSchedule`
`kubectl taint nodes node1 key1=value2:NoExecute`

> `Taints`和`tolerations`的具体使用方法请参考调度器章节。

## Node维护模式

标志`Node`不可调度但不影响其上正在运行的`Pod`，这种维护`Node`时是非常有用的

`kubectl cordon $NODENAME`