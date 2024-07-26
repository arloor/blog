---
title: "Homebrew安装指定版本"
date: 2022-11-28T15:02:39+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

需要安装指定版本的thrift，记录下homebrew安装指定版本软件的方法。
<!--more-->

```bash
brew tap-new $USER/local-tap1
brew extract --version='0.14.1' thrift $USER/local-tap1
brew install thrift@0.14.1
```

如果还没有安装homebrew，可以通过下面的命令安装

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# 然后设置环境变量
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
```

其他常用命令：

```bash
brew deps --installed --tree # 查看已安装软件的依赖树
brew search mysql # 搜索软件
brew info mysql # 查看软件信息
brew list # 查看已安装软件
brew outdated # 查看过期软件
brew upgrade # 升级所有软件
brew upgrade mysql # 升级指定软件
brew cleanup # 清理旧版本软件
brew uninstall mysql # 卸载软件
brew doctor # 检查问题
```

## 参考文档

- [Homebrew 安装指定版本的三种方式](https://shockerli.net/post/homebrew-install-formula-specific-version/)
- [Formulae Versions](https://docs.brew.sh/Versions)

## 方式一：官方大版本

对于某些软件，homebrew本身提供了多个版本，例如mysql提供了5.6、5.7版本

```bash
brew search mysql                                    
==> Formulae
automysqlbackup          mysql-client ✔           mysql-sandbox            mysql@5.7
mysql                    mysql-client@5.7         mysql-search-replace     mysqltuner
mysql++                  mysql-connector-c++      mysql@5.6                qt-mysql
==> Casks
mysql-connector-python            mysql-utilities                   navicat-for-mysql
mysql-shell                       mysqlworkbench                    sqlpro-for-mysql
----------------------------------------------------------------------------------------------------
brew install mysql@5.7                                 
```

但是大多数软件并没有官方多版本

## 方式二：从`homebrew/core`中抽取特定版本的formulae到自己的tap中，并进行安装

**相关术语：** 详见[manpage](https://docs.brew.sh/Manpage)

| 术语     | 意译   | 说明                                              |
|----------|--------|---------------------------------------------------|
| formula  | 配方   | 表示安装包的描述文件。复数为 formulae。           |
| cask     | 木桶   | 装酒的器具，表示具有 GUI 界面的原生应用。         |
| keg      | 小桶   | 表示某个包某个版本的安装目录，比如 /usr/local/Cellar/foo/0.1。 |
| Cellar   | 地窖   | 存放酒的地方，表示包的安装目录，比如 /usr/local/Cellar。 |
| Caskroom | 木桶间 | 表示类型为 Cask 的包的安装目录，比如：/usr/local/Caskroom。  |
| tap      | 水龙头 | 表示包的来源，也就是镜像源。                      |
| bottle   | 瓶子   | 表示预先编译好的包，下载好直接使用。              |


在安装指定版本的过程中涉及到的术语有tap和formula。简单理解是：

- formula：软件的安装脚本
- tap：formula所在的文件夹

`homebrew/core`是一个git仓库，git log中有着软件的历史版本，将历史版本的formula复制到自定义的tap中即可安装任意版本的软件，具体流程如下：

```bash
brew tap-new $USER/local-tap1
brew extract --version='0.14.1' thrift $USER/local-tap1
brew install thrift@0.14.1
```

上面的脚本把0.14.1版本的thrift formula抽取到了local-tap1的`thrift@0.14.1.rb`中，这是一个ruby文件，定义了编译步骤，具体文件如下：

```ruby
~ » cat /usr/local/Homebrew/Library/Taps/ganghuanliu/homebrew-local-tap1/Formula/thrift@0.14.1.rb
class ThriftAT0141 < Formula
  desc "Framework for scalable cross-language services development"
  homepage "https://thrift.apache.org/"
  url "https://www.apache.org/dyn/closer.lua?path=thrift/0.14.1/thrift-0.14.1.tar.gz"
  mirror "https://archive.apache.org/dist/thrift/0.14.1/thrift-0.14.1.tar.gz"
  sha256 "13da5e1cd9c8a3bb89778c0337cc57eb0c29b08f3090b41cf6ab78594b410ca5"
  license "Apache-2.0"

  head do
    url "https://github.com/apache/thrift.git"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
    depends_on "pkg-config" => :build
  end

  depends_on "bison" => :build
  depends_on "boost" => [:build, :test]
  depends_on "openssl@1.1"

  def install
    system "./bootstrap.sh" unless build.stable?

    args = %W[
      --disable-debug
      --disable-tests
      --prefix=#{prefix}
      --libdir=#{lib}
      --with-openssl=#{Formula["openssl@1.1"].opt_prefix}
      --without-erlang
      --without-haskell
      --without-java
      --without-perl
      --without-php
      --without-php_extension
      --without-python
      --without-ruby
      --without-swift
    ]

    ENV.cxx11 if ENV.compiler == :clang

    # Don't install extensions to /usr:
    ENV["PY_PREFIX"] = prefix
    ENV["PHP_PREFIX"] = prefix
    ENV["JAVA_PREFIX"] = buildpath

    system "./configure", *args
    ENV.deparallelize
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"test.thrift").write <<~'EOS'
      service MultiplicationService {
        i32 multiply(1:i32 x, 2:i32 y),
      }
    EOS

    system "#{bin}/thrift", "-r", "--gen", "cpp", "test.thrift"

    system ENV.cxx, "-std=c++11", "gen-cpp/MultiplicationService.cpp",
      "gen-cpp/MultiplicationService_server.skeleton.cpp",
      "-I#{include}/include",
      "-L#{lib}", "-lthrift"
  end
end
```

### 查看`homebrew/core`中有哪些历史版本

前面提到homebrew/core是一个git仓库，我们可以用git log来查看有哪些历史版本。

1. 先找到`homebrew/core`的路径
2. 通过git log查看历史版本中的url，从url中确定版本

```bash
brew tap homebrew/core --force
brew tap-info homebrew/core                                                                                          
homebrew/core: 2 commands, 5873 formulae
/usr/local/Homebrew/Library/Taps/homebrew/homebrew-core (6,238 files, 633.8MB)
From: https://github.com/Homebrew/homebrew-core
--------------------------------------------------------------------------------------------------------------------------------------------------
cd /usr/local/Homebrew/Library/Taps/homebrew/homebrew-core
git log -p -- Formula/thrift.rb | grep -e ^commit -e 'url "http'
commit 306904d90d17c0ffbfb024ec818235b9bc8f7b35
commit 2d25d7fdb9ed8527c15cb4c9dcc36e846b9059e9
-  url "https://www.apache.org/dyn/closer.lua?path=thrift/0.15.0/thrift-0.15.0.tar.gz"
+    url "https://www.apache.org/dyn/closer.lua?path=thrift/0.15.0/thrift-0.15.0.tar.gz"
+      url "https://raw.githubusercontent.com/Homebrew/formula-patches/03cf8088210822aa2c1ab544ed58ea04c897d9c4/libtool/configure-big_sur.diff"
commit 82d03f657371e1541a9a5e5de57c5e1aa00acd45
commit a1107432c0176a98e858bfe8ac30ec7472e166e6
-  url "https://www.apache.org/dyn/closer.lua?path=thrift/0.14.2/thrift-0.14.2.tar.gz"
+  url "https://www.apache.org/dyn/closer.lua?path=thrift/0.15.0/thrift-0.15.0.tar.gz"
commit 5502012cb8b18fc762ffa679b9123b3a6659e62c
commit a062b5de197a105fc3f14285bd90fef73dc84b89
commit ae9d72973b6601558f8d76b14e35e7eb3625078c
-  url "https://www.apache.org/dyn/closer.lua?path=thrift/0.14.1/thrift-0.14.1.tar.gz"
```


## 例子：安装clang-format-16

```bash
# 安装tap homebrew/core（最新版本默认不安装tap homebrew/core，所以需要手动安装
brew tap homebrew/core --force
# 寻找tap homebrew/core的路径
brew tap-info homebrew/core     
# /opt/homebrew/Library/Taps/homebrew/homebrew-core (7,446 files, 838.5MB)
# 查看clang-format的信息，确定路径
brew search clang-format
brew info clang-format
# From: https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/c/clang-format.rb
# 查看的Formula/c/clang-format.rb变更，确定版本
git log -p -- Formula/c/clang-format.rb | grep -e ^commit -e 'url "http'
# commit 32caf9d2d18b258e964354a1d555c05b3c8b0e5d
# commit 442f9cc511ce6dfe75b96b2c83749d90dde914d2
# +    url "https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.6/llvm-16.0.6.src.tar.xz"
# +      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.6/clang-16.0.6.src.tar.xz"
# +      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.6/cmake-16.0.6.src.tar.xz"
# +      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.6/third-party-16.0.6.src.tar.xz"

# 安装16.0.6
brew tap-new $USER/local-tap1
brew extract --version='16.0.6' clang-format $USER/local-tap1
brew install clang-format@16.0.6
```