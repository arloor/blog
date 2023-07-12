base_url="http://199.180.115.74/rhel8-install"
kernel_url="${base_url}/isolinux/vmlinuz"
init_url="${base_url}/isolinux/initrd.img"
ks_url="http://199.180.115.74/ks.cfg"

curl -k  "${init_url}" -o '/boot/initrd.img'
curl -k  "${kernel_url}" -o '/boot/vmlinuz'
machineId=`cat /etc/machine-id`
rm -rf /boot/loader/entries/${machineId}-vmlinuz*
grubby --add-kernel=/boot/vmlinuz  --make-default --initrd=/boot/initrd.img  --title="rhel9"  --args="ip=dhcp inst.repo=http://199.180.115.74/rhel8-install inst.ks=http://199.180.115.74/ks.cfg"

[[ -f  /boot/grub2/grubenv ]] && sed -i 's/saved_entry.*/saved_entry='${machineId}'-vmlinuz/g' /boot/grub2/grubenv;
grep saved_entry /boot/grub2/grubenv
echo rebooting to install
sleep 1
reboot