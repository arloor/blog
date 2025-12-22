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

## 代码生成

```rust
let rows = sqlx::query!(r"show variables like '%time_zone%';")
    .fetch_all(&pool)
    .await?;
```

上面的 `sqlx::query!` 查询宏自动生成了 sql 结果集对应的 `Rust struct`。这在编译期实现，因此可以在编译期确保你的 rust 代码和数据库表字段类型正确对应。又分为 `online` 代码生成和 `offline` 代码生成。

- **online：** 指每次 cargo build 都扫描一次数据库表结构
- **offline：** 指第一次 cargo build 扫描并生成缓存文件，后续直接使用缓存文件，直到表结构发生改变该缓存失效。

### online 代码生成

设置 `DATABASE_URL` 环境变量即可

| 方式   | 说明                                                          | 配置示例                                                                                              | 推荐 |
| ------ | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ---- |
| 方式一 | 在项目根目录下创建 `.env` 文件                                | `DATABASE_URL=mysql://user:passwd@host:3306/test?ssl-mode=Required&timezone=%2B08:00`                 | ✅   |
| 方式二 | 在 VSCode 的 `tasks.json` 的 `cargo build` 任务中设置环境变量 | `"env": { "DATABASE_URL": "mysql://user:passwd@host:3306/test?ssl-mode=Required&timezone=%2B08:00" }` |      |

### offline 代码生成

1. 首先安装 sqlx-cli: 这里仅激活了 rustls 和 mysql 驱动的 feature

```bash
cargo install sqlx-cli --no-default-features --features rustls,mysql
```

2. 设置 `DATABASE_URL` 环境变量，方式同上

3. 最后执行下面的命令:

```bash
cargo sqlx prepare
```

此时，会生成 `.sqlx` 文件夹，其中保存了缓存信息。这种方式的好处是，不需要将 `.env` 提交到代码仓库。

#### 强制使用 offline 缓存

在既有 `DATABASE_URL` 环境变量又有 `.sqlx` 文件夹的情况下，sqlx 会优先使用 `DATABASE_URL` 环境变量进行 online 代码生成，从而确保代码是最新的。

如果要强制使用`.sqlx` 文件夹的缓存，则需要在`.env` 中增加

```bash
SQLX_OFFLINE=true
```

### 查询宏 `query_as!`

可以自定义 struct ，前提是 struct 需要 `derive FromRow`

```rust
#[derive(sqlx::FromRow)]
struct StockRankChangeDB {
    market: String,
    code: String,
    name: String,
    calc_time: Option<NaiveDateTime>,
    current_rank: i32,
    ten_minute_change: Option<i32>,
    thirty_minute_change: Option<i32>,
    hour_change: i32,
    day_change: i32,
    realtime_data: Option<String>,
    today_posts: Option<String>,
    today_posts_fetch_err: Option<String>,
    created_at: Option<NaiveDateTime>,
}
```

## 连接池初始化

创建 MySQL 连接池有两种方式：

### 方式一：使用连接字符串

```rust
info!("connecting to mysql...");
let pool: sqlx::Pool<sqlx::MySql> = MySqlPoolOptions::new()
    .max_connections(20)
    .connect("mysql://user:password@host:3306/test?ssl-mode=Required&timezone=%2B08:00") // URL 需要 urlencode
    .await?;
```

### 方式二：使用配置选项

```rust
info!("connecting to mysql...");
let pool: sqlx::Pool<sqlx::MySql> = MySqlPoolOptions::new()
    .max_connections(20)
    .connect_with(
        MySqlConnectOptions::new()
            .host("host")
            .username("user")
            .password("password")
            .database("test")
            .ssl_mode(MySqlSslMode::Required)
            .timezone(Some(String::from("+08:00"))),
    )
    .await?;
```

## 查询执行方式

### 方式一：使用连接池中的单个连接

适合需要在同一连接上执行多次查询的场景。

```rust
// 从连接池获取连接
let mut conn = pool.acquire().await?;

// 执行查询函数
select_variables(&mut conn).await?; // 发生 deref_mut()，从 PoolConnection<MySql> 转为 &mut MySqlConnection

// 查询函数示例
async fn select_variables(conn: &mut sqlx::MySqlConnection) -> Result<(), DynError> {
    // 查询系统变量
    let rows = sqlx::query!(r"show variables like '%time_zone%';")
        .fetch_all(&mut *conn) // 触发 copy，从而复用 connection
        .await?;
    for row in rows {
        info!("mysql variable: {:?}", row);
    }

    // 查询当前时间
    let rows = sqlx::query!(r"select now() as now_local, now() as now_naive, now() as now_utc;")
        .fetch_all(&mut *conn) // 触发 copy，从而复用 connection
        .await?;
    for row in rows {
        info!("select now(): {:?}", row);
    }

    // 查询 SSL 配置
    let rows = sqlx::query!(r"SHOW SESSION STATUS WHERE Variable_name = 'Ssl_cipher';")
        .fetch_all(conn)
        .await?;
    for row in rows {
        info!("mysql variable: {:?}", row);
    }

    Ok(())
}
```

### 方式二：直接使用连接池

适合单次查询，无需保持连接的场景。

```rust
let result = sqlx::query!(
        r#"
        INSERT INTO stock_rank_changes (
            market, code, name, bankuai, calc_time, current_rank, ten_minute_change,
            thirty_minute_change, hour_change, day_change, price, price_change_rate,
            trading_volume, turnover_rate, float_market_capitalization, realtime_data,
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
    .execute(&self.mysql_pool) // 直接使用 pool 作为 executor
    .await;

match result {
    Ok(_) => {
        debug!("插入 stock_rank_changes 成功");
    }
    Err(e) => {
        warn!("插入 stock_rank_changes 失败： {}", e);
    }
}
```

### 方式三：手动管理连接生命周期

适合需要精确控制连接获取和释放的场景。

```rust
match self.mysql_pool.acquire().await {
    Ok(mut conn) => {
        let result = sqlx::query!(
            r#"
            INSERT INTO rank_record (
                hot_rank_score, inner_code, his_rank_change_rank, market_all_count,
                calc_time, his_rank_change, src_security_code, `rank`,
                hour_rank_change, rank_change
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE update_time = now()
            "#,
            record.hot_rank_score,
            record.inner_code,
            record.his_rank_change_rank,
            record.market_all_count,
            record.calc_time,
            record.his_rank_change,
            record.src_security_code + &self.name,
            record.rank,
            record.hour_rank_change,
            record.rank_change
        )
        .execute(conn.deref_mut()) // 手动调用 deref_mut()，转成非池化的 connection
        .await;

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

## 注意事项

1. **批量插入限制**：sqlx 目前只有 PostgreSQL 支持 batch insert，MySQL 不支持。参考：[sqlx FAQ](https://github.com/launchbadge/sqlx/blob/main/FAQ.md#how-can-i-bind-an-array-to-a-values-clause-how-can-i-do-bulk-inserts)

2. **URL 编码**：使用连接字符串时，注意对特殊字符进行 urlencode

3. **连接复用**：使用 `&mut *conn` 可以触发 copy trait，从而在多次查询间复用同一连接

## 参考文档

1. [sqlx 目前只有 pg 支持 batch insert，mysql 不支持](https://github.com/launchbadge/sqlx/blob/main/FAQ.md#how-can-i-bind-an-array-to-a-values-clause-how-can-i-do-bulk-inserts)
2. [容器运行 mysql9+ssl 配置](https://www.arloor.com/posts/mysql9-docker-ssl/)
3. [Enable building in "offline mode" with query!()](https://github.com/launchbadge/sqlx/blob/main/sqlx-cli/README.md#enable-building-in-offline-mode-with-query)
