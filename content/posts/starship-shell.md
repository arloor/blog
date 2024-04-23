---
title: "Starship Shell"
date: 2022-12-16T21:22:57+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

<!--more-->

## 官方文档

[README.md](https://github.com/starship/starship/blob/master/docs/zh-CN/guide/README.md)

## Windows powershell设置

1. 下载[Nerd Font](https://www.nerdfonts.com/)字体，并将字体文件复制到C://Windows/Fonts下
2. 在[发布页](https://github.com/starship/starship/releases/latest)下载 MSI 包来安装Starship最新版。
3. powershell以管理员运行下列命令，以放开脚本执行

```bash
Set-ExecutionPolicy -ExecutionPolicy Unrestricted  -Scope LocalMachine
```

4. 参考官方文档，修改PowerShell 配置文件

>将以下内容添加到您 PowerShell 配置文件的末尾（通过运行 $PROFILE 来获取配置文件的路径）

```plaintext
Invoke-Expression (&starship init powershell)
```

## Linux zsh

```bash
bash ~/.oh-my-zsh/tools/uninstall.sh

if ! grep debian /etc/os-release &>/dev/null; then
  yum install -y zsh git unzip
else
  apt-get install -y zsh git unzip
fi
cd /usr/share/fonts
mkdir -p nerd-fonts
cd nerd-fonts
curl -L https://github.com/ryanoasis/nerd-fonts/releases/download/v2.2.2/3270.zip -o 3270.zip&&unzip -o 3270.zip
cd


usermod -s /bin/zsh $USER
curl -sS https://starship.rs/install.sh | sh -s -- -y

if ! grep "HISTFILE=" ~/.zshrc &>/dev/null; then
  cat >> ~/.zshrc <<\EOF
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=1000
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS
EOF
fi

if ! grep "export ZDOTDIR=" /etc/zshrc &>/dev/null; then
  cat >> /etc/zshrc <<\EOF
export ZDOTDIR=$HOME
EOF
fi

if ! grep "starship init zsh" ~/.zshrc &>/dev/null; then
  cat >> ~/.zshrc <<\EOF
eval "$(starship init zsh)"
EOF
fi

base_dir=~/.zsh
add_plugin(){
    local plugin=$1
    if [ -z "${plugin}" ];then
        echo "Usage: add_plugin <plugin>"
        return 1
    fi
    if [ -d "${base_dir}/${plugin}" ];then
        rm -rf ${base_dir}/${plugin}
    fi
    if git clone https://github.com/zsh-users/${plugin}.git ${base_dir}/${plugin}; then
        if ! grep -E "^source ${base_dir}/${plugin}/${plugin}.zsh" ~/.zshrc &>/dev/null; then
            echo "source ${base_dir}/${plugin}/${plugin}.zsh" >> ~/.zshrc
        fi
    else
        echo "Failed to add plugin ${plugin}"
    fi
}

add_plugin zsh-syntax-highlighting
add_plugin zsh-autosuggestions
```

注意，默认的zsh跟bash在一些行为上有一些差距，所以我手动调用了setopt来设置一些行为，主要控制history和交互式命令行中注释的处理。可以参考zsh中的setopt设置：带localoptions的是仅在当前shell生效，可以不关注。

```bash
$ grep setopt ~/.oh-my-zsh/lib/*
.oh-my-zsh/lib/async_prompt.zsh:  setopt localoptions noksharrays
.oh-my-zsh/lib/cli.zsh:  setopt localoptions nopromptsubst
.oh-my-zsh/lib/completion.zsh:unsetopt menu_complete   # do not autoselect the first completion entry
.oh-my-zsh/lib/completion.zsh:unsetopt flowcontrol
.oh-my-zsh/lib/completion.zsh:setopt auto_menu         # show completion menu on successive tab press
.oh-my-zsh/lib/completion.zsh:setopt complete_in_word
.oh-my-zsh/lib/completion.zsh:setopt always_to_end
.oh-my-zsh/lib/correction.zsh:  setopt correct_all
.oh-my-zsh/lib/diagnostics.zsh:  builtin echo setopt: $(builtin setopt)
.oh-my-zsh/lib/diagnostics.zsh:    pushd pushln pwd r read rehash return sched set setopt shift
.oh-my-zsh/lib/diagnostics.zsh:    unfunction unhash unlimit unset unsetopt vared wait whence where which zcompile
.oh-my-zsh/lib/directories.zsh:setopt auto_cd
.oh-my-zsh/lib/directories.zsh:setopt auto_pushd
.oh-my-zsh/lib/directories.zsh:setopt pushd_ignore_dups
.oh-my-zsh/lib/directories.zsh:setopt pushdminus
.oh-my-zsh/lib/history.zsh:setopt extended_history       # record timestamp of command in HISTFILE
.oh-my-zsh/lib/history.zsh:setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
.oh-my-zsh/lib/history.zsh:setopt hist_ignore_dups       # ignore duplicated commands history list
.oh-my-zsh/lib/history.zsh:setopt hist_ignore_space      # ignore commands that start with space
.oh-my-zsh/lib/history.zsh:setopt hist_verify            # show command with history expansion to user before running it
.oh-my-zsh/lib/history.zsh:setopt share_history          # share command history data
.oh-my-zsh/lib/misc.zsh:setopt multios              # enable redirect to multiple streams: echo >file1 >file2
.oh-my-zsh/lib/misc.zsh:setopt long_list_jobs       # show long list format job notifications
.oh-my-zsh/lib/misc.zsh:setopt interactivecomments  # recognize comments
.oh-my-zsh/lib/spectrum.zsh:  setopt localoptions nopromptsubst
.oh-my-zsh/lib/spectrum.zsh:  setopt localoptions nopromptsubst
.oh-my-zsh/lib/termsupport.zsh:  setopt localoptions nopromptsubst
.oh-my-zsh/lib/termsupport.zsh:  setopt extended_glob
.oh-my-zsh/lib/theme-and-appearance.zsh:setopt prompt_subst
```