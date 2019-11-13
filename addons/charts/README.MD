## 基于Helm的Addons安装

### 一、安装Helm

下载Helm，[Helm On Github](https://github.com/helm/helm/releases)，解压文件，将helm拷贝至系统”/usr/local/bin“目录下。本教程基于helm2下安装，不建议下载Helm3版本。

为Tiller创建ServiceAccount

```yaml
# helm-tiller-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
```

```sh
# 确认Helm版本,并赋值HELM_VERSION
# eg: HELM_VERSION="v2.12.3"
HELM_VERSION=""
kubectl apply -f helm-tiller-rbac.yaml
helm init --upgrade --service-account tiller --tiller-image registry.aliyuncs.com/google_containers/tiller:${HELM_VERSION}  --stable-repo-url http://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts/
```
### 二、Kubernetes监控组件Prometheus安装

Prometheus和Grafana需要安装在同一个命名空间下面。

***

- 安装Prometheus

***

Chart 来源：[https://github.com/helm/charts/tree/master/stable/prometheus](https://github.com/helm/charts/tree/master/stable/prometheus)

Prometheus的安装配置在install-prometheus-values.yaml修改，详细见[prometheus-2.13.1/README.MD](file://prometheus-2.13.1/README.MD)；

```sh
# install-prometheus.sh
#!/bin/sh
BASEPATH=`pwd`
helm install -n prometheus ${BASEPATH}/prometheus-2.13.1 -f install-prometheus-values.yaml --namespace=kube-monitor
```

***

- 安装Grafana

***
Chart 来源：[https://github.com/helm/charts/tree/master/stable/grafana](https://github.com/helm/charts/tree/master/stable/grafana)

Grafana的安装配置在install-grafana-values.yaml修改，详细见[grafana-6.4.2/README.MD](file://prometheus-2.13.1/README.MD)

```sh
# install-grafana.sh
#!/bin/sh
BASEPATH=`pwd`
helm install -n grafana ${BASEPATH}/grafana-6.4.2 -f install-grafana-values.yaml --namespace=kube-monitor
```
***

### 三、Harbor Docker镜像仓库安装

***
***
Chart 来源：[https://github.com/goharbor/harbor-helm](https://github.com/goharbor/harbor-helm)

Harbor的安装配置在install-harbor-values.yaml修改，详细见[harbor-1.1.5/README.MD](file://prometheus-2.13.1/README.MD)

```sh
# install-harbor.sh
#!/bin/sh
BASEPATH=`pwd`
helm install -n harbor ${BASEPATH}/harbor-1.1.5 -f install-harbor-values.yaml --namespace=harbor
```

***
