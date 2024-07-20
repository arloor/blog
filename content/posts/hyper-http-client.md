---
title: "Rust reqwest代码阅读"
date: 2024-07-20T11:26:42+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---


最近在自己的rust_http_proxy中实现了简单的反向代理，第一版用的是手搓的无连接池版本，大致流程如下：

1. 首先 `TcpStream::connect` 建立连接
2. 通过 `hyper::client::conn::http1::Builder` 拿到 `sender`
3. 发送请求 `sender.send_request(new_req).await` 

工作的很正常，但是没有连接池。想到 `hyper` 官方提供的 `reqwest` 是有内置连接池的，于是研究了下做了改造，记录下过程中读到的代码。
<!--more-->

## 无连接池的reverse_proxy

```Rust
async fn reverse_proxy(
        &self,
        client_socket_addr: SocketAddr,
        authority: String,
        req: Request<Incoming>,
        plain_host: &str,
        plain_port: u16,
    ) -> Result<Response<BoxBody<Bytes, io::Error>>, io::Error> {
        let target = format!("{}:{}", plain_host, plain_port);
        info!(
            "{} fetch plaintext of {}:{} through {}",
            SocketAddrFormat(&client_socket_addr),
            plain_host,
            plain_port,
            authority
        );
        let stream = TcpStream::connect((plain_host, plain_port)).await?;
        let io = TokioIo::new(stream);
        match hyper::client::conn::http1::Builder::new()
            .preserve_header_case(true)
            .title_case_headers(true)
            .handshake(Box::pin(io))
            .await
        {
            Ok((mut sender, conn)) => {
                tokio::task::spawn(async move {
                    if let Err(err) = conn.await {
                        warn!("reverse proxy connection failed: {:?}", err);
                    }
                });

                let method = req.method().clone();
                let url = req.uri().clone();
                let url = match url.path_and_query() {
                    Some(path_and_query) => path_and_query.as_str(),
                    None => "/",
                };
                let mut new_req_builder = Request::builder()
                    .method(method.clone())
                    .uri(url)
                    .version(Version::HTTP_11);
                for ele in req.headers() {
                    new_req_builder = new_req_builder.header(ele.0, ele.1);
                    debug!("{}: {:?}", ele.0, ele.1);
                }

                let mut new_req: Request<Incoming> = new_req_builder
                    .body(req.into_body())
                    .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
                new_req.headers_mut().remove(http::header::HOST.to_string());
                // 这一版一定是HTTP/1.1，一定需要Host
                new_req.headers_mut().insert(
                    http::header::HOST,
                    HeaderValue::from_str(&target).unwrap_or(HeaderValue::from_static("unknown")),
                );

                if let Ok(resp) = sender.send_request(new_req).await {
                    Ok(resp.map(|b| {
                        b.map_err(|e| {
                            let e = e;
                            io::Error::new(ErrorKind::InvalidData, e)
                        })
                        .boxed()
                    }))
                } else {
                    Err(io::Error::new(ErrorKind::ConnectionAborted, "连接失败"))
                }
            }
            Err(e) => Err(io::Error::new(ErrorKind::ConnectionAborted, e)),
        }
    }
```

hyper_util::client::legacy::client::Client
impl<C, B> Client<C, B>
pub fn request(&self, req: Request<B>) -> ResponseFuture
where
    // Bounds from impl:
    C: Connect + Clone + Send + Sync + 'static,
    B: Body + Send + 'static + Unpin,
    B::Data: Send,
    B::Error: Into<Box<dyn StdError + Send + Sync>>,
Send a constructed Request using this Client.