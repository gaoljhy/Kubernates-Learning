# Volume

容器中的磁盘的生命周期是短暂的，这就带来了一系列的问题，第一，当一个容器损坏之后，kubelet 会重启这个容器，但是文件会丢失-这个容器会是一个全新的状态，第二，当很多容器在同一Pod中运行的时候，很多时候需要数据文件的共享。Kubernete Volume解决了这个问题

Background背景
Docker有一个Volumes的概念，虽然这个Volume有点宽松和管理性比较小。在Docker中，一个 Volume 是一个简单的所在主机的一个目录或者其它容器中的。生命周期是没有办法管理，直到最近才有 local-disk-backed 磁盘。Docker现在提供了磁盘驱动，但是功能非常有限（例如Docker1.7只能挂在一个磁盘每个容器，并且无法传递参数）

从另外一个方面讲，一个Kubernetes volume，拥有明确的生命周期，与所在的Pod的生命周期相同。因此，Kubernetes volume独立与任何容器，与Pod相关，所以数据在重启的过程中还会保留，当然，如果这个Pod被删除了，那么这些数据也会被删除。更重要的是，Kubernetes volume 支持多种类型，任何容器都可以使用多个Kubernetes volume。

它的核心，一个 volume 就是一个目录，可能包含一些数据，这些数据对pod中的所有容器都是可用的，这个目录怎么使用，什么类型，由什么组成都是由特殊的volume 类型决定的

想要使用一个volume，Pod必须指明Pod提供了那些磁盘，并且说明如何挂在到容器中

A process in a container sees a filesystem view composed from their Docker image and volumes. The Docker image is at the root of the filesystem hierarchy, and any volumes are mounted at the specified paths within the image. Volumes can not mount onto other volumes or have hard links to other volumes. Each container in the Pod must independently specify where to mount each volume.

（这段没太看懂阿）

容器中的一个进程看到文件系统由Docker镜像和磁盘构成，Docker镜像是文件系统的最底层，所有的磁盘都是挂在在这个镜像的特殊路径上。磁盘不能被挂在到被的磁盘或者创建硬链接。每个Pod中的容器必须是独立指定的取挂在这些磁盘

Types of Volumes
Kubernete 支持如下类型的volume:

emptyDir

hostPath

gcePersistentDisk

awsElasticBlockStore

nfs

iscsi

glusterfs

rbd

gitRepo

secret

persistentVolumeClaim

emptyDir
一个emptyDir 第一次创建是在一个pod被指定到具体node的时候，并且会一直存在在pod的生命周期当中，正如它的名字一样，它初始化是一个空的目录，pod中的容器都可以读写这个目录，这个目录可以被挂在到各个容器相同或者不相同的的路径下。当一个pod因为任何原因被移除的时候，这些数据会被永久删除。注意：一个容器崩溃了不会导致数据的丢失，因为容器的崩溃并不移除pod.

emptyDir 磁盘的作用：

scratch space, such as for a disk-based mergesortcw

checkpointing a long computation for recovery from crashes

holding files that a content-manager container fetches while a webserver container serves the data

普通空间，基于磁盘的数据存储
作为从崩溃中恢复的备份点
存储那些那些需要长久保存的数据，例web服务中的数据
默认的，emptyDir 磁盘会存储在主机所使用的媒介上，可能是SSD，或者网络硬盘，这主要取决于你的环境。当然，我们也可以将emptyDir.medium的值设置为Memory来告诉Kubernetes 来挂在一个基于内存的目录tmpfs，因为

tmpfs速度会比硬盘块度了，但是，当主机重启的时候所有的数据都会丢失

hostPath
一个hostPath类型的磁盘就是挂在了主机的一个文件或者目录，这个功能可能不是那么常用，但是这个功能提供了一个很强大的突破口对于某些应用来说

例如，如下情况我们旧可能需要用到hostPath

某些应用需要用到docker的内部文件，这个时候只需要挂在本机的/var/lib/docker作为hostPath
在容器中运行cAdvisor，这个时候挂在/dev/cgroups
当我们使用hostPath的时候要注意如下内容

从模版文件中创建的pod可能会因为主机上文件夹目录的不同而导致一些问题

Kubernetes 规划一些资源相关的维护的时候，它旧不能根据此种类型的资源进行判断（这句没太看懂阿，这个应该得先要知道具体的维护类型才好….）

gcePersistentDisk
gcePersistentDisk 是指挂在一个特殊GCE 持久化磁盘 到我们的pod中，和emptyDir不同的是，emptyDir会被删除当我们的Pod被删除的时候，但是gcePersistentDisk不会被删除，仅仅是解除挂在状态而已，这就意味着PD能够允许我们提前对数据进行处理，而且这些数据可以在Pod之间相互传递

重要的是：我们需要先通过GCE api 或者图形操作界面 创建一个PD，这是你使用它的前提

gcePersistentDisk有一些限制：

节点必须使用的GCE VMs

PD必须和节点，项目在统一个区域

一个PD的特点是可以以只读的方式挂在到多个地方，这旧意味着我们可以先收集一些数据，然后共享给任意多个pod使用，不幸的，PD同时只能被一个pod以读写的方式挂在。

在ReplicationController管理的pod上使用pd会失败，除非是以只读方式，或者数量是1或者0（因为读写同时只能是1）

如何创建一个pd

gcloud compute disks create –size=500GB –zone=us-central1-a my-data-disk
pod的例子
apiVersion: v1

kind: Pod

metadata:

name: test-pd

spec:

containers:

– image: gcr.io/google_containers/test-webserver

name: test-container

volumeMounts:

– mountPath: /test-pd

name: test-volume

volumes:

– name: test-volume

# This GCE PD must already exist.

gcePersistentDisk:

pdName: my-data-disk

fsType: ext4

awsElasticBlockStore
一个awsElasticBlockStore是一个挂在aws EBS 磁盘到我们的pod中，和emptyDir不同的是，emptyDir会被删除当我们的Pod被删除的时候，但是awsElasticBlockStore不会被删除，仅仅是解除挂在状态而已,这就意味着EBS能够允许我们提前对数据进行处理，而且这些数据可以在Pod之间相互传递.

注意，我们首先要使用aws api或者图形操作界面创建EBS 在我们使用之前

awsElasticBlockStore 有如下几个限制：

节点必须运行在aws的虚拟机上
节点和卷宗必须在同一个区域
EBS只支持但个EC2的实例进行挂载
创建一个EBS

aws ec2 create-volume –availability-zone eu-west-1a –size 10 –volume-type gp2
注意，确保区域的正确性

具体例子

apiVersion: v1

kind: Pod

metadata:

name: test-ebs

spec:

containers:

– image: gcr.io/google_containers/test-webserver

name: test-container

volumeMounts:

– mountPath: /test-ebs

name: test-volume

volumes:

– name: test-volume文档

# This AWS EBS volume must already exist.

awsElasticBlockStore:

volumeID: aws:///

fsType: ext4

nfs
nfs使的我们可以挂在已经存在的共享到的我们的Pod中，和emptyDir不同的是，emptyDir会被删除当我们的Pod被删除的时候，但是nfs不会被删除，仅仅是解除挂在状态而已，这就意味着NFS能够允许我们提前对数据进行处理，而且这些数据可以在Pod之间相互传递.并且，nfs可以同时被多个pod挂在并进行读写

注意：必须先报纸NFS服务器正常运行在我们进行挂在nfs的时候

具体例子可以查看http://kubernetes.io/v1.0/examples/nfs/

具体的我们可以看到，挂在点volumeMount 叫做nfs 被挂在到了容器（pod名称叫做web）/var/www/html 目录下,磁盘的类型叫做nfs,nfs服务器的名称叫做 nfs-server.default.kube.local，它共享了它的/目录，在这个例子中，目录使可写入的

iscsi
iscsi允许将现有的iscsi磁盘挂载到我们的pod中，和emptyDir不同的是，emptyDir会被删除当我们的Pod被删除的时候，但是iscsi不会被删除，仅仅是解除挂在状态而已，这就意味着iscsi能够允许我们提前对数据进行处理，而且这些数据可以在Pod之间相互传递

注意，我们需要先有自己的iscsi服务才可以进行后续的操作

iscsi的一个特点是它可以同时被多个pod以只读的形式挂载，这就意味着我们可以提前将数据准备好，然后挂在到任意多个pod中，但是iscsi只允许一次只有一个以读写的挂在方式挂载。

glusterfs
glusterfs 允许 Glusterfs格式的开源磁盘挂载到我们的pod中，同样的，当pod被删除的时候，glusterfs也仅仅是被解除挂载，就意味着glusterfs能够允许我们提前对数据进行处理，而且这些数据可以在Pod之间相互传递

注意：我们需要Glusterfs先存在之后再进行后续操作