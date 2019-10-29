# Services

> 服务是对应于 namespace 的网络路由

##　Overview（概述）

`Kubernetes Pod`会被创建，也会死掉，并且他们是不可复活的。

`ReplicationControllers` 动态的创建和销毁`Pods`(比如规模扩大或者缩小，或者执行动态更新)。

> 每个`pod`都由自己的`ip`，这些`IP`也随着时间的变化也不能持续依赖。

这样就引发了一个问题：如果一些`Pods`（让我们叫它作后台，后端）提供了一些功能供其它的`Pod`使用（让我们叫作前台），在`kubernete`集群中是如何实现让这些前台能够持续的追踪到这些后台的?

答案是：`Service`

## 示例

`Kubernete Service` 是一个定义了一组`Pod`的策略的抽象，也有时候叫做宏观服务。

这些被服务标记的`Pod`都是（一般）通过`label Selector`决定的（下面会讲到为什么需要一个没有`label selector`的服务）

举个例子

假设后台是一个图形处理的后台，并且由3个副本。
这些副本是可以相互替代的，并且前台不需要关心使用的哪一个后台`Pod`，当这个承载前台请求的`pod`发生变化时，前台并不需要直到这些变化，或者追踪后台的这些副本，服务是这些的去耦

##　作用

1. 对于`Kubernete`原生的应用，`Kubernete`提供了一个简单的`Endpoints API`，这个`Endpoints api`的作用就是当一个服务中的`pod`发生变化时，`Endpoints API`随之变化

2. 对于不是原生的程序，`Kubernetes`提供了一个基于虚拟`IP`的网桥的服务，这个服务会将请求转发到对应的后台`pod`

##　Defining a service(定义一个服务)

一个`Kubernete`服务是一个最小的对象，类似`pod`

和其它的终端对象一样,可以发送请求来创建一个新的实例

比如，假设拥有一些`Pod`,每个`pod`都开放了`9376`端口，并且均带有一个标签`app=MyApp`

```json
{
“kind”: “Service”,
“apiVersion”: “v1”,
  “metadata”: {
    “name”: “my-service”
  },
  “spec”: {
    “selector”: {
      “app”: “MyApp”
    },
    “ports”: [
      {
      “protocol”: “TCP”,
      “port”: 80,
      “targetPort”: 9376
      }
    ]
  }
}
```

1. 这段代码会创建一个新的服务对象，名称为：`my-service`
2. 并且会连接带有`label app=MyApp`的`pod`目标端口`9376`
3. 这个服务会被分配一个`ip`地址，这个`ip`是给服务代理使用的（下面会看到）
4. 服务的选择器会持续的评估，并且结果会被发送到一个`Endpoints` 对象，这个`Endpoints`的对象的名字也叫`my-service`.

### 注解

服务可以将一个`入端口`转发到任何`目标端口`
    默认情况下`targetPort`的值会和`port`的值相同

`targetPort`可以是字符串，可以指定到一个`name`,这个`name`是`pod`的一个端口。
    并且实际指派给这个`name`的端口可以是在不同的后台`pod`中，这样能更加灵活的部署服务

比如
    可以在下一个更新版本中修改后台`pod`暴露的端口而不会影响客户的使用（更新过程不会打断）

服务支持`tcp`和`UDP`，但是默认的是`TCP`

## Services without selectors（没有选择器的服务）

服务总体上抽象了对`Pod`的访问，但是服务也抽象了其它的内容

比如：

1. 比如希望有一个额外的数据库云在生产环境中，但是在测试的时候，希望使用自己的数据库

2. 希望将服务指向其它的服务或者其它命名空间或者其它的云平台上的服务

3. 正在向kubernete迁移，并且后台并没有在`Kubernete`中

如上的情况下，可以定义一个服务没有选择器

```json
{
    “kind”: “Service”,
    “apiVersion”: “v1″,
    “metadata”: {
        “name”: “my-service”
    },
    “spec”: {
        “ports”: [
            {
            “protocol”: “TCP”,
            “port”: 80,
            “targetPort”: 9376
            }
        ]
    }
}
```

因为没有**选择器**，所以相应的`Endpoints`对象就不会被创建，但是可以手动把的服务和`Endpoints`对应起来

```json
{
“kind”: “Endpoints”,
“apiVersion”: “v1″,
“metadata”: {
    “name”: “my-service”
},
“subsets”: [
        {
            “addresses”: [
                { “IP”: “1.2.3.4” }
            ],
            “ports”: [
                { “port”: 80 }
            ]
        }
    ]
}
```

这样的话，这个服务虽然没有`selector`，但是却可以正常工作，所有的请求都会被转发到`1.2.3.4:80`

## Virtual IPs and service proxies（虚拟IP和服务代理）

每一个`Node`节点上都运行了一个`kube-proxy`

这个应用监控着`Kubermaster`增加和删除服

1. 对于每一个服务，`kube-proxy`会随机开启一个本机端口
2. 任何发向这个端口的请求都会被转发到一个后台的`Pod`当中，而如何选择是哪一个后台的`pod`的是基于`SessionAffinity`进行的分配。
`kube-proxy`会增加`iptables rules`来实现捕捉这个服务的`Ip`和**端口**来并重定向到前面提到的端口。

最终的结果就是所有的对于这个服务的请求都会被转发到后台的`Pod`中，这一过程用户根本察觉不到


默认的，后台的选择是**随机**的，基于用户`session`机制的策略可以通过修改`service.spec.sessionAffinity` 的值从`NONE`到`ClientIP`

## Multi-Port Services（多端口服务）

可能很多服务需要开发不止一个端口

为了满足这样的情况，`Kubernetes`允许在定义时候指定多个端口，当我们使用多个端口的时候，我们需要指定所有端口的名称，这样endpoints才能清楚

例如

```json
{
“kind”: “Service”,
“apiVersion”: “v1”,
“metadata”: {
    “name”: “my-service”
},
“spec”: {
    “selector”: {
    “app”: “MyApp”
    },
    “ports”: [
        {
        “name”: “http”,
        “protocol”: “TCP”,
        “port”: 80,
        “targetPort”: 9376
        },
        {
            “name”: “https”,
            “protocol”: “TCP”,
            “port”: 443,
            “targetPort”: 9377
        }
    ]
}
}
```

###　选择自己的IP地址

可以在创建服务的时候指定`IP`地址

将`spec.clusterIP`的值设定为想要的`IP`地址即可。

例如
已经有一个`DNS`域希望用来替换，或者遗留系统只能对指定`IP`提供服务，并且这些都非常难修改
用户选择的`IP`地址必须是一个有效的`IP`地址
并且要在`API server`分配的IP范围内
如果这个`IP`地址是不可用的，`apiserver`会返回`422` http错误代码来告知是IP地址不可用

### 为什么不使用循环的DNS

一个问题持续的被提出来，这个问题就是我们为什么不使用标准的循环DNS而使用虚拟IP，主要有如下几个原因

1. DNS不遵循`TTL`查询和缓存`name`查询的问题由来已久（这个还真不知道，就是DNS更新的问题估计）

2. 许多的应用的`DNS`查询查询一次后就缓存起来

3. 即使如上亮点被解决了，但是不停的进行`DNS`进行查询，大量的请求也是很难被管理的

> 阻止用户使用这些可能会“伤害”他们的事情，但是如果足够多的人要求这么作，那么将对此提供支持，来作为一个可选项.


## Discovering services（服务的发现）

Kubernetes 支持两种方式的来发现服务 ，**环境变量** 和 `DNS`

### 环境变量

当一个`Pod`在一个`node`上运行时

`kubelet` 会针对运行的服务增加一系列的环境变量，它支持`Docker links compatible` 和`普通环境变量`

举例子来说：

`redis-master`服务暴露了 `TCP` `6379`端口，并且被分配了`10.0.0.11` IP地址

那么就会有如下的环境变量

```sh
REDIS_MASTER_SERVICE_HOST=10.0.0.11

REDIS_MASTER_SERVICE_PORT=6379

REDIS_MASTER_PORT=tcp://10.0.0.11:6379

REDIS_MASTER_PORT_6379_TCP=tcp://10.0.0.11:6379

REDIS_MASTER_PORT_6379_TCP_PROTO=tcp

REDIS_MASTER_PORT_6379_TCP_PORT=6379

REDIS_MASTER_PORT_6379_TCP_ADDR=10.0.0.11
```

这样的话，对系统有一个要求：
所有的想要被`POD`访问的服务，必须在`POD`创建之前创建，否则这个环境变量不会被填充，使用`DNS`则没有这个问题

### DNS

一个可选择的云平台插件就是`DNS`

`DNS` 服务器监控着`API SERVER`,当有服务被创建的时候，`DNS` 服务器会为之创建相应的记录，如果`DNS`这个服务被添加了，那么`Pod`应该是可以自动解析服务的。

举个例子

如果在`my-ns`命名空间下有一个服务叫做`my-service`
这个时候`DNS`就会创建一个`my-service.my-ns`的记录，所有`my-ns`命名空间下的`Pod`,都可以通过域名`my-service`查询找到对应的`ip`地址

同一namespace下的不同`Pod`查找是必须使用`my-sesrvice.my-ns`才可以。

`Kubernete` 同样支持端口的解析，如果`my-service`有一个提供`http`的`TCP`主持的端口，那么可以通过查询`_http._tcp.my-service.my-ns`来查询这个端口

##　Headless services

有时候可能不需要一个固定的`IP`和分发，这个时候只需要将`spec.cluster`IP的值设置为`none`就可以了

对于这样的服务来说，集群`IP`没有分配，这个时候当查询服务的名称的时候，`DNS`会返回多个`A`记录，这些记录都是指向后端`Pod`的。

`Kube` 代理不会处理这个服务，在服务的前端也没有负载均衡器。
但是`endpoints controller`还是会创建`Endpoints`


This option allows developers to reduce coupling to the Kubernetes system, if they desire, but leaves them freedom to do discovery in their own way. Applications can still use a self-registration pattern and adapters for other discovery systems could easily be built upon this API.

##　External services（外部服务）

对于应用程序来说，可能有一部分是放在`Kubernete`外部的（比如有单独的物理机来承担数据库的角色）

`Kubernetes`支持两种方式：`NodePorts`，`LoadBalancers`

每一个服务都会有一个字段定义了该服务如何被调用（发现），这个字段的值可以为：

1. `ClusterIP`:使用一个集群固定IP，这个是默认选项
2. `NodePort`：使用一个集群固定IP，但是额外在每个`POD`上均暴露这个服务，端口
3. `LoadBalancer`：使用集群固定IP，和`NODEPord`,额外还会申请申请一个负载均衡器来转发到服务（load balancer ）
    > 注意：`NodePort` 支持`TCP`和`UDN`，但是`LoadBalancers`在1.0版本只支持TCP

### Type NodePort

如果你选择了“NodePort”，那么 Kubernetes master 会分配一个区域范围内，（默认是30000-32767），并且，每一个node，都会代理（proxy）这个端口到你的服务中，我们可以在spec.ports[*].nodePort 找到具体的值

如果我们向指定一个端口，我们可以直接写在nodePort上，系统就会给你指派指定端口，但是这个值必须是指定范围内的。

这样的话就能够让开发者搭配自己的负载均衡器，去撘建一个kubernete不是完全支持的系统，又或者是直接暴露一个node的ip地址

Type LoadBalancer
在支持额外的负载均衡器的的平台上，将值设置为LoadBalancer会提供一个负载均衡器给你的服务，负载均衡器的创建其实是异步的。下面的例子

{

“kind”: “Service”,

“apiVersion”: “v1″,

“metadata”: {

“name”: “my-service”

},

“spec”: {

“selector”: {

“app”: “MyApp”

},

“ports”: [

{

“protocol”: “TCP”,

“port”: 80,

“targetPort”: 9376,

“nodePort”: 30061

}

],

“clusterIP”: “10.0.171.239”,

“type”: “LoadBalancer”

},

“status”: {

“loadBalancer”: {

“ingress”: [

{

“ip”: “146.148.47.155”

}

]

}

}

}

所有服务的请求均会直接到到Pod,具体是如何工作的是由平台决定的

缺点

我们希望使用IPTABLES和用户命名空间来代理虚拟IP能在中小型规模的平台上正常运行，但是可能出现问题在比较大的平台上当应对成千上万的服务的时候。

这个时候，使用kube-proxy来封装服务的请求，这使得这些变成可能

LoadBalancers 只支持TCP，不支持UDP

Type 的值是设定好的，不同的值代表不同的功能，并不是所有的平台都需要的，但是是所有API需要的

Future work
在将来，我们预想proxy的策略能够更加细致，不再是单纯的转发，比如master-elected or sharded，我们预想将来服务会拥有真正的负载均衡器，到时候虚拟IP直接转发到负载均衡器

将来有倾向与将所的工作均通过iptables来进行，从而小从用户命名空间代理，这样的话会有更好的性能和消除一些原地值IP的问题，尽管这样的会减少一些灵活性.

更多讨论：QQ交流群  513817976  入群暗号: kubernetes.org.cn

更多请参考：http://kubernetes.io/docs/user-guide/services/#future-work