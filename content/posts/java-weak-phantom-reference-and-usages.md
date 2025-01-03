---
title: "Java的引用类型以及WeakReference和PhantomReference在Threadlocal和DirectByteBuffer中的使用"
date: 2024-01-24T17:21:50+08:00
draft: false
categories: [ "undefined"]
tags: ["java"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

> 内容来自ChatGPT4

## 问：Java的强 软 弱 幻引用区别和使用场景

答：Java中的引用类型是管理内存和垃圾回收的关键工具。在Java中，有四种类型的引用：强引用、软引用、弱引用和幻引用。每种引用类型都有其特定的使用场景和垃圾回收行为。

1. **强引用（Strong Reference）**:
   - **描述**: 默认情况下，当我们在Java中创建一个对象并赋值给一个引用变量时，这个引用就是强引用。例如，`Object obj = new Object();`。只要强引用还存在，垃圾回收器永远不会回收被引用的对象。
   - **使用场景**: 常规对象创建和引用。只要程序需要使用对象，就应该用强引用。
   - **特点**: 容易导致内存泄漏，如果不正确管理。

2. **软引用（Soft Reference）**:
   - **描述**: 通过`SoftReference`类实现。如果一个对象只具有软引用，那么当JVM内存不足时，这些对象可能会被垃圾回收器回收。软引用可以用来实现内存敏感的缓存。
   - **使用场景**: 适用于缓存，特别是那些大小可调整的缓存。如果内存足够，软引用对象不会被回收，这样可以提高性能；如果内存紧张，这些对象会被回收以释放内存。
   - **特点**: 比强引用更灵活，有助于防止内存溢出。

3. **弱引用（Weak Reference）**:
   - **描述**: 通过`WeakReference`类实现。比软引用更弱，只要垃圾回收器运行，无论内存是否足够，都可能回收只有弱引用的对象。
   - **使用场景**: 适合于临时缓存或者作为映射（map）中的键，比如在`WeakHashMap`中。当键不再正常使用时，可以自动移除映射中的条目。
   - **特点**: 有助于避免内存泄漏，但不适合长期存储。

4. **幻引用（Phantom Reference）**:
   - **描述**: 通过`PhantomReference`类实现。幻引用最弱，通过幻引用无法直接获取对象。它主要用于跟踪对象被垃圾回收的状态。
   - **使用场景**: 当对象被回收时接收系统通知或者执行清理工作。通常用于实现高级内存管理技巧。
   - **特点**: 无法通过幻引用获取对象，仅用于跟踪对象的回收状态。

每种引用类型在内存管理中都有其特定用途。选择适当的引用类型可以帮助优

化内存使用，减少内存泄漏的风险，并提高应用程序的性能。 下面是这些引用类型的一些更具体的使用建议：

1. **强引用**:
   - 最常用，但需要谨慎管理。
   - 当对象不再需要时，应该显式地设置引用为`null`，以帮助垃圾回收器及时回收。

2. **软引用**:
   - 在实现缓存时非常有用，尤其是对于那些占用大量内存但不是必需的对象。
   - 例如，可以将图像或文件内容存储在软引用中，当内存足够时，可以从缓存中快速访问这些数据；当内存不足时，垃圾回收器可以自由地回收这些对象，以回收内存空间。

3. **弱引用**:
   - 通常用于实现对对象的非强制性引用，如在`WeakHashMap`中。
   - 当你希望对象能够自动被回收，但又需要跟踪它们的存在时，使用弱引用。例如，弱引用可以用于监听对象何时被垃圾回收。

4. **幻引用**:
   - 幻引用最适用于那些需要在对象被垃圾回收之前进行某些特定清理操作的场景。
   - 由于通过幻引用无法获取对象，它通常用于协调JVM的垃圾回收活动，比如跟踪对象被回收的时间点或者回收前的准备工作。

在选择使用这些不同类型的引用时，应当基于对象的生命周期和程序对内存管理的需求来做决策。强引用是最直接、最简单的引用方式，但在处理大型对象或具有复杂生命周期的对象时，适当使用软引用、弱引用和幻引用可以大大提高程序的性能和可靠性。

## 问：java 幻引用和DirectByteBuffer释放的关系

Java中的幻引用（Phantom Reference）和`DirectByteBuffer`释放之间有一个紧密的关系，这主要涉及到非堆内存的管理。

`DirectByteBuffer`是Java NIO中的一种ByteBuffer，它在非堆内存（直接内存）中分配空间。与在Java堆上分配的标准`ByteBuffer`不同，`DirectByteBuffer`为高效的I/O操作提供了更直接的内存访问路径。但是，直接内存的分配和释放不是由Java虚拟机（JVM）的垃圾回收器直接管理的，这就带来了内存管理的挑战。

在这里，幻引用就发挥了作用：

1. **跟踪DirectByteBuffer的回收状态**:
   - 当`DirectByteBuffer`实例不再有任何强引用指向时，它理论上可以被垃圾回收器回收。但由于它占用的是直接内存，所以需要确保这块内存被正确释放。
   - 通过将`DirectByteBuffer`与一个幻引用关联，可以在`DirectByteBuffer`即将被回收时获得通知。

2. **幻引用队列**:
   - 幻引用通常与一个引用队列一起使用。当`DirectByteBuffer`对象被垃圾回收器标记为即将回收时，它的幻引用会被加入到一个引用队列中。
   - 应用程序可以监视这个队列，当发现某个幻引用出队时，意味着相应的`DirectByteBuffer`对象即将被回收。

3. **触发清理动作**:
   - 一旦幻引用出队，应用程序可以采取行动来确保直接内存被释放。这通常通过调用一些特定的清理方法来实现，如`sun.misc.Cleaner`的`clean`方法。
   - 这种机制确保了即使JVM的垃圾回收器不直接管理直接内存，直接内存的清理和回收也能得到妥善处理。

在实际应用中，这种机制是透明的。`DirectByteBuffer`和其他使用直接内存的NIO类通常已经内置了这样的清理机制。但是，了解这一过程对于理解和处理可能出现的内存泄漏或其他内存管理问题是很重要的。

综上所述，幻引用在`DirectByteBuffer`的内存管理中扮演着重要角色，它允许开发者或JVM在直接内存不再被使用时及时采取措施进行清理，从而避免内存泄漏。

## 问：Java的DirectByteBuffer释放时机

> [Java - When does direct buffer released?](https://stackoverflow.com/questions/36077641/java-when-does-direct-buffer-released)

`DirectByteBuffer` 并不使用 Java 旧的终结器（finalizer）。相反，它使用内部的 `sun.misc.Cleaner` API。它创建一个新线程，并为每个创建的 `DirectByteBuffer`（除了那些指向主缓冲区的副本和切片）存储一个幻影引用（PhantomReference）。当 `DirectByteBuffer` 变成幻影可达状态（即，对字节缓冲区不再存在任何强、软或弱引用）并且垃圾收集器发现这一点时，它会将这个缓冲区添加到由 Cleaner 线程处理的 ReferenceQueue 中。因此，需要发生三个事件：

1. `DirectByteBuffer` 变成幻影可达状态。
2. 进行垃圾收集（在单独的线程中），收集 `DirectByteBuffer` Java 对象，并在 `ReferenceQueue` 中添加一个条目。
3. Cleaner 线程处理到这个条目并运行注册的清理动作（在这个案例中，它是 `DirectByteBuffer.Deallocator` 对象），这个动作最终释放了本地内存。

所以通常你不能保证它何时被释放。如果 Java 堆中有足够的内存，垃圾收集器可能长时间不会被激活。即使它成为幻影可达状态，Cleaner 线程也可能需要一些时间来处理这个条目。它可能正忙于处理之前也使用 Cleaner API 的其他对象。然而，请注意，在 JDK 中实现了部分解决方案：如果你创建了新的 `DirectByteBuffer` 并在此之前分配了过多的直接内存，垃圾收集器可能会被显式调用以强制释放之前遗弃的缓冲区。有关详细信息，请参阅 `Bits.reserveMemory()`（从 `DirectByteBuffer` 构造函数中调用）。

值得注意的是，在 Java 9 中，内部 Cleaner API 已经被整理并发布供一般使用：现在是 `java.lang.ref.Cleaner`。阅读 JavaDoc 可以了解更多有关其工作方式的细节。

## 问：Java threadlocal和WeakReference的关系

Java中的`ThreadLocal`和`WeakReference`（弱引用）之间存在着一个有趣且重要的关系。这种关系主要体现在`ThreadLocal`如何管理其存储的线程局部变量，以及它如何利用弱引用来避免内存泄漏。

### ThreadLocal基础

`ThreadLocal`在Java中用于存储线程局部变量。每个线程都可以通过`ThreadLocal`存储自己的数据副本，而这些数据副本对其他线程不可见。这是实现线程安全的一种方式，因为每个线程都有自己的变量副本，不会与其他线程共享。

### 弱引用（WeakReference）

弱引用是Java中的一种特殊引用类型，它允许对象在没有其他强引用的情况下被垃圾回收器回收。与强引用不同，即使还有弱引用指向对象，垃圾回收器也可以决定回收这个对象，以释放内存空间。

### ThreadLocal和WeakReference的关系

1. **ThreadLocal的键是弱引用**:
   - `ThreadLocal`内部使用了一个名为`ThreadLocalMap`的内部类，它类似于一个简化版的`Map`。
   - 在`ThreadLocalMap`中，`ThreadLocal`对象本身作为键，并且是以弱引用的形式存储的。
   - 这意味着，如果没有其他地方对`ThreadLocal`实例持有强引用，这个`ThreadLocal`实例可能会被垃圾回收器回收。

2. **防止内存泄漏**:
   - 如果`ThreadLocal`的实例被回收，它的`ThreadLocalMap`中的条目的键会变成null。然而，值（存储的线程局部变量）可能不会被回收，因为`ThreadLocalMap`的条目对值持有强引用。
   - 为了防止内存泄漏，每次访问`ThreadLocalMap`时，Java会清理那些键为null的条目。这样可以释放那些不再被使用的线程局部变量的内存。

3. **实用考虑**:
   - 正因为`ThreadLocal`的键是弱引用，所以在使用`ThreadLocal`时，我们必须保持对`ThreadLocal`实例的强引用，至少在这个实例被线程使用期间保持。
   - 同时，为了防止潜在的内存泄漏，通常需要在不再需要线程局部变量时，显式地调用`ThreadLocal.remove()`来清理。

总结来说，`ThreadLocal`通过使用弱引用作为其键来避免潜在的内存泄漏问题。这种设计确保了当`ThreadLocal`对象本身不再被使用时，它存储的数据可以被垃圾回收器适时清理，从而有效管理内存。

## 问： Java的ThreadLocalMap中Entry的key为什么要是WeakReference

Java中的`ThreadLocalMap`使用`WeakReference`作为其Entry的key有几个重要的原因，它们与垃圾回收（GC）、内存泄露和ThreadLocal的生命周期管理密切相关：

1. **避免内存泄露**：`ThreadLocal`的一个常见用途是在线程生命周期内存储线程特有的数据。如果`ThreadLocal`对象的引用被垃圾回收器回收，但是由于ThreadLocalMap中的强引用，其对应的Entry不会被回收，这可能导致内存泄露。使用`WeakReference`作为key，可以确保一旦外部对`ThreadLocal`对象的强引用不存在时，`ThreadLocal`对象可以被垃圾回收器回收。

2. **自动清理Entry**：当`ThreadLocal`对象被回收后，其对应的Entry在`ThreadLocalMap`中成为一个无用的条目（因为它的key为null）。为了避免内存泄露，`ThreadLocalMap`会在后续操作中清理这些无用的条目，例如在调用`set`或`get`方法时。

3. **线程生命周期管理**：由于`ThreadLocalMap`是与线程生命周期绑定的，使用`WeakReference`作为key有助于在不需要时自动清理资源，而不是依赖于显式的清理。这样可以减少内存泄露的风险，尤其是在长时间运行的应用中。

4. **减轻GC压力**：使用`WeakReference`可以减轻垃圾回收器的压力。当ThreadLocal不再被使用时，它可以在下一次GC时被自动回收，而不需要显式的删除操作。

总之，使用`WeakReference`作为`ThreadLocalMap`中Entry的key是一种内存优化策略，旨在减少内存泄露的风险，并简化线程局部变量的生命周期管理。这种设计使得垃圾回收器能够更有效地回收不再需要的ThreadLocal对象，同时保持`ThreadLocalMap`的高效性和一致性。