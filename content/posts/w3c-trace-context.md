---
title: "W3c Trace Context"
date: 2023-03-23T14:42:06+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

> Generate by ChatGPT4

W3C (World Wide Web Consortium)推出了Trace Context规范，旨在规范分布式追踪中跟踪信息的传播格式。Trace Context规范主要定义了两个HTTP头部字段：**`traceparent`**和**`tracestate`**。

1. **`traceparent`**：
**`traceparent`**头部字段包含了必要的追踪信息，允许分布式系统中的组件协同追踪。它遵循以下格式：

```
traceparent: {version}-{trace-id}-{parent-id}-{trace-flags}
```

- **`version`**（版本）：2个十六进制数字，表示当前**`traceparent`**头部字段的版本。如：**`00`**。
- **`trace-id`**（追踪ID）：32个十六进制数字，用于标识整个分布式追踪过程中的唯一追踪ID。如：**`0af7651916cd43dd8448eb211c80319c`**。
- **`parent-id`**（父ID）：16个十六进制数字，用于表示当前请求或操作的唯一ID。如：**`b7ad6b7169203331`**
- **`trace-flags`**（追踪标志）：2个十六进制数字，表示追踪的特定选项。如：**`01`**。

例如：

```

traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01

```

1. **`tracestate`**：
**`tracestate`**头部字段允许跟踪系统扩展**`traceparent`**头部字段中的信息。它包含多个键值对，由逗号分隔，每个键值对由供应商定义的键和值组成。

```

tracestate: {vendor1Key}={vendor1Value},{vendor2Key}={vendor2Value},...

```

例如：

```

tracestate: congo=t61rcWkgMzE,rojo=00f067aa0ba902b7

```

在分布式追踪过程中，每个服务都需要遵循W3C Trace Context规范，将**`traceparent`**和**`tracestate`**头部字段传递给下游服务。这些头部字段使得跨服务的请求链路可追踪和可观测。