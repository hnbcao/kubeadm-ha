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

apiVersion: v1
kind: Service
metadata:
 name: segma-refiner-gateway-backend
 namespace: segma-miner
spec:
 ports:
 - name: http
   port: 81
   protocol: TCP
   targetPort: 81
 sessionAffinity: None
 type: ExternalName
 externalName: segma-refiner-gateway-backend.segma-refiner.svc.cluster.local

 