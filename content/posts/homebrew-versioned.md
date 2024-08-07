---
title: "Homebrew安装指定版本的软件"
date: 2024-07-26T15:02:39+08:00
draft: false
categories: [ "undefined"]
tags: ["software"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

需要在mac上安装 clang-format-16，记录下homebrew安装指定版本软件的方法。
<!--more-->

## 安装homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

## 参考文档

- [Homebrew 安装指定版本的三种方式](https://shockerli.net/post/homebrew-install-formula-specific-version/)
- [Formulae Versions](https://docs.brew.sh/Versions)

## 安装指定版本的软件

以安装 clang-format-16 为例

```bash
# 安装tap homebrew/core（最新版本默认不安装tap homebrew/core，所以需要手动安装
brew tap homebrew/core --force
# 寻找tap homebrew/core的路径
brew tap-info homebrew/core     
# /opt/homebrew/Library/Taps/homebrew/homebrew-core (7,446 files, 838.5MB)
cd /opt/homebrew/Library/Taps/homebrew/homebrew-core
# 查看clang-format的信息，确定路径
brew search clang-format
# 如果已经有官方的大版本，比如 clang-format@11，可以直接安装
brew info clang-format
# From: https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/c/clang-format.rb
# 查看的Formula/c/clang-format.rb变更，确定版本
git log -p -- Formula/c/clang-format.rb | grep -e ^commit -e 'url "http'
# commit 32caf9d2d18b258e964354a1d555c05b3c8b0e5d
# commit 442f9cc511ce6dfe75b96b2c83749d90dde914d2
# +    url "https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.6/llvm-16.0.6.src.tar.xz"
# +      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.6/clang-16.0.6.src.tar.xz"
# +      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.6/cmake-16.0.6.src.tar.xz"
# +      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.6/third-party-16.0.6.src.tar.xz"

# 安装16.0.6
brew tap-new $USER/local-tap
brew extract --version='16.0.6' clang-format $USER/local-tap
brew install clang-format@16.0.6
```

## 附录：相关术语：

详见[manpage](https://docs.brew.sh/Manpage)

| 术语     | 意译   | 说明                                              |
|----------|--------|---------------------------------------------------|
| formula  | 配方   | 表示安装包的描述文件。复数为 formulae。           |
| cask     | 木桶   | 装酒的器具，表示具有 GUI 界面的原生应用。         |
| keg      | 小桶   | 表示某个包某个版本的安装目录，比如 /usr/local/Cellar/foo/0.1。 |
| Cellar   | 地窖   | 存放酒的地方，表示包的安装目录，比如 /usr/local/Cellar。 |
| Caskroom | 木桶间 | 表示类型为 Cask 的包的安装目录，比如：/usr/local/Caskroom。  |
| tap      | 水龙头 | 表示包的来源，也就是镜像源。                      |
| bottle   | 瓶子   | 表示预先编译好的包，下载好直接使用。              |


在安装指定版本的过程中涉及到的术语有tap和formula。简单理解是：

- formula：软件的下载、编译、安装的脚本，中文名为配方
- tap：formula所在的文件夹

## 附录：homebrew常用命令：

```bash
brew deps --installed --tree # 查看已安装软件的依赖树
brew search mysql # 搜索软件
brew search "/(^|.+tap.+)go(@|$)/" # 使用正则表达式搜索，以搜索golang为例
brew info mysql # 查看软件信息
brew install mysql # 安装软件
brew list # 查看已安装软件
brew outdated # 查看过期软件
brew upgrade # 升级所有软件
brew upgrade mysql # 升级指定软件
brew cleanup # 清理旧版本软件
brew uninstall mysql # 卸载软件
brew doctor # 检查问题
```

## 附录：指定版本安装的rb脚本

```bash
cat /opt/homebrew/Library/Taps/xxxxxxx/homebrew-local-tap/Formula/clang-format@16.0.6.rb
```

```Ruby
class ClangFormatAT1606 < Formula
  desc "Formatting tools for C, C++, Obj-C, Java, JavaScript, TypeScript"
  homepage "https://clang.llvm.org/docs/ClangFormat.html"
  # The LLVM Project is under the Apache License v2.0 with LLVM Exceptions
  license "Apache-2.0"
  version_scheme 1
  head "https://github.com/llvm/llvm-project.git", branch: "main"

  stable do
    url "https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.6/llvm-16.0.6.src.tar.xz"
    sha256 "e91db44d1b3bb1c33fcea9a7d1f2423b883eaa9163d3d56ca2aa6d2f0711bc29"

    resource "clang" do
      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.6/clang-16.0.6.src.tar.xz"
      sha256 "1186b6e6eefeadd09912ed73b3729e85b59f043724bb2818a95a2ec024571840"
    end

    resource "cmake" do
      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.6/cmake-16.0.6.src.tar.xz"
      sha256 "39d342a4161095d2f28fb1253e4585978ac50521117da666e2b1f6f28b62f514"
    end

    resource "third-party" do
      url "https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.6/third-party-16.0.6.src.tar.xz"
      sha256 "15f5b9aeeba938530af977d5f9205612737a091a7f0f6c8075df8723b7713f70"
    end
  end

  livecheck do
    url :stable
    regex(/llvmorg[._-]v?(\d+(?:\.\d+)+)/i)
    strategy :github_latest
  end

  depends_on "cmake" => :build

  uses_from_macos "libxml2"
  uses_from_macos "ncurses"
  uses_from_macos "python", since: :catalina
  uses_from_macos "zlib"

  on_linux do
    keg_only "it conflicts with llvm"
  end

  def install
    llvmpath = if build.head?
      ln_s buildpath/"clang", buildpath/"llvm/tools/clang"

      buildpath/"llvm"
    else
      (buildpath/"src").install buildpath.children
      (buildpath/"src/tools/clang").install resource("clang")
      (buildpath/"cmake").install resource("cmake")
      (buildpath/"third-party").install resource("third-party")

      buildpath/"src"
    end

    system "cmake", "-S", llvmpath, "-B", "build",
                    "-DLLVM_EXTERNAL_PROJECTS=clang",
                    "-DLLVM_INCLUDE_BENCHMARKS=OFF",
                    *std_cmake_args
    system "cmake", "--build", "build", "--target", "clang-format"

    bin.install "build/bin/clang-format"
    bin.install llvmpath/"tools/clang/tools/clang-format/git-clang-format"
    (share/"clang").install llvmpath.glob("tools/clang/tools/clang-format/clang-format*")
  end

  test do
    system "git", "init"
    system "git", "commit", "--allow-empty", "-m", "initial commit", "--quiet"

    # NB: below C code is messily formatted on purpose.
    (testpath/"test.c").write <<~EOS
      int         main(char *args) { \n   \t printf("hello"); }
    EOS
    system "git", "add", "test.c"

    assert_equal "int main(char *args) { printf(\"hello\"); }\n",
        shell_output("#{bin}/clang-format -style=Google test.c")

    ENV.prepend_path "PATH", bin
    assert_match "test.c", shell_output("git clang-format", 1)
  end
end
```
