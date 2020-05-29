---
title: "markdown编辑工具"
date: 2020-05-29T12:07:18+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---


一个很简陋的工具

<!--more-->

<table width="100%" style="height:100%">
    <tr >
        <td width="50%" style="border: grey 5px solid;padding:10px" valign="top">
            <div contenteditable="true" oninput="mark()" id="textBox" style="min-height:1000px;height:auto !important;height:1000px;line-height:1.1rem;outline: 0px solid transparent;word-wrap:break-word; word-break:break-all;"></div>
        </td>
        <td width="50%" style="border: grey 5px solid;vertical-align:text-top;">
            <div id="content" style="min-height:1000px;height:auto !important;height:1000px;line-height:1.1rem;outline: 0px solid transparent;word-wrap:break-word; word-break:break-all;"></div>
        </td>
    </tr>
</table>

<script>
    function mark(){
        console.log(document.getElementById('textBox'));
        document.getElementById('content').innerHTML = marked(document.getElementById('textBox').innerText);
    }
</script>
<script src="/marked.min.js"></script>