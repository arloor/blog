---
title: "使用K8S DaemonSet部署rust_http_proxy"
date: 2023-07-23T21:07:02+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

1. tls的证书没有使用Secret，感觉没啥必要
2. 使用hostPort来暴露端口

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: proxy
  labels:
    k8s-app: proxy
spec:
  selector:
    matchLabels:
      name: proxy
  template:
    metadata:
      labels:
        name: proxy
    spec:
      tolerations:
      # 这些容忍度设置是为了让该守护进程集在控制平面节点上运行
      # 如果你不希望自己的控制平面节点运行 Pod，可以删除它们
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      containers:
      - name: proxy
        image: docker.io/arloor/rust_http_proxy:1.0
        imagePullPolicy: Always
        ports:
          - containerPort: 443 
            hostPort: 444 # 使用主机的444端口
            protocol: TCP
        envFrom:
        - configMapRef:
            name: proxy-env
        volumeMounts:
        - name: proxy-certs
          mountPath: /certs
      terminationGracePeriodSeconds: 30
      volumes:
      - configMap:
          name: proxy-certs          #指定使用ConfigMap的名称
        name: proxy-certs 

---

apiVersion: v1
kind: ConfigMap
metadata:
  name: proxy-env
data:
  port: "443"
  cert: /certs/cert
  raw_key: /certs/key
  basic_auth: "Basic xxxxxxxxxxxx=="
  ask_for_auth: "false"
  over_tls: "true"
  web_content_path: /data

---

apiVersion: v1
kind: ConfigMap
metadata:
  name: proxy-certs
data:
  # the data is abbreviated in this example
  cert: |
    -----BEGIN CERTIFICATE-----
    MIIDWTCCAkGgAwIBAgIJAIoVUUAfNZ76MA0GCSqGSIb3DQEBCwUAMBYxFDASBgNV
    BAMMC2xpdWdhbmdodWFuMCAXDTIzMDcyMjA4NTUzMVoYDzIxMjMwNjI4MDg1NTMx
    WjAVMRMwEQYDVQQDDAphcmxvb3IuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
    MIIBCgKCAQEAtUj8vGQ8OdTL7aVb9yL8XKn+OywKtm7dL9t4yh1TnwcBrlQke8Oh
    zb3UPCXVd5KrnWiDWJvN/QU+A/DfqLH6vp/FasJbaxKje8iNIzZhoyuSZkI9cLUg
    6200puWRx3boBLd2/ElNEG15eVt8eB2QmzGr9RQbYWCX0ryFv0e1Qu+G7McIFMPf
    Wbgt01FRs4l0yPwHetpYojAEeQ9Uk2D+P2Y2LGrGgjTCmuVfd6NZ2xx04RVM/FSE
    4blXEnyJuXhAFxTBglCW3fzAY4maRhc5eVwsLMkwnOwXN3L4p+LuaK0lmrzHoW1E
    HMaccGRYurMhyRybkTisA2NcOlRAh+MoSQIDAQABo4GoMIGlMB8GA1UdIwQYMBaA
    FJwkY2icDn85ov9LRJ59qPaK4sIrMAkGA1UdEwQCMAAwCwYDVR0PBAQDAgTwMGoG
    A1UdEQRjMGGCCWxvY2FsaG9zdIcEfwAAAYIKYXJsb29yLmNvbYIMKi5hcmxvb3Iu
    Y29tggphcmxvb3IuZGV2ggwqLmFybG9vci5kZXaCC21vb250ZWxsLmNugg0qLm1v
    b250ZWxsLmNuMA0GCSqGSIb3DQEBCwUAA4IBAQB0Om2QsTIOQCCWjN9HnusRBw1d
    DU+bk5QEjqqYAo3TPNyt79O3us1dINg6XpGUS2la+LxqM4ihfEEMBxqM43KG23l8
    yAhqGZ1WeNpnAQt8aA/uMbLOGneoCfutzbxT4CaMP+9oywEQ3G3OiOWNETHPT+f+
    vd9IuzFYm05NNqudFaBvuqHYGMbIHQxeN3gp+erMX2y41xh/RYWj4YeZkDwpCMuL
    oiOnj2wcPch/pajLtXzlRKA9ZnpzDoqhprRPdJggrdjgMtHAJfp9uoMgMTFtlKR0
    GriqG6/YpYWSDMtCZOczvdkBp+M4HpS1zznV6aMPHy4bQQ2eWCDxkCU9C9b3
    -----END CERTIFICATE-----
    -----BEGIN CERTIFICATE-----
    MIIDFDCCAfygAwIBAgIJALjFVSSUIdUYMA0GCSqGSIb3DQEBCwUAMBYxFDASBgNV
    BAMMC2xpdWdhbmdodWFuMCAXDTIzMDcyMjA4NTExMloYDzIxMjMwNjI4MDg1MTEy
    WjAWMRQwEgYDVQQDDAtsaXVnYW5naHVhbjCCASIwDQYJKoZIhvcNAQEBBQADggEP
    ADCCAQoCggEBAO1+hnRKa8XpiqDb+61WVhM1V8Mr84SwiSyMNhMkVF0xCLVqo0GQ
    +DA1Myr6ks+1Qd4DRGeOEZZvtXs7CNtV26klYGzWGffHd5jQij82Xx179FP5sUiY
    9aRZ8d0nrhgdbPKTfMzBigqjD/xVkeHP3OGLNCJyLnnAVTqgY+kSdg8LWGjCGJWn
    bQubFHDMQoG+bv/KCEJA5oWFv42xHPikTBdOJSBNwlNCpq3KtQHRY4VTB1BVQ89t
    Ry99mlIAjmYVN7/DXFOCdq8WmquvfUrhNUJmXSZEHEN6/zyb3nXBlUl11dtoe5yu
    MChI327ZGIJuoy5UsL0ouT1IMtDWeP9W/nMCAwEAAaNjMGEwHQYDVR0OBBYEFJwk
    Y2icDn85ov9LRJ59qPaK4sIrMB8GA1UdIwQYMBaAFJwkY2icDn85ov9LRJ59qPaK
    4sIrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgGGMA0GCSqGSIb3DQEB
    CwUAA4IBAQBUP6XXH4oeWhy4CC7Brx8ndZb4XzF5sWmZE8KcutPw7f+eN4JHsMf6
    B396bfAkM4A/ljFZuxWzo4oGfN4ibg6PItI9R1IC6Gnp///y1TtQNhpg9zzRRYZQ
    vm2EBPP3E/jsOlP1nk/0fvInEaaF2fBMl2a5+2pOUj2JRBFsNTivVY+BQ64yI0RN
    N4Y8BXdcTLua9CTi5g4S5s6UJfXw2zN3A2Yk009v3d6MiMB4uJHk1cZVSVqA34eO
    AS/KuYYtohYByarXgu+tE0JCmZ1StvO/KFkor7pm/Lx9z/Wc7vpF85hGLzM9xnZz
    VV0IRxlUny5mKQz6a+f+G/JcT7lh1eQu
    -----END CERTIFICATE-----
  key: |
    -----BEGIN RSA PRIVATE KEY-----
    ........

```