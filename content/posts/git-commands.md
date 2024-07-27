---
title: "Git常用命令"
date: 2023-06-07T14:31:05+08:00
draft: false
categories: [ "undefined"]
tags: ["software","github"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 设置github.com的用户名

参考[git文档](https://git-scm.com/docs/git-config#Documentation/git-config.txt-codehasconfigremoteurlcode)，允许使用标准文件通配符（standard globbing wildcards）和`/**`、`**/`来定义url的pattern

```bash
git config --global "includeIf.hasconfig:remote.*.url:*://*github.com*/**.path" .gitconfig_github
git config --global "includeIf.hasconfig:remote.*.url:git@github.com:*/**.path" .gitconfig_github

cat > ~/.gitconfig_github <<EOF
[user]
        name = arloor
        email = admin@arloor.com
EOF
```

## 永久保存git密码

### Linux/Windows

```bash
git config --global credential.helper store
touch ~/.git-credentials
echo "https://arloor:${{ github.token }}@github.com" >> ~/.git-credentials
```

当github账号启用了二次验证时，输入的密码请填写自己在github上生成的api key。

### MacOS

```bash
git config --global credential.helper osxkeychain
```

然后在“钥匙串访问”搜索`github.com`，双击，可以查看和修改密码。

![Alt text](/img/git-credential-osxkeychain-view.png)

### 使用git config

```bash
git config --global url.https://arloor:${{ github.token }}@github.com/.insteadOf https://github.com/
```

这种设置的坏处是token保存在了git config文件中，安全程度可能稍差。但是对于go.mod中依赖了私有库的情况很方便

## 修改历史提交中的用户

比如，你的 `commit` 历史为 `A-B-C-D-E-F` ， `F` 为 `HEAD` ， 你打算修改 `C` 和 `D` 的用户名或邮箱，你需要：

1. 运行 `git rebase -i B` 
    1. 如果你需要修改 A ，可以运行 `git rebase -i --root`
2. 把 C 和 D 两个 commit 的那一行的 pick 改为 edit。下面用vim列模式来批量修改( d删除、I在前方插入、A在后方插入、c修改)
    1. 按 `Ctrl + V` 进入vim的列模式
    2. 然后上下左右移动光标选择多个pick
    3. 先输入小写d，删除pick，再输入大写I，插入`edit`，然后安 `Esc`，等两秒左右。
    4. **或者选中 `pick` ，按c进入删除插入模式输入 `edit`，再按 `Esc` 等两秒**
3. 多次执行以下命令，直至rebase结束

```bash
git commit --amend --author="arloor <admin@arloor.com>" --no-edit&&git rebase --continue
```

4. 如果需要更新到远程仓库， 使用 `git push -f`（请确保修改的 `commit` 不会影响其他人）

## 统计git仓库中用户代码行

```bash
cat > /usr/local/bin/ncode <<\EOF
[ "$1" = "" ]&&user=arloor||user=$1

echo ${user}\'s work summary: @$(date) | tee -a ~/data/ncode.log
git log --author="${user}" --pretty=tformat: --numstat | awk '{ add += $1; subs += $2; loc += $1 - $2 } END { printf "added lines: %s, removed lines: %s, total lines: %s", add, subs, loc }' | tee -a ~/data/ncode.log
echo  "" | tee -a ~/data/ncode.log
EOF
chmod +x /usr/local/bin/ncode
ncode arloor
```

执行历史还会输出到 `~/data/ncode.log` 以便查看历史记录

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
git push --force --all
git push origin master --force --tags
```

立即删除本地无用的缓存，释放空间

```bash
git for-each-ref --format="delete %(refname)" refs/original | git update-ref --stdin
git reflog expire --expire=now --all
git gc --prune=now
```

## 打印最后一个提交

```bash
git -P log -1 -p --color
```

## 不再跟踪某个文件

如果想要保持之前的内容，不再提交之后的变更，可以使用下面的命令：

```bash
git update-index --assume-unchanged path/to/your/file # 假设某文件未变更，从而不加入暂存区
git ls-files -v | grep '^[a-z]' # 查看当前被假设未变更的文件，即以 h 开头的文件

# git update-index --no-assume-unchanged path/to/your/file # 恢复
```

## 将已被追踪的文件删除并加入 `.gitignore`

比如要在 `.gitignore` 中增加：

```bash
logs/
data/*.csv
```

需要执行下面命令删除相关缓存

```bash
git rm -r --cached logs/
git rm -r --cached data/*.csv
```

更暴力的也可以：

```bash
git rm -r --cached .
```

之后可以 `add` 和 `commit`