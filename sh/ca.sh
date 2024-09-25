mkdir -p ~/ca
cd ~/ca
if [ ! -f ca_key.pem -o ! -f ca.pem ]; then
    echo -e "\033[32mgenerating new CA\033[0m"
    echo -e "\033[32m================================\033[0m"
    if [ -f ca_key.pem ]; then
        rm -f ca_key.pem
    fi
    if [ -f ca.pem ]; then
        rm -f ca.pem
    fi
    cat >ca.conf <<EOF
[ req ]
# Options for the "req" tool "man req".
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# Extension to add when the -x509 option is used.
x509_extensions     = v3_ca

[ req_distinguished_name ]
# See https://en.wikipedia.org/wiki/Certificate_signing_request
countryName_min                 = 0
stateOrProvinceName_min         = 0
localityName_min                = 0
organizationName_min            = 0
organizationalUnitName_min      = 0
commonName                      = Common Name
emailAddress_min                = 0

[ v3_ca ]
# Extensions for a typical CA "man x509v3_config".
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
EOF

    # 使用liuganghuan.com创建SSL证书，作为CA
    openssl req -config ~/ca/ca.conf -x509 -newkey rsa:4096 -sha256 -nodes -keyout temp.pem -extensions v3_ca -out ca.pem -days 36500 -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Self Sign/OU=CA/CN=liuganghuan"
    openssl rsa -inform PEM -in temp.pem -outform PEM -out ca_key.pem # PKCS#8 转PKCS#1
    openssl x509 -in ca.pem -noout -text
    rm -f temp.pem 
    echo
    echo -e "\033[32mnew ca.pem generated! please install ~/ca/ca.pem !!!\033[0m"
    echo -e "\033[32m================================\033[0m"
fi

mkdir -p ~/ca/certs
cd ~/ca/certs
# 设置证书的使用范围
cat >cert.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
IP.2 = 127.0.0.1
DNS.3 = arloor.com
DNS.4 = *.arloor.com
DNS.5 = arloor.dev
DNS.6 = *.arloor.dev
EOF

# 使用CA给arloor.com颁发证书
openssl genrsa -out privkey.pem 2048
openssl req -new -key privkey.pem -out localhost.csr -subj "/C=CN/ST=Shanghai/L=Shanghai/O=Self Sign/OU=Cert/CN=arloor.com"
openssl x509 -req -in localhost.csr -out cert.pem -days 825 \
    -CAcreateserial -CA ../ca.pem -CAkey ../ca_key.pem \
    -CAserial serial -extfile cert.ext

openssl x509 -in cert.pem -noout -text
openssl verify -CAfile ~/ca/ca.pem cert.pem
cat ~/ca/ca.pem >>cert.pem