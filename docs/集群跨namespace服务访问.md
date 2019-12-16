## 集群跨namespace服务访问

***

ns-02需要访问ns-01下面的服务service01

***
```yaml
apiVersion: v1
kind: Service
metadata:
 name: service02
 namespace: ns-02
spec:
 ports:
 - name: http
   port: 80
   protocol: TCP
   targetPort: 80
 sessionAffinity: None
 type: ExternalName
 externalName: service01.ns-01.svc.cluster.local
 ```

- externalName：需要访问的服务域名，service01指服务名字，ns-01指命名空间，svc.cluster.local指kubernetes内部服务域名结尾，默认是svc.cluster.local

***