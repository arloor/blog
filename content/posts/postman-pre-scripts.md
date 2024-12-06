---
title: "Postman Pre Scripts设置环境变量"
subtitle:
tags: 
- undefined
date: 2024-12-06T16:59:16+08:00
lastmod: 2024-12-06T16:59:16+08:00
draft: false
categories: 
- undefined
weight: 10
description:
highlightjslanguages:
---

<!--more-->
 
```js
// 获取当前日期
const now = new Date();

// 创建一个新的日期对象并将时间重置为 0 点
let today_start = new Date(now);
today_start.setHours(0, 0, 0, 0);

// 格式化日期为 YYYY-MM-DD HH:mm:ss
function formatDateTime(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
}

// 设置环境变量
pm.environment.set("now", formatDateTime(now));
pm.environment.set("today_start", formatDateTime(today_start));
```

```json
{
    "startTime": "{{today_start}}",
    "endTime": "{{now}}"
}
```