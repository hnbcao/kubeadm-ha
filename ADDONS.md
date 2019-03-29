
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
    stateOrProvinceName_value       = Beijing

    localityName                    = Locality Name (eg, city)
    localityName_value              = Haidian

    organizationName                = Organization Name (eg, company)
    organizationName_value          = Channelsoft

    organizationalUnitName          = Organizational Unit Name (eg, section)
    organizationalUnitName_value    = R & D Department

    commonName                      = Common Name (eg, your name or your server\'s hostname)
    commonName_value                = *.multi.io


    emailAddress                    = Email Address
    emailAddress_value              = lentil1016@gmail.com
    """ > ~/ikube/tls/openssl.cnf
    openssl req -newkey rsa:4096 -nodes -config ~/ikube/tls/openssl.cnf -days 3650 -x509 -out ~/ikube/tls/tls.crt -keyout ~/ikube/tls/tls.key
    kubectl create -n kube-system secret tls ssl --cert ~/ikube/tls/tls.crt --key ~/ikube/tls/tls.key
    kubectl apply -f https://raw.githubusercontent.com/hnbcao/kubeadm-ha-master/v1.14.0/addons/traefik/traefik-daemonset-full.yaml
    ```