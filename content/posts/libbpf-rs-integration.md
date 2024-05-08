---
title: "在Rust项目中集成libbpf-rs"
date: 2024-04-20T11:47:53+08:00
draft: false
categories: [ "undefined"]
tags: ["ebpf"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

前面已经有两篇博客记录了ebpf的一些知识，这篇则是实操。作为一个对C语言和Rust有一定了解的选手，我选择使用 `libbpf-rs` 开发ebpf应用，这就记录下我在Rust项目中集成 `libbpf-rs` 的过程。

<!--more-->

## 项目地址

[bpf_rs_hub](https://github.com/arloor/bpf_rs_hub)

## 安装依赖

1. Clang编译器。至少需要Clang10，CO-RE需要Clang11或Clang12
2. libbpf库
3. bpftool可执行性文件，用来生成vmlinux.h和xx_skel.h
4. zlib (libz-dev or zlib-devel ) 和 libelf (libelf-dev or elfutils-libelf-devel )
5. pkg-config: libbpf-rs使用pkg-config来查找libbpf库

**ubuntu 22.04 安装：**

```bash
apt-get install -y libbpf-dev libz-dev libelf-dev pkg-config clang bpftool
```

**centos stream 9 安装：**

```bash
yum install -y libbpf zlib-devel elfutils-libelf-devel pkgconf-pkg-config clang bpftool 
```

## 生成vmlinux.h

```bash
bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h
```

一些简单的ebpf程序可以不依赖vmlinux.h。

> 也可以不依赖手动生成的vmlinux.h，而是直接将 libbpf-rs 下的 [vmlinux模块](https://github.com/libbpf/libbpf-rs/tree/master/vmlinux) 作为build dependency，这样可以避免手动生成vmlinux.h的麻烦。后面的详细实操就没有生成vmlinux.h

## rust lib项目搭建

### 总体文件结构

```bash
.
├── Cargo.lock
├── Cargo.toml
├── build.rs
├── examples
│   └── example1.rs
└── src
    ├── bpf
    │   ├── program.bpf.c
    │   └── program.skel.rs
    └── lib.rs

4 directories, 7 files
```

### 编写 xxx.bpf.c，生成 xxx.skel.rs

以最简单的 `socket filter` 统计网卡上行流量为例:

**program.bpf.c：**

```c
#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_core_read.h>
#include <bpf/bpf_tracing.h>

// copy from #include <linux/if_ether.h>
#define ETH_HLEN	14		/* Total octets in header.	 */
// copy from  <linux/if_packet.h>
#define PACKET_OUTGOING		4		/* Outgoing of any type */

#define IP_PROTO_OFF offsetof(struct iphdr, protocol)
#define IP_DEST_OFF offsetof(struct iphdr, daddr)

struct {
	__uint(type, BPF_MAP_TYPE_ARRAY);
	__uint(max_entries, 1);
	__type(key, u32);
	__type(value, u64);
} map SEC(".maps");

/*
 * Track size of outgoing ICMP and UDP packets
 */
SEC("socket")
int bpf_program(struct __sk_buff *skb) {
    // Only outgoing packets
    if (skb->pkt_type != PACKET_OUTGOING) return 0;

    __u32 proto = IPPROTO_IP;
    long *value = bpf_map_lookup_elem(&map, &proto);
    if (value) {
        __sync_fetch_and_add(value, skb->len);
    }

    return 0;
}

char _license[] SEC("license") = "GPL";
```

**Cargo.toml：**

```toml
[package]
name = "bpf_socket_filter"
version = "0.1.0"
authors = ["arloor <admin@arloor.com>"]
edition = "2021"

[lib]
path = "src/lib.rs" # 库文件的路径

[[example]]
name = "example1"
path = "examples/example1.rs"

[dependencies]
libc = "0.2.98"           # Raw FFI bindings to platform libraries like libc
libbpf-rs = "0.23.0"      # libbpf-rs is a safe, idiomatic, and opinionated wrapper around libbpf-sys
plain = "0.2.3"           # A small Rust library that allows users to reinterpret data of certain types safely
pnet="0.34"             # Rust library for low level networking using the pcap library
log="0.4"               # A lightweight logging facade for Rust

[build-dependencies]
libbpf-cargo = "0.23.0"   # Cargo plugin to build bpf programs
vmlinux = { git = "https://github.com/libbpf/libbpf-rs.git", branch = "master" } #使用远程的vmlinux.h 配合build.rs使用
```

**build.rs**

```rust
use std::env;
use std::path::PathBuf;

use libbpf_cargo::SkeletonBuilder;

const SRC: &str = "src/bpf/program.bpf.c";

fn main() {
    let out = PathBuf::from(
        env::var_os("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR must be set in build script"),
    )
    .join("src")
    .join("bpf")
    .join("program.skel.rs");
    let mut builder = SkeletonBuilder::new();
    let builder = builder.source(SRC);
    // 不依赖本地的vmlinux.h，而是使用libbpf-bootstrap项目提供的vmlinux.h，详见build-dependencies
    // builder.clang_args(["-I."]);
    {
        use std::ffi::OsStr;
        let arch = env::var("CARGO_CFG_TARGET_ARCH")
        .expect("CARGO_CFG_TARGET_ARCH must be set in build script");
        builder.clang_args([
            OsStr::new("-I"),
            vmlinux::include_path_root().join(arch).as_os_str(),
        ]);
    }
    builder.build_and_generate(&out).unwrap();
    println!("cargo:rerun-if-changed={SRC}");
}
```

运行cargo build时，libbpf-cargo插件将会根据build.rs生成的program.skel.rs文件，包含了所有的bpf map和bpf program。

### 编写lib.rs,以作为其他项目的依赖

```rust
#![deny(warnings)]
use libc::{
    bind, close, if_nametoindex, sockaddr_ll, socket, AF_PACKET, PF_PACKET, SOCK_CLOEXEC,
    SOCK_NONBLOCK, SOCK_RAW,
};
use std::os::fd::AsRawFd;
use std::os::unix::io::RawFd;
use std::{ffi::CString, os::fd::AsFd};

#[path = "bpf/program.skel.rs"]
mod prog;
use prog::*;
use libbpf_rs::skel::{OpenSkel, SkelBuilder};
use libbpf_rs::MapFlags;
use pnet::datalink;
use std::mem::size_of_val;
use log::{info, warn};

pub struct SocketFilter {
    skel: ProgramSkel<'static>,
}

impl SocketFilter {
    pub fn get_value(&self) -> u64 {
        get_value(&self.skel)
    }
}

impl Default for SocketFilter {
    fn default() -> Self {
        bump_memlock_rlimit().expect("Failed to increase rlimit");
        let skel = open_and_load_socket_filter_prog();
        let all_interfaces = datalink::interfaces();
        // 遍历接口列表
        for iface in all_interfaces {
            if iface.name.starts_with("lo")||iface.name.starts_with("podman")||iface.name.starts_with("veth")||iface.name.starts_with("flannel")||iface.name.starts_with("cni0")||iface.name.starts_with("utun") {
                continue;
            }
            info!("load bpf socket filter for Interface: {}", iface.name);
            set_socket_opt_bpf(&skel, iface.name.as_str());
        }
        SocketFilter { skel }
    }
}

pub fn open_and_load_socket_filter_prog() -> ProgramSkel<'static> {
    let builder = ProgramSkelBuilder::default();

    let open_skel = builder.open().expect("Failed to open BPF program");
    open_skel.load().expect("Failed to load BPF program")
}
type DynError = Box<dyn std::error::Error>;
fn bump_memlock_rlimit() -> Result<(),DynError> {
    let rlimit = libc::rlimit {
        rlim_cur: 128 << 20,
        rlim_max: 128 << 20,
    };

    if unsafe { libc::setrlimit(libc::RLIMIT_MEMLOCK, &rlimit) } != 0 {
        warn!("Failed to increase rlimit");
    }

    Ok(())
}

pub fn set_socket_opt_bpf(skel: &ProgramSkel<'static>, name: &str) {
    unsafe {
        let sock = open_raw_sock(name).expect("Failed to open raw socket");

        let prog_fd = skel.progs().bpf_program().as_fd().as_raw_fd();
        let value = &prog_fd as *const i32;
        let option_len = size_of_val(&prog_fd) as libc::socklen_t;

        let sockopt = libc::setsockopt(
            sock,
            libc::SOL_SOCKET,
            libc::SO_ATTACH_BPF,
            value as *const libc::c_void,
            option_len,
        );
        assert_eq!(sockopt, 0, "Failed to set socket option");
    };
}

pub fn get_value(skel: &ProgramSkel<'static>) -> u64 {
    let maps = skel.maps();
    let map = maps.map();

    let key = unsafe { plain::as_bytes(&(libc::IPPROTO_IP as u32)) };
    let mut value: u64 = 0;
    if let Ok(Some(buf)) = map.lookup(key, MapFlags::ANY) {
        plain::copy_from_bytes(&mut value, &buf).expect("Invalid buffer");
    }
    value
}

pub fn open_raw_sock(name: &str) -> Result<RawFd, String> {
    unsafe {
        let protocol = (libc::ETH_P_ALL as libc::c_short).to_be() as libc::c_int;
        let sock = socket(PF_PACKET, SOCK_RAW | SOCK_NONBLOCK | SOCK_CLOEXEC, protocol);
        if sock < 0 {
            return Err("Failed to create raw socket".to_string());
        }

        let name_cstring = CString::new(name).unwrap();
        let sll = sockaddr_ll {
            sll_family: AF_PACKET as u16,
            sll_protocol: protocol as u16,
            sll_ifindex: if_nametoindex(name_cstring.as_ptr()) as i32,
            sll_hatype: 0,
            sll_pkttype: 0,
            sll_halen: 0,
            sll_addr: [0; 8],
        };

        if bind(
            sock,
            &sll as *const _ as *const _,
            std::mem::size_of::<sockaddr_ll>() as u32,
        ) < 0
        {
            let err = CString::new("Failed to bind to interface: ".to_string() + name).unwrap();
            close(sock);
            return Err(err.to_str().unwrap().to_string()
                + ": "
                + &std::io::Error::last_os_error().to_string());
        }

        Ok(sock)
    }
}
```

### 编写example1.rs

```rust
use std::{thread::sleep, time::Duration};

use bpf_socket_filter as socket_filter;

fn main() {
    let socket_filter = socket_filter::SocketFilter::default();
    loop{
        let value = socket_filter.get_value();
        println!("{}",value);
        sleep(Duration::from_secs(1));
    }
}
```

### 测试

```bash
cargo run --example example1
```

## 进阶

### docker运行

需要增加 `--privileged`, 参考[running-ebpf-programs-on-docker-containers](https://andreybleme.com/2022-05-22/running-ebpf-programs-on-docker-containers/)

### 静态链接

**1. 静态链接libbpf、zlib、libelf**

`libbpf-rs` 提供了 `vendored` 特性，自动在运行时编译libbpf、zlib、libelf的静态库，从而可以静态链接到生成的可执行文件中。在Cargo.toml中激活：

```toml
[dependencies.libbpf-rs]
version = "0.23.0"
features = ["vendored"]
default-features = false
```

`vendored` 特性编译时需要执行[libbpf-sys的build.rs](https://github.com/libbpf/libbpf-sys/blob/master/build.rs)，需要下面的这些包，请根据发行版自行安装

```bash
# centos # 使用 yum whatprovides xxx查询到具体的package
yum install -y autoconf gettext-devel flex bison gawk make pkg-config automake
# ubuntu # 使用 apt-file search xxx查询到具体的package
apt-get install -y autoconf autopoint flex bison gawk make pkg-config automake
```

**2. 生成静态链接的 gnu 二进制文件**

参考[Rust Linkage](https://doc.rust-lang.org/reference/linkage.html)和[VENDORIZE: add feature vendored](https://github.com/libbpf/libbpf-rs/pull/498)，执行以下命令即可：

```bash
RUSTFLAGS="-C target-feature=+crt-static" cargo build --release --target x86_64-unknown-linux-gnu
```

注意：

1. libbpf-rs静态链接仅支持gnu，**不支持musl**
2. `--target x86_64-unknown-linux-gnu` 不能省略
3. 可执行文件在 `/target/x86_64-unknown-linux-gnu/release/`

如果报错：

```bash
/usr/bin/ld: cannot find -lm
/usr/bin/ld: cannot find -lc
```

说明系统上缺少了一些静态库，安装即可。

以我的redhat9开发机为例，缺失的是 `glibc-static`

```bash
# search from https://pkgs.org/search/?q=libc.a
# centos 9
dnf --enablerepo=crb install glibc-static
# redhat9
subscription-manager repos --enable codeready-builder-for-rhel-9-x86_64-rpms # https://access.redhat.com/articles/4348511
yum install -y glibc-static # yum whatprovides "*/libc.a"
```

以ubuntu为例，缺失的是 `libc6-dev`

```bash
apt install -y libc6-dev

$ apt update && apt-get install -y apt-file && apt-file update && apt-file search libc.a | grep "libc6-dev:"
libc6-dev: /usr/lib/x86_64-linux-gnu/libc.a
$ apt-file search libm.a | grep "libc6-dev:"
libc6-dev: /usr/lib/x86_64-linux-gnu/libm.a
```