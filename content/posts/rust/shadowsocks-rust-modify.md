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

```java
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

    }
}
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

## 加密信道创建

```
    pub async fn connect_proxied(
        context: SharedContext,
        svr_cfg: &ServerConfig,
        addr: &Address,
    ) -> io::Result<ProxyStream> {
        debug!(
            "connect to {} via {} ({}) (proxied)",
            addr,
            svr_cfg.addr(),
            svr_cfg.external_addr()
        );

        // 创建tcp连接
        let server_stream = connect_proxy_server(&context, svr_cfg).await?;
        // 处理加密方法handshake，并且返回加密后的信道（重写）
        let proxy_stream = proxy_server_handshake(context.clone(), server_stream, svr_cfg, addr).await?;

        Ok(ProxyStream::Proxied {
            stream: proxy_stream,
            context,
        })
    }
```

## proxy_server_handshake调用创建CryptoStream

```
impl<S> CryptoStream<S> {
    /// Create a new CryptoStream with the underlying stream connection
    pub fn new(context: SharedContext, stream: S, svr_cfg: &ServerConfig) -> CryptoStream<S> {
        let method = svr_cfg.method();
        let prev_len = match method.category() {
            CipherCategory::Stream => method.iv_size(),
            CipherCategory::Aead => method.salt_size(),
        };

        let iv = match method.category() {
            CipherCategory::Stream => {
                let local_iv = loop {
                    let iv = method.gen_init_vec();
                    if context.check_nonce_and_set(&iv) {
                        // IV exist, generate another one
                        continue;
                    }
                    break iv;
                };
                trace!("generated Stream cipher IV {:?}", local_iv);
                local_iv
            }
            CipherCategory::Aead => {
                let local_salt = loop {
                    let salt = method.gen_salt();
                    if context.check_nonce_and_set(&salt) {
                        // Salt exist, generate another one
                        continue;
                    }
                    break salt;
                };
                trace!("generated AEAD cipher salt {:?}", local_salt);
                local_salt
            }
        };

        let method = svr_cfg.method();
        let enc = match method.category() {
            CipherCategory::Stream => EncryptedWriter::Stream(StreamEncryptedWriter::new(method, svr_cfg.key(), iv)),
            CipherCategory::Aead => EncryptedWriter::Aead(AeadEncryptedWriter::new(method, svr_cfg.key(), iv)),
        };

        CryptoStream {
            stream,
            dec: None,
            enc,
            read_status: ReadStatus::WaitIv(context, vec![0u8; prev_len], 0usize, method, svr_cfg.clone_key()),
        }
    }
```

## CryptoStream重写poll_read,poll_write来增加加解密

```
impl<S> AsyncRead for CryptoStream<S>
where
    S: AsyncRead + Unpin,
{
    fn poll_read(self: Pin<&mut Self>, ctx: &mut Context<'_>, buf: &mut [u8]) -> Poll<io::Result<usize>> {
        self.priv_poll_read(ctx, buf)
    }
}

impl<S> AsyncWrite for CryptoStream<S>
where
    S: AsyncWrite + Unpin,
{
    fn poll_write(self: Pin<&mut Self>, ctx: &mut Context<'_>, buf: &[u8]) -> Poll<io::Result<usize>> {
        self.priv_poll_write(ctx, buf)
    }

    fn poll_flush(self: Pin<&mut Self>, ctx: &mut Context<'_>) -> Poll<io::Result<()>> {
        self.priv_poll_flush(ctx)
    }

    fn poll_shutdown(self: Pin<&mut Self>, ctx: &mut Context<'_>) -> Poll<io::Result<()>> {
        self.priv_poll_shutdown(ctx)
    }
}
```