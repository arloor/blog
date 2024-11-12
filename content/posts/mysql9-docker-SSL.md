---
title: "MySQL9 docker容器配置SSL"
subtitle:
date: 2024-11-10T15:05:05+08:00
draft: false
categories: 
- undefined
tags: 
- notion
weight: 10
subtitle: ""
description : ""
---

最近写个小东西用到了MySQL，折腾下怎么给MySQL配置SSL
<!--more-->

## MySQL Daemon配置

```bash
#rm -rf /var/lib/mysql
docker stop mysql
mkdir -p /var/lib/mysql /etc/mysql/conf.d
cat > /etc/mysql/conf.d/ssl.cnf <<EOF
[mysqld]
ssl_ca=/etc/mysql/ssl/ca.cer
ssl_cert=/etc/mysql/ssl/arloor.dev.cer
ssl_key=/etc/mysql/ssl/arloor.dev.key
require_secure_transport=ON
EOF
docker run -d --rm  --name mysql \
--network host \
-v /var/lib/mysql:/var/lib/mysql \
-v /etc/mysql/conf.d:/etc/mysql/conf.d \
-v /root/.acme.sh/arloor.dev:/etc/mysql/ssl \
-e MYSQL_DATABASE=test \
-e MYSQL_ROOT_PASSWORD=xxxxxx \
docker.io/library/mysql:9.1 
```

**解释：**

1. MySQL 数据文件在 `/var/lib/mysql`
2. 在 `/etc/mysql/conf.d/ssl.cnf` 中指定了 acme.sh 生成的ssl证书，并强制要求客户端ssl连接

**一些坑点：**

1. MySQL docker容器只能访问特定的文件夹（SELinux和ApkArmor机制），例如 `/var/lib/mysql` 和`/etc/mysql` 。如果将SSL证书放在别的地方，会报错  `Unable to get private key from xxx` 。这个脚本把ssl证书放在了`/etc/mysql`。
2. 这里挂在了宿主机的 `/var/lib/mysql`。在第一次运行本脚本时，该文件夹为空，此时dockerfile会执行初始化操作，例如创建数据库、创建root用户、设置root用户密码等。
    1. 如果初始化时`/var/lib/mysql` 不为空，则会直接报错，所以不把ssl证书挂载在`/var/lib/mysql`中。
    2. 如果是后续再执行该脚本，则不会执行初始化。这意味着如果`/var/lib/mysql`的关键数据在的话，不会重新创建数据库、root用户、也不会修改root密码。也就是说，后续你稍微改了脚本中的 `MYSQL_DATABASE`和 `MYSQL_ROOT_PASSWORD` 环境变量也不会生效。

### 建表

```bash
docker exec mysql sh -c '
mysql -pYOUR_PASSWORD -e "
use test
DROP TABLE IF EXISTS rank_record;
CREATE TABLE rank_record (
    id BIGINT NOT NULL AUTO_INCREMENT,
    hot_rank_score DOUBLE NOT NULL,
    inner_code VARCHAR(255) NOT NULL,
    his_rank_change_rank INT NOT NULL,
    market_all_count INT NOT NULL,
    calc_time DATETIME NOT NULL,
    his_rank_change INT NOT NULL,
    src_security_code VARCHAR(255) NOT NULL,
    \`rank\` INT NOT NULL,
    hour_rank_change INT NOT NULL,
    rank_change INT DEFAULT NULL,
    update_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE INDEX idx_inner_code_calc_time (inner_code, calc_time)
);
show tables
"
'
```

## macOS连接

```bash
brew install mysql-client
echo 'export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"' >> ~/.zshrc
export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"
mysql test -h xxxx.com -u root --password=xxxxxx --ssl-mode=REQUIRED
## 执行 SHOW SESSION STATUS LIKE 'Ssl_cipher'; 或 \s; 确认ssl已激活
```

## Rust sqlx 连接：

```rust
let pool: sqlx::Pool<sqlx::MySql> = MySqlPoolOptions::new()
    .max_connections(20)
    // .connect("mysql://root:@127.0.0.1:3306/test")
    .connect_with(
        MySqlConnectOptions::new()
            .host("xxxx.com")
            .username("root")
            .password("xxxxxxx")
            .database("test")
            .ssl_mode(MySqlSslMode::Required),
    )
    .await?;
```

## Grafana配置数据源

核心是要打开 `With CA Cert` ，并把 `ssl_ca=` 指定的ca证书内容贴在下面，否则Grafana不会尝试使用ssl连接，就会被mysql服务端拒绝。 

![d27be30b18dff83b4aa40501bb9a0816.png](/img/d27be30b18dff83b4aa40501bb9a0816.png)

## 参考文档

1. [8.3.1 Configuring MySQL to Use Encrypted Connections](https://dev.mysql.com/doc/refman/9.1/en/using-encrypted-connections.html)
2. [MySqlConnectOptions in sqlx::mysql - Rust](https://docs.rs/sqlx/latest/sqlx/mysql/struct.MySqlConnectOptions.html)
3. [MySQL cannot get private key from a readable folder : r/mysql](https://www.reddit.com/r/mysql/comments/1enwniu/mysql_cannot_get_private_key_from_a_readable/)
