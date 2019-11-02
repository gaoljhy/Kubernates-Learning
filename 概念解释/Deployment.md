# 名称解释：Deployment

## 简述

`Deployment`为`Pod`和`ReplicaSet`提供了一个声明式定义(`declarative`)方法，用来替代以前的`ReplicationController`来方便的管理应用。


典型的应用场景包括：

1. 定义Deployment来创建Pod和ReplicaSet
2. 滚动升级和回滚应用
3. 扩容和缩容
4. 暂停和继续Deployment

比如一个简单的nginx应用可以定义为

```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80

```

### 扩容：

`kubectl scale deployment nginx-deployment --replicas 10`

如果集群支持 `horizontal pod autoscaling` 的话，还可以为`Deployment`设置自动扩展：

`kubectl autoscale deployment nginx-deployment --min=10 --max=15 --cpu-percent=80`

### 更新镜像也比较简单:

`kubectl set image deployment/nginx-deployment nginx=nginx:1.9.1`

### 回滚：

`kubectl rollout undo deployment/nginx-deployment`

Deployment概念详细解析

本文翻译自kubernetes官方文档：<https://github.com/kubernetes/kubernetes.github.io/blob/master/docs/concepts/workloads/controllers/deployment.md>

## Deployment是什么

`Deployment`为`Pod`和`Replica Set`（下一代Replication Controller）提供声明式更新。

只需要在`Deployment`中描述你想要的目标状态是什么，`Deployment controller`就会帮`Pod`和`Replica Set`的实际状态改变到你的目标状态。

你可以定义一个全新的`Deployment`，也可以创建一个新的替换旧的`Deployment`。

一个典型的用例如下：

使用`Deployment`来创建`ReplicaSet`。
`ReplicaSet`在后台创建`pod`。检查启动状态，看它是成功还是失败。
然后，通过更新Deployment的PodTemplateSpec字段来声明Pod的新状态。这会创建一个新的ReplicaSet，Deployment会按照控制的速率将pod从旧的ReplicaSet移动到新的ReplicaSet中。
如果当前状态不稳定，回滚到之前的Deployment revision。每次回滚都会更新Deployment的revision。
扩容Deployment以满足更高的负载。
暂停Deployment来应用PodTemplateSpec的多个修复，然后恢复上线。
根据Deployment 的状态判断上线是否hang住了。
清除旧的不必要的ReplicaSet。
创建Deployment
下面是一个Deployment示例，它创建了一个Replica Set来启动3个nginx pod。

下载示例文件并执行命令：

$ kubectl create -f docs/user-guide/nginx-deployment.yaml --record
deployment "nginx-deployment" created
将kubectl的 —record 的flag设置为 true可以在annotation中记录当前命令创建或者升级了该资源。这在未来会很有用，例如，查看在每个Deployment revision中执行了哪些命令。

然后立即执行getí将获得如下结果：

$ kubectl get deployments
NAME               DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3         0         0            0           1s
输出结果表明我们希望的repalica数是3（根据deployment中的.spec.replicas配置）当前replica数（ .status.replicas）是0, 最新的replica数（.status.updatedReplicas）是0，可用的replica数（.status.availableReplicas）是0。

过几秒后再执行get命令，将获得如下输出：

$ kubectl get deployments
NAME               DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3         3         3            3           18s
我们可以看到Deployment已经创建了3个replica，所有的replica都已经是最新的了（包含最新的pod template），可用的（根据Deployment中的.spec.minReadySeconds声明，处于已就绪状态的pod的最少个数）。执行kubectl get rs和kubectl get pods会显示Replica Set（RS）和Pod已创建。

$ kubectl get rs
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-2035384211   3         3         0       18s
你可能会注意到Replica Set的名字总是<Deployment的名字>-<pod template的hash值>。

$ kubectl get pods --show-labels
NAME                                READY     STATUS    RESTARTS   AGE       LABELS
nginx-deployment-2035384211-7ci7o   1/1       Running   0          18s       app=nginx,pod-template-hash=2035384211
nginx-deployment-2035384211-kzszj   1/1       Running   0          18s       app=nginx,pod-template-hash=2035384211
nginx-deployment-2035384211-qqcnn   1/1       Running   0          18s       app=nginx,pod-template-hash=2035384211
刚创建的Replica Set将保证总是有3个nginx的pod存在。

注意： 你必须在Deployment中的selector指定正确pod template label（在该示例中是 app = nginx），不要跟其他的controller搞混了（包括Deployment、Replica Set、Replication Controller等）。Kubernetes本身不会阻止你这么做，如果你真的这么做了，这些controller之间会相互打架，并可能导致不正确的行为。

更新Deployment
注意： Deployment的rollout当且仅当Deployment的pod template（例如.spec.template）中的label更新或者镜像更改时被触发。其他更新，例如扩容Deployment不会触发rollout。

假如我们现在想要让nginx pod使用nginx:1.9.1的镜像来代替原来的nginx:1.7.9的镜像。

$ kubectl set image deployment/nginx-deployment nginx=nginx:1.9.1
deployment "nginx-deployment" image updated
我们可以使用edit命令来编辑Deployment，修改 .spec.template.spec.containers[0].image ，将nginx:1.7.9 改写成nginx:1.9.1。

$ kubectl edit deployment/nginx-deployment
deployment "nginx-deployment" edited
查看rollout的状态，只要执行：

$ kubectl rollout status deployment/nginx-deployment
Waiting for rollout to finish: 2 out of 3 new replicas have been updated...
deployment "nginx-deployment" successfully rolled out
Rollout成功后，get Deployment：

$ kubectl get deployments
NAME               DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3         3         3            3           36s
UP-TO-DATE的replica的数目已经达到了配置中要求的数目。

CURRENT的replica数表示Deployment管理的replica数量，AVAILABLE的replica数是当前可用的replica数量。

We can run kubectl get rs to see that the Deployment updated the Pods by creating a new Replica Set and scaling it up to 3 replicas, as well as scaling down the old Replica Set to 0 replicas.

我们通过执行kubectl get rs可以看到Deployment更新了Pod，通过创建一个新的Replica Set并扩容了3个replica，同时将原来的Replica Set缩容到了0个replica。

$ kubectl get rs
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-1564180365   3         3         0       6s
nginx-deployment-2035384211   0         0         0       36s
执行 get pods只会看到当前的新的pod:

$ kubectl get pods
NAME                                READY     STATUS    RESTARTS   AGE
nginx-deployment-1564180365-khku8   1/1       Running   0          14s
nginx-deployment-1564180365-nacti   1/1       Running   0          14s
nginx-deployment-1564180365-z9gth   1/1       Running   0          14s
下次更新这些pod的时候，只需要更新Deployment中的pod的template即可。

Deployment可以保证在升级时只有一定数量的Pod是down的。默认的，它会确保至少有比期望的Pod数量少一个的Pod是up状态（最多一个不可用）。

Deployment同时也可以确保只创建出超过期望数量的一定数量的Pod。默认的，它会确保最多比期望的Pod数量多一个的Pod是up的（最多1个surge）。

在未来的Kuberentes版本中，将从1-1变成25%-25%）。

例如，如果你自己看下上面的Deployment，你会发现，开始创建一个新的Pod，然后删除一些旧的Pod再创建一个新的。当新的Pod创建出来之前不会杀掉旧的Pod。这样能够确保可用的Pod数量至少有2个，Pod的总数最多4个。

$ kubectl describe deployments
Name:           nginx-deployment
Namespace:      default
CreationTimestamp:  Tue, 15 Mar 2016 12:01:06 -0700
Labels:         app=nginx
Selector:       app=nginx
Replicas:       3 updated | 3 total | 3 available | 0 unavailable
StrategyType:       RollingUpdate
MinReadySeconds:    0
RollingUpdateStrategy:  1 max unavailable, 1 max surge
OldReplicaSets:     <none>
NewReplicaSet:      nginx-deployment-1564180365 (3/3 replicas created)
Events:
  FirstSeen LastSeen    Count   From                     SubobjectPath   Type        Reason              Message
  --------- --------    -----   ----                     -------------   --------    ------              -------
  36s       36s         1       {deployment-controller }                 Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-2035384211 to 3
  23s       23s         1       {deployment-controller }                 Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-1564180365 to 1
  23s       23s         1       {deployment-controller }                 Normal      ScalingReplicaSet   Scaled down replica set nginx-deployment-2035384211 to 2
  23s       23s         1       {deployment-controller }                 Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-1564180365 to 2
  21s       21s         1       {deployment-controller }                 Normal      ScalingReplicaSet   Scaled down replica set nginx-deployment-2035384211 to 0
  21s       21s         1       {deployment-controller }                 Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-1564180365 to 3
我们可以看到当我们刚开始创建这个Deployment的时候，创建了一个Replica Set（nginx-deployment-2035384211），并直接扩容到了3个replica。

当我们更新这个Deployment的时候，它会创建一个新的Replica Set（nginx-deployment-1564180365），将它扩容到1个replica，然后缩容原先的Replica Set到2个replica，此时满足至少2个Pod是可用状态，同一时刻最多有4个Pod处于创建的状态。

接着继续使用相同的rolling update策略扩容新的Replica Set和缩容旧的Replica Set。最终，将会在新的Replica Set中有3个可用的replica，旧的Replica Set的replica数目变成0。

Rollover（多个rollout并行）
每当Deployment controller观测到有新的deployment被创建时，如果没有已存在的Replica Set来创建期望个数的Pod的话，就会创建出一个新的Replica Set来做这件事。已存在的Replica Set控制label匹配.spec.selector但是template跟.spec.template不匹配的Pod缩容。最终，新的Replica Set将会扩容出.spec.replicas指定数目的Pod，旧的Replica Set会缩容到0。

如果你更新了一个的已存在并正在进行中的Deployment，每次更新Deployment都会创建一个新的Replica Set并扩容它，同时回滚之前扩容的Replica Set——将它添加到旧的Replica Set列表，开始缩容。

例如，假如你创建了一个有5个niginx:1.7.9 replica的Deployment，但是当还只有3个nginx:1.7.9的replica创建出来的时候你就开始更新含有5个nginx:1.9.1 replica的Deployment。在这种情况下，Deployment会立即杀掉已创建的3个nginx:1.7.9的Pod，并开始创建nginx:1.9.1的Pod。它不会等到所有的5个nginx:1.7.9的Pod都创建完成后才开始改变航道。

回退Deployment
有时候你可能想回退一个Deployment，例如，当Deployment不稳定时，比如一直crash looping。

默认情况下，kubernetes会在系统中保存前两次的Deployment的rollout历史记录，以便你可以随时会退（你可以修改revision history limit来更改保存的revision数）。ß

注意： 只要Deployment的rollout被触发就会创建一个revision。也就是说当且仅当Deployment的Pod template（如.spec.template）被更改，例如更新template中的label和容器镜像时，就会创建出一个新的revision。

其他的更新，比如扩容Deployment不会创建revision——因此我们可以很方便的手动或者自动扩容。这意味着当你回退到历史revision是，直邮Deployment中的Pod template部分才会回退。

假设我们在更新Deployment的时候犯了一个拼写错误，将镜像的名字写成了nginx:1.91，而正确的名字应该是nginx:1.9.1：

$ kubectl set image deployment/nginx-deployment nginx=nginx:1.91
deployment "nginx-deployment" image updated
Rollout将会卡住。

$ kubectl rollout status deployments nginx-deployment
Waiting for rollout to finish: 2 out of 3 new replicas have been updated...
按住Ctrl-C停止上面的rollout状态监控。

你会看到旧的replicas（nginx-deployment-1564180365 和 nginx-deployment-2035384211）和新的replicas （nginx-deployment-3066724191）数目都是2个。

$ kubectl get rs
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-1564180365   2         2         0       25s
nginx-deployment-2035384211   0         0         0       36s
nginx-deployment-3066724191   2         2         2       6s
看下创建Pod，你会看到有两个新的呃Replica Set创建的Pod处于ImagePullBackOff状态，循环拉取镜像。

$ kubectl get pods
NAME                                READY     STATUS             RESTARTS   AGE
nginx-deployment-1564180365-70iae   1/1       Running            0          25s
nginx-deployment-1564180365-jbqqo   1/1       Running            0          25s
nginx-deployment-3066724191-08mng   0/1       ImagePullBackOff   0          6s
nginx-deployment-3066724191-eocby   0/1       ImagePullBackOff   0          6s
注意，Deployment controller会自动停止坏的rollout，并停止扩容新的Replica Set。

$ kubectl describe deployment
Name:           nginx-deployment
Namespace:      default
CreationTimestamp:  Tue, 15 Mar 2016 14:48:04 -0700
Labels:         app=nginx
Selector:       app=nginx
Replicas:       2 updated | 3 total | 2 available | 2 unavailable
StrategyType:       RollingUpdate
MinReadySeconds:    0
RollingUpdateStrategy:  1 max unavailable, 1 max surge
OldReplicaSets:     nginx-deployment-1564180365 (2/2 replicas created)
NewReplicaSet:      nginx-deployment-3066724191 (2/2 replicas created)
Events:
  FirstSeen LastSeen    Count   From                    SubobjectPath   Type        Reason              Message
  --------- --------    -----   ----                    -------------   --------    ------              -------
  1m        1m          1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-2035384211 to 3
  22s       22s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-1564180365 to 1
  22s       22s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled down replica set nginx-deployment-2035384211 to 2
  22s       22s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-1564180365 to 2
  21s       21s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled down replica set nginx-deployment-2035384211 to 0
  21s       21s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-1564180365 to 3
  13s       13s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-3066724191 to 1
  13s       13s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled down replica set nginx-deployment-1564180365 to 2
  13s       13s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-3066724191 to 2
为了修复这个问题，我们需要回退到稳定的Deployment revision。

检查Deployment升级的历史记录
首先，检查下Deployment的revision：

$ kubectl rollout history deployment/nginx-deployment
deployments "nginx-deployment":
REVISION    CHANGE-CAUSE
1           kubectl create -f docs/user-guide/nginx-deployment.yaml --record
2           kubectl set image deployment/nginx-deployment nginx=nginx:1.9.1
3           kubectl set image deployment/nginx-deployment nginx=nginx:1.91
因为我们创建Deployment的时候使用了—recored参数可以记录命令，我们可以很方便的查看每次revison的变化。

查看单个revision的详细信息：

$ kubectl rollout history deployment/nginx-deployment --revision=2
deployments "nginx-deployment" revision 2
  Labels:       app=nginx
          pod-template-hash=1159050644
  Annotations:  kubernetes.io/change-cause=kubectl set image deployment/nginx-deployment nginx=nginx:1.9.1
  Containers:
   nginx:
    Image:      nginx:1.9.1
    Port:       80/TCP
     QoS Tier:
        cpu:      BestEffort
        memory:   BestEffort
    Environment Variables:      <none>
  No volumes.
回退到历史版本
现在，我们可以决定回退当前的rollout到之前的版本：

$ kubectl rollout undo deployment/nginx-deployment
deployment "nginx-deployment" rolled back
也可以使用 --revision参数指定某个历史版本：

$ kubectl rollout undo deployment/nginx-deployment --to-revision=2
deployment "nginx-deployment" rolled back
与rollout相关的命令详细文档见kubectl rollout。

该Deployment现在已经回退到了先前的稳定版本。如你所见，Deployment controller产生了一个回退到revison 2的DeploymentRollback的event。

$ kubectl get deployment
NAME               DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3         3         3            3           30m

$ kubectl describe deployment
Name:           nginx-deployment
Namespace:      default
CreationTimestamp:  Tue, 15 Mar 2016 14:48:04 -0700
Labels:         app=nginx
Selector:       app=nginx
Replicas:       3 updated | 3 total | 3 available | 0 unavailable
StrategyType:       RollingUpdate
MinReadySeconds:    0
RollingUpdateStrategy:  1 max unavailable, 1 max surge
OldReplicaSets:     <none>
NewReplicaSet:      nginx-deployment-1564180365 (3/3 replicas created)
Events:
  FirstSeen LastSeen    Count   From                    SubobjectPath   Type        Reason              Message
  --------- --------    -----   ----                    -------------   --------    ------              -------
  30m       30m         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-2035384211 to 3
  29m       29m         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-1564180365 to 1
  29m       29m         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled down replica set nginx-deployment-2035384211 to 2
  29m       29m         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-1564180365 to 2
  29m       29m         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled down replica set nginx-deployment-2035384211 to 0
  29m       29m         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-3066724191 to 2
  29m       29m         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-3066724191 to 1
  29m       29m         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled down replica set nginx-deployment-1564180365 to 2
  2m        2m          1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled down replica set nginx-deployment-3066724191 to 0
  2m        2m          1       {deployment-controller }                Normal      DeploymentRollback  Rolled back deployment "nginx-deployment" to revision 2
  29m       2m          2       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-1564180365 to 3
清理Policy
你可以通过设置.spec.revisonHistoryLimit项来指定deployment最多保留多少revison历史记录。默认的会保留所有的revision；如果将该项设置为0，Deployment就不允许回退了。

Deployment扩容
你可以使用以下命令扩容Deployment：

$ kubectl scale deployment nginx-deployment --replicas 10
deployment "nginx-deployment" scaled
假设你的集群中启用了horizontal pod autoscaling，你可以给Deployment设置一个autoscaler，基于当前Pod的CPU利用率选择最少和最多的Pod数。

$ kubectl autoscale deployment nginx-deployment --min=10 --max=15 --cpu-percent=80
deployment "nginx-deployment" autoscaled
比例扩容
RollingUpdate Deployment支持同时运行一个应用的多个版本。当你活着autoscaler扩容RollingUpdate Deployment的时候，正在中途的rollout（进行中或者已经暂停的），为了降低风险，Deployment controller将会平衡已存在的活动中的ReplicaSets（有Pod的ReplicaSets）和新加入的replicas。这被称为比例扩容。

例如，你正在运行中含有10个replica的Deployment。maxSurge=3，maxUnavailable=2。

$ kubectl get deploy
NAME                 DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment     10        10        10           10          50s
你更新了一个镜像，而在集群内部无法解析。

$ kubectl set image deploy/nginx-deployment nginx=nginx:sometag
deployment "nginx-deployment" image updated
镜像更新启动了一个包含ReplicaSet nginx-deployment-1989198191的新的rollout，但是它被阻塞了，因为我们上面提到的maxUnavailable。

$ kubectl get rs
NAME                          DESIRED   CURRENT   READY     AGE
nginx-deployment-1989198191   5         5         0         9s
nginx-deployment-618515232    8         8         8         1m
然后发起了一个新的Deployment扩容请求。autoscaler将Deployment的repllica数目增加到了15个。Deployment controller需要判断在哪里增加这5个新的replica。如果我们没有谁用比例扩容，所有的5个replica都会加到一个新的ReplicaSet中。如果使用比例扩容，新添加的replica将传播到所有的ReplicaSet中。大的部分加入replica数最多的ReplicaSet中，小的部分加入到replica数少的ReplciaSet中。0个replica的ReplicaSet不会被扩容。

在我们上面的例子中，3个replica将添加到旧的ReplicaSet中，2个replica将添加到新的ReplicaSet中。rollout进程最终会将所有的replica移动到新的ReplicaSet中，假设新的replica成为健康状态。

$ kubectl get deploy
NAME                 DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment     15        18        7            8           7m
$ kubectl get rs
NAME                          DESIRED   CURRENT   READY     AGE
nginx-deployment-1989198191   7         7         0         7m
nginx-deployment-618515232    11        11        11        7m
暂停和恢复Deployment
你可以在出发一次或多次更新前暂停一个Deployment，然后再恢复它。这样你就能多次暂停和恢复Deployment，在此期间进行一些修复工作，而不会出发不必要的rollout。

例如使用刚刚创建Deployment：

$ kubectl get deploy
NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx     3         3         3            3           1m
[mkargaki@dhcp129-211 kubernetes]$ kubectl get rs
NAME               DESIRED   CURRENT   READY     AGE
nginx-2142116321   3         3         3         1m
使用以下命令暂停Deployment：

$ kubectl rollout pause deployment/nginx-deployment
deployment "nginx-deployment" paused
然后更新Deplyment中的镜像：

$ kubectl set image deploy/nginx nginx=nginx:1.9.1
deployment "nginx-deployment" image updated
注意新的rollout启动了：

$ kubectl rollout history deploy/nginx
deployments "nginx"
REVISION  CHANGE-CAUSE
1   <none>

$ kubectl get rs
NAME               DESIRED   CURRENT   READY     AGE
nginx-2142116321   3         3         3         2m
你可以进行任意多次更新，例如更新使用的资源：

$ kubectl set resources deployment nginx -c=nginx --limits=cpu=200m,memory=512Mi
deployment "nginx" resource requirements updated
Deployment暂停前的初始状态将继续它的功能，而不会对Deployment的更新产生任何影响，只要Deployment是暂停的。

最后，恢复这个Deployment，观察完成更新的ReplicaSet已经创建出来了：

$ kubectl rollout resume deploy nginx
deployment "nginx" resumed
$ KUBECTL get rs -w
NAME               DESIRED   CURRENT   READY     AGE
nginx-2142116321   2         2         2         2m
nginx-3926361531   2         2         0         6s
nginx-3926361531   2         2         1         18s
nginx-2142116321   1         2         2         2m
nginx-2142116321   1         2         2         2m
nginx-3926361531   3         2         1         18s
nginx-3926361531   3         2         1         18s
nginx-2142116321   1         1         1         2m
nginx-3926361531   3         3         1         18s
nginx-3926361531   3         3         2         19s
nginx-2142116321   0         1         1         2m
nginx-2142116321   0         1         1         2m
nginx-2142116321   0         0         0         2m
nginx-3926361531   3         3         3         20s
^C
$ KUBECTL get rs
NAME               DESIRED   CURRENT   READY     AGE
nginx-2142116321   0         0         0         2m
nginx-3926361531   3         3         3         28s
注意： 在恢复Deployment之前你无法回退一个暂停了个Deployment。

Deployment状态
Deployment在生命周期中有多种状态。在创建一个新的ReplicaSet的时候它可以是 progressing 状态， complete 状态，或者fail to progress状态。

Progressing Deployment
Kubernetes将执行过下列任务之一的Deployment标记为progressing状态：

Deployment正在创建新的ReplicaSet过程中。
Deployment正在扩容一个已有的ReplicaSet。
Deployment正在缩容一个已有的ReplicaSet。
有新的可用的pod出现。
你可以使用kubectl roullout status命令监控Deployment的进度。

Complete Deployment
Kubernetes将包括以下特性的Deployment标记为complete状态：

Deployment最小可用。最小可用意味着Deployment的可用replica个数等于或者超过Deployment策略中的期望个数。
所有与该Deployment相关的replica都被更新到了你指定版本，也就说更新完成。
该Deployment中没有旧的Pod存在。
你可以用kubectl rollout status命令查看Deployment是否完成。如果rollout成功完成，kubectl rollout status将返回一个0值的Exit Code。

$ kubectl rollout status deploy/nginx
Waiting for rollout to finish: 2 of 3 updated replicas are available...
deployment "nginx" successfully rolled out
$ echo $?
0
Failed Deployment
你的Deployment在尝试部署新的ReplicaSet的时候可能卡住，用于也不会完成。这可能是因为以下几个因素引起的：

无效的引用
不可读的probe failure
镜像拉取错误
权限不够
范围限制
程序运行时配置错误
探测这种情况的一种方式是，在你的Deployment spec中指定spec.progressDeadlineSeconds。spec.progressDeadlineSeconds表示Deployment controller等待多少秒才能确定（通过Deployment status）Deployment进程是卡住的。

下面的kubectl命令设置progressDeadlineSeconds 使controller在Deployment在进度卡住10分钟后报告：

$ kubectl patch deployment/nginx-deployment -p '{"spec":{"progressDeadlineSeconds":600}}'
"nginx-deployment" patched
Once the deadline has been exceeded, the Deployment controller adds a with the following attributes to the Deployment’s

当超过截止时间后，Deployment controller会在Deployment的 status.conditions中增加一条DeploymentCondition，它包括如下属性：

Type=Progressing
Status=False
Reason=ProgressDeadlineExceeded
浏览 Kubernetes API conventions 查看关于status conditions的更多信息。

注意： kubernetes除了报告Reason=ProgressDeadlineExceeded状态信息外不会对卡住的Deployment做任何操作。更高层次的协调器可以利用它并采取相应行动，例如，回滚Deployment到之前的版本。

注意： 如果你暂停了一个Deployment，在暂停的这段时间内kubernetnes不会检查你指定的deadline。你可以在Deployment的rollout途中安全的暂停它，然后再恢复它，这不会触发超过deadline的状态。

你可能在使用Deployment的时候遇到一些短暂的错误，这些可能是由于你设置了太短的timeout，也有可能是因为各种其他错误导致的短暂错误。例如，假设你使用了无效的引用。当你Describe Deployment的时候可能会注意到如下信息：

$ kubectl describe deployment nginx-deployment
<...>
Conditions:
  Type            Status  Reason
  ----            ------  ------
  Available       True    MinimumReplicasAvailable
  Progressing     True    ReplicaSetUpdated
  ReplicaFailure  True    FailedCreate
<...>
执行 kubectl get deployment nginx-deployment -o yaml，Deployement 的状态可能看起来像这个样子：

status:
  availableReplicas: 2
  conditions:
  - lastTransitionTime: 2016-10-04T12:25:39Z
    lastUpdateTime: 2016-10-04T12:25:39Z
    message: Replica set "nginx-deployment-4262182780" is progressing.
    reason: ReplicaSetUpdated
    status: "True"
    type: Progressing
  - lastTransitionTime: 2016-10-04T12:25:42Z
    lastUpdateTime: 2016-10-04T12:25:42Z
    message: Deployment has minimum availability.
    reason: MinimumReplicasAvailable
    status: "True"
    type: Available
  - lastTransitionTime: 2016-10-04T12:25:39Z
    lastUpdateTime: 2016-10-04T12:25:39Z
    message: 'Error creating: pods "nginx-deployment-4262182780-" is forbidden: exceeded quota:
      object-counts, requested: pods=1, used: pods=3, limited: pods=2'
    reason: FailedCreate
    status: "True"
    type: ReplicaFailure
  observedGeneration: 3
  replicas: 2
  unavailableReplicas: 2
最终，一旦超过Deployment进程的deadline，kuberentes会更新状态和导致Progressing状态的原因：

Conditions:
  Type            Status  Reason
  ----            ------  ------
  Available       True    MinimumReplicasAvailable
  Progressing     False   ProgressDeadlineExceeded
  ReplicaFailure  True    FailedCreate
你可以通过缩容Deployment的方式解决配额不足的问题，或者增加你的namespace的配额。如果你满足了配额条件后，Deployment controller就会完成你的Deployment rollout，你将看到Deployment的状态更新为成功状态（Status=True并且Reason=NewReplicaSetAvailable）。

Conditions:
  Type          Status  Reason
  ----          ------  ------
  Available     True    MinimumReplicasAvailable
  Progressing   True    NewReplicaSetAvailable
Type=Available、 Status=True 以为这你的Deployment有最小可用性。 最小可用性是在Deployment策略中指定的参数。Type=Progressing 、 Status=True意味着你的Deployment 或者在部署过程中，或者已经成功部署，达到了期望的最少的可用replica数量（查看特定状态的Reason——在我们的例子中Reason=NewReplicaSetAvailable 意味着Deployment已经完成）。

你可以使用kubectl rollout status命令查看Deployment进程是否失败。当Deployment过程超过了deadline，kubectl rollout status将返回非0的exit code。

$ kubectl rollout status deploy/nginx
Waiting for rollout to finish: 2 out of 3 new replicas have been updated...
error: deployment "nginx" exceeded its progress deadline
$ echo $?
1