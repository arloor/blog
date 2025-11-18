---
title: "Rust sqlx使用记录"
date: 2024-12-05T22:17:05+08:00
draft: false
categories:
  - undefined
tags:
  - rust
weight: 10
subtitle: ""
description: ""
---

<!--more-->

## 依赖

```toml
sqlx = { version = "0.8.2", features = [
    "mysql",
    "runtime-tokio-rustls", # 使用rustls而不是native-tls
    # "runtime-tokio-native-tls",
    "chrono", # 使用chrono的时间类型，而不是sqlx自己的时间类型，例如PrimitiveDateTime
    # "time",
] }
sqlx-mysql = "0.8.2" # mysql驱动
```

## 查询宏

sqlx 支持自动生成 sql 查询语句对应的 Rust struct，这在编译期实现，因此可以在编译期确保你的 rust 代码和数据库表字段类型正确对应。又分为 online 代码生成和 offline 代码生成。

- online 指每次 cargo build 都扫描一次数据库表结构
- offline 指第一次 cargo build 扫描并生成缓存文件，后续直接使用缓存文件，直到表结构发生改变该缓存失效。

> set `DATABASE_URL` to use query macros online, or run `cargo sqlx prepare` to update the query cache

如引用文字所述，需要设置`DATABASE_URL` 以激活 online 的运行时代码生成或者执行`cargo sqlx prepare`来进行 offline 代码生成。

### 设置 DATABASE_URL 环境变量，进行 online 代码生成

方式一：在项目根目录下创建 `.env` 文件，文件内容如下（**推荐**）：

```toml
DATABASE_URL=mysql://user:passwd@host:3306/test?ssl-mode=Required&timezone=%2B08:00
```

方式二：在 vscode 的`tasks.json`的 `cargo build` 任务中设置该环境变量

```json
"env": {
    "DATABASE_URL": "mysql://user:passwd@host:3306/test?ssl-mode=Required&timezone=%2B08:00"
}
```

### offline 代码生成

1. 首先安装 sqlx-cli: 这里仅激活了 rustls 和 mysql 驱动的 feature

```bash
 cargo install sqlx-cli --no-default-features --features rustls,mysql
```

2. 然后使用“设置 DATABASE_URL 环境变量”中的方式一设置环境变量

3. 最后执行下面的命令:

```bash
cargo sqlx prepare
```

此时，会生成 `.sqlx` 文件夹，其中保存了缓存信息。这种方式的好处是，不需要将 `.env` 提交到代码仓库。

### 强制使用 offline 代码生成的缓存

在既有`DATABASE_URL`环境变量又有`.sqlx` 文件夹的情况下，sqlx 会优先使用`DATABASE_URL`环境变量进行 online 代码生成，从而确保代码是最新的。如果要强制使用`.sqlx` 文件夹的缓存，则需要在`.env` 中增加

```bash
SQLX_OFFLINE=true
```

参考文档：[Enable building in "offline mode" with query!()](https://github.com/launchbadge/sqlx/blob/main/sqlx-cli/README.md#enable-building-in-offline-mode-with-query)

### 查询宏 `query_as!`

可以自定义 struct name，前提是 struct 需要 derive FromRow

## 整体使用

```rust
info!("connecting to mysql...");
let pool: sqlx::Pool<sqlx::MySql> = MySqlPoolOptions::new()
    .max_connections(20)
    // .connect("mysql://user:passwprd@host:3306/test?ssl-mode=Required&timezone=%2B08:00") // 注意url部分需要urlencode
    .connect_with(
        MySqlConnectOptions::new()
            .host("host")
            .username("user")
            .password("passwrod")
            .database("test")
            .ssl_mode(MySqlSslMode::Required)
            .timezone(Some(String::from("+08:00"))),
    )
    .await?;

// 获取connection
let mut conn = pool.acquire().await?;
// 查询
select_variables(&mut conn).await?; //此处有一个deref_mut()，从PoolConnection<sqlx::MySql> 转成 sqlx::MySqlConnection

// ===============使用MySqlConnection========================
async fn select_variables(conn: &mut sqlx::MySqlConnection) -> Result<(), DynError> {
    let rows = sqlx::query!(r"show variables like '%time_zone%';")
        .fetch_all(&mut *conn)// 触发copy，从而复用connection
        .await?;
    for row in rows {
        info!("mysql variable: {:?}", row);
    }

    let rows = sqlx::query!(r"select now() as now_local, now() as now_naive, now() as now_utc;")
        .fetch_all(&mut *conn)// 触发copy，从而复用connection
        .await?;
    for row in rows {
        info!("select now(): {:?}", row);
    }

    let rows = sqlx::query!(r"SHOW SESSION STATUS WHERE Variable_name = 'Ssl_cipher';")
        .fetch_all(conn)
        .await?;
    for row in rows {
        info!("mysql variable: {:?}", row);
    }

    Ok(())
}

// ===============直接使用mysql pool======================
            let result = sqlx::query!(
                    r#"
                    INSERT INTO stock_rank_changes (
                        market, code, name, bankuai, calc_time, current_rank, ten_minute_change,
                        thirty_minute_change, hour_change, day_change, price, price_change_rate, trading_volume, turnover_rate, float_market_capitalization, realtime_data,
                        today_posts, today_posts_fetch_err, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE created_at = VALUES(created_at)
                    "#,
                    &stock_rank_change.market,
                    &stock_rank_change.code,
                    &stock_rank_change.name,
                    rt.map(|rt| rt.bankuai.clone()),
                    stock_rank_change.calc_time,
                    stock_rank_change.current_rank,
                    stock_rank_change.ten_minute_change,
                    stock_rank_change.thirty_minute_change,
                    stock_rank_change.hour_change,
                    stock_rank_change.day_change,
                    rt.map(|rt| rt.price),
                    rt.map(|rt| rt.price_change_rate),
                    rt.map(|rt| rt.trading_volume),
                    rt.map(|rt| rt.turnover_rate),
                    rt.map(|rt| rt.float_market_capitalization),
                    rt.map(|rt| serde_json::to_string(rt).unwrap_or("{}".to_string())),
                    serde_json::to_string(&stock_rank_change.today_posts)
                        .unwrap_or("[]".to_string()),
                    &stock_rank_change.today_posts_fetch_err,
                    Local::now().naive_local(),
                )
                .execute(&self.mysql_pool) //直接使用pool作为executor
                .await;

        match result {
            Ok(_) => {
                debug!("插入 stock_rank_changes 成功");
            }
            Err(e) => {
                warn!("插入 stock_rank_changes 失败： {}", e);
            }
        }

// =================	match self.mysql_pool.acquire()=================================
						match self.mysql_pool.acquire().await {
                // 将data根据时间排序
                Ok(mut conn) => {
                    let result= sqlx::query!(
                        r#"
                        INSERT INTO rank_record (hot_rank_score, inner_code, his_rank_change_rank, market_all_count, calc_time, his_rank_change, src_security_code, `rank`, hour_rank_change, rank_change)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        on duplicate key update update_time = now()
                    "#,
                        record.hot_rank_score,
                        record.inner_code,
                        record.his_rank_change_rank,
                        record.market_all_count,
                        record.calc_time,
                        record.his_rank_change,
                        record.src_security_code+&self.name,
                        record.rank,
                        record.hour_rank_change,
                        record.rank_change
                    )
                    .execute(conn.deref_mut()).await; // 手动调用deref_mut()，转成非池化的connection
                    match result {
                        Ok(_) => {
                            self.insert_history.insert(history_key, record.calc_time);
                        }
                        Err(e) => {
                            warn!("插入失败： {}", e);
                        }
                    }
                }
                Err(e) => warn!("获取连接失败 {}", e),
            }

```

## 参考文档

1. [sqlx 目前只有 pg 支持 batch insert，mysql 不支持](https://github.com/launchbadge/sqlx/blob/main/FAQ.md#how-can-i-bind-an-array-to-a-values-clause-how-can-i-do-bulk-inserts)
