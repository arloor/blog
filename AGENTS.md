# AGENTS.md

## 项目定位

- 本仓库是 Hugo 静态博客站点，主语言为中文。
- 主题为 `themes/hyde-arloor/`（Git submodule）。
- 主配置文件为 `config.toml`，文章位于 `content/`。

## 目录约定

- `content/posts/`：技术文章 Markdown（主内容）。
- `content/about.md`、`content/*-iframe.md`：独立页面。
- `layouts/shortcodes/`：自定义短代码（`imgx`、`bilibili`、`youtube` 等）。
- `static/`：静态资源（图片、脚本、配置文件）。
- `themes/hyde-arloor/`：主题源码（子模块）。
- `public/`：构建产物目录（发布输出）。
- `resources/_gen/`：Hugo 资源缓存/生成目录。

## Agent 工作原则

- 只做与需求直接相关的最小改动，避免顺手重构。
- 不要手动编辑 `public/` 与 `resources/_gen/`，除非用户明确要求。
- 若修改主题文件，确认改动发生在 `themes/hyde-arloor/`，并注意这是 submodule。
- 文章和文档默认使用中文；命令、路径、代码使用原文。
- 保持现有格式风格，不额外引入格式化噪音。

## 常用命令

```bash
# 启动本地预览（http://127.0.0.1:5505）
make server

# 初始化/更新主题子模块
make update

# 构建站点
hugo -d public
```

## 内容编写规范

- Front Matter 使用 YAML 三横线格式，建议包含：
  - `title`
  - `date`
  - `lastmod`
  - `tags`
  - `categories`
  - `description`
  - `draft`
- 图片优先放在 `static/img/`，正文使用绝对路径引用，如 `/img/xxx.png`。
- 可复用短代码：
  - `{{< imgx src="/img/xxx.png" alt="" width="700px" style="max-width: 100%;">}}`
  - `{{< bilibili BV1YK4y1s7ZU >}}`
  - `{{< youtube VIDEO_ID >}}`

## 提交前检查清单

- 能成功执行 `hugo -d public`，且无新增构建错误。
- 新文章/页面链接可访问，图片路径有效。
- 未误改无关文件，尤其是大体积静态资源。
- 若涉及主题改动，确认 submodule 状态与提交意图一致。

## 发布说明（简）

- GitHub Actions 在 `master` 分支 push/PR 时构建并更新 `gh-pages`。
- 生产环境通过 SSH 拉取 `gh-pages` 到 Nginx 目录。
- 日常内容更新通常只需提交源码，不需要手工维护 `gh-pages`。
