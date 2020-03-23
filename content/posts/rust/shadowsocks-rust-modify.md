---
title: "Shadowsocks-rust源码阅读【where to modify】"
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

看看shadowsocks-rust的源码，确定需要改哪里
<!--more-->

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
        // 处理加密方法handshake，并且返回加密后的信道（重写），在这里面会发送CONNECT地质
        let proxy_stream = proxy_server_handshake(context.clone(), server_stream, svr_cfg, addr).await?;

        Ok(ProxyStream::Proxied {
            stream: proxy_stream,
            context,
        })
    }
```

## 啊啊啊

```java
async fn proxy_server_handshake(
    context: SharedContext,
    remote_stream: STcpStream,
    svr_cfg: &ServerConfig,
    relay_addr: &Address,
) -> io::Result<CryptoStream<STcpStream>> {
    //todo: 进入改动点1
    let mut stream = CryptoStream::new(context, remote_stream, svr_cfg);

    trace!("got encrypt stream and going to send addr: {:?}", relay_addr);

    // Send relay address to remote
    //
    // NOTE: `Address` handshake packets are very small in most cases,
    // so it will be sent with the IV/Nonce data (implemented inside `CryptoStream`).
    //
    // For lower latency, first packet should be sent back quickly,
    // so TCP_NODELAY should be kept enabled until the first data packet is received.
    //todo: 进入改动点2
    let mut addr_buf = BytesMut::with_capacity(relay_addr.serialized_len());
    relay_addr.write_to_buf(&mut addr_buf);
    stream.write_all(&addr_buf).await?;

    // Here we should keep the TCP_NODELAY set until the first packet is received.
    // https://github.com/shadowsocks/shadowsocks-libev/pull/746
    //
    // Reset TCP_NODELAY after the first packet is received and sent back.

    Ok(stream)
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

在我这里仅需要重写poll_read，poll_write为包裹tls即可  tokio-tls

## 修改点

- CryptoStream： poll_read，poll_write，poll_read_handshake 通过ssl加密
- ProxyStream： proxy_server_handshake 通过Http connect传递地质

https://github.com/tokio-rs/tokio/tree/master/tokio-tls

/etc/pki/tls/certs/ca-bundle.crt


  187  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  188  git clone https://github.com/arloor/socks5-https.git
  189  yum install -y git
  190  git clone https://github.com/arloor/socks5-https.git
  191  cd socks5-https/
  192  ls
  193  cargo build --release
  194  ls ~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/
  195  vim /etc/profile.d/rust.sh
  196  ls  ~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/
  197  . /etc/profile.d/rust.sh
yum install gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto c-ares-devel libev-devel -y
dnf install openssl-devel
SODIUM_LIB_DIR=/usr/lib64/
SODIUM_SHARED=1
openssl = {version = "0.10", optional = true}
cargo build --release


 libtun2socks.so --netif-ipaddr 172.19.0.2 --socks-server-addr 127.0.0.1:1080 --tunmtu 1500 --sock-path sock_path --dnsgw 127.0.0.1:5450 --loglevel warning --enable-udprelay
 libss-local.so -b 127.0.0.1 -l 1080 -t 600 -S /data/user_de/0/com.github.shadowsocks/no_backup/stat_main -c /data/user/0/com.github.shadowsocks/no_backup/shadowsocks.conf -V -u --acl /data/user_de/0/com.github.shadowsocks/no_backup/bypass-lan-china.acl --fast-open