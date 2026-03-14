#!/bin/bash
# 复刻能正常启动的手动命令 + FEMU 参数
qemu-system-x86_64 \
  -m 8192 \
  -drive file=/home/taoytao/images/u20s.qcow2,format=qcow2,if=virtio \
  -boot order=c \
  -nographic \
  -machine accel=tcg \
  # 新增 FEMU 设备参数（不影响引导）
  -device femu,devsz_mb=12288,namespaces=1,femu_mode=1,secsz=512,secs_per_pg=8,pgs_per_blk=256,blks_per_pl=256,pls_per_lun=1,luns_per_ch=8,nchs=8,pg_rd_lat=40000,pg_wr_lat=200000,blk_er_lat=2000000,ch_xfer_lat=0,gc_thres_pcent=75,gc_thres_pcent_high=95 \
  -cpu qemu64 \
  -serial mon:stdio