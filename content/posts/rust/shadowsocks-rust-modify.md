---
title: "Shadowsocks Rust Modify"
date: 2020-03-22T15:13:17+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 处理socks5 connect请求

```rust
async fn handle_socks5_connect<'a>(
    server: &SharedPlainServerStatistic,
    stream: &mut TcpStream,
    client_addr: SocketAddr,
    addr: &Address,
) -> io::Result<()> {
    let context = server.context();
    let svr_cfg = server.server_config();

    let svr_s = match ProxyStream::connect(server.clone_context(), svr_cfg, addr).await {
        Ok(svr_s) => {
            // Tell the client that we are ready
            let header = TcpResponseHeader::new(socks5::Reply::Succeeded, Address::SocketAddress(svr_s.local_addr()?));
            header.write_to(stream).await?;

            trace!("sent header: {:?}", header);

            svr_s
        }
....
```

需要在这里修改成向server连接并发送http1.1 connect请求，并使用tls包裹

## 创建加密通信

```
    async fn connect_proxied_wrapped(
        context: SharedContext,
        svr_cfg: &ServerConfig,
        addr: &Address,
    ) -> Result<ProxyStream, ProxyStreamError> {
        match ProxyStream::connect_proxied(context, svr_cfg, addr).await {
            Ok(s) => Ok(s),
            Err(err) => Err(ProxyStreamError::new(err, false)),
        }
    }
```