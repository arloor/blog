---
title: "Rust reqwest代码阅读"
date: 2024-07-20T11:26:42+08:00
draft: false
categories: [ "undefined"]
tags: ["rust"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---


最近在自己的[rust_http_proxy](https://github.com/arloor/rust_http_proxy)中实现了简单的反向代理，第一版用的是手搓的无连接池版本，大致流程如下：

1. 首先 `TcpStream::connect` 建立连接
2. 通过 `conn::http1::Builder` 拿到 `sender`
3. 发送请求 `sender.send_request(new_req)` 

工作的很正常，但是没有连接池。想到 `hyper` 官方提供的 `reqwest` 是有内置连接池的，于是研究了下做了改造，记录下过程中读到的代码。
<!--more-->

## 无连接池的reverse_proxy

```Rust
async fn reverse_proxy(
        req: Request<Incoming>, // 原始请求
        plain_host: &str, // 目标主机
        plain_port: u16, // 目标端口
    ) -> Result<Response<BoxBody<Bytes, io::Error>>, io::Error> {
        let stream = TcpStream::connect((plain_host, plain_port)).await?;
        let io = TokioIo::new(stream);
        match hyper::client::conn::http1::Builder::new()
            .preserve_header_case(true)
            .title_case_headers(true)
            .handshake(Box::pin(io))
            .await
        {
            Ok((mut sender, conn)) => {
                tokio::task::spawn(async move { // conn是一个future，tokio::spawn来poll它，驱动它完成
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
                let target = format!("{}:{}", plain_host, plain_port);
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

## 发现reqwest对 `legacy::client::Client` 的使用

下面是 `reqwest` 发起执行请求的代码，关注用 `!!!` 标注的注释

```Rust
    /// Executes a `Request`.
    ///
    /// A `Request` can be built manually with `Request::new()` or obtained
    /// from a RequestBuilder with `RequestBuilder::build()`.
    ///
    /// You should prefer to use the `RequestBuilder` and
    /// `RequestBuilder::send()`.
    ///
    /// # Errors
    ///
    /// This method fails if there was an error while sending request,
    /// redirect loop was detected or redirect limit was exhausted.
    pub fn execute(
        &self,
        request: Request, // ！！！类型是 reqwest::async_impl::request，我们不能直接使用，看下面会转换成http::Reqwest
    ) -> impl Future<Output = Result<Response, crate::Error>> {
        self.execute_request(request)
    }

    pub(super) fn execute_request(&self, req: Request) -> Pending {
        let (method, url, mut headers, body, timeout, version) = req.pieces();
        if url.scheme() != "http" && url.scheme() != "https" {
            return Pending::new_err(error::url_bad_scheme(url));
        }

        // check if we're in https_only mode and check the scheme of the current URL
        if self.inner.https_only && url.scheme() != "https" {
            return Pending::new_err(error::url_bad_scheme(url));
        }

        // insert default headers in the request headers
        // without overwriting already appended headers.
        for (key, value) in &self.inner.headers {
            if let Entry::Vacant(entry) = headers.entry(key) {
                entry.insert(value.clone());
            }
        }

        // Add cookies from the cookie store.
        #[cfg(feature = "cookies")]
        {
            if let Some(cookie_store) = self.inner.cookie_store.as_ref() {
                if headers.get(crate::header::COOKIE).is_none() {
                    add_cookie_header(&mut headers, &**cookie_store, &url);
                }
            }
        }

        let accept_encoding = self.inner.accepts.as_str();

        if let Some(accept_encoding) = accept_encoding {
            if !headers.contains_key(ACCEPT_ENCODING) && !headers.contains_key(RANGE) {
                headers.insert(ACCEPT_ENCODING, HeaderValue::from_static(accept_encoding));
            }
        }

        let uri = match try_uri(&url) {
            Ok(uri) => uri,
            _ => return Pending::new_err(error::url_invalid_uri(url)),
        };

        let (reusable, body) = match body {
            Some(body) => {
                let (reusable, body) = body.try_reuse();
                (Some(reusable), body)
            }
            None => (None, Body::empty()),
        };

        self.proxy_auth(&uri, &mut headers);

        let builder = hyper::Request::builder() // ！！！转成我们可以直接使用的hyper::Request
            .method(method.clone())
            .uri(uri)
            .version(version);

        let in_flight = match version {
            #[cfg(feature = "http3")]
            http::Version::HTTP_3 if self.inner.h3_client.is_some() => {
                let mut req = builder.body(body).expect("valid request parts");
                *req.headers_mut() = headers.clone();
                ResponseFuture::H3(self.inner.h3_client.as_ref().unwrap().request(req))
            }
            _ => {
                let mut req = builder.body(body).expect("valid request parts");
                *req.headers_mut() = headers.clone();
                ResponseFuture::Default(self.inner.hyper.request(req)) // ！！！调用hyper_util::client::legacy::client::Client
            }
        };

        let total_timeout = timeout
            .or(self.inner.request_timeout)
            .map(tokio::time::sleep)
            .map(Box::pin);

        let read_timeout_fut = self
            .inner
            .read_timeout
            .map(tokio::time::sleep)
            .map(Box::pin);

        Pending {
            inner: PendingInner::Request(PendingRequest {
                method,
                url,
                headers,
                body: reusable,

                urls: Vec::new(),

                retry_count: 0,

                client: self.inner.clone(),

                in_flight,
                total_timeout,
                read_timeout_fut,
                read_timeout: self.inner.read_timeout,
            }),
        }
    }
```

看完这段代码之后，就知道核心是使用 `hyper-util` 的 `legacy client` 的 `request` 方法：

```Rust
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
```

值得说明的是 `legacy client` 并不是“过时”的意思，而是 `hyper` 库从 `0.14` 升级到 `1.0` 时，将其从 `hyper` 移动到了 `hyper-util`。可以理解为从hyper体系的核心库移动到了外围实用组件。见下面引用自[Upgrade from v0.14 to v1](https://hyper.rs/guides/1/upgrading/)的描述

> The higher-level pooling Client was removed from `hyper 1.0`. A similar type was added to `hyper-util`, called `client::legacy::Client`. It’s mostly a drop-in replacement.

## 跟一下legacy client中池化的实现

`legacy client` 的核心实现都在 `impl<C, B> Client<C, B>` 中，核心方法有：

```Rust
// 发送请求
pub fn request(&self, req: Request<B>) -> ResponseFuture
// 从pool中找一条connection，发起请求
async fn try_send_request(&self, mut req: Request<B>, pool_key: PoolKey) -> Result<Response<hyper::body::Incoming>, TrySendError<B>>
// 从pool中找一条connection
async fn connection_for(&self, pool_key: PoolKey) -> Result<pool::Pooled<PoolClient<B>, PoolKey>, Error>
```

大致流程时将scheme、host、port作为pool_key找到一个连接（PoolClient），然后使用PoolClient的 `try_send_request` 方法。 `try_send_request` 定义如下：

```Rust
impl<B: Body + 'static> PoolClient<B> {
    fn try_send_request(
        &mut self,
        req: Request<B>,
    ) -> impl Future<Output = Result<Response<hyper::body::Incoming>, ConnTrySendError<Request<B>>>>
    where
        B: Send,
    {
        #[cfg(all(feature = "http1", feature = "http2"))]
        return match self.tx {
            #[cfg(feature = "http1")]
            PoolTx::Http1(ref mut tx) => Either::Left(tx.try_send_request(req)),
            #[cfg(feature = "http2")]
            PoolTx::Http2(ref mut tx) => Either::Right(tx.try_send_request(req)),
        };

        #[cfg(feature = "http1")]
        #[cfg(not(feature = "http2"))]
        return match self.tx {
            #[cfg(feature = "http1")]
            PoolTx::Http1(ref mut tx) => tx.try_send_request(req),
        };

        #[cfg(not(feature = "http1"))]
        #[cfg(feature = "http2")]
        return match self.tx {
            #[cfg(feature = "http2")]
            PoolTx::Http2(ref mut tx) => tx.try_send_request(req),
        };
    }
}
```

当我们走进 `http1` 的 `tx.try_send_request(req)`，发现这个 `PoolClient.tx` 就是之前无连接池版本中的 `sender`，就是下面这个 `handshake` 的返回值：

```Rust
hyper::client::conn::http1::Builder::new()
    .preserve_header_case(true)
    .title_case_headers(true)
    .handshake(Box::pin(io))
    .await
```

至此，无连接池和有连接池的版本交会了，连接池中实际放的是就是之前的 `sender: http1::SendRequest`，见下面的定义。

```Rust
#[allow(missing_debug_implementations)]
struct PoolClient<B> {
    conn_info: Connected,
    tx: PoolTx<B>,
}

enum PoolTx<B> {
    #[cfg(feature = "http1")]
    Http1(hyper::client::conn::http1::SendRequest<B>),
    #[cfg(feature = "http2")]
    Http2(hyper::client::conn::http2::SendRequest<B>),
}
```

我们可以额外关注下的http1部分，可以更清晰的看到和无连接连接池版本的相通之处

```Rust
hyper_util::client::legacy::client::Client
impl<C, B> Client<C, B>
fn connect_to(&self, pool_key: PoolKey) -> impl Lazy<Output = Result<pool::Pooled<PoolClient<B>, PoolKey>, Error>> + Send + Unpin

............

#[cfg(feature = "http1")] {
let (mut tx, conn) =
    h1_builder.handshake(io).await.map_err(Error::tx)?; // 1. 熟悉的hanshake

trace!(
    "http1 handshake complete, spawning background dispatcher task"
);
executor.execute( // 这里实际就是tokio::spawn，和无连接池版本一样
    conn.with_upgrades()
        .map_err(|e| debug!("client connection error: {}", e))
        .map(|_| ()),
);

// Wait for 'conn' to ready up before we
// declare this tx as usable
tx.ready().await.map_err(Error::tx)?;
return PoolTx::Http1(tx)
}                            
```

## 跟一下真正发送http请求的代码（hyper）

让我们从hyper-util走到hyper，看看hyper这个底层库是如何发送http请求的。看这个的意义在于确定我们将http2请求的body转换成http1.1的body是否有损，具体来说是，将http2分帧的body的转换成http1.1的`Transfer-Encoding: chunked`的body是否有损。答案是无损的。

我们先从上节的继续看起

```Rust
hyper::client::conn::http1::SendRequest
impl<B> SendRequest<B>
pub fn send_request(&mut self, req: Request<B>) -> impl Future<Output = crate::Result<Response<IncomingBody>>>
where
    // Bounds from impl:
    B: Body + 'static,
{
let sent = self.dispatch.send(req); // 返回的是respones的receiver

async move {
    match sent {
        Ok(rx) => match rx.await {
            Ok(Ok(resp)) => Ok(resp), // 如果从receiver中拿到了response，返回
            Ok(Err(err)) => Err(err),
            // this is definite bug if it happens, but it shouldn't happen!
            Err(_canceled) => panic!("dispatch dropped without returning error"),
        },
        Err(_req) => {
            debug!("connection was not ready");
            Err(crate::Error::new_canceled().with("connection was not ready"))
        }
    }
}
........

// self.dispatch.send(req);的定义
#[cfg(feature = "http1")]
pub(crate) fn send(&mut self, val: T) -> Result<Promise<U>, T> {
    if !self.can_send() {
        return Err(val);
    }
    let (tx, rx) = oneshot::channel();
    self.inner
        .send(Envelope(Some((val, Callback::NoRetry(Some(tx))))))
        .map(move |_| rx)
        .map_err(|mut e| (e.0).0.take().expect("envelope not dropped").0)
}
```

这个 `inner.send` 是发送到了一个channel中，那这个channel的接收者在哪呢？答案是我们之前看到的被 `tokio::spawn` 的`Connection`中。这里有必要给出`Connection`的定义：

```Rust
/// A future that processes all HTTP state for the IO object.
///
/// In most cases, this should just be spawned into an executor, so that it
/// can process incoming and outgoing messages, notice hangups, and the like.
#[must_use = "futures do nothing unless polled"]
pub struct Connection<T, B>
where
    T: Read + Write,
    B: Body + 'static,
{
    inner: Dispatcher<T, B>,
}
```

Connection被 `tokio::spawn` 说明他是个 `Future`，他的逻辑就在 `poll` 方法中，我们看下这个 `poll` 方法：

```Rust
impl<T, B> Future for Connection<T, B>
where
    T: Read + Write + Unpin,
    B: Body + 'static,
    B::Data: Send,
    B::Error: Into<Box<dyn StdError + Send + Sync>>,
{
    type Output = crate::Result<()>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        match ready!(Pin::new(&mut self.inner).poll(cx))? { // 调用 inner: Dispatcher<T, B> 的poll
            proto::Dispatched::Shutdown => Poll::Ready(Ok(())),
            proto::Dispatched::Upgrade(pending) => {
                // With no `Send` bound on `I`, we can't try to do
                // upgrades here. In case a user was trying to use
                // `upgrade` with this API, send a special
                // error letting them know about that.
                pending.manual();
                Poll::Ready(Ok(()))
            }
        }
    }
}
```

这里就是推动 `inner: Dispatcher`的执行，我们继续看 `Dispatcher` 的poll（trait bounds有点多，经典类型体操）：

```Rust
impl<D, Bs, I, T> Future for Dispatcher<D, Bs, I, T>
where
    D: Dispatch<
            PollItem = MessageHead<T::Outgoing>,
            PollBody = Bs,
            RecvItem = MessageHead<T::Incoming>,
        > + Unpin,
    D::PollError: Into<Box<dyn StdError + Send + Sync>>,
    I: Read + Write + Unpin,
    T: Http1Transaction + Unpin,
    Bs: Body + 'static,
    Bs::Error: Into<Box<dyn StdError + Send + Sync>>,
{
    type Output = crate::Result<Dispatched>;

    #[inline]
    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        self.poll_catch(cx, true)
    }
}
```

而后逐步走到 `poll_inner`、`poll_loop`，有经验而敏感的同学看到`poll_loop`就知道 Reacotr模式的事件循环（eventloop）他来了。这个`poll_loop`值得贴一下源码，因为涉及到其他future的饥饿问题，可能自己在做设计的时候也要考虑

```Rust
fn poll_loop(&mut self, cx: &mut Context<'_>) -> Poll<crate::Result<()>> {
    // Limit the looping on this connection, in case it is ready far too
    // often, so that other futures don't starve.
    //
    // 16 was chosen arbitrarily, as that is number of pipelined requests
    // benchmarks often use. Perhaps it should be a config option instead.
    for _ in 0..16 {
        let _ = self.poll_read(cx)?;
        let _ = self.poll_write(cx)?;
        let _ = self.poll_flush(cx)?;

        // This could happen if reading paused before blocking on IO,
        // such as getting to the end of a framed message, but then
        // writing/flushing set the state back to Init. In that case,
        // if the read buffer still had bytes, we'd want to try poll_read
        // again, or else we wouldn't ever be woken up again.
        //
        // Using this instead of task::current() and notify() inside
        // the Conn is noticeably faster in pipelined benchmarks.
        if !self.conn.wants_read_again() {
            //break;
            return Poll::Ready(Ok(()));
        }
    }
    trace!("poll_loop yielding (self = {:p})", self);
    task::yield_now(cx).map(|never| match never {}) // 让出执行，避免其他饥饿
}
```

接着走进 `poll_write`的逻辑，就能看到具体的http请求的发送逻辑了。这里只截图我关注的HTTP2转HTTP1.1时是否能自动增加 `Transfer-Encoding: chunked`，简要总结下，如果没有设置 `Content-Length`，则会自动增加 `Transfer-Encoding: chunked`。截图左侧的调用栈也可以关注下。

![alt text](/img/hyper_http1_poll_write_debug.png)

## 最终构建legacy client的代码，支持HTTPS

```toml
[dependencies]
hyper-rustls = { version = "0", default-features = false, features = [
    "rustls-platform-verifier",
    "http2",
    "native-tokio",
    "http1",
    "logging",
] } 
hyper-util = { version = "0.1", features = ["tokio", "server-auto"] }
rustls = { version = "0" }
rustls-native-certs = "0"
webpki-roots = "0"
http = "1"
```

hyper-rustls中的ring或者aws-lc-rs是受自己crate的可选feature控制的，这里没有展示出来


```Rust
fn build_http_client() -> Client<hyper_rustls::HttpsConnector<HttpConnector>, Incoming> {
    // 创建一个 HttpConnector
    let mut http_connector = HttpConnector::new();
    http_connector.enforce_http(false);
    http_connector.set_keepalive(Some(Duration::from_secs(90)));

    let mut root_cert_store = rustls::RootCertStore::empty();
    root_cert_store.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
    let mut valid_count = 0;
    let mut invalid_count = 0;
    if let Ok(a) = rustls_native_certs::load_native_certs() {
        for cert in a {
            // Continue on parsing errors, as native stores often include ancient or syntactically
            // invalid certificates, like root certificates without any X509 extensions.
            // Inspiration: https://github.com/rustls/rustls/blob/633bf4ba9d9521a95f68766d04c22e2b01e68318/rustls/src/anchors.rs#L105-L112
            match root_cert_store.add(cert) {
                Ok(_) => valid_count += 1,
                Err(err) => {
                    invalid_count += 1;
                    log::debug!("rustls failed to parse DER certificate: {err:?}");
                }
            }
        }
    }
    log::debug!("rustls_native_certs found {valid_count} valid and {invalid_count} invalid certificates for reverse proxy");

    let client_tls_config = rustls::ClientConfig::builder()
        .with_root_certificates(root_cert_store)
        .with_no_client_auth();
    let https_connector = HttpsConnectorBuilder::new()
        .with_tls_config(client_tls_config)
        .https_or_http()
        .enable_all_versions()
        .wrap_connector(http_connector);
    // 创建一个 HttpsConnector，使用 rustls 作为后端
    let client: Client<hyper_rustls::HttpsConnector<HttpConnector>, Incoming> =
        Client::builder(TokioExecutor::new())
            .pool_idle_timeout(Duration::from_secs(90))
            .pool_max_idle_per_host(5)
            .pool_timer(hyper_util::rt::TokioTimer::new())
            .build(https_connector);
    client
}
```


## 总结

很久没有这样深入地开源库的代码，这次跟的是Rust中比较重要的基础库的代码，也要一定Rust的功力才能看得懂这些代码


