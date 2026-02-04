---
title: "Git常用命令"
date: 2023-06-07T14:31:05+08:00
draft: false
categories: ["undefined"]
tags: ["software", "github"]
weight: 10
subtitle: ""
description: ""
keywords:
  - 刘港欢 arloor moontell
---

## 设置github.com的用户名

参考[git文档](https://git-scm.com/docs/git-config#Documentation/git-config.txt-codehasconfigremoteurlcode)，允许使用标准文件路径匹配（standard globbing wildcards）和`/**`、`**/`来定义url的pattern

```bash
git config --global "includeIf.hasconfig:remote.*.url:*://*github.com*/**.path" .gitconfig_github
git config --global "includeIf.hasconfig:remote.*.url:git@github.com:*/**.path" .gitconfig_github

cat > ~/.gitconfig_github <<EOF
[user]
        name = arloor
        email = admin@arloor.com
EOF
```

> 可以增加下面的代码来控制内网的git仓库不走全局git代理：

```bash
[http]
        proxy =
[https]
        proxy =
```

## 使用ssh密钥登录Github

### linux/MacOS

```bash
proxyport=7890 #按需修改
apt install -y socat # 安装socat工具
# 替换将https的github地址替换为ssh地址
git config --global url.git@github.com:.insteadOf https://github.com/
# 设置http代理
mkdir -p ~/.ssh
grep -qF 'Host github.com' ~/.ssh/config || cat >> ~/.ssh/config << EOL
Host github.com
    HostName github.com
    ProxyCommand socat - PROXY:localhost:%h:%p,proxyport=${proxyport}
    User arloor
EOL
ssh -T git@github.com
```

### Windows

```powershell
$proxyport = 7890 # 按需修改
# 替换将https的github地址替换为ssh地址
git config --global url.git@github.com:.insteadOf https://github.com/
# 设置SSH代理（使用Git for Windows自带的connect工具）
$sshConfigPath = "$env:USERPROFILE\.ssh\config"
if (!(Test-Path $sshConfigPath)) {
    New-Item -ItemType File -Path $sshConfigPath -Force | Out-Null
}
$configContent = Get-Content $sshConfigPath -Raw -ErrorAction SilentlyContinue
if ($configContent -notmatch 'Host github\.com') {
    Add-Content -Path $sshConfigPath -Value @"

Host github.com
    HostName github.com
    ProxyCommand "C:\\Program Files\\Git\\mingw64\\bin\\connect.exe" -H localhost:$proxyport %h %p
    User arloor
"@
}
ssh -T git@github.com
```

> 注意：此方法需要 Git for Windows 环境（自带 connect.exe）。如果使用其他代理工具，可以将 `connect -H` 替换为相应的代理命令。

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
# 默认就是，其实不需要显式设置
git config --global credential.helper osxkeychain
```

然后在“钥匙串访问”搜索`github.com`，双击，可以查看和修改密码。

{{< imgx src="/img/git-credential-osxkeychain-view.png" alt="" width="700px" style="max-width: 100%;">}}

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
[ "$1" = "" ]&&user="arloor\|刘港欢\|liuganghuan"||user=$1

echo ${user}\'s work summary: @$(date)
git log --author="刘港欢\|liuganghuan\|arloor" --pretty=tformat: --numstat | awk '{
    if ($1 != "-" && $2 != "-") {
        add += $1;
        subs += $2;
        loc += $1 - $2;
    }
}
END {
    printf "added lines: %s, removed lines: %s, total lines: %s\n", add, subs, loc
}'
EOF
chmod +x /usr/local/bin/ncode
ncode arloor
```

## 删除git中某一文件的历史

```bash
git filter-branch --tree-filter 'rm -rf path/folder' HEAD
git filter-branch --tree-filter 'rm -f path/file' HEAD
# 也可以指定 检索的 Commit 历史的范围：
# git filter-branch --tree-filter 'rm -rf path/folder' 347ae59..HEAD

# 最后强制推送
git push --force --all
git push origin master --force --tags

# 立即删除本地无用的缓存，释放空间
git for-each-ref --format="delete %(refname)" refs/original | git update-ref --stdin
git reflog expire --expire=now --all
git gc --prune=now
```

## 打印最后一个提交

```bash
git -P log -1 -p --color
```

## 不再跟踪某个文件

保持之前的内容，不再提交之后的变更，可以使用下面的命令：

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
