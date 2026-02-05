# CLAUDE.md

## Project Overview

Hugo 静态博客站点，站点地址 https://www.arloor.com/ ，作者刘港欢（arloor）。内容以中文技术博客为主，涵盖 Linux、Redis、Netty、Rust、Docker、Spring Boot 等主题。

## Tech Stack

- **静态站点生成器**: Hugo (extended 版本，需要 SCSS 支持)
- **主题**: `hyde-arloor` (Git submodule，位于 `themes/hyde-arloor/`)
- **语法高亮**: Highlight.js (atom-one-dark 风格)
- **部署**: GitHub Actions → gh-pages 分支 → GitHub Pages + SSH 推送至多台服务器
- **Web 服务器**: Nginx

## Common Commands

```bash
# 本地开发服务器 (http://127.0.0.1:5505)
make server

# 更新 Git submodule（主题）
make update

# 构建站点到 public/ 目录
hugo -d public

# 部署（提交 + 构建 + 推送至远程服务器）
bash deploy.sh
```

## Directory Structure

```
archetypes/         # Hugo 文章模板（front matter 默认值）
content/            # 博客内容（Markdown）
  posts/            # 主要博客文章（按子目录分类）
  about.md          # 关于页面
  *-iframe.md       # 嵌入式 iframe 页面（Grafana、网速监控等）
layouts/            # 自定义 Hugo 布局
  iframe/           # iframe 类型页面的布局模板
  shortcodes/       # 自定义 shortcodes（bilibili, img, imgx, youtube）
static/             # 静态资源（图片、脚本、配置文件等）
themes/hyde-arloor/ # 主题（Git submodule，勿直接修改）
config.toml         # Hugo 站点配置
```

## Content Conventions

### Front Matter 格式 (YAML)

```yaml
---
title: "文章标题"
subtitle:
tags:
  - tag1
date: 2026-01-01T00:00:00+08:00
lastmod: 2026-01-01T00:00:00+08:00
draft: false
categories:
  - category1
weight: 10
description:
highlightjslanguages:
  - rust    # 按需指定需要的高亮语言
---
```

### 自定义 Shortcodes

```markdown
<!-- 图片（带宽度和样式控制） -->
{{< imgx src="/img/xxx.png" alt="描述" width="700px" style="max-width: 100%;">}}

<!-- Bilibili 视频嵌入 -->
{{< bilibili BV1YK4y1s7ZU >}}

<!-- YouTube 视频嵌入 -->
{{< youtube VIDEO_ID >}}
```

### iframe 页面

使用 `layout: iframe` 的 Markdown 页面会渲染为全屏 iframe，sandbox 属性为 `allow-scripts allow-same-origin allow-forms allow-popups allow-storage-access-by-user-activation allow-modals`。

## Configuration

- **站点配置**: [config.toml](config.toml) — 包含站点元数据、菜单、社交链接、语法高亮设置
- **主分支**: `master`
- **部署分支**: `gh-pages`（自动生成，勿手动修改）
- **语言**: `zh-CN`（中文，启用 CJK 支持）

## Git Conventions

- 提交信息通常使用中文，格式如：`更新 xxx，添加 yyy`
- 主题 `hyde-arloor` 是 Git submodule，更新主题使用 `make update`
- `public/` 目录为构建产物，已在 `.gitignore` 中排除

## CI/CD

GitHub Actions 工作流 ([.github/workflows/deploy.yml](.github/workflows/deploy.yml))：
1. `master` 分支 push 或 PR 时触发
2. 使用最新 Hugo extended 版本构建
3. 将构建产物推送至 `gh-pages` 分支
4. 通过 SSH 部署到生产服务器

## Notes

- `img` 是指向 `static/img` 的符号链接，方便在编辑器中引用图片
- `static/` 目录较大（包含大量图片和二进制文件），搜索时注意排除
- VS Code 已配置搜索排除规则（见 `.vscode/settings.json`）
