---
author: "刘港欢"
date: 2018-06-15
linktitle: redis与springboot整合学习
title: redis与springboot整合学习
categories: [ "java","redis","springboot"]
tags: ["program"]
weight: 10
---


最近在做一个电商网站。今天想要实现一下购物车的功能。




考虑问题如下：用户访问购物车会比较频繁，而且经常更改（比如修改数字）。对于后端的数据来说，也就是读写都很频繁。于是考虑通过redis，来减少对数据库的读写。

就研究一下怎么使用redis以及整合到springboot中。<!--more-->

cart数据库的设计如下：

```sql
DROP TABLE IF EXISTS `cart`;
CREATE TABLE `cart` (
  `uname` varchar(30) NOT NULL,
  `pid` int(30) NOT NULL,
  `num` int(10) DEFAULT NULL,
  PRIMARY KEY (`uname`,`pid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
```
其中pid是商品的唯一标识。uname是用户的唯一标识。

# 需要考虑哪几个问题

- 由于购物车是商品的列表，首先要考虑怎么存列表最好。
- 购物车的uname怎么体现——是谁的购物车
- 何时读取数据库、何时更新数据库、何时删除缓存
- 数据库里是一条条记录、在java中是一个个object、前端需要json。何时做这个转换以及redis中单个记录怎么存储（json，还是格式化的字符串）

先留下redis的文档地址[redis文档](https://redis.io/documentation)

# 在centos7.4安装配置redis4.0.9



## 下载、解压、安装gcc、编译

```shell
 wget http://download.redis.io/releases/redis-4.0.9.tar.gz
 tar xzf redis-4.0.9.tar.gz
 cd redis-4.0.9
 yum install gcc
 make MALLOC=libc
```

## 配置PATH
```shell
vim /etc/profile.d/custom.sh
## 在custome.sh中输入
export  PATH=$PATH:/root/redis-4.0.9/src
```

PATH生效之后（注意要生效，小白别说我坑，可以搜一下这个），输入`redis-server`会有如下控制台输出：

```shell

                _._                                                  
           _.-``__ ''-._                                             
      _.-``    `.  `_.  ''-._           Redis 4.0.9 (00000000/0) 64 bit
  .-`` .-```.  ```\/    _.,_ ''-._                                   
 (    '      ,       .-`  | `,    )     Running in standalone mode
 |`-._`-...-` __...-.``-._|'` _.-'|     Port: 6379
 |    `-._   `._    /     _.-'    |     PID: 13984
  `-._    `-._  `-./  _.-'    _.-'                                   
 |`-._`-._    `-.__.-'    _.-'_.-'|                                  
 |    `-._`-._        _.-'_.-'    |           http://redis.io        
  `-._    `-._`-.__.-'_.-'    _.-'                                   
 |`-._`-._    `-.__.-'    _.-'_.-'|                                  
 |    `-._`-._        _.-'_.-'    |                                  
  `-._    `-._`-.__.-'_.-'    _.-'                                   
      `-._    `-.__.-'    _.-'                                       
          `-._        _.-'                                           
              `-.__.-'                                               


```

## 设置服务与开机自动启动

修改 redis目录下的redis.conf 如下部分。将`daemonize no`设置为`daemonize yes`

```shell
# By default Redis does not run as a daemon. Use 'yes' if you need it.
# Note that Redis will write a pid file in /var/run/redis.pid when daemonized.
daemonize yes
```

```shell
mkdir /etc/redis
# 复制redis.conf 到 /etc/redis/6379.conf
cp /root/redis-4.0.9/redis.conf /etc/redis/6379.conf

#将redis的启动脚本复制到/etc/init.d中
cp /root/redis-4.0.9/utils/redis_init_script /etc/init.d/redisd

# 执行自启动命令
chkconfig redisd on
```

在执行`chkconfig redisd on`时报错`service redisd does not support chkconfig`。解决这个：

```shell
vim /etc/init.d/redisd
```
在第一行中加入如下注释：
```shell
#!/bin/sh
# chkconfig:   2345 90 10
# description:  Redis is a persistent key-value database
```
这两行的意思时，在运行级别为2、3、4、5时，自动启动redis。启动优先级90、关闭优先级10

再次执行`chkconfig redisd on`，就不报错了。

下面以服务的方式启动一下redis。

```
service redisd start
```

报错：

```
Starting Redis server...
/etc/init.d/redisd: line 21: /usr/local/bin/redis-server: No such file or directory
```

跟据报错信息，创建server、cli的软连接（redis-cli的软连接也是需要的）

```shell
ln -s /root/redis-4.0.9/src/redis-server /usr/local/bin/redis-server
ln -s /root/redis-4.0.9/src/redis-cli /usr/local/bin/redis-cli
```

再次执行`service redisd start`，使用`ps -aux | grep redis`可以看到redis进程的信息，说明配置成功。

## 记下没有遇到的坑

如果“某天”出现`/var/redis/run/redis_6379.pid exists, process is already running or crashed`的问题，说明机器有过异常断电或者崩溃。

科学的处理办法2种

- 可用安装文件启动 `redis-server /etc/redis/6379.conf`

- `shutdown -r now` 软重启让系统自动恢复下就行了

## 允许远程连接

```
/etc/redis/6379.conf中
1.将bind 127.0.0.1注释掉即可
2.设置密码 requirepass ....
3.（如果不设置密码需要）将protected-mode yes改为no
```

ps：网上说，他的机器没有设置密码，被挖矿了，吓得我设置了密码

## 解决设置密码之后的问题

设置密码之后使用`service redisd stop`会报这样

```
Stopping ...
(error) NOAUTH Authentication required.
Waiting for Redis to shutdown ...
Waiting for Redis to shutdown ...
Waiting for Redis to shutdown ...
## 这样并不能正确关闭redis
## 只能ps -aux |grep redis 找到pid 然后手动kill
```

这是因为`service redisd stop`使用的其实是`redis-cli -p 6379 shutdown`。当设置了密码之后，就需要`redis-cli -a "你的密码" -p 6379 shutdown`才能正常关闭服务。所以，在`/etc/init.d/redisd`中将stop下面的`$CLIEXEC -p $REDISPORT shutdown`改为`$CLIEXEC  -a "你的密码" -p $REDISPORT shutdown`

redis的安装和配置，基本到这里就结束了。

# springboot配置redis和使用redisTemplate

首先要说，springboot使用redis有两种方式：

- 用spring的cache抽象，就是给方法加上@EnableCache等等注解的方式
- 用redisTemplate。这种就类似于使用redis-cli终端一样，自己去设置key-value。

## application.properties和pom.xml

```xml
<dependency>
	<groupId>org.springframework.boot</groupId>
	<artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
```

上面的依赖貌似自动导入了jedis和一个连接池，不是很清楚

```shell
# redis
# Redis数据库索引（默认为0）
spring.redis.database=0
# Redis服务器地址
spring.redis.host=hostname/ip
# Redis服务器连接端口
spring.redis.port=6379
# Redis服务器连接密码（默认为空）
spring.redis.password=passwdIfAny
# 连接池最大连接数（使用负值表示没有限制）
spring.redis.jedis.pool.max-active=8
# 连接池最大阻塞等待时间（使用负值表示没有限制）
spring.redis.jedis.pool.max-wait=-1
# 连接池中的最大空闲连接
spring.redis.jedis.pool.max-idle=8
# 连接池中的最小空闲连接
spring.redis.jedis.pool.min-idle=0
# 连接超时时间（毫秒）
spring.redis.timeout=5000 ##如果非本机，这个不能为0，否则会报timeout
```

## 使用redisTemplate

因为springboot的自动配置，很开心，有了这些配置，就可以直接使用redisTemplate了。

测试代码：

```
@RunWith(SpringRunner.class)
	@SpringBootTest
	public class EmarketApplicationTests {
		@Autowired
		private RedisTemplate redisTemplate;
		
		@Test
		public void set() throws InterruptedException {
			ValueOperations value=redisTemplate.opsForValue();
			value.set("名字","刘港欢");

			for (int i = 0; i <20 ; i++) {
				System.out.println(value.get("test"));
				Thread.sleep(1000);
			}
		}
}
```
测试结果表明能正常运行，而且中文也没有问题。

首先自动导入`RedisTemplate`依赖。

然后使用`redisTemplate.opsFor...();`就能得到支持的操作，剩下的看代码就能理解。

上面的`opsfor...`,for后面的部分就是redis支持的数据类型，这个以后可以写一篇博客。。。

## redis的Serializer带来的小问题

代码的`value.get`能正常运行，但是在redis-cli运行`get 你设置key`就显示nil(null)。原因是使用了`JdkSerializationRedisSerializer`，将对象的类型信息也加入了key。

于是真正的key为

```
\xac\xed\x00\x05t\x00\x06\xe5\x90\x8d\xe5\xad\x97test
```

要是强迫症的话，需要自己配置`redisTemplate`这个bean，具体说就是要调用`redis.setKeySerializer(..);`这种。

当然我也只是遇到了这个问题，而没有真正解决，如果真的因为这个出bug，我再找解决方案吧

## 最后怎么用redis的

用了很暴力的办法。抛弃了数据库，购物车完全用redis的String
保存，值直接就是前端需要用的json，格式还挺复杂的。问题就是不会持久化购物车信息。设置超时5分钟，redis中的记录就删除，很暴力了。。。
