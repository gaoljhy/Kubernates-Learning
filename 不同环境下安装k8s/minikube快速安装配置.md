# 安装

## 安装minikube

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
   && sudo install minikube-linux-amd64 /usr/local/bin/minikube

```

## 安装 kubectl

```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
```

## 指定虚拟化(若没有则不指定)

`minikube config set vm-driver 虚拟化架构`

`virtualbox` 或者 `kvm2` 或者 `none`

如果已经在`VM`内部运行`minikube`，则可以使用`none`驱动程序跳过创建其他`VM`层的操作。

## 安装docker

> 参考 <https://docs.docker.com/install/linux/docker-ce/centos/>

`centos-extras`库须要启用

### 卸载旧版本

```sh
sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
```

### 使用存储库安装

设置Docker存储库。之后，可以从存储库安装和更新Docker。

1. 安装所需的软件包。

    `$ sudo yum install -y yum-utils device-mapper-persistent-data lvm2`

2. 使用设置稳定的存储库。

    `$ sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo`

3. 安装指定版本(最新版可能不支持)
    > 其他版本参阅官方文档
    > 或者 `yum list docker-ce --showduplicates | sort -r`

    `sudo yum install docker-ce-<VERSION_STRING> docker-ce-cli-<VERSION_STRING> containerd.io`

    例如18.09 `sudo yum install docker-ce-18.09.0 docker-ce-cli-18.09.0 containerd.io`

### 测试成功

1. 启动Docker。
    `sudo systemctl start docker`

2. 使用helloworld测试
    `sudo docker run hello-world`

## 启动 minikube

`minikube start`

### 若被墙掉,使用国内镜像

`minikube start --registry-mirror=https://registry.docker-cn.com`
成功之后使用 `kubectl` 接入