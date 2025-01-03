---
author: "刘港欢"
date: 2018-06-21
linktitle: 微服务架构是什么
title: 微服务架构是什么
categories: [ "微服务"]
tags: ["program"]
weight: 10
---



最近总是能看得到微服务这个概念，今天来整理一下微服务的相关概念。内容源自《微服务架构与实践》王磊<!--more-->

## 微服务定义

微服务是一种架构模式，它提倡将单一的应用程序划分为一组小的服务，服务之间互相协调、互相配合，为用户提供最终价值。每个服务运行在其独立的进程中，服务之间通过轻量级的通信机制互相沟通（通常是restful api）。每个服务都围绕具体业务进行构建，并且能够独立地部署到生产环境、类生产环境等。另外，应该尽量避免统一的、集中的服务管理机制，对具体一个服务来说，应根据业务上下文、选择合适的语言、工具对其进行构建。


多微才是微？有人用代码行数或者重写时间来衡量微服务的“微”。作者说：微服务的微并不是一个可衡量、看得见、摸得着的微，而是一种设计思想和指导方针，是需要团队或者组织共同努力找到的一个平衡点。

如何划分服务？应该确保服务是具有“业务独立性”的单元，并不能只是为了微而微。可以从领域模型的角度划分服务。回忆起来丁二玉老师的一段话：软件是对现实世界的抽象，是对现实世界的模拟。通过这种模拟和抽象，软件和现实世界有了共同点，就是领域（domain）。开发者通过影响领域，来影响现实世界。通过领域来划分服务，就是将程序划分为订单、产品、合同等等不同服务。订单、产品、合同这些就是上文说的领域，也就是程序所模拟的现实世界。也可以从业务行为的角度划分服务，比如发送邮件、单点登陆验证、不同数据库之间的同步等等。（说到这里，可以自己搞个发送邮件的微服务欸，毕竟很久之前搞过发送邮件的东西）

团队也需要微。团队需要微的原因是：沟通和协作的成本。当团队的人数超过10人，在沟通和协作上的成本会显著增加。团队虽小，但是需要全功能

轻量级通信。轻量级通信一般是指：平台无关、语言无关的通信方式。格式一般是xml或者json、协议一般是http。这样通信能够标准化并且无状态。对于熟知的java RMI，虽然这种方式简化了消费段的使用，但是对语言产生了耦合。

微服务可以独立地进行开发、测试、构建、部署，不会影响到应用程序的其他部分（与单个进程的应用程序相比）。微服务的部署最好充分的体现独立性和隔离性——不要部署在同一台服务器上（学生没钱搞不起多个服务器怎么破）。

## 微服务与SOA的不同

对SOA本身并不是十分了解，但还是记下这个吧。

|SOA|微服务|
|---|---|
|企业级，自顶向下开展实施|团队级，自底向上开展实施|
|服务由多个子系统构成，粒度达|一个系统被拆分为多个服务，粒度小|
|企业服务总线，集中的服务架构|无集中式总线，松散的服务架构|
|集成方式复杂（ESB/WS/SOLP）|集成方式简单（HTTP/JSON/REST）|
|单块架构系统，相互依赖，部署复杂|服务能独立部署|

## 一个典型的微服务架构是什么样的？

给一个基于spring cloud的架构图：

![微服务架构图](/img/microservice_structure.png)

这个架构各个组件的实现会在`spring cloud学习`中记录。

## 待整理

[服务发现](https://segmentfault.com/a/1190000004960668)

[安全、事务等](https://segmentfault.com/a/1190000004655274)

[service mesh服务网络](https://segmentfault.com/a/1190000015223912)