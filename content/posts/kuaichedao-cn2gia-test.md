---
title: "快车道GIA主机测评"
date: 2019-08-27T00:02:46+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

很幸运拿到了[快车道](https://kuaichedao.co/)的圣何塞cn2 gia的测试机器，做一篇主机测评的文章。
<!--more-->

## Superbench测试

```java
----------------------------------------------------------------------
 Superbench.sh -- https://www.oldking.net/350.html
 Mode  : Standard    Version : 1.1.5
 Usage : wget -qO- git.io/superbench.sh | bash
----------------------------------------------------------------------
 CPU Model            : Intel(R) Xeon(R) CPU E5-2690 v2 @ 3.00GHz
 CPU Cores            : 1 Cores @ 2999.998 MHz x86_64
 CPU Cache            : 16384 KB
 OS                   : CentOS 7.6.1810 (64 Bit) KVM
 Kernel               : 3.10.0-957.27.2.el7.x86_64
 Total Space          : 1.8 GB / 20.0 GB
 Total RAM            : 68 MB / 487 MB (366 MB Buff)
 Total SWAP           : 0 MB / 0 MB
 Uptime               : 0 days 1 hour 45 min
 Load Average         : 0.02, 0.35, 0.34
 TCP CC               : cubic
 ASN & ISP            : AS138211, VMHaus Limited
 Organization         : Kirino
 Location             : Frankfurt am Main, Germany / DE
 Region               : Hesse
----------------------------------------------------------------------
 I/O Speed( 1.0GB )   : 236 MB/s
 I/O Speed( 1.0GB )   : 626 MB/s
 I/O Speed( 1.0GB )   : 615 MB/s
 Average I/O Speed    : 492.3 MB/s
----------------------------------------------------------------------
 Node Name        Upload Speed      Download Speed      Latency
 Speedtest.net    3.32 Mbit/s       2.38 Mbit/s         (*) 2508.971 ms
 Fast.com         0.00 Mbit/s       101.2 Mbit/s        -
 Guangzhou CT     2.77 Mbit/s       2.01 Mbit/s         -
 Wuhan     CT     2.80 Mbit/s       2.06 Mbit/s         -
 Hangzhou  CT     20.02 Mbit/s      81.97 Mbit/s        -
 Lanzhou   CT     0.24 Mbit/s       1.47 Mbit/s         -
 Shanghai  CU     2.67 Mbit/s       2.14 Mbit/s         -
 Heifei    CU     13.54 Mbit/s      36.59 Mbit/s        -
 Chongqing CU     2.02 Mbit/s       1.90 Mbit/s         -
 Xizang    CM     2.37 Mbit/s       1.69 Mbit/s         -
----------------------------------------------------------------------
 Finished in  : 13 min 33 sec
 Timestamp    : 2019-08-27 00:32:40 GMT+8
----------------------------------------------------------------------
 Share result:
 · http://www.speedtest.net/result/8534540797.png
 · https://paste.ubuntu.com/p/qVTCdhBDFk/
----------------------------------------------------------------------
```

- 磁盘很不错，不过大部分512MB的用户也不看重磁盘性能
- CPU主频较高，但是CPU性能这点要看老板生多少小鸡
- superbench网络测试有点不理想，更多关于网速的情况请看下一节



## 网络情况

|-|电信|联通|移动|
|---|---|---|---|
|去程|gia|直连|gia|
|回程|gia|gia|gia|

自己试了电信宽带和联通4G，体验都比较好。电信宽带延迟132ms，联通4G跑到了67Mbps的下载速度。跟上面使用superbench测速得到的结果很不一样，网络方面还是挺好的。

测试IP的AS号属于KirinoNET，我听到的不多，貌似风评不错。

