## 部署TraefikIngress

### 使用OpenSSL创建TLS证书（已有证书则跳过该选项）

- 设置证书信息

```sh
cd ~ && mkdir tls 
echo """
[req] 
distinguished_name = req_distinguished_name
prompt = yes

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
countryName_value               = CN

stateOrProvinceName             = State or Province Name (full name)
stateOrProvinceName_value       = Chongqing

localityName                    = Locality Name (eg, city)
localityName_value              = Yubei

organizationName                = Organization Name (eg, company)
organizationName_value          = HNBCAO

organizationalUnitName          = Organizational Unit Name (eg, section)
organizationalUnitName_value    = R & D Department

commonName                      = Common Name (eg, your name or your server\'s hostname)
commonName_value                = *.hnbcao.io


emailAddress                    = Email Address
emailAddress_value              = hnbcao@163.com
""" > ~/tls/openssl.cnf
```

- 生成证书

```sh
openssl req -newkey rsa:4096 -nodes -config ~/tls/openssl.cnf -days 3650 -x509 -out ~/tls/tls.crt -keyout ~/tls/tls.key
```

### 部署Traefik

- 添加证书至集群

```sh
kubectl create -n kube-system secret tls ssl --cert ~/ikube/tls/tls.crt --key ~/ikube/tls/tls.key
```

- 部署Traefik

```sh
kubectl apply -f https://raw.githubusercontent.com/hnbcao/kubeadm-ha/master/addons/yaml/traefik/traefik-daemonset-full.yaml
```