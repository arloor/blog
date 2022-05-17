#! /bin/bash

dir=/home/x1/blog
dir=$PWD
host=$([ "$1" = "" ] && echo "arloor.com 42.192.15.60" || echo "$1")
port=22

git pull
git add .
msg="commit @arloor $(date)"
git commit -m "$msg"
if git push; then
  for i in $host; do
    ssh root@i -p$port -t "
          bash tarloor 1 #使用代理: bash tarloor 1
          "
    echo -e "\033[32m 请访问： https://"$i"\033[0m"
  done
else
  echo -e "\033[32m 推送失败 \033[0m"
fi

function githubio() {
  rm -rf /tmp/arloor.github.io
  hugo -d /tmp/arloor.github.io &>/dev/null
  cd /tmp/arloor.github.io
  git init
  git add . 2>/dev/null
  git commit -m "init" 1>/dev/null
  git remote add origin https://github.com/arloor/arloor.github.io.git
  git push origin master -f
  cd $dir
}
