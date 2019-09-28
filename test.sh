wget --no-check-certificate -qO '/boot/initrd.img' "http://mirrors.ustc.edu.cn/centos/7/os/x86_64/isolinux/initrd.img"
wget --no-check-certificate -qO '/boot/vmlinuz' "http://mirrors.ustc.edu.cn/centos/7/os/x86_64/isolinux/vmlinuz"

menuentry 'Install Centos7' --class debian --class gnu-linux --class gnu --class os {
        抄
        linux16 /vmlinuz ip=dhcp inst.repo=http://mirrors.aliyun.com/centos/7/os/x86_64/   nameserver=223.6.6.6 inst.lang=zh_CN inst.keymap=us 
        initrd16        /initrd.img
}