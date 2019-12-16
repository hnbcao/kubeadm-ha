## 创建ImagePullSecret

### 一、登录镜像仓库，成功之后会生成如下/root/.docker/config.json文件
```json
{
	"auths": {
		"harbor.hnbcao.tech": {
			"auth": "YWRtaW4******lRlY2g="
		}
	},
	"HttpHeaders": {
		"User-Agent": "Docker-Client/***"
	}
}
```

### 二、执行如下命令创建ImagePullSecret

```sh
kubectl create secret generic harbor-admin-secret --from-file=.dockerconfigjson=/root/.docker/config.json --type=kubernetes.io/dockerconfigjson --namespace hnbcao-mixing-ore
```

说明：

- harbor-admin-secret： ImagePullSecret名字
- type： 指定secret类型为kubernetes.io/dockerconfigjson
- namespace：secret命名空间

### 四、为项目添加ImagePullSecret

- Deployment

在配置项的spec.template.spec.imagePullSecrets下添加secret：harbor-admin-secret。例如，Deployment的配置如下：
```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: app-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: app-test
      app.kubernetes.io/name: hnbcao
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: app-test
        app.kubernetes.io/name: hnbcao
    spec:
      containers:
        - name: hnbcao
          image: nginx
      imagePullSecrets:
        - name: harbor-admin-secret
```

### 结束

附上官网教程：[https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)