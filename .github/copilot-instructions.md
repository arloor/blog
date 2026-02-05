# Copilot Instructions for arloor.com Blog

## Project Overview

Hugo 静态博客站点 (https://www.arloor.com/)，作者刘港欢。中文技术博客，涵盖 Linux、Redis、Netty、Rust、Docker、Spring Boot 等主题。

## Tech Stack & Requirements

- **Hugo**: Extended version required (需要 SCSS 支持)
- **Theme**: `hyde-arloor` (Git submodule 在 [themes/hyde-arloor](themes/hyde-arloor))
- **语法高亮**: Highlight.js (atom-one-dark 风格)
- **部署**: GitHub Actions → gh-pages 分支 → GitHub Pages + SSH 推送至服务器

## Essential Commands

```bash
make server          # 启动开发服务器 (http://127.0.0.1:5505)
make update          # 更新主题 submodule
hugo -d public       # 构建站点
bash deploy.sh       # 提交 + 构建 + 部署到远程服务器
```

## Directory Structure

- `content/posts/`: 主要博客文章 (Markdown)
- `layouts/shortcodes/`: 自定义 shortcodes (bilibili, imgx, youtube)
- `layouts/iframe/`: iframe 页面专用布局
- `static/`: 静态资源（图片、脚本等），`img/` 是其符号链接
- `themes/hyde-arloor/`: 可修改的主题 submodule
- `public/`: 构建产物（已在 .gitignore，勿手动编辑）

## Content Conventions

### Front Matter (YAML 格式)

所有博客文章使用 YAML front matter：

```yaml
---
title: "文章标题"
date: 2026-01-01T00:00:00+08:00
draft: false
categories: ["category1"]
tags: ["tag1", "tag2"]
weight: 10
highlightjslanguages:
  - rust  # 按需指定语法高亮语言
---
```

### Custom Shortcodes

```markdown
{{< imgx src="/img/xxx.png" width="700px" >}}
{{< bilibili BV1YK4y1s7ZU >}}
{{< youtube VIDEO_ID >}}
```

### iframe 页面

在 front matter 中设置 `layout: iframe` 和 `iframeUrl: "..."` 创建全屏嵌入页面（用于 Grafana、网速监控等）。参考 [content/grafana-iframe.md](content/grafana-iframe.md)。

## Git Conventions

- **提交信息**: 使用中文，格式如 `更新 xxx，添加 yyy`
- **主题更新**: 使用 `make update` 而非直接操作 git submodule
- **避免编辑**: `public/` 目录、`gh-pages` 分支（自动生成）

## Deployment Pipeline

1. Push 到 `master` 分支触发 [GitHub Actions](.github/workflows/deploy.yml)
2. Hugo 构建并强制推送到 `gh-pages` 分支
3. SSH 部署到生产服务器 (ti.arloor.com, us.arloor.dev)
4. 手动部署使用 [deploy.sh](deploy.sh)

## Key Files

- [config.toml](config.toml): 站点配置（菜单、社交链接、高亮设置）
- [Makefile](Makefile): 开发命令定义
- [.vscode/settings.json](.vscode/settings.json): 搜索排除规则（posts/, static/img/）

## 主题定制 (themes/hyde-arloor/)

`hyde-arloor` 是可修改的 Git submodule，基于 Hugo 模板系统。

### 关键目录结构

- `layouts/_default/baseof.html`: 基础模板（HTML 框架）
- `layouts/partials/`: 可复用组件（sidebar、header、footer 等）
- `assets/scss/`: SCSS 样式文件（需要 Hugo extended）
- `layouts/shortcodes/`: 主题级 shortcodes（项目级优先级更高）

### 常见修改场景

**修改侧边栏**: 编辑 [layouts/partials/sidebar.html](themes/hyde-arloor/layouts/partials/sidebar.html)
```html
<!-- 示例：添加自定义链接 -->
<nav class="sidebar-nav">
  <a class="sidebar-nav-item" href="/custom-page/">自定义页面</a>
</nav>
```

**修改样式**: 编辑 [assets/scss/](themes/hyde-arloor/assets/scss/) 下的 SCSS 文件
```scss
// 示例：修改主色调
$sidebar-color: #202020;
```

**覆盖布局**: 在项目根目录 `layouts/` 下创建同名文件（优先级高于主题）
- 示例：创建 `layouts/_default/single.html` 覆盖主题的单页模板

### 主题更新注意事项

```bash
# 更新主题到最新版本
make update  # 或 git submodule update --remote themes/hyde-arloor

# 如果修改了主题，需要在 themes/hyde-arloor/ 中提交
cd themes/hyde-arloor
git add .
git commit -m "自定义修改说明"
git push  # 推送到你的 fork（如果有）
```

## 创建 Shortcodes

Shortcodes 是 Hugo 的可复用内容片段，放置在 [layouts/shortcodes/](layouts/shortcodes/) 目录。

### Shortcode 参数传递方式

**位置参数** (适用于简单 shortcode):
```html
<!-- layouts/shortcodes/youtube.html -->
{{ $videoID := index .Params 0 }}
<iframe src="https://www.youtube.com/embed/{{ $videoID }}"></iframe>
```

使用方式：`{{< youtube VIDEO_ID >}}`

**命名参数** (适用于复杂 shortcode):
```html
<!-- layouts/shortcodes/imgx.html -->
{{ $src := .Get "src" }}
{{ $width := .Get "width" }}
<img src="{{ $src }}" width="{{ $width }}" style="max-width: 100%;">
```

使用方式：`{{< imgx src="/img/pic.png" width="700px" >}}`

### 创建新 Shortcode 的步骤

1. 在 `layouts/shortcodes/` 创建 HTML 文件（如 `alert.html`）
2. 使用 Hugo 模板语法编写内容
3. 在 Markdown 中使用 `{{< alert >}}` 调用

**示例：创建提示框 shortcode**

```html
<!-- layouts/shortcodes/alert.html -->
{{ $type := .Get "type" | default "info" }}
<div class="alert alert-{{ $type }}">
  {{ .Inner }}
</div>
```

使用：
```markdown
{{< alert type="warning" >}}
注意：这是警告信息
{{< /alert >}}
```

### 现有 Shortcodes 参考

- [bilibili.html](layouts/shortcodes/bilibili.html): 支持 BV 号和 AV 号，自动识别
- [imgx.html](layouts/shortcodes/imgx.html): 图片插入，支持宽度控制
- [youtube.html](layouts/shortcodes/youtube.html): YouTube 视频嵌入

## Notes for AI Agents

- 新增博客文章时，参考现有文章的 front matter 格式
- 图片引用使用 `/img/` 路径（对应 `static/img/`）
- 主题修改在 `themes/hyde-arloor/` 中进行（这是可编辑的 submodule）
- 项目级 `layouts/` 文件优先级高于主题级，可用于覆盖主题模板
- 避免搜索 `static/img/` (大量二进制文件)
- 本地测试必须使用 Hugo extended 版本（SCSS 编译需要）
- 所有内容、注释、提交信息均使用中文
