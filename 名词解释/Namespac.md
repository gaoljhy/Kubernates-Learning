# 名词解释：Namespace

`Namespace`是对一组**资源**和**对象**的抽象集合，比如可以用来将系统内部的对象划分为不同的项目组或用户组。

常见的`pods`, `services`, `replication controllers`和`deployments`等都是属于某一个`namespace`的（默认是`default`,不可删除）

而`node`, `persistentVolumes`等则不属于任何`namespace`。

`Namespace`常用来隔离不同的用户
    比如`Kubernetes`自带的服务一般运行在`kube-system namespace`中。

## Namespace操作

`kubectl`可以通过`–namespace`或者`-n`选项指定`namespace`。

如果不指定，默认为`default`。

查看操作下,也可以通过设置`–all-namespace=true`来查看所有`namespace`下的资源。

### 查询

```sh
$ kubectl get namespaces
NAME          STATUS    AGE
default       Active    11d
kube-system   Active    11d
```

注意：`namespace`包含两种状态`Active`和`Terminating`。
> 在`namespace`删除过程中，`namespace`状态被设置成`Terminating`。

### 创建

1. 命令行直接创建

`kubectl create namespace new-namespace`

2. 通过文件创建

`$ cat my-namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: new-namespace
```

`$ kubectl create -f ./my-namespace.yaml`

注意：命名空间名称满足正则表达式`[a-z0-9]([-a-z0-9]*[a-z0-9])?`,最大长度为`63`位

### 删除

`$ kubectl delete namespaces new-namespace`

注意：

删除一个`namespace`会自动删除所有属于该`namespace`的资源。

`default`和`kube-system`命名空间不可删除。

参考：<https://feisky.gitbooks.io/kubernetes/concepts/namespace.html>