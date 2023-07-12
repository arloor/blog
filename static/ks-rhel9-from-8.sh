# 1. 启用blscfg模块
sed -i 's/GRUB_ENABLE_BLSCFG.*/GRUB_ENABLE_BLSCFG=true/g' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
# 2. 下载网络安装的kernel
ks_url="http://199.180.115.74/ks.cfg" #kickstart配置文件地址
base_url="http://199.180.115.74/rhel8-install"
## 可以从http://199.180.115.74/rhel8-install/.treeinfo确认地址
kernel_url="${base_url}/images/pxeboot/vmlinuz"
init_url="${base_url}/images/pxeboot/initrd.img"
curl -k  "${init_url}" -o '/boot/initrd.img'
curl -k  "${kernel_url}" -o '/boot/vmlinuz'
# 3. 使用grubby工具生成loader entry，这将由blscfg加载
machineId=`cat /etc/machine-id`
rm -rf /boot/loader/entries/${machineId}-vmlinuz*
grubby --add-kernel=/boot/vmlinuz  --make-default --initrd=/boot/initrd.img  --title="rhel9"  --args="ip=dhcp inst.repo=${base_url} inst.ks=${ks_url}" # --make-default 将设置成下次启动的内核
cat /boot/loader/entries/${machineId}-vmlinuz.conf

# [[ -f  /boot/grub2/grubenv ]] && sed -i 's/saved_entry.*/saved_entry='${machineId}'-vmlinuz/g' /boot/grub2/grubenv;
grep saved_entry /boot/grub2/grubenv
echo rebooting to install
sleep 1
reboot