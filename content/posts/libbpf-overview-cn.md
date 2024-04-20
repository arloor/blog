---
title: "libbpf Overview中文翻译"
date: 2024-04-20T11:37:52+08:00
draft: false
categories: [ "undefined"]
tags: ["ebpf"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

> **本文是机器翻译加手动修改，[原文链接](https://docs.kernel.org/bpf/libbpf/libbpf_overview.html)，仅供自己学习理解，如有错漏，请勿批评**

libbpf 是一个基于 C 的库，包含一个 BPF 加载器，该加载器采用编译后的 BPF 目标文件并准备并将它们加载到 Linux 内核中。 libbpf 采取 加载、验证 BPF 程序并将其附加到各种 内核钩子，让BPF应用程序开发人员只关注BPF程序 正确性和性能。

以下是 libbpf 支持的高级功能：

- 提供高层和低层API供用户空间程序进行交互 与 BPF 程序。 低级 API 包装了所有 bpf 系统调用 功能，当用户需要更细粒度的控制时非常有用 用户空间和 BPF 程序之间的交互。
- 为bpftool生成的BPF对象骨架提供全面支持。 骨架文件简化了用户空间程序访问的过程 全局变量并与 BPF 程序一起使用。
- 提供BPF端APIS，包括BPF帮助器定义、BPF映射支持、 和跟踪助手，使开发人员能够简化 BPF 代码编写。
- 支持BPF CO-RE机制，使BPF开发者能够编写可移植的 BPF程序可以编译一次并跨不同内核运行 版本。

本文档将详细探讨上述概念，提供对 libbpf 的功能和优势以及它如何帮助 您高效开发 BPF 应用程序的更深入 了解。

## BPF App Lifecycle and libbpf APIs

一个 BPF 应用程序包括一个或多个 BPF 程序（要么是协作的，要么是 完全独立的），BPF 映射和全局变量。这些全局 变量在所有 BPF 程序之间共享，使它们能够在 一个共同的数据集上协作。libbpf 提供了 API，用户空间程序可以利用这些 API 来 通过触发 BPF 应用程序 生命周期的不同阶段来操作 BPF 程序。

下一节将简要概述 BPF 生命周期中的每个阶段：

- **Open phase**：在此阶段，libbpf 解析 BPF 对象文件并发现 BPF 映射、BPF 程序和全局变量。在 一个 BPF 应用程序被打开后，用户空间应用可以进行额外的调整 （如有必要，设置 BPF 程序类型；为 全局变量预设初始值等），在所有实体被创建和加载之前。
- **Load phase**：在加载阶段，libbpf 创建 BPF 映射，解析各种重定位，并验证并将 BPF 程序加载到 内核中。此时，libbpf 验证 BPF 应用程序的所有部分 并将 BPF 程序加载到内核中，但还没有 执行任何 BPF 程序。在加载阶段后，可以设置初始 BPF 映射 状态，而不会与 BPF 程序代码执行发生冲突。
- **Attachment phase**：在此阶段，libbpf 将 BPF 程序附加到各种 BPF 钩子点（例如，跟踪点、kprobes、 控制组钩子、网络数据包处理管道等）。在此 阶段，BPF 程序执行有用的工作，例如处理 数据包，或更新可以从用户 空间读取的 BPF 映射和全局变量。
- **Tear down phase**：在拆解阶段， libbpf 分离 BPF 程序并将其从内核中卸载。 BPF 映射是 销毁，并且 BPF 应用程序使用的所有资源都被释放。

## BPF Object Skeleton File

BPF 骨架是 libbpf API 的替代接口，用于与 BPF 一起使用 对象。 骨架代码抽象出通用的 libbpf API，以显着 简化从用户空间操作 BPF 程序的代码。 骨架代码 包括 BPF 目标文件的字节码表示，简化了 分发 BPF 代码的过程。 嵌入 BPF 字节码后，就没有 与应用程序二进制文件一起部署的额外文件。

You can generate the skeleton header file (.skel.h) for a specific object file by passing the BPF object to the bpftool. 生成的BPF骨架 提供了以下与BPF生命周期对应的自定义函数， 每个都以特定的对象名称为前缀：

- <name>__open() – creates and opens BPF application (<name> stands for the specific bpf object name)
- <name>__load() – instantiates, loads,and verifies BPF application parts
- <name>__attach() – attaches all auto-attachable BPF programs (it’s optional, you can have more control by using libbpf APIs directly)
- <name>__destroy() – detaches all BPF programs and frees up all used resources

使用骨架代码是使用 bpf 程序的推荐方法。请记住，BPF 骨架允许程序员访问底层的 BPF object，所以任何通用libbpf API能做的，BPF骨架也都能做。这是一个附加的方便的功能特性，不需要额外系统调用，不需要繁琐的代码。

## 使用骨架文件的其他优点

- BPF骨架提供了一个接口，来让用户空间程序可以使用BPF全局变量。骨架代码将全局变量映射为用户空间的一个结构体。这个结构体允许用户空间程序在BPF load phase之前初始化BPF程序，并在之后从用户空间获取和更新数据。
- `skel.h` 列出来所有的maps、programs等等来反映 object file的结构。BPF 骨架将BPF map和 BPF program作为结构体字段，从而让用户态程序直接使用。 这消除了需要 基于字符串的查找 `bpf_object_find_map_by_name()` 和 `bpf_object_find_program_by_name()` 的使用，减少因 `BPF source code` 和 `user-space code` 不同步导致的错误。
- The embedded bytecode representation of the object file ensures that the skeleton and the BPF object file are always in sync.

## BPF Helpers

libbpf提供了 BPF-side 的api，BPF程序可以使用这些api与系统进行交互。BPF helpers允许开发人员在BPF代码中使用它们，就像使用任何普通的C函数一样。例如，有BPF helpers用于打印调试消息，获取自系统启动以来的时间，与BPF map交互，操作网络数据包等。

关于BPF helper的完整描述，例如他们的作用，他们接受的参数，以及返回值，请参阅[bpf-helpers man page](https://man7.org/linux/man-pages/man7/bpf-helpers.7.html)。

## BPF CO-RE(一次编译，处处运行)

BPF programs work in the kernel space and have access to kernel memory and data structures. One limitation that BPF applications come across is the lack of portability across different kernel versions and configurations. BCC is one of the solutions for BPF portability. However, it comes with runtime overhead and a large binary size from embedding the compiler with the application.

BPF programs在内核空间工作，并且可以访问内核内存和数据结构。BPF应用程序的一个限制是在不同的内核版本和配置之间缺乏可移植性。BCC是BPF可移植性的解决方案之一。但是，它带来了运行时开销和大的二进制大小，因为它将编译器与应用程序嵌入在一起。

libbpf steps up the BPF program portability by supporting the BPF CO-RE concept. BPF CO-RE brings together BTF type information, libbpf, and the compiler to produce a single executable binary that you can run on multiple kernel versions and configurations.

libbpf通过支持BPF CO-RE概念来提高BPF程序的可移植性。BPF CO-RE将BTF类型信息、libbpf和编译器结合在一起，生成一个单独的可执行二进制文件，您可以在多个内核版本和配置上运行。

To make BPF programs portable libbpf relies on the BTF type information of the running kernel. Kernel also exposes this self-describing authoritative BTF information through sysfs at /sys/kernel/btf/vmlinux.

为了使BPF程序可移植，libbpf依赖于运行内核的BTF类型信息。内核还通过sysfs在/sys/kernel/btf/vmlinux暴露了这种自描述的权威BTF信息。

You can generate the BTF information for the running kernel with the following command:

你可以使用以下命令为运行的内核生成BTF信息：

```bash
bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h
```

The command generates a vmlinux.h header file with all kernel types (BTF types) that the running kernel uses. Including vmlinux.h in your BPF program eliminates dependency on system-wide kernel headers.

这个命令生成一个vmlinux.h头文件，其中包含运行内核使用的所有BPF Type Format（BTF类型）。在BPF程序中include vmlinux.h文件可以消除对系统范围内内核头文件的依赖。

libbpf enables portability of BPF programs by looking at the BPF program’s recorded BTF type and relocation information and matching them to BTF information (vmlinux) provided by the running kernel. libbpf then resolves and matches all the types and fields, and updates necessary offsets and other relocatable data to ensure that BPF program’s logic functions correctly for a specific kernel on the host. BPF CO-RE concept thus eliminates overhead associated with BPF development and allows developers to write portable BPF applications without modifications and runtime source code compilation on the target machine.

libbpf通过查看BPF程序记录的BTF类型和重定位信息，并将它们与运行内核提供的BTF信息（vmlinux）进行匹配，从而实现BPF程序的可移植性。然后，libbpf解析和匹配所有类型和字段，并更新必要的偏移量和其他可重定位数据，以确保BPF程序的逻辑在主机上的特定内核上正确运行。因此，BPF CO-RE概念消除了与BPF开发相关的开销，并允许开发人员编写可移植的BPF应用程序，而无需在目标机器上进行修改和运行时源代码编译。

The following code snippet shows how to read the parent field of a kernel task_struct using BPF CO-RE and libbf. The basic helper to read a field in a CO-RE relocatable manner is bpf_core_read(dst, sz, src), which will read sz bytes from the field referenced by src into the memory pointed to by dst.

下面的代码片段显示了如何使用BPF CO-RE和libbf读取内核task_struct的parent字段。以可重定位方式读取struct的field的基础BPF helper是bpf_core_read(dst, sz, src)，它将从src引用的字段中读取sz字节到dst指向的内存中。

```c
//...
 struct task_struct *task = (void *)bpf_get_current_task();
 struct task_struct *parent_task;
 int err;

 err = bpf_core_read(&parent_task, sizeof(void *), &task->parent);
 if (err) {
   /* handle error */
 }

 /* parent_task contains the value of task->parent pointer */
 ```

 In the code snippet, we first get a pointer to the current task_struct using bpf_get_current_task(). We then use bpf_core_read() to read the parent field of task struct into the parent_task variable. bpf_core_read() is just like bpf_probe_read_kernel() BPF helper, except it records information about the field that should be relocated on the target kernel. i.e, if the parent field gets shifted to a different offset within struct task_struct due to some new field added in front of it, libbpf will automatically adjust the actual offset to the proper value.

 在上面的代码片段中，我们首先使用bpf_get_current_task()获取指向当前task_struct的指针。然后我们使用bpf_core_read()将task struct的parent字段读入parent_task变量中。bpf_core_read()与bpf_probe_read_kernel() BPF helper类似，只是它记录了应该在目标内核上重定位的字段的信息。也就是说，如果由于在其前面添加了一些新字段而导致parent字段在struct task_struct中的偏移量发生变化，libbpf将自动调整实际偏移量到正确的值。

## Getting Started with libbpf

Check out the [libbpf-bootstrap](https://github.com/libbpf/libbpf-bootstrap) repository with simple examples of using libbpf to build various BPF applications.

See also [libbpf API documentation](libbpf API documentation.).

## libbpf and Rust

If you are building BPF applications in Rust, it is recommended to use the [Libbpf-rs](https://github.com/libbpf/libbpf-rs) library instead of bindgen bindings directly to libbpf. Libbpf-rs wraps libbpf functionality in Rust-idiomatic interfaces and provides libbpf-cargo plugin to handle BPF code compilation and skeleton generation. Using Libbpf-rs will make building user space part of the BPF application easier. Note that the BPF program themselves must still be written in plain C.

## Additional Documentation
- [Program types and ELF Sections](https://libbpf.readthedocs.io/en/latest/program_types.html)
- [API naming convention](https://libbpf.readthedocs.io/en/latest/libbpf_naming_convention.html)
- [Building libbpf](https://libbpf.readthedocs.io/en/latest/libbpf_build.html)
- [API documentation Convention](https://libbpf.readthedocs.io/en/latest/libbpf_naming_convention.html#api-documentation-convention)

## 重要文档索引

| 链接 | 描述 |
| --- | --- |
| [https://docs.kernel.org/bpf/index.html](https://docs.kernel.org/bpf/index.html) | linux内核官方的bpf文档 |
| [https://docs.cilium.io/en/latest/bpf/](https://docs.cilium.io/en/latest/bpf/) | cilium的bpf文档，包含**xdp**和**tc**的bpf program详解 |
| [bpf-helpers man page](https://man7.org/linux/man-pages/man7/bpf-helpers.7.html) |  |