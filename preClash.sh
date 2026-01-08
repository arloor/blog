mkdir -p static/clash/ruleset
cd static/clash/ruleset
for url in `awk -F "[ \"]+" '$2=="url:" {print $3}' <(curl -sSLf http://cdn.arloor.com/clash/mihomo.yaml)` 
do
    echo 下载 $url
    curl -sSLfO $url
done
cd -

# 下载 https://repo-1252282974.cos.ap-shanghai.myqcloud.com/clash/twitter.yaml
# 下载 https://repo-1252282974.cos.ap-shanghai.myqcloud.com/clash/openai.yaml
# 下载 https://repo-1252282974.cos.ap-shanghai.myqcloud.com/clash/apple.yaml
# 下载 https://repo-1252282974.cos.ap-shanghai.myqcloud.com/clash/netflix.yaml
# 下载 https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/proxy.txt
# 下载 https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/direct.txt
# 下载 https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/gfw.txt
# 下载 https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/greatfire.txt
# 下载 https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/telegramcidr.txt
# 下载 https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/cncidr.txt
# 下载 https://cdn.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/lancidr.txt
