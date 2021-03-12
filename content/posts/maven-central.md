---
title: "Maven发布到中央仓库"
date: 2021-02-02T20:05:02+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 1. 到sonatype上提交issue创建maven的groupid

可能有很多人要问这个不知名的sonatype是什么鬼东西？其实这就是maven中央仓库的托管机构。

首先需要注册sonatype的账号，账号名和密码需要记住，后面指的账号名和密码都是这个。

<!--more-->

issue内容如下：

![](/img/sonatype-create-project-id.png)

```
Type: New Project
Priority: Major
Labels:None
Group Id:com.arloor
Project URL:https://github.com/arloor/EasyCrawler
SCM url:https://github.com/arloor/EasyCrawler.git
Username(s):arloor
Already Synced to Central:No
```

相关信息和链接改成自己的就行。

提交issue后的交流如下：

![](/img/sonatype-issue-comment.png)

简单地说就是，你需要执行第一次`mvn deploy`将jar包往中央仓库推一下，管理员会帮你设定groupId。

提交issue这个步骤每个groupId只需要做一次。

## 设置本地maven，然后执行mvn deploy

在项目的`pom.xml`里做如下配置：

```
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-jar-plugin</artifactId>
                <version>2.6</version>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <configuration>
                    <source>8</source>
                    <target>8</target>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-source-plugin</artifactId>
                <version>2.2.1</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>jar-no-fork</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
            <!-- Javadoc -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-javadoc-plugin</artifactId>
                <version>2.9.1</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>jar</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
            <!-- GPG -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-gpg-plugin</artifactId>
                <version>1.6</version>
                <executions>
                    <execution>
                        <phase>verify</phase>
                        <goals>
                            <goal>sign</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>

    <distributionManagement>
        <snapshotRepository>
            <!-- snapshot仓库地址 -->
            <id>oss-snapshot</id>
            <url>https://oss.sonatype.org/content/repositories/snapshots/</url>
        </snapshotRepository>
        <repository>
            <!-- <!-- release仓库地址 --> -->
            <id>oss</id>
            <url>https://oss.sonatype.org/service/local/staging/deploy/maven2</url>
        </repository>
    </distributionManagement>
```

在maven的全局配置文件增加:

```xml
<servers>
    <server>
      <id>oss</id>
      <username>your_sonatype_username</username>
      <password>your_sonatype_passwd</password>
    </server>
    <server>
      <id>oss-snapshot</id>
      <username>your_sonatype_username</username>
      <password>your_sonatype_passwd</password>
    </server>
</servers>
```

## 创建gpg密钥

gpg（GunPG）是一款用于生成秘钥的加密软件。

- windows下载: https://www.gnupg.org/download/
- linux安装: 包管理器直接装
- MacOS: brew install gpg

gpg常用命令：

```
gpg --version 检查安装成功没
gpg --gen-key 生成密钥对
gpg --list-keys 查看公钥
gpg --keyserver hkp://keyserver.ubuntu.com:11371 --send-keys 公钥ID 将公钥发布到 PGP 密钥服务器
gpg --keyserver hkp://keyserver.ubuntu.com:11371 --recv-keys 公钥ID 查询公钥是否发布成功
```

依次执行上面的命令，创建和发布你的gpg密钥。后续的deploy将使用gpg密钥进行签名

## mvn deploy

然后就可以执行`mvn clean deploy`了，如果是第一次执行的话，记得到最初的sonatype issue上回复下。

之后可以到https://oss.sonatype.org/#stagingRepositories 这个网址，把你刚推上去的jar包 先close，再release（-SNAPSHOT的包不需要这个操作）

最好不要在idea中做mvn deploy，在命令行执行吧，因为检验gpg密钥的时候需要跳一个窗口出来验证下gpg的密码,如下：

![](/img/gpg_passwd.png)

对于mac，最好在.zshrc里加一个配置：

```
echo "export GPG_TTY=$(tty)" > ~/.zshrc
```