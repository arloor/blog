---
title: "Git修改历史提交中的用户"
date: 2023-06-07T14:31:05+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 修改历史提交中的用户

比如，你的 `commit` 历史为 `A-B-C-D-E-F` ， `F` 为 `HEAD` ， 你打算修改 `C` 和 `D` 的用户名或邮箱，你需要：

1. 运行 `git rebase -i B` （这里有一个运行该命令后的例子（英文））

    - 如果你需要修改 A ，可以运行 `git rebase -i --root`

2. 把 C 和 D 两个 commit 的那一行的 pick 改为 edit。
    - 可以按 `Ctrl + V` 进入vim的列模式，然后上下左右移动光标选择多个pick，先按X，删除pick，再按 `shift + i` （大写i），插入`edit`，然后安 `Esc`，等两秒左右，就成功将这些 `pick` 改成 `edit` 了。
    - 或者选中 `pick` ，按c进入删除插入模式输入 `edit`，再按 `Esc` 等两秒
3. 多次执行以下命令，直至rebase结束

```bash
git commit --amend --author="arloor <admin@arloor.com>" --no-edit&&git rebase --continue
```

4. 如果需要更新到远程仓库， 使用 `git push -f`（请确保修改的 `commit` 不会影响其他人）


## 统计git仓库中用户代码行

```bash
cat > /usr/local/bin/ncode <<\EOF
[ "$1" = "" ]&&user=arloor||user=$1
echo ${user}\'s work summary:
git log --author="${user}" --pretty=tformat: --numstat | awk '{ add += $1; subs += $2; loc += $1 - $2 } END { printf "added lines: %s, removed lines: %s, total lines: %s", add, subs, loc }'
EOF
chmod +x /usr/local/bin/ncode
ncode arloor
```

## 永久保存git密码

（非程序员不要管这一节啦

```
git config --global credential.helper store
```
当github账号启用了二次验证时，输入的密码请填写自己在github上生成的api key。

## 删除git中某一文件的历史

```bash
git filter-branch --tree-filter 'rm -rf path/folder' HEAD
git filter-branch --tree-filter 'rm -f path/file' HEAD
```

也可以指定 检索的 Commit 历史的范围：

```bash
git filter-branch --tree-filter 'rm -rf path/folder' 347ae59..HEAD
```

最后强制推送

```bash
git push origin master --force
```
