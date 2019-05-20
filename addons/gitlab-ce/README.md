# Gitlab安装（kubernetes）

## 概述

文档记录如何在kubernetes上安装Gitlab，安装过程参考[Gialab官方安装教程](https://docs.gitlab.com/charts/)。

## 安装

1、安装Helm

2、安装gitlab的helm仓库
```sh
helm repo add gitlab https://charts.gitlab.io/
helm search -l gitlab/gitlab
```

3、获取values.yaml并修改参数

获取values.yaml

* 方式一：

    [gitlab官方git仓库](https://gitlab.com/charts/gitlab/)

* 方式二：

```sh
# 首先使用helm安装gitlab
helm install -n gitlab gitlab/gitlab ...
# 使用helm get 获取values.yaml
helm get values gitlab > values.yaml
# 删除gitlab
helm del gitlab --purge
```

修改values.yaml

```yaml
# 配置仓库地址

global:
  ## 设置gitlab版本为社区版
  edition: ce
  ## 配置仓库地址
  communityImages:
    # Default repositories used to pull Gitlab Community Edition images.
    # See the image.repository and workhorse.repository template helpers.
    gitaly::
      repository: harbor.seos.segma.tech/gitlab-org/gitaly
    migrations:
      repository: harbor.seos.segma.tech/gitlab-org/gitlab-rails-ce
    sidekiq:
      repository: harbor.seos.segma.tech/gitlab-org/gitlab-sidekiq-ce
    task-runner:
      repository: harbor.seos.segma.tech/gitlab-org/gitlab-task-runner-ce
    unicorn:
      repository: harbor.seos.segma.tech/gitlab-org/gitlab-unicorn-ce
      workhorse:
        repository: harbor.seos.segma.tech/gitlab-org/gitlab-workhorse-ce
  gitaly:
    image:
      repository: harbor.seos.segma.tech/gitlab-org/gitaly

  certificates:
    image:
      repository: harbor.seos.segma.tech/gitlab-org/alpine-certificates
      tag: 20171114-r3
shared-secrets:
  image:
    repository: harbor.seos.segma.tech/gitlab-org/kubectl
    tag: 1f8690f03f7aeef27e727396927ab3cc96ac89e7
    # pullPolicy: Always
    pullSecrets: []
  selfsign:
    image:
      repository: harbor.seos.segma.tech/gitlab-org/cfssl-self-sign
      tag: 1.2
gitlab:
  gitaly:
    image:  
      repository: harbor.seos.segma.tech/gitlab-org/gitaly
  gitlab-shell:
    image:
      repository: harbor.seos.segma.tech/gitlab-org/gitlab-shell
  task-runner:
    image:
      repository: harbor.seos.segma.tech/gitlab-org/gitlab-task-runner-ce
```

```yaml
# 设置域名
global:
  ## doc/charts/globals.md#configure-host-settings
  hosts:
    domain: segma.tech
    # hostSuffix:
    https: true
    externalIP:
    ssh: ~
    minio:
      name: gitlab-minio.seos.segma.tech

# 配置ingress
  ingress:
    configureCertmanager: false
    annotations: 
      certmanager.k8s.io/acme-challenge-type: 'http01'
      certmanager.k8s.io/cluster-issuer: 'letsencrypt-prod'
      ingress.kubernetes.io/ssl-redirect: true
      kubernetes.io/ingress.class: 'traefik'
    enabled: true

# 不安装ingress，因为k8s已经有traefik存在
nginx-ingress:
  enabled: false

# 不安装certmanager，k8s已存在
certmanager:
  # Install cert-manager chart. Set to false if you already have cert-manager
  # installed or if you are not using cert-manager.
  install: false
```

4、安装gitlab

```sh
helm install -n gitlab gitlab/gitlab ...
```

5、后续配置

* 关于minio，minio的作用是保存gitlab中的大文件，后期使用时更多的是用于保存gitlab备份，所以将minio单独安装在其他命名空间。安装时保证minio的ingress域名与当前gitlab中的minio域名一致，鉴权信息也一致，然后删除gitlab中的minio。

* 关于备份，手动在k8s主节点上运行crontab任务
```sh
#!/bin/bash
# 备份脚本
TASK_INFO=`kubectl get po -n gitlab-ce | grep gitlab-task-runner`
if [ -n "${TASK_INFO}" ];then
    TASK_NAME=`echo ${TASK_INFO%% *}`
    if [ -n "${TASK_NAME}" ]; then
        kubectl exec ${TASK_NAME} -i /bin/bash backup-utility -n gitlab-ce
    else
        echo "Task Runner Can Not Found(0)"
    fi
else
    echo "Task Runner Can Not Found(1)"
fi

```

```sh
# 安装crontab：

yum install crontabs

# 服务操作说明：

/sbin/service crond start //启动服务

/sbin/service crond stop //关闭服务

/sbin/service crond restart //重启服务

/sbin/service crond reload //重新载入配置

/sbin/service crond status //启动服务

# 查看crontab服务是否已设置为开机启动，执行命令：

ntsysv

# 加入开机自动启动：

chkconfig –level 35 crond on
```

```
# gitlab-backup-cron内容 每周六晚上两点运行
0 2 * * 6 /bin/sh /etc/gitlab-backup.sh
```

```sh
crontab gitlab-backup-cron
```

