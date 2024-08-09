---
title: "Rust在poll方法中使用锁"
date: 2024-08-09T13:10:52+08:00
draft: false
categories: [ "undefined"]
tags: ["rust"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

看到一个在`poll`方法中使用锁的问题，觉得很有意思，记录一下。
<!--more-->

## 问题

原始问题在[futures-rs/issues/1972](https://github.com/rust-lang/futures-rs/issues/1972)。下面是有问题的代码

I just had a bug in some code that looks like this:

```rust
use futures::lock::Mutex;

struct MySender {
    inner: Arc<Mutex<Inner>>,
}

struct MyReceiver {
    inner: Arc<Mutex<Inner>>,
}

impl Future for MyReceiver {
    fn poll(self: Pin<&mut Self>, cx: &mut Context) -Poll<(){
        if let Poll::Ready(inner) = Pin::new(&mut self.get_mut().inner.lock()).poll(cx) {
            // do some stuff
            return Poll::Ready(());
        }
        Poll::Pending
    }
}
```

The bug is that the `MutexLockFuture` returned by `Mutex::lock` deregisters itself when it gets dropped. So if I poll `MyReceiver` and the lock is held the task won't get woken up again when the lock is released. AFAICT my options for fixing this are:

0. Store the `MutexLockFuture` inside `MyReceiver`. This is inconvenient and inefficient since `MutexLockFuture` borrows the `Mutex` and so I'd need to use `rental` and an extra layer of boxing.
1. Implement `MyReceiver` with an `async` block/function instead of implementing `Future` directly. Again this means an extra layer of boxing. Also I'm trying to implement a low-level primitive here and I'd rather just implement `Future` directly.
2. Use a `std` non-async `Mutex`. This is obviously less than ideal, though I know in my case the lock won't get held for very long.

At the moment I've gone for option (2) since it's the laziest option, but it would be nice if there was a simple way to do this properly.

Could we add a `poll_lock` method to `Mutex` which allows me to use the `Mutex` in the buggy way I attempted above?

相同的问题：[Async mutexes and poll_fn - Other lock future never wakes up](https://users.rust-lang.org/t/async-mutexes-and-poll-fn-other-lock-future-never-wakes-up/38673)，问题原因：Basically the issue is that you're recreating the future that waits for the lock to become available on every poll, and if it doesn't succeed, you throw it away. Since you threw the future away, you should not expect to be woken up by that future.

## 解决

[futures-rs/pull/2571](https://github.com/rust-lang/futures-rs/pull/2571)

Add 2 new methods `Mutex::lock_owned` and `Mutex::try_lock_owned`

People who like #1972 want a new method such as `poll_lock`, to help them implement `Future` easier and less overhead. But adding `poll_lock` new method is so hard for the currently `Mutex` implementation.

However, if #1972 can store the future which returned by `Mutex::lock`, it can `poll` the future when poll its `MyReceiver`. Currently, the `Mutex` only has `lock` and `try_lock` method, which use the `&self` and the `lock` return a future but it has a reference to the `Mutex`. If save the mutex and its `MutexLockFuture` in a struct, will meet the **self-reference** problem.

To solve the **self-reference** problem, add a new way to lock the mutex: `Mutex::lock_owned(self: &Arc<Self>) -OwnedMutexLockFuture<T>`, the `OwnedMutexLockFuture` doesn't reference any variable, it contains the mutex which wrapped by the `Arc`, so the _self-reference_ problem disappears.

with this PR, #1972 can rewrite like

```rust
use futures::lock::Mutex;

struct MySender {
    inner: Arc<Mutex<Inner>>,
}

struct MyReceiver {
    inner: Arc<Mutex<Inner>>,
    fut: Option<OwnedMutexLockFuture<Inner>>,
    guard: Option<OwnedMutexGuard<Inner>>,
}

impl Future for MyReceiver {
    type Output = ();

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -Poll<(){
        let this = self.get_mut();

        loop {
            if let Some(_guard) = this.guard.as_mut() {
                todo!()
            } else { 
                match this.fut.as_mut() {
                    None ={
                        this.fut.replace(this.inner.lock_owned());
                    }
                    Some(fut) ={
                        let guard = futures_core::ready!(Pin::new(fut).poll(cx));

                        this.guard.replace(guard);
                    }
                }
            }
        }
    }
}
```


