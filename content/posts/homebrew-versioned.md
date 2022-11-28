---
title: "Homebrew安装指定版本"
date: 2022-11-28T15:02:39+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
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

- **formula**: Homebrew package definition built from upstream sources
- cask: Homebrew package definition that installs macOS native applications
- keg: installation destination directory of a given formula version e.g. /usr/local/Cellar/foo/0.1
- rack: directory containing one or more versioned kegs e.g. /usr/local/Cellar/foo
- keg-only: a formula is keg-only if it is not symlinked into Homebrew’s prefix (e.g. /usr/local)
- cellar: directory containing one or more named racks e.g. /usr/local/Cellar
- Caskroom: directory containing one or more named casks e.g. /usr/local/Caskroom
- external command: brew subcommand defined outside of the Homebrew/brew GitHub repository
- **tap**: directory (and usually Git repository) of formulae, casks and/or external commands
- bottle: pre-built keg poured into the cellar/rack instead of building from upstream sources

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

