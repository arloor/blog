---
title: "Rust reqwest代码阅读"
date: 2024-07-20T11:26:42+08:00
draft: false
categories: ["undefined"]
tags: ["rust"]
weight: 10
subtitle: ""
description: ""
keywords:
  - 刘港欢 arloor moontell
---

最近在自己的[rust_http_proxy](https://github.com/arloor/rust_http_proxy)中实现了简单的反向代理，第一版用的是手搓的无连接池版本，大致流程如下：

1. 首先 `TcpStream::connect` 建立连接
2. 通过 `conn::http1::Builder` 拿到 `sender`
3. 发送请求 `sender.send_request(new_req)`

工作的很正常，但是没有连接池。想到 `hyper` 官方提供的 `reqwest` 是有内置连接池的，于是研究了下做了改造，记录下过程中读到的代码。

## Original：无连接池的 reverse_proxy

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

## 源码阅读：从 reqwest 到 hyper-util 再到 hyper

### reqwest 对 legacy::client 的使用

具体 package 是:

```rust
use hyper_util::client::legacy::client
```

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

值得说明的是 `legacy client` 并不是“过时”的意思，而是 `hyper` 库从 `0.14` 升级到 `1.0` 时，将其从 `hyper` 移动到了 `hyper-util`。可以理解为从 hyper 体系的核心库移动到了外围实用组件。见下面引用自[Upgrade from v0.14 to v1](https://hyper.rs/guides/1/upgrading/)的描述

> The higher-level pooling Client was removed from `hyper 1.0`. A similar type was added to `hyper-util`, called `client::legacy::Client`. It’s mostly a drop-in replacement.

### legacy client 中池化的实现

`legacy client` 的核心实现都在 `impl<C, B> Client<C, B>` 中，核心方法有：

```Rust
// 发送请求
pub fn request(&self, req: Request<B>) -> ResponseFuture
// 从pool中找一条connection，发起请求
async fn try_send_request(&self, mut req: Request<B>, pool_key: PoolKey) -> Result<Response<hyper::body::Incoming>, TrySendError<B>>
// 从pool中找一条connection
async fn connection_for(&self, pool_key: PoolKey) -> Result<pool::Pooled<PoolClient<B>, PoolKey>, Error>
```

大致流程时将 scheme、host、port 作为 pool_key 找到一个连接（PoolClient），然后使用 PoolClient 的 `try_send_request` 方法。 `try_send_request` 定义如下：

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

当我们走进 `http1` 的 `tx.try_send_request(req)`，发现这个 `PoolClient.tx` 就是之前无连接池版本中的 `sender`，就是下面这个 `handshake` 的返回的 tuple 的左值（右值是 Connection，会被 `tokio::spawn` 驱动执行）

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

我们可以额外关注下的 http1 部分，可以更清晰的看到和无连接连接池版本的相通之处

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

### hyper 如何发送 http1 请求

接下来从 hyper-util 走到 hyper，看看 hyper 这个底层库是如何发送 http 请求的。目标是确定我们将 http2 请求的 body 转换成 http1.1 的 body 是否有损，具体来说是，将 http2 分帧的 body 的转换成 http1.1 的`Transfer-Encoding: chunked`的 body 是否有损。答案是无损的。

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

这个 `inner.send` 是发送到了一个 channel 中，那这个 channel 的接收者在哪呢？答案是我们之前看到的被 `tokio::spawn` 的`Connection`中。这里有必要给出`Connection`的定义：

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

Connection 被 `tokio::spawn` 说明他是个 `Future`，他的逻辑就在 `poll` 方法中，我们看下这个 `poll` 方法：

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

这里就是推动 `inner: Dispatcher`的执行，我们继续看 `Dispatcher` 的 poll（trait bounds 有点多，经典类型体操）：

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

而后逐步走到 `poll_inner`、`poll_loop`，有经验而敏感的同学看到`poll_loop`就知道 Reacotr 模式的事件循环（eventloop）他来了。这个`poll_loop`值得贴一下源码，因为涉及到其他 future 的饥饿问题，可能自己在做设计的时候也要考虑

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

接着走进 `poll_write`的逻辑，就能看到具体的 http 请求的发送逻辑了。贴一小段代码，解密下消息从哪来

```Rust
fn poll_write(&mut self, cx: &mut Context<'_>) -> Poll<crate::Result<()>> {
    loop {
        if self.is_closing {
            return Poll::Ready(Ok(()));
        } else if self.body_rx.is_none()
            && self.conn.can_write_head()
            && self.dispatch.should_poll()
        {
            if let Some(msg) = ready!(Pin::new(&mut self.dispatch).poll_msg(cx)) { // ！！！ 从channel中接收消息
                let (head, body) = msg.map_err(crate::Error::new_user_service)?;

                let body_type = if body.is_end_stream() {
                    self.body_rx.set(None);
                    None // 长度为空
                } else {
                    let btype = body
                        .size_hint()
                        .exact()
                        .map(BodyLength::Known)
                        .or(Some(BodyLength::Unknown)); // 从body中知道是固定长度的还是chunked的
                    self.body_rx.set(Some(body));
                    btype
                };
                self.conn.write_head(head, body_type); // 写header部分，也是我们关注的chunked部分
            } else if !self.conn.can_buffer_body() {
                ...
            } else {
                // 接收body
                ...
            }
        }
    }
}
```

核心在于 `self.dispatch` 的 `poll_msg` 方法，这个方法是 `Dispatcher` 的方法，我们看下这个方法的定义：

```Rust
impl<B> Dispatch for Client<B>
where
    B: Body,
{
    type PollItem = RequestHead;
    type PollBody = B;
    type PollError = Infallible;
    type RecvItem = crate::proto::ResponseHead;

    fn poll_msg(
        mut self: Pin<&mut Self>,
        cx: &mut Context<'_>,
    ) -> Poll<Option<Result<(Self::PollItem, Self::PollBody), Infallible>>> {
        let mut this = self.as_mut();
        debug_assert!(!this.rx_closed);
        match this.rx.poll_recv(cx) {   // ！！！ 从channel中接收消息，看下面的impl<T, U> Receiver<T, U>
            Poll::Ready(Some((req, mut cb))) => {
                ...
            }
            Poll::Ready(None) => {
                ...
            }
            Poll::Pending => Poll::Pending,
        }
    }
    ...
}



pub(crate) struct Receiver<T, U> {
    inner: mpsc::UnboundedReceiver<Envelope<T, U>>,
    taker: want::Taker,
}

impl<T, U> Receiver<T, U> {
    pub(crate) fn poll_recv(&mut self, cx: &mut Context<'_>) -> Poll<Option<(T, Callback<T, U>)>> {
        match self.inner.poll_recv(cx) {
            Poll::Ready(item) => {
                Poll::Ready(item.map(|mut env| env.0.take().expect("envelope not dropped")))
            }
            Poll::Pending => {
                self.taker.want(); // 如果没拿到，则通知生产者，详见下面的want crate解释
                Poll::Pending
            }
        }
    }

    #[cfg(feature = "http1")]
    pub(crate) fn close(&mut self) {
        self.taker.cancel();
        self.inner.close();
    }

    #[cfg(feature = "http1")]
    pub(crate) fn try_recv(&mut self) -> Option<(T, Callback<T, U>)> {
        use futures_util::FutureExt;
        match self.inner.recv().now_or_never() {
            Some(Some(mut env)) => env.0.take(),
            _ => None,
        }
    }
}

// 在connection drop时，通知SendRequest is_closed
impl<T, U> Drop for Receiver<T, U> {
    fn drop(&mut self) {
        // Notify the giver about the closure first, before dropping
        // the mpsc::Receiver.
        self.taker.cancel();
    }
}
```

核心是 `this.rx.poll_recv(cx)`，这个 rx 就是 `handshake` 过程中创建的 `dispatch::channel()` 的接受部分，底层是 `mpsc::UnboundedReceiver`。其实看到这里，应该就明白 hyper 怎么实现 client 的了：

1. handshake 生成`sender: http1::SendRequest` 和 `Connection`。
2. 他们是**生产者消费者模型**，sender 有 mpsc 的发送端，connection 有 mpsc 的接收端。**我们自己实现 Rust 的生产者消费者模型时，可以重点参考`dispatch::channel()`**
3. connection 被 tokio::spawn，poll 方法中不断从 mpsc 接收端接收消息，然后发送 http 请求。

深究下 `dispatch::channel()` 的实现：

```Rust
pub(crate) fn channel<T, U>() -> (Sender<T, U>, Receiver<T, U>) {
    let (tx, rx) = mpsc::unbounded_channel();
    let (giver, taker) = want::new();
    let tx = Sender {
        #[cfg(feature = "http1")]
        buffered_once: false,
        giver,
        inner: tx,
    };
    let rx = Receiver { inner: rx, taker };
    (tx, rx)
}
```

用到了[hyper 作者的 want crate](https://docs.rs/want/0.3.1/want/)。文档中写的很清楚，简单总结下，大致作用是给 channel 的生产者和消费者增加 http1 协议的 ping-pong 反馈机制，上一个 request 处理完毕，再允许发送者发送下一个 request（ping pong ping pong）(http2 的 stream 比这个复杂)。所以这个库的典型使用场景就是和 `unbounded_channel` 一起使用。

真正写 header 的部分，这里只截图我关注的 HTTP2 转 HTTP1.1 时是否能自动增加 `Transfer-Encoding: chunked`，简要总结下，如果没有设置 `Content-Length`，则会自动增加 `Transfer-Encoding: chunked`。截图左侧的调用栈也可以关注下。

![alt text](/img/hyper_http1_poll_write_debug.png)

## Result1: 使用 legacy::client 构建 reverse_proxy

增加的依赖：

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

hyper-rustls 中的 ring 或者 aws-lc-rs 是受自己 crate 的可选 feature 控制的，这里没有展示出来。下面是构建`legacy client`的代码，支持 HTTPS：

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

## Result2: 使用 LRU cache 实现自己的连接池

最后，我又借鉴了 `shadowsocks-rust` 的 [http_client.rs](https://github.com/shadowsocks/shadowsocks-rust/blob/dc5ea4b39de4e5223c48877d18d85b931c799302/crates/shadowsocks-service/src/local/http/http_client.rs#L112)，使用 `lru_time_cache` 实现了自己的连接池。

```Rust
//! HTTP Client

use std::{
    collections::VecDeque,
    error::Error,
    fmt::Debug,
    io::{self, ErrorKind},
    sync::Arc,
    time::{Duration, Instant},
};

use http::{header, HeaderMap, HeaderValue, Version};
use hyper::{
    body::{self, Body},
    client::conn::http1,
    http::uri::Scheme,
    Request, Response,
};
use hyper_util::rt::TokioIo;
use io_x::{CounterIO, TimeoutIO};
use log::{debug, error, info, trace, warn};
use lru_time_cache::LruCache;
use prom_label::LabelImpl;
use tokio::{net::TcpStream, sync::Mutex};

use crate::proxy::AccessLabel;

const CONNECTION_EXPIRE_DURATION: Duration =
    Duration::from_secs(if !cfg!(debug_assertions) { 30 } else { 10 });

/// HTTPClient, supporting HTTP/1.1 and H2, HTTPS.
pub struct HttpClient<B> {
    #[allow(clippy::type_complexity)]
    cache_conn: Arc<Mutex<LruCache<AccessLabel, VecDeque<(HttpConnection<B>, Instant)>>>>,
}

impl<B> HttpClient<B>
where
    B: Body + Send + Unpin + Debug + 'static,
    B::Data: Send,
    B::Error: Into<Box<dyn ::std::error::Error + Send + Sync>>,
{
    /// Create a new HttpClient
    pub fn new() -> HttpClient<B> {
        HttpClient {
            cache_conn: Arc::new(Mutex::new(LruCache::with_expiry_duration(
                CONNECTION_EXPIRE_DURATION,
            ))),
        }
    }

    /// Make HTTP requests
    #[inline]
    pub async fn send_request(
        &self,
        req: Request<B>,
        access_label: &AccessLabel,
        stream_map_func: impl FnOnce(
            TcpStream,
            AccessLabel,
        ) -> CounterIO<TcpStream, LabelImpl<AccessLabel>>,
    ) -> Result<Response<body::Incoming>, std::io::Error> {
        // 1. Check if there is an available client
        if let Some(c) = self.get_cached_connection(access_label).await {
            debug!("HTTP client for host: {} taken from cache", &access_label);
            match self.send_request_conn(access_label, c, req).await {
                Ok(o) => return Ok(o),
                Err(err) => return Err(io::Error::new(io::ErrorKind::InvalidData, err)),
            }
        }

        // 2. If no. Make a new connection
        let scheme = match req.uri().scheme() {
            Some(s) => s,
            None => &Scheme::HTTP,
        };

        let c = match HttpConnection::connect(scheme, access_label, stream_map_func).await {
            Ok(c) => c,
            Err(err) => {
                error!(
                    "failed to connect to host: {}, error: {}",
                    &access_label.target, err
                );
                return Err(io::Error::new(io::ErrorKind::InvalidData, err));
            }
        };

        self.send_request_conn(access_label, c, req)
            .await
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))
    }

    async fn get_cached_connection(&self, access_label: &AccessLabel) -> Option<HttpConnection<B>> {
        if let Some(q) = self.cache_conn.lock().await.get_mut(access_label) {
            debug!(
                "HTTP client for host: {} found in cache, len: {}",
                access_label,
                q.len()
            );
            while let Some((c, inst)) = q.pop_front() {
                let now = Instant::now();
                if now - inst >= CONNECTION_EXPIRE_DURATION {
                    debug!("HTTP connection for host: {} expired", access_label,);
                    continue;
                }
                if c.is_closed() {
                    // true at once after connection.await return
                    debug!("HTTP connection for host: {} is closed", access_label,);
                    continue;
                }
                if !c.is_ready() {
                    debug!("HTTP connection for host: {access_label} is not ready",);
                    continue;
                }
                return Some(c);
            }
        } else {
            debug!("HTTP client for host: {} not found in cache", access_label);
        }
        None
    }

    async fn send_request_conn(
        &self,
        access_label: &AccessLabel,
        mut c: HttpConnection<B>,
        req: Request<B>,
    ) -> hyper::Result<Response<body::Incoming>> {
        trace!(
            "HTTP making request to host: {}, request: {:?}",
            access_label,
            req
        );
        let response = c.send_request(req).await?;
        trace!(
            "HTTP received response from host: {}, response: {:?}",
            access_label,
            response
        );

        // Check keep-alive
        if check_keep_alive(response.version(), response.headers(), false) {
            trace!(
                "HTTP connection keep-alive for host: {}, response: {:?}",
                access_label,
                response
            );
            self.cache_conn
                .lock()
                .await
                .entry(access_label.clone())
                .or_insert_with(VecDeque::new)
                .push_back((c, Instant::now()));
        }

        Ok(response)
    }
}

pub fn check_keep_alive(
    version: Version,
    headers: &HeaderMap<HeaderValue>,
    check_proxy: bool,
) -> bool {
    // HTTP/1.1, HTTP/2, HTTP/3 keeps alive by default
    let mut conn_keep_alive = !matches!(version, Version::HTTP_09 | Version::HTTP_10);

    if check_proxy {
        // Modern browsers will send Proxy-Connection instead of Connection
        // for HTTP/1.0 proxies which blindly forward Connection to remote
        //
        // https://tools.ietf.org/html/rfc7230#appendix-A.1.2
        if let Some(b) = get_keep_alive_val(headers.get_all("Proxy-Connection")) {
            conn_keep_alive = b
        }
    }

    // Connection will replace Proxy-Connection
    //
    // But why client sent both Connection and Proxy-Connection? That's not standard!
    if let Some(b) = get_keep_alive_val(headers.get_all("Connection")) {
        conn_keep_alive = b
    }

    conn_keep_alive
}

fn get_keep_alive_val(values: header::GetAll<HeaderValue>) -> Option<bool> {
    let mut conn_keep_alive = None;
    for value in values {
        if let Ok(value) = value.to_str() {
            if value.eq_ignore_ascii_case("close") {
                conn_keep_alive = Some(false);
            } else {
                for part in value.split(',') {
                    let part = part.trim();
                    if part.eq_ignore_ascii_case("keep-alive") {
                        conn_keep_alive = Some(true);
                        break;
                    }
                }
            }
        }
    }
    conn_keep_alive
}

#[allow(dead_code)]
enum HttpConnection<B> {
    Http1(http1::SendRequest<B>),
}

impl<B> HttpConnection<B>
where
    B: Body + Send + Unpin + 'static,
    B::Data: Send,
    B::Error: Into<Box<dyn ::std::error::Error + Send + Sync>>,
{
    async fn connect(
        scheme: &Scheme,
        access_label: &AccessLabel,
        stream_map_func: impl FnOnce(
            TcpStream,
            AccessLabel,
        ) -> CounterIO<TcpStream, LabelImpl<AccessLabel>>,
    ) -> io::Result<HttpConnection<B>> {
        if *scheme != Scheme::HTTP && *scheme != Scheme::HTTPS {
            return Err(io::Error::new(ErrorKind::InvalidInput, "invalid scheme"));
        }

        let stream = TcpStream::connect(&access_label.target).await?;
        let stream: CounterIO<TcpStream, LabelImpl<AccessLabel>> =
            stream_map_func(stream, access_label.clone());

        HttpConnection::connect_http_http1(scheme, access_label, stream).await
    }

    async fn connect_http_http1(
        scheme: &Scheme,
        access_label: &AccessLabel,
        stream: CounterIO<TcpStream, LabelImpl<AccessLabel>>,
    ) -> io::Result<HttpConnection<B>> {
        trace!(
            "HTTP making new HTTP/1.1 connection to host: {}, scheme: {}",
            access_label,
            scheme
        );
        let stream = TimeoutIO::new(stream, CONNECTION_EXPIRE_DURATION);

        // HTTP/1.x
        let (send_request, connection) = match http1::Builder::new()
            .preserve_header_case(true)
            .title_case_headers(true)
            .handshake(Box::pin(TokioIo::new(stream)))
            .await
        {
            Ok(s) => s,
            Err(err) => return Err(io::Error::new(ErrorKind::Other, err)),
        };

        let access_label = access_label.clone();
        tokio::spawn(async move {
            if let Err(err) = connection.await {
                handle_http1_connection_error(err, access_label);
            }
        });
        Ok(HttpConnection::Http1(send_request))
    }

    #[inline]
    pub async fn send_request(
        &mut self,
        req: Request<B>,
    ) -> hyper::Result<Response<body::Incoming>> {
        match self {
            HttpConnection::Http1(r) => r.send_request(req).await,
        }
    }

    pub fn is_closed(&self) -> bool {
        match self {
            HttpConnection::Http1(r) => r.is_closed(),
        }
    }
    pub fn is_ready(&self) -> bool {
        match self {
            HttpConnection::Http1(r) => r.is_ready(),
        }
    }
}

fn handle_http1_connection_error(err: hyper::Error, access_label: AccessLabel) {
    if let Some(source) = err.source() {
        if let Some(io_err) = source.downcast_ref::<io::Error>() {
            if io_err.kind() == ErrorKind::TimedOut {
                // 由于超时导致的连接关闭（TimeoutIO）
                info!(
                    "[legacy proxy connection io closed]: [{}] {} to {}",
                    io_err.kind(),
                    io_err,
                    access_label
                );
            } else {
                warn!(
                    "[legacy proxy io error]: [{}] {} to {}",
                    io_err.kind(),
                    io_err,
                    access_label
                );
            }
        } else {
            warn!("[legacy proxy io error]: [{}] to {}", source, access_label);
        }
    } else {
        warn!("[legacy proxy io error] [{}] to {}", err, access_label);
    }
}

```
