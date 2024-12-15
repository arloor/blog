---
title: "微星Z890 Carbon WIFI主板安装ppm文件"
subtitle:
date: 2024-12-15T15:30:06+08:00
draft: false
categories: 
- undefined
tags: 
- notion
weight: 10
subtitle: ""
description : ""
---

<!--more-->

## 什么是PPM

全称**Intel® PPM(Processor Power Management) Provisioning Package**，即Intel处理器电源管理预配置包，为处理器提供经过调整和优化的电源管理设置，以提高响应速度、电池续航时间和性能。从12代CPU到Ultra 200s CPU，他们都是大小核心设计，额外需要这个东西。

官方的说明在[英特尔® PPM 配置包和驱动程序概述和常见问题解答](https://www.intel.cn/content/www/cn/zh/support/articles/000100206/processors/processor-utilities-and-programs.html)，但是细看这个文档非常抽象。针对我使用的[Arrow Lake](https://www.intel.cn/content/www/cn/zh/ark/products/codename/225837/products-formerly-arrow-lake.html)系列的265k CPU，需要IPF （**Intel® Innovation Platform Framework**）版本在 **2.2.10203.4 或更高版本**，文档里说这由OEM提供更新或这通过Windows Update（WU）提供驱动程序更新。但是我搜索了主板的[驱动更新页面](https://www.msi.cn/Motherboard/MPG-Z890-CARBON-WIFI/support#driver)和检查windows更新的驱动程序更新都没找到。

> 允许windows更新检查驱动程序更新：（我之前关闭了，这里打开）
> 

```bash
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 0 /f
```

## 如何安装

最后我确认了原因，是微星的驱动程序更新太慢了。但华硕就很给力，我在[华硕的z890-p主板支持页面](https://www.asus.com/bt/motherboards-components/motherboards/prime/prime-z890-p/helpdesk_download?model2Name=PRIME-Z890-P)找到了我要的驱动程序：

![8e8208913a70ca6459da9ae2b03a674b.png](/img/8e8208913a70ca6459da9ae2b03a674b.png)

下载之后，我大胆运行了图中的 `AsusSetup.exe` ，这成功解决了问题，安装了对应版本的DTT Driver、IPF、PPM。这三个东西都是CPU相关的，跟主板没任何关系，所以我才敢安装。其中DTT是**Intel® Dynamic Tuning Technology (Intel® DTT)** ，Intel的官方系统内超频工具XTU就是依赖这个技术。

![696f3485731aa73dc213e8f4943b1d87.png](/img/696f3485731aa73dc213e8f4943b1d87.png)

之后在设备管理器中查看这些内容，就是图中所示的版本：

{{<img 881f076f28b4571961352a6600c22edf.png 700>}}

并且，C盘的预配置包( `C:\Windows\Provisioning\Packages` )里也有了PPM文件：

![e6f632a2dfed15334dd18bc35c634ea5.png](/img/e6f632a2dfed15334dd18bc35c634ea5.png)

至此，就安装完成了。

## 探索路径

过程中还搜索到 Intel Extreme Tunning Utility（简称Intel XTU）也依赖IPF，这个我是用过的啊。我尝试安装了新版的 Intel XTU，下载地址[Intel® Extreme Tuning Utility (Intel® XTU)](https://www.intel.com/content/www/us/en/download/17881/intel-extreme-tuning-utility-intel-xtu.html)，安装10.x版本是支持265k的。

{{<img 860f12eb5f83041cb9f13c0890ecda4d.png 500>}}

安装结束后提示到这个链接（[Intel® Innovation Platform Framework](https://www.intel.com/content/www/us/en/download/826464/intel-innovation-platform-framework.html)）下载IPF installer，我心里一喜，结果打开来一看，这个页面提供的也是老版本的：

![581ca5407be2820f83a44113741963dd.png](/img/581ca5407be2820f83a44113741963dd.png)

此路不通。

## 在XTU中查看IPF版本

{{<img 28e81f36d6d93852bf0660edd6a3a1a8.png 500 >}}
