---
title: "oh-my-zsh使用"
date: 2022-12-08T15:00:02+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

<!--more-->

## 安装zsh和ohMyZsh

```bash
yum install -y zsh
sh -c "$(curl -fsSL --insecure https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

## 配置相关插件

我这边常用的插件是git、 zsh-autosuggestions、 zsh-syntax-highlighting

```bash
## 设置默认shell为zsh
sudo usermod -s /bin/zsh $USER
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
sed -i  -e "s/^plugin.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/g" ~/.zshrc
## 在命令提示符前增加hostname
echo 'export PS1="%m "${PS1}' >> ~/.zshrc
```

