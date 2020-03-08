---
title: "Telegram tdlib java 使用"
date: 2020-03-02T20:04:04+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

玩电报比较久了，电报的生态真的很开放，允许大家自建机器人，并提供bot api。但是电报bot会有很多限制，今天要做的是使用telegram的tdlib创建一个java的电报客户端。相似的东西其实已经有了，例如pytelethon，但是我用不惯python，今天就写一篇如何在windows10上使用java jni调用tdlib的文章。

如果有什么问题，可以加电报群[https://t.me/popstary](https://t.me/popstary)讨论

<!--more-->

## 编译Tdlib

首先需要将tdlib的代码编译成jni能调用的.dll(.so)，开放的电报团队提供了这方面的文档，包括各种语言应如何编译tdlib。

地址: [https://tdlib.github.io/td/build.html?language=Java](https://tdlib.github.io/td/build.html?language=Java)

该网页首先说明了需要安装的一些依赖，然后直接列出了编译的完整命令，经过实测只要正确安装依赖，就可以无坑地编译。


### 选择环境及需要的依赖

![](/img/dependency-4-tdlib-windows.png)


### 上述环境的编译命令
```shell
git clone https://github.com/tdlib/td.git
cd td
git checkout v1.6.0
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
./bootstrap-vcpkg.bat
./vcpkg.exe install openssl:x64-windows zlib:x64-windows
cd ..
Remove-Item build -Force -Recurse -ErrorAction SilentlyContinue
mkdir build
cd build
cmake -A x64 -DCMAKE_INSTALL_PREFIX:PATH=../example/java/td -DTD_ENABLE_JNI=ON -DCMAKE_TOOLCHAIN_FILE:FILEPATH=../vcpkg/scripts/buildsystems/vcpkg.cmake ..
cmake --build . --target install --config Release
cd ..
cd example/java
Remove-Item build -Force -Recurse -ErrorAction SilentlyContinue
mkdir build
cd build
cmake -A x64 -DCMAKE_INSTALL_PREFIX:PATH=../../../tdlib -DCMAKE_TOOLCHAIN_FILE:FILEPATH=../../../vcpkg/scripts/buildsystems/vcpkg.cmake -DTd_DIR:PATH=$(Resolve-Path ../td/lib/cmake/Td) ..
cmake --build . --target install --config Release
cd ../../..
cd ..
dir td/tdlib
```

其中，"Download and install Microsoft Visual Studio. Enable C++ support while installing."，我安装的是visual studio 2017 community版本，勾选“使用 C++ 的桌面开发”，同时比较坑的一点是，必须要安装“语言包”里的英文。因为没有安装英文语言包，我被坑了好久。

![](/img/vs-4-tdlib-compile.png)



编译的时间会很长哦

### 运行示例代码

编译完成后，找到相关文件：

1. 首先是 `td\tdlib`，这个目录有`bin`和`docs`两个文件夹。`docs`里面是javaDoc的htmls；`bin`文件夹存放示例代码(.java)和自动编译的.class以及`tdjni.dll`

2. td\vcpkg\installed\x64-windows\bin 存放了三个.dll文件，是tdjni所依赖的动态库。

运行`bin`中的示例代码：

1. 将 td\vcpkg\installed\x64-windows\bin中的三个ddl放到系统path中，让tdjni在运行时能找的到
2. 进入`td\tdlib\bin`，执行`java '-Djava.library.path=.' org/drinkless/tdlib/example/Example`,输出如下：

```
TextEntities {
  entities = Array[5] {
    TextEntity {
      offset = 0
      length = 9
      type = TextEntityTypeMention {
      }
    }
    TextEntity {
      offset = 10
      length = 13
      type = TextEntityTypeBotCommand {
      }
    }
    TextEntity {
      offset = 24
      length = 20
      type = TextEntityTypeUrl {
      }
    }
    TextEntity {
      offset = 45
      length = 11
      type = TextEntityTypeUrl {
      }
    }
    TextEntity {
      offset = 57
      length = 4
      type = TextEntityTypeMention {
      }
    }
  }
}

Please enter phone number:
```

可以看到已经进入输入电话号码进行登录的阶段了。

## 免编译，直接使用我编译好的dll

一共有四个dll文件，地址[tdlib-dll-windows10-x64.zip](https://cdn.arloor.com/tool/tdlib-dll-windows10-x64.zip)

限制：windows10 x64架构才能使用

内容：tdjni.dll(需要放在`-Djava.library.path=`指定的目录)； `dll/`路径下还有三个dll，需要放在系统的path中，供tdjni.dll动态链接。

## Idea maven项目

以上很麻烦吧，那么如何跳过以上步骤，直接享受开发的乐趣呢？请看[arloor/tdlib-use](https://github.com/arloor/tdlib-use)

运行说明：

- 仅支持windows10
- git clone https://github.com/arloor/tdlib-use
- git checkout raw 
- lib/: 存放dll文件；在运行前需要将lib/dll/下的三个文件放到path
- doc/: 存放javaDocs，为了方便查阅文档，一并提供
- 编辑 run configuration，在VM options中增加：`-Djava.library.path=lib`，以指定tgjni.dll的查询路径为lib/
- 点击运行，会进入电报登录过程

更多情况，还请移步Github

放一张效果图，打印出所有文字消息：

![](/img/tdlib-use-msgs.png)

## centos8 编译tdjni.so和安装相关依赖

> centos7不用尝试了，cmake版本不符合要求

```
yum install -y gcc gcc-c++ git make cmake openssl-devel zlib-devel php
wget -O gperf-3.1.tar.gz  http://ftp.gnu.org/pub/gnu/gperf/gperf-3.1.tar.gz
tar xf gperf-3.1.tar.gz
cd gperf-3.1
BUILD_LIBS=${HOME}/build_libs
export PATH=${BUILD_LIBS}/bin:${PATH}
export PKG_CONFIG_PATH=${BUILD_LIBS}/lib/pkgconfig:${PKG_CONFIG_PATH}
if [ -f autogen.sh ]; then
    ./autogen.sh
fi
./configure \
    --prefix=${BUILD_LIBS} \
    CFLAGS="-I${BUILD_LIBS}/include" \
    LDFLAGS="-L${BUILD_LIBS}/lib"
make
make install
cp src/gperf ${BUILD_LIBS}/bin
cd ~

##自行安装jdk8 
## 并确定JAVA_HOME，我的是/usr/java/jdk1.8.0_131 所以下文cmake我添加了-DJAVA_HOME=/usr/java/jdk1.8.0_131/

rm -rf td
git clone https://github.com/tdlib/td.git
cd td
git checkout v1.6.0
rm -rf build
mkdir build
cd build
export CXXFLAGS=""
cmake -DCMAKE_BUILD_TYPE=Release -DJAVA_HOME=/usr/java/jdk1.8.0_131/ -DCMAKE_INSTALL_PREFIX:PATH=../example/java/td -DTD_ENABLE_JNI=ON ..
cmake --build . --target install
cd ..
cd example/java
rm -rf build
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DJAVA_HOME=/usr/java/jdk1.8.0_131/ -DCMAKE_INSTALL_PREFIX:PATH=/usr/local -DTd_DIR:PATH=$(readlink -e ../td/lib/cmake/Td) ..
cmake --build . --target install
cd ../../..
cd ..
ls -l /usr/local
```

看到以下，则说明编译成功，libtdjni.so在`/usr/local/bin/libtdjni.so`



```
[100%] Built target tdjni
Install the project...
-- Install configuration: "Release"
-- Installing: /usr/local/bin/libtdjni.so
-- Set runtime path of "/usr/local/bin/libtdjni.so" to ""
```


运行：

```
java -Dproxy=http -Djava.library.path=/usr/local/bin  -jar tdlib-use-1.0-SNAPSHOT-jar-with-dependencies.jar
```
