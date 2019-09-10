
## kubernetes 插件安装
* 1、traefik安装：

    ```
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
    """ > ~/ikube/tls/openssl.cnf
    openssl req -newkey rsa:4096 -nodes -config ~/ikube/tls/openssl.cnf -days 3650 -x509 -out ~/ikube/tls/tls.crt -keyout ~/ikube/tls/tls.key
    kubectl create -n kube-system secret tls ssl --cert ~/ikube/tls/tls.crt --key ~/ikube/tls/tls.key
    kubectl apply -f https://raw.githubusercontent.com/hnbcao/kubeadm-ha-master/v1.14.0/addons/traefik/traefik-daemonset-full.yaml
    ```