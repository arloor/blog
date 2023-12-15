#! /bin/bash
hosts="ti.arloor.com us.arloor.dev"

# 上传到arloor.github.io
function githubio() {
  dir=$PWD
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

msg="commit @$(git config   user.name) $(date '+%F %T %z %A')" 
git pull&&git add . && git commit -m "$msg" && git push || {
  echo -e "\033[32m 推送失败 \033[0m"
}

for host in $hosts; do
  ssh root@${host} '
            curl -sSLf "https://www.arloor.com/tarloor.sh" -o /usr/local/bin/tarloor
            source /etc/profile
            echo $http_proxy
            bash tarloor 0 blog #使用代理: bash tarloor 1
            '
  echo -e "\033[32m 请访问： https://"${host}"\033[0m"
done