#!/bin/bash
IMGDIR=$HOME/images
OSIMGF=$IMGDIR/u20s.qcow2

# 检查镜像
if [[ ! -e "$OSIMGF" ]]; then
    echo "错误：找不到虚拟机镜像 $OSIMGF"
    exit 1
fi

# 关键：设备大小降到2GB（2048MB），内存占用约2GB，WSL2可稳定分配
FEMU_OPT="-device femu,devsz_mb=4096,namespaces=1,femu_mode=1,secsz=512,secs_per_pg=8,pgs_per_blk=256,blks_per_pl=256,pls_per_lun=1,luns_per_ch=4,nchs=4,pg_rd_lat=40000,pg_wr_lat=200000,blk_er_lat=2000000,ch_xfer_lat=0,gc_thres_pcent=75,gc_thres_pcent_high=95"
echo $FEMU_OPT

# 绝对路径 + 单行命令（避免格式错误）
QEMU_PATH="/home/taoytao/Project/FEMU/build-femu/qemu-system-x86_64"
sudo $QEMU_PATH -name "FEMU-BBSSD-VM" -machine type=pc,accel=tcg -cpu qemu64 -smp 2 -m 4G -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=hd0 -drive file=$OSIMGF,if=none,aio=native,cache=none,format=qcow2,id=hd0 $FEMU_OPT -net user,hostfwd=tcp::8080-:22 -net nic,model=virtio -nographic -qmp unix:./qmp-sock,server,nowait 2>&1 | tee log